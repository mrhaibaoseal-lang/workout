# 動作批次：姿勢（不在動作庫；給分享卡等畫面用）。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   angles＝關鍵關節角度的範圍（clipbatch.py 判定）。
MOVE_META = {
    'flex': {'angles': {'knee': (160, 180), 'elbow.L': (70, 105), 'uarm_vert.L': (75, 110),
                        'elbow.R': (55, 125), 'trunk_lean': (0, 8)}},
}

# 站姿（同 rest.py 的寫法，各批次檔分開維護）：雙腳比髖略寬、膝蓋微彎、腳釘在地板上。先擺軀幹再擺腿。
def _ps_stand(hip_z, lam_h, lam_c, lam_hd, width=0.15, ankle_w=0.17):
    hm = Vector((0, 0, hip_z))
    cp, sh = trunk(hm + Vector((0, 0, 0.04)), lam_h, lam_c, lam_hd)
    for s, sx in SX:
        leg_to(s, Vector((width * sx, 0, hip_z)), Vector((ankle_w * sx, 0.01, 0.11)), Vector((0.12 * sx, -1, 0)))
    return hm, cp, sh

def _ps_hip_hand(s, sx, sh, hm, flare=0.0):
    """扠腰：拳頭靠在髖骨上緣外側，手肘朝外。比 rest.py 的 _rs_hip_hand 往外、往上各移一點：
    分享卡會穿各系列裝備，大手套（gold 拳擊手套、pig、titan）放在原本位置會陷進腰帶和大腿。"""
    wrist = hm + Vector((0.262 * sx, -0.015, 0.235))
    arm_to(s, sh[s], wrist, Vector((sx * (1.0 + flare), 0.35, 0.1)), Vector((-0.30 * sx, -0.20, -0.90)))

def _ps_flex_arm(s, sx, sh, lift, elbow_deg, fwd):
    """秀二頭：上臂往側邊抬到約水平（lift＝高於水平幾度、fwd＝往前幾度），手肘彎 elbow_deg（內角），
    前臂朝上、拳頭往頭的方向收；二頭肌（上臂前側）朝前。直接 aim 三節（不釘手腕，鎖骨跟轉時整條手臂平移，角度不變）。"""
    u = Vector((sx * math.cos(fwd) * math.cos(lift), -math.sin(fwd) * math.cos(lift), math.sin(lift))).normalized()
    fl = Vector((0, -0.12, 1.0)); fl = (fl - u * fl.dot(u)).normalized()
    th = D(elbow_deg)
    e = sh[s] + u * blen[f'upper_arm.{s}']
    fd = -u * math.cos(th) + fl * math.sin(th)
    w = e + fd * blen[f'forearm.{s}']
    hd = (fd - u * 0.12).normalized()           # 手腕微屈（折太多拳頭會和護腕分開）
    aim(f'upper_arm.{s}', sh[s], e - sh[s]); aim(f'forearm.{s}', e, w - e); aim(f'hand.{s}', w, hd)

# ======================= 單手秀二頭 =======================
# 站姿、挺胸。左手（角色左邊＝x 為正，App 斜側鏡頭那一側，不會被身體擋住）秀二頭：上臂約水平往側邊、手肘約 90°、握拳；
# 右手扠腰。48 格無縫循環：小幅呼吸＋用力起伏（cos 波），第 24 格（中間）是最用力、姿勢最完整的時候（分享卡取這格）。
if MOVE == 'flex':
    N = 48
    def pose(t):
        lam_c = D(1) - D(4) * t                         # 用力時挺胸（略往後）
        hm, cp, sh = _ps_stand(0.930 + 0.006 * t, lam_c * 0.5, lam_c, D(2) - D(4) * t)
        _ps_flex_arm('L', 1, sh, lift=D(5) + D(4) * t, elbow_deg=88 - 12 * t, fwd=D(12))
        _ps_hip_hand('R', -1, sh, hm, flare=0.3 * t)
    for f in range(N):
        sc.frame_set(f); pose(0.5 - 0.5 * math.cos(2 * math.pi * f / N)); keyall(f)
    # App 的鏡頭（Hero3DStage：yaw −0.5、從 [0,1.2,4.6] 看 [0,0.8,0]、FOV 30°）換算到角色座標：
    # 鏡頭繞 Y 轉 +0.5 → RealityKit (2.205, 1.2, 4.037) → Blender (x, −z, y) = (2.205, −4.037, 1.2)；FOV 30° → 焦距 18/tan15° ≈ 67 mm
    CAM = dict(loc=(2.205, -4.037, 1.2), tgt=(0, 0, 0.8), lens=67.2, stage=(0, 0, 0.62))
