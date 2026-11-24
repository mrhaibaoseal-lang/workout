"""審查總覽圖的 Blender 端：對 hero.blend 量角度找 4 個時間點，從 4 個鏡頭各渲染 4 格（共 16 張小圖）。
blender -b <hero.blend> -P scripts/blender/review_render.py -- <輸出資料夾> [格寬像素，預設 400]
輸出：<輸出資料夾>/cells/<鏡頭>_<格>.png、<輸出資料夾>/meta.json（選了哪幾格、量測值；review_sheet.py 拿去拼圖和判定）。
時間點：起始＝第 0 格；最深＝「變化最大的那個角度」離起始最遠的格（有停留就取中間）；中段／回程＝去程／回程走到一半的格。
找不到變化（角度變化都 < 5°）就用動作中點：起始 0、中段 N/4、最深 N/2、回程 3N/4。
鏡頭：原本（動作檔的 CAM）、正面、側面（人面向右）、正上方（人面向上）；後三個是正交鏡頭，角度才看得準。
"""
import bpy, sys, os, json, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0]; CELL = int(argv[1]) if len(argv) > 1 else 400
_here = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index('-P') + 1]))
_src = open(os.path.join(_here, 'moves3d.py'), encoding='utf-8').read()
NS = {'math': math, 'Vector': Vector}
exec(_src[_src.index('# ANGLE-MEASURE-BEGIN'):_src.index('# ANGLE-MEASURE-END')], NS)

sc = bpy.context.scene
rig = bpy.data.objects['rig']; hero = bpy.data.objects['hero']
f0, f1 = sc.frame_start, sc.frame_end
N = f1 - f0 + 1

# ---------- 量角度、選格 ----------
q = {}
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    pbs = rig.evaluated_get(bpy.context.evaluated_depsgraph_get()).pose.bones
    for k, v in NS['measure_pose'](pbs).items(): q.setdefault(k, []).append(v)

def pick(q):
    key = max(q, key=lambda k: max(q[k]) - min(q[k]))        # 變化最大的量（左右一樣大就取先出現的）
    v = q[key]; dev = [abs(x - v[0]) for x in v]; peak = max(dev)
    if peak < 5: return None, [0, N // 4, N // 2, 3 * N // 4]
    plateau = [i for i, d in enumerate(dev) if d >= peak - 0.5]
    deep = plateau[len(plateau) // 2]
    mid = next((i for i in range(deep) if dev[i] >= peak / 2), deep // 2)
    ret = next((i for i in range(deep, N) if dev[i] <= peak / 2), (deep + N - 1) // 2)
    return key, [0, mid, deep, ret]

key, idx = pick(q)
frames = [f0 + i for i in idx]
names = ['起始', '中段', '最深', '回程']

# ---------- 鏡頭 ----------
mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
for f in frames:                                              # 四格合起來的人體範圍
    sc.frame_set(f); ev = hero.evaluated_get(bpy.context.evaluated_depsgraph_get()); me = ev.to_mesh()
    for v in me.vertices:
        p = hero.matrix_world @ v.co
        for i in range(3): mn[i] = min(mn[i], p[i]); mx[i] = max(mx[i], p[i])
    ev.to_mesh_clear()
ctr = (mn + mx) / 2
size = max(1.7, max(mx[i] - mn[i] for i in range(3)) * 1.25)
def ortho(name, loc, rot):
    cd = bpy.data.cameras.new(name); cd.type = 'ORTHO'; cd.ortho_scale = size; cd.clip_start, cd.clip_end = 0.1, 60
    ob = bpy.data.objects.new(name, cd); sc.collection.objects.link(ob); ob.location = loc; ob.rotation_euler = rot
    return ob
D = 8.0
cams = [('原本', sc.camera),
        ('正面', ortho('c_front', ctr + Vector((0, -D, 0)), (math.pi / 2, 0, 0))),
        ('側面', ortho('c_side', ctr + Vector((-D, 0, 0)), (math.pi / 2, 0, -math.pi / 2))),
        ('正上方', ortho('c_top', ctr + Vector((0, 0, D)), (0, 0, math.pi)))]

# ---------- 渲染 ----------
os.makedirs(os.path.join(OUT, 'cells'), exist_ok=True)
sc.render.resolution_x = sc.render.resolution_y = CELL; sc.render.resolution_percentage = 100
sc.eevee.taa_render_samples = 8
for cname, cam in cams:
    sc.camera = cam
    for f in frames:
        sc.frame_set(f); sc.render.filepath = os.path.join(OUT, 'cells', f'{cname}_{f}.png')
        bpy.ops.render.render(write_still=True)
json.dump({'frames': frames, 'names': names, 'cams': [c for c, _ in cams], 'key': key, 'n': N,
           'q': {k: [round(x, 2) for x in v] for k, v in q.items()}},
          open(os.path.join(OUT, 'meta.json'), 'w', encoding='utf-8'), ensure_ascii=False)
print('REVIEW', OUT, frames, key)
