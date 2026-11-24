# 動作批次：站姿啞鈴。負責：Gemini（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    # angles＝動作卡「關鍵關節角度」的範圍（clipbatch.py 判定；寫法見 scripts/blender/README.md）。
    # 'knee': (70, 180)＝整個循環最小值不小於 70、最大值不大於 180；{'min': (70, 85)}＝最小值要落在 70～85（抓蹲不夠深）。
    'squat': {'bell': True, 'angles': {'knee': {'min': (70, 85)}, 'trunk_lean': (0, 45)}},
    'press': {'bell': True, 'angles': {'elbow': (80, 172), 'uarm_trunk': (75, 170), 'trunk_lean': (0, 5)}},
    'rdl': {'bell': True, 'angles': {'trunk_lean': (5, 72), 'knee': (160, 170), 'hip': (85, 170), 'elbow': (170, 180)}},
    'row': {'bell': True, 'angles': {'trunk_lean': (42, 48), 'knee': (150, 160), 'elbow': (75, 172)}},
    'curl': {'bell': True, 'angles': {'elbow': (44, 168), 'uarm_vert': (0, 8), 'trunk_lean': (0, 3)}},
    'lateral': {'bell': True, 'angles': {'uarm_vert': (12, 88), 'elbow': (152, 162), 'trunk_lean': (4, 6)}},
}

def _ang_deg(u, v):
    u, v = u.normalized(), v.normalized()
    return math.degrees(math.acos(max(-1.0, min(1.0, u.dot(v)))))

def _bone_vec(name):
    b = pb[name]
    return (b.tail - b.head).normalized()

def _elbow_deg(s):
    return _ang_deg(-_bone_vec(f'upper_arm.{s}'), _bone_vec(f'forearm.{s}'))

def _knee_deg(s):
    return _ang_deg(-_bone_vec(f'thigh.{s}'), _bone_vec(f'shin.{s}'))

def _cycle(f, h0, go, h1, back):
    if f < h0: return 0.0
    f -= h0
    if f < go: return ease(f / go)
    f -= go
    if f < h1: return 1.0
    f -= h1
    if f < back: return 1.0 - ease(f / back)
    return 0.0

def _stand_base(width=0.14, hip_z=0.97, lam_hips=0.0, lam_chest=0.0, lam_head=0.0, hip_y=0.0):
    for s, sx in SX:
        hj = Vector((width * sx, hip_y, hip_z))
        an = Vector((width * sx, 0.01, 0.11))
        leg_to(s, hj, an, Vector((0.12 * sx, -1, 0)))
    return trunk(Vector((0, hip_y, hip_z + 0.04)), lam_hips, lam_chest, lam_head)

# ======================= 啞鈴深蹲 =======================
if MOVE == 'squat':
    N = 48
    def pose(t):
        ts, tt, lam = D(22) * t, D(88) * t, D(36) * t   # 小腿前傾 22°＋大腿到水平：膝角約 70°（動作卡 70～85°；原本 38°/78° 膝角 64°）
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
            d = Vector((0.03 * sx + 0.10 * sx * t, -0.10 * t, -1))   # 蹲低時手往外，啞鈴落在大腿外側
            e = aim(f'upper_arm.{s}', sh[s], d); w = aim(f'forearm.{s}', e, d); aim(f'hand.{s}', w, d)
    for f in range(N):
        sc.frame_set(f); pose(ease(f / 24 if f <= 24 else (47 - f) / 23)); keyall(f)

# ======================= 啞鈴肩推 =======================
if MOVE == 'press':
    N = 48
    ang = {'elbow': [], 'elev': [], 'trunk': []}
    def pose(t):
        _, sh = _stand_base(width=0.145, hip_z=0.97, lam_hips=D(3), lam_chest=D(2), lam_head=0)
        for s, sx in SX:
            w0 = sh[s] + Vector((0.24 * sx, -0.11, 0.265))
            w1 = sh[s] + Vector((0.075 * sx, -0.05, 0.589))
            wrist = w0.lerp(w1, t) + Vector((0.03 * sx * math.sin(math.pi * t), -0.03 * math.sin(math.pi * t), 0))
            pole = Vector((0.85 * sx, -0.55, -0.35))
            arm_to(s, sh[s], wrist, pole, Vector((0.06 * sx * (1 - t), 0.04, 1.0)), hand_roll=D(72) * sx)
    def _meas():   # 在 keyall 之後量：鎖骨跟轉、手臂滾轉校正會改變實際骨頭方向
        ang['elbow'].append(_elbow_deg('L'))
        ang['elev'].append(_ang_deg(Vector((0, 0, -1)), _bone_vec('upper_arm.L')))
        ang['trunk'].append(_ang_deg(UP, _bone_vec('chest')))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f); _meas()
    print(f"[angles] press elbow={min(ang['elbow']):.1f}..{max(ang['elbow']):.1f} elev={min(ang['elev']):.1f}..{max(ang['elev']):.1f} trunk={min(ang['trunk']):.1f}..{max(ang['trunk']):.1f}")
    CAM = dict(loc=(4.2, -4.3, 1.45), tgt=(0, 0, 1.15), lens=60, stage=(0, 0, 0.65))

# ======================= 啞鈴羅馬尼亞硬舉 =======================
if MOVE == 'rdl':
    N = 48
    ang = {'trunk': [], 'knee': [], 'elbow': []}
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        ts = D(4) + D(1) * t
        tt = D(6) + D(8.5) * t
        lam = D(5) + D(66) * t
        hipmid = Vector((0, 0, 0)); J = {}
        for s, sx in SX:
            A = rest[f'shin.{s}'][1] + Vector((0.01 * sx, 0, 0))
            K = A + blen[f'shin.{s}'] * Vector((0, -math.sin(ts), math.cos(ts)))
            Hj = K + blen[f'thigh.{s}'] * Vector((0, math.sin(tt), math.cos(tt)))
            J[s] = (A, K, Hj); hipmid += Hj / 2
        _, sh = trunk(hipmid + Vector((0, 0, 0.04)), lam, lam, D(4) + D(54) * t)
        for s, sx in SX:
            A, K, Hj = J[s]
            aim(f'thigh.{s}', Hj, K - Hj); aim(f'shin.{s}', K, A - K)
            aim(f'foot.{s}', A, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            dx = -0.025 * sx
            dy = -0.20 * (1 - t) - 0.02 * t
            dz = -math.sqrt(max(0.01, (reach * 1.015) ** 2 - dx * dx - dy * dy))
            wrist = sh[s] + Vector((dx, dy, dz))
            hdir = (wrist - sh[s]).normalized()
            arm_to(s, sh[s], wrist, Vector((0.15 * sx, 1.0, 0.0)), hdir, hand_roll=D(90) * sx)
    def _meas():   # 在 keyall 之後量：鎖骨跟轉、手臂滾轉校正會改變實際骨頭方向
        ang['trunk'].append(_ang_deg(UP, _bone_vec('chest')))
        ang['knee'].append(_knee_deg('L'))
        ang['elbow'].append(_elbow_deg('L'))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 22, 4, 14)); keyall(f); _meas()
    print(f"[angles] rdl trunk={min(ang['trunk']):.1f}..{max(ang['trunk']):.1f} knee={min(ang['knee']):.1f}..{max(ang['knee']):.1f} elbow={min(ang['elbow']):.1f}..{max(ang['elbow']):.1f}")
    CAM = dict(loc=(4.2, -3.9, 1.55), tgt=(0, -0.05, 0.92), lens=65, stage=(0, 0, 0.65))

# ======================= 俯身啞鈴划船 =======================
if MOVE == 'row':
    N = 48
    ang = {'trunk': [], 'knee': [], 'elbow': []}
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        ts, tt = D(12), D(16)
        hipmid = Vector((0, 0, 0)); J = {}
        for s, sx in SX:
            A = rest[f'shin.{s}'][1] + Vector((0.015 * sx, 0, 0))
            K = A + blen[f'shin.{s}'] * Vector((0, -math.sin(ts), math.cos(ts)))
            Hj = K + blen[f'thigh.{s}'] * Vector((0, math.sin(tt), math.cos(tt)))
            J[s] = (A, K, Hj); hipmid += Hj / 2
        _, sh = trunk(hipmid + Vector((0, 0, 0.04)), D(44), D(45), D(33))
        for s, sx in SX:
            A, K, Hj = J[s]
            aim(f'thigh.{s}', Hj, K - Hj); aim(f'shin.{s}', K, A - K)
            aim(f'foot.{s}', A, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            w0 = sh[s] + Vector((0.045 * sx, -0.02, -reach * 0.991))
            w1 = sh[s] + Vector((0.065 * sx, 0.24, -0.21))
            wrist = w0.lerp(w1, t) + Vector((0, 0.02 * math.sin(math.pi * t), -0.02 * math.sin(math.pi * t)))
            pole = Vector((0.40 * sx, 0.85, 0.45))
            arm_to(s, sh[s], wrist, pole, Vector((0.03 * sx, 0.12 * t, -1.0)), hand_roll=0.0)
    def _meas():   # 在 keyall 之後量：鎖骨跟轉、手臂滾轉校正會改變實際骨頭方向
        ang['trunk'].append(_ang_deg(UP, _bone_vec('chest')))
        ang['knee'].append(_knee_deg('L'))
        ang['elbow'].append(_elbow_deg('L'))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f); _meas()
    print(f"[angles] row trunk={min(ang['trunk']):.1f}..{max(ang['trunk']):.1f} knee={min(ang['knee']):.1f}..{max(ang['knee']):.1f} elbow={min(ang['elbow']):.1f}..{max(ang['elbow']):.1f}")
    CAM = dict(loc=(4.1, -3.9, 1.55), tgt=(0, -0.02, 0.95), lens=65, stage=(0, 0, 0.65))

# ======================= 啞鈴彎舉 =======================
if MOVE == 'curl':
    N = 48
    ang = {'elbow': [], 'uarm': [], 'trunk': []}
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        _, sh = _stand_base(width=0.13, hip_z=0.98, lam_hips=0, lam_chest=0, lam_head=0)
        phi = D(13) + D(120) * t                      # 手肘屈曲量（前臂相對上臂轉的角度）：手肘角 ＝ 180° − phi
        for s, sx in SX:
            # 上臂幾乎固定（貼身、微微外開避開大腿，往前漂 ≤ 8°）；只有前臂繞手肘轉（Rodrigues：繞世界 X 軸往前上方）
            u = Vector((0.12 * sx, -0.03 - 0.03 * t, -1.0)).normalized()
            e = sh[s] + u * blen[f'upper_arm.{s}']
            f = Matrix.Rotation(-phi, 3, 'X') @ u
            wrist = e + f * blen[f'forearm.{s}']
            ua = (wrist - sh[s]).normalized()
            pole = (e - sh[s]) - ua * (e - sh[s]).dot(ua)   # 讓 IK 解出的手肘剛好落在 e
            # 旋後彎舉：底部掌心相對（握把前後向，啞鈴不撞大腿），上舉到 55% 時旋成掌心朝上（握把左右向）
            arm_to(s, sh[s], wrist, pole, f, hand_roll=D(90) * sx * ease(min(1.0, t / 0.55)))
    def _meas():   # 在 keyall 之後量：鎖骨跟轉、手臂滾轉校正會改變實際骨頭方向
        ang['elbow'].append(_elbow_deg('L'))
        ang['uarm'].append(_ang_deg(Vector((0, 0, -1)), _bone_vec('upper_arm.L')))
        ang['trunk'].append(_ang_deg(UP, _bone_vec('chest')))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f); _meas()
    print(f"[angles] curl elbow={min(ang['elbow']):.1f}..{max(ang['elbow']):.1f} uarm={min(ang['uarm']):.1f}..{max(ang['uarm']):.1f} trunk={min(ang['trunk']):.1f}..{max(ang['trunk']):.1f}")
    CAM = dict(loc=(4.0, -3.9, 1.50), tgt=(0, -0.05, 1.02), lens=65, stage=(0, 0, 0.65))

# ======================= 啞鈴側平舉 =======================
if MOVE == 'lateral':
    N = 48
    ang = {'abd': [], 'elbow': [], 'trunk': [], 'hx': []}
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        _, sh = _stand_base(width=0.135, hip_z=0.98, lam_hips=D(4), lam_chest=D(5), lam_head=D(3))
        for s, sx in SX:
            d0 = Vector((0.20 * sx, -0.20, -1.0)).normalized()
            d1 = Vector((0.92 * sx, -0.38, -0.04)).normalized()
            d = d0.lerp(d1, t).normalized()
            wrist = sh[s] + d * (reach * 0.975)
            pole = Vector((0.25 * sx, 1.0, -0.35 + 0.70 * t))
            e0 = ik2(sh[s], wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
            hdir = (wrist - e0).normalized()
            arm_to(s, sh[s], wrist, pole, hdir, hand_roll=0.0)
            if s == 'L': ang['hx'].append(abs(hdir.x))
    def _meas():   # 在 keyall 之後量：鎖骨跟轉、手臂滾轉校正會改變實際骨頭方向
        ang['abd'].append(_ang_deg(Vector((0, 0, -1)), _bone_vec('upper_arm.L')))
        ang['elbow'].append(_elbow_deg('L'))
        ang['trunk'].append(_ang_deg(UP, _bone_vec('chest')))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f); _meas()
    print(f"[angles] lateral abd={min(ang['abd']):.1f}..{max(ang['abd']):.1f} elbow={min(ang['elbow']):.1f}..{max(ang['elbow']):.1f} trunk={min(ang['trunk']):.1f}..{max(ang['trunk']):.1f} max_hx={max(ang['hx']):.3f}")
    CAM = dict(loc=(4.4, -4.3, 1.55), tgt=(0, 0, 1.02), lens=56, stage=(0, 0, 0.78))
