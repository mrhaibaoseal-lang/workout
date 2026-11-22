import Foundation

/// 一次訓練當時是什麼週期、哪幾組是刻意減輕的（0.30.0）。
/// 減量週、刻意減輕的組不拿來當「下次加重」和「停滯」的基準，不然減量完會卡在減輕的重量、還被誤判停滯。
enum SessionPhase {
    /// 這次訓練的週期。0.30.0 以前的舊紀錄沒存，用當時的週數和區塊時鐘推回來。
    static func of(_ s: WorkoutSession) -> Phase {
        if let p = Phase(rawValue: s.phase) { return p }
        let start = UserDefaults.standard.double(forKey: Keys.startDate)
        guard start > 0 else { return .normal }
        let week = Stats.week(since: Date(timeIntervalSince1970: start), at: s.date)
        if week <= 2 { return .rampUp }
        return BlockClock.locate(week: week).deload == week ? .deload : .normal
    }

    static func isDeload(_ s: WorkoutSession) -> Bool { of(s) == .deload }

    /// 這個動作這次的正式組能不能當基準：不是減量週，而且不是每一組都刻意減輕。
    static func isBaseline(_ s: WorkoutSession, sets: [SetEntry]) -> Bool {
        if isDeload(s) { return false }
        return !sets.allSatisfy(\.eased)
    }
}
