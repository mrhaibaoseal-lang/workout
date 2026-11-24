# 動作批次：熱身。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡：docs/3d-moves/warmup.md
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
# 熱身全部徒手（沒有 bell）。靠牆天使背靠牆：牆不是椅背，但背部裝備（披風、背包、尾巴）會穿進牆，所以也隱藏背部（lean_back）。
MOVE_META = {
    # angles：動作卡 docs/3d-moves/warmup.md 的角度範圍（寫法見 scripts/blender/README.md；範圍照卡片，不照量到的值）。
    'armCircle': {'angles': {'elbow': (160, 180), 'uarm_vert': {'min': (40, 62), 'max': (118, 140)}, 'trunk_lean': (0, 4)}},
    'hipHinge': {'angles': {'trunk_lean': {'max': (55, 70)}, 'knee': (158, 178), 'hip': {'min': (95, 115)}}},
    'bwSquat': {'angles': {'knee': {'min': (70, 85)}, 'trunk_lean': (0, 45), 'elbow': (160, 180)}},
    'lungeStep': {'angles': {'knee': {'min': (85, 115), 'max': (165, 180)}, 'trunk_lean': (0, 15)}},
    'armSwing': {'angles': {'uarm_vert': (78, 102), 'trunk_lean': (0, 5), 'elbow': (110, 180)}},
    'wallSlide': {'lean_back': True, 'angles': {'uarm_vert': {'min': (70, 95), 'max': (140, 165)}, 'elbow': {'min': (75, 100), 'max': (165, 180)}, 'trunk_lean': (0, 4), 'knee': (160, 180)}},
    'legSwing': {'angles': {'hip.R': {'min': (115, 135)}, 'knee.R': {'min': (150, 168), 'max': (170, 180)}, 'knee.L': (155, 180), 'trunk_lean': (0, 5)}},
    'bwBridge': {'lean_back': True, 'angles': {'hip': {'max': (165, 180)}, 'knee': (80, 115), 'elbow': (160, 180)}},
}

# ---------- 這批共用 ----------
# 熱身是連續循環：49 格（第 0～48 格），第 48 格 ＝ 第 0 格（循環播放時跳過最後一格就完全無縫）。
# 每個動作的姿勢函式都吃 u（0～1，u＝f/48），而且對 u 是週期的（pose(1) ＝ pose(0)）。
# 全部徒手，沒有器材（靠牆天使、擺腿有一面牆：moves/props_warmup.py）。
LOOP = 48
def _cw(u):
    """0 → 1 → 0 的平滑來回（餘弦），u 一個循環"""
    return 0.5 - 0.5 * math.cos(2 * math.pi * u)

def _loop_report(name):
    """量第 48 格和第 0 格差多少（骨頭頭尾位置，公分）、相鄰兩格最大跳動；印出來給動作卡"""
    def snap(f):
        sc.frame_set(f); bpy.context.view_layer.update()
        return {n: (p_.head.copy(), p_.tail.copy()) for n, p_ in pb.items()}
    snaps = [snap(f) for f in range(N)]
    def dist(a, b): return max(max((a[n][0] - b[n][0]).length, (a[n][1] - b[n][1]).length) for n in a)
    gap = dist(snaps[0], snaps[N - 1]) * 100
    steps = [dist(snaps[i], snaps[i + 1]) * 100 for i in range(N - 1)]
    wrap = dist(snaps[N - 2], snaps[N - 1]) * 100
    print(f'[loop] {name}: 第48格-第0格最大偏差 {gap:.2f} cm、相鄰兩格最大跳動 {max(steps):.1f} cm（第{steps.index(max(steps))}→{steps.index(max(steps)) + 1}格）、平均 {sum(steps) / len(steps):.1f} cm')

def _hand_hang(s, sh, spread=0.10, back=0.0):
    wrist = sh + Vector((spread * (1 if s == 'L' else -1), back, -(blen[f'upper_arm.{s}'] + blen[f'forearm.{s}']) * 0.992))
    arm_to(s, sh, wrist, Vector((0.25 * (1 if s == 'L' else -1), 1.0, 0.1)), Vector((0.02, 0.05, -1.0)))

REACH = blen['upper_arm.L'] + blen['forearm.L']

def _arm_free(s, sh, wrist, pole, hand_dir, roll=0.0):
    """不釘手腕的手臂：手肘照 pole 解出來之後直接擺三節骨頭。手臂舉高時鎖骨把肩膀抬起，整條手臂跟著平移，
    各骨頭的方向（手肘角度、手臂抬舉角）和設定的一樣（釘手腕的 arm_to 會被抬起的肩膀拉直或壓彎）"""
    e = ik2(sh, wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
    aim(f'upper_arm.{s}', sh, e - sh); aim(f'forearm.{s}', e, wrist - e); aim(f'hand.{s}', wrist, hand_dir, roll)

# ======================= 手臂繞圈（雙臂側平舉，手畫圈；前繞 2 圈、後繞 2 圈，圈大小變化；App：armCircle） =======================
# 手臂維持側平舉高度附近，整條手臂繞肩膀轉成一個圓錐：手畫的圈在前後／上下的平面（垂直於手臂）。
# 半角 r 從小圈（12°）到大圈（40°）再回小圈；轉向的那一刻圈最大、速度最慢，小圈時轉最快（像真人）。
if MOVE == 'armCircle':
    N = LOOP + 1
    def pose(u):
        hc = stand_legs(width=0.12, hip_z=0.93)
        _, sh = trunk(hc + Vector((0, 0, 0.04)), 0.0, 0.0, 0.0)
        w = abs(math.sin(2 * math.pi * u))
        r = D(12) + (D(40) - D(12)) * ease(w)
        phi = -2 * math.pi * math.sin(2 * math.pi * u)           # 0（正前）→ 往下、往後、往上＝前繞；反向＝後繞
        for s, sx in SX:
            d = Vector((sx * math.cos(r), -math.sin(r) * math.cos(phi), math.sin(r) * math.sin(phi))).normalized()
            wrist = sh[s] + d * (REACH * 0.995)
            _arm_free(s, sh[s], wrist, Vector((0.0, 0.6, -1.0)), d)
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('armCircle')
    CAM = dict(loc=(3.7, -4.0, 1.55), tgt=(0, 0, 1.08), lens=55, stage=(0, 0, 1.0))

# ======================= 徒手髖鉸鏈／早安式（手抱胸，髖往後推，背打直前傾；App：hipHinge＝徒手早安式） =======================
# 範本是 rdl（站姿啞鈴）：小腿幾乎垂直、膝蓋微彎（約 170° 到 162°），髖往後推，軀幹前傾到約 62°（大腿後側有拉的感覺就停），
# 脊椎一直線（骨盆、胸、頭同方向，頭比胸少前傾約 12°＝眼睛看前下方）。手抱胸（雙手搭對側肩前），
# 前傾時手不離胸口。
if MOVE == 'hipHinge':
    N = LOOP + 1
    def pose(u):
        t = _cw(u)
        ts = D(4) + D(1) * t
        tt = D(6) + D(8.5) * t
        lam = D(4) + D(58) * t
        hipmid = Vector((0, 0, 0)); J = {}
        for s, sx in SX:
            A = rest[f'shin.{s}'][1] + Vector((0.01 * sx, 0, 0))
            K = A + blen[f'shin.{s}'] * Vector((0, -math.sin(ts), math.cos(ts)))
            Hj = K + blen[f'thigh.{s}'] * Vector((0, math.sin(tt), math.cos(tt)))
            J[s] = (A, K, Hj); hipmid += Hj / 2
        cp, sh = trunk(hipmid + Vector((0, 0, 0.04)), lam, lam, D(4) + D(46) * t)
        for s, sx in SX:
            A, K, Hj = J[s]
            aim(f'thigh.{s}', Hj, K - Hj); aim(f'shin.{s}', K, A - K)
            aim(f'foot.{s}', A, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            # 手抱胸：左手搭右肩前（在上）、右手搭左肩前（在下）。座標是胸骨頭的靜止座標，跟著軀幹前傾
            wrist = cp((-0.075 * sx, -0.23 if s == 'L' else -0.14, 1.43 if s == 'L' else 1.26))
            arm_to(s, sh[s], wrist, Vector((0.35 * sx, -1.0, -0.7)), Vector((-0.5 * sx, -0.3, 0.45)))
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('hipHinge')
    CAM = dict(loc=(4.6, -3.0, 1.45), tgt=(0, -0.05, 0.95), lens=62, stage=(0, 0, 0.8))

# ======================= 徒手深蹲（手往前伸平衡；App：bwSquat） =======================
# 範本是 squat（站姿啞鈴）：腳掌平貼地、小腿前傾 22°、大腿到水平以下（膝內角約 70～80°）、軀幹前傾約 36°、膝蓋跟著腳尖方向。
# 手臂隨蹲低從垂在身側慢慢往前抬到水平（當配重），站起來再放下。
if MOVE == 'bwSquat':
    N = LOOP + 1
    def pose(u):
        t = _cw(u)
        ts, tt, lam = D(22) * t, D(88) * t, D(36) * t
        hipmid = Vector((0, 0, 0)); J = {}
        for s, sx in SX:
            A = rest[f'shin.{s}'][1] + Vector((0.02 * sx, 0, 0))
            K = A + blen[f'shin.{s}'] * Vector((0.035 * sx * t, -math.sin(ts), math.cos(ts)))
            Hj = K + blen[f'thigh.{s}'] * Vector((-0.02 * sx * t, math.sin(tt), math.cos(tt)))
            J[s] = (A, K, Hj); hipmid += Hj / 2
        _, sh = trunk(hipmid + Vector((0, 0, 0.04)), lam * 0.6, lam, lam * 0.15)
        el = D(14) + D(76) * t                                   # 手臂抬舉角（離垂直往下）：垂在身側 → 水平往前
        for s, sx in SX:
            A, K, Hj = J[s]
            aim(f'thigh.{s}', Hj, K - Hj); aim(f'shin.{s}', K, A - K)
            aim(f'foot.{s}', A, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            d = Vector((0.035 * sx, -math.sin(el), -math.cos(el))).normalized()
            wrist = sh[s] + d * (REACH * 0.992)
            _arm_free(s, sh[s], wrist, Vector((0.25 * sx, 0.3, -1.0)), d)
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('bwSquat')
    CAM = dict(loc=(4.2, -3.9, 1.5), tgt=(0, -0.05, 0.92), lens=60, stage=(0, 0, 0.8))

# ======================= 左右交替後跨弓步（手叉腰；App：lungeStep） =======================
# 範本是 lunge_pose（moves3d.py）／reverseLunge：站直併腳 → 一腳往後踏一大步（前腳掌先著地、腳跟抬起）→ 前膝約 90°、後膝約 90° 懸空 → 蹬回併腳；
# 前 24 格右腳往後、後 24 格左腳往後（左右交替）。手叉腰（拇指朝後、手肘往外），軀幹直立。
if MOVE == 'lungeStep':
    N = LOOP + 1
    def pose(f):
        h = 0 if f < 24 or f == LOOP else 1
        fl = f - 24 * h if f != LOOP else 24
        t = profile(fl, 24, 10, 2, 12)
        fs = 'L' if h == 0 else 'R'; sf = 1 if fs == 'L' else -1
        front = Vector((HIPX[fs], 0.01, 0.11))
        toe0 = Vector((-HIPX[fs], -0.13, 0.04)); toe1 = Vector((-HIPX[fs], 0.69, 0.045))
        rear = rear_step_back(toe0, toe1, 55, lift=0.07, split=0.5)
        H, sh = lunge_pose(t, front, rear, hy=(0.0, 0.34), knee=(176, 92), lean=D(8), front_side=fs)
        for s, sx in SX:
            wrist = H + Vector((0.205 * sx, -0.01 - 0.04 * t, 0.15))
            arm_to(s, sh[s], wrist, Vector((1.0 * sx, 0.7, 0.1)), Vector((-0.2 * sx, -0.6, -0.6)))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    _loop_report('lungeStep')
    CAM = dict(loc=(4.3, -3.2, 1.25), tgt=(0, 0.3, 0.62), lens=52, stage=(0, 0.3, 0.95))

# ======================= 手臂前後開合（手臂水平往前交叉抱、往後打開；App：armSwing） =======================
# 站直，雙臂在肩膀高度（水平面內）來回：往前時雙臂交叉像抱自己（手肘微彎、兩臂上下錯開 10 cm 不撞，上面那隻每次換邊），
# 往後打開約 30°（胸口拉開，不再往後硬扳）。軀幹不跟著晃；打開時胸口微挺（後仰 ≤ 3°）。
if MOVE == 'armSwing':
    N = LOOP + 1
    def pose(u):
        w = _cw(2 * u)                                           # 0＝打開、1＝抱（一個循環做兩次）
        hc = stand_legs(width=0.12, hip_z=0.93)
        _, sh = trunk(hc + Vector((0, 0, 0.04)), 0.0, -D(3) * (1 - w), 0.0)
        psi = D(-30) + D(168) * w                                # 手臂方向離側邊（水平面）往前的角度
        top = math.sin(2 * math.pi * u)                          # 抱的時候哪隻手在上：第一次左、第二次右
        for s, sx in SX:
            dz = 0.05 * top * sx
            d = Vector((sx * math.cos(psi), -math.sin(psi), dz / 0.52)).normalized()
            reach = REACH * (0.995 - 0.07 * w)                    # 抱的時候手肘彎一點
            wrist = sh[s] + d * reach
            _arm_free(s, sh[s], wrist, Vector((0.8 * sx, 0.3, 0.0)), d)
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('armSwing')
    CAM = dict(loc=(3.9, -3.7, 1.6), tgt=(0, -0.05, 1.08), lens=55, stage=(0, 0, 0.95))

# ======================= 靠牆天使（背貼牆，W 滑到 Y；App：wallSlide＝頭上推舉伸展） =======================
# 背靠牆站：後腦、上背、臀貼牆，腳跟離牆約 15 cm、膝微彎；手肘彎 90°、上臂約水平、前臂垂直往上（W），手背貼牆；
# 沿牆往上滑到手臂斜上伸直（Y，上臂離垂直往下約 150°），再滑回 W。全程腰不反弓、肋骨收著、肩膀往下沉不聳肩。
if MOVE == 'wallSlide':
    N = LOOP + 1
    WALL_Y = 0.19
    build_wall('y', WALL_Y)
    def pose(u):
        t = _cw(u)
        for s, sx in SX:
            leg_to(s, Vector((0.12 * sx, 0.0, 0.925)), Vector((0.12 * sx, -0.15, 0.11)), Vector((0.12 * sx, -1.0, 0)))
        _, sh = trunk(Vector((0, 0.0, 0.925 + 0.04)), 0.0, 0.0, 0.0)
        th = D(85) + D(65) * t                                   # 上臂離垂直往下：85°（W）→ 150°（Y）
        ph = D(30) * t                                           # 前臂離垂直往上（朝外）：0°（W）→ 30°（Y，和上臂同方向＝伸直）
        for s, sx in SX:
            ua = Vector((sx * math.sin(th), 0.20, -math.cos(th))).normalized()
            e = sh[s] + ua * blen[f'upper_arm.{s}']
            fy = 0.04 + (0.20 - 0.04) * t * t
            fa = Vector((sx * math.sin(ph), fy, math.cos(ph))).normalized()
            wrist = e + fa * blen[f'forearm.{s}']
            ua_n = (wrist - sh[s]).normalized()
            pole = (e - sh[s]) - ua_n * (e - sh[s]).dot(ua_n)
            _arm_free(s, sh[s], wrist, pole, fa)
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('wallSlide')
    CAM = dict(loc=(2.3, -4.6, 1.55), tgt=(0, 0.0, 1.22), lens=55, stage=(0, -0.1, 0.95))

# ======================= 前後擺腿（單手扶牆，一條腿像鐘擺前後擺，幅度慢慢加大；App：legSwing） =======================
# 側身站在牆旁（牆在角色左邊），左手扶牆（手肘微彎），右腳放鬆前後擺（膝蓋幾乎打直、往後擺時自然微彎）；
# 站立腳膝微彎、骨盆水平、軀幹直立（不跟著晃）。一個循環擺 2 次，幅度從約 55% 慢慢加大到 100% 再回來
# （向前最多 55°、向後最多 25°，不過度反弓）。App 每邊做 20 秒，3D 只示範右腳（換邊就是鏡像）。
if MOVE == 'legSwing':
    N = LOOP + 1
    WALL_X = 0.80
    build_wall('x', WALL_X)
    def pose(u):
        amp = 0.55 + 0.45 * _cw(u)
        phi = amp * (D(15) + D(40) * math.sin(4 * math.pi * u + D(-22)))     # 大腿離垂直往前的角度（負＝往後）
        kb = max(0.0, min(1.0, (-phi / amp + D(5)) / D(30)))               # 往後擺時膝蓋微彎的程度
        kin = D(176) - D(20) * kb * kb * (3 - 2 * kb) * amp                  # 擺動腿的膝內角
        hz = 0.925
        # 站立腳（左）：膝微彎
        leg_to('L', Vector((0.12, 0, hz)), Vector((0.12, 0.01, 0.11)), Vector((0.12, -1.0, 0)))
        # 擺動腿（右）：大腿照角度、小腿在大腿後面彎 (180° - kin)
        hj = Vector((-0.12, 0, hz)); k = hj + blen['thigh.R'] * Vector((0, -math.sin(phi), -math.cos(phi)))
        phs = phi - (math.pi - kin)
        a = k + blen['shin.R'] * Vector((0, -math.sin(phs), -math.cos(phs)))
        aim('thigh.R', hj, k - hj); aim('shin.R', k, a - k)
        sh0 = (rest['shin.R'][1] - rest['shin.R'][0]).normalized()
        R = sh0.rotation_difference((a - k).normalized()).to_matrix()
        aim('foot.R', a, R @ (rest['foot.R'][1] - rest['foot.R'][0]))
        _, sh = trunk(Vector((0, 0, hz + 0.04)), 0.0, 0.0, 0.0)
        # 左手扶牆（掌心貼牆，手肘微彎）；右手自然垂在身側、微微和腿反向擺
        wrist = Vector((WALL_X - 0.075, -0.03, 1.27))
        arm_to('L', sh['L'], wrist, Vector((0.2, 0.9, -1.0)), Vector((0.5, 0.0, 1.0)))
        _hand_hang('R', sh['R'], spread=0.10, back=0.06 * math.sin(phi))
    for f in range(N):
        sc.frame_set(f); pose(f / LOOP); keyall(f)
    _loop_report('legSwing')
    CAM = dict(loc=(-4.9, -2.7, 1.35), tgt=(0.25, -0.05, 0.92), lens=52, stage=(0.25, 0, 1.15))

# ======================= 徒手臀橋（仰躺，夾臀把髖頂起，停 1 秒再放下；App：bwBridge） =======================
# 範本是 bridge（moves/lunge_bridge.py，同一個 bridge_pose）：仰躺、膝蓋彎、腳掌平貼地（與髖同寬）、手掌貼地放身側；
# 頂端肩—髖—膝成一直線（髖內角 ≥ 165°）、膝內角約 98°；上背（肩胛）是支點，頭和肩不離地。
# 節奏：向上 14 格（約 1.2 秒）→ 頂端停 12 格（1 秒）→ 慢放 22 格（約 1.8 秒）。
if MOVE == 'bwBridge':
    N = LOOP + 1
    TC = 0.40
    C = Vector((0, 0.45, 0.155))
    PHI_TOP = D(27)
    def _top_feet():
        c = Vector((0, math.cos(PHI_TOP), -math.sin(PHI_TOP)))
        hj = C - c * TC + RX(-D(90) - PHI_TOP) @ Vector((0, 0, -0.04))
        d = 2 * blen['thigh.L'] * math.sin(D(98) / 2)
        return hj.y - math.sqrt(max(d * d - (hj.z - 0.11) ** 2, 0.0))
    FOOT_Y = _top_feet()
    def pose(f):
        phi = PHI_TOP * profile(f, N, 14, 12, 22)
        hh, c, sh, J = bridge_pose(phi, C, FOOT_Y, foot_x=0.16, trunk_c=TC)
        for s, sx in SX:
            # 手掌貼地放身側（手臂幾乎伸直，從肩膀斜下到地板）
            dz = 0.04 - sh[s].z
            dxo = 0.10
            dy = -math.sqrt(max((REACH * 0.985) ** 2 - dz * dz - dxo * dxo, 0.01))
            wrist = sh[s] + Vector((dxo * sx, dy, dz))
            arm_to(s, sh[s], wrist, Vector((0.3 * sx, 0.0, 1.0)), Vector((0.0, -1.0, -0.1)), hand_roll=0.0)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    _loop_report('bwBridge')
    CAM = dict(loc=(3.4, -1.5, 1.0), tgt=(0, 0.0, 0.28), lens=48, stage=(0, 0.0, 1.0))
