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
    enum Kind { case workout, record, weekly, quest, comeback, shield, bet }

    let id = UUID()
    let date: Date
    let delta: Int
    let reason: String
    var kind: Kind = .workout
    /// 不加減分的項目（保護卡、押注、請假週）顯示這段文字代替分數。
    var valueText: String? = nil

    /// 週一結算畫面要秀的項目。
    var isSettlement: Bool { kind == .weekly || kind == .shield || kind == .bet }

    var displayValue: String {
        valueText ?? (delta >= 0 ? "+\(delta)" : "−\(abs(delta))")
    }
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

    static func ledger(sessions: [WorkoutSession], goal: Int, now: Date = .now,
                       ctx: GoalContext = .load()) -> [RankEvent] {
        let facts = GoalEngine.facts(sessions)
        guard !facts.isEmpty else { return [] }
        var events: [RankEvent] = []

        // 每次訓練＋破紀錄加分。破紀錄的定義跟進步頁、角色里程碑一樣：
        // 有負重的動作，重量超過這個動作以前的最高重量（第一次做不算）。
        for f in facts {
            events.append(RankEvent(date: f.date, delta: points(for: f.length), reason: "完成訓練（\(f.length.title)）"))
            if f.prs > 0 {
                events.append(RankEvent(date: f.date, delta: min(prCap, f.prs * prPoints), reason: "破個人紀錄 × \(f.prs)", kind: .record))
            }
        }

        // 逆轉：漏掉排好的日子後馬上練回來
        for d in GoalEngine.comebacks(facts: facts, ctx: ctx) {
            events.append(RankEvent(date: d, delta: GoalEngine.comebackPoints, reason: "逆轉：漏練後練回來", kind: .comeback))
        }

        // 週任務：每完成一項加分
        let dates = facts.map(\.date)
        for w in GoalEngine.questWeeks(facts: facts, dates: dates, goal: goal, ctx: ctx, now: now) {
            for q in w.quests {
                if let at = q.doneAt {
                    events.append(RankEvent(date: at, delta: GoalEngine.questPoints, reason: "週任務：\(q.title)", kind: .quest))
                }
            }
        }

        // 每週結算：達標加分、連續達標加碼；沒練的週扣分。本週還沒結束，不結算。
        // 新規則（這版裝上之後的週）：請假會降低週目標、請假 4 天以上不結算、保護卡、排程排不出來的週不罰。
        for r in GoalEngine.weeks(dates: dates, goal: goal, ctx: ctx, now: now) {
            let settle = r.end.addingTimeInterval(-1)
            switch r.outcome {
            case .met:
                let extra = min(streakMax, (r.rankStreak - 1) * streakStep)
                var reason = r.rankStreak > 1 ? "週目標達成（連續 \(r.rankStreak) 週）" : "週目標達成"
                if r.goal < goal { reason += "・請假後目標 \(r.goal) 次" }
                events.append(RankEvent(date: settle, delta: goalBonus + extra, reason: reason, kind: .weekly))
                if r.shieldEarned {
                    events.append(RankEvent(date: settle, delta: 0, reason: "練滿一週，得到 1 張保護卡", kind: .shield, valueText: "+1 卡"))
                }
            case .excused:
                events.append(RankEvent(date: settle, delta: 0, reason: "請假 \(r.excusedDays) 天，這週不結算", kind: .weekly, valueText: "不結算"))
            case .shielded:
                events.append(RankEvent(date: settle, delta: 0, reason: "用掉 1 張保護卡，連續不中斷", kind: .shield, valueText: "保護"))
            case .missed:
                let lenient = r.isNew && r.planned != nil
                let planned = r.planned ?? 0
                if r.count == 0 {
                    if lenient && planned == 0 {
                        events.append(RankEvent(date: settle, delta: 0, reason: "這週排程排不出時間，不扣分", kind: .weekly, valueText: "不扣分"))
                    } else {
                        events.append(RankEvent(date: settle, delta: -emptyWeekPenalty, reason: "整週沒練", kind: .weekly))
                    }
                } else if r.count == 1 && r.goal > 1 {
                    if lenient && planned < 2 {
                        events.append(RankEvent(date: settle, delta: 0, reason: "這週只排得出 \(planned) 天，不扣分", kind: .weekly, valueText: "不扣分"))
                    } else {
                        events.append(RankEvent(date: settle, delta: -lightWeekPenalty, reason: "這週只練 1 次", kind: .weekly))
                    }
                }
            }
            for b in ctx.bets where b.week == r.start {
                switch r.outcome {
                case .met:
                    events.append(RankEvent(date: settle, delta: 0, reason: "押注 \(b.stake) 碎片：達標", kind: .bet, valueText: "+\(b.stake * 2) 碎片"))
                case .excused:
                    events.append(RankEvent(date: settle, delta: 0, reason: "押注 \(b.stake) 碎片：請假週退回", kind: .bet, valueText: "退回"))
                default:
                    events.append(RankEvent(date: settle, delta: 0, reason: "押注 \(b.stake) 碎片：沒達標", kind: .bet, valueText: "−\(b.stake) 碎片"))
                }
            }
        }
        return events.sorted { $0.date < $1.date }
    }

    /// 依序加總，分數不會低於 0。
    static func total(_ events: [RankEvent]) -> Int {
        events.reduce(0) { max(0, $0 + $1.delta) }
    }

    static func rank(sessions: [WorkoutSession], goal: Int, now: Date = .now, ctx: GoalContext = .load()) -> Rank {
        Rank(points: total(ledger(sessions: sessions, goal: goal, now: now, ctx: ctx)))
    }
}

/// 牌位的一格（階＋小段），晉級畫面用來表示「從哪裡到哪裡」。
struct RankStep: Equatable {
    let tier: RankTier
    /// 3 = III … 1 = I；大師、王者為 nil
    let division: Int?

    init(tier: RankTier, division: Int?) {
        self.tier = tier
        self.division = tier.hasDivisions ? division : nil
    }

    init(_ rank: Rank) {
        self.init(tier: rank.tier, division: rank.division)
    }

    /// 由 Rank.index 反推。
    init(index: Int) {
        let t = RankTier(rawValue: max(0, min(RankTier.champion.rawValue, index / 3))) ?? .iron
        self.init(tier: t, division: t.hasDivisions ? 3 - index % 3 : nil)
    }

    var index: Int { tier.rawValue * 3 + (3 - (division ?? 3)) }

    var title: String {
        guard let d = division else { return tier.name }
        return "\(tier.name) \(["I", "II", "III"][d - 1])"
    }
}
