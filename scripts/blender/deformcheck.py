"""身體變形自動檢查（不渲染）：對 hero_proto.py 存下的 hero.blend，逐格拿變形後的身體網格和靜止姿勢比。
blender -b <輸出資料夾>/hero.blend -P scripts/blender/deformcheck.py -- <報告.json> [每幾格取樣，預設 2]
（環境變數 LBS=1：關掉保持體積，看 App 即時線性蒙皮的結果）

只看會彎的網格（hero['deform_faces']：1＝身體皮膚、2＝衣服網格，例如短褲、長褲）；剛性零件（鞋、頭、裝備）不看。
每個面找出：
  - 面積縮到 50% 以下（擠扁），或撐大到 180% 以上（拉扯）
  - 法線翻轉：靜止法線照「權重最大的骨頭」轉過去，和變形後的法線方向相反（摺進去了）
  - 皮膚自己穿過自己（只看身體皮膚；靜止時就碰在一起的面不算，例如腋下、胯下本來就貼著）
報告每一格、每個部位壞幾個面。部位＝面上權重前兩名的骨頭（第二名占 25% 以上才寫，例如 thigh.L+shin.L＝膝窩）。
這支管身體本身的畸變；裝備、器材穿模是 clipcheck.py 的事。BLENDER_BRIEF §6-1。
"""
import bpy, sys, json
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '/tmp/deform.json'
STEP = int(argv[1]) if len(argv) > 1 else 2
SMALL, BIG = 0.5, 1.8

sc = bpy.context.scene
hero = bpy.data.objects['hero']; rig = bpy.data.objects['rig']
import os
LBS = os.environ.get('LBS') == '1'   # LBS=1：關掉保持體積，模擬 App（RealityKit）的線性蒙皮
for md in hero.modifiers:
    if md.type == 'SOLIDIFY': md.show_viewport = False          # 描邊外殼不算
    if md.type == 'ARMATURE' and LBS: md.use_deform_preserve_volume = False
rngs = hero['deform_faces']
kind = {}
for k, name in (('1', 'skin'), ('2', 'cloth')):
    for a, b in rngs.get(k, []):
        for i in range(a, b): kind[i] = name
FACES = sorted(kind)

# 每個面的部位標籤（前兩名骨頭）和主要骨頭
me0 = hero.data
vg = {g.index: g.name for g in hero.vertex_groups}
bones = {b.name for b in rig.data.bones}
label, main = {}, {}
for i in FACES:
    acc = {}
    for vi in me0.polygons[i].vertices:
        for g in me0.vertices[vi].groups:
            n = vg[g.group]
            if n in bones: acc[n] = acc.get(n, 0) + g.weight
    top = sorted(acc.items(), key=lambda x: -x[1])
    main[i] = top[0][0] if top else '?'
    tot = sum(acc.values()) or 1
    label[i] = top[0][0] + (f'+{top[1][0]}' if len(top) > 1 and top[1][1] / tot >= 0.25 else '') if top else '?'

def evaluated():
    dg = bpy.context.evaluated_depsgraph_get(); ev = hero.evaluated_get(dg); me = ev.to_mesh()
    mw = hero.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    data = {i: (me.polygons[i].area, (mw.to_3x3() @ me.polygons[i].normal).normalized()) for i in FACES}
    ev.to_mesh_clear(); return verts, data

polys = {i: tuple(me0.polygons[i].vertices) for i in FACES}
SKIN = [i for i in FACES if kind[i] == 'skin']
def self_hits(verts):
    tree = BVHTree.FromPolygons(verts, [polys[i] for i in SKIN])
    out = set()
    for a, b in tree.overlap(tree):
        if a >= b: continue
        fa, fb = SKIN[a], SKIN[b]
        if set(polys[fa]) & set(polys[fb]): continue          # 相鄰的面（共用頂點）
        out.add((fa, fb))
    return out

pose0 = rig.data.pose_position
rig.data.pose_position = 'REST'; sc.frame_set(sc.frame_start); bpy.context.view_layer.update()
rverts, rest = evaluated()
rest_self = self_hits(rverts)
rig.data.pose_position = pose0; bpy.context.view_layer.update()

report = {'frames': {}, 'summary': {}, 'rest_self_pairs': len(rest_self)}
for f in range(sc.frame_start, sc.frame_end + 1, STEP):
    sc.frame_set(f); bpy.context.view_layer.update()
    rot = {}
    for pb in rig.pose.bones:
        m = (rig.matrix_world @ pb.matrix @ pb.bone.matrix_local.inverted() @ rig.matrix_world.inverted()).to_3x3()
        m.normalize(); rot[pb.name] = m
    verts, cur = evaluated()
    hits = {}
    def add(k, i):
        key = f'{k} {kind[i]}:{label[i]}'; hits[key] = hits.get(key, 0) + 1
    for i in FACES:
        a0, n0 = rest[i]; a1, n1 = cur[i]
        if a0 < 1e-9: continue
        r = a1 / a0
        if r < SMALL: add('擠扁<50%', i)
        elif r > BIG: add('拉扯>180%', i)
        R = rot.get(main[i])
        if R is not None and (R @ n0).dot(n1) < 0: add('法線翻轉', i)
    for fa, fb in self_hits(verts) - rest_self:
        la, lb = sorted((label[fa], label[fb]))
        key = f'皮膚自穿 {la} × {lb}'; hits[key] = hits.get(key, 0) + 1
    report['frames'][f] = hits
tot = {}
for f, hits in report['frames'].items():
    for k, v in hits.items():
        if v > tot.get(k, (0, 0))[0]: tot[k] = (v, f)
report['summary'] = {k: {'max': v, 'frame': f} for k, (v, f) in sorted(tot.items(), key=lambda x: -x[1][0])}
report['bad_faces_max'] = max((sum(h.values()) for h in report['frames'].values()), default=0)
json.dump(report, open(OUT, 'w'), ensure_ascii=False, indent=1)
print('DEFORM', OUT, '線性蒙皮' if LBS else '', f'（身體 {len(SKIN)} 面、衣服 {len(FACES) - len(SKIN)} 面、靜止時本來就碰在一起 {len(rest_self)} 對）')
for k, d in report['summary'].items(): print(f'  {d["max"]:5}  {k}  （最多在 f{d["frame"]}）')
print('  單格最多壞面：', report['bad_faces_max'])
