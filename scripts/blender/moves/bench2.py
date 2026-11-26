# 動作批次：椅子 2（補動作庫缺的 3D 示範）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1、docs/3d-moves/inventory.md）。動作卡：docs/3d-moves/bench2.md
# 這裡 exec floor2.py（取身體座標系 bf_*）和 bench.py（取 supine、grip、press_path…）的共用函式；那兩個檔的動作不會被啟動（MOVE 不同名）。
# MOVE_META 只能寫字面值（hero_proto.py 用 ast 讀）。
MOVE_META = {
    'dbFly': {'bell': True, 'lean_back': True, 'angles': {'elbow': (156, 170), 'uarm_vert': {'min': (80, 100), 'max': (165, 178)}}},
    'declineCrunch': {'bell': True, 'lean_back': True, 'angles': {'trunk_lean': {'min': (55, 72), 'max': (95, 110)}, 'knee': (85, 125)}},
    'sideLyingLateral': {'bell': True, 'lean_back': True, 'angles': {'elbow.R': (155, 175)}},
    'concentrationCurl': {'bell': True, 'angles': {'elbow.R': {'min': (35, 55), 'max': (160, 180)}, 'knee': (85, 125), 'trunk_lean': (40, 72)}},
    'benchDip': {'angles': {'elbow': {'min': (75, 100), 'max': (150, 175)}, 'knee': (100, 175)}},
    'elevatedBenchDip': {'angles': {'elbow': {'min': (75, 100), 'max': (150, 175)}, 'knee': (145, 180)}},
}
exec(open(os.path.join(_MDIR, 'floor2.py'), encoding='utf-8').read())
exec(open(os.path.join(_MDIR, 'bench.py'), encoding='utf-8').read())

def kill_bell(side):
    """只留一隻手的啞鈴：把 side（'L' 或 'R'）手上的啞鈴面刪掉（做法同 bench.py 的 pullover）"""
    import bmesh
    _hero = bpy.data.objects['hero']; _bm = bmesh.new(); _bm.from_mesh(_hero.data)
    _pa = _bm.faces.layers.int.get('part'); _dl = _bm.verts.layers.deform.verify()
    _gi = _hero.vertex_groups[f'hand.{side}'].index
    _kill = [f_ for f_ in _bm.faces if PART_NAMES[f_[_pa]].startswith('bell')
             and all(v[_dl].get(_gi, 0) > 0.5 for v in f_.verts)]
    bmesh.ops.delete(_bm, geom=_kill, context='FACES'); _bm.to_mesh(_hero.data); _bm.free()
    print('[kill_bell]', side, '面數', len(_kill))

def leg_side(s, hj, an, pole, back, foot_dir):
    """側躺用的腿：像 leg_to，但大腿、小腿的「後面」（骨頭 z 軸）朝 back（身體背面），不照世界座標決定滾轉；
    這樣側躺時兩條大腿的剖面和骨盆同方向，褲子在胯下不會互穿。腳底朝小腿方向。"""
    k = ik2(hj, an, blen[f'thigh.{s}'], blen[f'shin.{s}'], pole)
    fl_aimz(f'thigh.{s}', hj, k - hj, back); fl_aimz(f'shin.{s}', k, an - k, back)
    fl_aimz(f'foot.{s}', an, foot_dir, an - k)

def trunk_over(target_mid, lam_h, lam_c, lam_hd):
    """先擺一次 trunk 量出肩膀中點，再平移髖讓肩膀中點落在 target_mid。回傳 (髖位置 hh, chest_pt, 肩 {L,R})"""
    h0 = Vector((0, 0, 0.9)); cp, sh = trunk(h0, lam_h, lam_c, lam_hd)
    hh = h0 + (target_mid - (sh['L'] + sh['R']) / 2)
    cp, sh = trunk(hh, lam_h, lam_c, lam_hd)
    return hh, cp, sh

# ======================= 啞鈴平躺飛鳥（App：db_fly） =======================
# 平躺（靠背 90°＝平）、啞鈴對握，手肘固定微彎（約 165°）從胸口正上方往兩側打開到手臂約與肩同高（胸口有拉開感），再像抱樹一樣合起來。
if MOVE == 'dbFly':
    N = 48
    build_bench(90)
    BEND = D(16)
    def pose(t):
        dv, nv, cp, sh = supine(90, -0.10, -0.30)
        top = Z_
        for s, sx in SX:
            phi = D(8) + D(78) * t                         # 頂端手臂近乎垂直（8°）→ 打開到約與肩同高（86°）
            out = X_ * sx
            a = top * math.cos(phi) + out * math.sin(phi)
            close = top * math.sin(phi) - out * math.cos(phi)
            e = sh[s] + a * UL
            fd = a * math.cos(BEND) + close * math.sin(BEND)
            w = e + fd * FL
            grip(s, sh[s], e, w, fd, dv)                   # 對握：握把沿身體長軸、掌心相對
            stat_arm(s, sh[s], e, w, -dv)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -1.2, 1.6), tgt=(0, 0.15, 0.8), lens=50, stage=(0, 0.15, 1.2))

# ======================= 下斜捲腹（App：decline_crunch；腳勾椅子前端滾筒） =======================
# 躺在稍微下斜（靠背 100°）的椅子上，膝蓋彎約 100°、腳踝勾在前端的滾筒後面；雙手抱一顆啞鈴貼在胸口（啞鈴立在胸前，兩手托住上端；使用者 2026-11-26 要求）。
# 用腹部把上背捲離椅面（約 36°）、下背留在椅面上，停一下，慢慢放回（背不用完全碰到底）。
if MOVE == 'declineCrunch':
    N = 48
    kill_bell('L')                                         # 只留一顆啞鈴（右手那顆），雙手一起抱著
    build_bench(100)
    BACK = 100
    HOLD_H = 0.17                                         # 啞鈴握把離胸口的高度
    def pose(t):
        dv, nv, hg = padframe(BACK)
        lam_h = -D(BACK)
        lam_c = lam_h + D(36) * t                          # 上背捲起（脊椎彎曲）
        lam_hd = lam_c + D(10 - 6 * t)                     # 下巴微收、眼睛看膝蓋方向
        h = hg + nv * 0.155 + dv * (-0.02)
        cp, sh = trunk(h, lam_h, lam_c, lam_hd)
        for s, sx in SX:
            hj = h + RX(lam_h) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
            an = Vector((0.13 * sx, -0.41, 0.16))          # 腳背勾在滾筒下面：腳尖往前下方伸、滾筒壓在腳背上（腳踝在滾筒後方約 12 cm）
            tdir = Vector((0, -0.75, -0.66))
            leg_to(s, hj, an, Vector((0.3 * sx, -0.5, 1.0)), tdir)
            fl_aimz(f'foot.{s}', an, tdir, Vector((0, 0.66, -0.75)))     # 腳背朝前上方（滾筒壓在腳背）、腳底朝後下方
        c0 = rest['chest'][0]
        p0 = Vector((0.0, c0.y, c0.z + 0.17))
        hold0 = cp(p0)
        a = (cp(p0 + Vector((0, -1, 0))) - hold0).normalized()        # 胸口往外（朝上）的方向：啞鈴立在胸前，軸沿著它
        hold = hold0 + a * HOLD_H
        for s, sx in SX:                                    # 雙手托著啞鈴上端（做法同 bench.py 的 pullover 雙手捧一顆）
            wrist = hold + X_ * (0.10 * sx) - a * 0.03
            pole = (X_ * sx + (-a) * 0.4).normalized()
            e = elbow_ik(s, sh[s], wrist, pole)
            hd = (-X_ * sx + a * 0.25).normalized()
            grip(s, sh[s], e, wrist, hd, a)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 18, 6, 18)); keyall(f)     # 捲起 18 格、頂端停 6、放回 18、底部停 6
    CAM = dict(loc=(3.3, -1.5, 1.4), tgt=(0, 0.1, 0.65), lens=50, stage=(0, 0.1, 1.15))

# ======================= 啞鈴側躺側平舉（App：db_side_lying_lateral） =======================
# 左側躺在斜背（45°）椅子上，左手臂在頭下當枕頭、右手拿啞鈴垂在身前（貼著大腿）。
# 手肘微彎（約 165°）固定，把啞鈴從身體旁畫弧舉到和身體垂直（肩高），停一下，慢慢放回；身體不要往後翻、不甩。
if MOVE == 'sideLyingLateral':
    N = 48
    kill_bell('L')                                         # 下面那隻手（左）當枕頭，不拿啞鈴
    build_bench(45)
    BACK = 45
    BEND = D(14)
    def pose(t):
        dv, nv, hg = padframe(BACK)
        fm = bf_frame(dv, Vector((1, 0, 0)))               # 胸口朝 +x、身體長軸沿靠背；左邊朝椅墊
        lt, fr, up = fm
        h = hg + nv * 0.28 + dv * 0.18
        sh, hj, ctop = bf_trunk(h, fm, fm, bf_frame(dv - nv * 0.1, Vector((1, 0, 0))))
        for s, sx in SX:                                    # 雙腿彎起來疊在一起（側睡的姿勢），膝蓋朝胸口那側
            top = (s == 'R')                                # 右腿在上：再抬高一點，兩腿不互碰
            an = hj[s] - up * (0.36 if top else 0.28) + fr * (0.34 if top else 0.20) + ((-lt) * 0.16 if top else Vector((0, 0, 0)))
            leg_side(s, hj[s], an, fr * 1.0 + ((-lt) * 1.0 if top else Vector((0, 0, 0))), -fr, (-up).normalized())
        # 左手（下面）：手臂往頭的方向伸直、手在頭下
        wl = sh['L'] + up * 0.20 + (-lt) * 0.10 + fr * 0.05   # 手肘彎著，手放在頭下當枕頭（不碰頭枕把手）
        arm_to('L', sh['L'], wl, fr * 1.0 + lt * 0.3, fr)
        # 右手（上面）：手臂從貼著大腿的位置（離身體往腳 0°）畫弧舉到和身體垂直（90°）
        phi = D(12) + D(78) * t
        a = (-up) * math.cos(phi) + (-lt) * math.sin(phi)
        close = (-up) * math.sin(phi) - (-lt) * math.cos(phi)
        e = sh['R'] + a * UL
        fd = a * math.cos(BEND) + (-fr) * math.sin(BEND)    # 手肘微彎，前臂略往身體前方（胸口朝向）收
        w = e + fd * FL
        grip('R', sh['R'], e, w, fd, fr)
        stat_arm('R', sh['R'], e, w, -up)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.4, -1.3, 1.5), tgt=(0, 0.25, 0.7), lens=50, stage=(0, 0.2, 1.2))

# ======================= 集中彎舉（App：db_concentration_curl；右手，左手扶左膝） =======================
# 坐在椅墊前段、雙腳打開（比肩寬）、上身前傾約 45°；右手肘頂在右大腿內側、手臂垂直往下垂，啞鈴從幾乎打直（約 170°）彎到頂（約 45°），
# 手肘不離開大腿。左手放在左膝上撐著。（每邊做；示範右手。）
if MOVE == 'concentrationCurl':
    N = 48
    kill_bell('L')
    place_bench2(90, -90, (0.085, 0.0, 0.0))                # 平躺的椅子轉 90°：人橫坐在座墊上，立柱在右邊遠處（頭不會撞到）
    HIP_Z, HIP_Y = SEAT_Z + 0.10, 0.0
    def legs_geom():
        K = {}; hjs = {}; AN = {}
        for s, sx in SX:
            hj = Vector((HIPX[s], HIP_Y, HIP_Z)); an = Vector((0.40 * sx, -0.30, 0.11))
            K[s] = ik2(hj, an, blen[f'thigh.{s}'], blen[f'shin.{s}'], Vector((0.9 * sx, -1.0, 0.3))); hjs[s] = hj; AN[s] = an
        return hjs, K, AN
    def lean_for(lam):
        cp, sh = trunk(Vector((0, HIP_Y, HIP_Z + 0.04)), lam * 0.5, lam, lam - D(14)); return cp, sh
    def pose(t):
        hjs, K, AN = legs_geom()
        # 右手肘（R，x 為負）頂在右大腿內側：離髖約 70% 處、貼大腿內側往上 5 cm
        hj, kn = hjs['R'], K['R']
        E = hj + (kn - hj) * 0.85 + Vector((0.17, 0, 0.08))
        lo, hi = D(10), D(80)
        for _ in range(40):                                  # 上身前傾角：讓右肩到手肘的距離＝上臂長
            mid = (lo + hi) / 2; _, shm = lean_for(mid)
            if (shm['R'] - E).length > UL * 0.995: lo = mid
            else: hi = mid
        lam = (lo + hi) / 2
        cp, sh = lean_for(lam)
        for s, sx in SX:                                      # 骨盆／胸先擺好，再擺腿
            leg_to(s, hjs[s], AN[s], Vector((0.9 * sx, -1.0, 0.3)), Vector((0.2 * sx, -1, -0.25)))
        u = (E - sh['R']).normalized(); e = sh['R'] + u * UL
        fl = Vector((0.0, -1.0, 0.0)); fl = (fl - u * fl.dot(u)).normalized()
        th = D(172) - D(128) * t                              # 手肘內角：172° → 44°
        fd = -u * math.cos(th) + fl * math.sin(th)
        w = e + fd * FL
        grip('R', sh['R'], e, w, fd, X_)                      # 反握（掌心朝前）：握把左右向
        stat_arm('R', sh['R'], e, w, -(cp(Vector((0, 0, 1))) - cp(Vector((0, 0, 0)))))
        # 左手撐在左膝上
        wl = K['L'] + Vector((0.0, -0.01, 0.10)) + Vector((0.01, 0, 0))
        arm_to('L', sh['L'], wl, Vector((0.8, 0.2, 0.2)), Vector((0, -1, -0.2)))
        stat('前傾角', math.degrees(lam))
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.4, -1.9, 1.1), tgt=(0, -0.1, 0.75), lens=50, stage=(0, 0.0, 1.1))

# ======================= 椅子撐體（App：bench_dip）／腳抬高（elevated_bench_dip） =======================
# 椅子轉 90°（長邊朝人），背對椅子坐在邊緣：雙手撐在椅緣（肩寬、手指朝前扣住邊）、臀部離開椅面往前、雙腳伸出去（一般版腳跟踩地、膝微彎；
# 腳抬高版腳放在另一個高約 45 cm 的墊子上、腿近乎伸直）。手肘往後彎到約 90°（上臂約與地面平行）、肩膀不聳起、身體貼近椅子垂直下降，再推起。
if MOVE in ('benchDip', 'elevatedBenchDip'):
    N = 48
    ELEV = (MOVE == 'elevatedBenchDip')
    Y_E, Z_P = -0.15, 0.50                                  # 椅緣（面向人那側）y 座標、椅面高度
    place_bench2(90, -90, (-0.55, Y_E + 0.15, 0.0))        # 轉 -90°：長邊沿 X、立柱在左邊遠處；人坐在靠背墊那一段前面
    if ELEV:
        pbox('pad', (0, Y_E - 0.95, 0.225), (0.24, 0.17, 0.225), 0.02)    # 腳的墊子（高 45 cm）
    HX = 0.25                                               # 手撐的 x（比肩略寬，大腿才不會碰到手）
    DY = 0.19                                               # 肩膀在手腕前面（-y）多少：上身貼近椅子垂直下降
    def pose(t):
        W = {s: Vector((HX * sx, Y_E + 0.035, Z_P + 0.012)) for s, sx in SX}
        dtop = (UL + FL) * 0.985; dbot = math.sqrt(UL * UL + FL * FL)       # 手肘 170° → 90°
        d = dtop + (dbot - dtop) * t
        sz = W['L'].z + math.sqrt(max(d * d - DY * DY - 0.0, 0.01))
        target = Vector((0, W['L'].y - DY, sz))
        hh, cp, sh = trunk_over(target, D(5), D(5), D(-4))
        for s, sx in SX:
            hj = hh + RX(D(5)) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
            if ELEV: an = Vector((0.12 * sx, Y_E - 0.93, 0.45 + 0.11))
            else: an = Vector((0.12 * sx, Y_E - 0.80, 0.11))
            leg_to(s, hj, an, Vector((0.2 * sx, -0.5, 1.0)), Vector((0, -1, -0.2)) if not ELEV else Vector((0, -0.3, 1.0)))
        for s, sx in SX:
            arm_to(s, sh[s], W[s], Vector((0.25 * sx, 1.0, -0.15)), Vector((0, -1, -0.3)))   # 手肘往後（+y）、手指朝前扣住椅緣
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 4, 18)); keyall(f)
    CAM = dict(loc=(3.4, -1.7, 1.3), tgt=(0, -0.4, 0.62), lens=50, stage=(0, -0.3, 1.2))
