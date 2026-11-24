# 動作批次：休息頁（組間休息的待機動畫）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡 docs/3d-moves/rest.md。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   angles＝動作卡「關鍵關節角度」的範圍（clipbatch.py 判定；範圍照卡片，不照量到的值）。
MOVE_META = {
    'breathe': {'angles': {'knee': (160, 180), 'elbow': (55, 125), 'trunk_lean': (0, 9)}},
    'drink': {'angles': {'knee': (160, 180), 'elbow.R': {'min': (60, 90), 'max': (100, 130)}, 'elbow.L': (55, 125), 'trunk_lean': (0, 8)}},
    'ready': {'angles': {'knee': (145, 175), 'elbow': (75, 115), 'trunk_lean': (5, 18)}},
}

# 三個動作共用的站姿：雙腳與髖同寬、膝蓋微彎、腳釘在地板上。先擺軀幹（trunk）再擺腿（子骨頭相對父骨頭算）。
def _rs_stand(hip_z, lam_h, lam_c, lam_hd, back=0.0, width=0.14, ankle_w=None):
    """back＝髖往後坐多少（腳踝固定在 y＝0.01，髖往 +Y 移）"""
    aw = width if ankle_w is None else ankle_w
    hm = Vector((0, back, hip_z))
    cp, sh = trunk(hm + Vector((0, 0, 0.04)), lam_h, lam_c, lam_hd)
    for s, sx in SX:
        leg_to(s, Vector((width * sx, back, hip_z)), Vector((aw * sx, 0.01, 0.11)), Vector((0.12 * sx, -1, 0)))
    return hm, cp, sh

def _rs_hip_hand(s, sx, sh, hm, flare=0.0, y=-0.015):
    """叉腰：拳頭貼在髖骨上緣外側（手腕在髖中心上方 10 cm、左右 0.205），手指往下往內。flare＝手肘再往外多少（只影響 pole）"""
    wrist = hm + Vector((0.235 * sx, y, 0.21))
    arm_to(s, sh[s], wrist, Vector((sx * (1.0 + flare), 0.35, 0.1)), Vector((-0.30 * sx, -0.20, -0.90)))

# ======================= 深呼吸 =======================
# 站姿、雙手叉腰。吸氣：胸口打開（上身略往後挺）、膝蓋微微伸直把整個人頂高 1 cm、頭略抬、手肘往外一點；吐氣反過來。
if MOVE == 'breathe':
    N = 48
    def pose(t):
        hip_z = 0.930 + 0.012 * t
        lam_c = D(3) - D(7) * t
        hm, cp, sh = _rs_stand(hip_z, lam_c * 0.5, lam_c, D(5) - D(10) * t)
        for s, sx in SX: _rs_hip_hand(s, sx, sh, hm, flare=0.5 * t)
    for f in range(N):
        sc.frame_set(f); pose(profile(f, N, 20, 5, 21)); keyall(f)
    CAM = dict(loc=(3.4, -3.4, 1.35), tgt=(0, 0, 1.0), lens=60, stage=(0, 0, 0.62))

# ======================= 喝水 =======================
# 站姿，右手（角色右邊＝x 為負）拿水壺，左手叉腰。起點：水壺在腰前直立；舉到嘴前（手臂 a 0→1），再把壺傾斜到瓶底朝上（b 0→1），
# 頭只微微後仰；放下時反過來。水壺的位置和傾斜全由手骨頭決定（key_bottle 從 hand 骨頭量握拳中心和握把軸，和三頭繩同一做法）。
if MOVE == 'drink':
    N = 48
    bottle = build_bottle()
    RS, RX_ = 'R', -1
    def mouth_pt(cp, lam_c, lam_hd):
        """嘴的位置（頭骨頭局部座標 (0, -0.14, 1.63)，跟著胸和頭轉）"""
        return cp(rest['head'][0]) + RX(lam_hd) @ (Vector((0, -0.14, 1.63)) - rest['head'][0])
    def pose(a, b):
        lam_c = D(1.5) - D(2.5) * b
        lam_hd = D(2) - D(12) * b
        hm, cp, sh = _rs_stand(0.934, lam_c * 0.5, lam_c, lam_hd)
        _rs_hip_hand('L', 1, sh, hm)
        mp = mouth_pt(cp, lam_c, lam_hd)
        phi = D(8) + D(32) * a + D(82) * b                          # 手（連壺）往上翹的角度；壺軸垂直手方向
        y = Vector((0, -math.cos(phi), math.sin(phi)))             # 手的方向
        cd = Vector((0, math.sin(phi), math.cos(phi)))             # 蓋子方向
        far = hm + Vector((-0.17, -0.30, 0.46))                     # 蓋尖：腰前、壺直立
        near = mp + Vector((-0.012, -0.030, 0.0))                   # 蓋尖：嘴前
        tip = far.lerp(mp + Vector((-0.012, -0.12, -0.02)), a).lerp(near, b)
        wrist = tip - cd * BOTTLE_CAP_TIP - y * 0.05
        arm_to(RS, sh[RS], wrist, Vector((-0.6, 0.2, -1.0)), y)
    for f in range(N):
        sc.frame_set(f); a = profile(f, N, 14, 15, 17)
        b = ease(min(1.0, max(0.0, (a - 0.72) / 0.28)))
        pose(a, b); keyall(f); key_bottle(bottle, RS, f)
    CAM = dict(loc=(3.2, -3.0, 1.55), tgt=(0, 0, 1.15), lens=62, stage=(0, 0, 0.62))

# ======================= 準備（預備姿勢＋小彈跳）=======================
# 運動員預備姿勢：雙腳與髖同寬、膝蓋約 150～160°、髖微往後坐、上身前傾約 12°、胸挺頭抬；雙拳舉在胸前。
# 48 格 3 次小彈跳（髖上下約 2.5 cm、雙腳貼地），兩拳跟著小幅度上下、左右差 1/4 拍。
if MOVE == 'ready':
    N = 48
    def pose(f):
        ph = 2 * math.pi * 3 * f / N
        hip_z = 0.919 + 0.012 * math.sin(ph)
        lam_c = D(13) + D(1.5) * math.sin(ph)
        hm, cp, sh = _rs_stand(hip_z, lam_c * 0.8, lam_c, D(2) + D(1) * math.sin(ph), back=0.03, width=0.15, ankle_w=0.16)
        for s, sx in SX:
            ps = ph + (0 if s == 'L' else math.pi / 2)
            wrist = cp((0.12 * sx, -0.30, 1.36 + 0.022 * math.sin(ps)))
            arm_to(s, sh[s], wrist, Vector((sx * 0.5, 0.45, -1.0)), Vector((-0.12 * sx, -0.35, 1.0)))
    for f in range(N):
        sc.frame_set(f); pose(f); keyall(f)
    CAM = dict(loc=(3.4, -3.4, 1.3), tgt=(0, 0, 0.98), lens=60, stage=(0, 0, 0.62))
