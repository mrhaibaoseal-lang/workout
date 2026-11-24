# 夜巡者系列（史詩，黑夜義警）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：義警兜帽＋眼罩、長袖戰術背心（V 字徽章、斜背帶、工具腰帶）、戰術長褲（大腿口袋、護膝）、
#       戰術靴（厚齒紋鞋底、綁帶）、戰術手套＋前臂鰭刃、扇形下緣斗篷（橘色內裡＋立領）、手裏劍啞鈴。
# 配色（GearCatalog）：c1 #1C2230 夜黑藍、c2 #FF8A1F 橘、c3 #3B4558 石板灰、glow #FF8A1F。原創，不做成任何現有英雄。

M['nt1'] = toon('nt1', hexc('#252D40'), 0.6)                     # 比 c1 亮一點，兩階明暗才看得出來
M['nt2'] = toon('nt2', hexc('#FF8A1F'), 0.62)
M['nt3'] = toon('nt3', hexc('#4A5568'), 0.58, spec=True)          # 石板灰硬件（扣具、護膝）
M['ntmat'] = toon('ntmat', hexc('#2A303A'), 0.55)                 # 消光黑（啞鈴、鞋底）
M['ntglow'] = flat('ntglow', hexc('#FF8A1F'), 3.0)

def chevron(bone, mat, c, w, h, t, th=0.008):
    """V 字（尖朝下）：正面朝前的一片六邊形，w 寬、h 高、t 筆畫粗"""
    x0, y0, z0 = c
    vs = [(-w / 2, y0, z0 + h / 2), (-w / 2 + t, y0, z0 + h / 2), (0, y0, z0 - h / 2 + t * 1.4),
          (w / 2 - t, y0, z0 + h / 2), (w / 2, y0, z0 + h / 2), (0, y0, z0 - h / 2)]
    vs = [(x0 + v[0], v[1], v[2]) for v in vs]
    return panel(bone, mat, vs, [(0, 5, 2, 1), (5, 4, 3, 2)], th, 0, 1)

# ---------- 義警兜帽＋眼罩 ----------
if want('head', 'night'):
    HC, HR = (0, 0.008, 1.715), (0.182, 0.192, 0.205)
    def _hood(x, y, z):
        if z < 1.555: return False
        if y < -0.03 and ((x / 0.128) ** 2 + ((z - 1.70) / 0.118) ** 2 < 1 or (z < 1.70 and abs(x) < 0.128)): return False
        return True
    cap_shell('head', 'nt1', HC, HR, _hood, 0.014)
    # 開口的橘色滾邊：沿開口邊緣、貼著兜帽外表面
    pts = []
    for i in range(25):                                   # 兩側直線＋上緣半橢圓
        t = i / 24
        if t < 0.2:   x, z = 0.128, 1.575 + (1.70 - 1.575) * (t / 0.2)
        elif t > 0.8: x, z = -0.128, 1.70 - (1.70 - 1.575) * ((t - 0.8) / 0.2)
        else:
            a = math.pi * (t - 0.2) / 0.6; x, z = 0.128 * math.cos(a), 1.70 + 0.118 * math.sin(a)
        pts.append((x, on_ellipsoid(HC, (HR[0] + 0.007, HR[1] + 0.007, HR[2] + 0.007), x, z), z))
    tube('head', 'nt2', pts, 0.011)
    # 兜帽尖：往後垂的布尖
    cyl('head', 'nt1', (0, 0.205, 1.78), 0.075, 0.16, (0, 1, -0.55), 12, 0.0, r2=0.0)
    # 眼罩：貼著臉的一條帶子（眼睛從帶子上凸出來）
    cap_shell('head', 'nt1', (0, -0.01, 1.70), (0.156, 0.166, 0.186),
              lambda x, y, z: abs(z - 1.705) < 0.03 and y < -0.07, 0.006)
    face(brow_tilt=-26, eye_tilt=-18)                     # 眉毛壓低：夜巡者比較兇
    # 兜帽兩側的橘色通訊燈
    for sx in (1, -1):
        cyl('head', 'nt3', (0.188 * sx, 0.0, 1.69), 0.03, 0.02, (sx, 0, 0), 12, 0.004)
        cyl('head', 'ntglow', (0.199 * sx, 0.0, 1.69), 0.016, 0.006, (sx, 0, 0), 12)

# ---------- 長袖戰術背心：塗在身體上（長袖夜黑藍＋石板灰背心），V 字徽章、斜背帶、胸前彈匣袋 ----------
if want('top', 'night'):
    tk = skinbody.data.attributes['tank']
    ve = skinbody.data.attributes.new('ntvest', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sl = sleeve_paint(x, y, z, 0.50)
        tk.data[i].value = min(neck, hem, sl)
        # 背心：軀幹、領口開大一點、袖籠在肩膀內側
        vest = min(hem + 0.01, neck - 0.02, 0.205 - abs(x), 1.47 - z)
        ve.data[i].value = vest
    mt = toon('skin_night', (0.50, 0.53, 0.58), alt=hexc('#252D40'), alt_attr='tank', alt_shade=0.6)
    skinbody.data.materials[0] = add_layer(mt, 'ntvest', hexc('#4A5568'), 0.58)
    chevron('chest', 'nt2', (0, -0.127, 1.36), 0.11, 0.06, 0.024)        # 胸前雙 V 徽章
    chevron('chest', 'nt2', (0, -0.127, 1.30), 0.075, 0.042, 0.018)
    for sx in (1, -1):                                                     # 彈匣袋
        obox('chest', 'nt3', (0.09 * sx, -0.128, 1.17), (0.04, 0.018, 0.045), w=0.008)
        obox('chest', 'nt1', (0.09 * sx, -0.145, 1.20), (0.042, 0.006, 0.014), w=0.003)
    # 斜背帶：右肩 → 左腰（胸前一段＋背後一段）
    for yf in (-0.128, 0.122):
        a, b = Vector((-0.15, yf, 1.47)), Vector((0.14, yf, 1.13))   # 到 1.05 時深蹲會切進左大腿
        obox('chest', 'nt1', (a + b) / 2, (0.022, 0.006, (b - a).length / 2), b - a, 0.003, roll=0)
    obox('chest', 'nt2', (-0.06, -0.134, 1.34), (0.022, 0.006, 0.02), (0.6, 0, -0.8), 0.003)   # 背帶扣
    # 工具腰帶＋四個小包
    obox('hips', 'nt3', (0, -0.005, 0.99), (0.165, 0.112, 0.024), w=0.01)
    obox('hips', 'nt2', (0, -0.118, 0.99), (0.028, 0.006, 0.02), w=0.003)
    for ax_, ay_ in ((0.12, -0.09), (-0.12, -0.09), (0.16, 0.02), (-0.16, 0.02)):
        obox('hips', 'nt1', (ax_, ay_ - 0.02 * (ay_ < 0), 0.975), (0.03, 0.022, 0.036), w=0.007)

# ---------- 戰術長褲：大腿側袋、護膝 ----------
if want('bottom', 'night'):
    for s, sx in (('L', 1), ('R', -1)):
        a, b = B[f'thigh.{s}']; d = b - a
        obox(f'thigh.{s}', 'nt1', a + d * 0.55 + Vector((0.098 * sx, 0, 0)), (0.016, 0.055, d.length * 0.16), d, 0.008)   # 側袋
        obox(f'thigh.{s}', 'nt2', a + d * 0.42 + Vector((0.112 * sx, 0, 0)), (0.004, 0.04, 0.006), d, 0)                 # 袋蓋橘線
        k, an = B[f'shin.{s}']; d2 = an - k
        ellipsoid(f'shin.{s}', 'nt3', k + Vector((0, -0.068, 0.0)), (0.06, 0.03, 0.07))                                   # 護膝
        obox(f'shin.{s}', 'nt2', k + Vector((0, -0.098, 0.0)), (0.035, 0.004, 0.008), w=0)
        cyl(f'shin.{s}', 'nt1', an + Vector((0, 0, 0.05)), 0.056, 0.05, d2, 16, 0.006)                                    # 褲管束口

# ---------- 戰術靴：厚齒紋鞋底、綁帶、腳踝扣帶 ----------
if want('feet', 'night'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'nt1', [(x - 0.068, -0.19, 0.035), (x + 0.068, -0.19, 0.035), (x + 0.068, 0.085, 0.035), (x - 0.068, 0.085, 0.035),
                          (x - 0.055, -0.11, 0.115), (x + 0.055, -0.11, 0.115), (x + 0.062, 0.075, 0.16), (x - 0.062, 0.075, 0.16)], 0.028)
        cyl(fb, 'nt1', (x, 0.018, 0.19), 0.066, 0.09, n=16, w=0.008, r2=0.072)        # 靴筒
        obox(fb, 'ntmat', (x, -0.055, 0.017), (0.074, 0.15, 0.018), w=0.008)           # 厚鞋底
        for j in range(5):                                                              # 齒紋
            obox(fb, 'ntmat', (x, -0.17 + j * 0.06, -0.003), (0.068, 0.012, 0.008), w=0.003)
        for j, (yy, zz) in enumerate(((-0.12, 0.10), (-0.08, 0.12), (-0.04, 0.14))):    # 交叉綁帶
            for k in (1, -1):
                obox(fb, 'nt2', (x, yy, zz + 0.01), (0.04, 0.006, 0.005), (0, -0.5, 1), 0.002, roll=0.5 * k)
        cyl(fb, 'nt3', (x, 0.02, 0.215), 0.074, 0.018, n=16, w=0.004)                  # 腳踝扣帶
        obox(fb, 'nt2', (x + 0.074 * sx, 0.02, 0.215), (0.006, 0.016, 0.012), w=0.002)  # 扣環

# ---------- 戰術手套＋前臂鰭刃 ----------
if want('hands', 'night'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e; dn = d.normalized()
        cyl(f'forearm.{s}', 'nt1', e + d * 0.62, 0.056, d.length * 0.62, d, 16, 0.008, r2=0.064)   # 護臂
        for j in range(3):                                                        # 外側三片鰭刃（往後上翹）
            base = e + d * (0.42 + 0.17 * j) + Vector((0.05 * sx, 0.02, 0))
            tip = base + Vector((0.05 * sx, 0.05, 0)) - dn * 0.05
            panel(f'forearm.{s}', 'nt3', [tuple(base - dn * 0.035), tuple(base + dn * 0.02), tuple(tip)], [(0, 1, 2)], 0.008, 0, 0)
            panel(f'forearm.{s}', 'nt2', [tuple(base - dn * 0.03 + Vector((0, 0, 0))), tuple(tip), tuple(tip + dn * 0.008)], [(0, 1, 2)], 0.009, 0, 0)
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'nt1', h + Vector((0, 0, -0.065)), (0.046, 0.064, 0.058))
        obox(f'hand.{s}', 'nt3', h + Vector((0.044 * sx, 0, -0.072)), (0.01, 0.055, 0.03), w=0.006)  # 指節護板
        obox(f'hand.{s}', 'nt2', h + Vector((0.055 * sx, 0, -0.072)), (0.003, 0.04, 0.005), w=0)

# ---------- 夜行斗篷：扇形下緣、橘色內裡、石板灰立領 ----------
if want('back', 'night'):
    ROWS = [(1.50, 0.12, 0.115, 0.0), (1.45, 0.205, 0.15, 0.0), (1.36, 0.24, 0.17, 0.0),
            (1.22, 0.255, 0.195, 0.0), (1.06, 0.27, 0.225, 0.0), (0.93, 0.29, 0.255, 0.0)]
    def _scallop(u):                                     # 五個尖、中間四個往上彎的弧
        k = (u * 4) % 1.0
        return 0.15 - 0.13 * math.sin(math.pi * k), 0.025
    back_drape('chest', 'nt1', ROWS, math.radians(52), 33, _scallop, 0.01, 1)          # 外層
    back_drape('chest', 'nt2', ROWS, math.radians(52), 33, _scallop, 0.006, -1)        # 內裡（往內加厚）
    _z, _rx, _ry, _yc = ROWS[-1]                         # 下緣橘色滾邊（背面才認得出斗篷）
    _pts = []
    for c in range(65):
        u = c / 64; p_ = math.radians(-52 + 104 * u); dz, fl = _scallop(u)
        _pts.append(((_rx + fl + 0.004) * math.sin(p_), _yc + (_ry + fl + 0.004) * math.cos(p_), _z - dz))
    tube('chest', 'nt2', _pts, 0.007)
    # 立領：後頸往上張開的一片
    vs = []
    for c in range(9):
        p_ = math.radians(-70 + 140 * c / 8)
        vs += [(0.11 * math.sin(p_), 0.11 * math.cos(p_) + 0.005, 1.48), (0.15 * math.sin(p_), 0.15 * math.cos(p_) + 0.04, 1.62 - 0.03 * abs(math.sin(p_)))]
    panel('chest', 'nt3', vs, [(2 * c, 2 * c + 2, 2 * c + 3, 2 * c + 1) for c in range(8)], 0.01, 0, 1)
    for sx in (1, -1):                                   # 肩上扣環：混搭沒有上衣時，斗篷才不像浮在背後
        cyl('chest', 'nt3', (0.13 * sx, -0.06, 1.47), 0.03, 0.014, (0.2 * sx, -0.4, 1), 12, 0.003)
        cyl('chest', 'ntglow', (0.13 * sx, -0.064, 1.478), 0.014, 0.008, (0.2 * sx, -0.4, 1), 12)

# ---------- 手裏劍啞鈴：兩頭是四角鏢形的消光鐵片 ----------
if want('bell', 'night'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'nt3', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.115 * sy, 0))
            star(f'hand.{s}', 'ntmat', c, (0, sy, 0), 0.098, 0.045, 0.036, 4, up=(0, 0, 1))
            star(f'hand.{s}', 'ntmat', c + Vector((0, 0.03 * sy, 0)), (0, sy, 0), 0.08, 0.04, 0.02, 4, up=(1, 0, 1))
            cyl(f'hand.{s}', 'nt3', c + Vector((0, 0.046 * sy, 0)), 0.03, 0.014, (0, 1, 0), 12, 0.003)
            cyl(f'hand.{s}', 'ntglow', c + Vector((0, 0.055 * sy, 0)), 0.017, 0.006, (0, 1, 0), 12)
