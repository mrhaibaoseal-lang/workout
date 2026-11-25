# 霓虹系列（史詩）3D 測試版。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：賽博夜跑——環繞式發光護目鏡＋耳機天線、長袖緊身衣（青／洋紅電路紋）、深色長褲＋發光側線、膝燈、
#       低筒發光跑鞋、發光指節手套、分段能量背環、八角發光啞鈴。
# 配色（GearCatalog）：c1 #141A24 深夜藍黑、c2 #19E3FF 青、c3 #FF3DCB 洋紅、glow #19E3FF。

M['ne1'] = toon('ne1', hexc('#222B3A'), 0.6)                     # 比 c1 亮一點，兩階明暗才看得出來
M['nemetal'] = toon('nemetal', hexc('#3A4556'), 0.55, spec=True)
M['ne2'] = flat('ne2', hexc('#19E3FF'), 3.0)
M['ne3'] = flat('ne3', hexc('#FF3DCB'), 3.0)

# ---------- 環繞式護目鏡：深色鏡框＋中間一條青光、兩側耳機（洋紅燈圈）、左耳天線 ----------
if want('head', 'neon'):
    hair_lite()
    HC = (0, -0.01, 1.70)
    cap_shell('head', 'ne1', HC, (0.166, 0.176, 0.196), lambda x, y, z: abs(z - 1.706) < 0.036 and y < 0.03, 0.012)
    cap_shell('head', 'ne2', HC, (0.179, 0.189, 0.209), lambda x, y, z: abs(z - 1.709) < 0.011 and y < -0.04, 0.004)
    face_lite(brow_tilt=-22)
    for sx in (1, -1):
        cyl('head', 'ne1', (0.172 * sx, 0.012, 1.70), 0.045, 0.034, (sx, 0, 0), 16, 0.006)
        cyl('head', 'ne3', (0.19 * sx, 0.012, 1.70), 0.03, 0.006, (sx, 0, 0), 16)
        cyl('head', 'nemetal', (0.194 * sx, 0.012, 1.70), 0.016, 0.006, (sx, 0, 0), 12)
    cyl('head', 'nemetal', (0.192, 0.03, 1.79), 0.006, 0.13, (0.3, 0.15, 1), 8)             # 天線
    blob('head', 'ne2', (0.212, 0.04, 1.853), (0.013, 0.013, 0.013), seg=8, ring=6)

# ---------- 長袖緊身衣：塗在身體上（深色、到手腕），正面兩組電路紋（青、洋紅）、背後脊椎電路、手臂外側青線；
#            電路端點和胸前六角核心是發光零件 ----------
if want('top', 'neon'):
    CY = [[(0.045, 0.99), (0.045, 1.2), (0.10, 1.27), (0.10, 1.40)]]                  # 正面青（左右對稱）
    MG = [[(0.14, 0.99), (0.14, 1.11), (0.172, 1.16), (0.172, 1.30)]]                   # 正面洋紅
    BK = [[(0.0, 0.99), (0.0, 1.46)], [(0.0, 1.22), (0.12, 1.30), (0.12, 1.42)], [(0.0, 1.10), (0.10, 1.16)]]   # 背後青
    tk = skinbody.data.attributes['tank']
    cy = skinbody.data.attributes.new('necy', 'FLOAT', 'POINT')
    mg = skinbody.data.attributes.new('nemg', 'FLOAT', 'POINT')
    ua = B['upper_arm.L']; fa = B['forearm.L']
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co; ax = abs(x)
        neck, hem, sl = sleeve_paint(x, y, z, 0.55)
        tee = min(neck, hem, sl)
        tk.data[i].value = tee
        if ax < 0.215:
            c_ = max(seg_field(ax, z, p, 0.008) for p in (CY if y < 0 else BK))
            m_ = max(seg_field(ax, z, p, 0.008) for p in MG) if y < 0 else -1
        else:                                                         # 手臂外側一條青線（跟著手臂軸）
            a_, b_ = (ua[0], ua[1]) if z > ua[1].z else (fa[0], fa[1])
            t = max(0.0, min(1.0, (z - a_.z) / (b_.z - a_.z)))
            cx, cy_ = a_.x + (b_.x - a_.x) * t, a_.y + (b_.y - a_.y) * t
            ang = abs(math.atan2(y - cy_, ax - cx))
            c_ = (0.22 - ang) * 0.04 if z < 1.40 else -1
            m_ = -1
        cy.data[i].value = min(c_, tee); mg.data[i].value = min(m_, tee)
    mt = toon('skin_neon', (0.50, 0.53, 0.58), alt=hexc('#222B3A'), alt_attr='tank', alt_shade=0.6)
    add_layer(mt, 'necy', hexc('#19E3FF'), 0.8)
    skinbody.data.materials[0] = add_layer(mt, 'nemg', hexc('#FF3DCB'), 0.8)
    for sx in (1, -1):                                                # 電路端點（發光小圓點）
        for (px, pz), mat in (((0.10, 1.40), 'ne2'), ((0.172, 1.30), 'ne3')):
            cyl('chest', mat, (px * sx, torso_y(px, pz) - 0.002, pz), 0.014, 0.01, (0.35 * sx, -1, 0), 12)
        cyl('chest', 'ne2', (0.12 * sx, torso_y(0.12, 1.42, True) + 0.002, 1.42), 0.013, 0.01, (0.3 * sx, 1, 0), 12)
    cz = 1.33
    cyl('chest', 'nemetal', (0, torso_y(0, cz) - 0.004, cz), 0.034, 0.016, (0, -1, 0), 6, 0.003)   # 胸前六角核心
    cyl('chest', 'ne3', (0, torso_y(0, cz) - 0.013, cz), 0.02, 0.006, (0, -1, 0), 6)

# ---------- 霓虹長褲：深色、外側一條青色發光線，膝蓋洋紅膝燈、褲管口青光環 ----------
if want('bottom', 'neon'):
    st = shorts.data.attributes.new('nestripe', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        x, y, z = v.co
        if z > 0.97: st.data[i].value = -1; continue
        sx = 1 if x > 0 else -1
        st.data[i].value = (0.13 - abs(math.atan2(y, (x - 0.12 * sx) * sx))) * 0.05
    shorts.data.materials[0] = toon('pants_neon2', hexc('#222B3A'), 0.6, alt=hexc('#19E3FF'), alt_attr='nestripe', alt_shade=0.8)
    for s, sx in (('L', 1), ('R', -1)):
        k, an = B[f'shin.{s}']; d2 = an - k
        cyl(f'shin.{s}', 'nemetal', k + Vector((0, -0.079, 0.0)), 0.034, 0.016, (0, -1, 0), 16, 0.004)   # 膝燈
        cyl(f'shin.{s}', 'ne3', k + Vector((0, -0.088, 0.0)), 0.022, 0.006, (0, -1, 0), 16)
        cyl(f'shin.{s}', 'nemetal', an + Vector((0, 0, 0.055)), 0.057, 0.04, d2, 16, 0.006)              # 褲管束口
        cyl(f'shin.{s}', 'ne2', an + Vector((0, 0, 0.072)), 0.0585, 0.008, d2, 16)                       # 青光環

# ---------- 發光跑鞋：低筒、厚鞋底一圈洋紅光帶、側面青色斜線、後跟發光氣墊 ----------
if want('feet', 'neon'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'ne1', [(x - 0.064, -0.2, 0.03), (x + 0.064, -0.2, 0.03), (x + 0.064, 0.08, 0.03), (x - 0.064, 0.08, 0.03),
                          (x - 0.046, -0.12, 0.085), (x + 0.046, -0.12, 0.085), (x + 0.056, 0.06, 0.13), (x - 0.056, 0.06, 0.13)], 0.03)
        cyl(fb, 'ne1', (x, 0.02, 0.135), 0.057, 0.04, n=16, w=0.006)                                 # 低筒口
        cyl(fb, 'ne3', (x, 0.02, 0.156), 0.0585, 0.006, n=16)
        obox(fb, 'nemetal', (x, -0.06, 0.02), (0.07, 0.15, 0.024), w=0.01)                           # 厚鞋底
        obox(fb, 'ne3', (x, -0.06, 0.024), (0.0718, 0.147, 0.006), w=0)                              # 鞋底光帶
        for k_, yy in ((0, -0.03), (1, -0.075)):                                                     # 側面兩條青色斜線
            obox(fb, 'ne2', (x + (0.058 - 0.004 * k_) * sx, yy, 0.07), (0.003, 0.006, 0.042), (0, -0.75, 0.66), 0)
        blob(fb, 'ne2', (x, 0.075, 0.05), (0.034, 0.02, 0.022), seg=10, ring=6)                       # 後跟氣墊

# ---------- 電光手套：深色手套、外側發光指節條、洋紅腕環 ----------
if want('hands', 'neon'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'ne1', w_ - d * 0.15, 0.052, d.length * 0.22, d, 16, 0.006, r2=0.057)
        cyl(f'forearm.{s}', 'ne3', w_ - d * 0.05, 0.0585, 0.008, d, 16)
        h = B[f'hand.{s}'][0]
        box(f'hand.{s}', 'ne1', h + Vector((0, 0, -0.065)), (0.046, 0.064, 0.058))
        obox(f'hand.{s}', 'nemetal', h + Vector((0.046 * sx, 0, -0.078)), (0.008, 0.056, 0.016), w=0.005)
        obox(f'hand.{s}', 'ne2', h + Vector((0.054 * sx, 0, -0.078)), (0.003, 0.05, 0.006), w=0)

# ---------- 能量背環：背後一個分成 8 段的青色光環，中間洋紅核心，四根細支架 ----------
if want('back', 'neon'):
    C = Vector((0, 0.175, 1.29)); R = 0.205
    cyl('chest', 'nemetal', (0, 0.128, 1.29), 0.05, 0.035, (0, 1, 0), 16, 0.008)                 # 背上底座
    cyl('chest', 'ne3', (0, 0.15, 1.29), 0.026, 0.012, (0, 1, 0), 16)
    for k in range(8):
        a0 = 2 * math.pi * k / 8 + 0.1; a1 = 2 * math.pi * (k + 1) / 8 - 0.1
        ring_arc('chest', 'ne2', C, R, a0, a1, 0.011, n=6)
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p0 = Vector((0, 0.14, 1.29)); p1 = C + Vector((R * math.cos(a), 0, R * math.sin(a)))
        obox('chest', 'nemetal', (p0 + p1) / 2, (0.006, 0.006, (p1 - p0).length / 2), p1 - p0, 0)

# ---------- 霓虹啞鈴：八角柱鈴頭、中間一圈青光、外側洋紅端蓋 ----------
if want('bell', 'neon'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'nemetal', hc, 0.017, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.115 * sy, 0))
            cyl(f'hand.{s}', 'ne1', c, 0.074, 0.085, (0, 1, 0), 8, 0.014)
            cyl(f'hand.{s}', 'ne2', c, 0.0765, 0.012, (0, 1, 0), 8)
            cyl(f'hand.{s}', 'ne3', c + Vector((0, 0.044 * sy, 0)), 0.032, 0.006, (0, 1, 0), 8)
