# 3D 動作示範。由 hero_proto.py 在建好角色和骨架後 exec（共用 rig、B、M、toon、flat、OUTLINE…）。
# MOVE=squat｜pushup｜pulldown。每個動作設定：影格數、相機、舞台，並對每一格算出關節位置 → 骨頭矩陣。
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

# ---------- 使用者的器材：多功能啞鈴椅＋高位下拉架（一體） ----------
# 角色面向 -Y。立柱在椅子前端（-Y），頂部滑輪盒；立柱兩側各兩層槓片收納柱；
# 椅子：座墊、可調靠背（角度 back_deg＝離垂直往後倒幾度）、頭枕＋把手、前端腳踝滾筒（腳勾在下面）。
# 前後兩支底座。不畫商標、不畫彈力繩（使用者不用）。
POST_Y, POST_TOP = -0.62, 2.0
SEAT_Z, SEAT_Y0, SEAT_Y1 = 0.47, -0.30, 0.13
HINGE = Vector((0, 0.15, 0.46))
PM['red'] = toon('red', hexc('#D3302F'), 0.55)
def pori(mat, c, s, d, bevel=0.012, roll=0.0):
    bpy.ops.mesh.primitive_cube_add(location=c); ob = bpy.context.object; ob.scale = s
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = UP.rotation_difference(Vector(d)) @ Matrix.Rotation(roll, 4, 'Z').to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False); return prop(ob, mat, True, bevel)
def tube(a, b, w=0.025, mat='frame'):
    a, b = Vector(a), Vector(b); return pori(mat, (a + b) / 2, (w, w, (b - a).length / 2), b - a, 0.006)
def build_bench(back_deg):
    # 底座：前（立柱下）、後各一支橫腳，中間一支縱樑
    pbox('frame', (0, POST_Y, 0.03), (0.17, 0.04, 0.03), 0.008)
    pbox('frame', (0, 0.60, 0.03), (0.26, 0.04, 0.03), 0.008)
    for x_ in (-0.15, 0.15): pbox('rubber', (x_, POST_Y, 0.008), (0.03, 0.05, 0.008), 0.003)
    for x_ in (-0.24, 0.24): pbox('rubber', (x_, 0.60, 0.008), (0.03, 0.05, 0.008), 0.003)
    tube((0, POST_Y, 0.06), (0, -0.30, 0.30), 0.028)              # 前斜樑
    tube((0, -0.30, 0.30), (0, 0.15, 0.38), 0.028)               # 座下主樑
    tube((0, 0.15, 0.38), (0, 0.60, 0.06), 0.028)                # 後斜腿
    tube((0, -0.10, 0.33), (0, -0.10, SEAT_Z - 0.04), 0.022)     # 座墊支柱
    # 座墊
    pbox('pad', (0, (SEAT_Y0 + SEAT_Y1) / 2, SEAT_Z - 0.035), (0.15, (SEAT_Y1 - SEAT_Y0) / 2, 0.035), 0.025)
    # 靠背＋頭枕＋把手
    a = D(back_deg); dv = Vector((0, math.sin(a), math.cos(a))); nv = Vector((0, -math.cos(a), math.sin(a)))
    pori('pad', HINGE + dv * 0.36 + nv * 0.0, (0.15, 0.04, 0.34), dv, 0.025)
    pori('frame', HINGE + dv * 0.30 - nv * 0.05, (0.03, 0.02, 0.28), dv, 0.006)
    hr = HINGE + dv * 0.80
    pori('pad', hr + nv * 0.02, (0.13, 0.045, 0.07), dv, 0.03)
    for sx in (1, -1): tube(hr - nv * 0.03 + Vector((0.09 * sx, 0, 0)), hr - nv * 0.03 + dv * 0.13 + Vector((0.09 * sx, 0, 0)), 0.01)
    tube(hr - nv * 0.03 + dv * 0.13 + Vector((-0.095, 0, 0)), hr - nv * 0.03 + dv * 0.13 + Vector((0.095, 0, 0)), 0.012)
    # 靠背調整支架（梯形孔架）
    tube((0, 0.42, 0.21), HINGE + dv * 0.25 - nv * 0.05, 0.02)
    # 前端腳踝滾筒（兩顆）＋橫桿
    pcyl('chrome', (0, -0.47, 0.22), 0.012, 0.42, (1, 0, 0), n=12)
    tube((0, -0.47, 0.10), (0, -0.47, 0.22), 0.02)
    for sx in (1, -1): pcyl('pad', (0.12 * sx, -0.47, 0.22), 0.055, 0.17, (1, 0, 0), bevel=0.012)
    # 立柱＋頂部滑輪盒
    pbox('frame', (0, POST_Y, POST_TOP / 2), (0.032, 0.032, POST_TOP / 2), 0.006)
    pbox('frame', (0, POST_Y + 0.02, POST_TOP - 0.03), (0.05, 0.085, 0.07), 0.02)
    for sx in (1, -1): pcyl('frame', (0.05 * sx, POST_Y + 0.02, POST_TOP - 0.03), 0.07, 0.01, (1, 0, 0), n=32)
    pcyl('chrome', (0, POST_Y + 0.02, POST_TOP - 0.03), 0.02, 0.11, (1, 0, 0), n=12)
    # 槓片收納柱：兩側、兩層，各掛兩片槓片＋紅色星形螺帽
    for z_ in (0.98, 0.66):
        for sx in (1, -1):
            pcyl('frame', (0.11 * sx, POST_Y, z_), 0.018, 0.16, (1, 0, 0), n=12)
            for i_, x_ in enumerate((0.075, 0.105)):
                pcyl('plate', (x_ * sx, POST_Y, z_), 0.115 - i_ * 0.012, 0.028, (1, 0, 0), n=32, bevel=0.006)
            pcyl('red', (0.15 * sx, POST_Y, z_), 0.032, 0.04, (1, 0, 0), n=6, bevel=0.004)

MOVE = os.environ.get('MOVE', 'squat')
CAM = dict(loc=(4.2, -3.9, 1.7), tgt=(0, 0, 0.95), lens=70, stage=(0, 0, 0.62))

# ======================= 啞鈴深蹲 =======================
if MOVE == 'squat':
    N = 48
    def pose(t):
        ts, tt, lam = D(38) * t, D(78) * t, D(36) * t
        hipmid = Vector((0, 0, 0)); J = {}
        for s, sx in SX:
            A = rest[f'shin.{s}'][1]
            K = A + blen[f'shin.{s}'] * Vector((0.035 * sx * t, -math.sin(ts), math.cos(ts)))
            Hj = K + blen[f'thigh.{s}'] * Vector((-0.02 * sx * t, math.sin(tt), math.cos(tt)))
            J[s] = (A, K, Hj); hipmid += Hj / 2
        _, sh = trunk(hipmid + Vector((0, 0, 0.04)), lam * 0.6, lam, lam * 0.15)
        for s, sx in SX:
            A, K, Hj = J[s]
            aim(f'thigh.{s}', Hj, K - Hj); aim(f'shin.{s}', K, A - K)
            aim(f'foot.{s}', A, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            d = Vector((0.03 * sx, -0.10 * t, -1))
            e = aim(f'upper_arm.{s}', sh[s], d); w = aim(f'forearm.{s}', e, d); aim(f'hand.{s}', w, d)
    for f in range(N):
        sc.frame_set(f); pose(ease(f / 24 if f <= 24 else (47 - f) / 23)); keyall(f)

# ======================= 伏地挺身 =======================
# 腳尖和手掌釘在地上，身體從腳尖到頭維持一直線（棒式），整條繞腳尖轉；手肘往後約 45 度。
elif MOVE == 'pushup':
    N = 48
    TOE_Y, FOOT = 0.72, 0.15
    WRIST_Z = 0.055
    def body(theta):
        u = Vector((0, -math.cos(theta), math.sin(theta)))          # 腳→頭
        n = Vector((0, -math.sin(theta), -math.cos(theta)))         # 垂直身體、朝地板
        lam = D(90) - theta
        J = {}
        for s, sx in SX:
            toe = Vector((HIPX[s] * 0.85, TOE_Y, 0.0))
            an = toe - n * FOOT
            hj = an + u * (blen[f'shin.{s}'] + blen[f'thigh.{s}'])
            J[s] = (toe, an, hj)
        hm = (J['L'][2] + J['R'][2]) / 2
        return u, n, lam, J, hm
    def shoulders_at(theta):
        u, n, lam, J, hm = body(theta)
        ctop = hm + u * 0.04 + RX(lam * 1.0) @ UP * blen['hips']
        return {s: ctop + RX(lam) @ (rest[f'upper_arm.{s}'][0] - rest['chest'][0]) for s in ('L', 'R')}
    def theta_for(h):
        lo, hi = 0.0, D(45)
        for _ in range(40):
            mid = (lo + hi) / 2
            if shoulders_at(mid)['L'].z < h: lo = mid
            else: hi = mid
        return (lo + hi) / 2
    reach = blen['upper_arm.L'] + blen['forearm.L']
    TH_TOP, TH_BOT = theta_for(WRIST_Z + reach * 0.985), theta_for(0.21)
    S_TOP = shoulders_at(TH_TOP)
    WRIST = {s: Vector((S_TOP[s].x * 1.18, S_TOP[s].y + 0.03, WRIST_Z)) for s in ('L', 'R')}
    def pose(t):
        th = TH_TOP + (TH_BOT - TH_TOP) * t
        u, n, lam, J, hm = body(th)
        _, sh = trunk(hm + u * 0.04, lam, lam, lam - D(12))
        for s, sx in SX:
            toe, an, hj = J[s]
            kn = an + u * blen[f'shin.{s}']
            aim(f'thigh.{s}', hj, kn - hj); aim(f'shin.{s}', kn, an - kn)
            aim(f'foot.{s}', an, toe - an)
            arm_to(s, sh[s], WRIST[s], Vector((0.75 * sx, 0.65, 0.0)), Vector((0.12 * sx, -1, -0.35)))
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 18, 4, 20)); keyall(f)
    CAM = dict(loc=(3.8, -1.3, 0.95), tgt=(0, 0.02, 0.32), lens=52, stage=(0, 0.15, 0.95))

# ======================= 高位下拉 =======================
# 坐在使用者的啞鈴椅上、面向前端立柱，腳踝勾在滾筒下；寬握直槓從前上方拉到上胸，手肘往下往後、上身後仰靠向靠背。
elif MOVE == 'pulldown':
    N = 48
    HIP_Z, HIP_Y = SEAT_Z + 0.085, 0.0
    GX = 0.40                                         # 握距（手腕 x）
    WHEEL = Vector((0, POST_Y + 0.09, POST_TOP - 0.03))  # 滑輪靠使用者那一側
    build_bench(24)                                    # 靠背往後倒 24 度，拉到底時背剛好靠上
    def lower(_t):
        for s, sx in SX:
            hj = Vector((HIPX[s], HIP_Y, HIP_Z))
            kn = hj + Vector((0.015 * sx, -blen[f'thigh.{s}'] * 0.985, -0.06))
            an = Vector((kn.x, -0.40, 0.12))                # 腳踝勾在滾筒後下方
            leg_to(s, hj, an, Vector((0, -1, 0.4)), Vector((0, -1, -0.15)))
        return Vector((0, HIP_Y, HIP_Z))
    def lean(t): return D(-6) + D(-18) * t
    def upper(t):
        hm = lower(t); lam = lean(t)
        return trunk(hm + Vector((0, 0, 0.04)), lam * 0.5, lam, lam - D(20) * (1 - t))
    # 起點：手臂幾乎打直、往前上方（立柱在前面，鋼索斜斜的）；終點：槓子到上胸
    cp0, sh0 = upper(0.0)
    reach = (blen['upper_arm.L'] + blen['forearm.L']) * 0.97
    BAR_Y0 = -0.27
    dx = GX - sh0['L'].x
    z0 = sh0['L'].z + math.sqrt(max(reach ** 2 - dx * dx - (BAR_Y0 - sh0['L'].y) ** 2, 0)) + 0.065
    P0 = Vector((0, BAR_Y0, z0))
    cp1, sh1 = upper(1.0)
    P1 = cp1((0, -0.17, 1.33)) + Vector((0, -0.06, 0.0))   # 上胸（鎖骨下方）
    # 配重：立柱前面（-Y）吊一支插銷掛槓片，拉下時升起
    load = bpy.data.objects.new('load', None); sc.collection.objects.link(load)
    LOAD_Y, LOAD_Z = POST_Y - 0.09, 0.22
    pcyl('chrome', (0, LOAD_Y, LOAD_Z + 0.16), 0.014, 0.40, n=12).parent = load
    for i, (r, dz) in enumerate(((0.115, 0.0), (0.115, 0.032), (0.10, 0.064))):
        pcyl('plate', (0, LOAD_Y, LOAD_Z + dz), r, 0.026, n=32, bevel=0.006).parent = load
    pcyl('red', (0, LOAD_Y, LOAD_Z + 0.095), 0.03, 0.03, n=6, bevel=0.004).parent = load
    cab1 = stretch('cable', 0.006); cab3 = stretch('cable', 0.006)
    # 下拉槓：中段直、兩端往下彎，握把包膠
    bar = bpy.data.objects.new('bar', None); sc.collection.objects.link(bar)
    parts_bar = [pcyl('chrome', (0, 0, 0), 0.014, 0.86, (1, 0, 0), n=12)]
    for sx in (1, -1):
        parts_bar.append(pcyl('chrome', (0.52 * sx, 0, -0.035), 0.014, 0.2, (sx, 0, -0.45), n=12))
        parts_bar.append(pcyl('rubber', (GX * sx, 0, 0), 0.019, 0.14, (1, 0, 0), n=12))
    parts_bar.append(pcyl('chrome', (0, 0, 0.03), 0.02, 0.06, n=12))
    for o_ in parts_bar: o_.parent = bar
    def pose(t):
        P = P0.lerp(P1, t) + Vector((0, -0.04 * math.sin(math.pi * t), 0))
        _, sh = upper(t)
        for s, sx in SX:
            wrist = Vector((GX * sx, P.y + 0.01, P.z - 0.065))
            arm_to(s, sh[s], wrist, Vector((sx * 1.0, 0.55, -0.7)), Vector((0, -0.12, 1)))
        return P
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 14, 6, 22); P = pose(t); keyall(f)
        bar.location = P; bar.keyframe_insert('location', frame=f)
        rise = P0.z - P.z
        load.location = (0, 0, rise); load.keyframe_insert('location', frame=f)
        key_stretch(cab1, WHEEL + Vector((0, 0.06, 0)), P + Vector((0, 0, 0.06)), f)
        key_stretch(cab3, WHEEL + Vector((0, -0.17, 0.0)), Vector((0, LOAD_Y, LOAD_Z + 0.36 + rise)), f)
    CAM = dict(loc=(4.0, -2.2, 1.45), tgt=(0, -0.12, 1.02), lens=58, stage=(0, -0.05, 1.0))

sc.frame_start, sc.frame_end = 0, N - 1
