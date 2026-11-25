# 熔岩系列（史詩）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：火山岩漿——岩石頭帶冒火舌、岩石背心＋發光岩漿裂紋＋肩上岩塊、橘短褲＋褲管火舌、岩石戰靴（鞋跟噴火）、
#       岩石火拳、火舌下緣披風、岩漿裂開的石塊啞鈴。
# 配色（GearCatalog）：c1 #2A1A16 黑岩、c2 #FF5A1F 熔岩橘、c3 #FFC23D 火黃、glow #FF5A1F。

M['lv1'] = toon('lv1', hexc('#3D2A24'), 0.55)                    # 比 c1 亮一點，兩階明暗才看得出來
M['lvdk'] = toon('lvdk', hexc('#1E1210'), 0.6)
M['lv2'] = toon('lv2', hexc('#FF5A1F'), 0.62)
M['lv3'] = toon('lv3', hexc('#FFC23D'), 0.66)
M['lvglow'] = flat('lvglow', hexc('#FF5A1F'), 3.0)
M['lvhot'] = flat('lvhot', hexc('#FFC23D'), 3.5)

def fire(bone, base, d, r, L, bend=(0, 0, 0)):
    """兩層火舌：外橘內黃"""
    flame(bone, 'lvglow', base, d, r, L, bend)
    flame(bone, 'lvhot', Vector(base) + Vector(d).normalized() * 0.005, d, r * 0.55, L * 0.68, Vector(bend) * 0.6)

# ---------- 火焰頭帶：黑岩頭帶，正面五道火舌往後上方竄 ----------
if want('head', 'lava'):
    hair_lite()
    bpy.ops.mesh.primitive_torus_add(major_radius=0.163, minor_radius=0.022, major_segments=32, minor_segments=8,
                                     location=(0, -0.005, 1.775), rotation=(math.radians(-8), 0, 0))
    finish(bpy.context.object, 'head', 'lv1', 0)
    for k, a in enumerate((-62, -31, 0, 31, 62)):
        r_ = math.radians(a)
        base = (0.168 * math.sin(r_), -0.005 - 0.168 * math.cos(r_), 1.79 + 0.004 * abs(a) / 31)
        L = 0.17 if a == 0 else 0.13 if abs(a) == 31 else 0.10
        fire('head', base, (0.35 * math.sin(r_), 0.25, 1), 0.03, L, (0, 0.05, 0))
    rock('head', 'lv1', (0, -0.183, 1.775), (0.03, 0.016, 0.026), 3)                            # 正面岩塊
    cyl('head', 'lvhot', (0, -0.197, 1.775), 0.011, 0.006, (0, -1, 0), 6)
    face_lite(brow_tilt=-24)

# ---------- 熔岩背心：塗在身體上（黑岩色、寬肩帶），發光的岩漿裂紋（橘外框＋黃芯），肩上兩塊岩石、胸口岩漿核 ----------
if want('top', 'lava'):
    FR = [[(0.02, 0.99), (0.06, 1.08), (0.03, 1.16), (0.09, 1.24), (0.07, 1.32), (0.12, 1.40)],
          [(-0.03, 0.99), (-0.08, 1.06), (-0.05, 1.14), (-0.12, 1.22), (-0.10, 1.30), (-0.15, 1.37)],
          [(0.09, 1.24), (0.17, 1.21)], [(-0.10, 1.30), (-0.03, 1.36)]]
    BK = [[(0.0, 0.99), (0.05, 1.10), (-0.02, 1.20), (0.06, 1.30), (0.0, 1.42)], [(-0.02, 1.20), (-0.14, 1.26)],
          [(0.06, 1.30), (0.15, 1.38)]]
    tk = skinbody.data.attributes['tank']
    ck = skinbody.data.attributes.new('lvcrack', 'FLOAT', 'POINT')
    co = skinbody.data.attributes.new('lvcore', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co; ax = abs(x)
        vest = max(min(z - 0.98, 1.44 - z, 0.195 - ax), min(z - 1.40, 1.56 - z, ax - 0.06, 0.185 - ax))   # 背心＋寬肩帶
        tk.data[i].value = vest
        P_ = FR if y < 0 else BK
        ck.data[i].value = min(max(seg_field(x, z, p, 0.012) for p in P_), vest)
        co.data[i].value = min(max(seg_field(x, z, p, 0.0045) for p in P_), vest)
    mt = toon('skin_lava', (0.50, 0.53, 0.58), alt=hexc('#3D2A24'), alt_attr='tank', alt_shade=0.55)
    add_layer(mt, 'lvcrack', hexc('#FF5A1F'), 0.8)
    skinbody.data.materials[0] = add_layer(mt, 'lvcore', hexc('#FFC23D'), 0.85)
    for sx, sd in ((1, 5), (-1, 7)):                                     # 肩上岩塊（在肩帶上，不壓到手臂）
        rock('chest', 'lv1', (0.125 * sx, 0.0, 1.5), (0.055, 0.06, 0.032), sd)
        obox('chest', 'lvglow', (0.125 * sx, -0.02, 1.522), (0.004, 0.028, 0.004), (0, 0, 1), 0, roll=0.5 * sx)
    cz = 1.33                                                            # 胸口岩漿核：岩石框＋黃色熔芯
    cyl('chest', 'lvdk', (0, torso_y(0, cz) - 0.004, cz), 0.036, 0.018, (0, -1, 0), 7, 0.004)
    cyl('chest', 'lvhot', (0, torso_y(0, cz) - 0.014, cz), 0.022, 0.006, (0, -1, 0), 7)

# ---------- 岩漿短褲：熔岩橘，褲管下緣竄起黃色火舌、最下面一圈黑岩邊 ----------
if want('bottom', 'lava'):
    def _fl(x, y, z, zh):
        sx = 1 if x > 0 else -1
        u = math.atan2(y, (x - 0.12 * sx) * sx) / (2 * math.pi) + 0.5
        k = int(u * 6) % 2
        return zh + 0.025 + (0.10 if k else 0.065) * tri(u * 6) ** 1.6 - z
    shorts_trim('lvflame', _fl, 0.06)
    shorts_trim('lvhem', lambda x, y, z, zh: zh + 0.014 - z, 0.03)
    ms = toon('shorts_lava', hexc('#FF5A1F'), 0.62, alt=hexc('#FFC23D'), alt_attr='lvflame', alt_shade=0.66)
    ms = add_layer(ms, 'lvhem', hexc('#3D2A24'), 0.55)
    shorts.data.materials[0] = ms; skinbody.data.materials[2] = ms

# ---------- 熔岩戰靴：黑岩靴身、鞋頭岩塊、側面發光裂縫、厚底，鞋跟往後噴兩道火 ----------
if want('feet', 'lava'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'lv1', [(x - 0.07, -0.19, 0.035), (x + 0.07, -0.19, 0.035), (x + 0.07, 0.09, 0.035), (x - 0.07, 0.09, 0.035),
                          (x - 0.058, -0.1, 0.12), (x + 0.058, -0.1, 0.12), (x + 0.065, 0.075, 0.17), (x - 0.065, 0.075, 0.17)], 0.03)
        cyl(fb, 'lv1', (x, 0.018, 0.19), 0.066, 0.08, n=8, w=0.008, r2=0.076)                     # 靴筒（八角，岩石感）
        cyl(fb, 'lvglow', (x, 0.018, 0.232), 0.077, 0.008, n=8)
        obox(fb, 'lvdk', (x, -0.05, 0.02), (0.076, 0.155, 0.024), w=0.008)                          # 厚底
        rock(fb, 'lv1', (x, -0.165, 0.075), (0.055, 0.045, 0.04), 11 if sx > 0 else 13)               # 鞋頭岩塊
        for yy, zz, rl in ((-0.06, 0.085, 0.6), (0.02, 0.12, -0.5)):                                # 側面裂縫
            obox(fb, 'lvglow', (x + 0.07 * sx, yy, zz), (0.003, 0.004, 0.032), (0, 0.6 * rl, 1), 0)
        for k in (1, -1):                                                                            # 鞋跟火焰
            fire(fb, (x + 0.03 * k, 0.09, 0.07), (0.25 * k, 1, 0.55), 0.026, 0.11, (0, 0, 0.04))

# ---------- 火拳手套：岩石拳頭（不規則石塊）、發光裂縫、拳頭外側竄出火舌、八角岩石護腕 ----------
if want('hands', 'lava'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'lv1', w_ - d * 0.17, 0.056, d.length * 0.3, d, 8, 0.008, r2=0.068)
        cyl(f'forearm.{s}', 'lvglow', w_ - d * 0.06, 0.069, 0.008, d, 8)
        h = B[f'hand.{s}'][0]
        rock(f'hand.{s}', 'lv1', h + Vector((0, 0, -0.066)), (0.056, 0.07, 0.066), 21 if sx > 0 else 23, 0.15)
        obox(f'hand.{s}', 'lvglow', h + Vector((0.058 * sx, 0, -0.07)), (0.003, 0.05, 0.004), (0, 0.3, 1), 0, roll=0)
        for k, yy in enumerate((-0.035, 0.0, 0.035)):
            fire(f'hand.{s}', h + Vector((0.05 * sx, yy, -0.05)), (sx, 0, 0.75), 0.022, 0.08 + 0.02 * (k == 1), (0, 0, 0.03))

# ---------- 火焰披風：外橘內黑岩，下緣是長短交錯的尖火舌、黃色滾邊；肩前兩顆岩石扣 ----------
if want('back', 'lava'):
    ROWS = [(1.50, 0.12, 0.115, 0.0), (1.45, 0.205, 0.15, 0.0), (1.36, 0.24, 0.17, 0.0),
            (1.22, 0.255, 0.195, 0.0), (1.08, 0.27, 0.225, 0.0), (0.97, 0.28, 0.245, 0.0)]
    PH = 50
    def _tongue(u):                                      # 七道尖火舌，中間長、兩側短，長短交錯
        k = int(min(u, 0.9999) * 7)
        return 0.03 + (0.20 if k % 2 == 0 else 0.13) * (1 - 0.35 * abs(u - 0.5) * 2) * tri(u * 7) ** 1.3, 0.02
    back_drape('chest', 'lv2', ROWS, math.radians(PH), 36, _tongue, 0.01, 1)
    back_drape('chest', 'lvdk', ROWS, math.radians(PH), 36, _tongue, 0.006, -1)
    _z, _rx, _ry, _yc = ROWS[-1]
    _pts = []
    for c in range(57):
        u = c / 56; p_ = math.radians(-PH + 2 * PH * u); dz, fl = _tongue(u)
        _pts.append(((_rx + fl + 0.004) * math.sin(p_), _yc + (_ry + fl + 0.004) * math.cos(p_), _z - dz))
    tube('chest', 'lv3', _pts, 0.006)
    for sx, sd in ((1, 31), (-1, 33)):
        rock('chest', 'lv1', (0.125 * sx, -0.075, 1.455), (0.034, 0.026, 0.034), sd)
        cyl('chest', 'lvhot', (0.125 * sx, -0.1, 1.455), 0.012, 0.006, (0.2 * sx, -1, 0), 6)

# ---------- 岩漿啞鈴：兩頭是不規則黑岩，中間一圈岩漿縫發光 ----------
if want('bell', 'lava'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'lvdk', hc, 0.018, 0.30, (0, 1, 0), 12)
        for k, sy in enumerate((1, -1)):
            c = hc + Vector((0, 0.115 * sy, 0))
            rock(f'hand.{s}', 'lv1', c, (0.08, 0.058, 0.078), 41 + k + (2 if sx < 0 else 0), 0.18)
            cyl(f'hand.{s}', 'lvglow', c, 0.072, 0.012, (0, 1, 0), 9)
            obox(f'hand.{s}', 'lvhot', c + Vector((0, 0.058 * sy, 0)), (0.004, 0.003, 0.045), (0, 0, 1), 0, roll=0.4)
