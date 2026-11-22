import SwiftUI
import SwiftData

struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var kind: SetKind = .work
    /// 指定用哪一組啞鈴（Drop set 用另一組先裝好的）
    var kit: String? = nil
    /// 還剩幾下力氣（RIR），-1 = 沒填
    var rir: Int = -1
    var done = false
    /// 這組的目標次數（排課表時的次數；判定 PERFECT 用）
    var target: Int = 0
    /// 做完後的判定（只有正式組）
    var grade: SetGrade? = nil
    /// 左右平衡：兩邊分開做（reps／rir 是先做的那邊，`SideBalance.first`）
    var oneArm = false
    /// 另一手的次數（-1 = 和弱的那手一樣）、還剩幾下（-1 = 沒填）
    var otherReps = -1
    var otherRir = -1
    /// 刻意減輕的組（練前狀態很差、會痛減輕）：下次加重不拿它當基準
    var eased = false
}

struct ExerciseDraft: Identifiable {
    var item: PlannedExercise
    var suggestion: Suggestion
    /// 「上次 10 kg × 12、11、10」, empty the first time.
    var lastText: String
    var sets: [SetDraft]
    /// 上次這個動作的正式組（休息頁比較用）
    var last: [LastSet] = []
    /// 使用者選的排法（可能是自動）
    var chosen: SetScheme = .auto
    /// 實際用的排法
    var scheme: SetScheme = .straight
    /// 這個動作裝得出來的重量
    var ladder = WeightLadder(loadings: [], step: 2.5)
    /// 這次因為停滯先減重（做完就從這次重新算停滯）
    var plateauReset = false
    /// 這次寫的動作備註
    var note: String = ""
    /// 上次寫的動作備註
    var lastNote: String? = nil
    /// 同一個關節最近會痛的提醒（`Joint.caution`）
    var caution: String? = nil
    /// 最近幾次的推估最大力量（休息頁小圖）
    var trend: [Double] = []
    /// 第一次做的動作：第一個正式組是試重組，做完依「還剩幾下」校準後面的組（`StartWeight`）
    var trial = false
    var id: String { item.id }

    /// 上次同一組（第 n 個正式組比第 n 個；上次組數比較少就比上次最後一組）
    func lastFor(_ set: SetDraft) -> LastSet? {
        guard set.kind == .work, !last.isEmpty, let i = sets.firstIndex(where: { $0.id == set.id }) else { return nil }
        let n = sets[...i].filter { $0.kind == .work }.count
        return last[min(n, last.count) - 1]
    }

    /// 已經開始做正式組，就不能再改排法或換動作。
    var locked: Bool { sets.contains { $0.done && $0.kind != .warmup } }
    var hasWarmups: Bool { sets.contains { $0.kind == .warmup } }
}
