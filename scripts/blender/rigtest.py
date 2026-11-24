# 骨架極限姿勢測試（BLENDER_BRIEF §6-1 第一道關卡）：MOVE=rigtest，每一格是一個姿勢，不是動作。
# 由 moves3d.py 像動作檔一樣 exec（hero_proto 會把 rigtest 加進 MOVES）。骨架、權重、身體有任何改動都要跑：
#   $env:MOVE="rigtest"; $env:QUICK="1"; blender -b -P scripts\blender\hero_proto.py -- <絕對路徑> 0 1 2 3 4 5 6
#   blender -b <絕對路徑>\hero.blend -P scripts\blender\deformcheck.py -- <絕對路徑>\deform.json 1
# 0 手舉過頭  1 側平舉 90°  2 前平舉 90°  3 手肘全彎  4 深蹲到底  5 髖鉸鏈前彎 90°  6 弓箭步（左腳在前）
RIGTEST = ['手舉過頭', '側平舉90°', '前平舉90°', '手肘全彎', '深蹲到底', '髖鉸鏈90°', '弓箭步']
N = len(RIGTEST)
HIP0 = rest['hips'][0]

def hipj(hh, lam, s):
    return hh + RX(lam) @ (rest[f'thigh.{s}'][0] - HIP0)

def stand_legs(hh, lam=0.0, knee=0.0):
    for s, sx in SX:
        an = Vector((rest[f'foot.{s}'][0].x, 0.01, 0.11))
        leg_to(s, hipj(hh, lam, s), an, Vector((0, -1, 0.2)), Vector((0, -1, -0.15)))

def arm_dir(s, sh, d_up, d_fore=None):
    e = aim(f'upper_arm.{s}', sh, d_up)
    w = aim(f'forearm.{s}', e, d_fore if d_fore is not None else d_up)
    aim(f'hand.{s}', w, d_fore if d_fore is not None else d_up)

def standing(arm):
    hh = HIP0.copy()
    _, sh = trunk(hh, 0, 0, 0)
    stand_legs(hh)
    for s, sx in SX: arm(s, sx, sh[s])

for f in range(N):
    sc.frame_set(f)
    if f == 0:   # 手舉過頭：手臂打直、略往外
        standing(lambda s, sx, sh: arm_dir(s, sh, Vector((0.18 * sx, 0.02, 1))))
    elif f == 1:   # 側平舉 90°
        standing(lambda s, sx, sh: arm_dir(s, sh, Vector((sx, -0.08, 0.0))))
    elif f == 2:   # 前平舉 90°
        standing(lambda s, sx, sh: arm_dir(s, sh, Vector((0.12 * sx, -1, 0.0))))
    elif f == 3:   # 手肘全彎：上臂貼身體、前臂往上折到底（約 145°）
        standing(lambda s, sx, sh: arm_dir(s, sh, Vector((0.08 * sx, 0.05, -1)), Vector((0.05 * sx, -0.57, 0.82))))
    elif f == 4:   # 深蹲到底：腳掌固定，大腿低於水平、軀幹前傾約 45°，手往前平衡
        lam = D(45)
        hh = Vector((0, 0.10, 0.40))
        _, sh = trunk(hh, lam * 0.8, lam, lam * 0.3)
        for s, sx in SX:
            A = Vector((rest[f'foot.{s}'][0].x * 1.2, 0.01, 0.11))
            leg_to(s, hipj(hh, lam * 0.8, s), A, Vector((0.35 * sx, -1, 0.2)), Vector((0.1 * sx, -1, -0.15)))
            arm_dir(s, sh[s], Vector((0.1 * sx, -1, 0.25)))
    elif f == 5:   # 髖鉸鏈 90°：膝蓋微彎、髖往後推、背打直到水平，手臂自然垂下
        lam = D(88)
        hh = HIP0 + Vector((0, 0.16, -0.05))
        _, sh = trunk(hh, lam * 0.85, lam, lam - D(25))
        for s, sx in SX:
            an = Vector((rest[f'foot.{s}'][0].x, -0.02, 0.11))
            leg_to(s, hipj(hh, lam * 0.85, s), an, Vector((0, -1, 0)), Vector((0, -1, -0.15)))
            arm_dir(s, sh[s], Vector((0.05 * sx, -0.15, -1)))
    elif f == 6:   # 弓箭步：左腳在前（大腿水平、小腿垂直），右膝接近地面
        hh = Vector((0, 0.02, 0.60))
        _, sh = trunk(hh, D(-4), 0, D(-4))
        hjL, hjR = hipj(hh, D(-4), 'L'), hipj(hh, D(-4), 'R')
        leg_to('L', hjL, Vector((hjL.x, hjL.y - blen['thigh.L'] * 0.97, 0.11)), Vector((0, -1, 0.3)), Vector((0, -1, -0.15)))
        leg_to('R', hjR, Vector((hjR.x, hjR.y + 0.62, 0.13)), Vector((0, -1, -0.6)), Vector((0, -0.25, -1)))
        for s, sx in SX: arm_dir(s, sh[s], Vector((0.12 * sx, 0.02, -1)))
    keyall(f)
CAM = dict(loc=(4.2, -3.9, 1.7), tgt=(0, 0, 0.9), lens=60, stage=(0, 0, 0.9))
