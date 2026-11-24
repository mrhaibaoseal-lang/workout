# 動作批次：地板徒手。負責：Gemini（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {'pushup': {}}

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
