# 給 App（RealityKit）用的匯出：hero.blend → USDZ（骨架＋動畫）＋ 材質表 JSON ＋ 動作 JSON ＋ 換裝貼圖。
#   blender -b <輸出>/hero.blend -P scripts/blender/export_app.py -- <目標資料夾> <動作名> [full|clip|outfit]
# full：所有零件（用 EXPORT=frost,titan 建出來的 hero.blend），App 逐件開關；clip：只取動作，不輸出模型。
#   full 依系列分檔：hero3d.usdz（骨架、身體、衣服網格、基本款）＋ hero3d_<系列>.usdz（該系列的零件），對照表在 hero3d.json 的 files。
# outfit：給換裝用，hero.blend 是 GEAR="top=X,bottom=X" 建的。存這個系列的塗色（outfit.json）和
#   上衣／下身的零件、衣服網格（parts.blend），目標資料夾就是那次建模的資料夾。
# full／clip 會讀環境變數 OUTFITS（系列清單，例如 basic,frost,titan,pig）和 OUTFIT_DIR（各系列 outfit_<系列>/ 所在資料夾），
#   把各系列的上衣／下身零件、衣服網格接進來（骨架改指向這次的 rig），full 再烘換裝貼圖 hero3d_<上衣|下身|衣服>_….png。
# 拆法：hero 網格依「零件(part 面屬性) × 材質」拆成獨立網格，名稱 <部位>_<系列>__<材質>。
#   身體只拆成一個 base__body（材質 body，App 讀上衣圖＋下身圖），衣服網格是 top_suit__cloth_suit、bottom_long__cloth_long、bottom_short__cloth_short。
# 描邊不烘外殼（0.39.0 起）：App 用著色器把同一份網格沿平均法線外撐再畫一次，USDZ 省一半頂點。
# 卡通著色不靠 USD 材質（RealityKit 不認 Blender 節點），App 依名稱查 materials.json 用自己的 Metal 著色器。
import bpy, bmesh, json, os, re, sys
from mathutils import Matrix

argv = sys.argv[sys.argv.index('--') + 1:]
DST, MOVE = argv[0], argv[1]
MODE = argv[2] if len(argv) > 2 else 'full'
os.makedirs(DST, exist_ok=True)
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'outfit_util.py'), encoding='utf-8').read())
sc = bpy.context.scene
hero = bpy.data.objects['hero']; rig = bpy.data.objects['rig']
PART_NAMES = list(hero.get('part_names', ['base']))
OUTFITS = [x for x in os.environ.get('OUTFITS', '').split(',') if x]
OUTFIT_DIR = os.environ.get('OUTFIT_DIR', '')
SKIN = [0.5, 0.53, 0.58]

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
    if m.name == 'body' or m.name.startswith('cloth_'):   # 換裝材質：App 讀貼圖，color＝沒穿衣服的地方（皮膚）
        return {'kind': 'outfit', 'color': SKIN, 'shade': 0.55, 'spec': False}
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
    return info

# ---------- 回到靜止姿勢；原型用的描邊外殼（solidify）不要 ----------
rig.data.pose_position = 'REST'; bpy.context.view_layer.update()
for md in list(hero.modifiers):
    if md.type == 'SOLIDIFY': hero.modifiers.remove(md)

# ---------- 依 零件 × 材質 拆網格（身體一個、每件衣服網格一個） ----------
me = hero.data
for u in list(me.uv_layers): me.uv_layers.remove(u)
mats = [m.name if m else '' for m in me.materials]
part_attr = me.attributes['part']
body_faces = set()
for a, b in hero.get('deform_faces', {}).get('1', []): body_faces.update(range(a, b))
groups = {}
for p in me.polygons:
    part = PART_NAMES[part_attr.data[p.index].value]
    mname = mats[p.material_index]
    if mname == 'outline': continue
    if p.index in body_faces: key = ('base', 'body')
    elif part in CLOTH_PARTS: key = (part, CLOTH_PARTS[part])
    else: key = (part, mname)
    groups.setdefault(key, []).append(p.index)

made = []; face_mats = {}
def placeholder(name):
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)
for (part, mname), faces in sorted(groups.items()):
    name = f'{part}__{mname}'
    ob = hero.copy(); ob.data = hero.data.copy(); ob.name = name; ob.data.name = name
    sc.collection.objects.link(ob)
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.faces.ensure_lookup_table()
    keep = set(faces)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    if mname == 'body' or mname.startswith('cloth_'):
        face_mats[name] = [ob.data.materials[p.material_index].name for p in ob.data.polygons]
        keepmat = placeholder(mname)
    else:
        keepmat = me.materials[mats.index(mname)]
    ob.data.materials.clear(); ob.data.materials.append(keepmat)
    # 用不到的骨頭權重群組刪掉（剛性零件只有一根）
    used = set()
    for v in ob.data.vertices:
        for g in v.groups:
            if g.weight > 0: used.add(g.group)
    drop = [vg.name for vg in ob.vertex_groups if vg.index not in used]   # 先記名字再刪（刪了索引會位移）
    for n in drop: ob.vertex_groups.remove(ob.vertex_groups[n])
    made.append(ob)

def strip_attrs(ob):
    """自訂屬性（part、rgn、各系列塗色）不要進 USD"""
    for a in [a.name for a in ob.data.attributes
              if a.name in ('part', 'rgn') or (a.domain == 'POINT' and a.data_type == 'FLOAT' and not a.name.startswith('.'))]:
        ob.data.attributes.remove(ob.data.attributes[a])

body = bpy.data.objects.get('base__body')
cloths = [o for o in made if o.name.split('__')[0] in CLOTH_PARTS]

if MODE == 'outfit':
    # 這個系列的塗色存起來，上衣／下身的零件和衣服網格存成 parts.blend，其他都不要
    dump_series(body, cloths, face_mats, hero, os.path.join(DST, 'outfit.json'))
    keep = [o for o in made if o.name.split('__')[0].startswith(('top_', 'bottom_'))]
    for o in keep: strip_attrs(o)
    for ob in list(sc.objects):
        if ob not in keep and ob != rig: bpy.data.objects.remove(ob, do_unlink=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(DST, 'parts.blend'))
    print('outfit parts', sorted(o.name for o in keep))
    sys.exit(0)

# ---------- 接進各系列的上衣／下身零件、衣服網格（outfit 模式存的 parts.blend） ----------
dumps = {}
for s in OUTFITS:
    d = os.path.join(OUTFIT_DIR, f'outfit_{s}')
    dumps[s] = json.load(open(os.path.join(d, 'outfit.json')))
    have = {o.name for o in sc.objects}
    with bpy.data.libraries.load(os.path.join(d, 'parts.blend'), link=False) as (src, dst_):
        dst_.objects = [n for n in src.objects if n != 'rig' and n not in have]
    for ob in dst_.objects:
        sc.collection.objects.link(ob)
        ob.parent = rig
        for md in ob.modifiers:
            if md.type == 'ARMATURE': md.object = rig
        for i, slot in enumerate(ob.material_slots):   # 同名材質用這次的（xxx.001 → xxx）
            m = slot.material
            if not m: continue
            bn = re.sub(r'\.\d{3}$', '', m.name)
            if bn != m.name and bn in bpy.data.materials: ob.data.materials[i] = bpy.data.materials[bn]
        made.append(ob)
        print('outfit part', s, ob.name, len(ob.data.vertices))
for ob in list(bpy.data.objects):   # 跟著零件進來的別次骨架
    if ob.type == 'ARMATURE' and ob != rig: bpy.data.objects.remove(ob, do_unlink=True)

# 接地：每個零件每格的最低點（不含整體抬高）
low = {o.name.split('__')[0]: [] for o in made}
rig.data.pose_position = 'POSE'
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f); rig.location.z = 0; bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get(); cur = {}
    for o in made:
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

# ---------- 換裝貼圖：身體、衣服網格各展一次 UV，每個系列烘一張 ----------
RES = int(os.environ.get('OUTFIT_RES', '1024'))
outfits = {'top': {}, 'bottom': {}}
tex_sizes = {}
if OUTFITS:
    cloth_obj = {o.name.split('__')[0]: o for o in made if o.name.split('__')[0] in CLOTH_PARTS}
    targets = [('body', body)] + sorted(cloth_obj.items())
    R = {}
    for k, ob in targets:
        unwrap(ob); R[k] = raster(ob, RES)
        print('uv', k, 'tris', len(R[k]['tri_v']), 'coverage', round(float((R[k]['tri'] >= 0).mean()), 3))
    def emit(fname, img):
        tex_sizes[fname] = write_png(os.path.join(DST, fname + '.png'), img); return fname
    for s in OUTFITS:
        dp = dumps[s]; bd = dp['body']
        assert bd['nv'] == len(body.data.vertices) and bd['topo'] == topo_hash(body.data), f'{s} 的身體網格拓撲跟基準不同'
        outfits['top'][s] = {'body': emit(f'hero3d_top_{s}', bake(R['body'], bd['top'], dp['chains'], bd['attrs']))}
        outfits['bottom'][s] = {'body': emit(f'hero3d_bottom_{s}', bake(R['body'], bd['bottom'], dp['chains'], bd['attrs']))}
        for part, cd in dp['cloth'].items():
            ob = cloth_obj[part]
            assert cd['nv'] == len(ob.data.vertices) and cd['topo'] == topo_hash(ob.data), f'{s} 的 {part} 網格拓撲不同'
            e = outfits[CLOTH_SLOT[part]][s]
            e['mesh'] = CLOTH_KIND[part]
            e['cloth'] = emit(f'hero3d_cloth_{CLOTH_KIND[part]}_{s}', bake(R[part], cd['faces'], dp['chains'], cd['attrs']))
        for slot in ('top', 'bottom'):   # 剛性小零件（冰霜胸章、鈦甲胸甲、小豬尾巴…）
            if any(o.name.startswith(f'{slot}_{s}__') for o in made): outfits[slot][s]['part'] = f'{slot}_{s}'
for o in made: strip_attrs(o)

# 其他東西（舞台、相機、燈、器材、原本的 hero）都不要
for ob in list(sc.objects):
    if ob not in made and ob != rig:
        bpy.data.objects.remove(ob, do_unlink=True)
rig.data.pose_position = 'POSE'

# ---------- 分檔（2026-11-26）：主檔 hero3d.usdz 放骨架、身體、衣服網格和基本款；每個系列的零件（頭、手、腳、背、啞鈴、
# 上衣／下身小零件）各一個 hero3d_<系列>.usdz，App 選到那個系列才載入。每個檔都帶同一副骨架和動畫。
def file_of(part):
    if part == 'base' or part in CLOTH_PARTS: return 'hero3d'
    ser = part.split('_', 1)[1] if '_' in part else 'basic'
    return 'hero3d' if ser == 'basic' else f'hero3d_{ser}'
groups = {}
for o in made: groups.setdefault(file_of(o.name.split('__')[0]), []).append(o)

info = {'parts': sorted({o.name.split('__')[0] for o in made}), 'meshes': sorted(o.name for o in made),
        'files': {f[len('hero3d_'):]: f for f in groups if f != 'hero3d'},
        'materials': {m.name: mat_info(m) for m in bpy.data.materials if m.users and (m.use_nodes or m.name == 'body' or m.name.startswith('cloth_'))},
        'outfits': outfits, 'textures': tex_sizes,
        'verts': {o.name: len(o.data.vertices) for o in made}}
json.dump(info, open(os.path.join(DST, 'hero3d.json'), 'w'), ensure_ascii=False, indent=1)
print('meshes', len(made), 'verts', sum(info['verts'].values()), 'textures', len(tex_sizes), sum(tex_sizes.values()))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(os.path.dirname(bpy.data.filepath), 'hero_app.blend'))   # 給 outfit_review.py 出總覽圖

sizes = {}
for fname, obs in sorted(groups.items()):
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for o in obs: o.select_set(True)
    path = os.path.join(DST, fname + '.usdz')
    bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_animation=True, export_armatures=True,
                          only_deform_bones=True, export_materials=False, export_uvmaps=True, rename_uvmaps=True,
                          export_mesh_colors=False, export_lights=False, export_cameras=False,
                          convert_orientation=True, export_global_up_selection='Y', export_global_forward_selection='NEGATIVE_Z',
                          triangulate_meshes=True, export_custom_properties=False, evaluation_mode='VIEWPORT')
    sizes[fname] = os.path.getsize(path)
    print('usdz', fname, sizes[fname], 'verts', sum(len(o.data.vertices) for o in obs))
print('usdz total', sum(sizes.values()))
