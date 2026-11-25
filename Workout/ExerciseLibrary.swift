import Foundation

enum MovementPattern: String, CaseIterable, Identifiable {
    case hPush, incline, vPush, hPull, vPull, squat, hinge, lunge, glute, hamCurl, quadIso, calf, biceps, triceps, lateral, rear, core

    var id: String { rawValue }

    /// 自訂動作、自訂課表選動作類型時顯示的名稱。
    var title: String {
        switch self {
        case .hPush: "水平推（胸）"
        case .incline: "上斜推（上胸）"
        case .vPush: "垂直推（肩）"
        case .hPull: "水平拉（背）"
        case .vPull: "垂直拉（背闊）"
        case .squat: "深蹲類"
        case .hinge: "髖鉸鏈（硬舉類）"
        case .lunge: "弓步、單腳"
        case .glute: "臀推、臀橋"
        case .hamCurl: "腿後彎舉"
        case .quadIso: "腿伸展"
        case .calf: "小腿"
        case .biceps: "二頭"
        case .triceps: "三頭"
        case .lateral: "側平舉（肩側）"
        case .rear: "後肩"
        case .core: "核心"
        }
    }

    /// 自訂課表判斷「上半身／下半身」日用（週任務「上下半身都練」）。核心兩邊都不算。
    var isUpper: Bool {
        switch self {
        case .hPush, .incline, .vPush, .hPull, .vPull, .biceps, .triceps, .lateral, .rear: true
        default: false
        }
    }

    var isLower: Bool {
        switch self {
        case .squat, .hinge, .lunge, .glute, .hamCurl, .quadIso, .calf: true
        default: false
        }
    }

    /// 熱身用的分區：同一區第一個複合動作做完整熱身，之後只做 1 組。nil = 單關節動作，不排熱身。
    var region: String? {
        switch self {
        case .hPush, .incline, .vPush: "push"
        case .hPull, .vPull: "pull"
        case .squat, .hinge, .lunge, .glute: "legs"
        default: nil
        }
    }
}

enum RepUnit: String {
    case reps, seconds

    var label: String { self == .reps ? "下" : "秒" }
}

struct Exercise: Identifiable {
    let id: String
    let name: String
    let pattern: MovementPattern
    let requires: Set<Equipment>
    /// Uses an external weight, so progression adds kg rather than reps.
    let loaded: Bool
    var unit: RepUnit = .reps
    /// Overrides the slot's rep range (e.g. plank seconds).
    var range: ClosedRange<Int>? = nil
    /// 這個動作自己指定練到的部位（主要 1.0、次要 0.5）。沒寫就照動作類型（`pattern.muscles`）。
    var muscles: [(Muscle, Double)]? = nil
    let tip: String

    /// 記錄、疲勞、熱圖、每週總結用：有指定部位就用指定的，沒有就照動作類型。
    var trainedMuscles: [(Muscle, Double)] { muscles ?? pattern.muscles }

    var isCustom: Bool { id.hasPrefix(CustomExercises.idPrefix) }
}

/// Candidates are listed in order of preference within each movement pattern.
enum ExerciseLibrary {
    /// 內建 + 自訂（不含已刪除的自訂動作）。
    static var all: [Exercise] { builtIn + CustomExercises.visible }

    static let builtIn: [Exercise] = [
        // 水平推（健身房的排前面，在家沒有那些器材會自動跳過）
        Exercise(id: "bb_bench", name: "槓鈴臥推", pattern: .hPush, requires: [.barbell, .rack, .bench], loaded: true, tip: "肩胛骨夾緊、腳踩穩，槓下放到胸口下緣再推起"),
        Exercise(id: "machine_chest_press", name: "坐姿推胸機", pattern: .hPush, requires: [.machine], loaded: true, tip: "把手對齊胸口中段，推到手臂快打直就收回"),
        Exercise(id: "db_bench", name: "啞鈴臥推", pattern: .hPush, requires: [.dumbbell, .bench], loaded: true, tip: "肩胛骨夾緊貼椅，啞鈴下放到胸側"),
        Exercise(id: "db_neutral_press", name: "啞鈴對握臥推", pattern: .hPush, requires: [.dumbbell, .bench], loaded: true, tip: "掌心相對、手肘貼近身體，比較護肩，也多練到三頭"),
        Exercise(id: "bb_floor_press", name: "槓鈴地板臥推", pattern: .hPush, requires: [.barbell], loaded: true, tip: "沒有深蹲架，所以躺地上推最安全，手肘碰地再推"),
        Exercise(id: "db_floor_press", name: "啞鈴地板臥推", pattern: .hPush, requires: [.dumbbell], loaded: true, tip: "躺地上，手肘輕碰地面停一下再推"),
        Exercise(id: "db_fly", name: "啞鈴平躺飛鳥", pattern: .hPush, requires: [.dumbbell, .bench], loaded: true, muscles: [(.chest, 1)], tip: "平躺，手肘微彎固定，往兩側打開到胸口有拉開感，再像抱樹一樣合起來"),
        Exercise(id: "pushup", name: "伏地挺身", pattern: .hPush, requires: [], loaded: false, tip: "身體一直線，胸口貼近地面"),
        // 上斜推（練上胸，胸肌看起來比較厚）
        Exercise(id: "db_incline_press", name: "啞鈴上斜臥推", pattern: .incline, requires: [.dumbbell, .bench], loaded: true, tip: "椅背調到第 2-3 格（約 30 度），推向上胸"),
        Exercise(id: "bb_incline_bench", name: "槓鈴上斜臥推", pattern: .incline, requires: [.barbell, .rack, .bench], loaded: true, tip: "椅背約 30 度，槓下放到鎖骨下方"),
        Exercise(id: "db_incline_fly", name: "啞鈴上斜飛鳥", pattern: .incline, requires: [.dumbbell, .bench], loaded: true, tip: "手肘微彎固定，像抱大樹一樣往下打開、再合起來"),
        Exercise(id: "decline_pushup", name: "腳抬高伏地挺身", pattern: .incline, requires: [], loaded: false, tip: "腳放椅子上，核心收緊不塌腰"),

        // 垂直推
        Exercise(id: "bb_ohp", name: "槓鈴站姿肩推", pattern: .vPush, requires: [.barbell, .rack], loaded: true, tip: "從架上取槓，夾臀收腹，推到頭頂時頭往前穿過"),
        Exercise(id: "machine_shoulder_press", name: "坐姿肩推機", pattern: .vPush, requires: [.machine], loaded: true, tip: "背貼椅背，推到手臂快打直"),
        Exercise(id: "db_shoulder_press", name: "啞鈴肩推", pattern: .vPush, requires: [.dumbbell], loaded: true, tip: "推到手臂打直，腹部收緊不拱腰"),
        Exercise(id: "db_arnold", name: "阿諾肩推", pattern: .vPush, requires: [.dumbbell], loaded: true, tip: "掌心朝自己開始，邊推邊轉向前"),
        Exercise(id: "band_press", name: "彈力帶肩推", pattern: .vPush, requires: [.band], loaded: false, tip: "腳踩彈力帶，往頭頂推直"),
        Exercise(id: "pike_pushup", name: "屈體伏地挺身", pattern: .vPush, requires: [], loaded: false, tip: "臀部抬高成倒 V，頭往地板方向下"),

        // 水平拉
        Exercise(id: "cable_row", name: "坐姿滑輪划船", pattern: .hPull, requires: [.machine], loaded: true, tip: "挺胸坐直，把手拉到肚子，停一秒夾背"),
        Exercise(id: "db_row", name: "單臂啞鈴划船", pattern: .hPull, requires: [.dumbbell], loaded: true, tip: "背打平，把啞鈴拉向髖部（每邊做）"),
        Exercise(id: "db_chest_row", name: "啞鈴俯臥划船", pattern: .hPull, requires: [.dumbbell, .bench], loaded: true, tip: "胸口趴椅上，雙手同時拉、夾背"),
        Exercise(id: "bb_row", name: "槓鈴俯身划船", pattern: .hPull, requires: [.barbell], loaded: true, tip: "上身前傾約 45 度，背打直，槓拉向肚臍"),
        Exercise(id: "band_row", name: "彈力帶划船", pattern: .hPull, requires: [.band], loaded: false, tip: "手肘貼身往後拉，停一秒夾背"),
        Exercise(id: "table_row", name: "桌下反向划船", pattern: .hPull, requires: [], loaded: false, tip: "先確認桌子夠穩！身體一直線，胸口拉向桌緣"),

        // 垂直拉
        Exercise(id: "assisted_pullup", name: "輔助引體向上機", pattern: .vPull, requires: [.machine], loaded: true, tip: "重量是「幫你減輕」的重量，越輕越難"),
        Exercise(id: "cable_pulldown", name: "高位下拉", pattern: .vPull, requires: [.cable], loaded: true, tip: "寬握長槓，挺胸，拉到上胸，不要往後倒"),
        Exercise(id: "cable_close_pulldown", name: "窄握下拉", pattern: .vPull, requires: [.cable], loaded: true, tip: "換上兩個橡膠把手，手肘往下往後拉到身側"),
        Exercise(id: "cable_one_arm_pulldown", name: "單手 D 把手下拉（跪姿）", pattern: .vPull, requires: [.cable], loaded: true, tip: "跪在滑輪下，單手握 D 把手，手肘往下往後拉到身側，上身不要扭（每邊做）"),
        Exercise(id: "cable_straight_arm", name: "直臂下拉", pattern: .vPull, requires: [.cable], loaded: true, muscles: [(.lats, 1)], tip: "用直槓或三頭繩，手臂打直往下壓到大腿，感覺背在出力"),
        Exercise(id: "db_pullover", name: "啞鈴仰臥拉舉", pattern: .vPull, requires: [.dumbbell, .bench], loaded: true, muscles: [(.lats, 1), (.chest, 0.5), (.triceps, 0.5)], tip: "躺椅上雙手捧一顆啞鈴，手肘微彎往頭後放到感覺背側拉開，再拉回胸口上方"),
        Exercise(id: "pullup", name: "引體向上", pattern: .vPull, requires: [.pullupBar], loaded: false, tip: "做不到就跳上去，花 3-5 秒慢慢放下"),
        Exercise(id: "chinup", name: "反手引體向上", pattern: .vPull, requires: [.pullupBar], loaded: false, tip: "掌心朝自己，下巴過槓"),
        Exercise(id: "band_pulldown", name: "彈力帶下拉", pattern: .vPull, requires: [.band], loaded: false, tip: "彈力帶掛高處，手肘往下往後拉"),
        Exercise(id: "prone_ytw", name: "俯臥 Y-T-W", pattern: .vPull, requires: [], loaded: false, muscles: [(.rearDelt, 1), (.traps, 1)], tip: "趴著，手臂依序擺成 Y、T、W 字，夾背"),

        // 深蹲
        Exercise(id: "bb_squat", name: "槓鈴深蹲", pattern: .squat, requires: [.barbell, .rack], loaded: true, tip: "槓放上背，吸氣撐住肚子，蹲到大腿平行再站起"),
        Exercise(id: "leg_press", name: "腿推機", pattern: .squat, requires: [.machine], loaded: true, tip: "下背貼緊椅墊，膝蓋對齊腳尖，不要鎖死膝蓋"),
        Exercise(id: "goblet_squat", name: "高腳杯深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, tip: "啞鈴抱胸前，蹲到大腿至少平行地面"),
        Exercise(id: "db_squat", name: "啞鈴深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, tip: "兩手各拿啞鈴垂在身側，挺胸下蹲"),
        Exercise(id: "heel_goblet", name: "腳跟墊高高腳杯深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, muscles: [(.quads, 1), (.glutes, 0.5)], tip: "腳跟踩在槓片上，上身可以更直、蹲更深，更練大腿前側"),
        Exercise(id: "goblet_15", name: "1.5 次高腳杯深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, tip: "蹲到底→站起一半→再蹲到底→站直，算 1 下。啞鈴不夠重時，同樣重量練得更夠"),
        Exercise(id: "squat", name: "徒手深蹲", pattern: .squat, requires: [], loaded: false, tip: "最低點停 2 秒，增加難度"),

        // 髖鉸鏈
        Exercise(id: "bb_rdl", name: "槓鈴羅馬尼亞硬舉", pattern: .hinge, requires: [.barbell], loaded: true, tip: "槓貼著大腿往下滑，屁股往後推，背打直"),
        Exercise(id: "db_rdl", name: "啞鈴羅馬尼亞硬舉", pattern: .hinge, requires: [.dumbbell], loaded: true, tip: "膝微彎，屁股往後推，背保持平直"),
        Exercise(id: "db_sl_rdl", name: "啞鈴單腳羅馬尼亞硬舉", pattern: .hinge, requires: [.dumbbell], loaded: true, tip: "單手拿啞鈴、對側腳站，屁股往後推，可以扶著下拉架保持平衡（每邊做）"),
        Exercise(id: "kb_swing", name: "壺鈴擺盪", pattern: .hinge, requires: [.kettlebell], loaded: true, tip: "用屁股發力把壺鈴甩出去，不是用手舉"),
        Exercise(id: "db_deadlift", name: "啞鈴傳統硬舉", pattern: .hinge, requires: [.dumbbell], loaded: true, muscles: [(.glutes, 1), (.hamstrings, 1), (.quads, 0.5)], tip: "兩手各拿啞鈴放在腳邊兩側，屁股後坐、膝蓋彎得比羅馬尼亞硬舉多，背打直，用腿和臀把身體站起來，啞鈴貼著腿"),
        Exercise(id: "sl_rdl", name: "單腳羅馬尼亞硬舉", pattern: .hinge, requires: [], loaded: false, tip: "單腳站，上身往前傾到與地面平行（每邊做）"),

        // 弓步
        Exercise(id: "db_split_squat", name: "啞鈴保加利亞分腿蹲", pattern: .lunge, requires: [.dumbbell], loaded: true, muscles: [(.quads, 1), (.glutes, 1)], tip: "後腳放椅子上，前膝對齊腳尖（每邊做）"),
        Exercise(id: "db_reverse_lunge", name: "啞鈴後跨弓步", pattern: .lunge, requires: [.dumbbell], loaded: true, muscles: [(.glutes, 1), (.quads, 0.5)], tip: "往後跨一大步，後膝輕碰地（每邊做）"),
        Exercise(id: "db_step_up", name: "啞鈴登階", pattern: .lunge, requires: [.dumbbell, .bench], loaded: true, muscles: [(.quads, 1), (.glutes, 1)], tip: "一腳踩在椅子上，用前腳把身體推上去，後腳不要蹬地（每邊做）"),
        Exercise(id: "split_squat", name: "保加利亞分腿蹲", pattern: .lunge, requires: [], loaded: false, muscles: [(.quads, 1), (.glutes, 1)], tip: "後腳放椅子上，慢慢下（每邊做）"),
        Exercise(id: "reverse_lunge", name: "後跨弓步", pattern: .lunge, requires: [], loaded: false, muscles: [(.glutes, 1), (.quads, 0.5)], tip: "往後跨一大步，上身挺直（每邊做）"),

        // 臀
        Exercise(id: "bb_hip_thrust", name: "槓鈴臀推", pattern: .glute, requires: [.barbell, .bench], loaded: true, tip: "上背靠椅，槓放髖部（墊毛巾），頂到身體一直線"),
        Exercise(id: "db_hip_thrust", name: "啞鈴臀推", pattern: .glute, requires: [.dumbbell, .bench], loaded: true, tip: "上背靠椅，啞鈴壓髖部，頂到身體一直線"),
        Exercise(id: "db_glute_bridge", name: "啞鈴臀橋", pattern: .glute, requires: [.dumbbell], loaded: true, tip: "躺地上，啞鈴壓髖部，頂起夾臀 1 秒"),
        Exercise(id: "sl_glute_bridge", name: "單腳臀橋", pattern: .glute, requires: [], loaded: false, tip: "單腳踩地把髖頂起（每邊做）"),

        // 腿後彎舉
        Exercise(id: "machine_leg_curl", name: "腿後彎舉機", pattern: .hamCurl, requires: [.machine], loaded: true, tip: "慢慢放回，不要讓重量片撞在一起"),
        Exercise(id: "db_leg_curl", name: "啞鈴俯臥腿後彎舉", pattern: .hamCurl, requires: [.dumbbell, .bench], loaded: true, tip: "趴在椅子上，兩腳夾住一顆啞鈴，用輕重量慢慢彎"),
        Exercise(id: "towel_leg_curl", name: "毛巾滑行腿後彎舉", pattern: .hamCurl, requires: [], loaded: false, tip: "躺地上、腳踩毛巾、臀部抬起，把腳跟拉向屁股"),

        // 腿前伸展（只有健身房有）
        Exercise(id: "leg_extension", name: "腿伸展機", pattern: .quadIso, requires: [.machine], loaded: true, tip: "踢到腿伸直停 1 秒，慢慢放下"),
        Exercise(id: "sissy_squat", name: "西西深蹲（扶椅子）", pattern: .quadIso, requires: [], loaded: false, tip: "一手扶椅背，膝蓋往前推、身體後仰成一直線，大腿前側拉長再站起"),
        Exercise(id: "reverse_nordic", name: "反向北歐", pattern: .quadIso, requires: [], loaded: false, tip: "跪在軟墊上，身體像一塊板子慢慢往後倒，大腿前側撐住，倒不下去就縮小角度"),

        // 小腿
        Exercise(id: "machine_calf", name: "站姿提踵機", pattern: .calf, requires: [.machine], loaded: true, tip: "腳跟放到底拉伸，再踮到最高"),
        Exercise(id: "db_calf_raise", name: "啞鈴單腳提踵", pattern: .calf, requires: [.dumbbell], loaded: true, tip: "站階梯邊緣，腳跟放到底再踮到最高"),
        Exercise(id: "calf_raise", name: "單腳提踵", pattern: .calf, requires: [], loaded: false, tip: "站階梯邊緣，腳跟放到底再踮到最高"),

        // 二頭
        Exercise(id: "bb_curl", name: "槓鈴彎舉", pattern: .biceps, requires: [.barbell], loaded: true, tip: "手肘固定在身側，不要用腰甩"),
        Exercise(id: "db_hammer_curl", name: "錘式彎舉", pattern: .biceps, requires: [.dumbbell], loaded: true, muscles: [(.biceps, 1), (.forearms, 1)], tip: "掌心相對，手肘固定"),
        Exercise(id: "db_curl", name: "啞鈴彎舉", pattern: .biceps, requires: [.dumbbell], loaded: true, tip: "手肘固定在身側，不要甩"),
        Exercise(id: "db_incline_curl", name: "上斜椅啞鈴彎舉", pattern: .biceps, requires: [.dumbbell, .bench], loaded: true, tip: "椅背調斜躺著，手臂自然垂在身體後方，手肘不往前跑"),
        Exercise(id: "db_concentration_curl", name: "集中彎舉", pattern: .biceps, requires: [.dumbbell], loaded: true, tip: "坐著，手肘靠在大腿內側，慢慢彎到頂、慢慢放（每邊做）"),
        Exercise(id: "cable_curl", name: "低位滑輪彎舉", pattern: .biceps, requires: [.machine], loaded: true, tip: "手肘貼身，彎到頂停一秒"),
        Exercise(id: "band_curl", name: "彈力帶彎舉", pattern: .biceps, requires: [.band], loaded: false, tip: "腳踩彈力帶，手肘固定"),

        // 三頭
        Exercise(id: "cable_pushdown", name: "繩索三頭下壓", pattern: .triceps, requires: [.cable], loaded: true, tip: "用三頭繩，手肘貼身，壓到底時把繩子往兩邊拉開"),
        Exercise(id: "cable_overhead_ext", name: "繩索過頭三頭伸展", pattern: .triceps, requires: [.cable], loaded: true, tip: "背對滑輪，手肘朝前，往前上方伸直"),
        Exercise(id: "cable_one_arm_pushdown", name: "單手繩索三頭下壓", pattern: .triceps, requires: [.cable], loaded: true, tip: "單手握 D 把手或單條繩子，手肘貼身固定，往下壓到手臂打直，上身不要跟著動（每邊做）"),
        Exercise(id: "db_overhead_ext", name: "啞鈴過頭三頭伸展", pattern: .triceps, requires: [.dumbbell], loaded: true, tip: "雙手握一顆啞鈴，手肘朝前不外開"),
        Exercise(id: "db_skull", name: "啞鈴仰臥三頭伸展", pattern: .triceps, requires: [.dumbbell, .bench], loaded: true, tip: "躺椅上，上臂垂直地面不動，只彎手肘把啞鈴放到耳朵旁再伸直"),
        Exercise(id: "db_kickback", name: "啞鈴三頭後踢", pattern: .triceps, requires: [.dumbbell], loaded: true, tip: "上身前傾，上臂貼身體不動，把啞鈴往後踢到手臂打直，停 1 秒"),
        Exercise(id: "band_pushdown", name: "彈力帶三頭下壓", pattern: .triceps, requires: [.band], loaded: false, tip: "彈力帶掛高處，手肘貼身往下壓"),
        Exercise(id: "bench_dip", name: "椅子撐體", pattern: .triceps, requires: [], loaded: false, tip: "手撐椅緣，肩膀不要聳起"),

        // 側肩
        Exercise(id: "db_lateral", name: "啞鈴側平舉", pattern: .lateral, requires: [.dumbbell], loaded: true, tip: "用輕重量，舉到肩膀高度就好"),
        Exercise(id: "db_lean_lateral", name: "單手扶柱側平舉", pattern: .lateral, requires: [.dumbbell], loaded: true, tip: "一手抓下拉架的柱子、身體往外傾，另一手做側平舉，頂端更吃力（每邊做）"),
        Exercise(id: "db_side_lying_lateral", name: "斜躺側平舉", pattern: .lateral, requires: [.dumbbell, .bench], loaded: true, tip: "側躺在斜背的椅子上，手臂微彎往上舉到肩膀高度，不要用甩的（每邊做）"),
        Exercise(id: "cable_lateral", name: "單手滑輪側平舉", pattern: .lateral, requires: [.machine], loaded: true, tip: "滑輪放最低，從身體前方往側邊舉"),
        Exercise(id: "band_lateral", name: "彈力帶側平舉", pattern: .lateral, requires: [.band], loaded: false, tip: "腳踩彈力帶，手臂微彎往兩側舉"),

        // 後肩
        Exercise(id: "cable_face_pull", name: "繩索面拉", pattern: .rear, requires: [.cable], loaded: true, tip: "坐著用三頭繩拉向臉，手肘外開，對肩膀健康很好"),
        Exercise(id: "machine_rear_delt", name: "反向飛鳥機", pattern: .rear, requires: [.machine], loaded: true, tip: "手臂微彎，往後打開到身體兩側"),
        Exercise(id: "db_rear_fly", name: "啞鈴反向飛鳥", pattern: .rear, requires: [.dumbbell], loaded: true, tip: "上身前傾，手臂微彎往兩側打開，用輕重量"),
        Exercise(id: "db_chest_rear_fly", name: "胸靠椅反向飛鳥", pattern: .rear, requires: [.dumbbell, .bench], loaded: true, tip: "胸口趴在斜椅上，手臂微彎往兩側打開，身體不會晃，比較好專心練後肩"),
        Exercise(id: "band_pull_apart", name: "彈力帶拉開", pattern: .rear, requires: [.band], loaded: false, tip: "手臂伸直，把彈力帶往兩邊拉到胸前"),

        // 核心
        Exercise(id: "cable_crunch", name: "跪姿繩索捲腹", pattern: .core, requires: [.cable], loaded: true, tip: "跪在滑輪下，用腹部把身體捲下去，不是用手拉"),
        Exercise(id: "cable_high_chop", name: "跪姿高位繩索下劈", pattern: .core, requires: [.cable], loaded: true, range: 10...15, muscles: [(.obliques, 1), (.abs, 0.5)], tip: "單膝跪在滑輪旁，雙手握繩從高處斜向下拉到對側膝旁，髖部不轉、用腹部出力（每邊做）"),
        Exercise(id: "decline_crunch", name: "下斜捲腹", pattern: .core, requires: [.bench], loaded: false, tip: "腳勾住健身椅的滾筒，背不用碰到底"),
        Exercise(id: "hanging_knee", name: "懸垂舉膝", pattern: .core, requires: [.pullupBar], loaded: false, muscles: [(.abs, 1), (.forearms, 0.5)], tip: "吊在單槓上，膝蓋抬到胸前，不要晃"),
        Exercise(id: "farmer_walk", name: "農夫走路", pattern: .core, requires: [.dumbbell], loaded: true, unit: .seconds, range: 30...60, muscles: [(.forearms, 1), (.traps, 1), (.abs, 0.5)], tip: "兩手各拿一顆啞鈴垂在身側，挺胸收腹、肩膀下沉，穩穩走直線，握不住就停"),
        Exercise(id: "suitcase_carry", name: "手提箱行走（單手）", pattern: .core, requires: [.dumbbell], loaded: true, unit: .seconds, range: 30...60, muscles: [(.obliques, 1), (.forearms, 1)], tip: "單手拿一顆啞鈴垂在身側，像提行李箱，身體不要往重的那邊歪，肩膀水平，穩穩走直線（每邊做）"),
        Exercise(id: "dead_bug", name: "死蟲式", pattern: .core, requires: [], loaded: false, tip: "下背貼地，對側手腳慢慢伸直"),
        Exercise(id: "reverse_crunch", name: "反向捲腹", pattern: .core, requires: [], loaded: false, tip: "躺著，用腹部把骨盆捲起來、膝蓋帶向胸口，慢慢放下，不要甩"),
        Exercise(id: "plank", name: "棒式", pattern: .core, requires: [], loaded: false, unit: .seconds, range: 30...60, tip: "身體一直線，夾臀收腹"),
        Exercise(id: "side_plank", name: "側棒式", pattern: .core, requires: [], loaded: false, unit: .seconds, range: 20...45, muscles: [(.obliques, 1)], tip: "手肘撐地，身體側躺成一直線，髖部撐高不下垂（每邊做）"),
        Exercise(id: "bird_dog", name: "鳥狗式", pattern: .core, requires: [], loaded: false, muscles: [(.abs, 1), (.lowerBack, 1)], tip: "四足跪姿，對側手腳同時往外伸直到和背一條線，停 1 秒再收回，骨盆不要左右晃"),

        // 徒手動作的進階版（0.33.0）：放在最後，平常不會排到；原本的徒手動作每組都做到次數上限才自動升級（`Upgrade`）
        Exercise(id: "pause_pushup", name: "暫停伏地挺身", pattern: .hPush, requires: [], loaded: false, tip: "胸口離地一個拳頭時停 2 秒，再推起來"),
        Exercise(id: "archer_pushup", name: "弓箭手伏地挺身", pattern: .hPush, requires: [], loaded: false, tip: "雙手撐很寬，身體往一邊下、另一手伸直只是扶著，左右輪流"),
        Exercise(id: "elevated_pike", name: "腳抬高屈體伏地挺身", pattern: .vPush, requires: [.bench], loaded: false, tip: "腳放椅子上、臀部抬高，頭往雙手中間的地板方向下"),
        Exercise(id: "pause_table_row", name: "暫停桌下划船", pattern: .hPull, requires: [], loaded: false, tip: "先確認桌子夠穩！胸口拉到桌緣停 2 秒，再慢慢放下"),
        Exercise(id: "slow_squat", name: "慢速深蹲", pattern: .squat, requires: [], loaded: false, tip: "3 秒蹲下、最低點停 2 秒，再站起來"),
        Exercise(id: "pause_split_squat", name: "暫停保加利亞分腿蹲", pattern: .lunge, requires: [], loaded: false, muscles: [(.quads, 1), (.glutes, 1)], tip: "後腳放椅子上，3 秒下、最低點停 2 秒（每邊做）"),
        Exercise(id: "sl_hip_thrust", name: "單腳臀推", pattern: .glute, requires: [.bench], loaded: false, tip: "上背靠在椅子邊緣，單腳踩地把髖頂到最高，停 1 秒（每邊做）"),
        Exercise(id: "sl_towel_leg_curl", name: "單腳毛巾腿後彎舉", pattern: .hamCurl, requires: [], loaded: false, tip: "臀部抬起、單腳踩毛巾往屁股拉，另一腳抬著（每邊做）"),
        Exercise(id: "elevated_bench_dip", name: "腳抬高椅子撐體", pattern: .triceps, requires: [.bench], loaded: false, tip: "手撐椅緣、腳放另一張椅子或高處，肩膀不要聳起"),
        Exercise(id: "pause_calf_raise", name: "暫停單腳提踵", pattern: .calf, requires: [], loaded: false, tip: "踮到最高停 2 秒，腳跟慢慢放到最低（每邊做）"),
    ]

    /// 不當主項（課表的重點動作）的動作：單腳版本受平衡限制、擺盪練的是爆發，重量進步不穩定。
    /// 還是可以當輔助動作，或在家啞鈴到頂時升級用（`Upgrade`）。
    static let notMain: Set<String> = ["db_sl_rdl", "sl_rdl", "kb_swing", "sl_glute_bridge"]

    /// 刪除的自訂動作也找得到：舊紀錄、PR 還要顯示它的名字。
    static func byId(_ id: String) -> Exercise? {
        if id.hasPrefix(CustomExercises.idPrefix) {
            return CustomExercises.load().first { $0.id == id }?.exercise
        }
        return builtIn.first { $0.id == id }
    }

    /// 自動挑動作用。自訂動作只有開了「自動挑動作時也排自訂動作」才會進來，排在內建的後面。
    /// 使用者標記「會痛／不喜歡」的動作不會出現（`byId` 還是找得到，舊紀錄要顯示名字）。
    static func candidates(for pattern: MovementPattern, equipment: Set<Equipment>) -> [Exercise] {
        let pool = CustomExercises.inAutoPick ? all : builtIn
        return pool.filter { $0.pattern == pattern && $0.requires.isSubset(of: equipment) && !Avoid.isAvoided($0.id) }
    }
}
