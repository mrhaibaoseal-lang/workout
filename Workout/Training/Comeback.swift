import Foundation

/// 排課要用、但 `Progression.suggest` 拿不到訓練紀錄的資訊：各動作最近的推估最大力量（新動作試重用）、
/// 停練回來的狀態。今天頁、訓練畫面出現時、練完存檔後呼叫 `refresh` 更新（只放記憶體，不存檔）。
enum TrainingHistory {
    struct Lift {
        let e1rm: Double
        let date: Date
    }

    /// 各動作最近一次訓練裡最好的正式組 e1RM（有負重、重量 > 0）
    private(set) static var lifts: [String: Lift] = [:]
    private(set) static var comeback: Comeback.State?

    private static var signature: String = ""

    /// 紀錄有變（筆數、最新一筆、最新一筆的組數）或換了一天才重算。畫面算排課前呼叫，便宜。
    static func sync(_ sessions: [WorkoutSession], now: Date = .now) {
        let day = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let sig = "\(sessions.count)|\(sessions.first?.date.timeIntervalSince1970 ?? 0)|\(sessions.first?.entries.count ?? 0)|\(day)"
        guard sig != signature else { return }
        signature = sig
        refresh(sessions, now: now)
    }

    /// 練完存檔時（紀錄還沒重新讀進來）先記下這次做過的動作，教練講評的「下次預計」才不會又說要減重。
    static func noteFinished(_ ids: [String], at date: Date) {
        guard let c = comeback else { return }
        comeback = Comeback.State(gapDays: c.gapDays, lastBefore: c.lastBefore, returned: c.returned ?? date,
                                  before: c.before, doneAfter: c.doneAfter.union(ids))
    }

    /// `sessions` 由新到舊。
    static func refresh(_ sessions: [WorkoutSession], now: Date = .now) {
        var out: [String: Lift] = [:]
        for s in sessions {
            for e in s.entries where e.isWork && e.weight > 0 && out[e.exerciseId] == nil {
                let best = s.entries.filter { $0.exerciseId == e.exerciseId && $0.isWork && $0.weight > 0 }
                    .map { Comeback.e1rm(weight: $0.weight, reps: $0.reps, rir: $0.rir) }.max() ?? 0
                out[e.exerciseId] = Lift(e1rm: best, date: s.date)
            }
        }
        lifts = out
        comeback = Comeback.detect(sessions, now: now)
    }
}

/// 停練 10 天以上回來（排課 6）：
/// - 每個動作停練後第一次做：10–20 天減 10%、21 天以上減 20%。
/// - 21 天以上：回來那一週當適應期（少 1 組、不拚力竭）。
/// - 減重後第一次全部達標，下次直接回到停練前的重量，不用一級一級爬。
/// 請假的日子也算停練（身體一樣會退）。回來 6 週後就不再看。
enum Comeback {
    static let minDays = 10
    static let bigDays = 21
    static let watchDays = 42

    struct State {
        /// 停了幾天
        let gapDays: Int
        /// 停練前最後一次訓練
        let lastBefore: Date
        /// 回來後第一次訓練；nil = 還沒回來（今天要練的就是回來第一次）
        let returned: Date?
        /// 停練前每個動作最重的正式組重量
        let before: [String: Double]
        /// 回來後做過的動作
        let doneAfter: Set<String>

        var level: Int { gapDays >= Comeback.bigDays ? 2 : 1 }
        /// 第一次回來減幾成
        var cut: Double { level == 2 ? 0.2 : 0.1 }
    }

    static func e1rm(weight: Double, reps: Int, rir: Int) -> Double {
        weight * (1 + Double(reps + (rir < 0 ? 1 : rir)) / 30)
    }

    /// `sessions` 由新到舊。
    static func detect(_ sessions: [WorkoutSession], now: Date = .now) -> State? {
        let cal = Calendar.current
        func days(_ a: Date, _ b: Date) -> Int {
            cal.dateComponents([.day], from: cal.startOfDay(for: a), to: cal.startOfDay(for: b)).day ?? 0
        }
        guard let latest = sessions.first else { return nil }
        var gap = 0
        var splitIndex: Int? = nil   // sessions[splitIndex] = 停練前最後一次
        let idle = days(latest.date, now)
        if idle >= minDays {
            gap = idle
            splitIndex = 0
        } else {
            for i in 0..<(sessions.count - 1) {
                let newer = sessions[i].date, older = sessions[i + 1].date
                if days(newer, now) > watchDays { break }
                let g = days(older, newer)
                if g >= minDays {
                    gap = g
                    splitIndex = i + 1
                    break
                }
            }
        }
        guard let split = splitIndex else { return nil }
        let after = sessions[..<split]
        let beforeSessions = sessions[split...]
        var before: [String: Double] = [:]
        for s in beforeSessions {
            for e in s.entries where e.isWork && e.weight > 0 && before[e.exerciseId] == nil {
                before[e.exerciseId] = s.entries.filter { $0.exerciseId == e.exerciseId && $0.isWork }.map(\.weight).max()
            }
        }
        let doneAfter = Set(after.flatMap { $0.entries.filter(\.isWork).map(\.exerciseId) })
        return State(gapDays: gap, lastBefore: sessions[split].date, returned: after.last?.date,
                     before: before, doneAfter: doneAfter)
    }

    /// 停 21 天以上：回來那一週（從回來第一次訓練算 7 天）當適應期。
    static var rampUpActive: Bool {
        guard let s = TrainingHistory.comeback, s.level == 2 else { return false }
        guard let r = s.returned else { return true }
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: r)) ?? r
        return Date.now < end
    }

    /// 停練回來的建議；不適用回傳 nil。lastWeight = 上次最重的正式組；allHit = 上次全部達標。
    static func suggest(_ item: PlannedExercise, lastWeight: Double, bestReps: Int, allHit: Bool,
                        ladder: WeightLadder) -> Suggestion? {
        let ex = item.exercise
        guard ex.loaded, let s = TrainingHistory.comeback, let pre = s.before[ex.id], pre > 0 else { return nil }
        if !s.doneAfter.contains(ex.id) {
            let w = ladder.snap(pre * (1 - s.cut))
            return Suggestion(weight: w, reps: min(max(bestReps, item.low), item.high),
                              note: "隔了 \(s.gapDays) 天沒練：重量先減 \(Int(s.cut * 100))%，找回感覺就好",
                              tip: .comeback)
        }
        if allHit && pre > lastWeight + 0.01 {
            let w = ladder.snap(pre)
            guard w > lastWeight + 0.01 else { return nil }
            return Suggestion(weight: w, reps: item.low,
                              note: "上次全部達標：直接回到停練前的 \(Progression.format(w)) kg",
                              tip: .comeback)
        }
        return nil
    }
}
