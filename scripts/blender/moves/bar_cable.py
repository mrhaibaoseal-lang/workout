# 動作批次：單槓／滑輪（補動作庫缺的 3D 示範）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1、docs/3d-moves/inventory.md）。動作卡：docs/3d-moves/bar_cable.md
# 這裡 exec bench2.py（取 trunk_over、floor2 的身體座標系 bf_*、bench 的 grip／stat…）；那些檔的動作不會被啟動（MOVE 不同名）。
# MOVE_META 只能寫字面值（hero_proto.py 用 ast 讀）。
MOVE_META = {
    'pullup': {'angles': {'elbow': {'min': (35, 60), 'max': (165, 180)}, 'knee': (120, 175)}},
    'chinup': {'angles': {'elbow': {'min': (30, 60), 'max': (165, 180)}, 'knee': (120, 175)}},
    'hangingKnee': {'angles': {'elbow': (165, 180), 'hip': {'min': (55, 85), 'max': (160, 180)}, 'knee': {'min': (60, 110), 'max': (160, 180)}}},
    'highChop': {'angles': {'elbow': (90, 180), 'knee.L': (80, 105), 'trunk_lean': {'min': (0, 12), 'max': (18, 40)}}},
    'oneArmPulldown': {'lean_back': True, 'angles': {'elbow.R': {'min': (35, 75), 'max': (150, 178)}, 'uarm_vert.R': {'min': (0, 40), 'max': (140, 175)}}},
}
exec(open(os.path.join(_MDIR, 'bench2.py'), encoding='utf-8').read())

BZ = 2.30                                                   # 單槓高度（橫槓中心；一般門框單槓約 2.1～2.3 m）
REACH_ = UL + FL

def clav_delta(s, e_sh):
    """keyall 的鎖骨跟轉（moves3d.py shoulder_follow）會把肩膀抬高、往內；手舉過頭（懸吊）時最多約 7 cm。
    這裡用同一個公式預先算出位移，讓肩膀『抬完之後』剛好在想要的位置（手腕釘在槓上，肩膀被抬高手肘就會被硬壓彎）。e_sh＝上臂方向（肩→肘）"""
    cl = f'clavicle.{s}'; C = pb['chest'].matrix
    elev = e_sh.angle(-C.col[1].xyz.normalized()); phi = min(CLAV_MAX, max(0.0, elev - CLAV_START) * CLAV_RATIO)
    Mc0 = C @ pb['chest'].bone.matrix_local.inverted() @ pb[cl].bone.matrix_local
    c0 = Mc0.col[1].xyz.normalized()
    R = Matrix.Rotation(phi, 3, c0.cross(C.col[1].xyz.normalized()).normalized()) if phi > 0 else Matrix.Identity(3)
    return (R @ c0 - c0) * blen[cl]

def hang_trunk(sy, sz, lam_h, lam_c, lam_hd, W):
    """肩膀（抬完之後）中點在 (0, sy, sz)，手腕釘在 W={s: 位置}。回傳 (髖位置, 胸變換, 肩＝抬之前的位置)"""
    off = Vector((0, 0, 0))
    for _ in range(3):
        hh, cp, sh = trunk_over(Vector((0, sy, sz)) - off, lam_h, lam_c, lam_hd)
        ds = []
        for s, sx in SX:
            e = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], Vector((0.3 * sx, 0.3, -1)))
            ds.append(clav_delta(s, e - sh[s]))
        off = (ds[0] + ds[1]) / 2
    return hh, cp, sh

def lift_wrists(sh, wfun, poles):
    """手舉高時肩膀會被鎖骨抬起（見 clav_delta）：wfun(抬完之後的肩 {s: 位置}) → {s: 手腕}。迭代兩次讓手腕相對『抬完的肩』"""
    cur = dict(sh)
    for _ in range(2):
        W = wfun(cur)
        for s_, sx_ in SX:
            if s_ in W:
                e = ik2(sh[s_], W[s_], blen[f'upper_arm.{s_}'], blen[f'forearm.{s_}'], poles[s_]); cur[s_] = sh[s_] + clav_delta(s_, e - sh[s_])
    return W

def hang_legs(sh_h, lam_h, ankle_off, foot_dir, pole=Vector((0, -1, 0.0))):
    """吊著的雙腿：ankle_off＝腳踝相對髖關節的位置（左腿，右腿 x 鏡像）"""
    for s, sx in SX:
        hj = sh_h + RX(lam_h) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
        an = hj + Vector((ankle_off.x * sx, ankle_off.y, ankle_off.z))
        leg_to(s, hj, an, Vector((0.1 * sx, pole.y, pole.z)), foot_dir)

# ======================= 引體向上／反手引體（pullup／chinup） =======================
# 雙手握橫槓（pullup＝正握、比肩寬；chinup＝反握、約與肩同寬），手臂打直懸垂、膝蓋微彎、腳離地；
# 用背把胸口拉向橫槓（手肘往下往身體兩側收），下巴過槓；停一下，慢慢放回到手臂打直。
if MOVE in ('pullup', 'chinup'):
    N = 48
    CHIN = (MOVE == 'chinup')
    GX = 0.28 if CHIN else 0.36                              # 手腕 x（肩關節在 ±0.27）
    WZ = BZ - 0.065                                          # 手腕高度（手掌包住橫槓）
    build_pullbar(BZ)
    ROLL = D(-90) if CHIN else D(90)
    dy_top = 0.14 if CHIN else 0.17                          # 頂端肩膀在橫槓後方多少（反握胸口更貼槓）
    def pose(t):
        z_hang = WZ - math.sqrt(max((REACH_ * 0.998) ** 2 - (GX - 0.27) ** 2 - 0.04 ** 2, 0.01))
        z_top = WZ - 0.115
        sz = z_hang + (z_top - z_hang) * t
        sy = 0.04 + (dy_top - 0.04) * t
        lam = D(-2) - D(14) * t
        hh, cp, sh = hang_trunk(sy, sz, lam, lam - D(2) * t, lam - D(10) * t - D(4) * t, {s_: Vector((GX * sx_, 0.0, WZ)) for s_, sx_ in SX})
        hang_legs(hh, lam, Vector((0.05, 0.10 + 0.22 * t, -0.80 + 0.06 * t)), Vector((0, -0.3, -1)))
        for s, sx in SX:
            W = Vector((GX * sx, 0.0, WZ))
            pole = Vector((0.45 * sx, 0.15 - 0.6 * (1 if CHIN else 0) * t, -1))
            arm_to(s, sh[s], W, pole, Vector((0, -0.10, 1)), hand_roll=ROLL * (1 if s == 'L' else -1))
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 18, 4, 22)); keyall(f)
    CAM = dict(loc=(3.6, -2.4, 1.7), tgt=(0, 0.05, 1.45), lens=46, stage=(0, 0.1, 0.9))

# ======================= 懸垂舉膝（hanging_knee） =======================
# 雙手握橫槓（正握、與肩同寬）、手臂打直懸垂、肩膀往下沉（不聳肩）。用腹部把骨盆往上捲、膝蓋往胸口抬到大腿約過水平（髖約 70°），
# 小腿自然垂下（膝約 90°）；頂端停一下，慢慢放回、不甩動、不晃。
if MOVE == 'hangingKnee':
    N = 48
    GX = 0.30; WZ = BZ - 0.065
    build_pullbar(BZ)
    def pose(t):
        sz = WZ - math.sqrt(max((REACH_ * 0.998) ** 2 - (GX - 0.27) ** 2 - 0.03 ** 2, 0.01))
        lam_h = D(-2) - D(30) * t                           # 骨盆往後捲（腹部收縮）
        lam_c = D(-2) - D(6) * t
        hh, cp, sh = hang_trunk(0.03, sz, lam_h, lam_c, lam_c + D(-2), {s_: Vector((GX * sx_, 0.0, WZ)) for s_, sx_ in SX})
        phi_t = D(4) + D(104) * t                           # 大腿離垂直往前抬：4° → 108°（過水平一點）
        flex = D(8) + D(92) * t                             # 膝蓋彎曲：8° → 100°
        for s, sx in SX:
            hj = hh + RX(lam_h) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
            kn = hj + Vector((0, -math.sin(phi_t), -math.cos(phi_t))) * blen[f'thigh.{s}']
            phi_s = phi_t - flex
            an = kn + Vector((0, -math.sin(phi_s), -math.cos(phi_s))) * blen[f'shin.{s}']
            leg_to(s, hj, an, Vector((0.05 * sx, -1, 0.25)), Vector((0, -0.4, -1)).lerp(Vector((0, -0.2, -1)), t))
        for s, sx in SX:
            arm_to(s, sh[s], Vector((GX * sx, 0.0, WZ)), Vector((0.3 * sx, 0.3, -1)), Vector((0, -0.10, 1)), hand_roll=D(90) * (1 if s == 'L' else -1))
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 5, 20)); keyall(f)
    CAM = dict(loc=(3.6, -2.4, 1.6), tgt=(0, 0.0, 1.35), lens=46, stage=(0, 0.1, 0.9))

# ======================= 高位滑輪下劈（cable_high_chop） =======================
# 標準是跪姿（單膝跪）、滑輪在高處、雙手握繩在外側肩膀上方，沿對角線往對側髖外側下劈；身體像砍柴一樣轉動，手臂近乎伸直。
# 這台只有高位滑輪：把整台機器轉 -90°，人跪在椅子旁邊（靠立柱那一側的右膝著地、左腳在前，膝蓋約 90°），雙手握三頭繩，
# 從右肩上方（靠滑輪那側）往左髖外側下劈，上身同時往左轉、微微前彎；髖不動。
if MOVE == 'highChop':
    N = 48
    HY, HZ = 0.88, 0.52
    stack, XF = bench_scene_rot(90, -90); rp = build_rope(); cbl = make_cables()
    WX = XF @ WHEEL_FRONT
    def pose(t):
        psi_c = D(-28) + D(52) * t                           # 胸朝向：右轉 28° → 左轉 24°
        psi_h = psi_c * 0.35
        lam = D(4) + D(18) * t
        def fm_of(psi, lm):
            fr = Vector((math.sin(psi), -math.cos(psi), 0)); up = Vector((0, 0, 1)) * math.cos(lm) + fr * math.sin(lm)
            return bf_frame(up, fr)
        hh = Vector((0, HY, HZ + 0.04))
        fmh, fmc = fm_of(psi_h, lam * 0.4), fm_of(psi_c, lam)
        sh, hj, ctop = bf_trunk(hh, fmh, fmc, fm_of(psi_c * 0.9, lam * 0.5))
        lt, fr, up = fmc
        for s, sx in SX:
            if s == 'L':                                     # 左腳在前（膝蓋約 90°）
                leg_to(s, hj[s], Vector((0.13, HY - 0.42, 0.11)), Vector((0.05, -1, 0.3)))
            else:                                            # 右膝著地、小腿貼地往後
                kn = Vector((-0.11, HY + 0.02, 0.085)); an = Vector((-0.11, HY + 0.43, 0.10))
                leg_to(s, hj[s], an, Vector((0, -1, -0.1)), Vector((0, 0.85, -0.5)))
        d0 = Vector((-0.22, 0.62, 0.75)).normalized(); d1 = Vector((0.05, 0.75, -0.65)).normalized()      # 手相對肩膀中點的方向（胸座標：左、前、上）
        dd = d0.lerp(d1, t).normalized()
        poles = {s_: Vector((0.3 * sx_, 0.5, -1)) for s_, sx_ in SX}
        def rad(dd):                                         # 手離肩膀中點多遠：讓離得比較遠的那隻手臂剛好伸到 99%、近的那隻略彎
            rs = []
            for sx_ in (1, -1):
                pv = Vector((0.27 * sx_, 0, 0)); dp = dd.dot(pv)
                rs.append(dp + math.sqrt(max(dp * dp - pv.length_squared + (REACH_ * 0.99) ** 2, 0)))
            return min(rs)
        def wf(cur):
            mid = (cur['L'] + cur['R']) / 2
            ctr = mid + lt * dd.x * 0.0 + (lt * dd.x + fr * dd.y + up * dd.z) * rad(dd)
            return {s_: ctr + lt * 0.05 * sx_ for s_, sx_ in SX}
        W = lift_wrists(sh, wf, poles)
        for s, sx in SX:
            e0 = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], poles[s])
            arm_to(s, sh[s], W[s], poles[s], (W[s] - e0).normalized())
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 18)); keyall(f)
        cp_ = key_rope(rp, f, WX, clip_len=0.34); key_cables(cbl, stack, f, WX, cp_, XF)
    CAM = dict(loc=(3.5, -1.3, 1.2), tgt=(-0.1, 0.65, 0.85), lens=52, stage=(-0.05, 0.7, 0.9))

# ======================= 單手高位下拉（cable_one_arm_pulldown） =======================
# 標準是跪姿（單膝跪）、滑輪在高處、單手握 D 型把手，身體微後仰，從手臂在頭上方前伸，把手肘往下往身體側邊拉到把手在肩旁；另一手扶膝。
# 這台是椅子和立柱一體的機器，跪在滑輪下面做不到：改成坐在椅子上（和 pulldown 一樣：靠背後倒 24°、腳勾滾筒），右手握 D 把手單手下拉，左手扶左大腿。
if MOVE == 'oneArmPulldown':
    N = 48
    HIP_Z, HIP_Y = SEAT_Z + 0.10, 0.0
    stack, XF = bench_scene(24); dh = build_dhandle(); cbl = make_cables()
    def pose(t):
        for s, sx in SX:
            hj = Vector((HIPX[s], HIP_Y, HIP_Z))
            kn = hj + Vector((0.015 * sx, -blen[f'thigh.{s}'] * 0.985, -0.06))
            an = Vector((kn.x, -0.40, 0.12))
            leg_to(s, hj, an, Vector((0, -1, 0.4)), Vector((0, -1, -0.15)))
        lam = D(-4) - D(14) * t
        cp, sh = trunk(Vector((0, HIP_Y, HIP_Z)) + Vector((0, 0, 0.04)), lam * 0.5, lam, lam * 0.35 - D(14) * (1 - t))
        s = 'R'; sx = -1
        d0 = Vector((0.03, -0.22, 0.97)).normalized()                                                  # 起點手舉在頭上方前面
        pole = Vector((0.25 * sx, 0.35, -0.2)).lerp(Vector((0.1 * sx, 1.0, -0.9)), t)
        def wf(cur):
            w0 = cur[s] + d0 * (REACH_ * 0.995)
            w1 = cur[s] + Vector((-0.02, -0.21, -0.22))                                                # 終點手在肩旁（上臂往下收）
            return {s: w0.lerp(w1, t)}
        wrist = lift_wrists(sh, wf, {s: pole})[s]
        e0 = ik2(sh[s], wrist, blen['upper_arm.R'], blen['forearm.R'], pole)
        arm_to(s, sh[s], wrist, pole, (wrist - e0).normalized())
        wl = Vector((HIPX['L'] + 0.03, -0.18, HIP_Z + 0.13))                                           # 左手扶大腿
        arm_to('L', sh['L'], wl, Vector((0.6, 0.2, -0.3)), Vector((0, -1, -0.3)))
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 18, 6, 20)); keyall(f)
        G, hz = hand_grip_frame('R')
        cp_ = key_dhandle(dh, f, 'R', WHEEL_FRONT); key_cables(cbl, stack, f, WHEEL_FRONT, cp_)
    CAM = dict(loc=(4.0, -2.2, 1.45), tgt=(0, -0.12, 1.1), lens=58, stage=(0, -0.05, 1.0))
