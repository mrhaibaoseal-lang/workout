# 動作批次：地板徒手。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡：docs/3d-moves/floor.md
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    'pushup': {},
    # angles：動作卡 docs/3d-moves/floor.md 的角度範圍（寫法見 scripts/blender/README.md；範圍照卡片，不照量到的值）。
    'plank': {'angles': {'elbow': (80, 100), 'hip': (165, 180), 'knee': (170, 180), 'trunk_lean': (72, 90), 'uarm_vert': (0, 20)}},
    'pikePushup': {'angles': {'elbow': {'min': (85, 105), 'max': (165, 180)}, 'hip': (70, 105), 'knee': (165, 180), 'trunk_lean': (110, 145)}},
    'reverseCrunch': {'lean_back': True, 'angles': {'knee': (85, 100), 'hip': {'min': (45, 60), 'max': (85, 95)}, 'trunk_lean': (85, 95), 'elbow': (165, 180)}},
    'deadBug': {'lean_back': True, 'angles': {'hip': {'min': (85, 95), 'max': (160, 178)}, 'knee': {'min': (85, 95), 'max': (160, 178)}, 'trunk_lean': (85, 95), 'elbow': (165, 180)}},
    'legCurl': {'angles': {'knee': {'min': (75, 95), 'max': (140, 165)}, 'hip': (160, 180), 'trunk_lean': (85, 95)}},
    'floorPress': {'bell': True, 'lean_back': True, 'angles': {'elbow': {'min': (65, 85), 'max': (165, 178)}, 'uarm_trunk': {'min': (45, 60)}, 'knee': (85, 105), 'trunk_lean': (85, 95)}},
}

# ======================= 伏地挺身 =======================
# 腳尖和手掌釘在地上，身體從腳尖到頭維持一直線（棒式），整條繞腳尖轉；手肘往後約 45 度。
if MOVE == 'pushup':
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


# ---------- 趴姿共用（plank、pikePushup 用；pushup 的程式不動） ----------
def pr_body(theta, toe_y=0.72, foot=0.15, toe_z=0.0):
    """棒式身體：腳尖釘在地上，整條繞腳尖轉，theta＝身體離地板的角度。回傳 (u 腳→頭, n 垂直身體朝地板, lam 軀幹前傾角, J 左右(腳尖,腳踝,髖), 兩髖中心)"""
    u = Vector((0, -math.cos(theta), math.sin(theta)))
    n = Vector((0, -math.sin(theta), -math.cos(theta)))
    lam = D(90) - theta
    J = {}
    for s, sx in SX:
        toe = Vector((HIPX[s] * 1.0, toe_y, toe_z))
        an = toe - n * foot
        hj = an + u * (blen[f'shin.{s}'] + blen[f'thigh.{s}'])
        J[s] = (toe, an, hj)
    return u, n, lam, J, (J['L'][2] + J['R'][2]) / 2

def pr_shoulders(theta, **kw):
    u, n, lam, J, hm = pr_body(theta, **kw)
    ctop = hm + u * 0.04 + RX(lam) @ UP * blen['hips']
    return {s: ctop + RX(lam) @ (rest[f'upper_arm.{s}'][0] - rest['chest'][0]) for s in ('L', 'R')}

def pr_theta_for(h, **kw):
    """左肩高度 h 時的身體角度（二分法）"""
    lo, hi = 0.0, D(60)
    for _ in range(40):
        mid = (lo + hi) / 2
        if pr_shoulders(mid, **kw)['L'].z < h: lo = mid
        else: hi = mid
    return (lo + hi) / 2

UL_, FL_ = blen['upper_arm.L'], blen['forearm.L']

# ---------- 仰躺共用（頭朝 +y、腳朝 -y，和 bench.py／lunge_bridge.py 一樣；反向捲腹、死蟲、地板臥推用） ----------
def fl_aimz(name, head, ydir, zhint):
    """像 aim，但骨頭的 z 軸（手：啞鈴握把方向）照 zhint"""
    yv = ydir.normalized(); zv = (zhint - yv * zhint.dot(yv)).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def fl_hold(s, sh, wrist, pole, fingers, axis):
    """手腕釘在 wrist，手指朝 fingers，握把軸 axis（手的 z 軸）"""
    e = ik2(sh, wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
    aim(f'upper_arm.{s}', sh, e - sh); aim(f'forearm.{s}', e, wrist - e); fl_aimz(f'hand.{s}', wrist, fingers, axis)
    _PIN[s] = (wrist.copy(), pole.copy())

def fl_lying(psi=0.0, ctop_y=0.19):
    """仰躺：胸從 (0, ctop_y, 0.155) 起平貼地板（頭枕地）；骨盆繞腰（胸與骨盆的接點）往後捲 psi 弧度（髖部離地、尾椎翹起）。
    回傳 (髖骨頭, 肩位置, 髖關節位置 {L,R})"""
    lam_p = -D(90) - psi
    ctop = Vector((0, ctop_y, 0.155))
    hh = ctop - RX(lam_p) @ UP * blen['hips']
    _, sh = trunk(hh, lam_p, -D(90), -D(76))
    J = {s: hh + RX(lam_p) @ (rest[f'thigh.{s}'][0] - rest['hips'][0]) for s, _ in SX}
    return hh, sh, J

def fl_follow_loop(place, n=2):
    """手臂舉高後鎖骨會自動上轉（keyall 裡做），肩膀因此移位、釘住手腕的手臂會被拉彎。
    place(post)：post＝鎖骨上轉後的肩位置 {L,R}（第一輪是 None＝用名義位置）。擺好手臂→shoulder_follow→量肩→重擺，讓手臂照設計伸直"""
    post = None
    for _ in range(n):
        place(post); shoulder_follow()
        post = {s: pb[f'upper_arm.{s}'].head.copy() for s in ('L', 'R')}

def fl_leg(s, sx, hj, d, knee_deg):
    """大腿方向 d（單位向量，在 y-z 平面為主）、膝蓋內角 knee_deg（往身體後側彎）；腳踝平放（腳背朝大腿前面）。回傳腳踝位置"""
    d = d.normalized(); p = Vector((0, d.z, -d.y))
    ka = D(knee_deg)
    k = hj + d * blen[f'thigh.{s}']
    sd = -d * math.cos(ka) - p * math.sin(ka)
    an = k + sd * blen[f'shin.{s}']
    fd = d * math.sin(ka) - p * math.cos(ka)
    aim(f'thigh.{s}', hj, k - hj); aim(f'shin.{s}', k, an - k); aim(f'foot.{s}', an, fd)
    return an

def fl_arm_floor(s, sx, sh, out=0.33):
    """手臂伸直放在身體兩側地板上（手掌朝下）：手腕在 (out*sx, ?, 0.05)"""
    reach = (blen[f'upper_arm.{s}'] + blen[f'forearm.{s}']) * 0.997
    dy = math.sqrt(max(reach ** 2 - (out - abs(sh.x)) ** 2 - (sh.z - 0.05) ** 2, 0.01))
    wrist = Vector((out * sx, sh.y - dy, 0.05))
    arm_to(s, sh, wrist, Vector((0.6 * sx, 0.0, 1.0)), Vector((0.02 * sx, -1, -0.10)))

# ======================= 平板支撐（前臂版；App：plank） =======================
# 前臂平放地板、手肘在肩膀正下方，腳尖著地；耳、肩、髖、膝、踝成一直線，只有輕微的呼吸起伏（上半身 ±1°）。
if MOVE == 'plank':
    N = 48
    EZ = 0.052                                   # 手肘關節離地（前臂厚度）
    TOE_Z = 0.055                                # 鞋底比腳骨頭尾端低約 5.7 cm：抬高這麼多，整個人才不會被接地修正再往上抬
    TH = pr_theta_for(EZ + UL_ * 0.975, toe_z=TOE_Z)
    S0 = pr_shoulders(TH, toe_z=TOE_Z)
    def pose(ph):
        u, n, lam, J, hm = pr_body(TH, toe_z=TOE_Z)
        _, sh = trunk(hm + u * 0.04, lam, lam + D(1.2) * ph, lam - D(10))
        for s, sx in SX:
            toe, an, hj = J[s]
            kn = an + u * blen[f'shin.{s}']
            aim(f'thigh.{s}', hj, kn - hj); aim(f'shin.{s}', kn, an - kn)
            aim(f'foot.{s}', an, toe - an)
        def arms(post):
            for s, sx in SX:
                b = post[s] if post else S0[s]
                wrist = Vector((b.x, b.y - FL_ * 0.99, EZ))
                arm_to(s, S0[s], wrist, Vector((0.1 * sx, 0.0, -1.0)), Vector((0.02 * sx, -1, -0.12)))
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(math.sin(2 * math.pi * f / N)); keyall(f)
    CAM = dict(loc=(3.7, -1.5, 0.85), tgt=(0, -0.15, 0.28), lens=55, stage=(0, -0.15, 1.1))

# ======================= 屈體伏地挺身（App：pike_pushup） =======================
# 倒 V 字：腳尖著地、手掌撐地、髖最高；手臂和腿接近伸直。下去時肩膀垂直往下、手肘彎到約 90°，頭頂往兩手前緣靠近（離地約 4～5 cm 就停）。
# 做法：軀幹是「髖中心→肩」一根 0.48 m 的桿子；腳踝和手腕釘住，肩膀沿一條路徑往下，髖用兩個圓的交點解（腿長 0.83 m、桿長 0.48 m）。
if MOVE == 'pikePushup':
    N = 48
    A_Y, A_Z, A_X = 0.38, 0.135, 0.17              # 腳踝（腳跟微抬：腳掌和地板夾 40°，腳尖剛好在地板）
    W_Y, W_Z, W_X = -0.70, 0.055, 0.30             # 手腕（手掌平貼地板、略比肩寬）
    LEG = (blen['thigh.L'] + blen['shin.L']) * 0.995
    TORSO = 0.48                                   # 髖中心到肩關節（矢狀面）
    def pk_hip(Sy, Sz):
        """兩個圓（腳踝半徑 LEG、肩半徑 TORSO）的上方交點 → 髖中心 (y, z)"""
        dy, dz = Sy - A_Y, Sz - A_Z; Dd = math.hypot(dy, dz)
        a = (LEG * LEG - TORSO * TORSO + Dd * Dd) / (2 * Dd); h = math.sqrt(max(LEG * LEG - a * a, 0))
        ux, uz = dy / Dd, dz / Dd
        return A_Y + a * ux + h * uz, A_Z + a * uz - h * ux
    def pk_shoulder(t):
        d = 0.526 + (0.395 - 0.526) * t; al = D(64 + (56 - 64) * t)
        return W_Y + d * math.cos(al), W_Z + d * math.sin(al)
    def pk_place(Sy, Sz):
        """肩（名義位置）在 (Sy, Sz) 時擺好全身；回傳名義的左肩位置"""
        Hy, Hz = pk_hip(Sy, Sz)
        lam = math.atan2(-(Sy - Hy), Sz - Hz)                       # 軀幹前傾角（髖→肩）
        hm = Vector((0, Hy, Hz))
        _, sh = trunk(hm + RX(lam) @ UP * 0.04, lam, lam, lam + D(4))
        for s, sx in SX:
            hj = hm + Vector((HIPX[s], 0, 0)); an = Vector((A_X * sx, A_Y, A_Z))
            leg_to(s, hj, an, Vector((0.05 * sx, -1.0, 0.0)), Vector((0, -math.cos(D(40)), -math.sin(D(40)))))
            wrist = Vector((W_X * sx, W_Y, W_Z))
            arm_to(s, sh[s], wrist, Vector((0.5 * sx, 1.0, 0.15)), Vector((0.02 * sx, -1, -0.12)))
        return sh['L']
    def pose(t):
        # 手臂舉過 60° 之後鎖骨會自動上轉（keyall 裡做），肩膀因此往頭的方向（這個姿勢是往前下）移幾公分 →
        # 先擺一次、量鎖骨造成的位移，再把名義肩位置反向補償，讓最後的肩膀落在路徑上（手臂才會在頂端伸直、底部彎約 90°）
        Sy, Sz = pk_shoulder(t); dy = dz = 0.0
        for _ in range(3):
            nom = pk_place(Sy - dy, Sz - dz)
            shoulder_follow()
            post = pb['upper_arm.L'].head
            dy, dz = post.y - nom.y, post.z - nom.z
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 15)); keyall(f)
    CAM = dict(loc=(3.4, -2.0, 0.95), tgt=(0, 0.0, 0.42), lens=58, stage=(0, 0.0, 0.95))

# ======================= 反向捲腹（App：reverse_crunch） =======================
# 仰躺、雙手放身體兩側地板；起點：大腿垂直、膝蓋彎 90°（小腿與地板平行）；用下腹把骨盆往肋骨方向捲起（骨盆後傾），
# 髖部離地約 10 cm、膝蓋靠向胸口，只有下背和骨盆離地，上背和頭一直貼地；膝蓋角度維持約 90°；慢慢放回。
if MOVE == 'reverseCrunch':
    N = 48
    def pose(t):
        hh, sh, J = fl_lying(psi=D(34) * t)
        al = D(40) * t
        for s, sx in SX:
            d = Vector((0.07 * sx, math.sin(al), math.cos(al)))
            fl_leg(s, sx, J[s], d, 92)
            fl_arm_floor(s, sx, sh[s])
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 3, 22)); keyall(f)
    CAM = dict(loc=(3.2, -1.4, 0.95), tgt=(0, 0.12, 0.38), lens=52, stage=(0, 0.12, 1.0))

# ======================= 死蟲（App：dead_bug） =======================
# 仰躺、雙手向天花板伸直、髖膝各彎 90°（桌面姿勢），下背貼地。對側的手和腳同時慢慢伸出去（右手過頭＋左腳伸直，再換邊），
# 手腳都在離地約 10 cm 處懸空不碰地，軀幹和骨盆全程不動（下背不離地）。48 格＝每邊 24 格（約 2 秒）。
if MOVE == 'deadBug':
    N = 48
    def prof(f):
        g = f % 24
        return profile(g, 24, 10, 3, 9)
    def pose(f):
        hh, sh, J = fl_lying()
        side_a = f < 24                                   # 前半：右手＋左腳；後半：左手＋右腳
        e = prof(f)
        dirs = {}
        for s, sx in SX:
            ext_arm = (s == 'R') if side_a else (s == 'L')
            ext_leg = (s == 'L') if side_a else (s == 'R')
            ea = e if ext_arm else 0.0; el = e if ext_leg else 0.0
            g = D(84) * ea
            dirs[s] = Vector((0.02 * sx, math.sin(g), math.cos(g))).normalized()
            gam = D(84) * el
            fl_leg(s, sx, J[s], Vector((0.07 * sx, -math.sin(gam), math.cos(gam))), 90 + 82 * el)
        def arms(post):
            for s, sx in SX:
                base = post[s] if post else sh[s]
                wrist = base + dirs[s] * ((blen[f'upper_arm.{s}'] + blen[f'forearm.{s}']) * 0.997)
                arm_to(s, sh[s], wrist, Vector((1.0 * sx, 0.0, 0.0)), dirs[s], 0.0)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.3, -1.5, 0.95), tgt=(0, 0.12, 0.32), lens=50, stage=(0, 0.12, 1.2))

# ======================= 啞鈴地板臥推（App：floor_press） =======================
# 仰躺在地板、膝蓋彎約 95° 雙腳踩地（保護下背），手持啞鈴：頂端手臂在肩膀正上方伸直；下放到上臂輕觸地板（手肘離身體約 45～50°，前臂垂直）停一下，再推起。
if MOVE == 'floorPress':
    N = 48
    UL, FL = blen['upper_arm.L'], blen['forearm.L']
    X_, Y_, Z_ = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
    EZ = 0.075                                          # 手肘關節離地（上臂厚度）
    TC = 0.40
    hj0 = Vector((0, 0.45 - TC, 0.155)) + Vector((0, 0.0, -0.04))
    d_ = 2 * blen['thigh.L'] * math.sin(D(95) / 2)
    FOOT_Y = hj0.y - math.sqrt(max(d_ * d_ - (hj0.z - 0.11) ** 2, 0.0))
    def pose(t):
        hh, sh, J = fl_lying()
        for s, sx in SX:
            an = Vector((0.17 * sx, FOOT_Y, 0.11))
            leg_to(s, J[s], an, Vector((0.25 * sx, -0.6, 1.0)))
        reach = (UL + FL) * 0.995
        def arms(post):
            for s, sx in SX:
                S_ = post[s] if post else sh[s]
                ez = (EZ - S_.z) / UL
                hb = math.sqrt(1 - ez * ez); b = hb * 0.70; a = math.sqrt(max(hb * hb - b * b, 0))
                ed = Vector((a * sx, -b, ez)).normalized()
                e1 = S_ + ed * UL; w1 = e1 + Z_ * FL
                base = S_ + X_ * (-0.01 * sx) - Y_ * 0.06
                off = base - S_; dz = math.sqrt(max(reach ** 2 - off.x ** 2 - off.y ** 2, 0)) - off.z
                w0 = base + Z_ * dz
                w = w0.lerp(w1, t) + X_ * (sx * 0.05 * math.sin(math.pi * t))
                fl_hold(s, sh[s], w, ed, Vector((0, 0.0, 1.0)), X_)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 15)); keyall(f)
    CAM = dict(loc=(3.2, -1.3, 0.95), tgt=(0, 0.1, 0.36), lens=52, stage=(0, 0.1, 1.0))

# ======================= 啞鈴俯臥腿後彎舉（App：db_leg_curl；使用者 2026-11-25 定案：趴在一體機椅子上、整台轉 180°、兩腳夾一顆啞鈴） =======================
# 椅子轉 180°（立柱在 +y，人面朝下趴著、頭朝 -y，雙手平放在座墊兩側），靠背放平；膝蓋在座墊上、小腿懸空越過座墊前緣；
# 兩腳（腳弓）夾住一顆直立的啞鈴（握把垂直、槓片在腳的上下）。大腿貼墊不動、骨盆不抬；只有膝蓋彎：從約 150° 彎到約 85°（小腿接近垂直）再慢慢放下。
# 啞鈴是另做的道具（使用者的快鎖啞鈴：黑色槓片），不是角色的 bell 裝備部位（bell 綁在手骨頭上）；父物件叫 bar（clipcheck 不算夾在腳間的接觸）。
def fl_place_bench(back_deg, rotz_deg):
    """呼叫 build_bench（不改它），再把新增的物件整組掛到一個轉向的空物件上"""
    before = set(bpy.data.objects)
    build_bench(back_deg)
    root = bpy.data.objects.new('benchroot', None); sc.collection.objects.link(root)
    root.rotation_euler = (0, 0, D(rotz_deg))
    for o in bpy.data.objects:
        if o not in before and o.parent is None and o is not root: o.parent = root
    return root

def fl_build_dumbbell():
    """使用者的快鎖啞鈴（直立）：握把沿 z、上下各兩片黑色槓片＋紅色固定螺帽。回傳父物件 bar"""
    bar = bpy.data.objects.new('bar', None); sc.collection.objects.link(bar)
    own = [pcyl('chrome', (0, 0, 0), 0.018, 0.19, (0, 0, 1), n=12)]
    for sg in (1, -1):
        for zz, rr in ((0.10, 0.115), (0.128, 0.103)):
            own.append(pcyl('plate', (0, 0, zz * sg), rr, 0.028, (0, 0, 1), n=32, bevel=0.006))
        own.append(pcyl('red', (0, 0, 0.158 * sg), 0.03, 0.035, (0, 0, 1), n=6, bevel=0.004))
    for o_ in own: o_.parent = bar
    return bar

if MOVE == 'legCurl':
    N = 48
    fl_place_bench(90, 180)
    bpy.data.objects['stack'].location.z += 0.55           # 配重啞鈴組滑到立柱上方（拿走手邊那顆，也不擋小腿）
    bar = fl_build_dumbbell()
    ZS, YK, ALPHA = 0.625, -0.02, D(9)                    # 脊椎線高度、膝蓋 y、大腿略往下垂（座墊比靠背低 3 cm）
    LT, LS = blen['thigh.L'], blen['shin.L']
    def pose(t):
        K = D(150 + (85 - 150) * t); phi = math.pi - K          # 膝蓋內角、彎曲量
        hjy = YK - LT * math.cos(ALPHA)
        hh = Vector((0, hjy - 0.04, ZS))
        _, sh = trunk(hh, D(90), D(90), D(90) - D(8))
        th = phi - ALPHA                                        # 小腿離水平往上的角度
        ank = {}
        for s, sx in SX:
            hj = Vector((HIPX[s], hjy, ZS))
            kn = hj + Vector((-0.01 * sx, math.cos(ALPHA), -math.sin(ALPHA))).normalized() * LT
            sv = Vector((-0.085 * sx, math.cos(th), math.sin(th))).normalized()
            an = kn + sv * LS
            aim(f'thigh.{s}', hj, kn - hj); aim(f'shin.{s}', kn, an - kn); aim(f'foot.{s}', an, sv)
            ank[s] = (an, sv)
        # 雙手放在身體兩側、腰旁（手掌朝下，手肘約 100°；不去握頭枕的把手，手臂會穿過支架）
        for s, sx in SX:
            wrist = Vector((0.27 * sx, sh[s].y + 0.40, 0.50))
            arm_to(s, sh[s], wrist, Vector((1.0 * sx, -0.2, 0.4)), Vector((0.05 * sx, -1.0, -0.12)))
        # 啞鈴夾在兩腳弓之間（跟著小腿轉）
        mid = sum((ank[s][0] + ank[s][1] * 0.085 for s, _ in SX), Vector()) / 2
        sv = (ank['L'][1] + ank['R'][1]).normalized()
        axis = Vector((0, -sv.z, sv.y))
        bar.location = mid; bar.rotation_mode = 'QUATERNION'; bar.rotation_quaternion = UP.rotation_difference(axis)
        bar.keyframe_insert('location'); bar.keyframe_insert('rotation_quaternion')
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 15, 7, 22)); keyall(f)       # 向上彎 15 格（約 1.2 秒）、頂端停 7 格、慢放 22 格、起點停 4 格
    CAM = dict(loc=(3.6, -1.6, 1.15), tgt=(0, -0.3, 0.5), lens=52, stage=(0, -0.3, 1.3))
