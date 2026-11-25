# 街頭系列（稀有）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：街頭籃球——反戴棒球帽、長袖帽 T（袋鼠口袋、抽繩、背後帽兜）、白色籃球褲＋藍側條、高筒籃球鞋、露指手套＋吸汗護腕、電鍍疊片啞鈴。
# GearCatalog 沒有街頭的背部和特效，所以只有 6 個部位。稀有度最低：零件最少、沒有發光。
# 配色（GearCatalog）：c1 #2F6FE0 藍、c2 #F4F5F7 白、c3 #FFCC33 黃、glow #4D8DFF。

M['sr1'] = toon('sr1', hexc('#2F6FE0'), 0.6)
M['sr2'] = toon('sr2', hexc('#F4F5F7'), 0.66)
M['sr3'] = toon('sr3', hexc('#FFCC33'), 0.62)
M['srdk'] = toon('srdk', hexc('#1D4FA8'), 0.6)                    # 深藍：帽兜內裡、口袋
M['srchrome'] = toon('srchrome', hexc('#DCE3EA'), 0.5, spec=True)  # 電鍍槓片

# ---------- 反戴棒球帽：帽舌朝後、前面調整扣露出一撮頭髮、頂上帽扣、側面黃星 ----------
if want('head', 'street'):
    import bmesh as _bm
    hair_lite(False)                                                         # 帽沿下露出的短髮
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=22, location=(0, 0.012, 1.775))
    ob = bpy.context.object; ob.scale = (0.168, 0.18, 0.148); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.0], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = 0.01; so.offset = 1
    finish(ob, 'head', 'sr1', 0)
    # 帽舌（朝後、略往下）：上黃下深藍兩片
    vs = []
    for i in range(13):
        p_ = math.radians(-72 + 144 * i / 12)
        vs += [(0.165 * math.sin(p_), 0.012 + 0.178 * math.cos(p_), 1.782),
               (0.15 * math.sin(p_), 0.012 + 0.178 * math.cos(p_) + 0.11 * math.cos(p_) ** 0.8, 1.76 - 0.03 * math.cos(p_))]
    fs = [(2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1) for i in range(12)]
    panel('head', 'sr3', vs, fs, 0.008, 0, 1)
    panel('head', 'srdk', vs, fs, 0.006, 0, -1)
    # 前面（反戴＝帽子的後面）：調整扣開口露出頭髮、白色扣帶
    blob('head', 'hair', (0, -0.176, 1.815), (0.045, 0.014, 0.03))
    obox('head', 'sr2', (0, -0.182, 1.79), (0.05, 0.006, 0.009), w=0.003)
    blob('head', 'sr1', (0, 0.012, 1.925), (0.02, 0.02, 0.011), seg=10, ring=6)                       # 頂上帽扣
    star('head', 'sr3', (0.156, -0.005, 1.83), (1, 0, 0.42), 0.032, th=0.006)                          # 左側黃星
    face_lite()

# ---------- 長袖帽 T：塗在身體上（藍色、深藍袋鼠口袋、白色袖口／下擺／領口羅紋），白抽繩、背後帽兜、胸前黃星 ----------
if want('top', 'street'):
    tk = skinbody.data.attributes['tank']
    pk = skinbody.data.attributes.new('srpocket', 'FLOAT', 'POINT')
    tr = skinbody.data.attributes.new('srtrim', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sl = sleeve_paint(x, y, z, 0.50)
        tee = min(neck, hem, sl)
        tk.data[i].value = tee
        pk.data[i].value = min(z - 1.03, 1.17 - z, 0.105 + (1.17 - z) * 0.3 - abs(x), tee) if y < -0.03 else -1
        tr.data[i].value = max(min(sl, 0.032 - sl, neck, hem), min(hem, 0.03 - hem, sl, neck), min(neck, 0.02 - neck, hem))
    mt = toon('skin_street', (0.50, 0.53, 0.58), alt=hexc('#2F6FE0'), alt_attr='tank', alt_shade=0.6)
    add_layer(mt, 'srpocket', hexc('#1D4FA8'), 0.6)
    skinbody.data.materials[0] = add_layer(mt, 'srtrim', hexc('#F4F5F7'), 0.66)
    # 抽繩：領口兩條白繩垂到胸口，末端黃色繩頭
    for sx in (1, -1):
        pts = [(0.032 * sx, torso_y(0.032, 1.465) - 0.012, 1.465), (0.036 * sx, torso_y(0.036, 1.40) - 0.012, 1.40),
               (0.04 * sx, torso_y(0.04, 1.33) - 0.012, 1.33)]
        tube('chest', 'sr2', pts, 0.0055)
        cyl('chest', 'sr3', (0.04 * sx, torso_y(0.04, 1.31) - 0.012, 1.31), 0.008, 0.03, (0, 0, 1), 8)
    # 背後帽兜：上背一團，上面開口是深藍內裡
    blob('chest', 'sr1', (0, 0.105, 1.39), (0.14, 0.082, 0.105), seg=16, ring=10)
    blob('chest', 'srdk', (0, 0.135, 1.458), (0.092, 0.044, 0.014), (math.radians(-25), 0, 0), seg=16, ring=6)
    tube('chest', 'sr2', [(0.098 * math.cos(t), 0.135 + 0.047 * math.sin(t), 1.461 - 0.021 * math.sin(t))
                          for t in (2 * math.pi * k / 20 for k in range(20))], 0.008, closed=True)          # 帽兜口白邊
    star('chest', 'sr3', (0.085, torso_y(0.085, 1.33) - 0.004, 1.33), (0.35, -1, 0), 0.03, th=0.006)

# ---------- 白色籃球褲：外側藍條、褲管口藍色寬邊（短褲網格本來就比較寬鬆） ----------
if want('bottom', 'street'):
    def _st(x, y, z, zh):
        sx = 1 if x > 0 else -1
        ang = abs(math.atan2(y, (x - 0.12 * sx) * sx))                # 0＝腿的正外側
        return max((0.30 - ang) * 0.06, zh + 0.035 - z)
    shorts_trim('srstripe', _st, 0.05)
    ms = toon('shorts_street', hexc('#F4F5F7'), 0.66, alt=hexc('#2F6FE0'), alt_attr='srstripe', alt_shade=0.6)
    shorts.data.materials[0] = ms; skinbody.data.materials[2] = ms

# ---------- 高筒籃球鞋：藍鞋身、白鞋頭、厚白鞋底＋黃中線、白色厚筒口、腳背魔鬼氈帶、腳踝黃星 ----------
if want('feet', 'street'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'sr1', [(x - 0.066, -0.19, 0.03), (x + 0.066, -0.19, 0.03), (x + 0.066, 0.085, 0.03), (x - 0.066, 0.085, 0.03),
                          (x - 0.052, -0.11, 0.11), (x + 0.052, -0.11, 0.11), (x + 0.062, 0.07, 0.15), (x - 0.062, 0.07, 0.15)], 0.028)
        blob(fb, 'sr2', (x, -0.155, 0.06), (0.062, 0.05, 0.038))                                    # 鞋頭
        cyl(fb, 'sr1', (x, 0.015, 0.185), 0.065, 0.09, n=16, w=0.008, r2=0.074)                       # 高筒
        cyl(fb, 'sr2', (x, 0.015, 0.232), 0.079, 0.02, n=16, w=0.007)                                 # 筒口厚墊
        obox(fb, 'sr2', (x, -0.055, 0.02), (0.073, 0.152, 0.024), w=0.009)                            # 厚鞋底
        obox(fb, 'sr3', (x, -0.055, 0.033), (0.0745, 0.153, 0.005), w=0)                              # 鞋底黃中線
        obox(fb, 'sr2', (x, -0.07, 0.13), (0.068, 0.022, 0.009), (0, -0.55, 1), 0.004)                # 腳背魔鬼氈帶
        for yy, zz in ((-0.135, 0.095), (-0.105, 0.11)):                                             # 鞋帶
            obox(fb, 'sr2', (x, yy, zz + 0.012), (0.038, 0.007, 0.005), (0, -0.45, 1), 0.002)
        star(fb, 'sr3', (x + 0.072 * sx, 0.02, 0.175), (sx, 0, 0), 0.033, th=0.008)                  # 腳踝外側黃星

# ---------- 露指手套＋吸汗護腕：白手套只包手掌，手指露出來；藍色魔鬼氈；黃色毛巾護腕 ----------
if want('hands', 'street'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'sr3', w_ - d * 0.17, 0.059, 0.06, d, 16, 0.012)              # 毛巾護腕（厚、圓角）
        cyl(f'forearm.{s}', 'sr1', w_ - d * 0.17, 0.0605, 0.014, d, 16)                    # 護腕藍線
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'skin', h + Vector((0, 0, -0.066)), (0.042, 0.06, 0.055))          # 手指（皮膚）
        box(f'hand.{s}', 'sr2', h + Vector((0, 0, -0.043)), (0.047, 0.065, 0.034))          # 手套（只到指根）
        obox(f'hand.{s}', 'sr1', h + Vector((0, 0, -0.024)), (0.05, 0.068, 0.011), w=0.006)  # 魔鬼氈帶

# ---------- 電鍍疊片啞鈴：每頭三片由大到小的鍍鉻槓片、藍色卡扣、黃色端蓋 ----------
if want('bell', 'street'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'grip', hc, 0.017, 0.31, (0, 1, 0), 12)
        for sy in (1, -1):
            for dy, rr, th in ((0.088, 0.088, 0.022), (0.113, 0.077, 0.022), (0.136, 0.064, 0.02)):
                cyl(f'hand.{s}', 'srchrome', hc + Vector((0, dy * sy, 0)), rr, th, (0, 1, 0), 20)
            cyl(f'hand.{s}', 'sr1', hc + Vector((0, 0.068 * sy, 0)), 0.03, 0.02, (0, 1, 0), 16, 0.004)
            cyl(f'hand.{s}', 'sr3', hc + Vector((0, 0.152 * sy, 0)), 0.024, 0.012, (0, 1, 0), 16, 0.003)
