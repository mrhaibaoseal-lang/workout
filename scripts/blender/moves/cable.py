# 動作批次：滑輪。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {'pulldown': {'lean_back': True}}

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
