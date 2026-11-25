# 器材：壺鈴（kbSwing 用）。負責：Claude（動作，批次 ⑤）。每次都會載入，只定義函式。
# 壺鈴本身的座標：原點＝握把中心、握把軸＝x、壺鈴本體在 -z 方向（本體中心在 z＝-0.155）。
# 擺盪時壺鈴的本體永遠在「手臂延伸的方向」（離心力沿著手臂拉出去），所以 key_kb 把 -z 對準手臂方向。
# 所有零件都掛在同一個叫 bar 的空物件底下（clipcheck 只跳過頂層父物件名字剛好是 bar 的道具；
# 第二個空物件會被 Blender 改名 bar.001，就不被跳過 → 手握的零件全被算成撞到人）。

def kbs_root():
    o = bpy.data.objects.get('bar')
    if o is None:
        o = bpy.data.objects.new('bar', None); sc.collection.objects.link(o)
    return o

def build_kettlebell(rad=0.095):
    """壺鈴（約 12 kg 的大小）：紅色本體＋底部平面＋兩根直立握把＋上橫桿。回傳父物件 kb（要擺姿勢就動它）。"""
    kb = bpy.data.objects.new('kb', None); sc.collection.objects.link(kb); kb.parent = kbs_root()
    kb.rotation_mode = 'QUATERNION'
    zc = -0.155                                                       # 本體中心
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=14, radius=rad, location=(0, 0, zc))
    prop(bpy.context.object, 'red', True, 0.0).parent = kb
    pcyl('plate', (0, 0, zc - rad * 0.93), 0.062, 0.03, (0, 0, 1), n=20, bevel=0.004).parent = kb   # 底座平面
    for sx in (1, -1):                                                 # 兩根直立握把（接到本體頂部）
        pcyl('plate', (0.085 * sx, 0, -0.045), 0.0145, 0.10, (0, 0, 1), n=12).parent = kb
    pcyl('plate', (0, 0, 0), 0.0145, 0.20, (1, 0, 0), n=12).parent = kb                              # 上橫桿（握把）
    return kb

def key_kb(kb, f, G, d):
    """壺鈴擺好並打影格。G＝握把中心（兩手握拳中心的中點）、d＝手臂方向（壺鈴本體在這個方向）"""
    d = Vector(d).normalized()
    xv = Vector((1, 0, 0)); xv = (xv - d * xv.dot(d)).normalized()
    zv = -d; yv = zv.cross(xv)
    kb.location = G; kb.rotation_quaternion = Matrix((xv, yv, zv)).transposed().to_quaternion()
    kb.keyframe_insert('location', frame=f); kb.keyframe_insert('rotation_quaternion', frame=f)
