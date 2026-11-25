# 動作批次：地板徒手 2（補動作庫缺的 3D 示範）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1、docs/3d-moves/inventory.md）。動作卡：docs/3d-moves/floor2.md
# floor.py 的 legCurl 是別的 session 在做，所以這批另開檔；這裡 exec floor.py 只為了取它的共用函式（fl_*、pr_*），沒有動作會被它啟動。
# MOVE_META 只能寫字面值（hero_proto.py 用 ast 讀）。
MOVE_META = {
    'birdDog': {'angles': {'elbow': (160, 180), 'hip': {'min': (90, 110), 'max': (160, 180)}, 'knee': {'min': (85, 100), 'max': (165, 180)}, 'trunk_lean': (70, 95)}},
    'sidePlank': {'angles': {'elbow.R': (85, 100), 'hip': (165, 180), 'knee': (170, 180)}},
    'proneYTW': {'angles': {'elbow': {'min': (80, 105), 'max': (160, 180)}, 'hip': (165, 180), 'knee': (165, 180)}},
    'towelLegCurl': {'angles': {'knee': {'min': (65, 90), 'max': (150, 175)}, 'trunk_lean': (100, 125)}},
    'slTowelLegCurl': {'angles': {'knee.L': {'min': (65, 90), 'max': (150, 175)}, 'knee.R': (165, 180), 'trunk_lean': (100, 125)}},
    'reverseNordic': {'angles': {'knee': {'min': (45, 60), 'max': (85, 95)}, 'hip': (165, 180), 'trunk_lean': {'min': (0, 5), 'max': (30, 45)}}},
    'sissySquat': {'angles': {'knee': {'min': (85, 110), 'max': (165, 180)}, 'hip': (165, 180), 'trunk_lean': {'min': (0, 6), 'max': (28, 40)}}},
    'declinePushup': {'angles': {'elbow': {'min': (30, 60), 'max': (160, 180)}, 'hip': (165, 180), 'knee': (170, 180)}},
    'elevatedPike': {'angles': {'elbow': {'min': (80, 110), 'max': (160, 180)}, 'knee': (165, 180)}},
}
exec(open(os.path.join(_MDIR, 'floor.py'), encoding='utf-8').read())

# ---------- 身體座標系（躺著、側躺都用）----------
# 身體的三個軸：up＝頭的方向、fr＝胸口朝向、lt＝身體的左邊（lt = up × fr；站著時 up＝+z、fr＝-y、lt＝+x）。
def bf_frame(up, fr):
    up = Vector(up).normalized(); fr = Vector(fr); fr = (fr - up * fr.dot(up)).normalized()
    return up.cross(fr), fr, up

def bf_pt(O, fm, p, z0=0.0):
    """站姿靜止點 p（建模座標）→ 以 O 為 z＝z0 處、身體座標系 fm 擺好的世界座標"""
    lt, fr, up = fm
    return O + lt * p[0] + fr * (-p[1]) + up * (p[2] - z0)

def bf_trunk(hh, fmh, fmc, fmhd):
    """像 trunk，但每段骨頭用完整座標系（可側躺、趴著）。hh＝骨盆骨頭位置；fmh／fmc／fmhd＝骨盆、胸、頭的座標系。
    回傳 (肩位置 {L,R}, 髖關節 {L,R}, 胸頂 ctop)"""
    fl_aimz('hips', hh, fmh[2], fmh[1])
    ctop = hh + fmh[2] * blen['hips']
    fl_aimz('chest', ctop, fmc[2], fmc[1])
    hd = ctop + fmc[2] * (rest['head'][0].z - rest['chest'][0].z)
    fl_aimz('head', hd, fmhd[2], fmhd[1])
    c0, h0 = rest['chest'][0], rest['hips'][0]
    def at(fm, base, p, q):
        return base + fm[0] * (p.x - q.x) + fm[1] * (-(p.y - q.y)) + fm[2] * (p.z - q.z)
    sh = {s: at(fmc, ctop, rest[f'upper_arm.{s}'][0], c0) for s, _ in SX}
    hj = {s: at(fmh, hh, rest[f'thigh.{s}'][0], h0) for s, _ in SX}
    return sh, hj, ctop

def dirA(a):
    """矢狀面（y-z）方向：a＝離「正下方」往 +y（腳的方向）轉的角度（弧度）。0＝垂直往下、90°＝水平往 +y"""
    return Vector((0, math.sin(a), -math.cos(a)))

FOOT_FLOOR = Vector((0, 0.85, -0.5))      # 跪姿、趴姿時腳背朝下、腳尖往後
REACH2 = blen['upper_arm.L'] + blen['forearm.L']

# ======================= 鳥狗式（App：bird_dog） =======================
# 四足跪姿：雙手在肩正下方撐地（手臂打直）、雙膝在髖正下方、背平直（耳肩髖成一線、頭中立）。
# 對側的手和腳同時往前／往後伸直到和地板平行（手臂在耳旁、腿和背成一線），停 1 秒，不轉骨盆、不塌腰，再收回；48 格＝每邊 24 格。
if MOVE == 'birdDog':
    N = 48
    ZK, ZW = 0.07, 0.055                              # 膝蓋關節離地（小腿平貼地板）、手腕離地
    LT, LS = blen['thigh.L'], blen['shin.L']
    ZH = ZK + LT                                      # 髖關節高度（大腿垂直）
    YH = 0.0
    def _lam_sh(lc):
        _, sh = trunk(Vector((0, YH, ZH)), (lc + D(90)) / 2, lc, lc - D(6))
        return sh['L'].z
    lo, hi = D(60), D(90)
    for _ in range(40):                                # 肩高＝手臂打直撐地的高度 → 軀幹微微頭高（約 8°）
        mid = (lo + hi) / 2
        if _lam_sh(mid) > ZW + REACH2 * 0.99: lo = mid
        else: hi = mid
    LC = (lo + hi) / 2
    def pose(f):
        side_a = f < 24                                # 前半：右手＋左腳；後半：左手＋右腳
        e = profile(f % 24, 24, 9, 6, 9)
        _, sh0 = trunk(Vector((0, YH, ZH)), (LC + D(90)) / 2, LC, LC - D(6))
        for s, sx in SX:
            ext_leg = (s == 'L') if side_a else (s == 'R')
            hj = Vector((HIPX[s], YH + 0.04, ZH))
            kn = hj + dirA(D(88) * (e if ext_leg else 0.0)) * LT     # 大腿從垂直擺到水平、小腿一直水平
            an = kn + dirA(D(90)) * LS
            aim(f'thigh.{s}', hj, kn - hj); aim(f'shin.{s}', kn, an - kn); aim(f'foot.{s}', an, FOOT_FLOOR)
        def arms(post):
            for s, sx in SX:
                base = post[s] if post else sh0[s]
                ext = (s == 'R') if side_a else (s == 'L')
                phi = D(92) * (e if ext else 0.0)       # 手臂從垂直往前擺到水平（耳旁）
                d = Vector((0.04 * sx * math.sin(phi), -math.sin(phi), -math.cos(phi)))
                arm_to(s, sh0[s], base + d * (REACH2 * 0.99), Vector((0.35 * sx, 0.5, 0.9)), d)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(4.1, -1.9, 1.0), tgt=(0, 0.0, 0.34), lens=52, stage=(0, 0.0, 1.2))

# ======================= 側棒式（前臂版；App：side_plank） =======================
# 側躺、下面那隻手（右）的前臂撐地（手肘在肩正下方、前臂朝前垂直身體），雙腳上下疊在一起；髖部抬起，頭、肩、髖、膝、踝成一直線。
# 上面的手（左）叉在髖上（保護肩膀）。靜止姿勢，只有呼吸的輕微起伏。
if MOVE == 'sidePlank':
    N = 48
    EZ, ZA = 0.052, 0.075                               # 手肘離地（前臂厚度）、下面腳的踝關節離地（鞋側著地）
    UL, FL = blen['upper_arm.L'], blen['forearm.L']
    Z_AN = rest['shin.R'][1].z
    def frame_at(th):
        up = Vector((0, -math.cos(th), math.sin(th)))   # 腳→頭
        lt = Vector((0, math.sin(th), math.cos(th)))    # 身體左邊（往上）
        return (lt, Vector((1, 0, 0)), up)              # 胸口朝 +x（鏡頭那側）
    def P_of(th):
        fm = frame_at(th); O = Vector((0, 0.60, ZA))
        return fm, (lambda p: bf_pt(O, fm, p, Z_AN))
    lo, hi = 0.0, D(40)
    for _ in range(40):
        mid = (lo + hi) / 2
        if P_of(mid)[1](rest['upper_arm.R'][0]).z < EZ + UL * 0.985: lo = mid
        else: hi = mid
    TH = (lo + hi) / 2
    def pose(ph):
        fm, P = P_of(TH + D(0.8) * ph)
        lt, fr, up = fm
        sh, hj, ctop = bf_trunk(P(rest['hips'][0]), fm, fm, fm)
        anR = P(rest['shin.R'][1]); anL = anR + lt * 0.22 + Vector((0, 0.01, 0))   # 兩腳疊在一起（上面的高 22 cm＝兩條腿平行相貼）
        for s, sx in SX:
            an_ = anR if s == 'R' else anL
            leg_to(s, hj[s], an_, Vector((0, 0.0, 1.0)), fr)
            fl_aimz(f'foot.{s}', an_, fr, -up)             # 腳尖朝前（胸口方向）、腳底朝腳的方向（像站著的腳轉成側躺）→ 腳外側著地、兩腳疊齊
        shR = sh['R']                                      # 下面的手臂：手肘在肩正下方、前臂朝前貼地
        eb = Vector((shR.x, shR.y, EZ)); wr = eb + Vector((FL * 0.99, 0, 0))
        aim('upper_arm.R', shR, eb - shR); aim('forearm.R', eb, wr - eb); aim('hand.R', wr, Vector((1, 0, -0.1)))
        wl = hj['L'] + lt * 0.11 + fr * 0.03               # 上面的手：叉在髖上，手肘朝上
        arm_to('L', sh['L'], wl, lt * 1.0 - up * 0.3 - fr * 0.4, fr - up * 0.6)
    for f in range(N):
        sc.frame_set(f); pose(math.sin(2 * math.pi * f / N)); keyall(f)
    CAM = dict(loc=(3.4, -2.2, 1.0), tgt=(0, 0.0, 0.36), lens=52, stage=(0, 0.0, 1.2))

# ======================= 俯臥 Y-T-W（App：prone_ytw） =======================
# 趴在地板、額頭微抬、雙腳伸直。依序做三個姿勢：Y（手臂斜向前方、拇指朝上）→ T（手臂打開和肩同高）→ W（手肘彎 90°、往身體兩側收，肩胛夾緊）。
# 每個姿勢：手臂離地約 15 cm、胸口只離地一點點（不聳肩、不仰頭）、停一下再放下。72 格＝每個姿勢 24 格。
if MOVE == 'proneYTW':
    N = 72
    YH, ZB = 0.30, 0.13                                    # 骨盆骨頭的 y、身體中軸離地高度
    def pose(f):
        seg = min(f // 24, 2); e = profile(f % 24, 24, 8, 8, 8)
        a = D(10) * e                                      # 胸口離地的角度（上背微微抬起）
        up0, fr0 = Vector((0, -1, 0)), Vector((0, 0, -1))
        upc = Vector((0, -math.cos(a), math.sin(a)))
        uph = Vector((0, -math.cos(a + D(6)), math.sin(a + D(6))))
        hh = Vector((0, YH, ZB))
        sh0, hj, _ = bf_trunk(hh, bf_frame(up0, fr0), bf_frame(upc, fr0), bf_frame(uph, fr0))
        for s, sx in SX:
            leg_to(s, hj[s], hj[s] + Vector((0, 0.999 * (blen['thigh.L'] + blen['shin.L']), -0.045)), Vector((0, 0, 1)), FOOT_FLOOR)
        def arms(post):
            for s, sx in SX:
                b = post[s] if post else sh0[s]
                wz = 0.06 + 0.17 * e
                dz = wz - b.z
                if seg == 2:                                # W：手腕在肩旁、手肘彎 90° 往身體兩側（手肘朝腳的方向）
                    wrist = b + Vector((0.34 * sx, 0.10, dz)); pole = Vector((0.5 * sx, 1.0, 0.2)); hd = Vector((0.1 * sx, -1, 0.1))
                else:
                    hv = Vector((0.58 * sx, -0.81, 0)) if seg == 0 else Vector((sx, 0, 0))
                    hor = math.sqrt(max((REACH2 * 0.992) ** 2 - dz * dz, 0.0))
                    wrist = b + hv * hor + Vector((0, 0, dz)); pole = Vector((0.2 * sx, 0.3, 1.0)); hd = Vector((hv.x, hv.y, 0.1))
                arm_to(s, sh0[s], wrist, pole, hd)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(2.3, -2.9, 1.5), tgt=(0, 0.1, 0.1), lens=50, stage=(0, 0.2, 1.3))

# ======================= 毛巾滑行腿後彎舉（App：towel_leg_curl；單腳版 sl_towel_leg_curl） =======================
# 仰躺在光滑地板（兩條毛巾墊在腳跟下），臀橋姿勢把髖抬高（肩膀、髖、膝成一直線）並維持不動；腳跟往臀部滑近到膝蓋約 80°，停一下，再慢慢滑出去到腿接近伸直。
# 單腳版：另一隻腳離地，伸直、和身體成一直線懸在空中。
def tl_setup(phi, C, trunk_c=0.40):
    c = Vector((0, math.cos(phi), -math.sin(phi)))
    hj = C - c * trunk_c + RX(-D(90) - phi) @ Vector((0, 0, -0.04))
    return hj, c
if MOVE in ('towelLegCurl', 'slTowelLegCurl'):
    N = 48
    SINGLE = (MOVE == 'slTowelLegCurl')
    PHI = D(28); TC = 0.40
    C = Vector((0, 0.45, 0.155))
    hj0, c0 = tl_setup(PHI, C, TC)
    LL = blen['thigh.L'] + blen['shin.L']
    dz = hj0.z - 0.11
    Y_FAR = hj0.y - math.sqrt(max((LL * 0.975) ** 2 - dz * dz, 0.01))     # 腿接近伸直
    Y_NEAR = hj0.y - math.sqrt(max(0.50 ** 2 - dz * dz, 0.01))            # 膝蓋約 75～80°
    towels = [build_towel() for _ in range(1 if SINGLE else 2)]
    TOE_UP = Vector((0, -0.45, 0.89))
    def pose(e):
        fy = Y_FAR + (Y_NEAR - Y_FAR) * e
        hh, c, sh, J = bridge_pose(PHI, C, fy, foot_x=0.12, trunk_c=TC)
        for s, sx in SX:
            an = Vector((0.12 * sx, fy, 0.11))
            if SINGLE and s == 'R':
                tip = J[s] + (-c) * (LL * 0.999)                  # 另一腳伸直、和身體成一直線
                leg_to(s, J[s], tip, Vector((0.25 * sx, -0.6, 1.0)), (-c + Vector((0, 0, 0.6))).normalized())
            else:
                leg_to(s, J[s], an, Vector((0.25 * sx, -0.6, 1.0)), TOE_UP)
            fl_arm_floor(s, sx, sh[s])
        for i, tw in enumerate(towels):
            sx = 1 if i == 0 else -1
            tw.location = Vector((0.12 * sx, fy + 0.02, 0.0)); tw.keyframe_insert('location')
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 5, 19)); keyall(f)       # 腳跟往臀部滑 20 格、停 5、慢滑出去 19、停 4
    CAM = dict(loc=(3.6, -1.9, 1.1), tgt=(0, 0.0, 0.3), lens=48, stage=(0, 0.0, 1.2))

# ======================= 反向北歐（App：reverse_nordic） =======================
# 跪在軟墊上、小腿平貼地板往後、腳背貼地。從膝蓋到頭保持一直線（髖不彎），整個人慢慢往後倒到約 35°（大腿前側拉長、股四頭出力），再用大腿力量把自己拉回直立。
# 雙手往前平舉當平衡（肩高）。
if MOVE == 'reverseNordic':
    N = 48
    KY, KZ = -0.10, 0.07
    LT, LS = blen['thigh.L'], blen['shin.L']
    def pose(t):
        b = D(36) * t
        u = Vector((0, math.sin(b), math.cos(b)))
        fm = bf_frame(u, Vector((0, -1, 0)))
        Hm = Vector((0, KY, KZ)) + u * LT                    # 兩髖關節的中點
        fmhd = bf_frame(Vector((0, math.sin(b - D(14)), math.cos(b - D(14)))), Vector((0, -1, 0)))
        sh, hj, _ = bf_trunk(Hm + u * 0.04, fm, fm, fmhd)
        for s, sx in SX:
            kn = Vector((HIPX[s], KY, KZ)); an = kn + Vector((0, LS, 0))
            aim(f'thigh.{s}', hj[s], kn - hj[s]); aim(f'shin.{s}', kn, an - kn); aim(f'foot.{s}', an, FOOT_FLOOR)
        def arms(post):
            for s, sx in SX:
                base = post[s] if post else sh[s]
                d = Vector((0.04 * sx, -1.0, 0.0))
                arm_to(s, sh[s], base + d * (REACH2 * 0.985), Vector((0.3 * sx, 0.3, 1.0)), d)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 18)); keyall(f)      # 往後倒 22 格（約 2 秒）、停 4、拉回 18
    CAM = dict(loc=(4.3, -1.4, 1.2), tgt=(0, 0.15, 0.6), lens=52, stage=(0, 0.15, 1.2))

# ======================= 西西深蹲（單手扶柱；App：sissy_squat） =======================
# 腳跟離地、左手扶住身旁的立柱（用使用者的一體機立柱，機器轉 -90° 放在左邊；扶穩就好，不靠手拉）、右手放胸前。
# 膝蓋往前推、髖往前頂，膝、髖、肩成一直線，整條線往後倒（約 34°）；小腿跟著往前傾約 50°；到底再把膝蓋收回，回直立。髖不彎、背不圓。
if MOVE == 'sissySquat':
    N = 48
    place_bench2(0, -90, (1.04, 0, 0))     # 立柱在 x＝0.42（左邊），機器其餘部分往外
    bpy.data.objects['stack'].location.z += 0.70          # 配重啞鈴組滑到立柱上方，不擋手
    LT, LS = blen['thigh.L'], blen['shin.L']
    ZA = 0.125; FOOT_PITCH = D(50)                         # 腳跟離地：腳掌和地板夾 50°
    def pose(t):
        g, b = D(50) * t, D(34) * t                         # 小腿前傾、大腿＋軀幹後仰
        A = Vector((0, 0, ZA))
        kmid = A + Vector((0, -math.sin(g), math.cos(g))) * LS
        u = Vector((0, math.sin(b), math.cos(b)))
        Hm = kmid + u * LT
        fm = bf_frame(u, Vector((0, -1, 0)))
        fmhd = bf_frame(Vector((0, math.sin(b * 0.4), math.cos(b * 0.4))), Vector((0, -1, 0)))
        sh, hj, _ = bf_trunk(Hm + u * 0.04, fm, fm, fmhd)
        for s, sx in SX:
            leg_to(s, hj[s], Vector((HIPX[s], 0, ZA)), Vector((0, -1, 0)), Vector((0, -math.cos(FOOT_PITCH), -math.sin(FOOT_PITCH))))
        def arms(post):
            arm_to('L', sh['L'], Vector((0.355, 0.0, 1.10)), Vector((-0.5, 0.6, -0.8)), Vector((1.0, 0.0, 0.0)))
            wr = hj['R'] - fm[0] * 0.14 + fm[2] * 0.10 + fm[1] * 0.02              # 右手叉腰（跟著軀幹轉）
            arm_to('R', sh['R'], wr, -fm[0] * 1.0 - fm[2] * 0.2 - fm[1] * 0.2, fm[1] * 0.6 - fm[2] * 0.6)
        fl_follow_loop(arms)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 18)); keyall(f)
    CAM = dict(loc=(3.5, -2.7, 1.3), tgt=(0.25, -0.05, 0.75), lens=55, stage=(0.1, -0.1, 1.1))

# ======================= 腳抬高伏地挺身（App：decline_pushup） =======================
# 和伏地挺身一樣（身體一直線、手肘往後約 45°），但腳尖放在椅子上（離地約 50 cm），身體頭低腳高；手在肩正下方偏外。
def fp_pushup_body(theta, toe_y, toe_z):
    return pr_body(theta, toe_y=toe_y, foot=0.15, toe_z=toe_z)

if MOVE == 'declinePushup':
    N = 48
    place_bench2(90, 180, (0, 1.45, 0))                    # 椅子轉 180°、靠背放平當腳墊（頂面約 50 cm，前緣在 y＝0.6：只有腳尖踩在上面），立柱在人後面很遠
    TOE_Y, TOE_Z, WRIST_Z = 0.72, 0.50, 0.055
    def sh_at(th): return pr_shoulders(th, toe_y=TOE_Y, toe_z=TOE_Z)
    def theta_for(h):
        lo, hi = -D(35), D(60)
        for _ in range(40):
            mid = (lo + hi) / 2
            if sh_at(mid)['L'].z < h: lo = mid
            else: hi = mid
        return (lo + hi) / 2
    TH_TOP, TH_BOT = theta_for(WRIST_Z + REACH2 * 0.985), theta_for(0.21)
    S_TOP = sh_at(TH_TOP)
    WRIST = {s: Vector((S_TOP[s].x * 1.18, S_TOP[s].y + 0.03, WRIST_Z)) for s in ('L', 'R')}
    def pose(t):
        th = TH_TOP + (TH_BOT - TH_TOP) * t
        u, n, lam, J, hm = pr_body(th, toe_y=TOE_Y, toe_z=TOE_Z)
        _, sh = trunk(hm + u * 0.04, lam, lam, lam - D(12))
        for s, sx in SX:
            toe, an, hj = J[s]
            kn = an + u * blen[f'shin.{s}']
            aim(f'thigh.{s}', hj, kn - hj); aim(f'shin.{s}', kn, an - kn); aim(f'foot.{s}', an, toe - an)
            arm_to(s, sh[s], WRIST[s], Vector((0.75 * sx, 0.65, 0.0)), Vector((0.12 * sx, -1, -0.35)))
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 18, 4, 20)); keyall(f)
    CAM = dict(loc=(3.8, -1.3, 0.95), tgt=(0, 0.2, 0.4), lens=52, stage=(0, 0.2, 1.1))

# ======================= 腳抬高屈體伏地挺身（App：elevated_pike） =======================
# 和屈體伏地挺身一樣的倒 V 字，但腳放在椅子上（約 50 cm），髖更高、身體更垂直；往下時頭頂往兩手前緣靠近，手肘彎到約 90°，再推起。
if MOVE == 'elevatedPike':
    N = 48
    place_bench2(90, 180, (0, 1.1, 0))
    A_Y, A_Z, A_X = 0.46, 0.635, 0.17                       # 腳踝（腳尖壓在椅子上，腳跟微抬）
    W_Y, W_Z, W_X = -0.62, 0.055, 0.30                      # 手腕
    LEG = (blen['thigh.L'] + blen['shin.L']) * 0.995
    TORSO = 0.48
    def pk_hip(Sy, Sz):
        dy, dz = Sy - A_Y, Sz - A_Z; Dd = math.hypot(dy, dz)
        a = (LEG * LEG - TORSO * TORSO + Dd * Dd) / (2 * Dd); h = math.sqrt(max(LEG * LEG - a * a, 0))
        ux, uz = dy / Dd, dz / Dd
        return A_Y + a * ux + h * uz, A_Z + a * uz - h * ux
    def pk_shoulder(t):
        d = 0.526 + (0.395 - 0.526) * t; al = D(68 + (56 - 68) * t)
        return W_Y + d * math.cos(al), W_Z + d * math.sin(al)
    def pk_place(Sy, Sz):
        Hy, Hz = pk_hip(Sy, Sz)
        lam = math.atan2(-(Sy - Hy), Sz - Hz)
        hm = Vector((0, Hy, Hz))
        _, sh = trunk(hm + RX(lam) @ UP * 0.04, lam, lam, lam + D(4))
        for s, sx in SX:
            hj = hm + Vector((HIPX[s], 0, 0)); an = Vector((A_X * sx, A_Y, A_Z))
            leg_to(s, hj, an, Vector((0.05 * sx, -1.0, 0.0)), Vector((0, -math.cos(D(40)), -math.sin(D(40)))))
            arm_to(s, sh[s], Vector((W_X * sx, W_Y, W_Z)), Vector((0.5 * sx, 1.0, 0.15)), Vector((0.02 * sx, -1, -0.12)))
        return sh['L']
    def pose(t):
        Sy, Sz = pk_shoulder(t); dy = dz = 0.0
        for _ in range(3):
            nom = pk_place(Sy - dy, Sz - dz)
            shoulder_follow()
            post = pb['upper_arm.L'].head
            dy, dz = post.y - nom.y, post.z - nom.z
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 22, 4, 15)); keyall(f)
    CAM = dict(loc=(3.6, -1.9, 1.1), tgt=(0, 0.0, 0.55), lens=52, stage=(0, 0.0, 1.1))
