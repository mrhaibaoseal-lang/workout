# 黃金系列（傳說，只能靠里程碑拿）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：拳擊冠軍＋國王——王者之冠（尖頂珍珠、紅絨內襯、頂上金球十字）、金背心＋紅滾邊＋金鍊大獎牌、紅色拳擊短褲＋冠軍腰帶、
#       翼靴、黃金拳擊手套、白貂毛邊紅披風、金星純金啞鈴。
# 配色（GearCatalog）：c1 #F2B630 金、c2 #FFF1B8 淡金、c3 #C8302C 紅、glow #FFC83D。

M['gd1'] = toon('gd1', hexc('#F2B630'), 0.55, spec=True)
M['gd2'] = toon('gd2', hexc('#FFF1B8'), 0.66, spec=True)
M['gd3'] = toon('gd3', hexc('#C8302C'), 0.6)
M['gdvel'] = toon('gdvel', hexc('#8A1A18'), 0.6)                  # 紅絨（深紅）
M['gdfur'] = toon('gdfur', hexc('#F7F4EE'), 0.7)                  # 白貂毛
M['gdspot'] = toon('gdspot', hexc('#1A1A1A'), 0.6)
M['gdgem'] = toon('gdgem', hexc('#E0403A'), 0.5, spec=True)

def gtorus(bone, mat, c, R, r, sy=1.0, ms=32, ns=8, rot=(0, 0, 0)):
    """低面數圓環（不細分），sy＝前後方向壓扁的比例"""
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=ms, minor_segments=ns, location=c, rotation=rot)
    ob = bpy.context.object; ob.scale = (1, sy, 1); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(ob, bone, mat, 0)

def ecyl(bone, mat, c, rx, ry, depth, n=24, w=0.006):
    """橢圓柱（直立），腰帶用"""
    bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=1, depth=depth, location=c)
    ob = bpy.context.object; ob.scale = (rx, ry, 1); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return hard(ob, bone, mat, w)

# ---------- 王者之冠：金冠圈（上下金邊、紅寶石）、八個尖頂（高低交錯、頂端珍珠）、紅絨內襯、頂上金球十字 ----------
if want('head', 'gold'):
    hair_lite(False)
    CZ = 1.83; CR = 0.158; SY = 1.06
    cyl('head', 'gd1', (0, 0.01, CZ), CR, 0.05, (0, 0, 1), 32, 0.004)
    for z_ in (CZ - 0.025, CZ + 0.025):
        gtorus('head', 'gd2', (0, 0.01, z_), CR + 0.002, 0.007, 1.0, 32, 6)
    for k in range(8):
        a = 2 * math.pi * k / 8; tall = k % 2 == 0
        base = Vector((CR * math.sin(a), 0.01 - CR * math.cos(a), CZ + 0.02))
        L = 0.085 if tall else 0.05
        dirv = Vector((0.18 * math.sin(a), -0.18 * math.cos(a), 1))
        cyl('head', 'gd1', base + dirv.normalized() * (L / 2), 0.03 if tall else 0.024, L, dirv, 4, 0.0, r2=0.004)
        blob('head', 'gd2', base + dirv.normalized() * (L + 0.008), (0.013, 0.013, 0.013), seg=10, ring=6, subd=0)
        if tall:                                                                            # 冠圈上的寶石
            gem('head', 'gdgem', (CR * 1.04 * math.sin(a), 0.01 - CR * 1.04 * math.cos(a), CZ), (math.sin(a), -math.cos(a), 0), 0.014, 0.03)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, location=(0, 0.01, CZ + 0.01))      # 紅絨內襯（半球）
    import bmesh as _bm
    ob = bpy.context.object; ob.scale = (CR * 0.93, CR * 0.93, 0.085); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data); _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.001], context='VERTS'); bm.to_mesh(ob.data); bm.free()
    finish(ob, 'head', 'gdvel', 0)
    blob('head', 'gd1', (0, 0.01, CZ + 0.108), (0.022, 0.022, 0.022), seg=12, ring=8)                    # 金球
    obox('head', 'gd1', (0, 0.01, CZ + 0.15), (0.006, 0.006, 0.026), w=0.002)                            # 十字
    obox('head', 'gd1', (0, 0.01, CZ + 0.155), (0.018, 0.006, 0.006), w=0.002)
    face_lite(brow_tilt=-18)

# ---------- 黃金背心：塗在身體上（金色背心、紅色滾邊），金鍊＋胸前大獎牌（紅圈、淡金星） ----------
if want('top', 'gold'):
    tk = skinbody.data.attributes['tank']
    tr = skinbody.data.attributes.new('gdtrim', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co; ax = abs(x)
        vest = max(min(z - 0.98, 1.44 - z, 0.19 - ax), min(z - 1.40, 1.56 - z, ax - 0.075, 0.17 - ax))
        tk.data[i].value = vest
        tr.data[i].value = min(vest, 0.016 - vest) if z > 1.0 else -1                 # 沿背心邊緣一圈紅滾邊（下擺被短褲蓋住，不畫）
    mt = toon('skin_gold', (0.50, 0.53, 0.58), alt=hexc('#F2B630'), alt_attr='tank', alt_shade=0.55)
    skinbody.data.materials[0] = add_layer(mt, 'gdtrim', hexc('#C8302C'), 0.6)
    # 金鍊：從兩側肩帶繞到胸口，大顆鍊珠
    MZ = 1.25; my = torso_y(0, MZ) - 0.02
    for sx in (1, -1):
        pts = []
        for k in range(9):
            t = k / 8; x_ = (0.11 * (1 - t) + 0.012 * t) * sx; z_ = 1.47 * (1 - t) + (MZ + 0.05) * t - 0.03 * math.sin(math.pi * t)
            pts.append((x_, torso_y(abs(x_), z_) - 0.012, z_))
        tube('chest', 'gd1', pts, 0.008)
        for k in (2, 4, 6):
            blob('chest', 'gd2', pts[k], (0.012, 0.012, 0.012), seg=8, ring=6, subd=0)
    cyl('chest', 'gd1', (0, my, MZ), 0.056, 0.016, (0, -1, 0.15), 28, 0.004)                 # 獎牌
    cyl('chest', 'gd3', (0, my - 0.009, MZ), 0.044, 0.004, (0, -1, 0.15), 28)
    star('chest', 'gd2', (0, my - 0.013, MZ), (0, -1, 0.15), 0.036, th=0.008)
    obox('chest', 'gd1', (0, my + 0.002, MZ + 0.062), (0.016, 0.008, 0.012), w=0.003)        # 掛環

# ---------- 拳擊短褲＋冠軍腰帶：紅短褲、外側金色寬條和金色褲管邊；腰上一條紅皮帶、正面大金牌（淡金星、紅寶石）、兩側小金牌 ----------
if want('bottom', 'gold'):
    def _gs(x, y, z, zh):
        sx = 1 if x > 0 else -1
        ang = abs(math.atan2(y, (x - 0.12 * sx) * sx))
        return max((0.26 - ang) * 0.06, zh + 0.03 - z)
    shorts_trim('gdstripe', _gs, 0.05)
    ms = toon('shorts_gold', hexc('#C8302C'), 0.6, alt=hexc('#F2B630'), alt_attr='gdstripe', alt_shade=0.55)
    shorts.data.materials[0] = ms; skinbody.data.materials[2] = ms
    BZ = 1.035
    ecyl('hips', 'gdvel', (0, -0.005, BZ), 0.175, 0.128, 0.055, 32, 0.008)                  # 皮帶
    for z_ in (BZ - 0.026, BZ + 0.026):
        ecyl('hips', 'gd1', (0, -0.005, z_), 0.177, 0.13, 0.006, 32, 0)
    py = -0.005 - 0.128 - 0.012
    cyl('hips', 'gd1', (0, py, BZ), 0.07, 0.02, (0, -1, 0), 28, 0.006)                      # 正面大金牌
    cyl('hips', 'gd2', (0, py - 0.011, BZ), 0.056, 0.004, (0, -1, 0), 28)
    star('hips', 'gd1', (0, py - 0.016, BZ), (0, -1, 0), 0.045, th=0.008)
    gem('hips', 'gdgem', (0, py - 0.024, BZ), (0, -1, 0), 0.013, 0.026)
    for sx in (1, -1):                                                                      # 兩側小金牌
        a = math.radians(48)
        c = (0.178 * math.sin(a) * sx, -0.005 - 0.13 * math.cos(a), BZ)
        obox('hips', 'gd1', c, (0.026, 0.008, 0.03), (math.sin(a) * sx, -math.cos(a), 0), 0.004)

# ---------- 黃金戰靴：金靴（及小腿）、紅色靴口、淡金厚底，腳踝外側三片金羽翅膀、靴筒正面紅寶石 ----------
if want('feet', 'gold'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'gd1', [(x - 0.066, -0.19, 0.03), (x + 0.066, -0.19, 0.03), (x + 0.066, 0.085, 0.03), (x - 0.066, 0.085, 0.03),
                          (x - 0.05, -0.11, 0.11), (x + 0.05, -0.11, 0.11), (x + 0.062, 0.07, 0.15), (x - 0.062, 0.07, 0.15)], 0.028)
        cyl(fb, 'gd1', (x, 0.016, 0.2), 0.064, 0.12, n=20, w=0.008, r2=0.074)                  # 靴筒
        cyl(fb, 'gd3', (x, 0.016, 0.262), 0.078, 0.022, n=20, w=0.007)                         # 紅靴口
        obox(fb, 'gd2', (x, -0.055, 0.02), (0.072, 0.152, 0.022), w=0.009)                     # 厚底
        gem(fb, 'gdgem', (x, -0.052, 0.205), (0, -1, 0), 0.013, 0.028)
        base = Vector((x + 0.068 * sx, 0.03, 0.19))
        for k, (ty, tz, L) in enumerate(((0.95, 0.75, 0.15), (1.0, 0.35, 0.13), (0.95, -0.05, 0.10))):   # 羽翅
            dv = Vector((0.12 * sx, ty, tz)).normalized(); tip = base + dv * L
            side = Vector((0, -tz, ty)).normalized() * 0.022
            panel(fb, 'gd2' if k != 1 else 'gd1', [tuple(base + side), tuple(base - side), tuple(tip - side * 0.3), tuple(tip + side * 0.6)],
                  [(0, 1, 2, 3)], 0.008, 0.002, 0)

# ---------- 黃金拳擊手套：大顆金手套（拇指另一塊）、白色護腕、紅色綁帶、淡金高光線 ----------
if want('hands', 'gold'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'gdfur', w_ - d * 0.12, 0.06, d.length * 0.26, d, 20, 0.012, r2=0.064)   # 白護腕
        cyl(f'forearm.{s}', 'gd3', w_ - d * 0.2, 0.0655, 0.014, d, 20)                               # 紅綁帶
        h = B[f'hand.{s}'][0]
        blob(f'hand.{s}', 'gd1', h + Vector((0.004 * sx, -0.004, -0.08)), (0.066, 0.08, 0.078), seg=24, ring=14, subd=0)
        blob(f'hand.{s}', 'gd1', h + Vector((-0.045 * sx, -0.05, -0.055)), (0.028, 0.028, 0.04), (0, 0, 0), 12, 8, 0)   # 拇指
        obox(f'hand.{s}', 'gd2', h + Vector((0.066 * sx, 0, -0.085)), (0.004, 0.05, 0.006), w=0)                     # 外側高光線

# ---------- 王者披風：紅色長披風（深紅絨內裡）、下緣白貂毛邊（黑點），肩上白貂披肩，兩顆金扣＋胸前金鍊 ----------
if want('back', 'gold'):
    ROWS = [(1.50, 0.12, 0.115, 0.0), (1.45, 0.205, 0.15, 0.0), (1.36, 0.24, 0.17, 0.0),
            (1.22, 0.258, 0.198, 0.0), (1.06, 0.275, 0.228, 0.0), (0.90, 0.29, 0.26, 0.0)]
    PH = 50
    back_drape('chest', 'gd3', ROWS, math.radians(PH), 25, None, 0.01, 1)
    back_drape('chest', 'gdvel', ROWS, math.radians(PH), 25, None, 0.006, -1)
    _z, _rx, _ry, _yc = ROWS[-1]
    pts = [((_rx + 0.012) * math.sin(math.radians(-PH + 2 * PH * c / 24)), _yc + (_ry + 0.012) * math.cos(math.radians(-PH + 2 * PH * c / 24)), _z) for c in range(25)]
    tube('chest', 'gdfur', pts, 0.024)                                                     # 下緣毛邊
    for c in range(2, 24, 3):
        p = Vector(pts[c]); n_ = Vector((p.x, p.y, 0)).normalized()
        blob('chest', 'gdspot', p + n_ * 0.022, (0.007, 0.007, 0.012), seg=6, ring=4, subd=0)
    # 白貂披肩：肩膀後半圈的短披肩，下緣一排圓弧
    MR = [(1.52, 0.115, 0.115, 0.0), (1.47, 0.20, 0.155, 0.0), (1.40, 0.235, 0.18, 0.0)]
    back_drape('chest', 'gdfur', MR, math.radians(68), 25, lambda u: (0.03 * abs(math.sin(math.pi * u * 6)), 0.01), 0.022, 1)
    for k in range(9):
        a = math.radians(-60 + 120 * k / 8)
        blob('chest', 'gdspot', (0.262 * math.sin(a), 0.205 * math.cos(a), 1.43), (0.007, 0.007, 0.012), seg=6, ring=4, subd=0)
    for sx in (1, -1):                                                                      # 金扣
        cyl('chest', 'gd1', (0.13 * sx, -0.065, 1.47), 0.032, 0.016, (0.2 * sx, -0.4, 1), 20, 0.004)
        gem('chest', 'gdgem', (0.133 * sx, -0.074, 1.478), (0.2 * sx, -0.4, 1), 0.012, 0.022)
    tube('chest', 'gd1', [(0.12, -0.08, 1.465), (0.06, torso_y(0.06, 1.43) - 0.012, 1.43), (0, torso_y(0, 1.42) - 0.012, 1.42),
                          (-0.06, torso_y(0.06, 1.43) - 0.012, 1.43), (-0.12, -0.08, 1.465)], 0.006)

# ---------- 純金啞鈴：粗金鼓形鈴頭、外側白色星章、紅握把＋金色卡環 ----------
if want('bell', 'gold'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'gd3', hc, 0.019, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.118 * sy, 0))
            cyl(f'hand.{s}', 'gd1', c, 0.078, 0.07, (0, 1, 0), 24, 0.02)
            cyl(f'hand.{s}', 'gd2', c, 0.0795, 0.012, (0, 1, 0), 24)                              # 中間一圈淡金
            cyl(f'hand.{s}', 'gd1', hc + Vector((0, 0.07 * sy, 0)), 0.03, 0.022, (0, 1, 0), 16, 0.004)
            star(f'hand.{s}', 'gdfur', c + Vector((0, 0.036 * sy, 0)), (0, sy, 0), 0.042, th=0.008)
