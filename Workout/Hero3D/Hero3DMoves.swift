import Foundation

/// 動作庫動作 → 3D 示範動作（0.56.0）。3D 動作名＝Blender `MOVE_META` 的鍵（scripts/blender/moves/*.py），
/// 動作檔是 `hero3d_clip_<名稱>.json`，有器材的另有 `hero3d_prop_<名稱>.json／.bin`。
/// 對照以 `docs/3d-moves/inventory.md` 為準；沒列在這裡、或動作檔不存在的動作，示範畫面退回原本的 2D（`CharacterMove`）。
enum Hero3DMoves {
    static let byExercise: [String: String] = [
        // 水平推
        "bb_bench": "benchPress", "db_bench": "benchPress", "db_neutral_press": "benchPress",
        "machine_chest_press": "machineChestPress",
        "bb_floor_press": "floorPress", "db_floor_press": "floorPress",
        "db_fly": "dbFly",
        "pushup": "pushup", "pause_pushup": "pushup", "archer_pushup": "pushup",
        "decline_pushup": "declinePushup",
        "db_incline_press": "inclinePress", "bb_incline_bench": "inclinePress", "db_incline_fly": "inclineFly",
        // 垂直推
        "bb_ohp": "press", "db_shoulder_press": "press", "band_press": "press",
        "machine_shoulder_press": "machineShoulderPress", "db_arnold": "arnoldPress",
        "pike_pushup": "pikePushup", "elevated_pike": "elevatedPike",
        // 水平拉
        "db_row": "row", "bb_row": "row", "band_row": "row", "db_chest_row": "chestRow",
        "cable_row": "seatedCableRow",
        // 垂直拉
        "cable_pulldown": "pulldown", "band_pulldown": "pulldown", "cable_close_pulldown": "closePulldown",
        "cable_one_arm_pulldown": "oneArmPulldown", "cable_straight_arm": "straightArmPulldown",
        "pullup": "pullup", "chinup": "chinup", "assisted_pullup": "assistedPullup",
        "db_pullover": "pullover",
        // 蹲
        "squat": "bwSquat",
        "bb_squat": "squat", "goblet_squat": "squat", "db_squat": "squat", "heel_goblet": "squat",
        "goblet_15": "squat", "slow_squat": "squat",
        "leg_press": "legPress", "sissy_squat": "sissySquat",
        // 髖鉸鏈
        "bb_rdl": "rdl", "db_rdl": "rdl", "db_deadlift": "rdl",
        "db_sl_rdl": "slRdl", "sl_rdl": "slRdl", "kb_swing": "kbSwing",
        // 弓步、臀
        "db_split_squat": "splitSquat", "split_squat": "splitSquat", "pause_split_squat": "splitSquat",
        "db_reverse_lunge": "reverseLunge", "reverse_lunge": "reverseLunge", "db_step_up": "stepUp",
        "bb_hip_thrust": "hipThrust", "db_hip_thrust": "hipThrust", "sl_hip_thrust": "hipThrust",
        "db_glute_bridge": "bridge", "sl_glute_bridge": "bwBridge",
        // 腿後側、股四頭
        "db_leg_curl": "legCurl", "machine_leg_curl": "machineLegCurl",
        "towel_leg_curl": "towelLegCurl", "sl_towel_leg_curl": "slTowelLegCurl",
        "leg_extension": "legExtension", "reverse_nordic": "reverseNordic",
        // 小腿
        "machine_calf": "calf", "calf_raise": "calfSingle", "db_calf_raise": "calfSingle", "pause_calf_raise": "calfSingle",
        // 二頭
        "bb_curl": "curl", "db_curl": "curl", "db_hammer_curl": "curl", "band_curl": "curl",
        "db_incline_curl": "inclineCurl", "db_concentration_curl": "concentrationCurl",
        // 三頭
        "cable_pushdown": "tricepsPushdown", "cable_one_arm_pushdown": "tricepsPushdown", "band_pushdown": "tricepsPushdown",
        "cable_overhead_ext": "overheadCableExt", "db_overhead_ext": "triceps",
        "db_skull": "skullCrusher", "db_kickback": "kickback",
        "bench_dip": "benchDip", "elevated_bench_dip": "elevatedBenchDip",
        // 側平舉、後三角
        "db_lateral": "lateral", "band_lateral": "lateral", "db_lean_lateral": "leanLateral",
        "db_side_lying_lateral": "sideLyingLateral", "cable_lateral": "cableLateral",
        "cable_face_pull": "facePull", "machine_rear_delt": "machineRearDelt",
        "db_rear_fly": "rearFly", "band_pull_apart": "rearFly", "db_chest_rear_fly": "chestRearFly",
        "prone_ytw": "proneYTW",
        // 核心、負重行走
        "cable_crunch": "cableCrunch", "cable_high_chop": "highChop", "decline_crunch": "declineCrunch",
        "hanging_knee": "hangingKnee", "farmer_walk": "farmerWalk", "suitcase_carry": "suitcaseCarry",
        "dead_bug": "deadBug", "reverse_crunch": "reverseCrunch", "plank": "plank", "side_plank": "sidePlank",
        "bird_dog": "birdDog",
    ]

    /// 動作檔在 App 裡找得到才算有 3D
    static func hasClip(_ move: String) -> Bool {
        Bundle(for: Hero3DModel.self).url(forResource: "hero3d_clip_\(move)", withExtension: "json") != nil
    }

    /// 這個動作庫動作要播哪個 3D 動作；沒有就回 nil（用 2D）
    static func move(for exerciseId: String) -> String? {
        byExercise[exerciseId].flatMap { hasClip($0) ? $0 : nil }
    }
}
