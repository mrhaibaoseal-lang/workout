"""原型：程序化 3D 角色（玩具公仔風）+ 骨架 + 啞鈴深蹲動畫，EEVEE 卡通著色。
GEAR=titan xvfb-run -a blender -b -P hero_proto.py -- <outdir> [frames...]
GEAR：basic（示範用）、titan（整套，不含特效）、或逐部位混搭，例如 GEAR="head=titan,hands=titan"
部位：head top bottom feet hands back bell fx（沒寫的部位用基本款）"""
import bpy, bmesh, math, sys, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '/tmp/out'
FRAMES = [int(a) for a in argv[1:]]
GEAR = os.environ.get('GEAR', 'basic')
SLOTS = ('head', 'top', 'bottom', 'feet', 'hands', 'back', 'bell', 'fx')
G = {k: 'basic' for k in SLOTS}
if GEAR in ('titan',):
    G.update({k: GEAR for k in SLOTS if k != 'fx'})
elif '=' in GEAR:
    for kv in GEAR.split(','):
        k, v = kv.split('='); assert k in SLOTS, k; G[k] = v
if os.environ.get('MOVE', 'squat') != 'squat':
    G['bell'] = 'none'          # 伏地挺身、下拉不拿啞鈴
# 背靠靠背、躺在椅子上的動作：背部裝備（披風、背包）一定會卡進椅背 → 示範時隱藏
if os.environ.get('MOVE', 'squat') in ('pulldown',):
    G['back'] = 'none'
TOP, BOT = G['top'] == 'titan', G['bottom'] == 'titan'
def hexc(h):
    h = h.lstrip('#'); return tuple(((int(h[i:i + 2], 16) / 255 + 0.055) / 1.055) ** 2.4 for i in (0, 2, 4))
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---------- 材質：卡通兩階 + 色帶 ----------
def toon(name, color, shade=0.55, spec=False, alt=None, alt_attr=None, alt_shade=None):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    dif = nt.nodes.new('ShaderNodeBsdfDiffuse')
    s2r = nt.nodes.new('ShaderNodeShaderToRGB')
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    r = ramp.color_ramp; r.interpolation = 'CONSTANT'
    r.elements[0].position = 0.0; r.elements[0].color = (*[c * shade for c in color], 1)
    r.elements[1].position = 0.18; r.elements[1].color = (*color, 1)
    e = r.elements.new(0.75); e.color = (*[min(1, c * 1.18 + 0.06) for c in color], 1)
    em = nt.nodes.new('ShaderNodeEmission'); em.inputs['Strength'].default_value = 1.0
    nt.links.new(dif.outputs[0], s2r.inputs[0])
    nt.links.new(s2r.outputs['Color'], ramp.inputs[0])
    if alt:
        ramp2 = nt.nodes.new('ShaderNodeValToRGB'); r2 = ramp2.color_ramp; r2.interpolation = 'CONSTANT'
        sh2 = alt_shade or shade
        r2.elements[0].position = 0.0; r2.elements[0].color = (*[c * sh2 for c in alt], 1)
        r2.elements[1].position = 0.18; r2.elements[1].color = (*alt, 1)
        e2 = r2.elements.new(0.75); e2.color = (*[min(1, c * 1.18 + 0.06) for c in alt], 1)
        nt.links.new(s2r.outputs['Color'], ramp2.inputs[0])
        at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = alt_attr
        gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.0
        nt.links.new(at.outputs['Fac'], gt.inputs[0])
        mx = nt.nodes.new('ShaderNodeMixRGB')
        nt.links.new(gt.outputs[0], mx.inputs['Fac']); nt.links.new(ramp.outputs['Color'], mx.inputs['Color1']); nt.links.new(ramp2.outputs['Color'], mx.inputs['Color2'])
        nt.links.new(mx.outputs['Color'], em.inputs['Color'])
    else:
        nt.links.new(ramp.outputs['Color'], em.inputs['Color'])
    # 邊緣光（Fresnel）
    fr = nt.nodes.new('ShaderNodeLayerWeight'); fr.inputs['Blend'].default_value = 0.25
    rr = nt.nodes.new('ShaderNodeValToRGB'); rr.color_ramp.interpolation = 'CONSTANT'
    rr.color_ramp.elements[1].position = 0.62
    rr.color_ramp.elements[0].color = (0, 0, 0, 1); rr.color_ramp.elements[1].color = (0.55, 0.75, 1.0, 1)
    nt.links.new(fr.outputs['Facing'], rr.inputs[0])
    add = nt.nodes.new('ShaderNodeEmission'); add.inputs['Strength'].default_value = 0.6
    nt.links.new(rr.outputs['Color'], add.inputs['Color'])
    mix = nt.nodes.new('ShaderNodeAddShader')
    nt.links.new(em.outputs[0], mix.inputs[0]); nt.links.new(add.outputs[0], mix.inputs[1])
    last = mix
    if spec:  # 金屬：一塊硬邊高光
        gl = nt.nodes.new('ShaderNodeBsdfGlossy'); gl.inputs['Roughness'].default_value = 0.25
        g2 = nt.nodes.new('ShaderNodeShaderToRGB'); gr = nt.nodes.new('ShaderNodeValToRGB')
        gr.color_ramp.interpolation = 'CONSTANT'; gr.color_ramp.elements[1].position = 0.55
        gr.color_ramp.elements[0].color = (0, 0, 0, 1); gr.color_ramp.elements[1].color = (1, 1, 1, 1)
        ge = nt.nodes.new('ShaderNodeEmission'); ge.inputs['Strength'].default_value = 0.7
        nt.links.new(gl.outputs[0], g2.inputs[0]); nt.links.new(g2.outputs['Color'], gr.inputs[0]); nt.links.new(gr.outputs['Color'], ge.inputs['Color'])
        a2 = nt.nodes.new('ShaderNodeAddShader'); nt.links.new(mix.outputs[0], a2.inputs[0]); nt.links.new(ge.outputs[0], a2.inputs[1]); last = a2
    nt.links.new(last.outputs[0], out.inputs[0])
    return m

def flat(name, color, strength=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = (*color, 1); em.inputs['Strength'].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0]); return m

M = {
    'skin': toon('skin', (0.50, 0.53, 0.58)),
    'shirt': toon('shirt', hexc('#FF6B35'), 0.62),   # 品牌橘背心
    'shorts': toon('shorts', hexc('#1F2A44'), 0.6),  # 深藍灰短褲
    'shoe': toon('shoe', (0.92, 0.92, 0.95)),
    'sole': toon('sole', (0.95, 0.38, 0.14)),
    'hair': toon('hair', (0.08, 0.08, 0.10)),
    'iron': toon('iron', (0.16, 0.17, 0.20)),
    'grip': toon('grip', (0.62, 0.64, 0.68)),
    'eye': flat('eye', (0.02, 0.02, 0.03)),
    'eyehi': flat('eyehi', (1, 1, 1), 1.5),
    'band': toon('band', hexc('#1F2A44'), 0.6),
    # 鈦甲 c1 #8C98A8／c2 #31F2D4／c3 #2A3340
    'ti': toon('ti', hexc('#B4BFCC'), 0.5, spec=True),
    'tidk': toon('tidk', hexc('#5A6676'), 0.5, spec=True),
    'tisuit': toon('tisuit', hexc('#2A3340'), 0.6),
    'glow': flat('glow', hexc('#31F2D4'), 3.0),
    'flame': flat('flame', hexc('#BFFFF4'), 5.0),
}
M['skintank'] = toon('skintank', (0.50, 0.53, 0.58), alt=hexc('#FF6B35'), alt_attr='tank', alt_shade=0.62)
if TOP: M['shirt'] = M['tisuit']
if BOT: M['shorts'] = M['tisuit']
OUTLINE = flat('outline', (0.01, 0.01, 0.02))
OUTLINE.use_backface_culling = True
MAT_ORDER = list(M.keys())

# ---------- 造型工具 ----------
parts = []
def finish(ob, bone, mat, subd=2):
    if subd:
        mod = ob.modifiers.new('s', 'SUBSURF'); mod.levels = subd; mod.render_levels = subd
    bpy.context.view_layer.objects.active = ob
    for md in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    ob.data.materials.append(M[mat])
    vg = ob.vertex_groups.new(name=bone); vg.add(range(len(ob.data.vertices)), 1.0, 'REPLACE')
    for p in ob.data.polygons: p.use_smooth = True
    parts.append(ob); return ob

def ellipsoid(bone, mat, c, r, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, location=c, rotation=rot)
    ob = bpy.context.object; ob.scale = r
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(ob, bone, mat, 1)

def box(bone, mat, c, s, rot=(0, 0, 0), subd=2):
    bpy.ops.mesh.primitive_cube_add(location=c, rotation=rot); ob = bpy.context.object
    ob.scale = s; bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return finish(ob, bone, mat, subd)

def limb(bone, mat, a, b, ra, rb):
    """兩端不同粗細的膠囊（錐形）"""
    a, b = Vector(a), Vector(b); d = b - a; L = d.length
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=1, depth=L, location=(a + b) / 2)
    ob = bpy.context.object
    for v in ob.data.vertices:
        t = (v.co.z / L) + 0.5; rr = ra + (rb - ra) * t
        v.co.x *= rr; v.co.y *= rr
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ob2 = finish(ob, bone, mat, 2)
    # 兩端加球蓋關節
    ellipsoid(bone, mat, a, (ra * 1.0,) * 3); ellipsoid(bone, mat, b, (rb * 1.0,) * 3)
    return ob2

def custom_box(bone, mat, verts, subd=2):
    me = bpy.data.meshes.new('cb'); faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(verts, [], faces); ob = bpy.data.objects.new('cb', me)
    sc.collection.objects.link(ob); bpy.context.view_layer.objects.active = ob
    for o in sc.objects: o.select_set(False)
    ob.select_set(True)
    return finish(ob, bone, mat, subd)

def trap(z0, z1, w0, d0, w1, d1, y0=0, y1=0):
    return [(-w0, -d0 + y0, z0), (w0, -d0 + y0, z0), (w0, d0 + y0, z0), (-w0, d0 + y0, z0),
            (-w1, -d1 + y1, z1), (w1, -d1 + y1, z1), (w1, d1 + y1, z1), (-w1, d1 + y1, z1)]

# ---------- 骨架 ----------
J = {  # 關節位置（面向 -Y，+X 是角色左邊）
    'hip': (0, 0, 0.98), 'waist': (0, 0, 1.12), 'neck': (0, 0, 1.50), 'top': (0, 0, 1.92),
}
BONES = [  # name, head, tail, parent
    ('hips', (0, 0, 0.98), (0, 0, 1.12), None),
    ('chest', (0, 0, 1.12), (0, 0, 1.50), 'hips'),
    ('head', (0, 0, 1.52), (0, 0, 1.90), 'chest'),
]
for s, sx in (('L', 1), ('R', -1)):
    BONES += [
        (f'upper_arm.{s}', (0.27 * sx, 0, 1.42), (0.33 * sx, 0.0, 1.14), 'chest'),
        (f'forearm.{s}', (0.33 * sx, 0.0, 1.14), (0.35 * sx, -0.02, 0.90), f'upper_arm.{s}'),
        (f'hand.{s}', (0.35 * sx, -0.02, 0.90), (0.355 * sx, -0.02, 0.80), f'forearm.{s}'),
        (f'thigh.{s}', (0.11 * sx, 0, 0.94), (0.12 * sx, -0.01, 0.52), 'hips'),
        (f'shin.{s}', (0.12 * sx, -0.01, 0.52), (0.12 * sx, 0.01, 0.11), f'thigh.{s}'),
        (f'foot.{s}', (0.12 * sx, 0.01, 0.11), (0.12 * sx, -0.13, 0.04), None),
    ]
arm_data = bpy.data.armatures.new('rig'); rig = bpy.data.objects.new('rig', arm_data)
sc.collection.objects.link(rig); bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')
for n, h, t, p in BONES:
    b = arm_data.edit_bones.new(n); b.head = h; b.tail = t
    yv = (Vector(t) - Vector(h)).normalized(); b.align_roll(Vector((1, 0, 0)).cross(yv))
    if p: b.parent = arm_data.edit_bones[p]; b.use_connect = (Vector(arm_data.edit_bones[p].tail) - Vector(h)).length < 1e-4 and not n.startswith(('upper', 'thigh'))
bpy.ops.object.mode_set(mode='OBJECT')
B = {n: (Vector(h), Vector(t)) for n, h, t, _ in BONES}

# ---------- 身體：Skin modifier 連續網格 ----------
def skinmesh(name, mat, pts, edges, scale=1.0, lv=2):
    me = bpy.data.meshes.new(name); me.from_pydata([p[0] for p in pts], edges, [])
    ob = bpy.data.objects.new(name, me); sc.collection.objects.link(ob)
    ob.modifiers.new('sk', 'SKIN')
    for i, p in enumerate(pts):
        r = p[1]; ob.data.skin_vertices[0].data[i].radius = (r[0] * scale, r[1] * scale)
    ob.data.skin_vertices[0].data[0].use_root = True
    sub = ob.modifiers.new('s', 'SUBSURF'); sub.levels = sub.render_levels = lv
    bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    for md in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
    ob.data.materials.append(M[mat])
    for p in ob.data.polygons: p.use_smooth = True
    return ob
P = [((0, 0, 0.95), (0.15, 0.10)), ((0, 0, 1.10), (0.125, 0.095)), ((0, -0.005, 1.30), (0.20, 0.12)),
     ((0, 0, 1.47), (0.085, 0.08)), ((0, 0, 1.56), (0.06, 0.06))]
E = [(0, 1), (1, 2), (2, 3), (3, 4)]
def addchain(chain, start):
    prev = start
    for c in chain:
        P.append(c); E.append((prev, len(P) - 1)); prev = len(P) - 1
for sx in (1, -1):
    addchain([((0.23 * sx, 0, 1.42), (0.09, 0.085)), ((0.28 * sx, -0.005, 1.29), (0.068, 0.066)),
              ((0.33 * sx, 0, 1.14), (0.052, 0.05)), ((0.34 * sx, -0.01, 1.04), (0.056, 0.05)),
              ((0.35 * sx, -0.02, 0.91), (0.04, 0.035))], 2)
    addchain([((0.11 * sx, 0, 0.92), (0.10, 0.10)), ((0.118 * sx, -0.01, 0.74), (0.095, 0.092)),
              ((0.12 * sx, -0.01, 0.52), (0.062, 0.062)), ((0.12 * sx, 0.005, 0.38), (0.068, 0.066)),
              ((0.12 * sx, 0.01, 0.12), (0.042, 0.042))], 0)
skinbody = skinmesh('skin', 'skin', P, E, lv=3)   # 細一級：背心是塗色，邊緣才不會鋸齒
# 衣服底下的身體直接塗成衣服色：彎曲時就算皮膚穿出來也看不到
skinbody.data.materials.append(M['shirt']); skinbody.data.materials.append(M['shorts'])
for f_ in skinbody.data.polygons:
    c = f_.center; ax = abs(c.x)
    if TOP and 1.0 < c.z < 1.50 and (ax < 0.2 or c.z > 0.92):
        f_.material_index = 1
    elif c.z <= (1.0 if TOP else 1.03) and c.z > (0.12 if BOT else 0.72):
        f_.material_index = 2
if not TOP:
    # 基本款背心：每個頂點存「在背心裡面多深」（公尺，>0＝背心）。著色器在面中間內插再判斷 >0，
    # 邊界是平滑的線，不會像整面塗色那樣鋸齒。之後 App 的即時著色器也用同一個屬性。
    def tank_field(x, z):
        ax = abs(x)
        body = min(z - 1.03, 1.44 - z, 0.19 - ax)                    # 軀幹
        strap = min(z - 1.40, 1.56 - z, ax - 0.075, 0.165 - ax)       # 肩帶
        return max(body, strap)
    at = skinbody.data.attributes.new('tank', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices): at.data[i].value = tank_field(v.co.x, v.co.z)
    skinbody.data.materials[0] = M['skintank']
# 上衣：基本款是貼身背心（只有肩帶），鈦甲是全身緊身衣。
# 基本款的背心最後會刪掉（改成身體塗色，見下方）；這裡照樣建，因為衣服權重轉移的流程共用。
SP = [((0, 0, 1.03), (0.135, 0.10)), ((0, -0.005, 1.30), (0.205, 0.125)), ((0, 0, 1.46), (0.10, 0.09))]
SE = [(0, 1), (1, 2)]
for sx in (1, -1):
    if not TOP:
        SP += [((0.15 * sx, -0.005, 1.47), (0.045, 0.07))]; SE += [(1, len(SP) - 1)]
        continue
    SP += [((0.23 * sx, 0, 1.42), (0.095, 0.09)), ((0.28 * sx, -0.005, 1.30), (0.075, 0.073))]
    SE += [(1, len(SP) - 2), (len(SP) - 2, len(SP) - 1)]
    SP += [((0.33 * sx, 0, 1.14), (0.058, 0.056)), ((0.35 * sx, -0.02, 0.93), (0.046, 0.042))]
    SE += [(len(SP) - 3, len(SP) - 2), (len(SP) - 2, len(SP) - 1)]
shirt = skinmesh('shirt', 'shirt', SP, SE, 1.08 if TOP else 1.06)
HP = [((0, 0, 0.95), (0.155, 0.105)), ((0, 0, 1.07), (0.135, 0.10))]
HE = [(0, 1)]
for sx in (1, -1):
    HP += [((0.11 * sx, 0, 0.92), (0.105, 0.105)), ((0.118 * sx, -0.01, 0.75), (0.10, 0.098))]
    HE += [(0, len(HP) - 2), (len(HP) - 2, len(HP) - 1)]
    if BOT:
        HP += [((0.12 * sx, -0.01, 0.52), (0.066, 0.066)), ((0.12 * sx, 0.005, 0.38), (0.071, 0.069)), ((0.12 * sx, 0.01, 0.14), (0.048, 0.048))]
        HE += [(len(HP) - 4, len(HP) - 3), (len(HP) - 3, len(HP) - 2), (len(HP) - 2, len(HP) - 1)]
shorts = skinmesh('shorts', 'shorts', HP, HE, 1.08 if BOT else 1.15)
bpy.ops.object.select_all(action='DESELECT')
skinbody.select_set(True)
rig.select_set(True); bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
skinbody.parent = None; skinbody.modifiers.clear()
# 自動權重會讓手臂影響一路延伸到胸口中央，舉手時胸口皮膚會戳穿背心。
# 軀幹範圍（|x|<0.20）的手臂權重全部改給胸部；0.20～0.27 之間漸變，肩關節外側才完全跟手臂。
_ARMG = [f'{b}.{s}' for b in ('upper_arm', 'forearm', 'hand') for s in ('L', 'R')]
_cg = skinbody.vertex_groups['chest']
for v in skinbody.data.vertices:
    if not (1.0 < v.co.z < 1.5): continue
    k = min(max((abs(v.co.x) - 0.235) / 0.055, 0.0), 1.0)      # 0＝全給胸部、1＝不動
    if k >= 1: continue
    moved = 0.0
    for g in list(v.groups):
        n = skinbody.vertex_groups[g.group].name
        if n in _ARMG:
            nw = g.weight * k; moved += g.weight - nw
            if nw > 0: skinbody.vertex_groups[n].add([v.index], nw, 'REPLACE')
            else: skinbody.vertex_groups[n].remove([v.index])
    if moved: _cg.add([v.index], moved, 'ADD')
for o in (shirt, shorts):  # 衣服沿用身體的權重，彎曲時才不會穿模
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
    dt = o.modifiers.new('dt', 'DATA_TRANSFER'); dt.object = skinbody; dt.use_vert_data = True
    dt.data_types_verts = {'VGROUP_WEIGHTS'}; dt.vert_mapping = 'POLYINTERP_NEAREST'
    bpy.ops.object.datalayout_transfer(modifier='dt'); bpy.ops.object.modifier_apply(modifier='dt')
ARMG = [f'{b}.{s}' for b in ('upper_arm', 'forearm', 'hand') for s in ('L', 'R')]
def arm_w(ob, vi):
    w = 0.0
    for g in ob.data.vertices[vi].groups:
        if ob.vertex_groups[g.group].name in ARMG: w += g.weight
    return w
if not TOP:
    # 基本款背心不另外做網格：直接把身體軀幹塗成背心色（上面的塗色）。只有一層表面，不會穿模，
    # 輪廓就是身體本身的平直倒三角（使用者選定的身型）。
    bpy.data.objects.remove(shirt)
for o in ((skinbody, shirt, shorts) if TOP else (skinbody, shorts)): parts.append(o)
# 頭
H = (0, -0.01, 1.70)
# 頭：一顆蛋形（下半部收窄成下巴，不另外加零件）
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=H)
_h = bpy.context.object; _h.scale = (0.152, 0.162, 0.182); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for v in _h.data.vertices:
    if v.co.z < 0:
        k = 1 - 0.28 * (-v.co.z / 0.182) ** 1.5; v.co.x *= k; v.co.y *= k
        v.co.y -= 0.025 * (-v.co.z / 0.182)   # 下巴略往前
finish(_h, 'head', 'skin', 1)
# 刺蝟短髮：幾束尖錐
bpy.ops.object.select_all(action='DESELECT')
def base_head():
  pass
  ellipsoid('head', 'hair', (0, 0.015, 1.765), (0.165, 0.17, 0.135))
  for i, (ax, ay, az) in enumerate([(0, -0.07, 1.86), (0.08, -0.05, 1.85), (-0.08, -0.05, 1.85), (0.04, 0.05, 1.89), (-0.05, 0.04, 1.89), (0.12, 0.03, 1.83), (-0.12, 0.03, 1.83)]):
      base = Vector((ax * 0.6, ay * 0.4 + 0.01, 1.80)); tip = Vector((ax * 1.25, ay * 1.3, az + 0.03))
      bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.07, depth=(tip - base).length, location=(base + tip) / 2)
      ob = bpy.context.object; ob.rotation_mode = 'QUATERNION'
      ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(tip - base)
      bpy.ops.object.transform_apply(location=False, rotation=True, scale=True); finish(ob, 'head', 'hair', 1)
  # 頭帶
  bpy.ops.mesh.primitive_torus_add(major_radius=0.162, minor_radius=0.018, location=(0, -0.005, 1.77), rotation=(math.radians(-8), 0, 0))
  finish(bpy.context.object, 'head', 'band', 1)
  # 眼睛：專注的斜眼
  for sx in (1, -1):
      ellipsoid('head', 'eye', (0.058 * sx, -0.158, 1.705), (0.036, 0.014, 0.03), (0, math.radians(-12 * sx), math.radians(-14 * sx)))
      ellipsoid('head', 'eyehi', (0.050 * sx, -0.168, 1.712), (0.011, 0.005, 0.01))
      ellipsoid('head', 'hair', (0.06 * sx, -0.15, 1.745), (0.04, 0.012, 0.010), (0, math.radians(-20 * sx), 0))  # 眉毛
if G['head'] == 'basic': base_head()
for s, sx in (('L', 1), ('R', -1)):
    ua, fa, ha = B[f'upper_arm.{s}'], B[f'forearm.{s}'], B[f'hand.{s}']
    th, sh, ft = B[f'thigh.{s}'], B[f'shin.{s}'], B[f'foot.{s}']
    hc = ha[0] + Vector((0, 0, -0.07))
    if G['hands'] == 'basic':
        box(f'hand.{s}', 'skin', ha[0] + Vector((0, 0, -0.065)), (0.042, 0.06, 0.055))
        # 護腕
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.056, depth=0.06, location=fa[1] + (fa[0] - fa[1]) * 0.18)
        finish(bpy.context.object, f'forearm.{s}', 'band', 1)
    if G['feet'] == 'basic':
        # 球鞋：鞋身 + 鞋底 + 鞋舌
        box(f'foot.{s}', 'shoe', (0.12 * sx, -0.06, 0.075), (0.065, 0.13, 0.055))
        box(f'foot.{s}', 'sole', (0.12 * sx, -0.06, 0.02), (0.07, 0.14, 0.02), subd=1)
        box(f'foot.{s}', 'shoe', (0.12 * sx, -0.02, 0.13), (0.05, 0.06, 0.04))
    if G['bell'] == 'basic':
        # 啞鈴（握把沿 Y 軸，兩頭各兩片槓片）
        hc = ha[0] + Vector((0, 0, -0.07))
        bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.018, depth=0.30, location=hc, rotation=(math.radians(90), 0, 0))
        finish(bpy.context.object, f'hand.{s}', 'grip', 0)
        for dy, rr, dp in ((0.10, 0.085, 0.035), (0.135, 0.07, 0.03), (-0.10, 0.085, 0.035), (-0.135, 0.07, 0.03)):
            bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=rr, depth=dp, location=hc + Vector((0, dy, 0)), rotation=(math.radians(90), 0, 0))
            ob = bpy.context.object; bev = ob.modifiers.new('b', 'BEVEL'); bev.width = 0.008; bev.segments = 2
            finish(ob, f'hand.{s}', 'iron', 0)


if 'titan' in G.values():
    exec(open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[sys.argv.index('-P') + 1])), 'gear_titan.py')).read())

# 合併成一個蒙皮網格
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join(); body = bpy.context.object; body.name = 'hero'
body.data.materials.append(OUTLINE)
am = body.modifiers.new('rig', 'ARMATURE'); am.object = rig
body.parent = rig
sol = body.modifiers.new('outline', 'SOLIDIFY'); sol.thickness = -0.014; sol.use_flip_normals = True
sol.material_offset = len(body.data.materials) - 1; sol.use_rim = False

# ---------- 動畫：見 moves3d.py（MOVE=squat｜pushup｜pulldown） ----------
exec(open(os.path.join(os.path.dirname(os.path.abspath(sys.argv[sys.argv.index('-P') + 1])), 'moves3d.py')).read())

# ---------- 舞台、燈光、相機 ----------
sc.render.engine = 'BLENDER_EEVEE'
QUICK = os.environ.get('QUICK') == '1'   # 草稿模式：檢查用，快 4～6 倍
sc.eevee.taa_render_samples = 4 if QUICK else 16
sc.render.film_transparent = False
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.02, 0.025, 0.05, 1)
# 地板圓台 + 光圈
bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=CAM['stage'][2], depth=0.06, location=(CAM['stage'][0], CAM['stage'][1], -0.03))
bpy.context.object.data.materials.append(toon('stage', (0.08, 0.10, 0.18)))
bpy.ops.mesh.primitive_torus_add(major_radius=CAM['stage'][2], minor_radius=0.012, location=(CAM['stage'][0], CAM['stage'][1], 0.0))
bpy.context.object.data.materials.append(flat('ring', (1.0, 0.55, 0.2), 4))
sc.eevee.use_bloom = True; sc.eevee.bloom_intensity = 0.08
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(-25), math.radians(-35)); sun.data.energy = 3
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = CAM['lens']
cam.location = CAM['loc']
dirv = Vector(CAM['tgt']) - cam.location
cam.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
sc.render.resolution_x = sc.render.resolution_y = 360 if QUICK else 600
sc.view_settings.view_transform = 'Standard'

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, 'hero.blend'))
for f in FRAMES or [0, 24]:
    sc.frame_set(f); sc.render.filepath = os.path.join(OUT, f'f{f:02d}.png')
    bpy.ops.render.render(write_still=True)
