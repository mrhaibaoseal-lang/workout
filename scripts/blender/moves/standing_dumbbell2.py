# 動作批次：站姿啞鈴 2（Claude，2026-11-25）。動作卡 docs/3d-moves/standing_dumbbell2.md
#   calf（站姿啞鈴提踵）、triceps（站姿啞鈴過頭三頭伸展，雙手一顆）、rearFly（俯身反向飛鳥）、
#   kickback（俯身三頭後踢，雙手）、slRdl（單腳羅馬尼亞硬舉）。
# 這個檔只靠 moves3d.py 現有的共用函式；這批自己的小工具（_cycle、_aimz、_hinge…）都寫在這裡。
MOVE_META = {
    # angles＝動作卡「關鍵關節角度」的範圍（clipbatch.py 判定；寫法見 scripts/blender/README.md）
    'calf': {'bell': True, 'angles': {'knee': (160, 180), 'trunk_lean': (0, 4), 'elbow': (165, 180)}},
    'triceps': {'bell': True, 'angles': {'elbow': (85, 172), 'uarm_vert': (150, 180), 'trunk_lean': (0, 5)}},
    'rearFly': {'bell': True, 'angles': {'trunk_lean': (50, 68), 'knee': (150, 168), 'elbow': (155, 172), 'uarm_vert': {'max': (80, 95)}}},
    'kickback': {'bell': True, 'angles': {'trunk_lean': (45, 62), 'knee': (150, 168), 'elbow': (85, 175), 'uarm_trunk': (0, 30)}},
    'slRdl': {'bell': True, 'angles': {'trunk_lean': (5, 80), 'knee.L': (160, 178), 'elbow': (165, 180), 'hip.L': {'min': (85, 100)}}},
}

def _ang_deg(u, v):
    u, v = u.normalized(), v.normalized()
    return math.degrees(math.acos(max(-1.0, min(1.0, u.dot(v)))))

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
    """像 aim，但骨頭的 z 軸（手：啞鈴握把方向）照 zhint（和 bench.py 的 aimz 一樣）"""
    yv = ydir.normalized(); zv = (zhint - yv * zhint.dot(yv)).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def _hand_grip(s, wrist, hd, handle):
    """手（已由 arm_to／elbow_hinge 擺好）重新擺：手方向 hd、握把軸 handle。keyall 會保留手的方向。"""
    _aimz(f'hand.{s}', wrist, hd, handle)

_V_REST = rest['thigh.L'][0] - rest['hips'][0]       # 髖關節相對骨盆骨頭的位置（建模姿勢）

def _hinge(lam_h, lam_c, lam_head, knee_deg, hjy, aw=0.12, ay=0.01):
    """髖鉸鏈站姿（兩腳站、腳踝釘在 (±aw, ay)）：骨盆前傾 lam_h、胸 lam_c、頭 lam_head；
    髖關節在 y＝hjy，髖高由膝內角 knee_deg 決定。回傳左右肩位置。"""
    A = {s: Vector((aw * sx, ay, 0.11)) for s, sx in SX}
    hz = solve_hip_z(HIPX['L'], hjy, A['L'], knee_deg, Vector((0.12, -1, 0)))
    hh = Vector((HIPX['L'], hjy, hz)) - RX(lam_h) @ _V_REST
    _, sh = trunk(hh, lam_h, lam_c, lam_head)
    for s, sx in SX:
        hj = hh + RX(lam_h) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
        leg_to(s, hj, A[s], Vector((0.12 * sx, -1, 0)))
    return sh

# ======================= 站姿啞鈴提踵 =======================
if MOVE == 'calf':
    N = 48
    reach = blen['upper_arm.L'] + blen['forearm.L']
    HEEL = D(26)                                    # 腳跟抬起的角度（鞋長 27 cm → 腳跟約離地 12 cm）
    def pose(t):
        dl = HEEL * t
        A = {}; fd = {}
        for s, sx in SX:
            a0, t0 = rest[f'foot.{s}']
            P = Vector((a0.x, -0.19, 0.012))        # 支點＝鞋底前緣（腳掌前端）；腳跟抬起時鞋尖留在地上
            R = Matrix.Rotation(dl, 3, 'X')
            A[s] = P + R @ (a0 - P); fd[s] = R @ (t0 - a0)
        hz = solve_hip_z(HIPX['L'], A['L'].y - 0.01, A['L'], 172, Vector((0.12, -1, 0)))
        H = Vector((0, A['L'].y - 0.01, hz))
        _, sh = trunk(H + Vector((0, 0, 0.04)), 0, 0, 0)
        for s, sx in SX:
            leg_to(s, H + Vector((HIPX[s], 0, 0)), A[s], Vector((0.12 * sx, -1, 0)), fd[s])
            dx, dy = 0.05 * sx, -0.01
            dz = -math.sqrt((reach * 0.992) ** 2 - dx * dx - dy * dy)
            wrist = sh[s] + Vector((dx, dy, dz))
            arm_to(s, sh[s], wrist, Vector((0.15 * sx, 1.0, 0.0)), (wrist - sh[s]).normalized(), hand_roll=0.0)
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 12, 8, 24)); keyall(f)
    CAM = dict(loc=(4.4, -4.2, 1.35), tgt=(0, 0, 0.85), lens=62, stage=(0, 0, 0.65))

# ======================= 站姿啞鈴過頭三頭伸展（雙手一顆，垂直握把） =======================
if MOVE == 'triceps':
    N = 48
    # 左手的啞鈴刪掉，只留右手那顆（雙手一起握著它；做法同 bench.py 的 pullover）
    import bmesh
    _hero = bpy.data.objects['hero']; _bm = bmesh.new(); _bm.from_mesh(_hero.data)
    _pa = _bm.faces.layers.int.get('part'); _dl = _bm.verts.layers.deform.verify()
    _gi = _hero.vertex_groups['hand.L'].index
    _kill = [f_ for f_ in _bm.faces if PART_NAMES[f_[_pa]].startswith('bell')
             and all(v[_dl].get(_gi, 0) > 0.5 for v in f_.verts)]
    bmesh.ops.delete(_bm, geom=_kill, context='FACES'); _bm.to_mesh(_hero.data); _bm.free()
    print('[triceps] 刪掉左手啞鈴面數', len(_kill))
    TILT_X, TILT_Y = D(3), D(15)                    # 上臂往內傾 3°（頭很大，手肘要在耳朵外面）、往後傾 15°（讓啞鈴落在頭後面）
    FA_X = 0.545                                    # 前臂往內的水平分量（手腕在 x＝±0.11，手才夠得到啞鈴握把）
    FA_YZ = math.sqrt(1 - FA_X ** 2)
    BUMP_Y, BUMP_Z = 0.03, 0.0
    PSI1 = D(105)                                   # 前臂最深往後倒的角度（從垂直算起）
    def pose(t):
        H = stand_legs(width=0.13, hip_z=0.955)
        _, sh = trunk(H + Vector((0, 0, 0.04)), 0, 0, 0)
        for s, sx in SX:
            u = Vector((-math.sin(TILT_X) * sx, math.sin(TILT_Y), math.cos(TILT_X) * math.cos(TILT_Y))).normalized()
            sh2 = sh[s] + Vector((-0.013 * sx, 0, 0.072))   # 上臂舉過頭時鎖骨自動上轉約 20°，肩點跟著上移（keyall 會做；這裡先算進去，手腕目標才構得到）
            E = sh2 + u * blen[f'upper_arm.{s}']
            psi = PSI1 * t
            fx = FA_X * (1 - 0.55 * min(1.0, 2.0 * math.sin(math.pi * t)))      # 前臂往內的量：中途少一點（不然前臂會切進頭側），頂端和底部手要併攏
            dirf = Vector((-fx * sx, math.sqrt(1 - fx * fx) * math.sin(psi), math.sqrt(1 - fx * fx) * math.cos(psi)))
            wrist = E + dirf * blen[f'forearm.{s}'] * 0.965 + Vector((0, BUMP_Y * math.sin(math.pi * t), BUMP_Z * math.sin(math.pi * min(1.0, t * 1.5))))   # 啞鈴繞過頭頂：中途往後、往上多繞一點
            ua_ = (wrist - sh2).normalized(); pole = (E - sh2) - ua_ * (E - sh2).dot(ua_)    # 讓 IK 解出的手肘落在我設定的上臂方向（curl 同做法）
            hd = Vector((-1.0 * sx, 0.0, 0.0))
            arm_to(s, sh[s], wrist, pole, hd, hand_roll=0.0)
            # 啞鈴：頂端橫放（握把前後向，不然下面那片槓片會插進頭頂），前臂開始往後倒就轉成直立（握把垂直）
            b = D(90) * ease(max(0.0, min(1.0, (t - 0.1) / 0.4)))
            _hand_grip(s, wrist, hd, Vector((0, math.cos(b), math.sin(b))))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 22, 6, 16)); keyall(f)
    CAM = dict(loc=(4.0, -3.5, 1.75), tgt=(0, 0.05, 1.3), lens=58, stage=(0, 0, 0.65))

# ======================= 俯身啞鈴反向飛鳥 =======================
if MOVE == 'rearFly':
    N = 48
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        sh = _hinge(D(58), D(60), D(46), 158, 0.0 - 0.02 * 0 + 0.11)
        for s, sx in SX:
            d0 = Vector((0.03 * sx, -0.05, -1.0)).normalized()
            d1 = Vector((1.0 * sx, 0.10, 0.02)).normalized()
            d = d0.lerp(d1, t).normalized()
            wrist = sh[s] + d * (reach * 0.985)
            pole = Vector((0.35 * sx, 0.9, 0.0)).lerp(Vector((0.05 * sx, 0.45, 1.0)), t)
            arm_to(s, sh[s], wrist, pole, d, hand_roll=0.0)
            e = ik2(sh[s], wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
            _hand_grip(s, wrist, (wrist - e).normalized(), Vector((0, 1, 0)))
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 14, 6, 20)); keyall(f)
    CAM = dict(loc=(4.1, -3.9, 1.5), tgt=(0, 0.0, 0.95), lens=65, stage=(0, 0, 0.65))

# ======================= 俯身啞鈴三頭後踢（雙手） =======================
if MOVE == 'kickback':
    N = 48
    def pose(t):
        sh = _hinge(D(52), D(54), D(40), 158, 0.11)
        u = Vector((0.03, math.cos(D(14)), -math.sin(D(14))))      # 上臂往後、離水平 14° 往下，約和背平行
        out = elbow_hinge(sh, t, u, Vector((0, 0, -1)), D(92), D(172))
        for s, sx in SX:
            e, w = out[s]
            fd = (w - e).normalized()
            _hand_grip(s, w, fd, Vector((1, 0, 0)).cross(fd))     # 中立握：掌心朝身體，握把垂直於前臂和手肘軸
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 16, 8, 20)); keyall(f)
    CAM = dict(loc=(4.1, -3.9, 1.5), tgt=(0, 0.05, 0.95), lens=65, stage=(0, 0, 0.65))

# ======================= 單腳羅馬尼亞硬舉（雙手各一顆） =======================
if MOVE == 'slRdl':
    N = 48
    reach = blen['upper_arm.L'] + blen['forearm.L']
    PX = 0.06                                           # 骨盆往支撐腳這一側移
    def pose(t):
        lean = D(5) + D(73) * t                         # 軀幹前傾
        phi = D(30) + D(52) * t                         # 後腳離垂直往後的角度（底部和軀幹成一直線）
        A = Vector((0.10, 0.01, 0.11))                  # 支撐腳（左）釘住
        hjy = A.y + 0.01 + 0.07 * t                     # 髖往後送
        hjx = PX + HIPX['L']
        hz = solve_hip_z(hjx, hjy, A, 168, Vector((0.12, -1, 0)))
        hh = Vector((hjx, hjy, hz)) - RX(lean) @ _V_REST
        _, sh = trunk(hh, lean, lean, D(4) + lean * 0.78)
        leg_to('L', hh + RX(lean) @ _V_REST, A, Vector((0.12, -1, 0)))
        # 後腳（右）：大腿往後 phi、膝微彎 8°，腳尖往下指，骨盆保持水平
        hj = hh + RX(lean) @ (rest['thigh.R'][0] - rest['hips'][0])
        K = hj + blen['thigh.R'] * Vector((0, math.sin(phi), -math.cos(phi)))
        ps = phi - D(8)
        Af = K + blen['shin.R'] * Vector((0, math.sin(ps), -math.cos(ps)))
        aim('thigh.R', hj, K - hj); aim('shin.R', K, Af - K)
        aim('foot.R', Af, Matrix.Rotation(ps, 3, 'X') @ (rest['foot.R'][1] - rest['foot.R'][0]))
        for s, sx in SX:
            dx, dy = (0.06 - 0.07 * t) * sx, -0.02     # 起始手在身側外面（啞鈴才不會壓到大腿），往下時漸漸移到小腿前
            dz = -math.sqrt((reach * 1.015) ** 2 - dx * dx - dy * dy)
            wrist = sh[s] + Vector((dx, dy, dz))
            arm_to(s, sh[s], wrist, Vector((0.15 * sx, 1.0, 0.0)), (wrist - sh[s]).normalized(), hand_roll=0.0)
    for f in range(N):
        sc.frame_set(f); pose(_cycle(f, 4, 22, 4, 14)); keyall(f)
    CAM = dict(loc=(4.2, -3.9, 1.5), tgt=(0.0, 0.05, 0.9), lens=65, stage=(0, 0, 0.65))
