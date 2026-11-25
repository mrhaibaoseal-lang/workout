# 器材：健身房器械（腿推機、腿伸展機、腿後彎舉機、輔助引體機、胸推機、肩推機、反向飛鳥機）。負責：Claude（動作）。每次都會載入，只定義函式。
# 使用者沒有這些機器，動作庫有 → 只做示範，卡片標「健身房動作」。畫成簡化的機器：底座、座墊、靠背、配重塊、槓桿臂；不畫商標。
# 人面向 -Y，髖關節在 H。移動的握把／踏板由動作檔照手腳位置每格擺（父物件叫 bar：clipcheck 不算手握東西的穿透）。

def mach_seat(H, back_deg, seat_front=-0.30, back_gap=0.12, back_h=0.62, stack_y=0.62, stack_h=0.9):
    """座墊（髖下）＋靠背（離垂直往後倒 back_deg，貼在脊椎後面 back_gap）＋底座＋後方配重塊。回傳 (dv 靠背往上方向, nv 靠背朝前法線)"""
    a = D(back_deg or 0); dv = Vector((0, math.sin(a), math.cos(a))); nv = Vector((0, -math.cos(a), math.sin(a)))
    zs = H.z - 0.085                                                                   # 座墊上面
    pbox('pad', (0, (seat_front + 0.14) / 2 + H.y * 0.5, zs - 0.035), (0.20, (0.14 - seat_front) / 2, 0.035), 0.025)
    if back_deg is not None: pori('pad', Vector((0, H.y, H.z)) + dv * (back_h / 2 + 0.02) - nv * (back_gap + 0.04), (0.19, 0.04, back_h / 2), dv, 0.025)
    pbox('frame', (0, H.y + 0.05, 0.03), (0.30, 0.50, 0.03), 0.01)                     # 底座（前後長）
    pbox('frame', (0, H.y + 0.05, 0.03), (0.30, 0.04, 0.03), 0.01)
    tube((0, H.y - 0.05, 0.05), (0, H.y - 0.05, zs - 0.07), 0.03)                      # 座墊支柱
    if back_deg is not None: tube((0, H.y + 0.30, 0.05), Vector((0, H.y, H.z)) + dv * 0.20 - nv * (back_gap + 0.09), 0.03)   # 靠背斜撐
    for sx in (1, -1): pbox('rubber', (0.30 * sx, H.y + 0.05, 0.008), (0.04, 0.52, 0.008), 0.003)
    mach_stack(stack_y, stack_h)
    return dv, nv

def mach_stack(y, h):
    """後方配重塊：立柱＋疊起來的配重片（兩片亮色代表選了的重量）"""
    pbox('frame', (0, y + 0.10, h / 2), (0.19, 0.03, h / 2), 0.008)
    for sx in (1, -1): pbox('frame', (0.17 * sx, y, h / 2), (0.02, 0.10, h / 2), 0.006)
    for i in range(7):
        pbox('plate', (0, y, 0.15 + i * 0.075), (0.15, 0.085, 0.032), 0.006)
    pcyl('red', (0, y - 0.09, 0.15 + 2 * 0.075), 0.012, 0.06, (0, 1, 0), n=8)

def mach_handle(rad=0.019, length=0.13):
    """握把（包膠，跟著手）＋兩條接到槓桿樞軸的細管（世界座標）：回傳 dict(root=握把父物件, tubes=[兩條 stretch])。兩個父物件都叫 bar。"""
    root = bpy.data.objects.new('bar', None); sc.collection.objects.link(root)
    pcyl('rubber', (0, 0, 0), rad, length, (0, 0, 1), n=12).parent = root
    st = bpy.data.objects.new('bar', None); sc.collection.objects.link(st)
    tubes = [stretch('frame', 0.016) for _ in (0, 1)]
    for t_ in tubes: t_.parent = st
    root.rotation_mode = 'QUATERNION'
    return dict(root=root, tubes=tubes)

def key_handle(h, f, s, pivots, grip_len=0.13):
    """握把擺到 s 邊的手上（握把軸＝手的 z 軸），兩條管子從握把兩端接到槓桿樞軸 pivots=(P1,P2)。要在 keyall 之後呼叫。回傳握拳中心。"""
    G, hz = hand_grip_frame(s)
    h['root'].location = G; h['root'].rotation_quaternion = Vector((0, 0, 1)).rotation_difference(hz)
    h['root'].keyframe_insert('location', frame=f); h['root'].keyframe_insert('rotation_quaternion', frame=f)
    for t_, p_, e_ in zip(h['tubes'], pivots, (G + hz * grip_len / 2, G - hz * grip_len / 2)):
        key_stretch(t_, Vector(p_), e_, f)
    return G
