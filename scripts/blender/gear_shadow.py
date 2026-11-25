# 暗影系列（傳說）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：暗影忍者——包頭面罩（只露眼睛、額前紫色新月、腦後打結飄帶）、長袖戰衣＋前臂綁帶＋飄尾圍巾、綁腿長褲＋大腿短刀、
#       分趾忍者鞋、利爪手甲、破布下緣披風、虛空球啞鈴。不做成任何現有的忍者角色。
# 配色（GearCatalog）：c1 #1A1424 暗紫黑、c2 #9B5CFF 紫、c3 #E2D4FF 淡紫、glow #9B5CFF。

M['sd1'] = toon('sd1', hexc('#2C2340'), 0.6)                     # 比 c1 亮一點，兩階明暗才看得出來
M['sdk'] = toon('sdk', hexc('#16101F'), 0.6)
M['sd2'] = toon('sd2', hexc('#9B5CFF'), 0.62)
M['sd3'] = toon('sd3', hexc('#E2D4FF'), 0.66, spec=True)
M['sdglow'] = flat('sdglow', hexc('#9B5CFF'), 3.0)

def strip(bone, mat, pts, w, side, th=0.006, twist=0.0):
    """飄帶：沿 pts 的一條寬 w 的帶子，side＝寬度方向（可沿路扭轉 twist 弧度）"""
    side = Vector(side).normalized(); vs = []
    for i, p in enumerate(pts):
        t = i / (len(pts) - 1); p = Vector(p)
        sd = Matrix.Rotation(twist * t, 3, 'Z') @ side * (w * (1 - 0.35 * t) / 2)
        vs += [tuple(p + sd), tuple(p - sd)]
    return panel(bone, mat, vs, [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(len(pts) - 1)], th, 0, 0)

# ---------- 暗影面罩：包住整顆頭、只露一條眼縫；額前淡紫新月、腦後結＋兩條紫飄帶 ----------
if want('head', 'shadow'):
    HC, HR = (0, -0.01, 1.70), (0.163, 0.173, 0.193)
    cap_shell('head', 'sd1', HC, HR, lambda x, y, z: z > 1.552 and (z > 1.742 or z < 1.668 or y > -0.02), 0.012, 36, 26)
    cap_shell('head', 'sd2', HC, (HR[0] + 0.013, HR[1] + 0.013, HR[2] + 0.013),                       # 頭巾紫帶（眼縫上方）
              lambda x, y, z: 1.748 < z < 1.775, 0.006, 36, 26)
    face_lite(brow_tilt=-28, eye_tilt=-20)
    for sx in (1, -1):                                                                              # 眼睛紫光
        blob('head', 'sdglow', (0.058 * sx, -0.172, 1.706), (0.02, 0.004, 0.011), (0, math.radians(-12 * sx), math.radians(-20 * sx)), 8, 6, 0)
    # 額前新月：兩段弧疊出月牙
    ring_arc('head', 'sd3', (0, -0.205, 1.80), 0.03, math.radians(200), math.radians(340), 0.007, (1, 0, 0), (0, 0, 1), 8)
    blob('head', 'sd3', (0, -0.198, 1.772), (0.012, 0.006, 0.012), seg=8, ring=6, subd=0)
    # 腦後結＋兩條飄帶（往後下方飄、左右分開）
    blob('head', 'sd2', (0, 0.18, 1.765), (0.04, 0.03, 0.032), seg=10, ring=8)
    for sx in (1, -1):
        pts = [(0.02 * sx + 0.09 * sx * t, 0.19 + 0.17 * t, 1.765 - 0.26 * t + 0.04 * math.sin(math.pi * t * 1.5)) for t in (k / 6 for k in range(7))]
        strip('head', 'sd2', pts, 0.045, (1, 0, 0.25 * sx), 0.006, 0.6 * sx)

# ---------- 暗影戰衣：塗在身體上（長袖到手腕、暗紫黑），胸前紫色 V 線、前臂淡紫綁帶紋；脖子一圈厚圍巾＋兩條飄尾、胸口紫晶 ----------
if want('top', 'shadow'):
    tk = skinbody.data.attributes['tank']
    ln = skinbody.data.attributes.new('sdline', 'FLOAT', 'POINT')
    wr = skinbody.data.attributes.new('sdwrapt', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co; ax = abs(x)
        neck, hem, sl = sleeve_paint(x, y, z, 0.55)
        tee = min(neck, hem, sl)
        tk.data[i].value = tee
        V = [(0.19, 1.42), (0.0, 1.17)] if y < 0 else [(0.19, 1.42), (0.0, 1.25), (0.0, 0.99)]
        ln.data[i].value = min(seg_field(ax, z, V, 0.009), tee) if ax < 0.215 else -1
        wr.data[i].value = min((tri(z * 22 + (x if y < 0 else -x) * 4) - 0.62) * 0.03, tee) if ax > 0.25 and z < 1.13 else -1
    mt = toon('skin_shadow', (0.50, 0.53, 0.58), alt=hexc('#2C2340'), alt_attr='tank', alt_shade=0.6)
    add_layer(mt, 'sdline', hexc('#9B5CFF'), 0.7)
    skinbody.data.materials[0] = add_layer(mt, 'sdwrapt', hexc('#E2D4FF'), 0.66)
    # 圍巾：脖子一圈厚圍巾（略往前垂）＋背後兩條飄尾
    tube('chest', 'sd2', [(0.112 * math.cos(t), -0.004 + 0.104 * math.sin(t), 1.478 + 0.018 * math.sin(t)) for t in (2 * math.pi * k / 20 for k in range(20))],
         0.03, closed=True)
    for sx, ln_ in ((1, 1.0), (-1, 0.78)):
        pts = [(0.03 * sx + 0.13 * sx * t, 0.12 + 0.24 * t, 1.47 - 0.30 * t * ln_ + 0.05 * math.sin(math.pi * t * 2)) for t in (k / 7 for k in range(8))]
        strip('chest', 'sd2', pts, 0.07, (1, 0, 0), 0.007, 0.5 * sx)
    cz = 1.32
    gem('chest', 'sdglow', (0, torso_y(0, cz) - 0.008, cz), (0, -0.25, 1), 0.016, 0.06)                 # 胸口紫晶
    cyl('chest', 'sdk', (0, torso_y(0, cz) - 0.002, cz), 0.03, 0.01, (0, -1, 0), 4, 0.002)

# ---------- 暗影長褲：暗紫黑，小腿交叉紫色綁腿紋；右大腿綁一把短刀（淡紫刀柄） ----------
if want('bottom', 'shadow'):
    wp = shorts.data.attributes.new('sdwrap', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        if not 0.14 < z < 0.47: wp.data[i].value = -1; continue
        sx = 1 if x > 0 else -1
        a = math.atan2(y, (x - 0.12 * sx) * sx)
        wp.data[i].value = (max(tri(z * 9 + a / math.pi), tri(z * 9 - a / math.pi)) - 0.8) * 0.03     # 交叉綁帶
    shorts.data.materials[0] = toon('pants_shadow2', hexc('#2C2340'), 0.6, alt=hexc('#9B5CFF'), alt_attr='sdwrap', alt_shade=0.65)
    for s, sx in (('L', 1), ('R', -1)):
        k, an = B[f'shin.{s}']; d2 = an - k
        cyl(f'shin.{s}', 'sdk', an + Vector((0, 0, 0.05)), 0.056, 0.04, d2, 16, 0.006)                 # 褲管束口
    a, b = B['thigh.R']; d = b - a
    c = a + d * 0.5 + Vector((-0.07, -0.075, 0))                                                          # 右大腿前外側的短刀
    cyl('thigh.R', 'sdk', a + d * 0.42, 0.114, 0.022, d, 20, 0.004)                                       # 大腿綁帶
    obox('thigh.R', 'sdk', c, (0.016, 0.01, 0.07), d, 0.005, roll=0.5)                                    # 刀鞘
    cyl('thigh.R', 'sd3', c - d.normalized() * 0.1, 0.009, 0.06, -d, 8)                                   # 刀柄
    cyl('thigh.R', 'sd2', c - d.normalized() * 0.07, 0.016, 0.008, -d, 8)                                 # 護手
    blob('thigh.R', 'sd3', c - d.normalized() * 0.135, (0.012, 0.012, 0.012), seg=8, ring=6, subd=0)

# ---------- 無聲靴：分趾忍者鞋（大拇趾另一顆）、薄底、腳踝到小腿的紫色交叉綁帶 ----------
if want('feet', 'shadow'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'sd1', [(x - 0.06, -0.14, 0.025), (x + 0.06, -0.14, 0.025), (x + 0.06, 0.08, 0.025), (x - 0.06, 0.08, 0.025),
                          (x - 0.05, -0.09, 0.1), (x + 0.05, -0.09, 0.1), (x + 0.058, 0.065, 0.14), (x - 0.058, 0.065, 0.14)], 0.026)
        blob(fb, 'sd1', (x - 0.03 * sx, -0.165, 0.045), (0.022, 0.04, 0.03), seg=14, ring=10, subd=0)             # 大拇趾（內側）
        blob(fb, 'sd1', (x + 0.018 * sx, -0.158, 0.043), (0.038, 0.042, 0.03), seg=16, ring=10, subd=0)           # 其他腳趾
        cyl(fb, 'sd1', (x, 0.012, 0.2), 0.06, 0.13, n=16, w=0.006, r2=0.066)                             # 筒（到小腿）
        obox(fb, 'sdk', (x, -0.05, 0.012), (0.064, 0.15, 0.012), w=0.006)                                # 薄底
        for j, zz in enumerate((0.11, 0.155, 0.2, 0.245)):                                              # 交叉綁帶
            for k_ in (1, -1):
                cyl(fb, 'sd2', (x, 0.012, zz), 0.0665 + 0.002 * j, 0.01, (0.28 * k_, 0, 1), 12)

# ---------- 暗影手甲：深色護甲手套、指節三根淡紫利爪（短、往下彎）、手背紫光紋、前臂淡紫綁帶 ----------
if want('hands', 'shadow'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'sd1', w_ - d * 0.18, 0.054, d.length * 0.34, d, 16, 0.006, r2=0.062)
        for j in range(3):
            cyl(f'forearm.{s}', 'sd3', w_ - d * (0.08 + 0.09 * j), 0.0605 + 0.002 * j, 0.01, d + Vector((0.12 * sx, 0, 0)) * (1 if j % 2 else -1), 16)
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'sdk', h + Vector((0, 0, -0.065)), (0.046, 0.064, 0.058))
        obox(f'hand.{s}', 'sdglow', h + Vector((0.047 * sx, 0, -0.05)), (0.003, 0.035, 0.004), (0, 0.5, 1), 0)
        for j, yy in enumerate((-0.035, 0.0, 0.035)):                                                     # 利爪：從指節往外下方彎
            base = h + Vector((0.046 * sx, yy, -0.1))
            flame(f'hand.{s}', 'sd3', base, (0.6 * sx, 0, -1), 0.011, 0.065 + 0.012 * (j == 1), (-0.02 * sx, 0, 0))

# ---------- 暗影披風：外暗內紫、下緣長短不一的破布條；肩上兩顆紫晶扣 ----------
if want('back', 'shadow'):
    ROWS = [(1.50, 0.12, 0.115, 0.0), (1.45, 0.205, 0.15, 0.0), (1.36, 0.24, 0.17, 0.0),
            (1.22, 0.255, 0.195, 0.0), (1.08, 0.27, 0.225, 0.0), (0.98, 0.28, 0.24, 0.0)]
    PH = 52
    RAG = [0.08, 0.26, 0.12, 0.31, 0.05, 0.2, 0.34, 0.1, 0.24, 0.07, 0.29, 0.15, 0.33, 0.06, 0.22, 0.11, 0.3, 0.09, 0.25]
    def _rag(u):                                       # 破布條：每段固定長短、條與條之間有缺口
        f = u * (len(RAG) - 1); k = int(round(f)); e = abs(f - k)
        return (RAG[k] * (1 - 0.8 * e ** 2) + 0.02), 0.015 + 0.02 * RAG[k]
    back_drape('chest', 'sd1', ROWS, math.radians(PH), 37, _rag, 0.01, 1)
    back_drape('chest', 'sd2', ROWS, math.radians(PH), 37, _rag, 0.006, -1)
    _z, _rx, _ry, _yc = ROWS[-1]                         # 下緣紫邊（同色的戰衣前面，背面才認得出披風）
    _pts = []
    for c in range(73):
        u = c / 72; p_ = math.radians(-PH + 2 * PH * u); dz, fl = _rag(u)
        _pts.append(((_rx + fl + 0.004) * math.sin(p_), _yc + (_ry + fl + 0.004) * math.cos(p_), _z - dz))
    tube('chest', 'sd2', _pts, 0.006)
    for sx in (1, -1):
        cyl('chest', 'sdk', (0.13 * sx, -0.06, 1.47), 0.028, 0.014, (0.2 * sx, -0.4, 1), 12, 0.003)
        gem('chest', 'sdglow', (0.132 * sx, -0.068, 1.477), (0.2 * sx, -0.4, 1), 0.012, 0.03)

# ---------- 虛空啞鈴：兩頭黑色球、中間一圈紫光環、外側淡紫核心，斜繞一圈細紫軌道 ----------
if want('bell', 'shadow'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'sdk', hc, 0.017, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.115 * sy, 0))
            blob(f'hand.{s}', 'sdk', c, (0.072, 0.066, 0.072), seg=20, ring=12, subd=0)
            ring_arc(f'hand.{s}', 'sdglow', c, 0.074, 0, 2 * math.pi, 0.007, (1, 0, 0), (0, 0, 1), 16, 1)
            blob(f'hand.{s}', 'sd3', c + Vector((0, 0.064 * sy, 0)), (0.022, 0.008, 0.022), seg=10, ring=6, subd=0)
            ring_arc(f'hand.{s}', 'sd2', c, 0.095, 0, 2 * math.pi, 0.004, (1, 0.5 * sy, 0.35), (0, -0.35, 1), 18, 1)
