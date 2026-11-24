# 動作批次：滑輪。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    'pulldown': {'lean_back': True},
    # angles＝動作卡 docs/3d-moves/cable.md 的範圍（寫法見 scripts/blender/README.md；範圍照卡片，不照量到的值）。
    'tricepsPushdown': {'angles': {'elbow': {'min': (75, 90), 'max': (160, 175)}, 'uarm_vert': (0, 15), 'uarm_trunk': (0, 20), 'trunk_lean': (0, 15)}},
    'overheadCableExt': {'lean_back': True, 'angles': {'elbow': {'min': (55, 75), 'max': (160, 175)}, 'uarm_vert': (150, 180), 'trunk_lean': (0, 20)}},
    'straightArmPulldown': {'angles': {'elbow': (150, 168), 'uarm_vert': {'min': (0, 20), 'max': (130, 155)}, 'trunk_lean': (25, 45), 'knee': (130, 170)}},
    'facePull': {'angles': {'elbow': {'min': (55, 90), 'max': (165, 180)}, 'uarm_vert': {'min': (80, 100), 'max': (95, 120)}, 'trunk_lean': (0, 10)}},
    'cableCrunch': {'lean_back': True, 'angles': {'trunk_lean': {'min': (0, 15), 'max': (45, 65)}}},
}

# ======================= 高位下拉 =======================
# 坐在使用者的啞鈴椅上、面向前端立柱，腳踝勾在滾筒下；寬握直槓從前上方拉到上胸，手肘往下往後、上身後仰靠向靠背。
if MOVE == 'pulldown':
    N = 48
    HIP_Z, HIP_Y = SEAT_Z + 0.10, 0.0
    GX = 0.40                                         # 握距（手腕 x）
    WHEEL = Vector((0, POST_Y + 0.09, POST_TOP - 0.03))  # 滑輪靠使用者那一側
    stack = build_bench(24)                            # 靠背往後倒 24 度，拉到底時背剛好靠上
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
        return trunk(hm + Vector((0, 0, 0.04)), lam * 0.5, lam, lam * 0.35 - D(20) * (1 - t))   # 拉到底時頭維持往前看，不往後靠
    # 起點：手臂幾乎打直、往前上方（立柱在前面，鋼索斜斜的）；終點：槓子到上胸
    cp0, sh0 = upper(0.0)
    reach = (blen['upper_arm.L'] + blen['forearm.L']) * 0.97
    BAR_Y0 = -0.27
    dx = GX - sh0['L'].x
    z0 = sh0['L'].z + math.sqrt(max(reach ** 2 - dx * dx - (BAR_Y0 - sh0['L'].y) ** 2, 0)) + 0.065
    P0 = Vector((0, BAR_Y0, z0))
    cp1, sh1 = upper(1.0)
    P1 = cp1((0, -0.17, 1.33)) + Vector((0, -0.06, 0.0))   # 上胸（鎖骨下方）
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
        stack.location = (0, 0, rise); stack.keyframe_insert('location', frame=f)
        key_stretch(cab1, WHEEL + Vector((0, 0.06, 0)), P + Vector((0, 0, 0.06)), f)
        key_stretch(cab3, Vector((0, POST_Y + 0.055, POST_TOP - 0.10)), Vector((0, POST_Y + 0.055, 1.10 + rise)), f)
    CAM = dict(loc=(4.0, -2.2, 1.45), tgt=(0, -0.12, 1.02), lens=58, stage=(0, -0.05, 1.0))

# ======================= 繩索三頭下壓（三頭族群的範本）=======================
# 一體機（靠背放平）：人跨站在椅子兩側、面向立柱，高位滑輪＋三頭繩。上臂貼身固定、只動手肘：從前臂水平（手肘約 80°）壓到手臂接近打直、手到大腿前。
# 姿勢函式 elbow_hinge 在 moves3d.py，overheadCableExt 用同一個函式。
if MOVE == 'tricepsPushdown':
    N = 48
    HY, LEAN = -0.05, D(8)
    stack, XF = bench_scene(90); rp = build_rope(); cbl = make_cables()
    def pose(t):
        hm = Vector((0, HY, 0.925))
        _, sh = trunk(hm + Vector((0, 0, 0.04)), LEAN * 0.5, LEAN, 0)
        stand_legs(0.15, 0.925, HY, ankle_w=0.27)
        elbow_hinge(sh, t, Vector((0.06, -0.14, -1)), Vector((-0.35, -1, 0)), D(80), D(168))
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 15, 5, 22); pose(t); keyall(f)
        cp_ = key_rope(rp, f, WHEEL_FRONT); key_cables(cbl, stack, f, WHEEL_FRONT, cp_)
    CAM = dict(loc=(3.2, -2.6, 1.35), tgt=(0, -0.20, 1.05), lens=58, stage=(0, 0.0, 0.8))

# ======================= 坐姿繩索過頭三頭伸展（同範本 elbow_hinge，換上臂方向）=======================
# 站姿的標準做法要鋼索從立柱另一側出來，這台做不到（鋼索只從椅子這一側出）。改成：靠背放平，人騎坐在椅面上、背對立柱（機器轉 180°），
# 上身坐直微前傾，雙手握三頭繩在頭後面，上臂指向上方貼著耳朵固定，只動手肘：從手肘約 65° 伸到接近打直。
# 和站姿的差別：鋼索從身後上方斜向上拉（約 35°），伸到頂端時阻力比站姿小。
if MOVE == 'overheadCableExt':
    N = 48
    HY, LEAN = -0.42, D(8)
    stack, XF = bench_scene(90, flip=True); rp = build_rope(); cbl = make_cables()
    WX = XF @ WHEEL_FRONT
    def pose(t):
        hm = Vector((0, HY, 0.60))
        _, sh = trunk(hm + Vector((0, 0, 0.04)), LEAN * 0.8, LEAN, LEAN * 0.7)
        for s, sx in SX:                                      # 騎坐：大腿往前、膝蓋在兩側，小腿垂直
            hj = Vector((0.11 * sx, HY, 0.60)); kn = hj + Vector((0.10 * sx, -0.39, -0.08)); an = Vector((kn.x, kn.y - 0.02, 0.11))
            leg_to(s, hj, an, Vector((0, -1, 0.3)))
        elbow_hinge(sh, t, Vector((0.03, -0.10, 1)), Vector((0.0, 1, 0)), D(65), D(168))
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 18, 5, 22); pose(t); keyall(f)
        cp_ = key_rope(rp, f, WX); key_cables(cbl, stack, f, WX, cp_, XF)
    CAM = dict(loc=(3.4, -1.9, 1.3), tgt=(0, -0.35, 1.0), lens=58, stage=(0, -0.4, 0.8))

# ======================= 直臂下拉（下拉的變化版）=======================
# 一體機（靠背放平）：人跨站在長長的椅面兩側、面向立柱，髖往後坐上身前傾約 35°，手臂幾乎打直（手肘約 155°，全程固定），直槓握距略比肩寬；
# 手臂像鐘擺繞肩膀從前上方（離垂直約 145°）弧線下壓到大腿前（約 10°）。鋼索要拉出約 0.9 m（要使用者確認拉得出來）。
if MOVE == 'straightArmPulldown':
    N = 48
    HY, LEAN, GX = 0.44, D(35), 0.30   # 腳踩在椅子後底座（y≈0.6）前面
    stack, XF = bench_scene(90); bar = build_latbar(GX); cbl = make_cables()
    def pose(t):
        hm = Vector((0, HY, 0.90))
        _, sh = trunk(hm + Vector((0, 0, 0.04)), LEAN * 0.85, LEAN, D(22))
        stand_legs(0.15, 0.90, HY, ankle_w=0.27)
        a = D(145) + (D(10) - D(145)) * t                      # 手臂離垂直的角度（像鐘擺繞肩膀）
        elbow_hinge(sh, 0, Vector((0.04, -math.sin(a), -math.cos(a))), Vector((0, -math.cos(a), math.sin(a))), D(155), D(155))   # 前臂往「手肘正常彎曲」的方向折（手垂下時往前），反過來就是手肘過度伸展、看起來像骨折
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 18, 4, 24); pose(t); keyall(f)
        w = [pb[f'hand.{s}'].matrix.translation + pb[f'hand.{s}'].matrix.col[1].xyz.normalized() * 0.06 for s, _ in SX]
        P = (w[0] + w[1]) / 2
        bar.location = P; bar.keyframe_insert('location', frame=f)
        key_cables(cbl, stack, f, WHEEL_FRONT, P + Vector((0, 0, 0.06)))
    CAM = dict(loc=(3.4, -2.2, 1.3), tgt=(0, 0.05, 1.0), lens=58, stage=(0, 0.1, 0.8))

# ======================= 繩索面拉（划船族群的變化版）=======================
# 一體機（靠背放平）：人跨站在椅面兩側、面向立柱，離立柱約 0.9 m，上身微後仰，雙手握三頭繩從前方、手臂接近打直，
# 拉到臉兩側、手肘高（約和肩同高）往外往後，肩胛骨往後收；末端雙手在耳朵旁。鋼索從前上方約 40° 斜下來（滑輪比頭高很多）。
if MOVE == 'facePull':
    N = 48
    HY, LEAN = 0.40, D(-4)   # 腳踩在椅子後底座（y≈0.6）前面；再近鋼索會更陡
    stack, XF = bench_scene(90); rp = build_rope(); cbl = make_cables()
    def pose(t):
        hm = Vector((0, HY, 0.925))
        cp, sh = trunk(hm + Vector((0, 0, 0.04)), LEAN * 0.5, LEAN, 0)
        stand_legs(0.15, 0.925, HY, ankle_w=0.27)
        for s, sx in SX:
            w0 = sh[s] + Vector((-0.17 * sx, -0.50, 0.10))
            w1 = sh[s] + Vector((-0.02 * sx, -0.23, 0.17))
            wrist = w0.lerp(w1, t)
            hd = Vector((0, -1, 0.15)).lerp(Vector((-0.35 * sx, -0.15, 1)), t)
            arm_to(s, sh[s], wrist, Vector((sx * 1.0, 0.5 * t, 0.15 - 0.6 * t)), hd)
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 20, 5, 20); pose(t); keyall(f)
        cp_ = key_rope(rp, f, WHEEL_FRONT); key_cables(cbl, stack, f, WHEEL_FRONT, cp_)
    CAM = dict(loc=(3.2, -1.2, 1.4), tgt=(0, 0.12, 1.15), lens=58, stage=(0, 0.15, 0.85))

# ======================= 坐姿繩索捲腹（新範本）=======================
# 跪姿的標準做法在這台做不到（跪在椅子旁拉不到：鋼索不夠長）。改成坐姿繩索捲腹：靠背放平，人騎坐在椅面後段（離立柱約 0.9 m，頭捲下去才不會撞到立柱和配重）、
# 面向立柱、兩腿跨在椅子兩側，三頭繩握在頭兩側（耳朵旁），髖固定不動、把脊椎一節一節往下捲（胸口往骨盆靠）；手肘往膝蓋的方向走，不是只把頭往下點。
if MOVE == 'cableCrunch':
    N = 48
    HIP_Y, HIP_Z = 0.35, 0.60
    stack, XF = bench_scene(90); rp = build_rope(); cbl = make_cables()
    def pose(t):
        lh, lc, lhd = D(3) + D(12) * t, D(5) + D(50) * t, D(5) + D(55) * t
        hm = Vector((0, HIP_Y, HIP_Z))
        cp, sh = trunk(hm + Vector((0, 0, 0.04)), lh, lc, lhd)      # 先骨盆、胸、頭，再擺腿（子骨頭相對父骨頭）
        for s, sx in SX:                                           # 騎坐：大腿往前、膝蓋在椅子兩側，小腿垂直
            hj = Vector((0.11 * sx, HIP_Y, HIP_Z)); kn = hj + Vector((0.11 * sx, -0.38, -0.08)); an = Vector((kn.x, kn.y - 0.02, 0.11))
            leg_to(s, hj, an, Vector((0, -1, 0.3)))
        R = RX(lc)
        for s, sx in SX:
            wrist = cp((0.27 * sx, -0.09, 1.58))
            arm_to(s, sh[s], wrist, R @ Vector((sx * 0.3, -1, -0.5)), R @ Vector((-0.3 * sx, -0.2, 1)))
    for f in range(N):
        sc.frame_set(f); t = profile(f, N, 22, 5, 17); pose(t); keyall(f)
        cp_ = key_rope(rp, f, WHEEL_FRONT); key_cables(cbl, stack, f, WHEEL_FRONT, cp_)
    CAM = dict(loc=(4.0, -2.2, 1.45), tgt=(0, 0.1, 1.0), lens=58, stage=(0, 0.2, 0.9))
