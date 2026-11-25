# 器材：地板徒手 2 批（毛巾、椅子轉向擺放）。負責：Claude（動作）。每次都會載入，只定義函式（呼叫才建物件）。
# 角色面向 -Y、+X 是角色左邊。

PM['towel'] = toon('towel', hexc('#5AA9E6'), 0.8)

def place_bench2(back_deg, rotz_deg, offset=(0, 0, 0)):
    """呼叫 build_bench（不改它），再把新增的物件整組掛到一個轉向、平移的空物件上。回傳那個空物件"""
    before = set(bpy.data.objects)
    build_bench(back_deg)
    root = bpy.data.objects.new('benchroot', None); sc.collection.objects.link(root)
    root.rotation_euler = (0, 0, D(rotz_deg)); root.location = Vector(offset)
    for o in bpy.data.objects:
        if o not in before and o.parent is None and o is not root: o.parent = root
    return root

def build_towel():
    """一條摺好的毛巾（約 22 × 34 cm，貼地）：回傳物件，動畫只要移動它"""
    return pbox('towel', (0, 0, 0.007), (0.11, 0.17, 0.007), 0.004)
