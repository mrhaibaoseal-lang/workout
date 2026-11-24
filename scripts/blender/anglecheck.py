"""關節角度量測：對 hero_proto.py 存下的 hero.blend，逐格從骨頭姿勢量角度（量測函式在 moves3d.py 的 ANGLE-MEASURE 區段）。
blender -b <輸出資料夾>/hero.blend -P scripts/blender/anglecheck.py -- <angles.json>
輸出 {'frames': [格...], 'q': {'knee.L': [每格的值...], ...}}；過不過由 clipbatch.py 依 MOVE_META 的 angles 判定。
"""
import bpy, sys, os, json, math
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else 'angles.json'
_here = os.path.dirname(os.path.abspath(sys.argv[sys.argv.index('-P') + 1]))
_src = open(os.path.join(_here, 'moves3d.py'), encoding='utf-8').read()
_a, _b = _src.index('# ANGLE-MEASURE-BEGIN'), _src.index('# ANGLE-MEASURE-END')
NS = {'math': math, 'Vector': Vector}
exec(_src[_a:_b], NS)

sc = bpy.context.scene
rig = bpy.data.objects['rig']
assert all(abs(x) < 1e-6 for x in rig.rotation_euler), '骨架物件有旋轉，世界座標的角度會不準'
frames, q = [], {}
for f in range(sc.frame_start, sc.frame_end + 1):
    sc.frame_set(f)
    pbs = rig.evaluated_get(bpy.context.evaluated_depsgraph_get()).pose.bones
    for k, v in NS['measure_pose'](pbs).items(): q.setdefault(k, []).append(round(v, 2))
    frames.append(f)
json.dump({'frames': frames, 'q': q}, open(OUT, 'w'), ensure_ascii=False)
print('ANGLES', OUT, len(frames), '格')
for k, v in q.items(): print(f'  {k:14} {min(v):6.1f} ~ {max(v):6.1f}')
