# 動作批次：健身房器械（補動作庫缺的 3D 示範）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1、docs/3d-moves/inventory.md）。動作卡：docs/3d-moves/machine.md
# 使用者沒有這些機器 → 只做示範，卡片標「健身房動作」。器材畫在 props_machine.py（簡化機器：座墊、靠背、配重塊、握把＋槓桿管）。
# 這裡 exec bar_cable.py（取 hang_trunk／lift_wrists／clav_delta、bench 的 UL／FL…）；那些檔的動作不會被啟動（MOVE 不同名）。
# MOVE_META 只能寫字面值（hero_proto.py 用 ast 讀）。
MOVE_META = {
    'legPress': {'angles': {'knee': {'min': (80, 100), 'max': (155, 178)}, 'hip': {'min': (55, 95)}}},
    'legExtension': {'angles': {'knee': {'min': (80, 100), 'max': (160, 180)}}},
    'machineLegCurl': {'angles': {'knee': {'min': (65, 100), 'max': (150, 178)}}},
    'assistedPullup': {'angles': {'elbow': {'min': (35, 70), 'max': (160, 180)}}},
    'machineChestPress': {'angles': {'elbow': {'min': (65, 100), 'max': (155, 178)}, 'trunk_lean': (0, 15)}},
    'machineShoulderPress': {'angles': {'elbow': {'min': (65, 100), 'max': (155, 178)}, 'trunk_lean': (0, 15)}},
    'machineRearDelt': {'angles': {'elbow': (145, 178), 'uarm_flare': {'min': (0, 40), 'max': (65, 95)}}},
}
exec(open(os.path.join(_MDIR, 'bar_cable.py'), encoding='utf-8').read())

def sit_trunk(H, lam, head=0.0):
    """坐著的軀幹：髖關節 H、胸往前傾 lam（負＝靠後）。回傳 (chest_pt, 肩 {L,R})"""
    return trunk(H + Vector((0, 0, 0.04)), lam * 0.5, lam, lam * 0.35 + head)

def feet_flat(H, ankle_y=-0.46, ankle_x=0.17):
    for s, sx in SX:
        leg_to(s, Vector((HIPX[s], H.y, H.z)), Vector((ankle_x * sx, ankle_y, 0.11)), Vector((0.1 * sx, -1, 0.5)), Vector((0, -1, -0.15)))

def side_grips(H, dy=-0.06):
    """雙手握座墊兩側的握把（腿部機器用）"""
    for s, sx in SX:
        pbox('frame', (0.27 * sx, H.y + dy, H.z + 0.07), (0.012, 0.07, 0.012), 0.004)
        tube((0.27 * sx, H.y + dy + 0.07, H.z + 0.07), (0.27 * sx, H.y + dy + 0.07, 0.25), 0.014)

def side_hands(sh, H, dy=-0.06):
    for s, sx in SX:
        arm_to(s, sh[s], Vector((0.27 * sx, H.y + dy, H.z + 0.08)), Vector((0.8 * sx, 0.4, -0.5)), Vector((0, -1, -0.2)))

# ======================= 腿推機（leg_press；坐姿水平腿推機） =======================
# 坐在座墊、靠背後倒 25°，雙腳平放踏板（與肩同寬、踏板中間），膝蓋朝腳尖方向；膝蓋從伸直前（約 165°，不鎖死）慢慢彎到約 90°，再用腳掌全面推回去。髖不離開座墊。
if MOVE == 'legPress':
    N = 48
    H = Vector((0, 0.0, 0.50)); BACK = 25
    mach_seat(H, BACK, stack_y=0.80, stack_h=0.8)
    pl = bpy.data.objects.new('bar', None); sc.collection.objects.link(pl)
    for o_ in (pbox('plate', (0, 0, 0), (0.30, 0.02, 0.22), 0.01), pbox('rubber', (0, 0.021, 0), (0.28, 0.004, 0.2), 0.002),
               pbox('frame', (0, 0.06, -0.20), (0.04, 0.05, 0.14), 0.006)): o_.parent = pl
    pbox('frame', (0, -0.72, 0.09), (0.12, 0.50, 0.025), 0.008)                # 踏板滑軌
    pbox('frame', (0, -1.22, 0.30), (0.12, 0.03, 0.25), 0.008)
    side_grips(H, 0.0)
    def pose(t, f):
        th = D(168) + (D(88) - D(168)) * t
        cp, sh = sit_trunk(H, -D(BACK))
        side_hands(sh, H, 0.0)
        for s, sx in SX:
            d = math.sqrt(blen[f'thigh.{s}'] ** 2 + blen[f'shin.{s}'] ** 2 - 2 * blen[f'thigh.{s}'] * blen[f'shin.{s}'] * math.cos(th))
            ay = H.y - math.sqrt(max(d * d - 0.04 ** 2, 0.01))
            leg_to(s, Vector((HIPX[s], H.y, H.z)), Vector((0.17 * sx, ay, H.z + 0.04)), Vector((0.15 * sx, -0.3, 1.0)), Vector((0, -0.25, 1.0)))
        pl.location = (0, ay - 0.095, H.z + 0.08); pl.keyframe_insert('location', frame=f)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 18), f); keyall(f)
    CAM = dict(loc=(3.6, -2.6, 1.4), tgt=(0, -0.35, 0.7), lens=50, stage=(0, -0.3, 0.9))

# 以上腿推機的手：在 pose 之後補手（見下面 legPress 手臂）
# ======================= 腿伸展機（leg_extension） =======================
# 坐在座墊、靠背後倒 10°，膝蓋對準機器軸心，墊子壓在腳踝前面（脛骨下段），雙手握座墊兩側握把；大腿貼座墊不動，把小腿往上伸直到膝約 170°，停一下，慢慢放回到膝約 90°。
if MOVE == 'legExtension':
    N = 48
    H = Vector((0, 0.0, 0.50)); BACK = 10
    mach_seat(H, BACK, stack_y=0.70, stack_h=0.8)
    side_grips(H)
    padc = pcyl('pad', (0, 0, 0), 0.045, 0.34, (1, 0, 0), n=16); proot = bpy.data.objects.new('bar', None); sc.collection.objects.link(proot); padc.parent = proot
    lv = [stretch('frame', 0.016) for _ in (0, 1)]
    st_ = bpy.data.objects.new('bar', None); sc.collection.objects.link(st_)
    for o_ in lv: o_.parent = st_
    def pose(t):
        cp, sh = sit_trunk(H, -D(BACK))
        side_hands(sh, H)
        ph = D(5)
        tdir = Vector((0, -math.cos(ph), -math.sin(ph)))
        th = D(90) + D(82) * t; phi = th - D(90)
        kn = None
        for s, sx in SX:
            hj = Vector((HIPX[s], H.y, H.z)); kn = hj + tdir * blen[f'thigh.{s}']
            sd = Vector((0, -math.sin(phi), -math.cos(phi))); an = kn + sd * blen[f'shin.{s}']
            leg_to(s, hj, an, Vector((0, -0.2, 1.0)), Vector((0, -math.cos(phi), math.sin(phi))))
        sd = Vector((0, -math.sin(phi), -math.cos(phi))); fr = Vector((0, -math.cos(phi), math.sin(phi)))
        return kn + sd * 0.34 + fr * 0.075, kn
    for f in range(N):
        sc.frame_set(f); pc, kn = pose(profile(f, N, 20, 6, 20)); keyall(f)
        proot.location = pc; proot.keyframe_insert('location', frame=f)
        for sx, o_ in ((1, lv[0]), (-1, lv[1])): key_stretch(o_, Vector((0.22 * sx, kn.y + 0.05, kn.z - 0.06)), pc + Vector((0.17 * sx, 0, 0)), f)
    CAM = dict(loc=(3.6, -2.6, 1.3), tgt=(0, -0.3, 0.65), lens=50, stage=(0, -0.2, 0.9))

# ======================= 腿後彎舉機（machine_leg_curl；坐姿） =======================
# 坐在座墊、靠背後倒 8°，腿往前伸（膝約 170°），墊子在小腿下面（腳跟上方、阿基里斯腱附近），上面一塊壓住大腿的墊子；雙手握握把。把腳跟往下往後彎到膝約 85°，停一下，慢慢放回。
if MOVE == 'machineLegCurl':
    N = 48
    H = Vector((0, 0.0, 0.56)); BACK = 8
    mach_seat(H, BACK, stack_y=0.75, stack_h=0.8)
    side_grips(H)
    for sx in (1, -1):
        tube((0.19 * sx, -0.27, H.z + 0.09), (0.19 * sx, -0.46, 0.30), 0.016)
    pbox('pad', (0, -0.27, H.z + 0.095), (0.17, 0.10, 0.035), 0.02)                 # 大腿壓墊
    padc = pcyl('pad', (0, 0, 0), 0.045, 0.34, (1, 0, 0), n=16); proot = bpy.data.objects.new('bar', None); sc.collection.objects.link(proot); padc.parent = proot
    lv = [stretch('frame', 0.016) for _ in (0, 1)]
    st_ = bpy.data.objects.new('bar', None); sc.collection.objects.link(st_)
    for o_ in lv: o_.parent = st_
    def pose(t):
        cp, sh = sit_trunk(H, -D(BACK))
        side_hands(sh, H)
        tdir = Vector((0, -0.995, -0.10)).normalized()
        fl = D(8) + D(87) * t
        sd = Vector((0, -math.cos(fl), -math.sin(fl))); post = Vector((0, math.sin(fl), -math.cos(fl)))
        kn = None
        for s, sx in SX:
            hj = Vector((HIPX[s], H.y, H.z)); kn = hj + tdir * blen[f'thigh.{s}']
            leg_to(s, hj, kn + sd * blen[f'shin.{s}'], Vector((0, -0.2, 1.0)), Vector((0, -math.sin(fl), math.cos(fl))))
        return kn + sd * 0.34 + post * 0.075, kn
    for f in range(N):
        sc.frame_set(f); pc, kn = pose(profile(f, N, 20, 6, 20)); keyall(f)
        proot.location = pc; proot.keyframe_insert('location', frame=f)
        for sx, o_ in ((1, lv[0]), (-1, lv[1])): key_stretch(o_, Vector((0.22 * sx, kn.y - 0.02, kn.z - 0.22)), pc + Vector((0.17 * sx, 0, 0)), f)
    CAM = dict(loc=(3.6, -2.6, 1.3), tgt=(0, -0.3, 0.65), lens=50, stage=(0, -0.2, 0.9))

# ======================= 輔助引體機（assisted_pullup；跪墊） =======================
# 雙膝跪在可升降的跪墊上（配重幫忙抵銷體重；用更重的配重＝更輕鬆），雙手握上方握把（正握、比肩寬），手臂打直，肩膀下沉；用背把胸口拉向握把，下巴過握把，停一下，慢慢放回到手臂伸直。
# 這是跪姿，所以身體跟引體向上的差別只在下半身（小腿放在墊上）。
if MOVE == 'assistedPullup':
    N = 48
    GX = 0.36; WZ = BZ - 0.065; ROLL = D(90)
    build_pullbar(BZ, 0.0, 0.60)
    mach_stack(0.95, 1.6)
    pad = pbox('pad', (0, 0, 0), (0.20, 0.24, 0.035), 0.02); proot = bpy.data.objects.new('bar', None); sc.collection.objects.link(proot); pad.parent = proot
    arm_ = stretch('frame', 0.02); st_ = bpy.data.objects.new('bar', None); sc.collection.objects.link(st_); arm_.parent = st_
    def pose(t):
        z_hang = WZ - math.sqrt(max((REACH_ * 0.998) ** 2 - (GX - 0.27) ** 2 - 0.04 ** 2, 0.01))
        sz = z_hang + (WZ - 0.115 - z_hang) * t
        sy = 0.04 + (0.17 - 0.04) * t
        lam = D(-2) - D(14) * t
        hh, cp, sh = hang_trunk(sy, sz, lam, lam - D(2) * t, lam - D(10) * t - D(4) * t, {s_: Vector((GX * sx_, 0.0, WZ)) for s_, sx_ in SX})
        kz = None
        for s, sx in SX:
            hj = hh + RX(lam) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
            kn = hj + Vector((0, -0.07, -math.sqrt(blen[f'thigh.{s}'] ** 2 - 0.07 ** 2)))
            an = kn + Vector((0, math.sqrt(blen[f'shin.{s}'] ** 2 - 0.0 ** 2) * 0.99, -0.02))
            leg_to(s, hj, an, Vector((0, -1, -0.4)), Vector((0, 0.9, -0.35)))
            kz = kn
        for s, sx in SX:
            W = Vector((GX * sx, 0.0, WZ))
            arm_to(s, sh[s], W, Vector((0.45 * sx, 0.15, -1)), Vector((0, -0.10, 1)), hand_roll=ROLL * (1 if s == 'L' else -1))
        return kz
    for f in range(N):
        sc.frame_set(f); kn = pose(profile(f, N, 18, 4, 22)); keyall(f)
        proot.location = (0, kn.y + 0.12, kn.z - 0.075 - 0.035); proot.keyframe_insert('location', frame=f)
        key_stretch(arm_, Vector((0, 0.80, kn.z - 0.10)), Vector((0, kn.y + 0.30, kn.z - 0.10)), f)
    CAM = dict(loc=(3.6, -2.4, 1.7), tgt=(0, 0.05, 1.3), lens=46, stage=(0, 0.1, 0.9))

# ======================= 胸推機（machine_chest_press；坐姿） =======================
# 坐正、背靠墊（後倒 5°），握把調到胸口高度（約與腋下同高）、雙手中立握（掌心相對），手肘從約 90° 推到約 165°（不鎖死），肩胛後收貼住靠墊；停一下，慢慢放回到手肘約 90°。
if MOVE == 'machineChestPress':
    N = 48
    H = Vector((0, 0.0, 0.52)); BACK = 5
    mach_seat(H, BACK, stack_y=0.70, stack_h=1.2)
    hnd = {s: mach_handle() for s, _ in SX}
    for sx in (1, -1): tube((0.42 * sx, -0.95, 0.05), (0.42 * sx, -0.95, 1.20), 0.03)
    def pose(t):
        cp, sh = sit_trunk(H, -D(BACK))
        feet_flat(H)
        poles = {s_: Vector((0.7 * sx_, 0.5, -0.2)) for s_, sx_ in SX}
        def wf(cur):
            return {s_: Vector((0.25 * sx_, cur[s_].y - (0.34 + (REACH_ * 0.985 - 0.34) * t), cur[s_].z - 0.04)) for s_, sx_ in SX}
        W = lift_wrists(sh, wf, poles)
        for s, sx in SX:
            e0 = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], poles[s])
            arm_to(s, sh[s], W[s], poles[s], (W[s] - e0).normalized())
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 5, 20)); keyall(f)
        for s, sx in SX: key_handle(hnd[s], f, s, (Vector((0.42 * sx, -0.95, 1.05)), Vector((0.42 * sx, -0.95, 1.05))))
    CAM = dict(loc=(3.5, -2.4, 1.4), tgt=(0, -0.3, 0.95), lens=50, stage=(0, -0.3, 1.0))

# ======================= 肩推機（machine_shoulder_press；坐姿） =======================
# 坐正、背靠墊（後倒 8°），握把在肩膀旁（手肘約 90°、前臂垂直），往上推到手臂接近伸直（約 165°、握把在頭上方偏前），停一下，慢慢放回到手肘 90°；腰不往後挺、不聳肩。
if MOVE == 'machineShoulderPress':
    N = 48
    H = Vector((0, 0.0, 0.52)); BACK = 8
    mach_seat(H, BACK, back_h=0.95, stack_y=0.80, stack_h=1.5)
    hnd = {s: mach_handle() for s, _ in SX}
    def pose(t):
        cp, sh = sit_trunk(H, -D(BACK))
        feet_flat(H)
        poles = {s_: Vector((0.4 * sx_, 0.2, -1)) for s_, sx_ in SX}
        def wf(cur):
            out = {}
            for s_, sx_ in SX:
                x = (0.55 + (0.28 - 0.55) * t) * sx_
                z = cur[s_].z + 0.27 + (REACH_ * 0.985 - 0.27) * t
                out[s_] = Vector((x, cur[s_].y - 0.02, z))
            return out
        W = lift_wrists(sh, wf, poles)
        for s, sx in SX:
            e0 = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], poles[s])
            arm_to(s, sh[s], W[s], poles[s], (W[s] - e0).normalized())
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 18)); keyall(f)
        for s, sx in SX: key_handle(hnd[s], f, s, (Vector((0.62 * sx, 0.30, 1.30)), Vector((0.62 * sx, 0.30, 1.30))))
    CAM = dict(loc=(3.4, -2.6, 1.6), tgt=(0, 0.0, 1.15), lens=50, stage=(0, 0.0, 1.0))

# ======================= 反向飛鳥機（machine_rear_delt；面向機器、胸貼墊） =======================
# 面對機器坐著、胸口貼住胸墊（墊頂略低於腋下），雙手握把在身體前面與肩同高、手臂近乎伸直（手肘約 165°）；用後肩把手臂往兩側打開到和肩膀成一直線（略在胸線前），停一下，慢慢放回；肩膀不聳、腰不挺。
if MOVE == 'machineRearDelt':
    N = 48
    H = Vector((0, 0.0, 0.52))
    mach_seat(H, None, stack_y=0.95, stack_h=1.2)
    hnd = {s: mach_handle() for s, _ in SX}
    cp0, sh0 = sit_trunk(H, D(6))
    my = (sh0['L'].y + sh0['R'].y) / 2
    pori('pad', Vector((0, my - 0.16, sh0['L'].z - 0.12 - 0.26)), (0.17, 0.04, 0.26), Vector((0, 0, 1)), 0.025)     # 胸墊
    tube((0, my - 0.20, sh0['L'].z - 0.5), (0, my - 0.55, sh0['L'].z - 0.5), 0.03)
    pbox('frame', (0, my - 0.58, (sh0['L'].z - 0.1) / 2), (0.05, 0.05, (sh0['L'].z - 0.1) / 2), 0.01)
    def pose(t):
        cp, sh = sit_trunk(H, D(6))
        feet_flat(H, -0.40)
        phi = D(6) + D(76) * t
        B_ = D(12)
        for s, sx in SX:
            a = Vector((math.sin(phi) * sx, -math.cos(phi), -0.04)).normalized()
            e = sh[s] + a * UL
            bn = Vector((-math.cos(phi) * sx, -math.sin(phi), 0))          # 水平面內、垂直上臂、往前往內：手肘微彎往這邊
            fd = (a * math.cos(B_) + bn * math.sin(B_)).normalized()
            w = e + fd * FL
            aim(f'upper_arm.{s}', sh[s], e - sh[s]); aim(f'forearm.{s}', e, w - e); aim(f'hand.{s}', w, fd)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 24, 4, 20)); keyall(f)
        for s, sx in SX: key_handle(hnd[s], f, s, (Vector((0.10 * sx, my - 0.58, sh0['L'].z)), Vector((0.10 * sx, my - 0.58, sh0['L'].z))))
    CAM = dict(loc=(3.4, -2.8, 1.5), tgt=(0, my - 0.3, 1.05), lens=50, stage=(0, my - 0.2, 1.0))
