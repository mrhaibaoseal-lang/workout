"""穿模自動檢查：對 hero_proto.py 存下的 hero.blend，逐格算三角形有沒有互相穿過。
blender -b <輸出資料夾>/hero.blend -P scripts/blender/clipcheck.py -- <報告.json> [每幾格取樣，預設 2]

把角色網格依「面的主要骨頭」和「類別」分組：
  body＝身體、衣服、鞋、頭髮；gear＝裝備（鈦甲材質）和手上的啞鈴；prop＝器材（椅子、立柱…，下拉槓和鋼索除外）。
檢查的組合（同一根骨頭、或父子相鄰的骨頭在關節處本來就會重疊，不算）：
  gear × 其他骨頭的 body/gear、body × 不相鄰骨頭的 body、body/gear × prop；另外檢查有沒有沉到地板下。
輸出：每格每組的穿透三角形對數，和最嚴重的幾格（拿去截圖人工看）。
"""
import bpy, sys, json, re
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '/tmp/clip.json'
STEP = int(argv[1]) if len(argv) > 1 else 2

sc = bpy.context.scene
hero = bpy.data.objects['hero']; rig = bpy.data.objects['rig']
for md in hero.modifiers:
    if md.type == 'SOLIDIFY': md.show_viewport = False          # 描邊外殼不算
GEAR_MATS = {'ti', 'tidk', 'glow', 'flame', 'iron', 'grip',
             'fr1', 'fr2', 'fr3', 'frice', 'frblade', 'frglow',   # 冰霜（衣服塗色和長褲不算，那些是 body）
             'pg1', 'pg2', 'pghoof', 'pgnose', 'pggold', 'pggolddk', 'pgbank'}   # 小豬（短褲不算）
SKIP_PROPS = {'bar', 'cable'}                                    # 手本來就握著
mats = [m.name if m else '' for m in hero.data.materials]
parent = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
# 關節相連的骨頭（骨架裡腳掌沒有父骨頭，所以手動列出）：在關節處本來就會重疊，不算穿模
JOINTS = {('hips', 'chest'), ('chest', 'head'), ('chest', 'upper_arm'), ('upper_arm', 'forearm'), ('forearm', 'hand'),
          ('hips', 'thigh'), ('thigh', 'shin'), ('shin', 'foot')}
def adjacent(a, b):
    if a == b: return True
    ba, sa = (a.split('.') + [''])[:2]; bb, sb = (b.split('.') + [''])[:2]
    if sa and sb and sa != sb: return False
    return (ba, bb) in JOINTS or (bb, ba) in JOINTS

# 每個面：(類別, 主要骨頭)
labels = []
for p in hero.data.polygons:
    acc = {}
    for vi in p.vertices:
        for g in hero.data.vertices[vi].groups:
            n = hero.vertex_groups[g.group].name; acc[n] = acc.get(n, 0) + g.weight
    bone = max(acc, key=acc.get) if acc else '?'
    cat = 'gear' if re.sub(r'\.\d+$', '', mats[p.material_index]) in GEAR_MATS else 'body'   # 只去掉 Blender 的 .001（不能 rstrip 數字：fr1 會變 fr）
    labels.append((cat, bone))
groups = sorted(set(labels))

def prop_objects():
    out = []
    for o in sc.objects:
        if o.type != 'MESH' or o is hero: continue
        mn = o.data.materials[0].name if o.data.materials else ''
        if mn.startswith(('stage', 'ring', 'cable', 'holo', 'glow')): continue   # 舞台、光圈、鋼索、特效
        top = o
        while top.parent: top = top.parent
        if top.name in SKIP_PROPS: continue
        out.append(o)
    return out

report = {'frames': {}, 'worst': []}
props = prop_objects()
for f in range(sc.frame_start, sc.frame_end + 1, STEP):
    sc.frame_set(f); dg = bpy.context.evaluated_depsgraph_get()
    ev = hero.evaluated_get(dg); me = ev.to_mesh()
    mw = hero.matrix_world
    verts = [mw @ v.co for v in me.vertices]
    trees = {}
    for g in groups:
        polys = [tuple(p.vertices) for p, l in zip(me.polygons, labels) if l == g]
        if polys: trees[g] = BVHTree.FromPolygons(verts, polys)
    ptrees = {}
    for kind in ('硬器材', '軟墊'):
        pv, pp = [], []
        for o in props:
            soft = o.data.materials and o.data.materials[0].name.startswith('pad')
            if (kind == '軟墊') != bool(soft): continue
            oe = o.evaluated_get(dg); m2 = oe.to_mesh(); base = len(pv)
            pv += [o.matrix_world @ v.co for v in m2.vertices]; pp += [tuple(base + i for i in p.vertices) for p in m2.polygons]
            oe.to_mesh_clear()
        if pp: ptrees[kind] = BVHTree.FromPolygons(pv, pp)
    hits = {}
    keys = list(trees)
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            if adjacent(a[1], b[1]): continue
            n = len(trees[a].overlap(trees[b]))
            if n: hits[f'{a[0]}:{a[1]} × {b[0]}:{b[1]}'] = n
        for kind, pt in ptrees.items():
            n = len(trees[a].overlap(pt))
            if n: hits[f'{a[0]}:{a[1]} × {kind}'] = n
    lows = {}
    for p, l in zip(me.polygons, labels):
        z = min(verts[i].z for i in p.vertices)
        if z < -0.01: lows[l] = min(lows.get(l, 0), z)
    for l, z in lows.items(): hits[f'沉入地板(cm) {l[0]}:{l[1]}'] = round(-z * 100, 1)
    ev.to_mesh_clear()
    report['frames'][f] = hits
    report['worst'].append((sum(v for k, v in hits.items() if not k.startswith('沉') and not k.endswith('軟墊')), f))
report['worst'] = [f for n, f in sorted(report['worst'], reverse=True)[:3] if n > 0]
json.dump(report, open(OUT, 'w'), ensure_ascii=False, indent=1)
# 文字摘要：每一組在整段動作中的最大值
tot = {}
for hits in report['frames'].values():
    for k, v in hits.items(): tot[k] = max(tot.get(k, 0), v)
print('CLIP', OUT)
for k, v in sorted(tot.items(), key=lambda x: -x[1]): print(f'  {v:5}  {k}')
print('  最嚴重的格：', report['worst'])
