"""換裝總覽圖：讀 export_app.py full 模式存的 hero_app.blend ＋ Workout/Hero3D 的換裝貼圖，
身體、衣服網格用節點照 Toon.metal 的 outfitSurface 算（上衣圖 → 下身圖 → 皮膚，兩階明暗），其他零件用原本的卡通材質。
blender -b out/app_squat/hero_app.blend -P scripts/blender/outfit_review.py -- <輸出資料夾> [上衣:下身,…]
每組兩格：站姿正面 3/4、蹲到底背面 3/4（看腰部有沒有露縫）。WAIST=1：腰部特寫。輸出 cells/*.png、spec.json（給 compose.py），另存一份灰階格子。
"""
import bpy, json, os, sys, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:]
OUT = argv[0]
HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.normpath(os.path.join(HERE, '..', '..', 'Workout', 'Hero3D'))
info = json.load(open(os.path.join(TEX, 'hero3d.json'), encoding='utf-8'))
O = info['outfits']
combos = [(s, s) for s in O['top']]
if len(argv) > 1:
    combos += [tuple(c.split(':')) for c in argv[1].split(',')]
os.makedirs(os.path.join(OUT, 'cells'), exist_ok=True)
sc = bpy.context.scene
rig = bpy.data.objects['rig']
SKIN = (0.5, 0.53, 0.58)

# ---------- 換裝材質（節點版 outfitSurface） ----------
_imgs = {}
def img(name, color):
    k = (name, color)
    if k not in _imgs:
        im = bpy.data.images.load(os.path.join(TEX, name + '.png'), check_existing=False)
        im.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
        _imgs[k] = im
    return _imgs[k]

def outfit_mat(mat, layers):
    """layers：由上到下的貼圖名（上衣、下身），都沒蓋住就是皮膚"""
    mat.use_nodes = True
    nt = mat.node_tree; nt.nodes.clear(); N = nt.nodes.new; L = nt.links.new
    uvn = N('ShaderNodeUVMap'); uvn.uv_map = 'st'
    sep = N('ShaderNodeSeparateXYZ'); L(uvn.outputs[0], sep.inputs[0])
    hu = N('ShaderNodeMath'); hu.operation = 'MULTIPLY'; hu.inputs[1].default_value = 0.5; L(sep.outputs[0], hu.inputs[0])
    hm = N('ShaderNodeMath'); hm.operation = 'ADD'; hm.inputs[1].default_value = 0.5; L(hu.outputs[0], hm.inputs[0])
    cc = N('ShaderNodeCombineXYZ'); L(hu.outputs[0], cc.inputs[0]); L(sep.outputs[1], cc.inputs[1])
    cm = N('ShaderNodeCombineXYZ'); L(hm.outputs[0], cm.inputs[0]); L(sep.outputs[1], cm.inputs[1])
    col = N('ShaderNodeRGB'); col.outputs[0].default_value = (*SKIN, 1); col_o = col.outputs[0]
    sh = N('ShaderNodeValue'); sh.outputs[0].default_value = 0.55; sh_o = sh.outputs[0]
    for name in reversed(layers):           # 下層先，上層蓋上去
        tc = N('ShaderNodeTexImage'); tc.image = img(name, True); tc.interpolation = 'Linear'; tc.extension = 'EXTEND'; L(cc.outputs[0], tc.inputs[0])
        tm = N('ShaderNodeTexImage'); tm.image = img(name, False); tm.interpolation = 'Linear'; tm.extension = 'EXTEND'; L(cm.outputs[0], tm.inputs[0])
        sp = N('ShaderNodeSeparateColor'); L(tm.outputs[0], sp.inputs[0])
        gt = N('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.5; L(sp.outputs[0], gt.inputs[0])
        mx = N('ShaderNodeMix'); mx.data_type = 'RGBA'; L(gt.outputs[0], mx.inputs[0]); L(col_o, mx.inputs[6]); L(tc.outputs[0], mx.inputs[7])
        ms = N('ShaderNodeMix'); ms.data_type = 'FLOAT'; L(gt.outputs[0], ms.inputs[0]); L(sh_o, ms.inputs[2]); L(sp.outputs[1], ms.inputs[3])
        col_o, sh_o = mx.outputs[2], ms.outputs[0]
    # 明暗：ShaderToRGB 亮度 < 0.18 暗面（色×倍率）、> 0.75 亮面（色×1.18+0.06），中間原色
    dif = N('ShaderNodeBsdfDiffuse'); s2r = N('ShaderNodeShaderToRGB'); L(dif.outputs[0], s2r.inputs[0])
    bw = N('ShaderNodeRGBToBW'); L(s2r.outputs[0], bw.inputs[0])
    l1 = N('ShaderNodeMath'); l1.operation = 'GREATER_THAN'; l1.inputs[1].default_value = 0.18; L(bw.outputs[0], l1.inputs[0])
    l2 = N('ShaderNodeMath'); l2.operation = 'GREATER_THAN'; l2.inputs[1].default_value = 0.75; L(bw.outputs[0], l2.inputs[0])
    dk = N('ShaderNodeVectorMath'); dk.operation = 'SCALE'; L(col_o, dk.inputs[0]); L(sh_o, dk.inputs['Scale'])
    hi = N('ShaderNodeVectorMath'); hi.operation = 'MULTIPLY_ADD'; L(col_o, hi.inputs[0]); hi.inputs[1].default_value = (1.18,) * 3; hi.inputs[2].default_value = (0.06,) * 3
    m1 = N('ShaderNodeMix'); m1.data_type = 'RGBA'; L(l1.outputs[0], m1.inputs[0]); L(dk.outputs[0], m1.inputs[6]); L(col_o, m1.inputs[7])
    m2 = N('ShaderNodeMix'); m2.data_type = 'RGBA'; L(l2.outputs[0], m2.inputs[0]); L(m1.outputs[2], m2.inputs[6]); L(hi.outputs[0], m2.inputs[7])
    em = N('ShaderNodeEmission'); L(m2.outputs[2], em.inputs[0])
    out = N('ShaderNodeOutputMaterial'); L(em.outputs[0], out.inputs[0])

# ---------- 舞台 ----------
sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 8
sc.view_settings.view_transform = 'Standard'
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.02, 0.025, 0.05, 1)
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35)); sun.data.energy = 3
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'; cam.data.ortho_scale = 2.15
sc.render.resolution_x, sc.render.resolution_y = 220, 320
WAIST = os.environ.get('WAIST') == '1'    # 腰部特寫（檢查混搭露縫）
if WAIST: cam.data.ortho_scale = 0.75; sc.render.resolution_x = sc.render.resolution_y = 300
def aim(loc, tgt=(0, 0, 0.93)):
    cam.location = loc; cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()

meshes = [o for o in sc.objects if o.type == 'MESH']
mid = sc.frame_start + (sc.frame_end - sc.frame_start) // 2
CLOTH = {'suit': 'top_suit', 'long': 'bottom_long', 'short': 'bottom_short'}
cells = []
for top, bot in combos:
    t, b = O['top'][top], O['bottom'][bot]
    on = {'base', 'head_basic', 'hands_basic', 'feet_basic', 'bell_basic'}
    for e in (t, b):
        if e.get('part'): on.add(e['part'])
        if e.get('mesh'): on.add(CLOTH[e['mesh']])
    for o in meshes:
        o.hide_render = o.name.split('__')[0] not in on
    outfit_mat(bpy.data.materials['body'], [t['body'], b['body']])
    for e in (t, b):
        if e.get('mesh'): outfit_mat(bpy.data.materials['cloth_' + e['mesh']], [e['cloth']])
    for tag, f, loc in (('stand', sc.frame_start, (2.0, -3.4, 1.25)), ('squat', mid, (-2.4, 3.0, 1.5))):
        sc.frame_set(f)
        p = os.path.join(OUT, 'cells', f'{top}-{bot}-{tag}.png')
        # 腰部特寫：攝影機對準這格的 hips 骨頭（蹲下時髖部降到 0.55～0.65）
        tgt = rig.matrix_world @ rig.pose.bones['hips'].head + Vector((0, 0, 0.04)) if WAIST else Vector((0, 0, 0.93))
        aim(Vector(loc) + tgt - Vector((0, 0, 0.93)), tgt); sc.render.filepath = p; bpy.ops.render.render(write_still=True)
        cells.append((top, bot, tag, p))

# 灰階版（美術規定：灰階也認得出）
for top, bot, tag, p in cells:
    im = bpy.data.images.load(p); px = list(im.pixels)
    for i in range(0, len(px), 4):
        y = 0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]; px[i] = px[i + 1] = px[i + 2] = y
    im.pixels = px; im.filepath_raw = p.replace('.png', '_g.png'); im.file_format = 'PNG'; im.save()

NAME = {'basic': '基本', 'frost': '冰霜', 'titan': '鈦甲', 'pig': '小豬', 'night': '暗夜', 'dawn': '曙光', 'rune': '符文', 'astral': '星界'}
for gray in (False, True):
    W, CW, CH = 0, sc.render.resolution_x, sc.render.resolution_y
    items = []; x = 0
    for i in range(0, len(cells), 2):
        top, bot = cells[i][0], cells[i][1]
        for j in range(2):
            pth = cells[i + j][3]
            items.append({'type': 'image', 'path': pth.replace('.png', '_g.png') if gray else pth, 'x': x + j * CW, 'y': 40, 'w': CW})
        items.append({'type': 'text', 'text': f'上 {NAME.get(top, top)}／下 {NAME.get(bot, bot)}', 'x': x + CW, 'y': 8, 'size': 22, 'color': [1, 1, 1], 'align': 'center'})
        x += 2 * CW + 12
    spec = {'out': os.path.join(OUT, 'outfits_gray.png' if gray else 'outfits.png'), 'w': x, 'h': CH + 44, 'bg': [0.09, 0.1, 0.14], 'items': items}
    json.dump(spec, open(os.path.join(OUT, 'spec_gray.json' if gray else 'spec.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print('cells', len(cells))
