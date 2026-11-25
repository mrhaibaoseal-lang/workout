# 冰霜系列（史詩）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：冰晶毛帽、冰柱領 T 恤、冰裂紋長褲、冰刀鞋、冰晶手套、冰柱披肩＋冰晶立領、冰塊啞鈴。
# 配色（GearCatalog）：c1 #DDF4FF 淡冰藍、c2 #4FB8FF 冰藍、c3 #FFFFFF 白、glow #8FDBFF。

M['fr1'] = toon('fr1', hexc('#DDF4FF'), 0.62)
M['fr2'] = toon('fr2', hexc('#4FB8FF'), 0.6)
M['fr3'] = toon('fr3', hexc('#F4F8FC'), 0.66)
M['frice'] = toon('frice', hexc('#9FE0FF'), 0.55, spec=True)      # 冰晶：亮面硬邊高光
M['frblade'] = toon('frblade', hexc('#C9D1DA'), 0.5, spec=True)   # 冰刀鋼
M['frglow'] = flat('frglow', hexc('#8FDBFF'), 3.0)

def crystal(bone, mat, base, d, r, L):
    """六角冰晶：柱身＋尖頂"""
    d = Vector(d).normalized(); base = Vector(base)
    cyl(bone, mat, base + d * (L * 0.35), r, L * 0.7, d, 6, 0.0)
    cyl(bone, mat, base + d * (L * 0.85), r, L * 0.3, d, 6, 0.0, r2=0.0)

# ---------- 冰晶毛帽 ----------
if want('head', 'frost'):
    import bmesh as _bm
    hair_lite(False)                                                         # 帽沿下露出的短髮
    # 帽身：半顆橢球，只留帽沿以上
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=(0, 0.012, 1.775))
    ob = bpy.context.object; ob.scale = (0.166, 0.178, 0.15); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.0], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = 0.01; so.offset = 1
    finish(ob, 'head', 'fr2', 1)
    # 反摺帽沿（白）：一圈厚的、平順的反摺
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=0.192, depth=0.062, location=(0, 0.012, 1.79))
    ob = bpy.context.object; ob.scale = (1.0, 1.06, 1.0); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bv = ob.modifiers.new('b', 'BEVEL'); bv.width = 0.02; bv.segments = 4
    finish(ob, 'head', 'fr3', 0)
    # 帽沿正面的雪花徽章
    cyl('head', 'frice', (0, -0.205, 1.79), 0.026, 0.012, (0, -1, 0), 6, 0.003)
    cyl('head', 'fr2', (0, -0.213, 1.79), 0.013, 0.006, (0, -1, 0), 6)
    # 頂上一叢冰晶（取代毛球）
    for d, L, r in (((0, 0.05, 1), 0.17, 0.036), ((0.6, 0.15, 1), 0.12, 0.028), ((-0.55, -0.2, 1), 0.115, 0.027), ((-0.15, 0.65, 1), 0.10, 0.024)):
        crystal('head', 'frice', (0, 0.015, 1.895), d, r, L)
    # 臉：眼睛、眼睛高光、眉毛（同基本款）
    face_lite()

# ---------- 冰霜 T 恤：塗在身體上（短袖＋圓領），肩頸是冰柱垂下的冰藍色 ----------
if want('top', 'frost'):
    tk = skinbody.data.attributes['tank']
    fr = skinbody.data.attributes.new('frst', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sleeve = tee_parts(x, y, z)
        tee = min(neck, hem, sleeve)
        a = math.atan2(x, -y)                                         # 0＝正前方
        drip = max(0.0, 1 - abs(2 * ((a * 9 / (2 * math.pi)) % 1.0) - 1) * 1.7)
        yoke = min(z - (1.405 - 0.075 * drip), tee)                   # 冰柱垂下的肩頸
        cuff = min(sleeve, 0.022 - sleeve, neck, hem)                      # 袖口滾邊
        collar = min(neck, 0.018 - neck)                              # 領口滾邊
        tk.data[i].value = tee
        fr.data[i].value = max(yoke, cuff, collar)
    mt = toon('skintee', (0.50, 0.53, 0.58), alt=hexc('#DDF4FF'), alt_attr='tank', alt_shade=0.62)
    skinbody.data.materials[0] = add_layer(mt, 'frst', hexc('#4FB8FF'))
    # 胸前冰晶徽章
    cyl('chest', 'frice', (0, -0.112, 1.33), 0.036, 0.02, (0, -1, 0), 6, 0.004)
    cyl('chest', 'frglow', (0, -0.124, 1.33), 0.017, 0.008, (0, -1, 0), 6)

# ---------- 冰霜長褲：冰藍，外側一條白色冰裂紋（鋸齒） ----------
if want('bottom', 'frost'):
    fr = shorts.data.attributes.new('frst', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        if z > 0.93: fr.data[i].value = -1; continue
        sx = 1 if x > 0 else -1
        ang = abs(math.atan2(y, (x - 0.12 * sx) * sx))               # 0＝腿的正外側
        w = 0.16 + 0.16 * tri(z * 9)                                   # 冰裂鋸齒
        fr.data[i].value = (w - ang) * 0.06
    mp = toon('frpant2', hexc('#4FB8FF'), 0.6, alt=hexc('#F4F8FC'), alt_attr='frst', alt_shade=0.66)
    shorts.data.materials[0] = mp
    for s, sx in (('L', 1), ('R', -1)):
        k, an = B[f'shin.{s}']; d2 = an - k
        cyl(f'shin.{s}', 'fr3', an + Vector((0, 0, 0.065)), 0.058, 0.045, d2, 16, 0.006)   # 白色褲管口

# ---------- 冰刀鞋（高筒、鞋底下有冰刀） ----------
if want('feet', 'frost'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'fr3', [(x - 0.066, -0.19, 0.03), (x + 0.066, -0.19, 0.03), (x + 0.066, 0.085, 0.03), (x - 0.066, 0.085, 0.03),
                          (x - 0.052, -0.10, 0.12), (x + 0.052, -0.10, 0.12), (x + 0.06, 0.075, 0.15), (x - 0.06, 0.075, 0.15)], 0.028)
        cyl(fb, 'fr3', (x, 0.018, 0.175), 0.064, 0.07, n=16, w=0.008, r2=0.074)          # 高筒（上緣外擴，蹲下時小腿才有空間）
        cyl(fb, 'fr2', (x, 0.018, 0.212), 0.077, 0.014, n=16, w=0.004)                    # 筒口冰藍滾邊
        for j, (yy, zz) in enumerate(((-0.13, 0.085), (-0.085, 0.105), (-0.04, 0.125))):  # 鞋帶
            obox(fb, 'fr2', (x, yy, zz + 0.012), (0.04, 0.008, 0.006), (0, -0.45, 1), 0.003)
        obox(fb, 'fr2', (x, -0.055, 0.03), (0.07, 0.145, 0.012), w=0.008)                 # 鞋底
        for yy in (-0.13, 0.04):                                                          # 刀座
            obox(fb, 'fr2', (x, yy, 0.008), (0.014, 0.028, 0.016), w=0.004)
        obox(fb, 'frblade', (x, -0.045, -0.008), (0.006, 0.165, 0.016), w=0.003)          # 冰刀
        cyl(fb, 'frblade', (x, -0.208, 0.004), 0.02, 0.012, (1, 0, 0), 12, 0.0)           # 刀尖上翹
        obox(fb, 'frglow', (x, -0.045, -0.021), (0.0075, 0.15, 0.003), w=0)               # 刀刃發光
        crystal(fb, 'frice', (x + 0.06 * sx, 0.05, 0.14), (0.6 * sx, 0.8, 0.6), 0.016, 0.06)   # 腳踝外側冰晶

# ---------- 霜凍手套（白色厚手套、外擴袖口、指節冰晶） ----------
if want('hands', 'frost'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'fr2', w_ - d * 0.16, 0.054, d.length * 0.3, d, 16, 0.008, r2=0.072)   # 外擴袖口
        cyl(f'forearm.{s}', 'frglow', w_ - d * 0.02, 0.073, 0.006, d, 16)
        h = B[f'hand.{s}'][0]
        ellipsoid(f'hand.{s}', 'fr3', h + Vector((0, 0, -0.065)), (0.05, 0.066, 0.062))
        for yy in (-0.03, 0.0, 0.03):
            crystal(f'hand.{s}', 'frice', h + Vector((0.042 * sx, yy, -0.075)), (sx, 0, 0.25), 0.012, 0.045)

# ---------- 冰柱披肩＋冰晶立領 ----------
if want('back', 'frost'):
    # 披肩：背後一片弧面（只蓋背，不包到手臂），下緣是冰柱鋸齒
    ROWS = [(1.52, 0.10, 0.11), (1.46, 0.19, 0.15), (1.38, 0.225, 0.165), (1.27, 0.23, 0.17), (1.17, 0.215, 0.16)]
    NC = 17; PH = math.radians(62)
    vs, fs = [], []
    for r in range(len(ROWS) + 1):
        for c in range(NC):
            ph = -PH + 2 * PH * c / (NC - 1)
            if r == len(ROWS):            # 冰柱尖：偶數列垂得長
                z, rx, ry = 1.17 - (0.13 if c % 2 == 0 else 0.03), 0.21, 0.155
            else:
                z, rx, ry = ROWS[r]
            vs.append((rx * math.sin(ph), 0.005 + ry * math.cos(ph), z))
    for r in range(len(ROWS)):
        for c in range(NC - 1):
            a = r * NC + c; fs.append((a, a + 1, a + 1 + NC, a + NC))
    me = bpy.data.meshes.new('cape'); me.from_pydata(vs, [], fs); ob = bpy.data.objects.new('cape', me); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = 0.012; so.offset = 1
    finish(ob, 'chest', 'fr1', 0)
    # 背後雪花（三條交叉）
    for k in range(3):
        obox('chest', 'fr2', (0, 0.188, 1.31), (0.007, 0.065, 0.004), (0, 1, 0), 0.002, roll=k * math.pi / 3)
    cyl('chest', 'frice', (0, 0.19, 1.31), 0.018, 0.012, (0, 1, 0), 6, 0.003)
    # 立領：一排冰晶從後頸往上、往後張開
    for i in (-2, -1, 0, 1, 2):
        crystal('chest', 'frice', (0.045 * i, 0.095, 1.47 - 0.01 * abs(i)), (0.4 * i, 0.65, 1), 0.024 - 0.002 * abs(i), 0.15 - 0.025 * abs(i))
    for sx in (1, -1):   # 肩上扣環：混搭沒有上衣時，披肩才不像浮在背後
        cyl('chest', 'frglow', (0.15 * sx, -0.02, 1.47), 0.022, 0.012, (0.3 * sx, 0, 1), 6)

# ---------- 冰塊啞鈴 ----------
if want('bell', 'frost'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'fr2', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.125 * sy, 0))
            obox(f'hand.{s}', 'frice', c, (0.064, 0.064, 0.048), (0, 1, 0), 0.018, roll=0.2 * sy)   # 冰塊（方的，略轉）
            for k, rl in enumerate((0.3, 1.4)):                                                   # 裂紋
                obox(f'hand.{s}', 'fr3', c + Vector((0, 0.05 * sy, 0)), (0.004, 0.045 - 0.012 * k, 0.002), (0, 1, 0), 0, roll=rl)
            crystal(f'hand.{s}', 'fr2', c + Vector((0, 0.045 * sy, 0)), (0, sy, 0), 0.022, 0.065)  # 外側冰晶尖
