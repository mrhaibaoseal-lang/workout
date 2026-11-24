# 器材：滑輪 A 批要用的塔柱（只有立柱和配重，沒有椅子）、三頭繩、跪墊。負責：Claude（動作）。
# 站、跪在高位滑輪前面的動作（三頭下壓、過頭伸展、面拉、跪姿捲腹）用這裡的 build_tower()：
# 使用者的機器是椅子和立柱一體的，站在立柱前面時椅子會擋到腿，所以這些動作假設把椅子移開／轉到一邊（見 docs/3d-moves/cable.md「器材假設」）。
# 立柱、滑輪、配重的尺寸和 props_bench.py 的 build_bench 一樣（POST_Y、POST_TOP 共用）。

PM['rope'] = toon('rope', hexc('#4B5563'), 0.7)

# 鋼索從滑輪出來的位置：+Y 側（面向立柱的動作）、-Y 側（背對立柱的動作）
WHEEL_FRONT = Vector((0, POST_Y + 0.15, POST_TOP - 0.03))
WHEEL_BACK = Vector((0, POST_Y - 0.075, POST_TOP - 0.03))

def build_tower():
    """立柱＋頂部滑輪盒＋配重，不含椅子。回傳配重組（動畫移動它）。"""
    pbox('frame', (0, POST_Y, 0.03), (0.22, 0.05, 0.03), 0.008)
    for x_ in (-0.19, 0.19): pbox('rubber', (x_, POST_Y, 0.008), (0.03, 0.05, 0.008), 0.003)
    tube((0, POST_Y, 0.06), (0, POST_Y + 0.40, 0.03), 0.028)      # 往後一支底樑，免得立柱站不穩
    pbox('frame', (0, POST_Y, POST_TOP / 2), (0.032, 0.032, POST_TOP / 2), 0.006)
    pbox('frame', (0, POST_Y + 0.02, POST_TOP - 0.03), (0.05, 0.085, 0.07), 0.02)
    for sx in (1, -1): pcyl('frame', (0.05 * sx, POST_Y + 0.02, POST_TOP - 0.03), 0.07, 0.01, (1, 0, 0), n=32)
    pcyl('chrome', (0, POST_Y + 0.02, POST_TOP - 0.03), 0.02, 0.11, (1, 0, 0), n=12)
    stack = bpy.data.objects.new('stack', None); sc.collection.objects.link(stack)
    own = [pbox('frame', (0, POST_Y, 0.82), (0.05, 0.05, 0.27), 0.01),
           pcyl('chrome', (0, POST_Y + 0.055, 1.10), 0.012, 0.035, (0, 1, 0), n=12)]
    for z_ in (0.98, 0.66):
        own.append(pcyl('chrome', (0, POST_Y, z_), 0.016, 0.36, (1, 0, 0), n=12))
        for sx in (1, -1):
            for i_, x_ in enumerate((0.075, 0.105)):
                own.append(pcyl('plate', (x_ * sx, POST_Y, z_), 0.115 - i_ * 0.012, 0.028, (1, 0, 0), n=32, bevel=0.006))
            own.append(pcyl('red', (0.15 * sx, POST_Y, z_), 0.032, 0.04, (1, 0, 0), n=6, bevel=0.004))
    for o_ in own: o_.parent = stack
    return stack

def build_mat(y, w=0.26, l=0.55):
    """跪墊（跪姿捲腹）：地上一塊厚墊，中心 y"""
    return pbox('pad', (0, y, 0.02), (w, l / 2, 0.02), 0.012)

# ---------- 三頭繩 ----------
# 中間一個扣環（接鋼索），兩條粗繩，握把段包膠，末端一顆橡膠球擋。每隻手一段「繩子（扣環→拳頭）＋握把段＋球擋」。
# 握把段順著手的「握把軸」（hand 骨頭的 z 軸，和啞鈴握把同一個方向）穿過拳頭。
def build_rope():
    clip = bpy.data.objects.new('ropeclip', None); sc.collection.objects.link(clip)
    for o_ in (pcyl('chrome', (0, 0, 0), 0.016, 0.07, (1, 0, 0), n=12), pbox('chrome', (0, 0, 0.035), (0.012, 0.012, 0.03), 0.004)):
        o_.parent = clip
    strands = [stretch('rope', 0.013) for _ in (0, 1)]
    grips = [stretch('rubber', 0.021) for _ in (0, 1)]
    balls = []
    for _ in (0, 1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.034)
        balls.append(prop(bpy.context.object, 'rubber', True, 0.0))
    root = bpy.data.objects.new('bar', None); sc.collection.objects.link(root)   # 叫 bar：clipcheck 不算手和握把的穿透（手本來就握著）
    for o_ in [clip] + strands + grips + balls: o_.parent = root
    return dict(clip=clip, strands=strands, grips=grips, balls=balls, root=root)

def hand_grip_frame(s):
    """手在目前姿勢的握拳中心 G、握把軸 hz（朝下／朝後那一端）。要在 keyall 之後呼叫（鎖骨會改變手臂）"""
    M = pb[f'hand.{s}'].matrix
    return M.translation + M.col[1].xyz.normalized() * 0.05, M.col[2].xyz.normalized()

def key_rope(rp, f, cable_pt, clip_len=0.30, ball_out=0.10, grip_len=0.12, hand_axis=True):
    """把繩子擺到手上並打影格。cable_pt＝鋼索從滑輪出來的位置（扣環會放在握把往滑輪的方向 clip_len 處）。回傳扣環位置。"""
    G = {}; HZ = {}
    for s, _ in SX: G[s], HZ[s] = hand_grip_frame(s)
    mid = (G['L'] + G['R']) / 2
    dx = abs(G['L'].x - G['R'].x) / 2
    h = math.sqrt(max(clip_len ** 2 - dx ** 2, 0.04 ** 2))
    cp_ = mid + (Vector(cable_pt) - mid).normalized() * h
    rp['clip'].location = cp_; rp['clip'].keyframe_insert('location', frame=f)
    for i, (s, _) in enumerate(SX):
        hz = HZ[s]
        if hz.dot(G[s] - cp_) < 0: hz = -hz            # 握把軸朝「離開扣環」那一端，球擋在拳頭外面
        top, bot = G[s] - hz * grip_len / 2, G[s] + hz * grip_len / 2
        key_stretch(rp['strands'][i], cp_, top, f)
        key_stretch(rp['grips'][i], top, bot, f)
        rp['balls'][i].location = bot + hz * 0.025; rp['balls'][i].keyframe_insert('location', frame=f)
    return cp_

# ---------- 鋼索和配重跟著動 ----------
# 鋼索：滑輪出口 → 扣環；配重沿立柱升起的高度 ＝ 鋼索被拉出的長度（跟 L0 比）；配重的鋼索從滑輪另一側掛到配重頂端。
def make_cables():
    return dict(a=stretch('cable', 0.006), w=stretch('cable', 0.006), L0=None)

def key_cables(cb, stack, f, cable_pt, clip_pos):
    cable_pt = Vector(cable_pt)
    L = (cable_pt - clip_pos).length
    if cb['L0'] is None: cb['L0'] = L
    rise = max(0.0, L - cb['L0'])
    stack.location = (0, 0, rise); stack.keyframe_insert('location', frame=f)
    key_stretch(cb['a'], cable_pt, clip_pos, f)
    key_stretch(cb['w'], Vector((0, POST_Y + 0.055, POST_TOP - 0.10)), Vector((0, POST_Y + 0.055, 1.10 + rise)), f)
    return rise

# ---------- 下拉槓（直槓，兩端下彎，握把包膠）：同 pulldown 用的那支，握距可調 ----------
def build_latbar(gx):
    bar = bpy.data.objects.new('bar', None); sc.collection.objects.link(bar)
    parts = [pcyl('chrome', (0, 0, 0), 0.014, 0.86, (1, 0, 0), n=12)]
    for sx in (1, -1):
        parts.append(pcyl('chrome', (0.52 * sx, 0, -0.035), 0.014, 0.2, (sx, 0, -0.45), n=12))
        parts.append(pcyl('rubber', (gx * sx, 0, 0), 0.019, 0.14, (1, 0, 0), n=12))
    parts.append(pcyl('chrome', (0, 0, 0.03), 0.02, 0.06, n=12))
    for o_ in parts: o_.parent = bar
    return bar
