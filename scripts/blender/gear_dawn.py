# 曙光系列（傳說，披風英雄）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：旭日頭環（扇形光芒＋藍寶石）、白藍長袖戰衣（金色高領、星形胸章、金肩飾、太陽扣腰帶）、
#       藍長褲＋金側線、及膝長靴（前緣 V 口金邊）、金色長護手（手背星）、金邊藍長披風、旭日啞鈴。
# 配色（GearCatalog）：c1 #EEF3FA 白、c2 #E0A21B 金、c3 #2E6BFF 藍、glow #FFD45C。原創，不做成任何現有英雄。

M['dw1'] = toon('dw1', hexc('#EEF3FA'), 0.7)
M['dwgold'] = toon('dwgold', hexc('#E8AE2A'), 0.55, spec=True)
M['dw3'] = toon('dw3', hexc('#2E6BFF'), 0.6)
M['dwgem'] = toon('dwgem', hexc('#2E6BFF'), 0.5, spec=True)
M['dwglow'] = flat('dwglow', hexc('#FFD45C'), 3.5)

def sunburst(bone, c, d, r, n, L, mat='dwgold', ray_r=None, up=(0, 0, 1), arc=None):
    """太陽：圓盤＋一圈三角光芒（arc＝只畫上半圈之類的角度範圍，弧度）"""
    d = Vector(d).normalized(); c = Vector(c); up = Vector(up)
    up = (up - d * up.dot(d)).normalized(); side = d.cross(up)
    a0, a1 = arc if arc else (0, 2 * math.pi)
    for k in range(n):
        a = a0 + (a1 - a0) * k / max(1, n - 1) if arc else 2 * math.pi * k / n
        u = up * math.cos(a) + side * math.sin(a)
        LL = L * (1.0 if k % 2 == 0 else 0.62)                 # 長短交錯
        cyl(bone, mat, c + u * (r + LL * 0.45), ray_r or r * 0.32, LL, u, 4, 0.0, r2=0.0)

# ---------- 旭日頭環：金環＋額前扇形光芒＋藍寶石，露出頭髮 ----------
if want('head', 'dawn'):
    hair()
    face()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.165, minor_radius=0.016, location=(0, -0.008, 1.775), rotation=(math.radians(-10), 0, 0))
    ob = bpy.context.object; ob.scale = (1.0, 1.07, 1.0); bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    finish(ob, 'head', 'dwgold', 0)
    C0 = Vector((0, -0.178, 1.80))
    cyl('head', 'dwgold', C0, 0.045, 0.02, (0, -1, 0.25), 24, 0.004)                     # 額前圓盤
    sunburst('head', C0 + Vector((0, 0.01, 0.0)), (0, -1, 0.25), 0.04, 9, 0.11, ray_r=0.016, arc=(-1.25, 1.25))   # 扇形光芒（只往上）
    gem('head', 'dwgem', C0 + Vector((0, -0.016, 0)), (0, -1, 0.25), 0.024, 0.045)        # 藍寶石
    for sx in (1, -1):                                                                    # 兩側小翼
        cyl('head', 'dwgold', (0.158 * sx, 0.02, 1.80), 0.016, 0.09, (0.3 * sx, 0.6, 0.75), 4, 0.0, r2=0.0)
        cyl('head', 'dwgold', (0.162 * sx, 0.04, 1.775), 0.014, 0.07, (0.3 * sx, 0.8, 0.45), 4, 0.0, r2=0.0)

# ---------- 曙光戰衣：塗在身體上（白色長袖、藍色側片和袖子外側），金高領、星章、金肩飾、太陽扣腰帶 ----------
if want('top', 'dawn'):
    tk = skinbody.data.attributes['tank']
    bl = skinbody.data.attributes.new('dwblue', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sl = sleeve_paint(x, y, z, 0.53)
        suit = min(neck, hem, sl); tk.data[i].value = suit
        ax = abs(x)
        side = min(ax - (0.13 + 0.05 * max(0.0, (z - 1.20) / 0.25)), 0.25 - ax + 0.0)   # 軀幹側片（往上收窄成 V）
        arm = min(ax - 0.235, 0.6)                                                       # 整條袖子
        bl.data[i].value = min(suit, max(side, arm))
    mt = toon('skin_dawn', (0.50, 0.53, 0.58), alt=hexc('#EEF3FA'), alt_attr='tank', alt_shade=0.7)
    skinbody.data.materials[0] = add_layer(mt, 'dwblue', hexc('#2E6BFF'), 0.6)
    cyl('chest', 'dwgold', (0, 0.0, 1.50), 0.098, 0.07, (0, 0, 1), 24, 0.006, r2=0.112)   # 金色高領（上緣外擴）
    star('chest', 'dwgold', (0, -0.132, 1.33), (0, -1, 0), 0.068, 0.03, 0.018)           # 星章
    star('chest', 'dwglow', (0, -0.142, 1.33), (0, -1, 0), 0.04, 0.018, 0.008)
    for s, sx in (('L', 1), ('R', -1)):                                                   # 金肩飾：圓弧肩片＋三條垂穗
        ellipsoid(f'upper_arm.{s}', 'dwgold', (0.265 * sx, 0, 1.455), (0.105, 0.11, 0.045), (0, math.radians(-22 * sx), 0))
        for k in (-1, 0, 1):
            cyl(f'upper_arm.{s}', 'dwgold', (0.33 * sx, 0.045 * k, 1.385), 0.009, 0.06, (0.4 * sx, 0, -1), 8, 0.0)
    obox('hips', 'dwgold', (0, -0.005, 0.99), (0.165, 0.112, 0.022), w=0.01)              # 金腰帶
    cyl('hips', 'dwgold', (0, -0.12, 0.99), 0.034, 0.018, (0, -1, 0), 24, 0.004)
    sunburst('hips', (0, -0.124, 0.99), (0, -1, 0), 0.03, 8, 0.03, ray_r=0.009)
    cyl('hips', 'dwglow', (0, -0.132, 0.99), 0.018, 0.006, (0, -1, 0), 16)

# ---------- 曙光長褲：藍色長褲＋金色側線 ----------
if want('bottom', 'dawn'):
    wt = shorts.data.attributes.new('dwtrunk', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        sx = 1 if x > 0 else -1
        ang = abs(math.atan2(y, (x - 0.12 * sx) * sx))                      # 0＝腿的正外側
        leg = 0.84 + 0.05 * (1 - min(1.0, ang / 1.6))                       # 褲口外側高、內側低（斜切）
        trunk = z - leg
        stripe = min(0.11 - ang, 0.97 - z) * 0.08                          # 外側金線（腰以下）
        wt.data[i].value = -0.25 if stripe > 0 else -0.5   # 外穿短褲試過，和白色上衣糊成一團，拿掉
    mp = toon('pants_dawn2', hexc('#2E6BFF'), 0.6, alt=hexc('#EEF3FA'), alt_attr='dwtrunk', alt_shade=0.7)
    # 金線：第二層塗色（屬性 dwstripe）
    st = shorts.data.attributes.new('dwstripe', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        st.data[i].value = 1.0 if wt.data[i].value == -0.25 else -1.0
    shorts.data.materials[0] = add_layer(mp, 'dwstripe', hexc('#E8AE2A'), 0.55)
    for s, sx in (('L', 1), ('R', -1)):                                    # 褲口金邊
        a, b = B[f'thigh.{s}']; d = b - a
        cyl(f'thigh.{s}', 'dwgold', a + d * 0.32, 0.108, 0.016, d, 24, 0.004)

# ---------- 及膝長靴：藍色，前緣 V 口＋金邊，金鞋底 ----------
if want('feet', 'dawn'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'dw3', [(x - 0.066, -0.20, 0.03), (x + 0.066, -0.20, 0.03), (x + 0.066, 0.085, 0.03), (x - 0.066, 0.085, 0.03),
                          (x - 0.05, -0.12, 0.11), (x + 0.05, -0.12, 0.11), (x + 0.062, 0.07, 0.16), (x - 0.062, 0.07, 0.16)], 0.03)
        obox(fb, 'dwgold', (x, -0.06, 0.016), (0.07, 0.15, 0.016), w=0.008)
        k, an = B[f'shin.{s}']; d2 = an - k
        # 靴筒：綁小腿，從腳踝到膝下
        cyl(f'shin.{s}', 'dw3', an - d2 * 0.42, 0.068, d2.length * 0.82, d2, 20, 0.006, r2=0.06)
        top = an - d2 * 0.83
        # 前緣 V 口：前面一片尖角翻起
        cyl(f'shin.{s}', 'dwgold', top, 0.072, 0.018, d2, 20, 0.004)
        panel(f'shin.{s}', 'dw3', [tuple(top + Vector((-0.05, -0.064, -0.01))), tuple(top + Vector((0.05, -0.064, -0.01))), tuple(top + Vector((0, -0.075, 0.07)))], [(0, 1, 2)], 0.012, 0, 1)
        tube(f'shin.{s}', 'dwgold', [tuple(top + Vector((-0.05, -0.078, -0.008))), tuple(top + Vector((0, -0.088, 0.072))), tuple(top + Vector((0.05, -0.078, -0.008)))], 0.007)

# ---------- 金色長護手：喇叭形金護腕＋白手套＋手背星 ----------
if want('hands', 'dawn'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'dwgold', e + d * 0.6, 0.054, d.length * 0.62, d, 20, 0.006, r2=0.08)   # 往手肘張開
        cyl(f'forearm.{s}', 'dw3', e + d * 0.31, 0.083, 0.014, d, 20, 0.003)                        # 張口藍邊
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'dw1', h + Vector((0, 0, -0.065)), (0.045, 0.063, 0.057))
        star(f'hand.{s}', 'dwgold', h + Vector((0.05 * sx, 0, -0.06)), (sx, 0, 0), 0.03, 0.013, 0.01)

# ---------- 金邊藍長披風（到小腿、往後張開）＋太陽扣 ----------
if want('back', 'dawn'):
    ROWS = [(1.50, 0.13, 0.115, 0.0), (1.44, 0.215, 0.15, 0.0), (1.34, 0.24, 0.17, 0.0), (1.18, 0.245, 0.19, 0.0),
            (1.0, 0.255, 0.23, 0.0), (0.80, 0.27, 0.29, 0.0), (0.60, 0.29, 0.35, 0.0)]
    def _wave(u):                                         # 下緣微微起伏（布料）
        return 0.10 + 0.025 * math.sin(u * math.pi * 5), 0.04
    back_drape('chest', 'dw3', ROWS, math.radians(52), 33, _wave, 0.012, 1)
    back_drape('chest', 'dw1', ROWS, math.radians(52), 33, _wave, 0.004, -1)            # 白色內裡（薄）
    pts = []
    z, rx, ry, yc = ROWS[-1]
    for c in range(65):                                   # 下緣金邊
        u = c / 64; p_ = math.radians(-52 + 104 * u); dz, fl = _wave(u)
        pts.append(((rx + fl + 0.006) * math.sin(p_), yc + (ry + fl + 0.006) * math.cos(p_), z - dz))
    tube('chest', 'dwgold', pts, 0.012)
    for sx in (1, -1):                                    # 兩側直邊金邊
        side = []
        for (z, rx, ry, yc) in ROWS + [(ROWS[-1][0] - _wave(0 if sx < 0 else 1)[0], ROWS[-1][1] + 0.04, ROWS[-1][2] + 0.04, 0)]:
            p_ = math.radians(52) * sx
            side.append(((rx + 0.006) * math.sin(p_), yc + (ry + 0.006) * math.cos(p_), z))
        tube('chest', 'dwgold', side, 0.01)
    for sx in (1, -1):                                    # 太陽扣
        cyl('chest', 'dwgold', (0.14 * sx, -0.07, 1.465), 0.036, 0.016, (0.2 * sx, -0.5, 1), 20, 0.004)
        sunburst('chest', (0.14 * sx, -0.07, 1.465), (0.2 * sx, -0.5, 1), 0.032, 8, 0.028, ray_r=0.009, up=(0, -1, 0))
        cyl('chest', 'dwglow', (0.14 * sx, -0.076, 1.476), 0.018, 0.008, (0.2 * sx, -0.5, 1), 16)

# ---------- 旭日啞鈴：兩頭是帶光芒的金色太陽盤，中心發光 ----------
if want('bell', 'dawn'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'dw1', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.118 * sy, 0))
            cyl(f'hand.{s}', 'dwgold', c, 0.062, 0.05, (0, 1, 0), 24, 0.01)
            sunburst(f'hand.{s}', c, (0, sy, 0), 0.058, 12, 0.045, ray_r=0.017)
            cyl(f'hand.{s}', 'dwglow', c + Vector((0, 0.027 * sy, 0)), 0.036, 0.008, (0, 1, 0), 20)
            cyl(f'hand.{s}', 'dw3', c + Vector((0, -0.03 * sy, 0)), 0.045, 0.012, (0, 1, 0), 20, 0.003)
