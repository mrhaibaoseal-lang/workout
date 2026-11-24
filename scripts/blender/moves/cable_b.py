# 動作批次：滑輪 B（坐姿划船、單手滑輪側平舉；cableCurl 使用者決定刪掉）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。
# 動作卡 docs/3d-moves/cable_b.md。器材照滑輪 A：一體機 build_bench（props_cable.py 的 bench_scene）、鋼索只從椅子這一側的高位滑輪出、不長。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。angles＝動作卡範圍（寫法見 scripts/blender/README.md）。
MOVE_META = {
    'seatedCableRow': {'angles': {'elbow': {'min': (60, 90), 'max': (155, 175)}, 'uarm_vert': {'min': (0, 35), 'max': (65, 100)}, 'trunk_lean': (0, 12), 'knee': (125, 170)}},
    'cableLateral': {'angles': {'uarm_vert.L': {'min': (5, 25), 'max': (80, 95)}, 'elbow.L': (150, 172), 'trunk_lean': (0, 8)}},
}

# ======================= 坐姿滑輪划船（一體機、高位滑輪、三頭繩中立握）=======================
# 標準是低位滑輪、鋼索水平；這台只有高位滑輪，所以鋼索從前上方斜斜拉來（約 55～75°）。
# 靠背放平，人坐在椅子後段（離立柱約 1 m，鋼索才不會太陡）、面向立柱、兩腳跨在椅子兩側踩地、膝蓋微彎。
# 上身直立（起點微前傾 10°、終點微後仰 3°）；雙手握三頭繩，手臂前伸接近打直 → 拉向肚臍、手肘貼身往後，肩胛骨後收。
if MOVE == 'seatedCableRow':
    N = 48
    HIP_Y, HIP_Z = 0.45, 0.60
    stack, XF = bench_scene(90); rp = build_rope(); cbl = make_cables()
    def pose(t):
        lam = D(10) - D(13) * t
        hm = Vector((0, HIP_Y, HIP_Z))
        cp, sh = trunk(hm + Vector((0, 0, 0.04)), lam * 0.4, lam, lam * 0.5)
        for s, sx in SX:                                         # 兩腳踩地、跨在椅子兩側、膝蓋微彎
            hj = Vector((0.12 * sx, HIP_Y, HIP_Z)); an = Vector((0.27 * sx, HIP_Y - 0.62, 0.11))
            leg_to(s, hj, an, Vector((0.12 * sx, -1, 0.5)))
        for s, sx in SX:
            w0 = sh[s] + Vector((-0.15 * sx, -0.50, -0.09))
            w1 = sh[s] + Vector((-0.07 * sx, -0.17, -0.30))
            wrist = w0.lerp(w1, t)
            pole = Vector((0.3 * sx, 0.0, -1.0)).lerp(Vector((0.7 * sx, 1.0, -0.3)), t)
            e = ik2(sh[s], wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
            arm_to(s, sh[s], wrist, pole, (wrist - e).normalized())
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 18, 4, 24); pose(t); keyall(f)
        cp_ = key_rope(rp, f, WHEEL_FRONT); key_cables(cbl, stack, f, WHEEL_FRONT, cp_)
    CAM = dict(loc=(3.7, -1.6, 1.3), tgt=(0, 0.1, 1.0), lens=58, stage=(0, 0.15, 0.85))

# ======================= 單手滑輪側平舉（一體機、高位滑輪、D 型把手）=======================
# 標準是站在低位滑輪旁、休息的手靠滑輪那一側、工作的手從身前橫過去握把手。這台只有高位滑輪：
# 把整台機器轉 -90°，人站在椅子旁邊（椅子後面一點）、側身面向 -Y、右臉朝立柱（使用者 2026-11-25 指定）；
# 右手（靠立柱，休息）自然垂著，左手（遠離立柱）握 D 把手，鋼索從身前橫過去、往內往上拉；手臂從身側抬到側平舉（約 90°，不超過肩膀高度）、手肘微彎。
if MOVE == 'cableLateral':
    N = 48
    HY = 0.48                      # 人站在椅子旁邊（椅子轉 -90° 後沿 X 軸、立柱在 x≈-0.62）
    stack, XF = bench_scene_rot(90, -90); dh = build_dhandle(); cbl = make_cables()
    WX = XF @ WHEEL_FRONT
    reach = blen['upper_arm.L'] + blen['forearm.L']
    def pose(t):
        hm = Vector((0, HY, 0.925))
        _, sh = trunk(hm + Vector((0, 0, 0.04)), D(3), D(4), D(2))
        stand_legs(0.15, 0.925, HY)
        sx = 1; s = 'L'
        d0 = Vector((0.20, -0.20, -1.0)).normalized(); d1 = Vector((0.92, -0.38, -0.04)).normalized()
        d = d0.lerp(d1, t).normalized()
        wrist = sh[s] + d * (reach * 0.975)
        pole = Vector((0.25, 1.0, -0.35 + 0.70 * t))
        e0 = ik2(sh[s], wrist, blen['upper_arm.L'], blen['forearm.L'], pole)
        arm_to(s, sh[s], wrist, pole, (wrist - e0).normalized())
        sx = -1; s = 'R'                                       # 靠立柱的手自然垂著、微微往前
        dr = Vector((0.10 * sx, -0.10, -1.0)).normalized()
        wr = sh[s] + dr * (reach * 0.975)
        arm_to(s, sh[s], wr, Vector((0.25 * sx, 1.0, -0.35)), dr)
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 16, 4, 26); pose(t); keyall(f)
        clip_ = key_dhandle(dh, f, 'L', WX)
        key_cables(cbl, stack, f, WX, clip_, XF)
    CAM = dict(loc=(3.6, -1.8, 1.4), tgt=(-0.1, 0.3, 1.05), lens=56, stage=(-0.05, 0.25, 0.9))
