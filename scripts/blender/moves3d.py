# 3D 動作示範的共用部分。由 hero_proto.py 在建好角色和骨架後 exec（共用 rig、B、M、toon、flat、OUTLINE…）。
# 動作本身在 moves/*.py（每批器材一個檔案，各自有負責人，見 docs/art/BLENDER_BRIEF.md §0-1）：
#   這裡先放共用工具（IK、軀幹、道具），再 exec 所有 moves/props_*.py（器材），最後只 exec 定義了 MOVE 的那個動作檔。
#   動作檔設定：N（影格數）、CAM（相機、舞台），並對每一格算出關節位置 → 骨頭矩陣、keyall(f)。
# 共用工具要改（新增可以，改既有函式的行為不行），先在 BLENDER_BRIEF §10 進度表講好，因為兩邊的動作都靠它。
#
# 做法：手腳「釘」在地板／握把上（例如伏地挺身的手掌和腳尖、下拉的握把），
#       軀幹用角度描述，手肘和膝蓋用兩節 IK 解出來（pole＝關節要往哪邊彎）。

pb = rig.pose.bones
for p_ in pb: p_.rotation_mode = 'QUATERNION'
rest = {n: (h.copy(), t.copy()) for n, (h, t) in B.items()}
blen = {n: (t - h).length for n, (h, t) in rest.items()}
RX = lambda ang: Matrix.Rotation(ang, 4, 'X')
UP = Vector((0, 0, 1))
D = math.radians

def aim(name, head, direction):
    yv = direction.normalized()
    ref = Vector((1, 0, 0)) if abs(yv.x) < 0.95 else Vector((0, -1, 0))
    zv = ref.cross(yv).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def ik2(a, t, l1, l2, pole):
    """兩節 IK：根 a、末端 t、長度 l1 l2、pole＝中間關節往哪個方向凸 → 中間關節位置"""
    d = t - a; dist = min(d.length, (l1 + l2) * 0.999); u = d.normalized()
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist); h = math.sqrt(max(l1 * l1 - x * x, 0))
    p = (pole - u * pole.dot(u)).normalized()
    return a + u * x + p * h

def trunk(hh, lam_hips, lam_chest, lam_head):
    """髖中心上方 hh 起：骨盆、胸、頭。lam＝往前傾的角度（負＝往後仰）。回傳 (胸部變換, 左右肩位置)"""
    ctop = aim('hips', hh, RX(lam_hips) @ UP)
    aim('chest', ctop, RX(lam_chest) @ UP)
    aim('head', ctop + RX(lam_chest) @ (rest['head'][0] - rest['chest'][0]), RX(lam_head) @ UP)
    chest_pt = lambda p: ctop + RX(lam_chest) @ (Vector(p) - rest['chest'][0])
    sh = {s: chest_pt(rest[f'upper_arm.{s}'][0]) for s in ('L', 'R')}
    return chest_pt, sh

def arm_to(s, sh, wrist, pole, hand_dir):
    e = ik2(sh, wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
    aim(f'upper_arm.{s}', sh, e - sh); aim(f'forearm.{s}', e, wrist - e); aim(f'hand.{s}', wrist, hand_dir)

def leg_to(s, hipj, ankle, pole, foot_dir=None):
    k = ik2(hipj, ankle, blen[f'thigh.{s}'], blen[f'shin.{s}'], pole)
    aim(f'thigh.{s}', hipj, k - hipj); aim(f'shin.{s}', k, ankle - k)
    aim(f'foot.{s}', ankle, foot_dir if foot_dir is not None else rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])

def ease(x): return x * x * (3 - 2 * x)
def profile(f, n, down, hold1, up):
    """一個循環：0→down 下去、停 hold1、up 回來、最後停住。回傳 0（起始）~1（最深）"""
    if f < down: return ease(f / down)
    if f < down + hold1: return 1.0
    if f < down + hold1 + up: return 1 - ease((f - down - hold1) / up)
    return 0.0

SX = (('L', 1), ('R', -1))
HIPX = {s: rest[f'thigh.{s}'][0].x for s, _ in SX}

# ---------- 道具工具 ----------
PM = {'frame': toon('frame', hexc('#3A4452'), 0.55, spec=True), 'pad': toon('pad', hexc('#1F2A44'), 0.6),
      'cable': flat('cable', hexc('#C9D1DB'), 1.0), 'plate': toon('plate', hexc('#2A2F38'), 0.55, spec=True),
      'chrome': toon('chrome', hexc('#C2CBD6'), 0.5, spec=True), 'rubber': toon('rubber', hexc('#15181E'), 0.6)}
def prop(ob, mat, outline=True, bevel=0.0):
    if bevel:
        bv = ob.modifiers.new('b', 'BEVEL'); bv.width = bevel; bv.segments = 2
    ob.data.materials.append(PM[mat])
    for p_ in ob.data.polygons: p_.use_smooth = True
    if outline:
        ob.data.materials.append(OUTLINE)
        so = ob.modifiers.new('o', 'SOLIDIFY'); so.thickness = -0.01; so.use_flip_normals = True; so.material_offset = 1; so.use_rim = False
    return ob
def pbox(mat, c, s, bevel=0.01, outline=True):
    bpy.ops.mesh.primitive_cube_add(location=c); ob = bpy.context.object; ob.scale = s
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); return prop(ob, mat, outline, bevel)
def pcyl(mat, c, r, depth, d=(0, 0, 1), n=24, outline=True, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=depth, location=c); ob = bpy.context.object
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = UP.rotation_difference(Vector(d))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False); return prop(ob, mat, outline, bevel)
def stretch(mat, r):
    """從原點往 -Z 長 1 的細圓柱（鋼索）：用 location／旋轉／scale.z 讓它接兩點"""
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=1, location=(0, 0, -0.5))
    ob = bpy.context.object; bpy.ops.object.transform_apply(location=True)
    ob.location = (0, 0, 0); ob.rotation_mode = 'QUATERNION'; return prop(ob, mat, False)
def key_stretch(ob, a, b, f):
    ob.location = a; ob.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(b - a); ob.scale = (1, 1, (b - a).length)
    for k in ('location', 'rotation_quaternion', 'scale'): ob.keyframe_insert(k, frame=f)

def keyall(f):
    for p_ in pb:
        p_.keyframe_insert('rotation_quaternion', frame=f); p_.keyframe_insert('location', frame=f)

PM['red'] = toon('red', hexc('#D3302F'), 0.55)
def pori(mat, c, s, d, bevel=0.012, roll=0.0):
    bpy.ops.mesh.primitive_cube_add(location=c); ob = bpy.context.object; ob.scale = s
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = UP.rotation_difference(Vector(d)) @ Matrix.Rotation(roll, 4, 'Z').to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False); return prop(ob, mat, True, bevel)
def tube(a, b, w=0.025, mat='frame'):
    a, b = Vector(a), Vector(b); return pori(mat, (a + b) / 2, (w, w, (b - a).length / 2), b - a, 0.006)

MOVE = os.environ.get('MOVE', 'squat')
CAM = dict(loc=(4.2, -3.9, 1.7), tgt=(0, 0, 0.95), lens=70, stage=(0, 0, 0.62))

# ---------- 器材（moves/props_*.py）＋這個動作的檔案（MOVES 由 hero_proto.py 從各檔 MOVE_META 收集） ----------
_MDIR = os.path.join(_GD, 'moves')
for _pf in sorted(glob.glob(os.path.join(_MDIR, 'props_*.py'))):
    exec(open(_pf, encoding='utf-8').read())
exec(open(os.path.join(_MDIR, MOVES[MOVE]['file']), encoding='utf-8').read())
assert 'N' in globals(), f'{MOVES[MOVE]["file"]} 沒有設定 N（影格數）'

sc.frame_start, sc.frame_end = 0, N - 1

# ---------- 接地修正：裝備比基本款厚（例如推進靴、手甲），手腳釘點是照身體算的 → 有東西沉到地板下，就把整個人抬高 ----------
_sol = [m for m in bpy.data.objects['hero'].modifiers if m.type == 'SOLIDIFY']
for m in _sol: m.show_viewport = False
_hero = bpy.data.objects['hero']
for f in range(N):
    sc.frame_set(f); rig.location.z = 0; bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get(); ev = _hero.evaluated_get(dg); me = ev.to_mesh()
    low = min((_hero.matrix_world @ v.co).z for v in me.vertices); ev.to_mesh_clear()
    rig.location.z = max(0.0, -low - 0.002) if low < -0.004 else 0.0
    rig.keyframe_insert('location', index=2, frame=f)
for m in _sol: m.show_viewport = True
