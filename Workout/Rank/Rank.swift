import Foundation

/// 牌位：鐵 → 銅 → 銀 → 金 → 白金 → 鑽石（各 III/II/I 三小段）→ 大師 → 王者。
enum RankTier: Int, CaseIterable, Identifiable {
    case iron, bronze, silver, gold, platinum, diamond, master, champion

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .iron: "鐵牌"
        case .bronze: "銅牌"
        case .silver: "銀牌"
        case .gold: "金牌"
        case .platinum: "白金"
        case .diamond: "鑽石"
        case .master: "大師"
        case .champion: "王者"
        }
    }

    /// 每個小段要幾分；大師、王者沒有小段。
    var divisionSize: Int {
        switch self {
        case .iron: 50
        case .bronze: 75
        case .silver: 100
        case .gold: 125
        case .platinum: 150
        case .diamond: 200
        case .master: 900
        case .champion: 0
        }
    }

    var hasDivisions: Bool { rawValue <= RankTier.diamond.rawValue }

    /// 進入這個牌位需要的總分。
    var floor: Int {
        RankTier.allCases.prefix(rawValue).reduce(0) { $0 + $1.span }
    }

    /// 整個牌位的分數寬度。
    var span: Int { hasDivisions ? divisionSize * 3 : divisionSize }
}

struct Rank: Equatable {
    let points: Int
    let tier: RankTier
    /// 3 = III（最低）… 1 = I；大師、王者為 nil。
    let division: Int?
    /// 這一段已經拿到的分數。
    let progress: Int
    /// 這一段的總分；王者為 0。
    let size: Int

    init(points: Int) {
        let p = max(0, points)
        self.points = p
        let tier = RankTier.allCases.last { p >= $0.floor } ?? .iron
        self.tier = tier
        let inTier = p - tier.floor
        if tier.hasDivisions {
            let step = min(2, inTier / tier.divisionSize)
            division = 3 - step
            progress = inTier - step * tier.divisionSize
            size = tier.divisionSize
        } else {
            division = nil
            progress = inTier
            size = tier.divisionSize
        }
    }

    /// 用來比大小、判斷晉級或降級。
    var index: Int { tier.rawValue * 3 + (3 - (division ?? 3)) }

    var title: String {
        guard let d = division else { return tier.name }
        return "\(tier.name) \(["I", "II", "III"][d - 1])"
    }

    var fraction: Double { size > 0 ? min(1, Double(progress) / Double(size)) : 1 }

    var toNext: Int? { size > 0 ? size - progress : nil }

    var nextTitle: String? {
        guard toNext != nil else { return nil }
        return Rank(points: points + (toNext ?? 0)).title
    }
}

/// 積分的一筆加減紀錄。
struct RankEvent: Identifiable {
    let id = UUID()
    let date: Date
    let delta: Int
    let reason: String
}

/// 從訓練紀錄算出積分；不另外存資料，所以刪紀錄、改週目標都會自動重算。
enum RankEngine {
    static let fullPoints = 20
    static let shortPoints = 12
    static let minimalPoints = 5
    static let goalBonus = 15
    static let streakStep = 5
    static let streakMax = 20
    static let prPoints = 5
    static let prCap = 15
    static let emptyWeekPenalty = 50
    static let lightWeekPenalty = 20

    static func points(for length: WorkoutLength) -> Int {
        switch length {
        case .full: fullPoints
        case .short: shortPoints
        case .minimal: minimalPoints
        }
    }

    static func ledger(sessions: [WorkoutSession], goal: Int, now: Date = .now) -> [RankEvent] {
        let ordered = sessions.sorted { $0.date < $1.date }
        guard let first = ordered.first else { return [] }
        let cal = Stats.calendar
        var events: [RankEvent] = []

        // 每次訓練＋破紀錄加分。破紀錄的定義跟進步頁、角色里程碑一樣：
        // 有負重的動作，重量超過這個動作以前的最高重量（第一次做不算）。
        var best: [String: Double] = [:]
        for s in ordered {
            events.append(RankEvent(date: s.date, delta: points(for: s.length), reason: "完成訓練（\(s.length.title)）"))
            var prs = 0
            let byExercise = Dictionary(grouping: s.entries.filter { $0.weight > 0 }, by: \.exerciseId)
            for (id, sets) in byExercise {
                guard ExerciseLibrary.byId(id)?.loaded == true else { continue }
                let top = sets.map(\.weight).max() ?? 0
                if let old = best[id] {
                    if top > old { prs += 1; best[id] = top }
                } else {
                    best[id] = top
                }
            }
            if prs > 0 {
                events.append(RankEvent(date: s.date, delta: min(prCap, prs * prPoints), reason: "破個人紀錄 × \(prs)"))
            }
        }

        // 每週結算：達標加分、連續達標加碼；沒練的週扣分。本週還沒結束，不結算。
        let thisWeek = Stats.weekStart(now)
        var week = Stats.weekStart(first.date)
        var streak = 0
        while week < thisWeek {
            let next = cal.date(byAdding: .weekOfYear, value: 1, to: week)!
            let settle = next.addingTimeInterval(-1)
            let count = ordered.filter { $0.date >= week && $0.date < next }.count
            if count >= goal {
                streak += 1
                let extra = min(streakMax, (streak - 1) * streakStep)
                events.append(RankEvent(date: settle, delta: goalBonus + extra,
                                        reason: streak > 1 ? "週目標達成（連續 \(streak) 週）" : "週目標達成"))
            } else {
                streak = 0
                if count == 0 {
                    events.append(RankEvent(date: settle, delta: -emptyWeekPenalty, reason: "整週沒練"))
                } else if count == 1 && goal > 1 {
                    events.append(RankEvent(date: settle, delta: -lightWeekPenalty, reason: "這週只練 1 次"))
                }
            }
            week = next
        }
        return events.sorted { $0.date < $1.date }
    }

    /// 依序加總，分數不會低於 0。
    static func total(_ events: [RankEvent]) -> Int {
        events.reduce(0) { max(0, $0 + $1.delta) }
    }

    static func rank(sessions: [WorkoutSession], goal: Int, now: Date = .now) -> Rank {
        Rank(points: total(ledger(sessions: sessions, goal: goal, now: now)))
    }
}
