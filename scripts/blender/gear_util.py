# 各系列 gear_<id>.py 共用的造型工具。由 hero_proto.py 在載入系列檔之前 exec。

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


def _ramp(nt, color, shade):
    rp = nt.nodes.new('ShaderNodeValToRGB'); r = rp.color_ramp; r.interpolation = 'CONSTANT'
    r.elements[0].position = 0.0; r.elements[0].color = (*[c * shade for c in color], 1)
    r.elements[1].position = 0.18; r.elements[1].color = (*color, 1)
    e = r.elements.new(0.75); e.color = (*[min(1, c * 1.18 + 0.06) for c in color], 1)
    return rp

def add_layer(m, attr, color, shade=0.6):
    """在 toon(alt=...) 材質上再疊一層塗色：屬性 attr > 0 的地方換成 color（邊緣一樣平滑）"""
    nt = m.node_tree
    mx = [n for n in nt.nodes if n.type == 'MIX_RGB'][-1]
    em = mx.outputs['Color'].links[0].to_node
    s2r = [n for n in nt.nodes if n.type == 'SHADERTORGB'][0]
    rp = _ramp(nt, color, shade); nt.links.new(s2r.outputs['Color'], rp.inputs[0])
    at = nt.nodes.new('ShaderNodeAttribute'); at.attribute_name = attr
    gt = nt.nodes.new('ShaderNodeMath'); gt.operation = 'GREATER_THAN'; gt.inputs[1].default_value = 0.0
    nt.links.new(at.outputs['Fac'], gt.inputs[0])
    mx2 = nt.nodes.new('ShaderNodeMixRGB')
    nt.links.new(gt.outputs[0], mx2.inputs['Fac']); nt.links.new(mx.outputs['Color'], mx2.inputs['Color1'])
    nt.links.new(rp.outputs['Color'], mx2.inputs['Color2']); nt.links.new(mx2.outputs['Color'], em.inputs['Color'])
    return m

def tri(u):
    """0～1 的三角波，用來做冰柱鋸齒"""
    return 1 - abs(2 * (u % 1.0) - 1)

# 塗在身體上的短袖 T 恤形狀（冰霜、小豬共用）：回傳 (領口, 下擺, 袖口) 三個距離，都 >0 才在衣服裡
# 注意：袖口的「線」是無限延伸的平面，往下會再穿過小腿一次。用 sleeve 畫滾邊時一定要再 min(..., hem)，
# 否則小腿會被塗到（2026-11-24 小豬短褲露出來才發現）。hero_proto 會檢查，畫錯直接報錯。
_AD = Vector((0.09, -0.28)).normalized()           # 上臂方向（x, z）
def tee_parts(x, y, z):
    ax = abs(x)
    neck = (math.hypot(ax / 0.095, (z - 1.535) / 0.07) - 1) * 0.07   # 圓領
    hem = z - 0.98
    s = (ax - 0.24) * _AD.x + (z - 1.42) * _AD.y                 # 沿上臂離肩多遠
    sleeve = 0.17 - s + max(0.0, 0.235 - ax) * 6                  # 短袖袖口（軀幹上不作用）
    return neck, hem, sleeve
