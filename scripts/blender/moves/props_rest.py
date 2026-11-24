# 器材：休息頁批的水壺（drink 用）。負責：Claude（動作）。每次都會載入，但只有 build_bottle() 被呼叫時才建物件。
# 玩具公仔比例：壺身半徑 4 cm、高約 19 cm（握在拳頭裡剛好露出頭尾），藍色壺身＋白色標帶＋橘色蓋子（品牌橘）。
# 壺的局部座標：原點＝握拳中心、+Z＝瓶蓋那一端。壺身中心略高於握拳（握在壺身下半段，上面留空間給蓋子靠近嘴）。

PM['bottle'] = toon('bottle', hexc('#2E9BFF'), 0.55, spec=True)
PM['bband'] = toon('bband', hexc('#F4F6FA'), 0.6)
PM['bcap'] = toon('bcap', hexc('#FF6B35'), 0.55, spec=True)

BOTTLE_CAP_TIP = 0.165        # 握拳中心到蓋子最頂端的距離（沿壺軸）

def build_bottle():
    """水壺：回傳根物件（叫 bar：clipcheck 不算手握東西的穿透）。子物件的位置照局部座標（根在原點時建好再掛上去）"""
    root = bpy.data.objects.new('bar', None); sc.collection.objects.link(root)
    parts = [
        pcyl('bottle', (0, 0, 0.012), 0.040, 0.178, n=20, bevel=0.010),                 # 壺身
        pcyl('bband', (0, 0, -0.012), 0.0415, 0.030, n=20),                             # 標帶（握拳正上方）
        pcyl('bottle', (0, 0, 0.113), 0.028, 0.036, n=20, bevel=0.006),                 # 肩部（收窄）
        pcyl('bcap', (0, 0, 0.140), 0.030, 0.034, n=20, bevel=0.006),                   # 蓋子
        pcyl('bcap', (0, 0, 0.163), 0.013, 0.024, n=12, bevel=0.004),                   # 吸嘴
    ]
    for o_ in parts: o_.parent = root
    root.rotation_mode = 'QUATERNION'
    return root

_BOTTLE_SIGN = {}
def rest_grip_frame(s):
    """手在目前姿勢的握拳中心 G、握把軸 hz（手骨頭的 z 軸）。要在 keyall 之後呼叫（鎖骨會改變手臂）"""
    M = pb[f'hand.{s}'].matrix
    return M.translation + M.col[1].xyz.normalized() * 0.05, M.col[2].xyz.normalized()

def key_bottle(root, s, f):
    """把水壺擺到 s 手的握拳上並打影格。蓋子朝哪一端：第 0 格選「朝上」的那端，之後保持同一端（不翻面）。回傳 (握拳中心, 蓋子方向)"""
    G, hz = rest_grip_frame(s)
    if s not in _BOTTLE_SIGN: _BOTTLE_SIGN[s] = 1.0 if hz.z >= 0 else -1.0
    cd = hz * _BOTTLE_SIGN[s]
    root.location = G; root.rotation_quaternion = UP.rotation_difference(cd)
    root.keyframe_insert('location', frame=f); root.keyframe_insert('rotation_quaternion', frame=f)
    return G, cd
