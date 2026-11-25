# 各系列 gear_<id>.py 共用的造型工具。由 hero_proto.py 在載入系列檔之前 exec。

def hard(ob, bone, mat, w=0.012, seg=2):
    if w:
        bv = ob.modifiers.new('b', 'BEVEL'); bv.width = w; bv.segments = seg; bv.limit_method = 'ANGLE'
    return finish(ob, bone, mat, 0)

def obox(bone, mat, c, size, d=(0, 0, 1), w=0.012, roll=0.0):
    """沿方向 d 擺放的方塊（local Z＝d）"""
    bpy.ops.mesh.primitive_cube_add(location=c); ob = bpy.context.object
    ob.scale = size; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    q = Vector((0, 0, 1)).rotation_difference(Vector(d))
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = q @ Matrix.Rotation(roll, 4, 'Z').to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return hard(ob, bone, mat, w)

def cyl(bone, mat, c, r, depth, d=(0, 0, 1), n=16, w=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=depth, location=c)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r2, depth=depth, location=c)
    ob = bpy.context.object; ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(d))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return hard(ob, bone, mat, w)

def shell(bone, mat, verts, w=0.03):
    """8 個頂點的硬殼（倒角，不做細分，保留機甲的硬邊）"""
    me = bpy.data.meshes.new('sh'); faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(verts, [], faces); ob = bpy.data.objects.new('sh', me); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    return hard(ob, bone, mat, w, 3)


def _ramp(nt, color, shade):
    rp = nt.nodes.new('ShaderNodeValToRGB'); r = rp.color_ramp; r.interpolation = 'CONSTANT'
    r.elements[0].position = 0.0; r.elements[0].color = (*[c * shade for c in color], 1)
    r.elements[1].position = 0.18; r.elements[1].color = (*color, 1)
    e = r.elements.new(0.75); e.color = (*[min(1, c * 1.18 + 0.06) for c in color], 1)
    return rp

def add_layer(m, attr, color, shade=0.6):
    """在 toon(alt=...) 材質上再疊一層塗色：屬性 attr > 0 的地方換成 color（邊緣一樣平滑）"""
    nt = m.node_tree
    mx = [n for n in nt.nodes if n.type == 'MIX_RGB'][-1]
    em = mx.outputs['Color'].links[0].to_node
    s2r = [n for n in nt.nodes if n.type == 'SHADERTORGB'][0]
    rp = _ramp(nt, color, shade); nt.links.new(s2r.outputs['Color'], rp.inputs[0])
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = attr
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.0
    nt.links.new(at.outputs['Fac'], gt.inputs[0])
    mx2 = nt.nodes.new('ShaderNodeMixRGB')
    nt.links.new(gt.outputs[0], mx2.inputs['Fac']); nt.links.new(mx.outputs['Color'], mx2.inputs['Color1'])
    nt.links.new(rp.outputs['Color'], mx2.inputs['Color2']); nt.links.new(mx2.outputs['Color'], em.inputs['Color'])
    return m

def tri(u):
    """0～1 的三角波，用來做冰柱鋸齒"""
    return 1 - abs(2 * (u % 1.0) - 1)

# 塗在身體上的短袖 T 恤形狀（冰霜、小豬共用）：回傳 (領口, 下擺, 袖口) 三個距離，都 >0 才在衣服裡
# 注意：袖口的「線」是無限延伸的平面，往下會再穿過小腿一次。用 sleeve 畫滾邊時一定要再 min(..., hem)，
# 否則小腿會被塗到（2026-11-24 小豬短褲露出來才發現）。hero_proto 會檢查，畫錯直接報錯。
# 袖口跟著上臂骨頭（B）走：靜止姿勢改成 A 字（§6-1）時袖子會一起轉。
# 2026-11-24 前寫死 (0.09,-0.28) 和肩點 (0.24,1.42)；這裡保留和骨頭的相對角度、相對位置，原本的樣子不變。
_UA = B['upper_arm.L']; _ud = _UA[1] - _UA[0]
_ang = math.atan2(_ud.z, _ud.x) + (math.atan2(-0.28, 0.09) - math.atan2(-0.28, 0.06))
_AD = Vector((math.cos(_ang), math.sin(_ang)))              # 上臂方向（x, z）
_SH = (_UA[0].x - 0.03, _UA[0].z)                           # 袖子起算的肩點
def tee_parts(x, y, z):
    ax = abs(x)
    neck = (math.hypot(ax / 0.095, (z - 1.535) / 0.07) - 1) * 0.07   # 圓領
    hem = z - 0.98
    s = (ax - _SH[0]) * _AD.x + (z - _SH[1]) * _AD.y             # 沿上臂離肩多遠
    sleeve = 0.17 - s + max(0.0, 0.235 - ax) * 6                  # 短袖袖口（軀幹上不作用）
    return neck, hem, sleeve

# ---------- 英雄類四系列（night／dawn／rune／astral）共用 ----------
def tube(bone, mat, pts, r, closed=False, taper=None, res=3):
    """沿一串點拉出圓管（曲線轉網格）。taper：每點的半徑倍率；res：截面圓的細分（細環用 1，省頂點）"""
    cu = bpy.data.curves.new('tb', 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = res; cu.use_fill_caps = not closed
    sp = cu.splines.new('POLY'); sp.points.add(len(pts) - 1); sp.use_cyclic_u = closed
    for i, q in enumerate(pts):
        sp.points[i].co = (*q, 1)
        if taper: sp.points[i].radius = taper[i]
    ob = bpy.data.objects.new('tb', cu); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH'); ob = bpy.context.object
    return finish(ob, bone, mat, 0)

def panel(bone, mat, verts, faces, th=0.012, w=0.0, off=0.0):
    """一片有厚度的面（披風、羽翼、劍身）"""
    me = bpy.data.meshes.new('pn'); me.from_pydata(verts, [], faces); ob = bpy.data.objects.new('pn', me); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = th; so.offset = off
    if w:
        bv = ob.modifiers.new('b', 'BEVEL'); bv.width = w; bv.segments = 2; bv.limit_method = 'ANGLE'
    return finish(ob, bone, mat, 0)

def star(bone, mat, c, d, R, r=None, th=0.01, n=5, up=(0, 0, 1)):
    """立體星形（n 角、厚 th），正面朝 d、第一個尖朝 up"""
    d = Vector(d).normalized(); c = Vector(c); up = Vector(up)
    up = (up - d * up.dot(d)).normalized(); side = d.cross(up)
    r = R * 0.45 if r is None else r
    ring = []
    for k in range(2 * n):
        a = math.pi * k / n; rr = R if k % 2 == 0 else r
        ring.append(up * (rr * math.cos(a)) + side * (rr * math.sin(a)))
    vs = [tuple(c + q - d * th / 2) for q in ring] + [tuple(c + q + d * th / 2) for q in ring]
    vs += [tuple(c - d * th * 0.9), tuple(c + d * th * 0.9)]           # 正反面中心微凸，像切割寶石
    m = 2 * n; fs = []
    for k in range(m):
        k2 = (k + 1) % m
        fs.append((k, k2, m + k2, m + k)); fs.append((2 * m, k2, k)); fs.append((2 * m + 1, m + k, m + k2))
    me = bpy.data.meshes.new('st'); me.from_pydata(vs, [], fs); ob = bpy.data.objects.new('st', me); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    me.validate(); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode='OBJECT')
    return finish(ob, bone, mat, 0)

def gem(bone, mat, c, d, r, L):
    """菱形寶石（雙尖八面體，沿 d 拉長）"""
    d = Vector(d).normalized(); c = Vector(c)
    cyl(bone, mat, c + d * (L * 0.3), r, L * 0.6, d, 6, 0.0, r2=0.0)
    cyl(bone, mat, c - d * (L * 0.2), r, L * 0.4, -d, 6, 0.0, r2=0.0)

def sleeve_paint(x, y, z, L):
    """塗在身體上的上衣形狀，袖長 L（0.17＝短袖、0.55＝長袖到手腕）。回傳 (領口, 下擺, 袖口)，都 >0 才在衣服裡。
    袖口平面往下會穿過腿，所以一定要和下擺取 min（hero_proto 會檢查）"""
    neck, hem, sl = tee_parts(x, y, z)
    return neck, hem, sl + (L - 0.17)

def cap_shell(bone, mat, c, r, keep, th=0.012, seg=48, ring=32):
    """橢球殼只留 keep(x, y, z) 為真的頂點（世界座標），再加厚 th 往外。頭盔、兜帽、面罩用"""
    import bmesh as _bm
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=c)
    ob = bpy.context.object; ob.scale = r; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co.x + c[0], v.co.y + c[1], v.co.z + c[2])], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = th; so.offset = 1
    return finish(ob, bone, mat, 0)

def on_ellipsoid(c, r, x, z, front=True):
    """橢球表面上 (x, z) 那一點的 y（front＝前面那一側，y 較小）"""
    k = max(0.0, 1 - ((x - c[0]) / r[0]) ** 2 - ((z - c[2]) / r[2]) ** 2)
    return c[1] + (-1 if front else 1) * r[1] * math.sqrt(k)

# ---------- 街頭／霓虹／熔岩／黃金／暗影共用（2026-11-25） ----------
def blob(bone, mat, c, r, rot=(0, 0, 0), seg=12, ring=8, subd=1):
    """低面數的橢球（ellipsoid 是 24×14＋細分 1，一顆 1300 頂點；小零件用這個，約 1/4）"""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=ring, location=c, rotation=rot)
    ob = bpy.context.object; ob.scale = r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(ob, bone, mat, subd)

def face_lite(brow_tilt=-20, eye_tilt=-14):
    """臉：眼睛、眼睛高光、眉毛（同基本款；各系列換頭部時自己呼叫）。低面數版：原本 6 顆高面數橢球約 7,500 頂點，這個約 1,500"""
    for sx in (1, -1):
        blob('head', 'eye', (0.058 * sx, -0.158, 1.705), (0.036, 0.014, 0.03), (0, math.radians(-12 * sx), math.radians(eye_tilt * sx)), 12, 8)
        blob('head', 'eyehi', (0.050 * sx, -0.168, 1.712), (0.011, 0.005, 0.01), seg=8, ring=6, subd=0)
        blob('head', 'hair', (0.06 * sx, -0.15, 1.745), (0.04, 0.012, 0.010), (0, math.radians(brow_tilt * sx), 0), 10, 6)

def hair_lite(spikes=True):
    """頭髮：頭髮底（帽子底下露出的短髮）＋刺蝟髮尖（不細分）。spikes=False 只留頭髮底"""
    blob('head', 'hair', (0, 0.015, 1.765), (0.165, 0.17, 0.135), seg=20, ring=12)
    if not spikes: return
    for ax, ay, az in [(0, -0.07, 1.86), (0.08, -0.05, 1.85), (-0.08, -0.05, 1.85), (0.04, 0.05, 1.89), (-0.05, 0.04, 1.89), (0.12, 0.03, 1.83), (-0.12, 0.03, 1.83)]:
        base = Vector((ax * 0.6, ay * 0.4 + 0.01, 1.80)); tip = Vector((ax * 1.25, ay * 1.3, az + 0.03))
        bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=0.07, depth=(tip - base).length, location=(base + tip) / 2)
        ob = bpy.context.object; ob.rotation_mode = 'QUATERNION'
        ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(tip - base)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True); finish(ob, 'head', 'hair', 0)

def seg_field(px, pz, pts, w):
    """(px, pz) 到折線 pts（[(x, z)…]）的距離，回傳 w - 距離（>0＝在線條裡）。塗在身體上的線條紋路用"""
    best = 9.0
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        dx, dz = bx - ax, bz - az; L2 = dx * dx + dz * dz
        t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / L2))
        best = min(best, math.hypot(px - ax - t * dx, pz - az - t * dz))
    return w - best

def flame(bone, mat, base, d, r, L, bend=(0, 0, 0), n=7):
    """火舌：沿彎曲路徑由粗到尖的圓管（base 起、方向 d、長 L、bend＝尖端往哪邊彎）"""
    d = Vector(d).normalized(); base = Vector(base); bend = Vector(bend)
    pts = [tuple(base + d * (L * i / (n - 1)) + bend * ((i / (n - 1)) ** 2)) for i in range(n)]
    tp = [max(0.05, (1 - i / (n - 1)) ** 0.8) * (0.7 if i == 0 else 1) for i in range(n)]
    cu = bpy.data.curves.new('fl', 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = r; cu.bevel_resolution = 1; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(n - 1)
    for i, q in enumerate(pts): sp.points[i].co = (*q, 1); sp.points[i].radius = tp[i]
    ob = bpy.data.objects.new('fl', cu); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH'); ob = bpy.context.object
    return finish(ob, bone, mat, 0)

def rock(bone, mat, c, r, seed=1, jag=0.22):
    """不規則石塊：低面數二十面體，每個頂點往外推、往內縮一點（固定亂數，每次建都一樣）"""
    import random as _r
    rnd = _r.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(0, 0, 0))
    ob = bpy.context.object
    for v in ob.data.vertices: v.co *= 1 + jag * (rnd.random() * 2 - 1)
    for v in ob.data.vertices: v.co = Vector((v.co.x * r[0], v.co.y * r[1], v.co.z * r[2])) + Vector(c)
    ob.location = (0, 0, 0)
    bv = ob.modifiers.new('b', 'BEVEL'); bv.width = min(r) * 0.12; bv.segments = 1; bv.limit_method = 'ANGLE'
    o = finish(ob, bone, mat, 0)
    for p in o.data.polygons: p.use_smooth = False       # 石頭要看得到切面
    return o

def ring_arc(bone, mat, c, R, a0, a1, r, axis_u=(1, 0, 0), axis_v=(0, 0, 1), n=10, res=3):
    """圓弧管（c 為圓心、R 半徑，從角度 a0 到 a1，在 axis_u／axis_v 張成的平面上）"""
    u, v = Vector(axis_u).normalized(), Vector(axis_v).normalized(); c = Vector(c)
    pts = [tuple(c + u * (R * math.cos(a0 + (a1 - a0) * i / (n - 1))) + v * (R * math.sin(a0 + (a1 - a0) * i / (n - 1)))) for i in range(n)]
    return tube(bone, mat, pts, r, res=res)

_TORSO = [(0.95, 0.15, 0.10), (1.10, 0.125, 0.095), (1.30, 0.20, 0.12), (1.47, 0.085, 0.08)]   # 身體 P 的軀幹截面（z, 半寬, 半厚）
def torso_y(x, z, back=False, k=0.95):
    """軀幹表面 (x, z) 那一點的 y（前面＝負）。身體是 Skin＋細分，比節點半徑略小（k）；胸前小徽章、紋路端點用"""
    for (z0, a0, b0), (z1, a1, b1) in zip(_TORSO, _TORSO[1:]):
        if z <= z1 or z1 == _TORSO[-1][0]:
            t = max(0.0, min(1.0, (z - z0) / (z1 - z0))); rx, ry = (a0 + (a1 - a0) * t) * k, (b0 + (b1 - b0) * t) * k
            break
    return -0.005 + (1 if back else -1) * ry * math.sqrt(max(0.0, 1 - (x / rx) ** 2))

def shorts_trim(attr, field, body_band):
    """短褲系列的褲上花色：field(x, y, z, 褲管下緣 z) → 值（>0＝塗）。也在身體褲管口那段塗一份（body_band 公尺），
    短褲底下的身體從 0.72 起塗成短褲色，會露在褲管最下緣（見 docs/3d-system.md）。回傳褲管下緣高度"""
    zs = {1: min(v.co.z for v in shorts.data.vertices if v.co.x > 0), -1: min(v.co.z for v in shorts.data.vertices if v.co.x < 0)}
    a = shorts.data.attributes.new(attr, 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        a.data[i].value = field(x, y, z, zs[1 if x > 0 else -1]) if z < 1.0 else -1
    b = skinbody.data.attributes.new(attr, 'FLOAT', 'POINT')
    zc = min(zs.values())
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        b.data[i].value = field(x, y, max(z, zc), zc) if 0.7 < z < zc + body_band and abs(x) < 0.25 else -1
    return zc

def back_drape(bone, mat, rows, ph, nc=17, hem=None, th=0.012, off=1):
    """背後一片弧面（披風、披肩）：rows＝[(z, rx, ry, yc)…] 由上往下，ph＝左右張開的角度（0＝正後方）。
    hem(u)：最後一列下面再垂多少（u 0～1 從左到右），做鋸齒、扇形下緣"""
    vs, fs = [], []
    R = list(rows)
    for r, (z, rx, ry, yc) in enumerate(R):
        for c in range(nc):
            p_ = -ph + 2 * ph * c / (nc - 1)
            vs.append((rx * math.sin(p_), yc + ry * math.cos(p_), z))
    if hem:
        z, rx, ry, yc = R[-1]
        for c in range(nc):
            u = c / (nc - 1); p_ = -ph + 2 * ph * u; dz, fl = hem(u)
            vs.append(((rx + fl) * math.sin(p_), yc + (ry + fl) * math.cos(p_), z - dz))
    n = len(vs) // nc
    for r in range(n - 1):
        for c in range(nc - 1):
            a = r * nc + c; fs.append((a, a + 1, a + 1 + nc, a + nc))
    return panel(bone, mat, vs, fs, th, 0, off)
