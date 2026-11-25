# 星界魔導系列（傳說，奇幻法師）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：漂浮星晶冠（頭頂一圈晶石＋額前星）、星界法袍（靛藍長袖、喇叭袖口、扇形立領、菱形寶石、後擺雙燕尾）、
#       星點長褲＋尖角褲口、捲尖巫師鞋（鞋尖星）、星界護手（手背上漂浮的小行星）、能量羽翼、星核啞鈴（球＋行星環）。
# 配色（GearCatalog）：c1 #22184A 靛藍、c2 #FF6BD6 星粉、c3 #8FE3FF 星藍、glow #FF6BD6。原創，不做成任何現有角色。

M['as1'] = toon('as1', hexc('#2E2260'), 0.6)                       # 靛藍（比 c1 亮一點）
M['aspk'] = toon('aspk', hexc('#FF6BD6'), 0.6)
M['ascy'] = toon('ascy', hexc('#8FE3FF'), 0.62)
M['ascrys'] = toon('ascrys', hexc('#B9F0FF'), 0.5, spec=True)      # 晶石
M['asgem'] = toon('asgem', hexc('#FF6BD6'), 0.5, spec=True)
M['asglow'] = flat('asglow', hexc('#FF6BD6'), 3.2)
M['asglow2'] = flat('asglow2', hexc('#8FE3FF'), 2.6)

def ring(bone, mat, c, R, r, normal):
    """細圓環（行星環、光環）"""
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=48, minor_segments=8, location=c)
    ob = bpy.context.object; ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(normal))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(ob, bone, mat, 0)

# ---------- 漂浮星晶冠：頭頂上方一圈晶石（往外斜）、細光環、額前粉色星 ----------
if want('head', 'astral'):
    hair_lite()
    face_lite(brow_tilt=-14, eye_tilt=-10)                     # 法師：眼神比較冷靜
    C = Vector((0, 0.0, 1.93))
    ring('head', 'asglow2', C, 0.15, 0.006, (0, 0.2, 1))   # 光環（略往後傾）
    for k in range(7):
        a = math.radians(-90 + 180 * k / 6)                # 只排前半圈＋兩側，正面最高
        p = C + Vector((0.15 * math.sin(a), -0.15 * math.cos(a) * 1.0, 0.0)) + Vector((0, 0.03 * (1 - math.cos(a)), 0))
        L = 0.07 + 0.06 * math.cos(a) ** 2
        gem('head', 'ascrys', p, (0.25 * math.sin(a), -0.25 * math.cos(a), 1), 0.02, L)
    star('head', 'aspk', (0, -0.172, 1.80), (0, -1, 0.35), 0.045, 0.02, 0.014)     # 額前星
    star('head', 'asglow', (0, -0.18, 1.80), (0, -1, 0.35), 0.026, 0.012, 0.006)
    for sx in (1, -1):                                    # 太陽穴兩顆小晶石
        gem('head', 'ascrys', (0.16 * sx, -0.06, 1.77), (sx, -0.3, 0.5), 0.012, 0.05)

# ---------- 星界法袍：塗在身體上（靛藍長袖、星藍滾邊），扇形立領、菱形寶石、喇叭袖口、後擺雙燕尾 ----------
if want('top', 'astral'):
    tk = skinbody.data.attributes['tank']
    tr = skinbody.data.attributes.new('astrim', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sl = sleeve_paint(x, y, z, 0.42)
        robe = min(neck, hem, sl); tk.data[i].value = robe
        # 前襟：從領口斜下到腰的兩條星藍滾邊（V 形）
        vline = abs(abs(x) - 0.03 - (1.47 - z) * 0.25)
        tr.data[i].value = min(robe, 0.012 - vline, z - 1.0, 1.47 - z)
    mt = toon('skin_astral', (0.50, 0.53, 0.58), alt=hexc('#2E2260'), alt_attr='tank', alt_shade=0.6)
    skinbody.data.materials[0] = add_layer(mt, 'astrim', hexc('#8FE3FF'), 0.62)
    gem('chest', 'asgem', (0, -0.135, 1.28), (0, -1, 0), 0.03, 0.09)                # 胸前菱形寶石
    gem('chest', 'asglow', (0, -0.142, 1.28), (0, -1, 0), 0.016, 0.06)
    # 扇形立領：後頸往上往外張開，五片尖瓣
    vs, fs = [], []
    for c in range(11):
        p_ = math.radians(-80 + 160 * c / 10)
        hi = 1.66 + (0.05 if c % 2 == 0 else 0.0) - 0.04 * abs(math.sin(p_))
        vs += [(0.105 * math.sin(p_), 0.105 * math.cos(p_), 1.48), (0.17 * math.sin(p_), 0.17 * math.cos(p_) + 0.04, hi)]
    panel('chest', 'as1', vs, [(2 * c, 2 * c + 2, 2 * c + 3, 2 * c + 1) for c in range(10)], 0.01, 0, 1)
    tube('chest', 'ascy', [vs[2 * c + 1] for c in range(11)], 0.006)
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'as1', e + d * 0.62, 0.058, d.length * 0.22, d, 20, 0.004, r2=0.095)   # 喇叭袖口
        cyl(f'forearm.{s}', 'ascy', e + d * 0.73, 0.097, 0.01, d, 20, 0.002)
        gem(f'upper_arm.{s}', 'asgem', (0.30 * sx, -0.01, 1.47), (sx, 0, 1.2), 0.022, 0.06)     # 肩上晶石
    # 後擺雙燕尾：從後腰垂下、往後張開（綁 hips）
    for sx in (1, -1):
        vs = [(0.02 * sx, 0.125, 1.00), (0.14 * sx, 0.10, 1.00), (0.16 * sx, 0.20, 0.62), (0.07 * sx, 0.19, 0.70)]
        panel('hips', 'as1', vs, [(0, 1, 2, 3)], 0.01, 0, 1)
        tube('hips', 'ascy', [vs[1], vs[2], vs[3]], 0.006)
        star('hips', 'aspk', (0.13 * sx, 0.205, 0.66), (0, 1, 0), 0.022, 0.01, 0.008)
    obox('hips', 'ascy', (0, -0.005, 0.99), (0.163, 0.11, 0.016), w=0.006)              # 細腰帶

# ---------- 星點長褲：靛藍底撒粉／藍星點，褲口尖角 ----------
if want('bottom', 'astral'):
    dt = shorts.data.attributes.new('asdot', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        # 用格點雜湊撒點：每 6 cm 一格、格子裡一個點，半徑 1.1 cm
        a = math.atan2(y, x - (0.12 if x > 0 else -0.12)); u, w = a * 0.07 / 0.06, z / 0.06
        iu, iw = math.floor(u), math.floor(w)
        h = math.sin(iu * 12.9898 + iw * 78.233) * 43758.5453; h -= math.floor(h)
        cu, cw = iu + 0.25 + 0.5 * h, iw + 0.25 + 0.5 * ((h * 7.3) % 1)
        dist = math.hypot(u - cu, w - cw) * 0.06
        dt.data[i].value = (0.011 - dist) if (h > 0.45 and z < 0.93) else -1
    shorts.data.materials[0] = add_layer(toon('pants_astral2', hexc('#2E2260'), 0.6, alt=hexc('#2E2260'), alt_attr='asdot', alt_shade=0.6),
                                         'asdot', hexc('#8FE3FF'), 0.62)
    for s, sx in (('L', 1), ('R', -1)):
        k, an = B[f'shin.{s}']; d2 = an - k
        c = an + Vector((0, 0, 0.07))
        cyl(f'shin.{s}', 'ascy', c, 0.058, 0.014, d2, 20, 0.003)
        for ph in (0, 1, 2, 3):                                                         # 褲口四個尖角往下垂
            a = math.radians(45 + 90 * ph); o = Vector((math.cos(a), math.sin(a), 0))
            cyl(f'shin.{s}', 'as1', c + o * 0.058 + Vector((0, 0, -0.03)), 0.02, 0.05, (o.x * 0.3, o.y * 0.3, -1), 4, 0.0, r2=0.0)

# ---------- 捲尖巫師鞋：鞋尖往前往上捲一圈，尖端一顆星 ----------
if want('feet', 'astral'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'as1', [(x - 0.062, -0.16, 0.02), (x + 0.062, -0.16, 0.02), (x + 0.064, 0.085, 0.02), (x - 0.064, 0.085, 0.02),
                          (x - 0.04, -0.12, 0.09), (x + 0.04, -0.12, 0.09), (x + 0.058, 0.075, 0.14), (x - 0.058, 0.075, 0.14)], 0.03)
        obox(fb, 'ascy', (x, -0.04, 0.01), (0.066, 0.13, 0.012), w=0.006)
        pts, tp = [], []
        for i in range(16):                                        # 捲尖：先往前，再往上往回捲
            t = i / 15; a = t * math.radians(250)
            r_ = 0.06 * (1 - 0.45 * t)
            pts.append((x, -0.16 - r_ * math.sin(a) - 0.02 * t, 0.075 - r_ * math.cos(a) + 0.018)); tp.append(1 - 0.75 * t)
        tube(fb, 'as1', pts, 0.03, taper=tp)
        star(fb, 'aspk', pts[-1], (1, 0, 0), 0.024, 0.01, 0.01)
        cyl(fb, 'ascy', (x, 0.018, 0.15), 0.064, 0.014, n=20, w=0.003)                   # 鞋口滾邊

# ---------- 星界護手：星藍手套、粉色腕環，手背外側漂浮一顆帶環的小行星 ----------
if want('hands', 'astral'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'aspk', w_ - d * 0.12, 0.054, 0.03, d, 20, 0.004)
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'ascy', h + Vector((0, 0, -0.065)), (0.045, 0.063, 0.057))
        pc = h + Vector((0.115 * sx, 0, -0.04))
        ellipsoid(f'hand.{s}', 'aspk', pc, (0.03, 0.03, 0.03))
        ring(f'hand.{s}', 'asglow2', pc, 0.05, 0.004, (0.3 * sx, 0.4, 1))
        for k in range(3):                                                             # 幾顆小星塵
            a = k * 2.1
            star(f'hand.{s}', 'asglow2', pc + Vector((0.02 * sx, 0.06 * math.cos(a), 0.06 * math.sin(a))), (sx, 0, 0), 0.01, 0.004, 0.004)

# ---------- 能量羽翼：左右各一大一小兩片，粉色大翼＋星藍小翼，邊緣發光 ----------
if want('back', 'astral'):
    def wing(sx, root, pts, mat, edge):
        vs = [tuple(root)] + [(root[0] + p[0] * sx, root[1] + p[1], root[2] + p[2]) for p in pts]
        fs = [(0, i, i + 1) for i in range(1, len(vs) - 1)]
        panel('chest', mat, vs, fs, 0.012, 0, 0)
        tube('chest', edge, vs[1:], 0.006)
    for sx in (1, -1):
        root = (0.06 * sx, 0.16, 1.36)
        # 大翼：往上往外張開，下緣三個羽尖
        wing(sx, root, [(0.06, 0.04, 0.26), (0.30, 0.10, 0.30), (0.42, 0.14, 0.16), (0.34, 0.13, 0.08), (0.40, 0.15, -0.02),
                        (0.30, 0.13, -0.04), (0.33, 0.14, -0.14), (0.18, 0.10, -0.08)], 'aspk', 'asglow')
        # 小翼：往下往外
        wing(sx, (0.06 * sx, 0.155, 1.26), [(0.12, 0.06, -0.02), (0.26, 0.10, -0.12), (0.18, 0.09, -0.16), (0.20, 0.10, -0.26), (0.08, 0.06, -0.16)],
             'ascy', 'asglow2')
    gem('chest', 'asgem', (0, 0.16, 1.32), (0, 1, 0), 0.035, 0.08)                     # 翼根的晶核
    for sx in (1, -1):                                    # 肩帶：混搭沒有上衣時，翅膀才不像浮在背後
        obox('chest', 'as1', (0.12 * sx, 0.0, 1.475), (0.022, 0.14, 0.01), w=0.004)
        cyl('chest', 'asglow', (0.12 * sx, -0.14, 1.44), 0.014, 0.008, (0, -1, 0), 12)

# ---------- 星核啞鈴：兩頭是晶藍星球＋斜的粉色行星環 ----------
if want('bell', 'astral'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'as1', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.12 * sy, 0))
            ellipsoid(f'hand.{s}', 'ascrys', c, (0.06, 0.06, 0.06))
            ring(f'hand.{s}', 'aspk', c, 0.085, 0.008, (0.5, 0.35 * sy, 1))
            star(f'hand.{s}', 'asglow', c + Vector((0, 0.064 * sy, 0)), (0, sy, 0), 0.026, 0.011, 0.008)
