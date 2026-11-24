# 動作批次：椅子。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡：docs/3d-moves/bench.md
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    'benchPress': {'bell': True, 'lean_back': True},
    'inclinePress': {'bell': True, 'lean_back': True},
    'inclineFly': {'bell': True, 'lean_back': True},
    'skullCrusher': {'bell': True, 'lean_back': True},
    'pullover': {'bell': True, 'lean_back': True},
    'inclineCurl': {'bell': True, 'lean_back': True},
    'chestRow': {'bell': True},
    'chestRearFly': {'bell': True},
}

# ---------- 這批共用 ----------
# 靠背座標：dv＝沿靠背往頭的方向，nv＝靠背表面的法線（朝人那一側）。靠背墊面在 HINGE + nv*0.04 那個平面。
# 仰躺：脊椎線離墊面 0.115（背的厚度），trunk 的傾角＝-back_deg。
# 趴在靠背上（胸靠）：把整張椅子繞 Z 轉 180°，人照一般的「面向 -Y、往前傾」寫，不用另外處理骨頭滾轉。
X_ = Vector((1, 0, 0)); Z_ = Vector((0, 0, 1))
N = 48
def tempo(f): return profile(f, N, 22, 4, 15)       # 離心 22 格（約 2 秒）、底部停 4、向心 15、頂端停 7

def padframe(back_deg, flip=False):
    a = D(back_deg); dv = Vector((0, math.sin(a), math.cos(a))); nv = Vector((0, -math.cos(a), math.sin(a)))
    hg = HINGE.copy()
    if flip: dv.y, nv.y, hg.y = -dv.y, -nv.y, -hg.y
    return dv, nv, hg

def aimz(name, head, ydir, zhint):
    """像 aim，但骨頭的 z 軸（手：啞鈴握把方向）照 zhint，用來轉手腕（正握／對握／反握）"""
    yv = ydir.normalized(); zv = (zhint - yv * zhint.dot(yv)).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def grip(s, sh, e, wrist, hand_dir, handle):
    """上臂 sh→e、前臂 e→wrist；握把方向 handle（啞鈴的軸）。前臂跟著轉一半，手腕才不會扭成麻花。"""
    aim(f'upper_arm.{s}', sh, e - sh)
    fd = (wrist - e).normalized()
    dz = X_.cross(fd).normalized()
    hz = handle - fd * handle.dot(fd)
    if hz.length < 1e-4: hz = dz
    hz = hz.normalized()
    if hz.dot(dz) < 0: hz = -hz
    fz = (dz + hz); fz = fz.normalized() if fz.length > 1e-3 else hz
    aimz(f'forearm.{s}', e, wrist - e, fz)
    hh = handle if handle.dot(fz) >= 0 else -handle
    aimz(f'hand.{s}', wrist, hand_dir, hh)

def elbow_ik(s, sh, wrist, pole):
    return ik2(sh, wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)

def ang(a, b):
    a = a.normalized(); b = b.normalized(); return math.degrees(math.acos(max(-1.0, min(1.0, a.dot(b)))))
STAT = {}
def stat(k, v):
    lo, hi = STAT.get(k, (1e9, -1e9)); STAT[k] = (min(lo, v), max(hi, v))
def stat_arm(s, sh, e, w, down_axis):
    if s != 'L': return
    stat('手肘角', ang(sh - e, w - e)); stat('上臂-軀幹', ang(e - sh, down_axis))
def report():
    print('[angles]', MOVE, ' '.join(f'{k} {lo:.0f}~{hi:.0f}°' for k, (lo, hi) in STAT.items()))

UL = blen['upper_arm.L']; FL = blen['forearm.L']

def supine(back_deg, s0, foot_y, foot_x=0.30):
    """仰躺／靠在靠背上：髖、軀幹、頭（下巴微收貼墊）、兩腳平踩地面。回傳 (dv, nv, 胸部變換, 肩)"""
    dv, nv, hg = padframe(back_deg)
    lam = -D(back_deg)
    h = hg + nv * 0.155 + dv * s0
    cp, sh = trunk(h, lam, lam, lam + D(16 if back_deg > 70 else 8))
    for s, sx in SX:
        hj = h + RX(lam) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
        an = Vector((foot_x * sx, foot_y, 0.11))
        k = ik2(hj, an, blen[f'thigh.{s}'], blen[f'shin.{s}'], Vector((0.35 * sx, -0.5, 1.0)))
        aim(f'thigh.{s}', hj, k - hj); aim(f'shin.{s}', k, an - k)
        aim(f'foot.{s}', an, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
        if s == 'L': stat('膝角', ang(hj - k, an - k))
    return dv, nv, cp, sh

def press_path(sh, s, sx, dv, nv, t, top_back, dn=0.30):
    """臥推類：頂端手腕在肩膀正上方略往內、往腳的方向 top_back；底部前臂垂直、上臂離軀幹約 50～60°"""
    # 底部：手肘方向（軀幹座標：往外 0.66、往腳 0.53、往椅面下 0.30；手肘角約 70°），前臂垂直地面
    ed = (X_ * (0.66 * sx) - dv * 0.53 - nv * dn).normalized()
    e1 = sh + ed * UL; w1 = e1 + Z_ * FL
    reach = (UL + FL) * 0.965
    base = sh + X_ * (-0.01 * sx) - dv * top_back      # 頂端啞鈴在肩膀正上方（冰霜等大啞鈴不互撞）
    off = base - sh; dz = math.sqrt(max(reach ** 2 - off.x ** 2 - off.y ** 2, 0)) - off.z
    w0 = base + Z_ * dz
    w = w0.lerp(w1, t) + (X_ * sx) * 0.05 * math.sin(math.pi * t)   # 微弧線（往外）
    pole = (ed + Z_ * 0.0).normalized()
    return w, pole

# ======================= 啞鈴臥推（平躺） =======================
if MOVE == 'benchPress':
    build_bench(90)
    def pose(t):
        dv, nv, cp, sh = supine(90, -0.10, -0.30)
        for s, sx in SX:
            w, pole = press_path(sh[s], s, sx, dv, nv, t, 0.10)
            e = elbow_ik(s, sh[s], w, pole)
            grip(s, sh[s], e, w, Z_, X_)                 # 正握：握把左右向、掌心朝腳
            stat_arm(s, sh[s], e, w, -dv)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -0.9, 1.65), tgt=(0, 0.25, 0.72), lens=50, stage=(0, 0.2, 1.25))

# ======================= 啞鈴上斜臥推（靠背離地 30°） =======================
if MOVE == 'inclinePress':
    build_bench(60)
    def pose(t):
        dv, nv, cp, sh = supine(60, 0.0, -0.36)
        for s, sx in SX:
            w, pole = press_path(sh[s], s, sx, dv, nv, t, 0.04, 0.12)
            e = elbow_ik(s, sh[s], w, pole)
            grip(s, sh[s], e, w, Z_, X_)
            stat_arm(s, sh[s], e, w, -dv)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -1.2, 1.6), tgt=(0, 0.15, 0.85), lens=50, stage=(0, 0.15, 1.2))

# ======================= 啞鈴上斜飛鳥（靠背離地 30°，手肘固定微彎） =======================
if MOVE == 'inclineFly':
    build_bench(60)
    BEND = D(18)
    def pose(t):
        dv, nv, cp, sh = supine(60, 0.0, -0.36)
        top = (Z_ + nv * 0.35).normalized()             # 頂端：手臂大致垂直地面、在上胸正上方
        for s, sx in SX:
            phi = D(10) + D(78) * t                       # 從頂端（10°）打開到約與軀幹平面同高（88°）
            out = (X_ * sx - top * (X_ * sx).dot(top)).normalized()
            a = top * math.cos(phi) + out * math.sin(phi)
            close = top * math.sin(phi) - out * math.cos(phi)
            e = sh[s] + a * UL
            fd = a * math.cos(BEND) + close * math.sin(BEND)
            w = e + fd * FL
            grip(s, sh[s], e, w, fd, dv)                 # 對握：握把沿身體長軸、掌心相對
            stat_arm(s, sh[s], e, w, -dv); stat('手臂離垂直', ang(a, top) if s == 'L' else 0)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -1.2, 1.6), tgt=(0, 0.15, 0.85), lens=50, stage=(0, 0.15, 1.2))

# ======================= 啞鈴仰臥三頭伸展（平躺） =======================
if MOVE == 'skullCrusher':
    build_bench(90)
    def pose(t):
        dv, nv, cp, sh = supine(90, -0.10, -0.30)
        ua = (Z_ + dv * 0.18).normalized()               # 上臂往頭的方向傾約 10°，整組不動
        for s, sx in SX:
            e = sh[s] + (ua + X_ * (-0.02 * sx)).normalized() * UL
            flex = D(8) + D(100) * t                     # 手肘從近乎打直（172°）彎到約 72°
            fd = (ua * math.cos(flex) + dv * math.sin(flex) * 1.0 - Z_ * 0.0)
            fd = (fd - ua * 0.0).normalized()
            fd = (fd + X_ * (0.06 * sx)).normalized()    # 前臂略往外，啞鈴落在頭兩側
            w = e + fd * FL
            grip(s, sh[s], e, w, fd, X_.cross(fd))       # 對握
            stat_arm(s, sh[s], e, w, -dv)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -0.8, 1.65), tgt=(0, 0.3, 0.75), lens=50, stage=(0, 0.2, 1.25))

# ======================= 啞鈴仰臥拉舉（順著椅子躺，雙手捧一顆） =======================
if MOVE == 'pullover':
    build_bench(90)
    # 左手的啞鈴刪掉，只留右手那顆（雙手一起捧著它）
    import bmesh
    _hero = bpy.data.objects['hero']; _bm = bmesh.new(); _bm.from_mesh(_hero.data)
    _pa = _bm.faces.layers.int.get('part'); _dl = _bm.verts.layers.deform.verify()
    _gi = _hero.vertex_groups['hand.L'].index
    _kill = [f_ for f_ in _bm.faces if PART_NAMES[f_[_pa]].startswith('bell')
             and all(v[_dl].get(_gi, 0) > 0.5 for v in f_.verts)]
    bmesh.ops.delete(_bm, geom=_kill, context='FACES'); _bm.to_mesh(_hero.data); _bm.free()
    print('[pullover] 刪掉左手啞鈴面數', len(_kill))
    BEND = D(22)
    def pose(t):
        dv, nv, cp, sh = supine(90, -0.10, -0.30)
        mid = (sh['L'] + sh['R']) / 2
        phi = D(4) + D(38) * t                          # 從胸口正上方往頭後畫弧到額頭上方約 42°（公仔頭大、手短，再往後前臂會穿過臉；待使用者決定）
        a = Z_ * math.cos(phi) + dv * math.sin(phi)
        close = Z_ * math.sin(phi) - dv * math.cos(phi)
        hold = mid + a * 0.49 + close * 0.04  # 兩手在啞鈴握把中段
        for s, sx in SX:
            wrist = hold + X_ * (0.075 * sx) - a * 0.03
            pole = (close + X_ * (0.6 * sx)).normalized()
            e = elbow_ik(s, sh[s], wrist, pole)
            hd = (-X_ * sx + a * 0.25).normalized()      # 手指朝中間互扣，掌心托住啞鈴
            grip(s, sh[s], e, wrist, hd, a)              # 啞鈴的軸順著手臂方向（垂直捧著）
            stat_arm(s, sh[s], e, wrist, -dv)
        stat('手臂離垂直', math.degrees(phi))
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -0.6, 1.7), tgt=(0, 0.4, 0.75), lens=48, stage=(0, 0.3, 1.3))

# ======================= 上斜椅啞鈴彎舉（靠背離地 45°） =======================
if MOVE == 'inclineCurl':
    build_bench(45)
    def pose(t):
        dv, nv, cp, sh = supine(45, 0.05, -0.34)
        down = -Z_; fwd = Vector((0, -1, 0))
        for s, sx in SX:
            e = sh[s] + (down + X_ * (0.20 * sx)).normalized() * UL   # 上臂垂直地面不動（略往外，啞鈴不掃到大腿）
            th = D(6) + D(128) * t                       # 手肘 174° → 約 46°
            fd = down * math.cos(th) + fwd * math.sin(th)
            fd = (fd + X_ * (0.10 * sx)).normalized()
            w = e + fd * FL
            grip(s, sh[s], e, w, fd, X_)                 # 反握：掌心朝前，握把左右向
            stat_arm(s, sh[s], e, w, -dv); stat('上臂離垂直', ang(e - sh[s], down) if s == 'L' else 0)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -1.4, 1.5), tgt=(0, 0.1, 0.8), lens=50, stage=(0, 0.1, 1.15))

# ======================= 胸靠椅：俯臥划船、反向飛鳥 =======================
if MOVE in ('chestRow', 'chestRearFly'):
    _before = set(bpy.data.objects)
    build_bench(45)
    _rot = bpy.data.objects.new('bench_rot', None); sc.collection.objects.link(_rot)
    for o_ in set(bpy.data.objects) - _before:
        if o_.parent is None and o_ is not _rot: o_.parent = _rot
    _rot.rotation_euler = (0, 0, math.pi)                # 椅子轉 180°：靠背往 -Y 升高，人面向 -Y 趴上去
    dv, nv, hg = padframe(45, flip=True)                 # nv＝人背後那一側（離開墊面）
    S0 = 0.38                                            # 髖在靠背上的位置：肩膀到墊子頂端、頭超出頭枕
    lam = D(45)
    hpt = hg + nv * 0.165 + dv * S0
    def body():
        cp, sh = trunk(hpt, lam, lam, lam - D(10))       # 頭跟脊椎一直線（略抬，眼睛看前下方）
        for s, sx in SX:
            hj = hpt + RX(lam) @ (rest[f'thigh.{s}'][0] - rest['hips'][0])
            an = Vector((0.27 * sx, hj.y + 0.34, 0.11))  # 跨坐在座墊兩側，腳往後踩（膝蓋不往前頂到啞鈴）
            k = ik2(hj, an, blen[f'thigh.{s}'], blen[f'shin.{s}'], Vector((0.3 * sx, -1.0, 0.2)))
            aim(f'thigh.{s}', hj, k - hj); aim(f'shin.{s}', k, an - k)
            aim(f'foot.{s}', an, rest[f'foot.{s}'][1] - rest[f'foot.{s}'][0])
            if s == 'L': stat('膝角', ang(hj - k, an - k))
        return sh
    down = -Z_
    if MOVE == 'chestRow':
        def pose(t):
            sh = body()
            for s, sx in SX:
                ed0 = (down + X_ * (0.06 * sx)).normalized()
                ed1 = (-dv * 0.50 + nv * 0.80 + X_ * (0.34 * sx)).normalized()   # 拉到底：手肘往後往上、貼近身體
                ed = ed0.lerp(ed1, t).normalized()
                e = sh[s] + ed * UL
                w = e + (down + X_ * (0.02 * sx)).normalized() * FL * (0.995 if t < 0.05 else 1.0)  # 前臂一直垂直地面
                if t < 0.05:                                # 起點手臂近乎打直
                    w = sh[s] + (down + X_ * (0.06 * sx)).normalized() * (UL + FL) * 0.985
                    e = elbow_ik(s, sh[s], w, -dv + nv)
                grip(s, sh[s], e, w, (w - e).normalized(), dv)   # 對握：掌心相對
                stat_arm(s, sh[s], e, w, -dv)
                if s == 'L': stat('上臂外開', math.degrees(math.asin(max(-1, min(1, (e - sh[s]).normalized().x)))))
    else:
        BEND = D(15)
        def pose(t):
            sh = body()
            for s, sx in SX:
                phi = D(6) + D(82) * t                    # 從往下垂打開到與肩同高
                a = down * math.cos(phi) + X_ * sx * math.sin(phi)
                close = down * math.sin(phi) - X_ * sx * math.cos(phi)
                e = sh[s] + a * UL
                fd = a * math.cos(BEND) + close * math.sin(BEND)
                w = e + fd * FL
                grip(s, sh[s], e, w, fd, dv)              # 掌心相對
                stat_arm(s, sh[s], e, w, -dv)
                if s == 'L': stat('手臂離垂直', math.degrees(phi))
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    report()
    CAM = dict(loc=(3.3, -1.7, 1.6), tgt=(0, -0.25, 0.8), lens=50, stage=(0, -0.1, 1.2))
