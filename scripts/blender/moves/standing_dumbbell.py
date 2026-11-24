# 動作批次：站姿啞鈴。負責：Gemini（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {'squat': {'bell': True}}

# ======================= 啞鈴深蹲 =======================
if MOVE == 'squat':
    N = 48
    def pose(t):
        ts, tt, lam = D(38) * t, D(78) * t, D(36) * t
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
