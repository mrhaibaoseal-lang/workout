# 動作批次：弓步／臀橋。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。動作卡：docs/3d-moves/lunge_bridge.md
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {
    # angles：動作卡 docs/3d-moves/lunge_bridge.md 的角度範圍（寫法見 scripts/blender/README.md；範圍照卡片，不照量到的值）。
    # knee.L＝前腳（登階＝踩椅子那腳）、knee.R＝後腳；{'min': (85, 100)}＝最深那格的膝角落在 85～100°。
    'lunge': {'bell': True, 'angles': {'knee.L': {'min': (85, 100), 'max': (165, 180)}, 'knee.R': {'min': (85, 115)}, 'trunk_lean': (0, 15), 'elbow': (165, 180)}},
    'splitSquat': {'bell': True, 'angles': {'knee.L': {'min': (85, 100), 'max': (165, 180)}, 'knee.R': {'min': (90, 125)}, 'trunk_lean': (0, 20), 'elbow': (165, 180)}},
    'reverseLunge': {'bell': True, 'angles': {'knee.L': {'min': (85, 100), 'max': (165, 180)}, 'knee.R': {'min': (85, 115)}, 'trunk_lean': (0, 15), 'elbow': (165, 180)}},
    'stepUp': {'bell': True, 'angles': {'knee.L': {'min': (60, 100), 'max': (165, 180)}, 'trunk_lean': (0, 25), 'elbow': (165, 180)}},
    'bridge': {'bell': True, 'lean_back': True, 'angles': {'hip': {'max': (165, 180)}, 'knee': (80, 115)}},
    'hipThrust': {'lean_back': True, 'angles': {'hip': {'max': (165, 180)}, 'knee': (65, 100), 'trunk_lean': {'min': (35, 50)}}},
}

# ---------- 這批共用 ----------
# 弓步族群：姿勢函式 lunge_pose（moves3d.py）。前腳踝釘住、前膝內角決定髖高、後腳由 rear(t, H) 決定。
# 臀橋族群：bridge_pose（moves3d.py）。上背接觸點釘住、腳踝釘住、軀幹仰角決定髖高。
# 單邊動作：左腳在前（弓步、分腿蹲）／左腳踩上去（登階），右腳在後。
N = 48
X_ = Vector((1, 0, 0)); Z_ = Vector((0, 0, 1))
def tempo(f): return profile(f, N, 22, 4, 15)       # 離心 22 格（約 2 秒）、底部停 4、向心 15、頂端停 7（0＝頂端、1＝最深）
def tempo_up(f): return profile(f, N, 15, 7, 22)    # 向上發力 15 格（約 1.2 秒）、頂端停 7（夾 1 秒）、慢放 22、起點停 4（0＝起點、1＝頂端）

def ang(a, b):
    a = a.normalized(); b = b.normalized(); return math.degrees(math.acos(max(-1.0, min(1.0, a.dot(b)))))

def place_bench(back_deg, rotz_deg, offset):
    """呼叫 build_bench（不改它），再把新增的物件整組掛到一個空物件上轉向、平移"""
    before = set(bpy.data.objects)
    build_bench(back_deg)
    root = bpy.data.objects.new('benchroot', None); sc.collection.objects.link(root)
    root.rotation_euler = (0, 0, D(rotz_deg)); root.location = Vector(offset)
    for o in bpy.data.objects:
        if o not in before and o.parent is None and o is not root: o.parent = root
    return root

# 前腳（左）踩的位置：腳踝 x 0.11、y 0；後腳（右）x -0.11
FRONT = Vector((HIPX['L'], 0.0, 0.11))

# ======================= 弓步（原地、前後分開站，上下蹲） =======================
# 範本：其他三個弓步類動作用同一個 lunge_pose，只換前腳高度、後腳、髖位置、前膝角度。
if MOVE == 'lunge':
    N = 48
    REAR_TOE = Vector((-HIPX['L'], 0.69, 0.045))
    rear = rear_toe(REAR_TOE, 55)
    def pose(t):
        H, sh = lunge_pose(t, FRONT, rear, hy=(0.34, 0.34), knee=(172, 92), lean=D(8))
        hang_arms(sh, spread=0.09)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    CAM = dict(loc=(4.3, -3.2, 1.25), tgt=(0, 0.33, 0.62), lens=52, stage=(0, 0.34, 0.95))

# ======================= 保加利亞分腿蹲（後腳腳背放椅子上；App：db_split_squat） =======================
# 椅子轉 -90°（長邊朝左右），放在人的後面；後腳（右）腳背平放在座墊上、腳尖朝後。
if MOVE == 'splitSquat':
    N = 48
    REAR_Y = 0.97                                     # 後腳踝 y（前腳踝在 y=0）
    place_bench(90, -90, (0.0, REAR_Y + 0.06, 0.0))   # 座墊（x -0.30～0.13、y ±0.15）剛好托住後腳
    rear = rear_fixed(Vector((-HIPX['L'], REAR_Y, 0.47 + 0.025)), Vector((0, 0.894, 0.447)))   # 腳背貼座墊：鞋面離腳踝點約 2 cm
    def pose(t):
        H, sh = lunge_pose(t, FRONT, rear, hy=(0.34, 0.34), knee=(172, 92), lean=D(10))
        hang_arms(sh, spread=0.09)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    CAM = dict(loc=(4.4, -3.0, 1.35), tgt=(0, 0.5, 0.55), lens=50, stage=(0, 0.5, 1.25))

# ======================= 後跨弓步（站直 → 右腳往後踏一大步 → 蹲 → 蹬回站直；App：db_reverse_lunge） =======================
if MOVE == 'reverseLunge':
    N = 48
    toe0 = Vector((-HIPX['L'], -0.13, 0.04))          # 站直時腳平放的鞋尖點
    toe1 = Vector((-HIPX['L'], 0.69, 0.045))
    rear = rear_step_back(toe0, toe1, 55, lift=0.07, split=0.5)
    def pose(t):
        H, sh = lunge_pose(t, FRONT, rear, hy=(0.0, 0.34), knee=(176, 92), lean=D(8))
        hang_arms(sh, spread=0.09)
    for f in range(N):
        sc.frame_set(f); pose(tempo(f)); keyall(f)
    CAM = dict(loc=(4.3, -3.2, 1.25), tgt=(0, 0.33, 0.62), lens=52, stage=(0, 0.34, 0.95))

# ======================= 登階（左腳踩上椅子 → 站上去、右腳抬起 → 慢慢放下；App：db_step_up） =======================
# 椅子不轉，人站在椅子尾端（+y）朝 -y 踩上去；用靠背那段（平放，墊面高 0.50）。
if MOVE == 'stepUp':
    N = 48
    build_bench(90)
    LEAD = Vector((0.09, 0.73, 0.50 + 0.11 + 0.005))  # 前（踩上去的）腳踝：墊面上
    toe0 = Vector((-0.24, 1.13, 0.045))               # 後腳站寬一點（與肩同寬），避開椅子後端的頭枕把手（x ±0.1）
    rear = rear_air(toe0, 45, Vector((-0.04, -0.12, -0.62)), split=1.0)
    def pose(t):
        H, sh = lunge_pose(t, LEAD, rear, hy=(LEAD.y + 0.02, LEAD.y + 0.46), knee=(172, 88), lean=D(20))
        hang_arms(sh, spread=0.09)
    for f in range(N):
        sc.frame_set(f); pose(1 - tempo_up(f)); keyall(f)       # 深度 1＝起點（腳在椅子上、膝蓋彎）、0＝站上去
    CAM = dict(loc=(4.4, -2.6, 1.9), tgt=(0, 0.75, 0.85), lens=50, stage=(0, 0.75, 1.2))

# ---------- 臀橋族群（仰躺；頭朝 +y、腳朝 -y，和 bench.py 的 supine 一樣） ----------
def aimz(name, head, ydir, zhint):
    """像 aim，但骨頭的 z 軸（手：啞鈴握把方向）照 zhint"""
    yv = ydir.normalized(); zv = (zhint - yv * zhint.dot(yv)).normalized(); xv = yv.cross(zv)
    m = Matrix((xv, yv, zv)).transposed().to_4x4(); m.translation = head
    pb[name].matrix = m; bpy.context.view_layer.update()
    return head + yv * blen[name]

def hold(s, sh, wrist, pole, fingers, axis):
    """手腕釘在 wrist，手指朝 fingers，握把軸 axis（手的 z 軸）"""
    e = ik2(sh, wrist, blen[f'upper_arm.{s}'], blen[f'forearm.{s}'], pole)
    aim(f'upper_arm.{s}', sh, e - sh); aim(f'forearm.{s}', e, wrist - e); aimz(f'hand.{s}', wrist, fingers, axis)
    _PIN[s] = (wrist.copy(), pole.copy())

def bridge_feet(phi_top, C, knee_top_deg, trunk_c):
    """頂端時膝蓋內角 knee_top_deg 需要的腳踝 y（腳踩在地板，高 0.11）"""
    c = Vector((0, math.cos(phi_top), -math.sin(phi_top)))
    hj = C - c * trunk_c + RX(-D(90) - phi_top) @ Vector((0, 0, -0.04))
    d = 2 * blen['thigh.L'] * math.sin(D(knee_top_deg) / 2)
    return hj.y - math.sqrt(max(d * d - (hj.z - 0.11) ** 2, 0.0))

def build_barbell():
    """臀推用的槓鈴（使用者的槓鈴是兩支舊啞鈴接起來的）：槓桿、中段護墊、兩邊各三片槓片＋固定環。回傳父物件（名稱 bar：穿模檢查不算手握的東西）"""
    bar = bpy.data.objects.new('bar', None); sc.collection.objects.link(bar)
    own = [pcyl('chrome', (0, 0, 0), 0.014, 1.30, (1, 0, 0), n=12), pcyl('pad', (0, 0, 0), 0.04, 0.30, (1, 0, 0), n=20, bevel=0.01)]
    for sx in (1, -1):
        for i_, x_ in enumerate((0.47, 0.50, 0.53)):
            own.append(pcyl('plate', (x_ * sx, 0, 0), 0.115 - i_ * 0.012, 0.028, (1, 0, 0), n=32, bevel=0.006))
        own.append(pcyl('red', (0.40 * sx, 0, 0), 0.03, 0.035, (1, 0, 0), n=6, bevel=0.004))
    for o_ in own: o_.parent = bar
    return bar

# ======================= 臀橋（仰躺地板；App：db_glute_bridge，兩顆啞鈴各壓一側髖骨） =======================
# 範本：hipThrust 用同一個 bridge_pose，只換上背的支撐高度（地板 → 椅面）、軀幹仰角範圍、手拿的東西。
if MOVE == 'bridge':
    N = 48
    TC = 0.40
    C = Vector((0, 0.45, 0.155))                      # 上背接觸點（脊椎線，離地 0.155）
    PHI_TOP = D(27)
    FOOT_Y = bridge_feet(PHI_TOP, C, 98, TC)
    def pose(t):
        phi = PHI_TOP * t
        hh, c, sh, J = bridge_pose(phi, C, FOOT_Y, foot_x=0.16, trunk_c=TC)
        f = Vector((0, math.sin(phi), math.cos(phi)))                    # 身體前面（朝天花板那側）
        for s, sx in SX:
            P = J[s] + Vector((0.12 * sx, 0, 0)) + f * 0.26 + c * 0.12               # 啞鈴中心：同側髖骨上方
            hold(s, sh[s], P + f * 0.07, Vector((0.5 * sx, 0.3, 1.0)), -f, c)
    for f in range(N):
        sc.frame_set(f); pose(tempo_up(f)); keyall(f)
    CAM = dict(loc=(3.4, -1.5, 1.0), tgt=(0, 0.0, 0.28), lens=48, stage=(0, 0.0, 1.0))

# ======================= 臀推（上背靠椅子邊緣、槓鈴放髖部；App：bb_hip_thrust／db_hip_thrust） =======================
# 椅子轉 -90°（長邊朝左右）。背靠在座墊前緣（腳那側的邊）：背面碰到那條邊 E，邊的位置固定，
# 脊椎線離背面 0.115 → 脊椎上的接觸點 C ＝ E ＋ 身體前方 × 0.115（隨軀幹角度移動）。
# 底部髖部接近地板、軀幹約 48° 斜靠；頂端軀幹水平躺在座墊上、大腿和軀幹成一直線、小腿垂直。
if MOVE == 'hipThrust':
    N = 48
    TC = 0.50
    SEAT = 0.47
    E_Y = 0.40                                         # 座墊前緣（腳那側）y
    PHI_BOT, PHI_TOP = -D(48), -D(4)
    def contact(phi):
        return Vector((0, E_Y, SEAT)) + Vector((0, math.sin(phi), math.cos(phi))) * 0.115
    FOOT_Y = bridge_feet(PHI_TOP, contact(PHI_TOP), 92, TC)
    place_bench(90, -90, (0.085, E_Y + 0.15, 0.0))     # 座墊 x -0.215～0.215（置中）、y E_Y～E_Y+0.30
    bar = build_barbell()
    def pose(t):
        phi = PHI_BOT + (PHI_TOP - PHI_BOT) * t
        hh, c, sh, J = bridge_pose(phi, contact(phi), FOOT_Y, foot_x=0.18, trunk_c=TC)
        f = Vector((0, math.sin(phi), math.cos(phi)))
        hm = (J['L'] + J['R']) / 2
        bar.location = hm + f * 0.14 - c * 0.03; bar.keyframe_insert('location')
        for s, sx in SX:
            wrist = bar.location + Vector((0.30 * sx, 0, 0)) + f * 0.05
            hold(s, sh[s], wrist, Vector((0.4 * sx, 0.2, 1.0)), Vector((-0.2 * sx, 0, -1.0)), X_)
    for f in range(N):
        sc.frame_set(f); pose(tempo_up(f)); keyall(f)    # 0 起點（髖在低處）→ 1 頂端
    CAM = dict(loc=(3.6, -1.8, 1.1), tgt=(0, 0.1, 0.4), lens=48, stage=(0, 0.1, 1.15))
