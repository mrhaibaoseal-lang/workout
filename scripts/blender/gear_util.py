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

