# 小豬系列 3D 測試版（2026-11-24 使用者臨時提的新造型）。由 hero_proto.py exec，工具函式在 gear_util.py；每個部位各自判斷 G[部位]，可以混搭。
# 主題：小豬撲滿——豬耳豬鼻帽、粉紅肚兜 T 恤＋金幣、玫瑰短褲＋捲尾巴、豬蹄靴、豬蹄手套、撲滿背包、豬臉啞鈴。
# 配色：粉 #FFB3C6、玫瑰 #E8668F、奶油 #FFE6EC、豬蹄 #6E3B47、金幣 #FFC94A。

M['pg1'] = toon('pg1', hexc('#FFB3C6'), 0.66)
M['pg2'] = toon('pg2', hexc('#E8668F'), 0.62)
M['pgcream'] = toon('pgcream', hexc('#FFE6EC'), 0.7)
M['pghoof'] = toon('pghoof', hexc('#6E3B47'), 0.55, spec=True)
M['pgnose'] = toon('pgnose', hexc('#9C3358'), 0.6)
M['pggold'] = toon('pggold', hexc('#FFC94A'), 0.55, spec=True)
M['pgbank'] = toon('pgbank', hexc('#FFD3DE'), 0.7, spec=True)    # 撲滿：陶瓷亮面，比上衣淡
M['pggolddk'] = toon('pggolddk', hexc('#D9952B'), 0.55, spec=True)

def flatcone(bone, mat, base, d, r, L, flat=0.35, roll=0.0, subd=1):
    """扁的圓錐（豬耳朵）：local Y 壓扁，roll 決定扁面朝哪邊"""
    d = Vector(d).normalized(); base = Vector(base)
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r, radius2=r * 0.12, depth=L, location=base + d * (L / 2))
    ob = bpy.context.object; ob.scale = (1, flat, 1); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    q = Vector((0, 0, 1)).rotation_difference(d)
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = q @ Matrix.Rotation(roll, 4, 'Z').to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return finish(ob, bone, mat, subd)

def curl(bone, mat, start, out, up, r=0.028, turns=2.2, L=0.06, th=0.011, n=40):
    """捲捲的豬尾巴：從 start 沿 out 往外長，繞 out 轉圈，半徑越轉越小"""
    out = Vector(out).normalized(); up = Vector(up).normalized(); side = out.cross(up); start = Vector(start)
    cu = bpy.data.curves.new('curl', 'CURVE'); cu.dimensions = '3D'
    cu.bevel_depth = th; cu.bevel_resolution = 3; cu.use_fill_caps = True
    sp = cu.splines.new('POLY'); sp.points.add(n - 1)
    for i in range(n):
        t = i / (n - 1); a = t * turns * 2 * math.pi; rr = r * (1 - 0.45 * t) * min(1.0, t * 4)
        p = start + out * (L * t) + up * (rr * math.sin(a)) + side * (rr * (1 - math.cos(a)) * 0.9)
        sp.points[i].co = (*p, 1)
    ob = bpy.data.objects.new('curl', cu); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.convert(target='MESH'); ob = bpy.context.object
    return finish(ob, bone, mat, 0)

def snout(bone, c, d, r, depth, nost=True):
    """豬鼻：玫瑰色扁圓柱＋兩個鼻孔"""
    d = Vector(d).normalized(); c = Vector(c)
    cyl(bone, 'pg2', c, r, depth, d, 24, min(0.008, r * 0.2))
    if nost:
        side = d.cross(Vector((0, 0, 1))) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        side.normalize(); up = side.cross(d)
        for k in (1, -1):
            ob = ellipsoid(bone, 'pgnose', c + d * (depth / 2) + side * (r * 0.38 * k), (r * 0.16, r * 0.16, r * 0.3))
    return c

# ---------- 豬耳豬鼻帽 ----------
if want('head', 'pig'):
    import bmesh as _bm
    ellipsoid('head', 'hair', (0, 0.015, 1.765), (0.165, 0.17, 0.135))     # 帽沿下露出的短髮
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, location=(0, 0.012, 1.768))
    ob = bpy.context.object; ob.scale = (0.168, 0.18, 0.155); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < 0.0], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    so = ob.modifiers.new('t', 'SOLIDIFY'); so.thickness = 0.01; so.offset = 1
    finish(ob, 'head', 'pg1', 1)
    # 帽緣一圈細玫瑰滾邊（比冰霜的反摺帽沿細很多，輪廓是圓頂）
    bpy.ops.mesh.primitive_torus_add(major_radius=0.172, minor_radius=0.012, major_segments=48, minor_segments=10, location=(0, 0.012, 1.772))
    ob = bpy.context.object; ob.scale = (1.0, 1.055, 1.0); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(ob, 'head', 'pg2', 0)
    # 額頭上的豬鼻
    snout('head', (0, -0.178, 1.83), (0, -1, 0.35), 0.046, 0.04)
    # 兩隻往前垂的三角耳（外粉內玫瑰）
    for sx in (1, -1):
        d = Vector((0.55 * sx, -0.3, 0.78))
        flatcone('head', 'pg1', (0.105 * sx, 0.0, 1.875), d, 0.06, 0.12, 0.33)
        flatcone('head', 'pg2', (0.105 * sx, -0.014, 1.877), d, 0.038, 0.088, 0.25)
    # 臉：眼睛、眼睛高光、眉毛（同基本款）
    for sx in (1, -1):
        ellipsoid('head', 'eye', (0.058 * sx, -0.158, 1.705), (0.036, 0.014, 0.03), (0, math.radians(-12 * sx), math.radians(-14 * sx)))
        ellipsoid('head', 'eyehi', (0.050 * sx, -0.168, 1.712), (0.011, 0.005, 0.01))
        ellipsoid('head', 'hair', (0.06 * sx, -0.15, 1.745), (0.04, 0.012, 0.010), (0, math.radians(-20 * sx), 0))

# ---------- 小豬 T 恤：粉紅短袖（塗在身體上），前面一塊奶油色圓肚皮，領口袖口玫瑰滾邊 ----------
if want('top', 'pig'):
    tk = skinbody.data.attributes['tank']
    by = skinbody.data.attributes.new('pgbelly', 'FLOAT', 'POINT')
    tr = skinbody.data.attributes.new('pgtrim', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        x, y, z = v.co
        neck, hem, sleeve = tee_parts(x, y, z)
        tee = min(neck, hem, sleeve)
        belly = (1 - math.hypot(x / 0.13, (z - 1.17) / 0.17)) * 0.08 if y < -0.02 else -1
        tk.data[i].value = tee
        by.data[i].value = min(belly, tee)
        tr.data[i].value = max(min(sleeve, 0.022 - sleeve, neck, hem), min(neck, 0.02 - neck), min(hem, 0.022 - hem, sleeve))
    mt = toon('skinpig', (0.50, 0.53, 0.58), alt=hexc('#FFB3C6'), alt_attr='tank', alt_shade=0.66)
    add_layer(mt, 'pgbelly', hexc('#FFE6EC'), 0.7)
    skinbody.data.materials[0] = add_layer(mt, 'pgtrim', hexc('#E8668F'), 0.62)
    # 胸前金幣徽章（撲滿的錢）
    cyl('chest', 'pggold', (0.085, -0.112, 1.37), 0.032, 0.012, (0.3, -1, 0), 24, 0.004)
    cyl('chest', 'pggolddk', (0.087, -0.118, 1.37), 0.02, 0.004, (0.3, -1, 0), 24)

# ---------- 小豬短褲：玫瑰色（hero_proto 換短褲材質），屁股後面一條捲尾巴 ----------
if want('bottom', 'pig'):
    if not LEAN_BACK:   # 背靠椅背的動作尾巴會戳進椅背，示範時隱藏（同背部裝備）
        curl('hips', 'pg1', (0, 0.115, 1.0), (0, 1, 0.5), (1, 0, 0), r=0.04, turns=1.8, L=0.11, th=0.014)
    # 褲管口一圈粉色反摺：塗在短褲上（另做硬環的話，伏地挺身雙腿併攏時左右會互卡）
    zs = {1: min(v.co.z for v in shorts.data.vertices if v.co.x > 0), -1: min(v.co.z for v in shorts.data.vertices if v.co.x < 0)}
    cf = shorts.data.attributes.new('pgcuff', 'FLOAT', 'POINT')
    for i, v in enumerate(shorts.data.vertices):
        cf.data[i].value = (zs[1 if v.co.x > 0 else -1] + 0.04 - v.co.z) if v.co.z < 0.9 else -1
    mshort = toon('pgshorts2', hexc('#E8668F'), 0.6, alt=hexc('#FFB3C6'), alt_attr='pgcuff', alt_shade=0.66)
    shorts.data.materials[0] = mshort
    # 短褲底下的身體從 0.72 起塗成短褲色，會露出在褲管最下緣 → 身體那段也要塗反摺，否則反摺被蓋住
    zc = min(zs.values()) + 0.04
    cb = skinbody.data.attributes.new('pgcuff', 'FLOAT', 'POINT')
    for i, v in enumerate(skinbody.data.vertices):
        cb.data[i].value = (zc - v.co.z) if 0.7 < v.co.z < 0.9 else -1
    skinbody.data.materials[2] = mshort

# ---------- 豬蹄靴（粉色短靴，前端是分成兩瓣的深色豬蹄） ----------
if want('feet', 'pig'):
    for s, sx in (('L', 1), ('R', -1)):
        x = 0.12 * sx; fb = f'foot.{s}'
        shell(fb, 'pg1', [(x - 0.064, -0.12, 0.03), (x + 0.064, -0.12, 0.03), (x + 0.064, 0.085, 0.03), (x - 0.064, 0.085, 0.03),
                          (x - 0.054, -0.09, 0.12), (x + 0.054, -0.09, 0.12), (x + 0.058, 0.075, 0.14), (x - 0.058, 0.075, 0.14)], 0.03)
        cyl(fb, 'pg2', (x, 0.02, 0.155), 0.07, 0.045, n=20, w=0.012, r2=0.074)          # 毛絨感玫瑰靴口
        for k in (1, -1):                                                              # 兩瓣豬蹄
            ellipsoid(fb, 'pghoof', (x + 0.029 * k, -0.125, 0.05), (0.03, 0.042, 0.036), (math.radians(-15), 0, math.radians(8 * k)))
        obox(fb, 'pghoof', (x, -0.04, 0.018), (0.068, 0.13, 0.014), w=0.008)            # 鞋底
        cyl(fb, 'pggold', (x + 0.064 * sx, 0.0, 0.085), 0.022, 0.01, (sx, 0, 0), 20, 0.003)   # 腳踝外側金幣鈕

# ---------- 豬蹄手套（粉色圓手套，指尖是兩瓣深色豬蹄） ----------
if want('hands', 'pig'):
    for s, sx in (('L', 1), ('R', -1)):
        e, w_ = B[f'forearm.{s}']; d = w_ - e
        cyl(f'forearm.{s}', 'pg2', w_ - d * 0.12, 0.056, d.length * 0.2, d, 20, 0.012)   # 圓滾滾袖口
        h = B[f'hand.{s}'][0]
        ellipsoid(f'hand.{s}', 'pg1', h + Vector((0, 0, -0.06)), (0.05, 0.062, 0.058))
        for k in (1, -1):
            ellipsoid(f'hand.{s}', 'pghoof', h + Vector((0, 0.026 * k, -0.11)), (0.046, 0.028, 0.032))

# ---------- 撲滿背包（橫躺的小豬撲滿：鼻子朝左、捲尾巴朝右、背上投幣孔插著金幣） ----------
if want('back', 'pig'):
    C = Vector((0, 0.232, 1.27))   # 前緣 y≈0.127 貼著背（0.125）；離太遠伏地挺身側面會看到浮空
    ellipsoid('chest', 'pgbank', C, (0.165, 0.105, 0.12))
    ellipsoid('chest', 'pg2', (0, 0.15, 1.27), (0.13, 0.035, 0.125))      # 背墊：填掉蛋形撲滿和背之間的空隙（側面看才不像浮著）
    snout('chest', C + Vector((0.165, 0, 0.0)), (1, 0, 0), 0.05, 0.05)
    for k in (1, -1):
        ellipsoid('chest', 'eye', C + Vector((0.12, 0.072 * k, 0.045)), (0.012, 0.012, 0.016))
        flatcone('chest', 'pgbank', C + Vector((0.09, 0.05 * k, 0.095)), (0.45, 0.35 * k, 1), 0.04, 0.075, 0.33, roll=math.pi / 2)
        for xx in (0.09, -0.09):                                                       # 四隻小短腳
            cyl('chest', 'pgbank', C + Vector((xx, 0.045 * k, -0.115)), 0.028, 0.05, (0, 0, -1), 16, 0.008)
            cyl('chest', 'pghoof', C + Vector((xx, 0.045 * k, -0.145)), 0.028, 0.014, (0, 0, -1), 16, 0.004)
    curl('chest', 'pgbank', C + Vector((-0.16, 0, 0.01)), (-1, 0, 0.2), (0, 0, 1), r=0.022, turns=2.0, L=0.05, th=0.009)
    obox('chest', 'pghoof', C + Vector((0, 0, 0.118)), (0.045, 0.01, 0.012), w=0.004)   # 投幣孔
    cyl('chest', 'pggold', C + Vector((0, 0, 0.142)), 0.036, 0.01, (0, 1, 0), 24, 0.003)  # 插一半的金幣
    cyl('chest', 'pggolddk', C + Vector((0, -0.006, 0.148)), 0.022, 0.002, (0, 1, 0), 24)
    for sx in (1, -1):   # 肩帶：肩上一段、胸前一段
        obox('chest', 'pg2', (0.115 * sx, 0.0, 1.462), (0.024, 0.11, 0.01), (0.25 * sx, 0, 1), 0.006)
        obox('chest', 'pg2', (0.12 * sx, -0.112, 1.39), (0.022, 0.008, 0.09), (0, 0, 1), 0.004)
        cyl('chest', 'pggold', (0.12 * sx, -0.122, 1.31), 0.016, 0.008, (0, -1, 0), 16)

# ---------- 豬臉啞鈴（兩頭是圓滾滾的豬臉，握把是金色） ----------
if want('bell', 'pig'):
    for s, sx in (('L', 1), ('R', -1)):
        hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
        cyl(f'hand.{s}', 'pggold', hc, 0.018, 0.30, (0, 1, 0), 12)
        for sy in (1, -1):
            c = hc + Vector((0, 0.125 * sy, 0)); dy = Vector((0, sy, 0))
            cyl(f'hand.{s}', 'pg1', c, 0.082, 0.065, dy, 28, 0.022)                    # 圓臉
            snout(f'hand.{s}', c + dy * 0.038, dy, 0.032, 0.02)
            for k in (1, -1):
                ellipsoid(f'hand.{s}', 'eye', c + dy * 0.033 + Vector((0.038 * k, 0, 0.03)), (0.009, 0.005, 0.012))
                flatcone(f'hand.{s}', 'pg2', c + Vector((0.048 * k, 0, 0.06)), (0.6 * k, 0, 1), 0.026, 0.05, 0.4)
