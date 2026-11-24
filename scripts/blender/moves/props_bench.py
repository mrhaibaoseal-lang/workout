# 器材：使用者的多功能啞鈴椅＋高位下拉架（一體）。負責：Claude（動作）。
# 椅子、滑輪的動作都用這裡；其他人只呼叫 build_bench(角度)，要改形狀先在進度表講好。

# 角色面向 -Y。立柱在椅子前端（-Y），頂部滑輪盒；立柱兩側各兩層槓片收納柱；
# 椅子：座墊、可調靠背（角度 back_deg＝離垂直往後倒幾度）、頭枕＋把手、前端腳踝滾筒（腳勾在下面）。
# 前後兩支底座。不畫商標、不畫彈力繩（使用者不用）。
POST_Y, POST_TOP = -0.62, 2.0
SEAT_Z, SEAT_Y0, SEAT_Y1 = 0.47, -0.30, 0.13
HINGE = Vector((0, 0.15, 0.46))

def build_bench(back_deg):
    # 底座：前（立柱下）、後各一支橫腳，中間一支縱樑
    pbox('frame', (0, POST_Y, 0.03), (0.17, 0.04, 0.03), 0.008)
    pbox('frame', (0, 0.60, 0.03), (0.26, 0.04, 0.03), 0.008)
    for x_ in (-0.15, 0.15): pbox('rubber', (x_, POST_Y, 0.008), (0.03, 0.05, 0.008), 0.003)
    for x_ in (-0.24, 0.24): pbox('rubber', (x_, 0.60, 0.008), (0.03, 0.05, 0.008), 0.003)
    tube((0, POST_Y, 0.06), (0, -0.30, 0.30), 0.028)              # 前斜樑
    tube((0, -0.30, 0.30), (0, 0.15, 0.38), 0.028)               # 座下主樑
    tube((0, 0.15, 0.38), (0, 0.60, 0.06), 0.028)                # 後斜腿
    tube((0, -0.10, 0.33), (0, -0.10, SEAT_Z - 0.04), 0.022)     # 座墊支柱
    # 座墊
    pbox('pad', (0, (SEAT_Y0 + SEAT_Y1) / 2, SEAT_Z - 0.035), (0.15, (SEAT_Y1 - SEAT_Y0) / 2, 0.035), 0.025)
    # 靠背＋頭枕＋把手
    a = D(back_deg); dv = Vector((0, math.sin(a), math.cos(a))); nv = Vector((0, -math.cos(a), math.sin(a)))
    pori('pad', HINGE + dv * 0.36 + nv * 0.0, (0.15, 0.04, 0.34), dv, 0.025)
    pori('frame', HINGE + dv * 0.30 - nv * 0.05, (0.03, 0.02, 0.28), dv, 0.006)
    hr = HINGE + dv * 0.80
    pori('pad', hr + nv * 0.02, (0.13, 0.045, 0.07), dv, 0.03)
    for sx in (1, -1): tube(hr - nv * 0.03 + Vector((0.09 * sx, 0, 0)), hr - nv * 0.03 + dv * 0.13 + Vector((0.09 * sx, 0, 0)), 0.01)
    tube(hr - nv * 0.03 + dv * 0.13 + Vector((-0.095, 0, 0)), hr - nv * 0.03 + dv * 0.13 + Vector((0.095, 0, 0)), 0.012)
    # 靠背調整支架（梯形孔架）
    tube((0, 0.42, 0.21), HINGE + dv * 0.25 - nv * 0.05, 0.02)
    # 前端腳踝滾筒（兩顆）＋橫桿
    pcyl('chrome', (0, -0.53, 0.22), 0.012, 0.42, (1, 0, 0), n=12)
    tube((0, -0.53, 0.10), (0, -0.53, 0.22), 0.02)
    for sx in (1, -1): pcyl('pad', (0.12 * sx, -0.53, 0.22), 0.055, 0.17, (1, 0, 0), bevel=0.012)
    # 立柱＋頂部滑輪盒
    pbox('frame', (0, POST_Y, POST_TOP / 2), (0.032, 0.032, POST_TOP / 2), 0.006)
    pbox('frame', (0, POST_Y + 0.02, POST_TOP - 0.03), (0.05, 0.085, 0.07), 0.02)
    for sx in (1, -1): pcyl('frame', (0.05 * sx, POST_Y + 0.02, POST_TOP - 0.03), 0.07, 0.01, (1, 0, 0), n=32)
    pcyl('chrome', (0, POST_Y + 0.02, POST_TOP - 0.03), 0.02, 0.11, (1, 0, 0), n=12)
    # 配重：套在立柱上的滑套，上下各插一顆「啞鈴」（橫穿滑套的握把＋兩側槓片＋紅色星形螺帽）。
    # 拉下拉槓時整組沿立柱往上滑。回傳這組的父物件，動畫只要移動它。
    stack = bpy.data.objects.new('stack', None); sc.collection.objects.link(stack)
    own = [pbox('frame', (0, POST_Y, 0.82), (0.05, 0.05, 0.27), 0.01),            # 滑套
           pcyl('chrome', (0, POST_Y + 0.055, 1.10), 0.012, 0.035, (0, 1, 0), n=12)]  # 頂部掛鉤
    for z_ in (0.98, 0.66):
        own.append(pcyl('chrome', (0, POST_Y, z_), 0.016, 0.36, (1, 0, 0), n=12))
        for sx in (1, -1):
            for i_, x_ in enumerate((0.075, 0.105)):
                own.append(pcyl('plate', (x_ * sx, POST_Y, z_), 0.115 - i_ * 0.012, 0.028, (1, 0, 0), n=32, bevel=0.006))
            own.append(pcyl('red', (0.15 * sx, POST_Y, z_), 0.032, 0.04, (1, 0, 0), n=6, bevel=0.004))
    for o_ in own: o_.parent = stack
    return stack
