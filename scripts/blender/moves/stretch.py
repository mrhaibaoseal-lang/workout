# 動作批次：伸展。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡：docs/3d-moves/stretch.md
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    # angles：動作卡 docs/3d-moves/stretch.md 的角度範圍（寫法見 scripts/blender/README.md；範圍照卡片，不照量到的值）。
    # 左右同名的量＝兩邊都檢查；.L／.R 只檢查那一邊。伸展是停住＋呼吸，所以範圍就是「整段停留」的範圍。
    'chestStretch': {'angles': {'knee': (168, 180), 'trunk_lean': (0, 10), 'elbow': (165, 180), 'uarm_vert': (25, 50)}},
    'crossBody': {'angles': {'knee': (168, 180), 'trunk_lean': (0, 6), 'elbow.R': (165, 180), 'uarm_vert.R': (78, 100), 'elbow.L': (55, 130)}},
    'tricepsStretch': {'angles': {'knee': (168, 180), 'trunk_lean': (0, 6), 'uarm_vert.R': (140, 175), 'elbow.R': (40, 90)}},
    'childPose': {'angles': {'knee': (15, 50), 'hip': (15, 55), 'trunk_lean': (85, 120), 'elbow': (150, 180)}},
    'quadStretch': {'angles': {'knee.L': (168, 180), 'knee.R': (20, 60), 'hip.R': (160, 180), 'trunk_lean': (0, 8), 'elbow.L': (165, 180), 'elbow.R': (120, 180)}},
    'seatedFold': {'angles': {'knee': (165, 180), 'hip': (25, 65), 'trunk_lean': (35, 65)}},
    'kneeHug': {'lean_back': True, 'angles': {'knee.L': (168, 180), 'hip.L': (165, 180), 'knee.R': (25, 65), 'hip.R': (35, 65), 'trunk_lean': (80, 100)}},
    'calfStretch': {'angles': {'knee.R': {'min': (168, 180)}, 'knee.L': (110, 170), 'trunk_lean': (10, 30), 'elbow': (110, 180)}},
    'hipFlexor': {'angles': {'knee.L': (80, 105), 'knee.R': (85, 110), 'hip.R': (155, 180), 'trunk_lean': (0, 10)}},
    'cobra': {'angles': {'trunk_lean': (30, 60), 'hip': (120, 160), 'elbow': (70, 100), 'knee': (165, 180)}},
}

# ---------- 這批共用 ----------
# 伸展＝「停住的姿勢 ＋ 呼吸的小起伏」。48 格是一個呼吸循環（12 fps＝4 秒）：
#   第 0 格＝輕輕到位，吐氣加深一點（第 24 格最深），再放鬆回第 0 格；頭尾同一個姿勢，所以循環接得起來。
#   「進入」那段（從站姿走進姿勢）由 App 的切換處理，片段本身只有停住＋呼吸。
# 擺法照 floor.py／lunge_bridge.py：手腳釘點用 IK，軀幹用 trunk()（先擺軀幹、再擺腿）。
N = 48
def lerp(a, b, s): return a + (b - a) * s
def depth(f): return 0.5 - 0.5 * math.cos(2 * math.pi * f / N)     # 0（頭尾）→ 1（第 24 格）→ 0
def dbg(*a):
    if os.environ.get('DBG'): print('[DBG]', *a)

def arm_line(s, sh, u, hand=None):
    """手臂伸直沿 u 方向（不釘手腕；手跟著肩膀走）"""
    u = Vector(u).normalized(); e = sh + u * blen[f'upper_arm.{s}']; w = e + u * blen[f'forearm.{s}']
    aim(f'upper_arm.{s}', sh, u); aim(f'forearm.{s}', e, u); aim(f'hand.{s}', w, u if hand is None else Vector(hand))
    return e, w

def stand_base(hy=0.0, knee=174, fx=0.12, lam=(0.0, 0.0, 0.0), skip=()):
    """站姿：雙腳平放、膝蓋微彎（knee＝膝內角）。先軀幹再腿。回傳 (髖骨頭, 髖關節高, chest_pt, 肩位置)"""
    A = {s: Vector((fx * sx, hy, 0.11)) for s, sx in SX}
    hz = solve_hip_z(HIPX['L'], hy, A['L'], knee, Vector((0.12, -1, 0)))
    hh = Vector((0, hy, hz + 0.04))
    cp, sh = trunk(hh, *lam)
    for s, sx in SX:
        if s in skip: continue
        leg_to(s, Vector((HIPX[s], hy, hz)), A[s], Vector((0.12 * sx, -1, 0)))
    return hh, hz, cp, sh

def leg_pts(s, H, K, A, fdir):
    """腿的三個關節位置直接給（跪、坐、躺的姿勢用）：大腿 H→K、小腿 K→A、腳 A→fdir"""
    aim(f'thigh.{s}', H, K - H); aim(f'shin.{s}', K, A - K); aim(f'foot.{s}', A, Vector(fdir))

def hip_of(s, hh, lam_p):
    """骨盆骨頭頭 hh、骨盆前傾 lam_p 時，這一側的髖關節位置"""
    return hh + RX(lam_p) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])

def hh_from(Hm, lam_p):
    """已知兩髖關節中點 Hm → 骨盆骨頭頭"""
    return Hm + RX(lam_p) @ Vector((0, 0, rest['hips'][0].z - rest['thigh.L'][0].z))

def head_for(hh, lam_p, lam_c, zc):
    """頭骨中心高度 ＝ zc 的頭傾角 lam_h（頭趴低、靠地的動作用）。回傳 lam_h"""
    trunk(hh, lam_p, lam_c, lam_c)
    hb = pb['head'].head.copy()
    c = max(-1.0, min(1.0, (zc - hb.z) / (blen['head'] / 2)))
    return math.acos(c)

# ======================= 胸部伸展（站姿，雙手在背後交握、往後往上抬；ACE） =======================
if MOVE == 'chestStretch':
    def pose(f):
        s = depth(f)
        hh, hz, cp, sh = stand_base(knee=175, lam=(-D(1), -D(lerp(2, 6, s)), -D(lerp(1, 2, s))))
        for s_, sx in SX:
            e = D(lerp(26, 40, s))
            arm_line(s_, sh[s_], Vector((-0.40 * sx, math.sin(e), -math.cos(e))))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.9, -2.6, 1.3), tgt=(0, 0.05, 0.98), lens=58, stage=(0, 0, 0.62))

# ======================= 手臂橫跨胸前（站姿，右手臂伸直橫過胸前，左手托住手肘附近往身體拉） =======================
if MOVE == 'crossBody':
    def pose(f):
        s = depth(f)
        hh, hz, cp, sh = stand_base(knee=175)
        S = sh['R']
        T = Vector((lerp(0.15, 0.19, s), -0.27, S.z - 0.03))
        d = (T - S).normalized()
        arm_line('R', S, d)
        P = S + d * (blen['upper_arm.R'] * 0.95)                 # 左手托的位置：右上臂靠近手肘處
        W = P + Vector((0.10, -0.05, -0.11))
        arm_to('L', sh['L'], W, Vector((0.4, -0.4, -1.0)), P - W)
        dbg('crossBody L reach', (W - sh['L']).length)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.4, -3.0, 1.35), tgt=(0, -0.05, 1.05), lens=58, stage=(0, 0, 0.62))

# ======================= 過頭三頭伸展（站姿，右手臂舉過頭、手肘彎、手掌落到背後；左手把手肘往另一側拉） =======================
if MOVE == 'tricepsStretch':
    def pose(f):
        s = depth(f)
        hh, hz, cp, sh = stand_base(knee=175)
        S = sh['R']
        u = Vector((lerp(0.22, 0.20, s), lerp(0.34, 0.38, s), 0.90)).normalized()
        fd = Vector((lerp(0.50, 0.44, s), lerp(0.58, 0.60, s), -0.66)).normalized()
        e, w = arm_line('R', S, u, Vector((0, 0.3, -1)))
        e = S + u * blen['upper_arm.R']; w = e + fd * blen['forearm.R']
        aim('forearm.R', e, fd); aim('hand.R', w, Vector((0, 0.3, -1)))
        E = e + Vector((0, 0, 0.07))                                   # 鎖骨會把整條手臂再抬約 7 cm
        T = E + Vector((0.03, -0.19, -0.20))                          # 左手從前面托住右手肘下方
        arm_to('L', sh['L'], T, Vector((0.6, -0.4, -1.0)), Vector((-1, 0.4, 0.3)))
        dbg('triceps E', E, 'L reach', (T - sh['L']).length)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.4, -3.0, 1.45), tgt=(0, 0.0, 1.2), lens=60, stage=(0, 0, 0.62))

# ======================= 嬰兒式（跪、臀部往後坐在腳跟上、上身趴下、雙手往前伸） =======================
if MOVE == 'childPose':
    def pose(f):
        s = depth(f)
        KX = 0.24
        zh = lerp(0.25, 0.24, s)
        lam_p, lam_c = D(lerp(66, 70, s)), D(lerp(97, 99, s))
        th, sn = blen['thigh.L'], blen['shin.L']
        yh = math.sqrt(th ** 2 - (KX - 0.11) ** 2 - (zh - 0.07) ** 2)
        hh = hh_from(Vector((0, yh, zh)), lam_p)
        lam_h = head_for(hh, lam_p, lam_c, 0.215)
        cp, sh = trunk(hh, lam_p, lam_c, lam_h)
        dbg('childPose lam_h', math.degrees(lam_h), 'sh', sh['L'])
        for s_, sx in SX:
            H = Vector((0.11 * sx, yh, zh)); K = Vector((KX * sx, 0.0, 0.07))
            A = Vector((0.10 * sx, math.sqrt(sn ** 2 - (KX - 0.10) ** 2), 0.07))
            leg_pts(s_, H, K, A, Vector((0, 1, -0.12)))
            dx, dz = 0.20 - sh[s_].x * sx, 0.05 - sh[s_].z
            wy = sh[s_].y - 0.105 - math.sqrt(max(0.505 ** 2 - dx ** 2 - dz ** 2, 0.01))     # 鎖骨把肩膀往前推約 6 cm
            arm_to(s_, sh[s_], Vector((0.20 * sx, wy, 0.05)), Vector((0.5 * sx, 0.0, 1.0)), Vector((0, -1, -0.1)))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.6, -2.2, 0.95), tgt=(0, 0.0, 0.25), lens=55, stage=(0, 0.0, 0.95))

# ======================= 站姿大腿前側伸展（左腳站、右腳往後勾、右手抓腳；左手往前伸保持平衡） =======================
if MOVE == 'quadStretch':
    def pose(f):
        s = depth(f)
        hh, hz, cp, sh = stand_base(knee=177, lam=(-D(4), 0, 0), skip=('R',))
        HR = Vector((HIPX['R'], 0, hz))
        tdir = Vector((0.08, lerp(0.03, 0.12, s), -1)).normalized()
        K = HR + tdir * blen['thigh.R']
        b = D(lerp(36, 22, s)); sdir = Vector((0.0, math.sin(b), math.cos(b)))
        A = K + sdir * blen['shin.R']
        fdir = Vector((0.0, 0.40, 0.92)).normalized()
        aim('thigh.R', HR, K - HR); aim('shin.R', K, A - K); aim('foot.R', A, fdir)
        W = A + Vector((-0.13, 0.07, 0.03))
        arm_to('R', sh['R'], W, Vector((-0.5, 1.0, 0.0)), Vector((0.8, -0.1, 0.2)))
        arm_line('L', sh['L'], Vector((0.50, -0.60, -0.30)))
        dbg('quad R reach', (W - sh['R']).length, 'ankle', A)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.6, -3.0, 1.2), tgt=(0, 0.1, 0.8), lens=58, stage=(0, 0, 0.62))

# ======================= 坐姿體前彎（坐地板、雙腿往前伸直、從髖往前彎、手往腳的方向伸） =======================
if MOVE == 'seatedFold':
    def pose(f):
        s = depth(f)
        zh = 0.10
        lam_p, lam_c = D(lerp(36, 46, s)), D(lerp(44, 56, s))
        hh = hh_from(Vector((0, 0, zh)), lam_p)
        cp, sh = trunk(hh, lam_p, lam_c, lam_c + D(4))
        th, sn = blen['thigh.L'], blen['shin.L']
        shin = {}
        for s_, sx in SX:
            H = Vector((HIPX[s_], 0, zh))
            K = H + Vector((0.05 * sx, -1.0, 0.0)).normalized() * th
            A = K + Vector((0.02 * sx, -1.0, -0.13)).normalized() * sn
            leg_pts(s_, H, K, A, Vector((0, -0.3, 0.95)))
            shin[s_] = (K, A)
        for s_, sx in SX:
            K, A = shin[s_]
            u = 0.60
            while u > 0.15:
                Q = K + (A - K) * u + Vector((0, 0, 0.10))
                if (Q - sh[s_]).length <= 0.505: break
                u -= 0.02
            arm_to(s_, sh[s_], Q, Vector((0.5 * sx, -0.3, 0.8)), Vector((0, -1, -0.2)))
            dbg('seatedFold', s_, 'u', round(u, 2))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.7, -2.6, 1.0), tgt=(0, -0.35, 0.3), lens=55, stage=(0, -0.35, 1.05))

# ======================= 仰躺抱膝（躺平、右膝抱向胸口、左腿平放伸直；App：每邊做） =======================
# 躺法和臀橋一樣：頭朝 +Y、腳朝 -Y，臉朝上。
if MOVE == 'kneeHug':
    def pose(f):
        s = depth(f)
        ZC = 0.11
        lam = -D(90)
        hh = Vector((0, 0.0, ZC))
        cp, sh = trunk(hh, lam + D(2), lam, lam + D(14))
        HL, HR = hip_of('L', hh, lam + D(2)), hip_of('R', hh, lam + D(2))
        # 左腿：平放
        KL = HL + Vector((0.02, -1, -0.03)).normalized() * blen['thigh.L']
        AL = KL + Vector((0.0, -1, -0.06)).normalized() * blen['shin.L']
        leg_pts('L', HL, KL, AL, Vector((0, -0.25, 0.97)))
        # 右腿：大腿朝頭的方向抬起、膝蓋靠近胸口，小腿放鬆往腳的方向垂
        ph = D(lerp(44, 52, s))
        KR = HR + Vector((0.10, math.cos(ph), math.sin(ph))).normalized() * blen['thigh.R']
        sd = Vector((-0.03, -math.cos(D(10)), -math.sin(D(10))))
        AR = KR + sd.normalized() * blen['shin.R']
        leg_pts('R', HR, KR, AR, Vector((0, -0.5, 0.86)))
        shd = sd.normalized()
        for s_, sx in SX:
            Q = KR + shd * 0.10 + Vector((0.0, 0.0, 0.13))
            Q = Q + Vector((-0.17 if s_ == 'R' else 0.07, 0, 0))
            arm_to(s_, sh[s_], Q, Vector((0.7 * sx, 0.3, 0.3)), Vector((1 if s_ == 'R' else -1, 0, 0)))
            dbg('kneeHug', s_, 'reach', (Q - sh[s_]).length)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.4, -2.0, 1.0), tgt=(0, 0.0, 0.3), lens=52, stage=(0, 0.0, 1.0))

# ======================= 推牆小腿伸展（面對牆、雙手推牆、右腳在後伸直腳跟踩地、左膝彎） =======================
if MOVE == 'calfStretch':
    WALL_Y = -0.865
    build_stretch_wall(WALL_Y)
    YB = 0.16                                       # 後腳踝 y
    def pose(f):
        s = depth(f)
        al = D(lerp(18, 20, s))                     # 後腿（腳踝→髖）離垂直的角度
        AB = Vector((-0.11, YB, 0.11))
        Hb = AB + Vector((0, -math.sin(al), math.cos(al))) * ((blen['thigh.R'] + blen['shin.R']) * 0.9985)
        Hm = Vector((0.0, Hb.y, Hb.z))
        lam = al + D(2)
        hh = hh_from(Hm, lam)
        cp, sh = trunk(hh, lam, lam, lam - D(14))
        leg_to('R', Hb, AB, Vector((-0.12, -1, 0)))
        HF = hip_of('L', hh, lam)
        AF = Vector((0.11, -0.32, 0.11))
        leg_to('L', HF, AF, Vector((0.12, -1, 0.2)))
        for s_, sx in SX:
            Wt = Vector((0.20 * sx, WALL_Y + 0.065, sh[s_].z - 0.02))
            arm_to(s_, sh[s_], Wt, Vector((0.6 * sx, 0.4, -0.5)), Vector((0, 0, 1)))
            dbg('calf', s_, 'reach', (Wt - sh[s_]).length, 'Hb', Hb)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.7, -1.6, 1.15), tgt=(0, 0.0, 0.85), lens=55, stage=(0, 0.0, 1.0))

# ======================= 跪姿髖屈肌伸展（半跪：右膝跪地、左腳在前、骨盆後傾、髖往前送；手扶腰） =======================
if MOVE == 'hipFlexor':
    def pose(f):
        s = depth(f)
        KB = Vector((-0.11, 0.0, 0.07))
        th = D(lerp(6, 13, s))
        Hm_r = KB + Vector((0, -math.sin(th), math.cos(th))) * blen['thigh.R']
        Hm = Vector((0, Hm_r.y, Hm_r.z))
        lam_p = -D(lerp(6, 10, s))
        hh = hh_from(Hm, lam_p)
        cp, sh = trunk(hh, lam_p, -D(1), 0.0)
        # 後腿：膝跪地、小腿貼地往後、腳背貼地
        HR = hip_of('R', hh, lam_p)
        AR = KB + Vector((0, 1, 0)) * blen['shin.R']
        leg_pts('R', HR, KB, AR, Vector((0, 1, -0.10)))
        # 前腿：腳掌平放，膝蓋約 90°
        HF = hip_of('L', hh, lam_p)
        AF = Vector((0.11, Hm.y - 0.46, 0.11))
        leg_to('L', HF, AF, Vector((0.12, -1, 0)))
        for s_, sx in SX:
            Wt = hh + RX(lam_p) @ Vector((0.235 * sx, -0.02, 0.17))
            arm_to(s_, sh[s_], Wt, Vector((1.0 * sx, 0.6, 0.0)), Vector((-0.4 * sx, -0.2, -1)))
            dbg('hipFlexor', s_, 'reach', (Wt - sh[s_]).length)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.7, -2.0, 1.0), tgt=(0, -0.1, 0.6), lens=55, stage=(0, 0.0, 0.95))

# ======================= 人面獅身式（趴著、前臂撐地、手肘在肩膀正下方、胸口抬起；App 的「人面獅身式」，比眼鏡蛇保守） =======================
if MOVE == 'cobra':
    def pose(f):
        s = depth(f)
        zh = 0.115
        lam_p = D(88)
        Hm = Vector((0, 0.0, zh))
        hh = hh_from(Hm, lam_p)
        # 肩膀高 = 手肘高 + 上臂長；用二分法找胸的抬起角
        ZE = 0.055
        ztar = ZE + blen['upper_arm.L'] * lerp(0.98, 0.99, s)
        lo, hi = D(35), D(88)
        for _ in range(30):
            mid = (lo + hi) / 2
            _, shm = trunk(hh, lam_p, mid, mid)
            if shm['L'].z > ztar: lo = mid
            else: hi = mid
        lam_c = (lo + hi) / 2
        cp, sh = trunk(hh, lam_p, lam_c, lam_c - D(32))
        for s_, sx in SX:
            H = Vector((HIPX[s_] * 1.15, 0.0, zh))
            K = H + Vector((0.02 * sx, 1, 0.0)).normalized() * blen['thigh.L']
            A = K + Vector((0.0, 1, 0.0)).normalized() * blen['shin.L']
            leg_pts(s_, H, K, A, Vector((0, 1, -0.10)))
            E = Vector((sh[s_].x * 0.97, sh[s_].y + 0.03, ZE))
            W = E + Vector((0.01 * sx, -blen['forearm.L'] * 0.985, 0))
            arm_to(s_, sh[s_], W, Vector((0.3 * sx, 1.0, 0.0)), Vector((0, -1, -0.05)))
            dbg('cobra', s_, 'sh', sh[s_], 'lam_c', math.degrees(lam_c))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.4, -1.6, 0.9), tgt=(0, 0.0, 0.3), lens=52, stage=(0, 0.0, 1.0))
