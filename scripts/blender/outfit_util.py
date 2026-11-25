# 上衣／下身換裝的共用工具（export_app.py exec）：讀卡通材質的塗色節點鏈、存每個系列的塗色資料、
# 展 UV、算「像素 → 三角形＋重心座標」、把塗色烘成貼圖（不用 Cycles，ShaderToRGB 不能烘；用 numpy 直接算）。
# 設計見 docs/3d-system.md「上衣／下身換裝」。
#
# 貼圖格式（每張 2N×N、RGB、不透明 PNG）：
#   左半 = 亮面色（sRGB 編碼，App 著色器自己轉回線性）
#   右半 = R：有沒有蓋住（255＝衣服、0＝不蓋，露出下一層／皮膚）、G：暗面倍率×255
# 不放 alpha：iOS 讀 PNG 時可能把顏色預乘 alpha，顏色會變暗。
import bpy, bmesh, json, math, hashlib, os
import numpy as np

CLOTH_PARTS = {'top_suit': 'cloth_suit', 'bottom_long': 'cloth_long', 'bottom_short': 'cloth_short'}
CLOTH_SLOT = {'top_suit': 'top', 'bottom_long': 'bottom', 'bottom_short': 'bottom'}
CLOTH_KIND = {'top_suit': 'suit', 'bottom_long': 'long', 'bottom_short': 'short'}


def _ramp_info(node):
    els = node.color_ramp.elements
    c = list(els[1].color[:3])
    k = max(range(3), key=lambda i: c[i])
    shade = els[0].color[k] / c[k] if c[k] > 0 else 0.6
    return [round(x, 5) for x in c], round(shade, 4)


def paint_chain(mname, covered):
    """卡通材質的塗色節點鏈 → {'base': [色, 暗面倍率] 或 None, 'layers': [[屬性, 色, 暗面倍率]…]}（layers 依序疊，後面的蓋前面的）。
    covered=False：底色是皮膚（上衣圖裡算「不蓋」）"""
    m = bpy.data.materials[mname]
    nt = m.node_tree
    em = None
    for n in nt.nodes:
        if n.type != 'EMISSION' or not n.inputs['Color'].is_linked: continue
        fn = n.inputs['Color'].links[0].from_node
        if fn.type == 'MIX_RGB' or (fn.type == 'VALTORGB' and len(fn.color_ramp.elements) == 3):
            em = n; break
    assert em, f'材質 {mname} 不是卡通材質，讀不到塗色'
    node = em.inputs['Color'].links[0].from_node
    layers = []
    while node.type == 'MIX_RGB':
        rp = node.inputs['Color2'].links[0].from_node
        gt = node.inputs['Fac'].links[0].from_node
        assert gt.type == 'MATH' and gt.operation == 'GREATER_THAN' and abs(gt.inputs[1].default_value) < 1e-9, f'{mname}：塗色判斷不是「屬性 > 0」'
        at = gt.inputs[0].links[0].from_node
        assert at.type == 'ATTRIBUTE', f'{mname}：塗色層不是讀屬性'
        layers.append([at.attribute_name, *_ramp_info(rp)])
        node = node.inputs['Color1'].links[0].from_node
    assert node.type == 'VALTORGB', f'{mname}：最底層不是色帶'
    layers.reverse()
    return {'base': list(_ramp_info(node)) if covered else None, 'layers': layers}


def topo_hash(me):
    h = hashlib.md5()
    for p in me.polygons: h.update(np.array(p.vertices, dtype=np.int32).tobytes())
    return h.hexdigest()


def float_attrs(me, names):
    out = {}
    for n in names:
        a = me.attributes.get(n)
        assert a is not None and a.domain == 'POINT', f'找不到頂點屬性 {n}'
        v = np.zeros(len(me.vertices), dtype=np.float32); a.data.foreach_get('value', v)
        out[n] = [round(float(x), 5) for x in v]
    return out


def dump_series(body, cloths, face_mats, hero, path):
    """outfit 模式：把這個系列的上衣／下身塗色存成 JSON（身體＋衣服網格）。
    body、cloths：拆好的物件；face_mats[物件名]＝每個面原本的材質名"""
    meta = hero['outfit'].to_dict(); bm_ = list(hero['body_mats'])
    chains, keys = [], {}
    def cid(mname, covered):
        k = (mname, covered)
        if k not in keys: keys[k] = len(chains); chains.append(paint_chain(mname, covered))
        return keys[k]
    rg = body.data.attributes['rgn']; rgn = np.zeros(len(body.data.polygons), dtype=np.int32); rg.data.foreach_get('value', rgn)
    bit = 4 if meta['long'] else 2
    top, bot = [], []
    for i in range(len(body.data.polygons)):
        r = int(rgn[i])
        top.append(cid(bm_[1], True) if meta['suit'] and r & 1 else cid(bm_[0], False))
        bot.append(cid(bm_[2], True) if r & bit else -1)
    def attrs_of(me, faces):
        need = {l[0] for c in faces if c >= 0 for l in chains[c]['layers']}
        return float_attrs(me, sorted(need))
    out = {'series': meta, 'chains': chains,
           'body': {'nv': len(body.data.vertices), 'topo': topo_hash(body.data), 'top': top, 'bottom': bot}, 'cloth': {}}
    out['body']['attrs'] = attrs_of(body.data, set(top) | set(bot))
    for ob in cloths:
        part = ob.name.split('__')[0]
        fc = [cid(mn, True) for mn in face_mats[ob.name]]
        out['cloth'][part] = {'nv': len(ob.data.vertices), 'topo': topo_hash(ob.data), 'faces': fc, 'attrs': attrs_of(ob.data, set(fc))}
    json.dump(out, open(path, 'w'), separators=(',', ':'))
    print('outfit dump', meta, 'chains', len(chains), 'cloth', list(out['cloth']))


# ---------- UV 與像素對照 ----------
def unwrap(ob, margin=0.02):
    """Smart UV Project，再縮進 [0.01, 0.99]（貼圖左右兩半拼在一起，島不能碰邊）"""
    for u in list(ob.data.uv_layers): ob.data.uv_layers.remove(u)
    ob.data.uv_layers.new(name='st')
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=margin, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(rotate=True, margin_method='FRACTION', margin=margin)   # smart_project 排得鬆（身體只占 27%）
    bpy.ops.object.mode_set(mode='OBJECT')
    uv = ob.data.uv_layers['st'].data
    a = np.zeros(len(uv) * 2, dtype=np.float32); uv.foreach_get('uv', a)
    a = 0.01 + np.clip(a, 0, 1) * 0.98
    uv.foreach_set('uv', a)


def raster(ob, N):
    """每個像素（中心）落在哪個三角形、重心座標。回傳 dict：tri (N,N)、bary (N,N,3)、tri_v (T,3)、tri_poly (T,)"""
    me = ob.data; me.calc_loop_triangles()
    T = len(me.loop_triangles)
    loops = np.zeros(T * 3, dtype=np.int32); me.loop_triangles.foreach_get('loops', loops)
    tv = np.zeros(T * 3, dtype=np.int32); me.loop_triangles.foreach_get('vertices', tv)
    tp = np.zeros(T, dtype=np.int32); me.loop_triangles.foreach_get('polygon_index', tp)
    uvd = me.uv_layers['st'].data
    uv = np.zeros(len(uvd) * 2, dtype=np.float64); uvd.foreach_get('uv', uv); uv = uv.reshape(-1, 2)
    P = uv[loops].reshape(T, 3, 2) * N
    tri = -np.ones((N, N), dtype=np.int32); bary = np.zeros((N, N, 3), dtype=np.float32)
    for t in range(T):
        a, b, c = P[t]
        x0 = max(int(math.floor(min(a[0], b[0], c[0]) - 0.5)), 0); x1 = min(int(math.ceil(max(a[0], b[0], c[0]))), N - 1)
        y0 = max(int(math.floor(min(a[1], b[1], c[1]) - 0.5)), 0); y1 = min(int(math.ceil(max(a[1], b[1], c[1]))), N - 1)
        if x1 < x0 or y1 < y0: continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-12: continue
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1 - w0 - w1
        ins = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not ins.any(): continue
        yy, xx = np.nonzero(ins)
        tri[yy + y0, xx + x0] = t
        bary[yy + y0, xx + x0] = np.stack([w0[ins], w1[ins], w2[ins]], 1)
    return {'tri': tri, 'bary': bary, 'tri_v': tv.reshape(T, 3), 'tri_poly': tp, 'N': N}


def _dilate(val, mask, steps):
    """mask 外的像素往外補 steps 圈（取四鄰中已有值的）"""
    val = val.copy(); mask = mask.copy()
    for _ in range(steps):
        if mask.all(): break
        acc = np.zeros_like(val); cnt = np.zeros(mask.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            m = np.roll(mask, (dy, dx), (0, 1)); v = np.roll(val, (dy, dx), (0, 1))
            acc[m] += v[m]; cnt[m] += 1
        new = (~mask) & (cnt > 0)
        val[new] = acc[new] / (cnt[new][:, None] if val.ndim == 3 else cnt[new])
        mask = mask | new
    return val


def bake(R, face_chain, chains, attrs, pad=8):
    """face_chain[面]＝鏈編號（-1＝不蓋）。回傳 (N, 2N, 3) uint8：左半亮面色（sRGB）、右半 R＝蓋住、G＝暗面倍率"""
    N = R['N']; valid = R['tri'] >= 0
    t = R['tri'][valid]; bc = R['bary'][valid]
    vid = R['tri_v'][t]; fc = np.asarray(face_chain, dtype=np.int32)[R['tri_poly'][t]]
    K = len(t)
    col = np.zeros((K, 3), dtype=np.float32); sh = np.zeros(K, dtype=np.float32); cov = np.zeros(K, dtype=bool)
    A = {k: np.asarray(v, dtype=np.float32) for k, v in attrs.items()}
    for ci, ch in enumerate(chains):
        sel = np.nonzero(fc == ci)[0]
        if not len(sel): continue
        if ch['base']:
            col[sel] = ch['base'][0]; sh[sel] = ch['base'][1]; cov[sel] = True
        for name, c, s in ch['layers']:
            v = (A[name][vid[sel]] * bc[sel]).sum(1)
            hit = sel[v > 0]
            col[hit] = c; sh[hit] = s; cov[hit] = True
    img = np.zeros((N, N, 3), dtype=np.float32); shade = np.zeros((N, N), dtype=np.float32); c_ = np.zeros((N, N), dtype=bool)
    img[valid] = col; shade[valid] = sh; c_[valid] = cov
    # 顏色、暗面倍率往外補到沒蓋的像素（雙線性取樣在邊緣才不會混到別的顏色）
    img = _dilate(img, c_, pad); shade = _dilate(shade, c_, pad)
    # 蓋不蓋：島外補 pad 圈（UV 接縫處取樣不會掉到空白）
    cv = _dilate(c_.astype(np.float32), valid, pad)
    srgb = np.where(img <= 0.0031308, img * 12.92, 1.055 * np.power(np.clip(img, 0, 1), 1 / 2.4) - 0.055)
    out = np.zeros((N, 2 * N, 3), dtype=np.uint8)
    out[:, :N] = np.clip(np.round(srgb * 255), 0, 255).astype(np.uint8)
    out[:, N:, 0] = np.where(cv > 0.5, 255, 0).astype(np.uint8)
    out[:, N:, 1] = np.clip(np.round(shade * 255), 0, 255).astype(np.uint8)
    return out


def write_png(path, img):
    """img (H, W, 3) uint8，第 0 列是 v=0（下面）；PNG 由上往下存，所以翻過來"""
    import zlib, struct
    a = np.ascontiguousarray(img[::-1])
    H, W = a.shape[:2]
    raw = b''.join(b'\x00' + a[y].tobytes() for y in range(H))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(data)
    return len(data)
