import Foundation

/// 一次訓練裡引擎需要的數字。
struct SessionFact {
    let date: Date
    let length: WorkoutLength
    let dayKey: String
    let workSets: Int
    /// 破了幾個動作的個人紀錄（定義同牌位）
    let prs: Int
    /// 正式組的重量 × 次數
    let volume: Double
}

/// 一週的結算結果（只有已經結束的週）。
struct WeekRecord {
    enum Outcome { case met, excused, shielded, missed }

    let start: Date
    let end: Date
    let count: Int
    /// 扣掉請假後的週目標
    let goal: Int
    let excusedDays: Int
    /// 排程排了幾天（扣掉請假）；nil = 沒有排程紀錄
    let planned: Int?
    /// 這週適用新規則
    let isNew: Bool
    var outcome: Outcome = .missed
    /// 這週結束後的「連續達標」週數（牌位加碼用）
    var rankStreak = 0
    /// 這週結束後的「每週練 2 次以上」連續週數
    var minStreak = 0
    /// 這週結束後手上的保護卡
    var shields = 0
    var shieldUsed = false
    var shieldEarned = false
}

struct Quest: Identifiable {
    enum Kind: String { case goal, record, fullTwice, upperLower, sets, onPlan }

    let kind: Kind
    let target: Int
    var current = 0
    var doneAt: Date?

    var id: String { kind.rawValue }
    var done: Bool { doneAt != nil }

    var title: String {
        switch kind {
        case .goal: "練滿這週的目標 \(target) 次"
        case .record: "破 1 次個人紀錄"
        case .fullTwice: "完成 2 次完整版"
        case .upperLower: "上半身、下半身各練 1 次"
        case .sets: "這週完成 \(target) 組正式組"
        case .onPlan: "在排好的日子練 \(target) 次"
        }
    }

    var icon: String {
        switch kind {
        case .goal: "target"
        case .record: "trophy.fill"
        case .fullTwice: "flame.fill"
        case .upperLower: "figure.strengthtraining.traditional"
        case .sets: "square.stack.3d.up.fill"
        case .onPlan: "calendar.badge.checkmark"
        }
    }
}

/// 請假、排程紀錄、保護卡、週任務、押注、逆轉、狀態的規則。全部由訓練紀錄＋GoalContext 算出。
enum GoalEngine {
    static let shieldCap = 2
    static let shieldPrice = 50
    static let questPoints = 10
    static let comebackPoints = 10
    static let betStakes = [20, 50, 100]
    static let setsQuest = 40
    /// 一週請假（或整天活動）幾天以上就不結算
    static let excusedWeekDays = 4

    private static var cal: Calendar { SharedStore.calendar }

    static var savedGoal: Int {
        let g = UserDefaults.standard.integer(forKey: Keys.weeklyGoal)
        return g == 0 ? 4 : g
    }

    // MARK: 訓練摘要

    static func facts(_ sessions: [WorkoutSession]) -> [SessionFact] {
        let ordered = sessions.sorted { $0.date < $1.date }
        var best: [String: PRBest] = [:]
        return ordered.map { s in
            let work = s.entries.filter(\.isWork)
            var prs = 0
            let byExercise = Dictionary(grouping: work.filter { $0.weight > 0 }, by: \.exerciseId)
            for (id, sets) in byExercise {
                guard ExerciseLibrary.byId(id)?.loaded == true else { continue }
                // 重量紀錄或次數紀錄（`PRRule`）
                let r = PRRule.session(sets: sets.sorted { $0.setIndex < $1.setIndex }.map { (weight: $0.weight, reps: $0.reps) },
                                       best: best[id])
                if r.pr { prs += 1 }
                best[id] = r.best
            }
            let volume = work.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
            return SessionFact(date: s.date, length: s.length, dayKey: s.dayKey,
                               workSets: work.count, prs: prs, volume: volume)
        }
    }

    // MARK: 週

    static func days(of week: Date) -> [Date] {
        (0..<7).map { cal.date(byAdding: .day, value: $0, to: week)! }
    }

    static func adjustedGoal(_ goal: Int, excusedDays: Int) -> Int {
        max(1, goal - excusedDays / 2)
    }

    static func excusedDays(week: Date, ctx: GoalContext) -> Int {
        days(of: week).filter { ctx.excused($0) }.count
    }

    /// 已經結束的每一週，從第一次訓練那週到上週。
    static func weeks(dates: [Date], goal: Int, ctx: GoalContext, now: Date = .now) -> [WeekRecord] {
        guard let first = dates.min() else { return [] }
        let thisWeek = SharedStore.weekStart(now)
        var week = SharedStore.weekStart(first)
        var out: [WeekRecord] = []
        var rankStreak = 0, minStreak = 0, shields = 0
        while week < thisWeek {
            let next = cal.date(byAdding: .weekOfYear, value: 1, to: week)!
            let count = SharedStore.trainingDays(dates.filter { $0 >= week && $0 < next })
            let isNew = week >= ctx.since
            let excused = isNew ? excusedDays(week: week, ctx: ctx) : 0
            var planned: Int?
            if isNew {
                let ds = days(of: week)
                if ds.contains(where: { ctx.planned($0) != nil }) {
                    planned = ds.filter { ctx.planned($0) == true && !ctx.excused($0) }.count
                }
                shields = min(shieldCap, shields + ctx.shieldBuys.filter { $0 >= week && $0 < next }.count)
            }
            let g = isNew ? adjustedGoal(goal, excusedDays: excused) : goal
            var r = WeekRecord(start: week, end: next, count: count, goal: g, excusedDays: excused,
                               planned: planned, isNew: isNew)
            if count >= g {
                r.outcome = .met
                rankStreak += 1
                if isNew && shields < shieldCap { shields += 1; r.shieldEarned = true }
            } else if isNew && excused >= excusedWeekDays {
                r.outcome = .excused
            } else if isNew && shields > 0 && (rankStreak > 0 || (count < 2 && minStreak > 0)) {
                r.outcome = .shielded
                shields -= 1
                r.shieldUsed = true
            } else {
                r.outcome = .missed
                rankStreak = 0
            }
            if count >= 2 { minStreak += 1 } else if r.outcome == .missed { minStreak = 0 }
            r.rankStreak = rankStreak
            r.minStreak = minStreak
            r.shields = shields
            out.append(r)
            week = next
        }
        return out
    }

    /// 本週的狀況。
    struct Current {
        let week: Date
        let count: Int
        let goal: Int
        let excusedDays: Int
        let shields: Int
        /// 每週練 2 次以上的連續週數（含本週，本週還沒滿 2 次就從上週算起）
        let streak: Int
    }

    static func current(dates: [Date], goal: Int, ctx: GoalContext, now: Date = .now) -> Current {
        let week = SharedStore.weekStart(now)
        let recs = weeks(dates: dates, goal: goal, ctx: ctx, now: now)
        let count = SharedStore.trainingDays(dates.filter { $0 >= week })
        let isNew = week >= ctx.since
        let excused = isNew ? excusedDays(week: week, ctx: ctx) : 0
        var shields = recs.last?.shields ?? 0
        if isNew {
            let buys = ctx.shieldBuys.filter { $0 >= week || (recs.isEmpty && $0 >= ctx.since) }.count
            shields = min(shieldCap, shields + buys)
        }
        let base = recs.last?.minStreak ?? 0
        return Current(week: week, count: count, goal: isNew ? adjustedGoal(goal, excusedDays: excused) : goal,
                       excusedDays: excused, shields: shields, streak: base + (count >= 2 ? 1 : 0))
    }

    /// 連續週數（請假週、用保護卡的週不會中斷）。
    static func streak(dates: [Date], goal: Int = savedGoal, ctx: GoalContext = .load(), now: Date = .now) -> Int {
        current(dates: dates, goal: goal, ctx: ctx, now: now).streak
    }

    // MARK: 週任務

    private static let pool: [Quest.Kind] = [.record, .fullTwice, .upperLower, .sets, .onPlan]

    static func questKinds(week: Date) -> [Quest.Kind] {
        let w = Int((week.timeIntervalSince1970 / 604_800).rounded())
        let n = pool.count
        let a = ((w % n) + n) % n
        let b = (a + 1 + ((w / n) % (n - 1) + (n - 1)) % (n - 1)) % n
        return [.goal, pool[a], pool[b]]
    }

    static func quests(week: Date, facts: [SessionFact], goal: Int, ctx: GoalContext) -> [Quest] {
        let next = cal.date(byAdding: .weekOfYear, value: 1, to: week)!
        let inWeek = facts.filter { $0.date >= week && $0.date < next }
        return questKinds(week: week).map { kind in
            let target: Int
            switch kind {
            case .goal: target = goal
            case .record: target = 1
            case .fullTwice: target = 2
            case .upperLower: target = 2
            case .sets: target = setsQuest
            case .onPlan: target = min(3, goal)
            }
            var q = Quest(kind: kind, target: target)
            var upper = false, lower = false
            var days = Set<Date>()
            for f in inWeek {
                switch kind {
                case .goal:
                    // 同一天練兩次算 1 天
                    days.insert(cal.startOfDay(for: f.date))
                    q.current = days.count
                case .record: q.current += f.prs
                case .fullTwice: if f.length == .full { q.current += 1 }
                case .upperLower:
                    let h = ProgramBuilder.template(id: f.dayKey)?.halves
                        ?? (upper: f.dayKey.hasPrefix("upper"), lower: f.dayKey.hasPrefix("lower"))
                    if h.upper { upper = true }
                    if h.lower { lower = true }
                    q.current = (upper ? 1 : 0) + (lower ? 1 : 0)
                case .sets: q.current += f.workSets
                case .onPlan:
                    if ctx.planned(cal.startOfDay(for: f.date)) == true { q.current += 1 }
                }
                if q.doneAt == nil && q.current >= target { q.doneAt = f.date }
            }
            return q
        }
    }

    /// 適用新規則的每一週（含本週）的週任務。
    static func questWeeks(facts: [SessionFact], dates: [Date], goal: Int, ctx: GoalContext, now: Date = .now)
    -> [(week: Date, quests: [Quest])] {
        let thisWeek = SharedStore.weekStart(now)
        guard ctx.since <= thisWeek else { return [] }
        var out: [(week: Date, quests: [Quest])] = []
        var week = ctx.since
        while week <= thisWeek {
            let g = adjustedGoal(goal, excusedDays: excusedDays(week: week, ctx: ctx))
            out.append((week: week, quests: quests(week: week, facts: facts, goal: g, ctx: ctx)))
            week = cal.date(byAdding: .weekOfYear, value: 1, to: week)!
        }
        return out
    }

    /// 三個週任務都完成的週，各送 1 個補給箱。
    static func bonusBoxes(facts: [SessionFact], goal: Int, ctx: GoalContext, now: Date = .now) -> Int {
        questWeeks(facts: facts, dates: facts.map(\.date), goal: goal, ctx: ctx, now: now)
            .filter { $0.quests.allSatisfy(\.done) }.count
    }

    /// 補給箱總數：每次訓練 1 箱 + 週任務全破的獎勵箱。
    static func boxTotal(sessions: [WorkoutSession], goal: Int = savedGoal) -> Int {
        // 每天最多一箱（同一天練好幾次不會多拿）
        SharedStore.trainingDays(sessions.map(\.date)) + bonusBoxes(facts: facts(sessions), goal: goal, ctx: .load())
    }

    // MARK: 逆轉

    /// 漏掉排好的練習日後，第一次練回來的訓練。
    static func comebacks(facts: [SessionFact], ctx: GoalContext) -> [Date] {
        var out: [Date] = []
        for f in facts where f.date >= ctx.since {
            let day = cal.startOfDay(for: f.date)
            for back in 1...7 {
                let d = cal.date(byAdding: .day, value: -back, to: day)!
                if d < ctx.since { break }
                if ctx.planned(d) == true && !ctx.excused(d) {
                    if !facts.contains(where: { $0.date >= d && $0.date < day }) { out.append(f.date) }
                    break
                }
            }
        }
        return out
    }

    // MARK: 漏練

    /// 上一個排好的練習日沒練，而且之後也還沒練。沒有排程紀錄時用舊規則（3 天以上沒練）。
    static func missedLastPlanned(dates: [Date], ctx: GoalContext = .load(), now: Date = .now) -> Bool {
        let c = Calendar.current
        let today = c.startOfDay(for: now)
        if dates.contains(where: { $0 >= today }) || ctx.excused(today) { return false }
        guard ctx.hasLog else {
            guard let last = dates.max() else { return false }
            let gap = c.dateComponents([.day], from: c.startOfDay(for: last), to: today).day ?? 0
            return gap >= 3
        }
        guard !dates.isEmpty else { return false }
        for back in 1...7 {
            let d = c.date(byAdding: .day, value: -back, to: today)!
            if ctx.planned(d) == true && !ctx.excused(d) {
                return !dates.contains { $0 >= d }
            }
        }
        return false
    }

    // MARK: 狀態

    /// 距離上次訓練（請假日不算）：2 天內 100，之後每天 −15。沒有紀錄回傳 nil。
    static func condition(dates: [Date], ctx: GoalContext = .load(), now: Date = .now) -> Int? {
        guard let last = dates.max() else { return nil }
        let c = Calendar.current
        let today = c.startOfDay(for: now)
        var d = c.date(byAdding: .day, value: 1, to: c.startOfDay(for: last))!
        var idle = 0
        while d < today {
            if !ctx.excused(d) { idle += 1 }
            d = c.date(byAdding: .day, value: 1, to: d)!
        }
        return idle <= 1 ? 100 : max(0, 100 - 15 * (idle - 1))
    }

    static func conditionName(_ v: Int) -> String {
        switch v {
        case 80...: "巔峰"
        case 50..<80: "普通"
        case 25..<50: "疲軟"
        default: "生鏽"
        }
    }

    // MARK: 押注

    enum BetResult { case pending, won, lost, refunded }

    static func result(of bet: Bet, records: [WeekRecord]) -> BetResult {
        guard let r = records.first(where: { $0.start == bet.week }) else {
            return bet.week < SharedStore.weekStart(.now) ? .lost : .pending
        }
        switch r.outcome {
        case .met: return .won
        case .excused: return .refunded
        default: return .lost
        }
    }

    /// 已經結束的週，把押注的碎片入帳。回傳這次入帳的碎片數。
    @discardableResult
    static func settleBets(sessions: [WorkoutSession], goal: Int = savedGoal, inventory: InventoryStore) -> Int {
        var bets = GoalStore.bets()
        guard bets.contains(where: { !$0.paid }) else { return 0 }
        let records = weeks(dates: sessions.map(\.date), goal: goal, ctx: .load())
        var gain = 0
        for i in bets.indices where !bets[i].paid {
            switch result(of: bets[i], records: records) {
            case .pending: continue
            case .won: gain += bets[i].stake * 2
            case .refunded: gain += bets[i].stake
            case .lost: break
            }
            bets[i].paid = true
        }
        GoalStore.saveBets(bets)
        if gain > 0 { inventory.state.shards += gain }
        return gain
    }

    /// 這週只能在週一、週二押；下週隨時可押。每週只能押一次。
    static func canBet(week: Date, now: Date = .now) -> Bool {
        let thisWeek = SharedStore.weekStart(now)
        if GoalStore.bets().contains(where: { $0.week == week }) { return false }
        if week == thisWeek {
            let wd = Calendar.current.component(.weekday, from: now)
            return wd == 2 || wd == 3
        }
        return week == cal.date(byAdding: .weekOfYear, value: 1, to: thisWeek)!
    }
}
