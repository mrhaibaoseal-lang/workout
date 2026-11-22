# 鈦甲系列（傳說）3D 測試版。由 hero_proto.py 在 GEAR=titan 時 exec，共用它的工具函式。
# 對照 2D：頭盔、胸甲＋腹甲＋能量核心、大腿甲＋護膝、推進靴、機械手甲、雙筒噴射背包、能量膠囊啞鈴、全像掃描。

def hard(ob, bone, mat, w=0.012, seg=2):
    if w:
        bv = ob.modifiers.new('b', 'BEVEL'); bv.width = w; bv.segments = seg; bv.limit_method = 'ANGLE'
    return finish(ob, bone, mat, 0)

def obox(bone, mat, c, size, d=(0, 0, 1), w=0.012, roll=0.0):
    """沿方向 d 擺放的方塊（local Z＝d）"""
    bpy.ops.mesh.primitive_cube_add(location=c); ob = bpy.context.object
    ob.scale = size; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    q = Vector((0, 0, 1)).rotation_difference(Vector(d))
    ob.rotation_mode = 'QUATERNION'; ob.rotation_quaternion = q @ Matrix.Rotation(roll, 4, 'Z').to_quaternion()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return hard(ob, bone, mat, w)

def cyl(bone, mat, c, r, depth, d=(0, 0, 1), n=16, w=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=depth, location=c)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=r, radius2=r2, depth=depth, location=c)
    ob = bpy.context.object; ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(d))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return hard(ob, bone, mat, w)

def shell(bone, mat, verts, w=0.03):
    """8 個頂點的硬殼（倒角，不做細分，保留機甲的硬邊）"""
    me = bpy.data.meshes.new('sh'); faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    me.from_pydata(verts, [], faces); ob = bpy.data.objects.new('sh', me); sc.collection.objects.link(ob)
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
    return hard(ob, bone, mat, w, 3)

# ---------- 頭盔 ----------
ellipsoid('head', 'ti', (0, 0.0, 1.715), (0.178, 0.188, 0.195))
def band(bone, mat, c, r, zc, half, ymax):
    """貼著頭盔曲面的一條帶子：同心橢球只留 |z-zc|<half、y<ymax 的部分"""
    import bmesh as _bm
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=48, location=c)
    ob = bpy.context.object; ob.scale = r; bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = _bm.new(); bm.from_mesh(ob.data)
    _bm.ops.delete(bm, geom=[v for v in bm.verts if abs(v.co.z + c[2] - zc) > half or v.co.y + c[1] > ymax], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
    sol_ = ob.modifiers.new('t', 'SOLIDIFY'); sol_.thickness = 0.012; sol_.offset = 1
    return finish(ob, bone, mat, 0)
band('head', 'tidk', (0, 0, 1.715), (0.181, 0.191, 0.198), 1.71, 0.042, -0.05)   # 面罩框（貼合）
band('head', 'glow', (0, 0, 1.715), (0.186, 0.196, 0.203), 1.712, 0.022, -0.09)  # 發光目鏡（貼合）
obox('head', 'tidk', (0, 0.0, 1.89), (0.014, 0.13, 0.05), w=0.008)          # 頭頂鰭
obox('head', 'glow', (0, -0.02, 1.915), (0.006, 0.09, 0.012), w=0)
for sx in (1, -1):
    cyl('head', 'tidk', (0.182 * sx, 0.01, 1.70), 0.055, 0.05, (1, 0, 0), 8, 0.006)   # 耳罩
    cyl('head', 'glow', (0.208 * sx, 0.01, 1.70), 0.025, 0.012, (1, 0, 0), 8)
    obox('head', 'ti', (0.15 * sx, -0.06, 1.80), (0.012, 0.07, 0.02), (0.3 * sx, 0, 1), w=0.005)  # 側邊天線

# ---------- 胸甲＋腹甲＋核心 ----------
shell('chest', 'ti', trap(1.20, 1.47, 0.20, 0.145, 0.285, 0.155, -0.005, 0.0))
shell('chest', 'tidk', trap(1.43, 1.50, 0.12, 0.11, 0.13, 0.10), 0.015)              # 頸圈
cyl('chest', 'tidk', (0, -0.165, 1.35), 0.062, 0.03, (0, -1, 0), 6, 0.006)            # 六角核心外框
cyl('chest', 'glow', (0, -0.18, 1.35), 0.042, 0.02, (0, -1, 0), 6)                     # 能量核心
for sx in (1, -1):
    obox('chest', 'glow', (0.14 * sx, -0.16, 1.40), (0.06, 0.005, 0.008), (0, 0, 1), 0, roll=0)  # 胸前導光條
    obox('chest', 'tidk', (0.17 * sx, -0.15, 1.27), (0.07, 0.012, 0.045), w=0.008)
for row, z in enumerate((1.165, 1.105, 1.045)):
    bone = 'chest' if z > 1.12 else 'hips'
    for sx in (1, -1):
        obox(bone, 'tidk', (0.055 * sx, -0.125 + row * 0.005, z), (0.045, 0.02, 0.025), w=0.01)
obox('hips', 'tidk', (0, -0.005, 0.99), (0.17, 0.115, 0.03), w=0.012)                  # 腰帶
obox('hips', 'glow', (0, -0.12, 0.99), (0.03, 0.006, 0.02), w=0)
for s, sx in (('L', 1), ('R', -1)):
    # 肩甲：兩層
    ellipsoid(f'upper_arm.{s}', 'ti', (0.28 * sx, 0, 1.44), (0.125, 0.125, 0.085))
    ellipsoid(f'upper_arm.{s}', 'tidk', (0.31 * sx, 0, 1.39), (0.10, 0.11, 0.06))
    obox(f'upper_arm.{s}', 'glow', (0.30 * sx, 0, 1.512), (0.05, 0.08, 0.006), w=0)

# ---------- 機械手甲 ----------
for s, sx in (('L', 1), ('R', -1)):
    e, w_ = B[f'forearm.{s}']
    d = w_ - e
    cyl(f'forearm.{s}', 'ti', e + d * 0.6, 0.064, d.length * 0.6, d, 8, 0.01, r2=0.074)
    obox(f'forearm.{s}', 'glow', e + d * 0.6 + Vector((0, -0.07, 0)), (0.008, 0.004, d.length * 0.22), d, 0)
    obox(f'forearm.{s}', 'tidk', e + d * 0.55 + Vector((0.065 * sx, 0, 0)), (0.012, 0.035, d.length * 0.2), d, 0.006)
    h = B[f'hand.{s}'][0]
    obox(f'hand.{s}', 'tidk', h + Vector((0, 0, -0.065)), (0.05, 0.068, 0.062), w=0.018)
    obox(f'hand.{s}', 'ti', h + Vector((0.035 * sx, 0, -0.06)), (0.02, 0.07, 0.05), w=0.01)   # 指節甲
    cyl(f'hand.{s}', 'glow', h + Vector((0.056 * sx, 0, -0.06)), 0.016, 0.006, (1, 0, 0), 8)

# ---------- 大腿甲＋護膝＋脛甲 ----------
for s, sx in (('L', 1), ('R', -1)):
    a, b = B[f'thigh.{s}']; d = b - a
    obox(f'thigh.{s}', 'ti', a + d * 0.55 + Vector((0.01 * sx, -0.085, 0)), (0.075, 0.03, d.length * 0.3), d, 0.02)
    obox(f'thigh.{s}', 'glow', a + d * 0.55 + Vector((0.01 * sx, -0.117, 0)), (0.008, 0.004, d.length * 0.2), d, 0)
    obox(f'thigh.{s}', 'tidk', a + d * 0.5 + Vector((0.09 * sx, 0, 0)), (0.02, 0.06, d.length * 0.25), d, 0.008)
    k, an = B[f'shin.{s}']; d2 = an - k
    ellipsoid(f'shin.{s}', 'ti', k + Vector((0, -0.07, -0.01)), (0.065, 0.04, 0.075))     # 護膝
    cyl(f'shin.{s}', 'glow', k + Vector((0, -0.112, -0.01)), 0.018, 0.008, (0, -1, 0), 8)
    obox(f'shin.{s}', 'tidk', k + d2 * 0.5 + Vector((0, -0.07, 0)), (0.055, 0.022, d2.length * 0.28), d2, 0.012)

# ---------- 推進靴 ----------
for s, sx in (('L', 1), ('R', -1)):
    x = 0.12 * sx
    shell(f'foot.{s}', 'ti', [(x - 0.075, -0.20, 0.0), (x + 0.075, -0.20, 0.0), (x + 0.075, 0.09, 0.0), (x - 0.075, 0.09, 0.0),
                              (x - 0.065, -0.12, 0.10), (x + 0.065, -0.12, 0.10), (x + 0.07, 0.08, 0.16), (x - 0.07, 0.08, 0.16)], 0.03)
    obox(f'foot.{s}', 'tidk', (x, -0.055, 0.02), (0.08, 0.15, 0.022), w=0.01)             # 厚鞋底
    obox(f'foot.{s}', 'tidk', (x, -0.17, 0.05), (0.07, 0.04, 0.045), w=0.015)            # 鞋尖蓋
    cyl(f'foot.{s}', 'tidk', (x, 0.01, 0.17), 0.072, 0.07, n=8, w=0.008)                 # 踝環
    obox(f'foot.{s}', 'glow', (x + 0.077 * sx, -0.05, 0.06), (0.003, 0.09, 0.008), w=0)  # 側邊導光條
    cyl(f'foot.{s}', 'tidk', (x, 0.105, 0.07), 0.035, 0.04, (0, 1, 0), 8, 0.005)         # 腳跟噴口
    cyl(f'foot.{s}', 'flame', (x, 0.14, 0.07), 0.026, 0.07, (0, 1, 0), 8, r2=0.0)        # 噴焰

# ---------- 雙筒噴射背包 ----------
obox('chest', 'tidk', (0, 0.18, 1.31), (0.10, 0.05, 0.13), w=0.02)
for sx in (1, -1):
    cyl('chest', 'ti', (0.10 * sx, 0.22, 1.30), 0.058, 0.30, n=12, w=0.012)
    cyl('chest', 'tidk', (0.10 * sx, 0.22, 1.47), 0.04, 0.05, n=12, r2=0.055, w=0.005)
    cyl('chest', 'tidk', (0.10 * sx, 0.22, 1.13), 0.042, 0.06, n=12, r2=0.06, w=0.005)  # 噴嘴
    obox('chest', 'glow', (0.10 * sx, 0.163, 1.30), (0.008, 0.004, 0.1), w=0)
    cyl('chest', 'glow', (0.10 * sx, 0.22, 1.03), 0.04, 0.14, (0, 0, 1), 10, r2=0.0)    # 外焰（倒錐）
    cyl('chest', 'flame', (0.10 * sx, 0.22, 1.06), 0.026, 0.09, (0, 0, 1), 10, r2=0.0)
    # 倒錐：上寬下尖
for o in parts[-4:]:
    pass
obox('chest', 'glow', (0, 0.235, 1.33), (0.04, 0.004, 0.04), w=0)

# ---------- 能量膠囊啞鈴 ----------
for s, sx in (('L', 1), ('R', -1)):
    hc = B[f'hand.{s}'][0] + Vector((0, 0, -0.07))
    cyl(f'hand.{s}', 'tidk', hc, 0.018, 0.30, (0, 1, 0), 12)
    for sy in (1, -1):
        c = hc + Vector((0, 0.125 * sy, 0))
        cyl(f'hand.{s}', 'ti', c, 0.078, 0.085, (0, 1, 0), 8, 0.012)
        cyl(f'hand.{s}', 'tidk', c + Vector((0, 0.055 * sy, 0)), 0.06, 0.03, (0, sy, 0), 8, 0.006, r2=0.04)
        cyl(f'hand.{s}', 'glow', c + Vector((0, -0.048 * sy, 0)), 0.065, 0.012, (0, 1, 0), 8)   # 發光環
        cyl(f'hand.{s}', 'glow', c + Vector((0, 0.072 * sy, 0)), 0.025, 0.01, (0, 1, 0), 8)     # 端蓋

# ---------- 全像掃描（獨立物件，不跟骨架） ----------
for i, ph in enumerate((0, 24)):
    bpy.ops.mesh.primitive_torus_add(major_radius=0.48, minor_radius=0.005, major_segments=64, location=(0, 0, 0.05))
    ring = bpy.context.object; ring.data.materials.append(M['glow'])
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=0.48, fill_type='NGON', location=(0, 0, 0))
    disc = bpy.context.object; disc.parent = ring
    dm = bpy.data.materials.new(f'holo{i}'); dm.use_nodes = True; nt = dm.node_tree; nt.nodes.clear()
    o_ = nt.nodes.new('ShaderNodeOutputMaterial'); em_ = nt.nodes.new('ShaderNodeEmission'); tr_ = nt.nodes.new('ShaderNodeBsdfTransparent')
    mx_ = nt.nodes.new('ShaderNodeMixShader'); mx_.inputs[0].default_value = 0.12
    em_.inputs['Color'].default_value = (*hexc('#31F2D4'), 1); em_.inputs['Strength'].default_value = 2
    nt.links.new(tr_.outputs[0], mx_.inputs[1]); nt.links.new(em_.outputs[0], mx_.inputs[2]); nt.links.new(mx_.outputs[0], o_.inputs[0])
    dm.blend_method = 'BLEND'; dm.shadow_method = 'NONE'; disc.data.materials.append(dm)
    for f in range(0, 49, 4):
        t = ((f + ph) % 48) / 48
        z = 0.05 + 1.9 * (t * 2 if t < 0.5 else 2 - t * 2)
        ring.location.z = z; ring.keyframe_insert('location', frame=f)
