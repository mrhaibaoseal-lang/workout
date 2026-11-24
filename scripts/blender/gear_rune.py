# 符文戰神系列（傳說，奇幻戰士）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：青銅角盔（大彎角、護頰、額前符文）、無袖符文戰甲（胸甲刻發光符文、毛皮披肩、青銅圓肩甲帶尖刺、符文腰帶）、
#       符文腿甲（大腿外側鱗片、尖刺護膝、脛甲符文）、青銅戰靴（鞋尖刺、踝翼）、尖刺拳套、背負巨劍、符石啞鈴。
# 配色（GearCatalog）：c1 #2C2F3A 暗鋼、c2 #3DF5A0 符文綠、c3 #C9A86A 青銅、glow #3DF5A0。原創，不做成任何現有角色。

M['rn1'] = toon('rn1', hexc('#3A3E4C'), 0.55, spec=True)          # 暗鋼（比 c1 亮一點）
M['rnbz'] = toon('rnbz', hexc('#C9A86A'), 0.55, spec=True)         # 青銅
M['rnbzdk'] = toon('rnbzdk', hexc('#8C6B3A'), 0.55, spec=True)     # 深青銅（邊、鉚釘）
M['rnfur'] = toon('rnfur', hexc('#7A6450'), 0.6)                   # 毛皮
M['rnstone'] = toon('rnstone', hexc('#5B5F6B'), 0.55)              # 符石
M['rnleather'] = toon('rnleather', hexc('#4A3A2E'), 0.6)
M['rnglow'] = flat('rnglow', hexc('#3DF5A0'), 3.5)

def rune_mark(bone, c, d, s, kind=0, up=(0, 0, 1)):
    """一個符文字（幾條發光短線組成）：kind 0＝箭頭、1＝菱形、2＝Y 字。s＝字高"""
    d = Vector(d).normalized(); c = Vector(c); up = Vector(up)
    up = (up - d * up.dot(d)).normalized(); side = d.cross(up)
    segs = {0: [((0, -0.5), (0, 0.5)), ((0, 0.5), (-0.35, 0.15)), ((0, 0.5), (0.35, 0.15))],
            1: [((0, 0.5), (0.35, 0)), ((0.35, 0), (0, -0.5)), ((0, -0.5), (-0.35, 0)), ((-0.35, 0), (0, 0.5))],
            2: [((0, -0.5), (0, 0.05)), ((0, 0.05), (-0.35, 0.5)), ((0, 0.05), (0.35, 0.5))]}[kind % 3]
    for (a0, b0), (a1, b1) in segs:
        p0 = c + side * (a0 * s) + up * (b0 * s); p1 = c + side * (a1 * s) + up * (b1 * s)
        obox(bone, 'rnglow', (p0 + p1) / 2, (0.0045, 0.0045, (p1 - p0).length / 2 + 0.003), p1 - p0, 0)

def horn(bone, root, out, up, L, r, sx):
    """彎角：從根部往外、往上彎，越來越細"""
    out = Vector(out).normalized(); up = Vector(up).normalized(); root = Vector(root)
    pts, tp = [], []
    for i in range(13):
        t = i / 12; a = t * math.radians(110)
        p = root + out * (L * 0.62 * math.sin(a)) + up * (L * 0.5 * (1 - math.cos(a))) + Vector((0, -0.05 * t, 0))
        pts.append(tuple(p)); tp.append(max(0.08, 1 - t ** 1.3))
    return tube(bone, 'rnbz', pts, r, taper=tp)

# ---------- 青銅角盔：圓頂、額前發光符文、護頰、兩支大彎角 ----------
if want('head', 'rune'):
    HC, HR = (0, -0.005, 1.715), (0.176, 0.186, 0.197)
    cap_shell('head', 'rnbz', HC, HR, lambda x, y, z: z > 1.74 or (y > -0.06 and z > 1.60), 0.014)
    # 額前暗鋼護條＋符文
    cap_shell('head', 'rn1', HC, (HR[0] + 0.012, HR[1] + 0.012, HR[2] + 0.012), lambda x, y, z: 1.745 < z < 1.79 and y < 0.03, 0.01)
    rune_mark('head', (0, on_ellipsoid(HC, (HR[0] + 0.03, HR[1] + 0.03, HR[2] + 0.03), 0, 1.768), 1.768), (0, -1, 0.3), 0.04, 0)
    # 頭頂脊
    pts = [(0, on_ellipsoid(HC, (0.19, 0.2, 0.211), 0, z_, front=(i < 4)), z_) for i, z_ in enumerate((1.80, 1.86, 1.90, 1.915, 1.90, 1.86, 1.80))]
    tube('head', 'rnbzdk', pts, 0.012)
    for sx in (1, -1):
        # 護頰：側面一片往下到下巴旁邊，不擋眼睛
        shell('head', 'rnbz', [(0.15 * sx, -0.10, 1.74), (0.18 * sx, 0.04, 1.74), (0.17 * sx, 0.04, 1.62), (0.125 * sx, -0.09, 1.60),
                               (0.165 * sx, -0.10, 1.74), (0.195 * sx, 0.04, 1.74), (0.185 * sx, 0.04, 1.62), (0.14 * sx, -0.09, 1.60)], 0.006)
        cyl('head', 'rnbzdk', (0.19 * sx, -0.02, 1.70), 0.012, 0.01, (sx, 0, 0), 8)      # 鉚釘
        cyl('head', 'rnbzdk', (0.172 * sx, 0.0, 1.79), 0.04, 0.03, (sx, 0, 0.2), 12, 0.004)   # 角座
        horn('head', (0.185 * sx, 0.0, 1.79), (sx, 0.0, 0.15), (0, -0.25, 1), 0.24, 0.036, sx)
    face(brow_tilt=-24)

# ---------- 符文戰甲：無袖（暗鋼塗色到肩），胸甲刻符文、毛皮披肩、青銅圓肩甲＋尖刺、符文腰帶 ----------
if want('top', 'rune'):
    tk = skinbody.data.attributes['tank']
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sl = tee_parts(x, y, z)
        tk.data[i].value = min(neck, hem, 0.215 - abs(x) + max(0.0, 1.40 - z) * 0.0)       # 無袖：手臂露出來
    skinbody.data.materials[0] = toon('skin_rune', (0.50, 0.53, 0.58), alt=hexc('#2C2F3A'), alt_attr='tank', alt_shade=0.6)
    # 胸甲：左右兩塊貼著胸肌的弧形甲片（青銅包邊）＋腹部三排小甲片，不做成一整塊平板
    # （圓的胸甲試過，看起來像比基尼，改成有稜角的斜切甲片）
    for sx in (1, -1):
        IF, OF, OB, IB = (0.012, -0.135), (0.165, -0.11), (0.165, -0.065), (0.012, -0.09)
        IFt, OFt, OBt, IBt = (0.012, -0.142), (0.19, -0.105), (0.19, -0.05), (0.012, -0.085)
        lo = [(IF, 1.25), (OF, 1.28), (OB, 1.28), (IB, 1.25)]; hi = [(IFt, 1.43), (OFt, 1.45), (OBt, 1.45), (IBt, 1.43)]
        if sx < 0: lo = [lo[1], lo[0], lo[3], lo[2]]; hi = [hi[1], hi[0], hi[3], hi[2]]
        shell('chest', 'rn1', [(q[0] * sx, q[1], z) for q, z in lo] + [(q[0] * sx, q[1], z) for q, z in hi], 0.012)
        tube('chest', 'rnbz', [(0.02 * sx, -0.142, 1.255), (0.17 * sx, -0.118, 1.285)], 0.008)   # 下緣青銅邊
        rune_mark('chest', (0.095 * sx, -0.152, 1.355), (0.15 * sx, -1, 0), 0.05, 1 if sx > 0 else 0)
    for row, z in enumerate((1.19, 1.13, 1.07)):
        bone = 'chest' if z > 1.12 else 'hips'
        for sx in (1, -1):
            obox(bone, 'rn1', (0.05 * sx, -0.118 + row * 0.004, z), (0.042, 0.018, 0.024), w=0.01)
            obox(bone, 'rnbzdk', (0.05 * sx, -0.122 + row * 0.004, z - 0.022), (0.04, 0.012, 0.004), w=0.002)
    rune_mark('chest', (0, -0.14, 1.235), (0, -1, 0), 0.05, 2)
    # 毛皮披肩：肩頸一圈蓬鬆的毛
    for k in range(15):
        a = math.radians(-120 + 240 * k / 14)
        rr = 0.165 + 0.035 * abs(math.sin(a))
        ellipsoid('chest', 'rnfur', (rr * math.sin(a) * 1.08, 0.01 + 0.13 * math.cos(a), 1.485 - 0.02 * abs(math.sin(a))), (0.075, 0.07, 0.06))
    for s, sx in (('L', 1), ('R', -1)):
        # 圓肩甲：兩層青銅圓頂＋一根尖刺
        ellipsoid(f'upper_arm.{s}', 'rnbz', (0.275 * sx, 0, 1.445), (0.115, 0.12, 0.07))
        ellipsoid(f'upper_arm.{s}', 'rnbzdk', (0.30 * sx, 0, 1.40), (0.10, 0.105, 0.05))
        cyl(f'upper_arm.{s}', 'rnbzdk', (0.31 * sx, 0, 1.53), 0.03, 0.10, (0.45 * sx, 0, 1), 8, 0.0, r2=0.0)
        rune_mark(f'upper_arm.{s}', (0.31 * sx, -0.105, 1.43), (0.4 * sx, -1, 0.3), 0.035, 0)
    # 符文腰帶：青銅方扣＋發光符文
    obox('hips', 'rnleather', (0, -0.005, 0.99), (0.165, 0.112, 0.026), w=0.008)
    obox('hips', 'rnbz', (0, -0.12, 0.99), (0.045, 0.012, 0.038), w=0.008)
    rune_mark('hips', (0, -0.134, 0.99), (0, -1, 0), 0.05, 1)

# ---------- 符文腿甲：暗鋼長褲、大腿外側兩排青銅鱗片、尖刺護膝、脛甲符文 ----------
if want('bottom', 'rune'):
    for s, sx in (('L', 1), ('R', -1)):
        a, b = B[f'thigh.{s}']; d = b - a; dn = d.normalized()
        for row in range(3):                                                    # 鱗片（上面蓋下面）
            for col in (-1, 1):
                c = a + d * (0.25 + 0.17 * row) + Vector((0.095 * sx, 0.035 * col, 0))
                obox(f'thigh.{s}', 'rnbz' if row % 2 == 0 else 'rnbzdk', c, (0.012, 0.036, 0.05), (0.15 * sx, 0, -1), 0.012)
        k, an = B[f'shin.{s}']; d2 = an - k
        ellipsoid(f'shin.{s}', 'rnbz', k + Vector((0, -0.065, 0.0)), (0.062, 0.035, 0.07))      # 護膝
        cyl(f'shin.{s}', 'rnbzdk', k + Vector((0, -0.12, 0.0)), 0.024, 0.07, (0, -1, 0.2), 8, 0.0, r2=0.0)   # 膝刺
        obox(f'shin.{s}', 'rn1', k + d2 * 0.5 + Vector((0, -0.065, 0)), (0.05, 0.018, d2.length * 0.3), d2, 0.012)   # 脛甲
        rune_mark(f'shin.{s}', k + d2 * 0.5 + Vector((0, -0.086, 0)), (0, -1, 0), 0.06, 0)

# ---------- 青銅戰靴：鞋尖刺、踝翼、暗鋼綁腿 ----------
if want('feet', 'rune'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'rnbz', [(x - 0.068, -0.17, 0.02), (x + 0.068, -0.17, 0.02), (x + 0.068, 0.085, 0.02), (x - 0.068, 0.085, 0.02),
                           (x - 0.05, -0.10, 0.11), (x + 0.05, -0.10, 0.11), (x + 0.062, 0.075, 0.15), (x - 0.062, 0.075, 0.15)], 0.022)
        cyl(fb, 'rnbz', (x, -0.21, 0.045), 0.04, 0.09, (0, -1, 0.15), 8, 0.0, r2=0.0)   # 鞋尖刺
        obox(fb, 'rnbzdk', (x, -0.045, 0.012), (0.072, 0.135, 0.014), w=0.006)          # 鞋底
        cyl(fb, 'rn1', (x, 0.018, 0.18), 0.066, 0.08, n=10, w=0.006, r2=0.07)           # 綁腿
        for j in range(3):
            cyl(fb, 'rnleather', (x, 0.018, 0.15 + j * 0.03), 0.071, 0.01, n=10, w=0.002)
        # 踝翼：外側一片往後上翹的青銅鰭
        panel(fb, 'rnbz', [(x + 0.07 * sx, -0.02, 0.10), (x + 0.07 * sx, 0.06, 0.10), (x + 0.10 * sx, 0.12, 0.22), (x + 0.075 * sx, 0.02, 0.17)],
              [(0, 1, 2, 3)], 0.01, 0, 0)
        cyl(fb, 'rnglow', (x + 0.072 * sx, 0.01, 0.12), 0.012, 0.006, (sx, 0, 0), 6)

# ---------- 尖刺拳套：青銅護臂（三道箍）＋暗鋼拳套＋指節三根刺 ----------
if want('hands', 'rune'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'rnbz', e + d * 0.62, 0.058, d.length * 0.6, d, 10, 0.006, r2=0.066)
        for j in (0.4, 0.62, 0.84):
            cyl(f'forearm.{s}', 'rnbzdk', e + d * j, 0.064 + 0.006 * j, 0.012, d, 10, 0.003)
        rune_mark(f'forearm.{s}', e + d * 0.62 + Vector((0.064 * sx, 0, 0)), (sx, 0, 0), 0.045, 2, up=-d)
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'rn1', h + Vector((0, 0, -0.065)), (0.047, 0.064, 0.058))
        for yy in (-0.035, 0.0, 0.035):
            cyl(f'hand.{s}', 'rnbz', h + Vector((0.06 * sx, yy, -0.08)), 0.014, 0.045, (sx, 0, -0.15), 6, 0.0, r2=0.0)

# ---------- 背負巨劍：斜背在背上（劍柄在右肩後上方），劍身發光血槽、青銅護手、皮帶 ----------
if want('back', 'rune'):
    top = Vector((-0.16, 0.20, 1.72)); tip = Vector((0.17, 0.20, 0.80))   # 劍尖到 0.70 時深蹲會戳進大腿
    ax_ = (tip - top).normalized(); side = Vector((0, 1, 0)).cross(ax_).normalized()
    gd = top + ax_ * 0.20                                                          # 護手位置
    cyl('chest', 'rnleather', top + ax_ * 0.09, 0.022, 0.16, ax_, 10, 0.004)      # 握把
    for j in range(4):
        cyl('chest', 'rnbzdk', top + ax_ * (0.03 + 0.045 * j), 0.025, 0.008, ax_, 10)
    gem('chest', 'rnglow', top - ax_ * 0.01, -ax_, 0.03, 0.06)                    # 劍首寶石
    obox('chest', 'rnbz', gd, (0.025, 0.03, 0.13), side, 0.012)                    # 護手
    for k in (1, -1):
        cyl('chest', 'rnbz', gd + side * (0.13 * k), 0.026, 0.05, side * k + ax_ * 0.6, 6, 0.0, r2=0.0)
    L = (tip - gd).length - 0.02
    b0 = gd + ax_ * 0.02
    w0, w1 = 0.07, 0.055
    vs = [tuple(b0 + side * w0), tuple(b0 - side * w0), tuple(b0 + ax_ * (L - 0.12) - side * w1), tuple(b0 + ax_ * L), tuple(b0 + ax_ * (L - 0.12) + side * w1)]
    blade = panel('chest', 'rn1', vs, [(0, 1, 2, 4), (4, 2, 3)], 0.022, 0.006, 0)
    obox('chest', 'rnglow', b0 + ax_ * (L * 0.42) + Vector((0, 0.013, 0)), (0.008, 0.003, L * 0.36), ax_, 0)   # 血槽發光
    for j in range(3):
        rune_mark('chest', b0 + ax_ * (0.12 + 0.2 * j) + Vector((0, 0.016, 0)) + side * 0.035, (0, 1, 0), 0.03, j, up=-ax_)
    # 斜背皮帶（胸前一段＋背後一段）＋青銅扣
    for yf in (-0.13, 0.13):
        a, b = Vector((-0.16, yf, 1.47)), Vector((0.15, yf, 1.13))   # 到 1.05 時深蹲會切進左大腿
        obox('chest', 'rnleather', (a + b) / 2, (0.02, 0.007, (b - a).length / 2), b - a, 0.003)
    cyl('chest', 'rnbz', (-0.03, -0.138, 1.30), 0.028, 0.012, (0, -1, 0), 12, 0.003)

# ---------- 符石啞鈴：兩頭是粗糙的石塊、刻發光符文、青銅箍 ----------
if want('bell', 'rune'):
    import random as _rnd
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'rnleather', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.122 * sy, 0))
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=c)
            ob = bpy.context.object; rg = _rnd.Random(7 + sy + (3 if s == 'L' else 0))
            for v in ob.data.vertices:
                k = 0.85 + 0.25 * rg.random(); v.co = Vector((v.co.x * 0.08 * k, v.co.y * 0.06 * k, v.co.z * 0.08 * k))
            hard(ob, f'hand.{s}', 'rnstone', 0.01, 1)
            cyl(f'hand.{s}', 'rnbz', c + Vector((0, -0.028 * sy, 0)), 0.068, 0.018, (0, 1, 0), 10, 0.004)   # 青銅箍
            rune_mark(f'hand.{s}', c + Vector((0, 0.062 * sy, 0)), (0, sy, 0), 0.06, (1 if sy > 0 else 2))
