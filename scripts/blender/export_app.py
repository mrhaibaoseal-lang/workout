# 給 App（RealityKit）用的匯出：hero.blend → USDZ（骨架＋動畫）＋ 材質表 JSON ＋ 動作 JSON。
#   blender -b <輸出>/hero.blend -P scripts/blender/export_app.py -- <目標資料夾> <動作名> [full|clip]
# full：所有零件（用 EXPORT=frost,titan 建出來的 hero.blend），App 逐件開關；clip：只取動作，不輸出模型。
# 拆法：hero 網格依「零件(part 面屬性) × 材質」拆成獨立網格，名稱 <部位>_<系列>__<材質>；描邊外殼烘成 <零件>__ol。
# 卡通著色不靠 USD 材質（RealityKit 不認 Blender 節點），App 依名稱查 materials.json 用自己的 Metal 著色器。
import bpy, bmesh, json, os, sys
from mathutils import Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
DST, MOVE = argv[0], argv[1]
MODE = argv[2] if len(argv) > 2 else 'full'
os.makedirs(DST, exist_ok=True)
sc = bpy.context.scene
hero = bpy.data.objects['hero']; rig = bpy.data.objects['rig']
PART_NAMES = list(hero.get('part_names', ['base']))

# ---------- 動作 JSON：每格每根骨頭的局部變換（相對父骨頭；根骨頭相對骨架）＋ 接地高度 ----------
# 跟 USD SkelAnimation 同一套定義，App 直接寫進 ModelEntity.jointTransforms（名稱用 USD 的骨頭路徑）。
def bone_path(b):
    names = []
    while b: names.append(b.name.replace('.', '_')); b = b.parent
    return '/'.join(reversed(names))
bones = [b for b in rig.data.bones]
frames = []
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f)
    row = []
    for b in bones:
        pb = rig.pose.bones[b.name]
        m = pb.matrix if not pb.parent else pb.parent.matrix.inverted() @ pb.matrix
        t, q, s = m.decompose()
        row.append([round(t.x, 5), round(t.y, 5), round(t.z, 5), round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)])
    frames.append(row)
clip = {'move': MOVE, 'fps': sc.render.fps, 'joints': [bone_path(b) for b in bones],
        'frames': frames,
        'note': 'Blender 座標（Z 朝上、角色面向 -Y）；每格 [tx,ty,tz,qx,qy,qz,qw]。low＝每個零件每格的最低點（公尺），App 依穿著的零件算接地抬高'}
def write_clip():
    json.dump(clip, open(os.path.join(DST, f'hero3d_clip_{MOVE}.json'), 'w'), separators=(',', ':'))
    print('clip', MOVE, len(frames), 'frames', len(bones), 'joints')

# ---------- 材質表：從卡通節點讀出亮面色、暗面倍率、有無高光；發光材質讀顏色和強度 ----------
def mat_info(m):
    nt = m.node_tree
    ramps = [n for n in nt.nodes if n.type == 'VALTORGB' and n.color_ramp.elements[0].position == 0.0 and len(n.color_ramp.elements) == 3]
    em = [n for n in nt.nodes if n.type == 'EMISSION']
    if not ramps:   # flat：發光、眼睛、描邊
        c = em[0].inputs['Color'].default_value
        return {'kind': 'flat', 'color': [round(c[0], 4), round(c[1], 4), round(c[2], 4)], 'strength': em[0].inputs['Strength'].default_value}
    r = ramps[0].color_ramp.elements
    base = r[1].color; shade = r[0].color[0] / base[0] if base[0] > 0 else 0.55
    info = {'kind': 'toon', 'color': [round(base[0], 4), round(base[1], 4), round(base[2], 4)], 'shade': round(shade, 3),
            'spec': any(n.type == 'BSDF_GLOSSY' for n in nt.nodes)}
    if len(ramps) > 1:   # 塗在身體上的衣服（tank 屬性 > 0 換色）
        a = ramps[1].color_ramp.elements
        info['alt'] = [round(a[1].color[0], 4), round(a[1].color[1], 4), round(a[1].color[2], 4)]
        info['altShade'] = round(a[0].color[0] / a[1].color[0], 3) if a[1].color[0] > 0 else 0.6
    return info

# ---------- 先回到靜止姿勢，把描邊外殼烘進網格 ----------
rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT'); bpy.context.view_layer.objects.active = hero; hero.select_set(True)
for md in list(hero.modifiers):
    if md.type == 'SOLIDIFY': md.show_viewport = True; bpy.ops.object.modifier_apply(modifier=md.name)

# 塗色欄位（tank）放進 UV（App 的著色器讀 uv0.x）
me = hero.data
tank = me.attributes.get('tank')
uv = me.uv_layers.new(name='st')
if tank:
    for loop in me.loops:
        uv.data[loop.index].uv = (tank.data[loop.vertex_index].value, 0.0)

# ---------- 依 零件 × 材質 拆網格 ----------
mats = [m.name if m else '' for m in me.materials]
part_attr = me.attributes['part']
groups = {}
for p in me.polygons:
    part = PART_NAMES[part_attr.data[p.index].value]
    mname = 'ol' if mats[p.material_index] == 'outline' else mats[p.material_index]
    groups.setdefault((part, mname), []).append(p.index)

made = []
for (part, mname), faces in sorted(groups.items()):
    name = f'{part}__{mname}'
    ob = hero.copy(); ob.data = hero.data.copy(); ob.name = name; ob.data.name = name
    sc.collection.objects.link(ob)
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
    keep = set(faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    keepmat = me.materials[mats.index('outline' if mname == 'ol' else mname)]
    ob.data.materials.clear(); ob.data.materials.append(keepmat)
    if mname != 'skintank':
        while ob.data.uv_layers: ob.data.uv_layers.remove(ob.data.uv_layers[0])
    for a in [a.name for a in ob.data.attributes if a.name in ('part', 'tank', 'frst')]:
        ob.data.attributes.remove(ob.data.attributes[a])
    # 用不到的骨頭權重群組刪掉（剛性零件只有一根）
    used = set()
    for v in ob.data.vertices:
        for g in v.groups:
            if g.weight > 0: used.add(g.group)
    drop = [vg.name for vg in ob.vertex_groups if vg.index not in used]   # 先記名字再刪（刪了索引會位移）
    for n in drop: ob.vertex_groups.remove(ob.vertex_groups[n])
    made.append(ob)

# 接地：每個零件每格的最低點（不含整體抬高；描邊外殼不算）
low = {o.name.split('__')[0]: [] for o in made if not o.name.endswith('__ol')}
rig.data.pose_position = 'POSE'
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f); rig.location.z = 0; bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get(); cur = {}
    for o in made:
        if o.name.endswith('__ol'): continue
        ev = o.evaluated_get(dg); m = ev.to_mesh()
        z = min((o.matrix_world @ v.co).z for v in m.vertices); ev.to_mesh_clear()
        k = o.name.split('__')[0]; cur[k] = min(cur.get(k, 9), z)
    for k in low: low[k].append(round(cur[k], 4))
clip['low'] = low
write_clip()
if MODE == 'clip':
    sys.exit(0)
# 整體抬高交給 App（依穿著算），USD 裡不要有骨架物件的位移動畫
for f in range(sc.frame_start, sc.frame_end + 1):
    rig.location.z = 0; rig.keyframe_insert('location', index=2, frame=f)
sc.frame_set(sc.frame_start)
rig.data.pose_position = 'REST'

# 其他東西（舞台、相機、燈、器材、原本的 hero）都不要
for ob in list(sc.objects):
    if ob not in made and ob != rig:
        bpy.data.objects.remove(ob, do_unlink=True)
rig.data.pose_position = 'POSE'

info = {'parts': PART_NAMES, 'meshes': sorted(o.name for o in made),
        'materials': {m.name: mat_info(m) for m in bpy.data.materials if m.users and m.use_nodes},
        'verts': {o.name: len(o.data.vertices) for o in made}}
json.dump(info, open(os.path.join(DST, 'hero3d.json'), 'w'), ensure_ascii=False, indent=1)
print('meshes', len(made), 'verts', sum(info['verts'].values()))

bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.usd_export(filepath=os.path.join(DST, 'hero3d.usdz'), export_animation=True, export_armatures=True,
                      only_deform_bones=True, export_materials=False, export_uvmaps=True, rename_uvmaps=True,
                      export_mesh_colors=False, export_lights=False, export_cameras=False,
                      convert_orientation=True, export_global_up_selection='Y', export_global_forward_selection='NEGATIVE_Z',
                      triangulate_meshes=True, export_custom_properties=False, evaluation_mode='VIEWPORT')
print('usdz', os.path.getsize(os.path.join(DST, 'hero3d.usdz')))
