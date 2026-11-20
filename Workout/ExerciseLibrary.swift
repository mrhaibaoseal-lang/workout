import Foundation

enum MovementPattern: String {
    case hPush, vPush, hPull, vPull, squat, hinge, lunge, glute, calf, biceps, triceps, lateral, core
}

enum RepUnit {
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
    let tip: String
}

/// Candidates are listed in order of preference within each movement pattern.
enum ExerciseLibrary {
    static let all: [Exercise] = [
        // 水平推
        Exercise(id: "db_bench", name: "啞鈴臥推", pattern: .hPush, requires: [.dumbbell, .bench], loaded: true, tip: "肩胛骨夾緊貼椅，啞鈴下放到胸側"),
        Exercise(id: "db_floor_press", name: "啞鈴地板臥推", pattern: .hPush, requires: [.dumbbell], loaded: true, tip: "躺地上，手肘輕碰地面停一下再推"),
        Exercise(id: "pushup", name: "伏地挺身", pattern: .hPush, requires: [], loaded: false, tip: "身體一直線，胸口貼近地面"),
        Exercise(id: "decline_pushup", name: "腳抬高伏地挺身", pattern: .hPush, requires: [], loaded: false, tip: "腳放椅子上，核心收緊不塌腰"),

        // 垂直推
        Exercise(id: "db_shoulder_press", name: "啞鈴肩推", pattern: .vPush, requires: [.dumbbell], loaded: true, tip: "推到手臂打直，腹部收緊不拱腰"),
        Exercise(id: "db_arnold", name: "阿諾肩推", pattern: .vPush, requires: [.dumbbell], loaded: true, tip: "掌心朝自己開始，邊推邊轉向前"),
        Exercise(id: "band_press", name: "彈力帶肩推", pattern: .vPush, requires: [.band], loaded: false, tip: "腳踩彈力帶，往頭頂推直"),
        Exercise(id: "pike_pushup", name: "屈體伏地挺身", pattern: .vPush, requires: [], loaded: false, tip: "臀部抬高成倒 V，頭往地板方向下"),

        // 水平拉
        Exercise(id: "db_row", name: "單臂啞鈴划船", pattern: .hPull, requires: [.dumbbell], loaded: true, tip: "背打平，把啞鈴拉向髖部（每邊做）"),
        Exercise(id: "db_chest_row", name: "啞鈴俯臥划船", pattern: .hPull, requires: [.dumbbell, .bench], loaded: true, tip: "胸口趴椅上，雙手同時拉、夾背"),
        Exercise(id: "band_row", name: "彈力帶划船", pattern: .hPull, requires: [.band], loaded: false, tip: "手肘貼身往後拉，停一秒夾背"),
        Exercise(id: "table_row", name: "桌下反向划船", pattern: .hPull, requires: [], loaded: false, tip: "先確認桌子夠穩！身體一直線，胸口拉向桌緣"),

        // 垂直拉
        Exercise(id: "pullup", name: "引體向上", pattern: .vPull, requires: [.pullupBar], loaded: false, tip: "做不到就跳上去，花 3-5 秒慢慢放下"),
        Exercise(id: "chinup", name: "反手引體向上", pattern: .vPull, requires: [.pullupBar], loaded: false, tip: "掌心朝自己，下巴過槓"),
        Exercise(id: "band_pulldown", name: "彈力帶下拉", pattern: .vPull, requires: [.band], loaded: false, tip: "彈力帶掛高處，手肘往下往後拉"),
        Exercise(id: "prone_ytw", name: "俯臥 Y-T-W", pattern: .vPull, requires: [], loaded: false, tip: "趴著，手臂依序擺成 Y、T、W 字，夾背"),

        // 深蹲
        Exercise(id: "goblet_squat", name: "高腳杯深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, tip: "啞鈴抱胸前，蹲到大腿至少平行地面"),
        Exercise(id: "db_squat", name: "啞鈴深蹲", pattern: .squat, requires: [.dumbbell], loaded: true, tip: "兩手各拿啞鈴垂在身側，挺胸下蹲"),
        Exercise(id: "squat", name: "徒手深蹲", pattern: .squat, requires: [], loaded: false, tip: "最低點停 2 秒，增加難度"),

        // 髖鉸鏈
        Exercise(id: "db_rdl", name: "啞鈴羅馬尼亞硬舉", pattern: .hinge, requires: [.dumbbell], loaded: true, tip: "膝微彎，屁股往後推，背保持平直"),
        Exercise(id: "kb_swing", name: "壺鈴擺盪", pattern: .hinge, requires: [.kettlebell], loaded: true, tip: "用屁股發力把壺鈴甩出去，不是用手舉"),
        Exercise(id: "sl_rdl", name: "單腳羅馬尼亞硬舉", pattern: .hinge, requires: [], loaded: false, tip: "單腳站，上身往前傾到與地面平行（每邊做）"),

        // 弓步
        Exercise(id: "db_split_squat", name: "啞鈴保加利亞分腿蹲", pattern: .lunge, requires: [.dumbbell], loaded: true, tip: "後腳放椅子上，前膝對齊腳尖（每邊做）"),
        Exercise(id: "db_reverse_lunge", name: "啞鈴後跨弓步", pattern: .lunge, requires: [.dumbbell], loaded: true, tip: "往後跨一大步，後膝輕碰地（每邊做）"),
        Exercise(id: "split_squat", name: "保加利亞分腿蹲", pattern: .lunge, requires: [], loaded: false, tip: "後腳放椅子上，慢慢下（每邊做）"),
        Exercise(id: "reverse_lunge", name: "後跨弓步", pattern: .lunge, requires: [], loaded: false, tip: "往後跨一大步，上身挺直（每邊做）"),

        // 臀
        Exercise(id: "db_hip_thrust", name: "啞鈴臀推", pattern: .glute, requires: [.dumbbell, .bench], loaded: true, tip: "上背靠椅，啞鈴壓髖部，頂到身體一直線"),
        Exercise(id: "db_glute_bridge", name: "啞鈴臀橋", pattern: .glute, requires: [.dumbbell], loaded: true, tip: "躺地上，啞鈴壓髖部，頂起夾臀 1 秒"),
        Exercise(id: "sl_glute_bridge", name: "單腳臀橋", pattern: .glute, requires: [], loaded: false, tip: "單腳踩地把髖頂起（每邊做）"),

        // 小腿
        Exercise(id: "db_calf_raise", name: "啞鈴單腳提踵", pattern: .calf, requires: [.dumbbell], loaded: true, tip: "站階梯邊緣，腳跟放到底再踮到最高"),
        Exercise(id: "calf_raise", name: "單腳提踵", pattern: .calf, requires: [], loaded: false, tip: "站階梯邊緣，腳跟放到底再踮到最高"),

        // 二頭
        Exercise(id: "db_curl", name: "啞鈴彎舉", pattern: .biceps, requires: [.dumbbell], loaded: true, tip: "手肘固定在身側，不要甩"),
        Exercise(id: "db_hammer_curl", name: "錘式彎舉", pattern: .biceps, requires: [.dumbbell], loaded: true, tip: "掌心相對，手肘固定"),
        Exercise(id: "band_curl", name: "彈力帶彎舉", pattern: .biceps, requires: [.band], loaded: false, tip: "腳踩彈力帶，手肘固定"),

        // 三頭
        Exercise(id: "db_overhead_ext", name: "啞鈴過頭三頭伸展", pattern: .triceps, requires: [.dumbbell], loaded: true, tip: "雙手握一顆啞鈴，手肘朝前不外開"),
        Exercise(id: "band_pushdown", name: "彈力帶三頭下壓", pattern: .triceps, requires: [.band], loaded: false, tip: "彈力帶掛高處，手肘貼身往下壓"),
        Exercise(id: "bench_dip", name: "椅子撐體", pattern: .triceps, requires: [], loaded: false, tip: "手撐椅緣，肩膀不要聳起"),

        // 側肩
        Exercise(id: "db_lateral", name: "啞鈴側平舉", pattern: .lateral, requires: [.dumbbell], loaded: true, tip: "用輕重量，舉到肩膀高度就好"),
        Exercise(id: "band_lateral", name: "彈力帶側平舉", pattern: .lateral, requires: [.band], loaded: false, tip: "腳踩彈力帶，手臂微彎往兩側舉"),

        // 核心
        Exercise(id: "hanging_knee", name: "懸垂舉膝", pattern: .core, requires: [.pullupBar], loaded: false, tip: "吊在單槓上，膝蓋抬到胸前，不要晃"),
        Exercise(id: "dead_bug", name: "死蟲式", pattern: .core, requires: [], loaded: false, tip: "下背貼地，對側手腳慢慢伸直"),
        Exercise(id: "plank", name: "棒式", pattern: .core, requires: [], loaded: false, unit: .seconds, range: 30...60, tip: "身體一直線，夾臀收腹"),
    ]

    static func byId(_ id: String) -> Exercise? {
        all.first { $0.id == id }
    }

    static func candidates(for pattern: MovementPattern, equipment: Set<Equipment>) -> [Exercise] {
        all.filter { $0.pattern == pattern && $0.requires.isSubset(of: equipment) }
    }
}
