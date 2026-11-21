import Foundation

/// 第一次做的動作自動試重（排課 5）。
/// 找做過、練到同一個主要部位的動作，用它最近的 e1RM × 兩個動作的強度比例，打 9 折，
/// 算出做到次數上限還剩 2 下的重量，取到器材裝得出來的重量。第一組當試重組，做完依「還剩幾下」校準（`calibrate`）。
enum StartWeight {
    /// 每個內建有負重動作的「典型 e1RM」，以槓鈴臥推 = 1 為基準（新手的大略比例，只用來換算起始重量）。
    /// 兩支啞鈴的動作是一支的重量；單支的是那一支；滑輪是掛的重量。
    /// 沒列的動作（自訂動作、輔助引體向上機這種「越輕越難」的）不推估。
    static let strength: [String: Double] = [
        // 水平推
        "bb_bench": 1.0, "machine_chest_press": 0.9, "db_bench": 0.37, "db_neutral_press": 0.35,
        "bb_floor_press": 0.9, "db_floor_press": 0.34,
        // 上斜推
        "db_incline_press": 0.31, "bb_incline_bench": 0.8, "db_incline_fly": 0.14,
        // 垂直推
        "bb_ohp": 0.62, "machine_shoulder_press": 0.55, "db_shoulder_press": 0.24, "db_arnold": 0.21,
        // 水平拉
        "cable_row": 0.85, "db_row": 0.42, "db_chest_row": 0.3, "bb_row": 0.85,
        // 垂直拉
        "cable_pulldown": 0.8, "cable_close_pulldown": 0.8, "cable_straight_arm": 0.35,
        // 深蹲
        "bb_squat": 1.25, "leg_press": 2.2, "goblet_squat": 0.45, "db_squat": 0.35,
        // 髖鉸鏈
        "bb_rdl": 1.2, "db_rdl": 0.45, "db_sl_rdl": 0.3, "kb_swing": 0.4,
        // 弓步
        "db_split_squat": 0.22, "db_reverse_lunge": 0.25,
        // 臀
        "bb_hip_thrust": 1.6, "db_hip_thrust": 0.6, "db_glute_bridge": 0.55,
        // 腿後、腿前、小腿
        "machine_leg_curl": 0.45, "db_leg_curl": 0.15, "leg_extension": 0.55,
        "machine_calf": 1.0, "db_calf_raise": 0.3,
        // 手臂
        "bb_curl": 0.4, "db_hammer_curl": 0.17, "db_curl": 0.15, "cable_curl": 0.35,
        "cable_pushdown": 0.35, "cable_overhead_ext": 0.3, "db_overhead_ext": 0.25,
        // 肩
        "db_lateral": 0.07, "db_lean_lateral": 0.08, "cable_lateral": 0.07,
        "cable_face_pull": 0.3, "machine_rear_delt": 0.35, "db_rear_fly": 0.07,
        // 核心
        "cable_crunch": 0.5,
    ]

    /// 試重組的目標：還剩 2 下
    static let targetRIR = 2
    /// 推估保守打幾折
    static let safety = 0.9

    struct Estimate {
        let weight: Double
        let reference: Exercise
    }

    private static func primary(_ p: MovementPattern) -> Set<Muscle> {
        Set(p.muscles.filter { $0.1 >= 1 }.map(\.0))
    }

    /// 參考動作：同一個動作類型優先，其次是主要部位有重疊的；同一級取最近做的。
    static func reference(for ex: Exercise) -> (Exercise, TrainingHistory.Lift)? {
        guard ex.loaded, strength[ex.id] != nil else { return nil }
        let mine = primary(ex.pattern)
        var best: (score: Int, ex: Exercise, lift: TrainingHistory.Lift)? = nil
        for (id, lift) in TrainingHistory.lifts where id != ex.id && lift.e1rm > 0 {
            guard strength[id] != nil, let ref = ExerciseLibrary.byId(id) else { continue }
            let score: Int
            if ref.pattern == ex.pattern { score = 2 }
            else if !primary(ref.pattern).isDisjoint(with: mine) { score = 1 }
            else { continue }
            if let b = best, b.score > score || (b.score == score && b.lift.date >= lift.date) { continue }
            best = (score, ref, lift)
        }
        return best.map { ($0.ex, $0.lift) }
    }

    /// 做到 reps 下、還剩 rir 下的重量（Epley 反推）
    static func weight(e1rm: Double, reps: Int, rir: Int) -> Double {
        e1rm / (1 + Double(reps + rir) / 30)
    }

    static func estimate(_ item: PlannedExercise, ladder: WeightLadder) -> Estimate? {
        let ex = item.exercise
        guard let (ref, lift) = reference(for: ex), let kNew = strength[ex.id], let kRef = strength[ref.id] else { return nil }
        let e1 = lift.e1rm * kNew / kRef * safety
        let raw = weight(e1rm: e1, reps: item.high, rir: targetRIR)
        guard raw > 0 else { return nil }
        let w = ladder.snap(raw)
        guard w > 0 else { return nil }
        return Estimate(weight: w, reference: ref)
    }

    /// 試重組做完：依這組的重量、次數、還剩幾下，算後面每組（目標次數 target）還剩 2 下的重量。
    static func calibrated(weight: Double, reps: Int, rir: Int, target: Int, ladder: WeightLadder) -> Double {
        let e1 = Comeback.e1rm(weight: weight, reps: reps, rir: rir)
        let w = ladder.snap(self.weight(e1rm: e1, reps: target, rir: targetRIR))
        return max(w, ladder.isEmpty ? 0 : (ladder.weights.first ?? 0))
    }
}
