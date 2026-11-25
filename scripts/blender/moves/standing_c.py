# 動作批次：站姿 C（補剩下的動作，批次 ⑤）。負責：Claude（動作）。動作卡 docs/3d-moves/standing_c.md
#   farmerWalk（農夫走路，雙手各一顆）、suitcaseCarry（單手提行李走）、kbSwing（壺鈴擺盪，新器材 props_kb.py）、
#   arnoldPress（阿諾推舉）、calfSingle（單腳提踵，扶牆）、leanLateral（單手扶柱、身體側傾的側平舉，扶使用者一體機的立柱）。
# 這裡 exec bench2.py（取 kill_bell、bf_frame／bf_trunk…）；那些檔的動作不會被啟動（MOVE 不同名）。
# MOVE_META 只能寫字面值（hero_proto.py 用 ast 讀）。bell＝手上拿啞鈴（kbSwing 用 props_kb.py 的壺鈴，不用啞鈴）。
MOVE_META = {
    'farmerWalk': {'bell': True, 'angles': {'trunk_lean': (0, 6), 'elbow': (165, 180), 'knee': (100, 180)}},
    'suitcaseCarry': {'bell': True, 'angles': {'trunk_lean': (0, 6), 'elbow.R': (165, 180), 'knee': (100, 180)}},
    'kbSwing': {'angles': {'trunk_lean': {'min': (0, 8), 'max': (50, 70)}, 'knee': {'min': (125, 150), 'max': (168, 180)}, 'elbow': (160, 180), 'hip': {'min': (60, 95), 'max': (165, 180)}}},
    'arnoldPress': {'bell': True, 'angles': {'trunk_lean': (0, 6), 'elbow': {'min': (30, 75), 'max': (160, 180)}, 'uarm_vert': {'max': (150, 180)}}},
    'calfSingle': {'angles': {'knee.R': (165, 180), 'trunk_lean': (0, 6)}},
    'leanLateral': {'bell': True, 'angles': {'trunk_lean': (18, 30), 'uarm_vert.L': {'min': (0, 30), 'max': (75, 100)}, 'elbow.L': (150, 175)}},
}
exec(open(os.path.join(_MDIR, 'bench2.py'), encoding='utf-8').read())

REACH_ = blen['upper_arm.L'] + blen['forearm.L']
_V_REST = rest['thigh.L'][0] - rest['hips'][0]           # 髖關節相對骨盆骨頭的位置（建模姿勢）

def _cycle(f, h0, go, h1, back):
    """h0 停、go 向心、h1 頂端停、back 離心；之後停住。回傳 0（起始）～1（頂端）"""
    if f < h0: return 0.0
    f -= h0
    if f < go: return ease(f / go)
    f -= go
    if f < h1: return 1.0
    f -= h1
    if f < back: return 1.0 - ease(f / back)
    return 0.0

def _aimz(name, head, ydir, zhint):
    """像 aim，但骨頭的 z 軸（手：握把方向）照 zhint"""
    yv = ydir.normalized(); zv = (zhint - yv * zhint.dot(yv)).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def _hand_grip(s, wrist, hd, handle):
    """手（已由 arm_to 擺好）重新擺：手方向 hd、握把軸 handle。keyall 會保留手的方向。"""
    _aimz(f'hand.{s}', wrist, hd, handle)

def clav_delta(s, e_sh):
    """keyall 的鎖骨跟轉（moves3d.py shoulder_follow）會把肩膀抬高、往內；手舉到頭上時最多約 7 cm。
    用同一個公式預先算出位移，讓手腕目標相對『抬完之後』的肩膀（同 bar_cable.py）。e_sh＝上臂方向（肩→肘）"""
    cl = f'clavicle.{s}'; C = pb['chest'].matrix
    elev = e_sh.angle(-C.col[1].xyz.normalized()); phi = min(CLAV_MAX, max(0.0, elev - CLAV_START) * CLAV_RATIO)
    Mc0 = C @ pb['chest'].bone.matrix_local.inverted() @ pb[cl].bone.matrix_local
    c0 = Mc0.col[1].xyz.normalized()
    R = Matrix.Rotation(phi, 3, c0.cross(C.col[1].xyz.normalized()).normalized()) if phi > 0 else Matrix.Identity(3)
    return (R @ c0 - c0) * blen[cl]

def lift_wrists(sh, wfun, poles):
    """wfun(抬完之後的肩 {s: 位置}) → {s: 手腕}；迭代兩次讓手腕相對『抬完的肩』"""
    cur = dict(sh)
    for _ in range(2):
        W = wfun(cur)
        for s_, sx_ in SX:
            if s_ in W:
                e = ik2(sh[s_], W[s_], blen[f'upper_arm.{s_}'], blen[f'forearm.{s_}'], poles[s_]); cur[s_] = sh[s_] + clav_delta(s_, e - sh[s_])
    return W

def _hinge(lam_h, lam_c, lam_head, knee_deg, hjy, aw=0.12, ay=0.01):
    """髖鉸鏈站姿（兩腳站、腳踝釘在 (±aw, ay)）：骨盆前傾 lam_h、胸 lam_c、頭 lam_head；
    髖關節在 y＝hjy，髖高由膝內角 knee_deg 決定。回傳左右肩位置（同 standing_dumbbell2.py）。"""
    A = {s: Vector((aw * sx, ay, 0.11)) for s, sx in SX}
    hz = solve_hip_z(HIPX['L'], hjy, A['L'], knee_deg, Vector((0.12, -1, 0)))
    hh = Vector((HIPX['L'], hjy, hz)) - RX(lam_h) @ _V_REST
    _, sh = trunk(hh, lam_h, lam_c, lam_head)
    for s, sx in SX:
        hj = hh + RX(lam_h) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
        leg_to(s, hj, A[s], Vector((0.12 * sx, -1, 0)))
    return sh

def _march(p, hip_z=0.93, aw=0.13, lift=0.12, fwd=0.09):
    """原地踏步：p＝0～1 一個循環（左腳先抬、右腳後抬）；腳踝釘在地上或抬起 lift、往前 fwd。回傳髖中心。"""
    H = Vector((0, 0, hip_z))
    for s, sx in SX:
        q = (p + (0.0 if s == 'L' else 0.5)) % 1.0
        w = math.sin(2 * math.pi * q) if q < 0.5 else 0.0
        an = Vector((aw * sx, 0.01 - fwd * w, 0.11 + lift * w))
        leg_to(s, H + Vector((HIPX[s], 0, 0)), an, Vector((0.12 * sx, -1, 0)))
    return H

# ======================= 農夫走路（farmerWalk）／單手提行李走（suitcaseCarry） =======================
# 站直、肩膀下沉往後、核心繃緊、手臂垂在身側握啞鈴（農夫走路雙手各一顆；提行李只有右手一顆、另一手自然垂著）。
# 示範是「原地踏步」（左右腳輪流抬起往前一點、落下，身體不晃）：真走路要往前移動，3D 場景固定，用原地代替。
if MOVE in ('farmerWalk', 'suitcaseCarry'):
    N = 48
    ONE = (MOVE == 'suitcaseCarry')
    if ONE: kill_bell('L')                                 # 只留右手的啞鈴
    def pose(p):
        H = _march(p)
        _, sh = trunk(H + Vector((0, 0, 0.04)), 0, 0, 0)
        for s, sx in SX:
            held = (s == 'R') or not ONE
            dx = (0.05 if held else 0.025) * sx
            dz = -math.sqrt((REACH_ * 0.992) ** 2 - dx * dx - 0.01 ** 2)
            wrist = sh[s] + Vector((dx, -0.01, dz))
            arm_to(s, sh[s], wrist, Vector((0.15 * sx, 1.0, 0.0)), (wrist - sh[s]).normalized(), hand_roll=0.0)
    for f in range(N):
        sc.frame_set(f); pose((f / (N / 2)) % 1.0); keyall(f)       # 48 格＝左右各兩步
    CAM = dict(loc=(4.4, -4.2, 1.35), tgt=(0, 0, 0.85), lens=62, stage=(0, 0, 0.65))

# ======================= 壺鈴擺盪（kbSwing，兩手握壺鈴） =======================
# 雙腳比肩寬、腳尖微外開；髖鉸鏈把髖往後送（背打直、膝微彎），壺鈴從兩腿之間往後甩；
# 然後用臀把髖往前爆發伸直（站直、臀夾緊），壺鈴被甩到胸口高（手臂水平、手臂是被甩起來的，不是用手舉）；再讓它落下、髖往後送。
# 壺鈴本體永遠在手臂延伸的方向（離心力沿手臂拉出去）。48 格＝擺兩下。
if MOVE == 'kbSwing':
    N = 48
    kb = build_kettlebell()
    AW = 0.22
    PHI0, PHI1 = D(-62), D(88)                              # 手臂方向離垂直往前的角度：底部在身後（往後下）、頂端水平
    POL = {s_: Vector((0.5 * sx_, 0.2, -0.6)) for s_, sx_ in SX}
    def pose(t):                                            # t＝0 底部、1 頂端
        sh = _hinge(D(56) * (1 - t) + D(2) * t, D(60) * (1 - t) + D(2) * t, D(42) * (1 - t) + D(2) * t,
                    142 + 34 * t, 0.20 * (1 - t) + 0.03 * t, aw=AW)
        phi = PHI0 + (PHI1 - PHI0) * t
        d = Vector((0, -math.sin(phi), -math.cos(phi)))
        def wf(cur):
            mid = (cur['L'] + cur['R']) / 2
            r = math.sqrt((REACH_ * 0.985) ** 2 - 0.22 ** 2)
            C = mid + d * r
            return {s_: C + Vector((0.05 * sx_, 0, 0)) for s_, sx_ in SX}
        W = lift_wrists(sh, wf, POL)
        for s, sx in SX:
            e = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], POL[s])
            hd = (W[s] - e).normalized()
            arm_to(s, sh[s], W[s], POL[s], hd)
            _hand_grip(s, W[s], hd, Vector((1, 0, 0)))
    for f in range(N):
        sc.frame_set(f); pose((1 - math.cos(2 * math.pi * 2 * f / N)) / 2); keyall(f)
        GL, _ = hand_grip_frame('L'); GR, _ = hand_grip_frame('R')
        fa = (pb['forearm.L'].tail - pb['forearm.L'].head).normalized() + (pb['forearm.R'].tail - pb['forearm.R'].head).normalized()
        key_kb(kb, f, (GL + GR) / 2, fa)
    CAM = dict(loc=(4.3, -3.6, 1.45), tgt=(0, -0.1, 0.9), lens=62, stage=(0, 0, 0.65))

# ======================= 阿諾推舉（arnoldPress） =======================
# 站直、雙手各一顆啞鈴；起點啞鈴在胸前（約下巴到上胸高）、手肘在身體前面、掌心朝自己；
# 往上推的同時手肘往外打開、手掌向外轉（中途掌心相對），推到手臂接近伸直（不鎖死）時掌心朝前；放下時反向轉回來。
if MOVE == 'arnoldPress':
    N = 48
    H = stand_legs(width=0.13, hip_z=0.955)
    K0 = Vector((-0.13, -0.20, -0.02)); KM = Vector((0.04, -0.15, 0.24)); K1 = Vector((0.05, -0.04, 0.58))   # 手腕相對肩膀（x 乘 sx）
    def pose(t):
        u = ease(t)
        _, sh = trunk(H + Vector((0, 0, 0.04)), 0, 0, 0)
        Kc = (KM * 4 - K0 - K1) / 2
        k = K0 * (1 - u) ** 2 + Kc * 2 * (1 - u) * u + K1 * u * u
        poles = {s_: Vector((0.3 * sx_, -1, -0.6)).lerp(Vector((0.9 * sx_, -0.3, -0.2)), u) for s_, sx_ in SX}
        W = lift_wrists(sh, lambda cur: {s_: cur[s_] + Vector((k.x * sx_, k.y, k.z)) for s_, sx_ in SX}, poles)
        ph = D(180) * ease(max(0.0, min(1.0, (t - 0.08) / 0.84)))          # 手掌轉動：0＝掌心朝自己、180°＝掌心朝前
        for s, sx in SX:
            e = ik2(sh[s], W[s], blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], poles[s])
            hd = (W[s] - e).normalized()
            arm_to(s, sh[s], W[s], poles[s], hd)
            _hand_grip(s, W[s], hd, Vector((math.cos(ph) * sx, math.sin(ph), 0)))     # 握把軸（拇指—小指）：先左右向、中途前後向、最後又左右向
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 20, 6, 18)); keyall(f)
    CAM = dict(loc=(4.0, -3.7, 1.7), tgt=(0, -0.05, 1.3), lens=58, stage=(0, 0, 0.65))

# ======================= 單腳提踵（calfSingle，扶牆） =======================
# 站在右腳（腳掌前緣當支點）、左腳彎起抬在後面不碰地、右手輕扶牆保持平衡（不靠手撐）；腳跟慢慢抬到最高、頂端停一下、慢慢放回。
if MOVE == 'calfSingle':
    N = 48
    WALL_X = -0.62
    _b4 = set(bpy.data.objects); build_wall('x', WALL_X)
    _bar = bpy.data.objects.get('bar') or bpy.data.objects.new('bar', None)
    if _bar.name not in sc.objects: sc.collection.objects.link(_bar)
    for _o in [o for o in bpy.data.objects if o not in _b4 and o.parent is None and o is not _bar]: _o.parent = _bar   # 牆掛在 bar 底下：手輕扶牆是故意的接觸
    HEEL = D(26)
    a0, t0 = rest['foot.R']
    def pose(t):
        P = Vector((a0.x, -0.19, 0.012)); R = Matrix.Rotation(HEEL * t, 3, 'X')
        A = P + R @ (a0 - P); fd = R @ (t0 - a0)
        hz = solve_hip_z(HIPX['R'], A.y - 0.01, A, 172, Vector((-0.12, -1, 0)))
        Hc = Vector((a0.x - HIPX['R'], A.y - 0.01, hz))
        _, sh = trunk(Hc + Vector((0, 0, 0.04)), 0, 0, 0)
        leg_to('R', Hc + Vector((HIPX['R'], 0, 0)), A, Vector((-0.12, -1, 0)), fd)
        hj = Hc + Vector((HIPX['L'], 0, 0))                                          # 左腳彎起：大腿垂直微往前、小腿往後
        ph, ps = D(-6), D(78)
        K = hj + blen['thigh.L'] * Vector((0, math.sin(ph), -math.cos(ph)))
        Af = K + blen['shin.L'] * Vector((0, math.sin(ps), -math.cos(ps)))
        aim('thigh.L', hj, K - hj); aim('shin.L', K, Af - K)
        aim('foot.L', Af, Matrix.Rotation(ps, 3, 'X') @ (rest['foot.L'][1] - rest['foot.L'][0]))
        wr = Vector((WALL_X + 0.045, sh['R'].y - 0.12, sh['R'].z - 0.02))             # 右手掌貼牆（約肩高）
        arm_to('R', sh['R'], wr, Vector((-0.2, 0.4, -1.0)), Vector((-0.35, -0.1, 0.9)), hand_roll=D(90))
        wl = sh['L'] + Vector((0.06, -0.02, -REACH_ * 0.98))                          # 左手自然垂著
        arm_to('L', sh['L'], wl, Vector((0.15, 1.0, 0.0)), (wl - sh['L']).normalized())
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 12, 8, 24)); keyall(f)
    CAM = dict(loc=(4.4, -4.2, 1.35), tgt=(-0.1, 0, 0.85), lens=62, stage=(-0.1, 0, 0.7))

# ======================= 單手扶柱側平舉（leanLateral） =======================
# 站在一體機立柱旁（立柱在人的右手邊），右手握柱（約頭高）、手臂打直，整個身體像一條直線離柱子往左傾約 24°（腳掌貼地、腳靠近柱子），
# 左手拿啞鈴從身側垂直往側邊抬，手肘微彎，抬到手臂約和地面平行；放下時慢慢回去。傾斜讓三角肌在底部就有張力，扶柱讓身體不會跟著甩。
if MOVE == 'leanLateral':
    N = 48
    stack, XF = bench_scene(90)
    kill_bell('R')                                          # 右手握柱，沒有啞鈴
    A_LEAN = D(24); XM, YP = 0.06, -0.80
    POST = Vector((0.0, -0.62, 0.0))
    def pose(t):
        a = A_LEAN
        up = Vector((math.sin(a), 0, math.cos(a))); fr = Vector((0, -1, 0))
        fm = bf_frame(up, fr); fmh = bf_frame(Vector((math.sin(a * 0.5), 0, math.cos(a * 0.5))), fr)
        M = Vector((XM, YP, 0.11)); Hc = M + up * 0.80
        sh, hj, ctop = bf_trunk(Hc + up * 0.04, fm, fm, fmh)
        for s, sx in SX:
            leg_to(s, hj[s], Vector((XM + 0.10 * sx, YP, 0.11)), Vector((0.12 * sx, -1, 0)))
        # 右手握柱（握把軸＝立柱方向＝垂直），手腕在手拳中心往後退 5 cm
        G = Vector((POST.x, POST.y, sh['R'].z + 0.20))
        pole = Vector((-0.3, 0.4, -1.0))
        wr = G + Vector((0.05, 0, 0))
        for _ in range(2):
            e = ik2(sh['R'], wr, blen['upper_arm.R'], blen['forearm.R'], pole); hd = (wr - e).normalized(); wr = G - hd * 0.05
        arm_to('R', sh['R'], wr, pole, hd)
        _hand_grip('R', wr, hd, Vector((0, 0, 1)))
        # 左手啞鈴側平舉
        d0 = Vector((0.06, -0.10, -1.0)).normalized(); d1 = Vector((1.0, -0.30, 0.10)).normalized()
        d = d0.lerp(d1, t).normalized()
        wl = sh['L'] + d * (REACH_ * 0.975)
        pl = Vector((0.25, 1.0, -0.35 + 0.70 * t))
        e0 = ik2(sh['L'], wl, blen['upper_arm.L'], blen['forearm.L'], pl)
        arm_to('L', sh['L'], wl, pl, (wl - e0).normalized(), hand_roll=0.0)
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f)
    CAM = dict(loc=(4.0, -3.6, 1.4), tgt=(0.0, -0.7, 1.0), lens=56, stage=(0.1, -0.7, 0.8))
