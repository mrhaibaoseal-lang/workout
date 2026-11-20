import Foundation

// MARK: - Inputs

struct FightSet {
    let exerciseId: String
    let weight: Double
    let reps: Int

    /// Estimated 1RM for loaded sets, reps for bodyweight ones.
    var score: Double { weight > 0 ? weight * (1 + Double(reps) / 30) : Double(reps) }
    var tonnage: Double { weight * Double(reps) }
}

struct FightInput {
    let date: Date
    let length: WorkoutLength
    let dayKey: String
    let sets: [FightSet]

    var isUpper: Bool { dayKey.hasPrefix("upper") }
}

extension FightInput {
    init(_ s: WorkoutSession) {
        self.init(date: s.date, length: s.length, dayKey: s.dayKey,
                  sets: s.entries.map { FightSet(exerciseId: $0.exerciseId, weight: $0.weight, reps: $0.reps) })
    }
}

struct CareerInputs {
    var sessions: [FightInput]
    var planLog: [Date: PlanLogEntry]
    var leave: Set<Date>
    var bets: [Date: Int]
    var cardBuys: [Date]
    var goal: Int
    var startDate: Date
    var now: Date

    static func load(_ sessions: [FightInput], now: Date = .now) -> CareerInputs {
        let d = UserDefaults.standard
        let goal = d.integer(forKey: Keys.weeklyGoal)
        let start = d.double(forKey: Keys.startDate)
        let first = sessions.map(\.date).min() ?? now
        var bets: [Date: Int] = [:]
        for b in CareerStore.bets() { bets[b.weekStart] = b.stake }
        return CareerInputs(
            sessions: sessions,
            planLog: CareerStore.planLog(),
            leave: Set(CareerStore.leaves().map(\.day)),
            bets: bets,
            cardBuys: CareerStore.cardBuys(),
            goal: goal == 0 ? 4 : goal,
            startDate: start == 0 ? first : Date(timeIntervalSince1970: start),
            now: now
        )
    }
}

// MARK: - Outputs

struct CareerEvent: Identifiable {
    enum Mood { case good, bad, neutral }
    let id = UUID()
    let date: Date
    let mood: Mood
    let title: String
    let detail: String
}

struct FightReport {
    var date: Date
    var fightNumber = 0
    var method: FightMethod = .dec
    var lines: [(String, Int)] = []
    var multiplier = 1.0
    var xp = 0
    var purse = 0
    var points = 0
    var prs: [String] = []
    var comeback = false
    var drop: (item: Cosmetic, duplicate: Bool)?
    var levelBefore = 1
    var levelAfter = 1
    var quests: [String] = []
    var milestones: [String] = []
    var badges: [String] = []
    var tierBefore: Tier = .amateur
    var tierAfter: Tier = .amateur
    var recordAfter = ""
}

struct QuestStatus: Identifiable {
    let kind: QuestKind
    let title: String
    let progress: Int
    let target: Int
    var id: String { kind.rawValue }
    var done: Bool { progress >= target }
}

struct CampStatus {
    var index = 0
    var start = Date()
    var end = Date()
    var sessions = 0
    var requirement = 1
    var milestones = 0
    var fightKind = "排名賽"
    var opponent: (nick: String, name: String) = Opponents.forCamp(0)
}

struct CareerState {
    var xp = 0
    var purse = 0
    var points = 0
    var wins = 0
    var ko = 0
    var sub = 0
    var dec = 0
    var forfeits = 0
    var campWins = 0
    var campLosses = 0
    var champion = false
    var defenses = 0
    var titlesWon = 0
    var streak = 0
    var bestStreak = 0
    var cards = 0
    var prCount = 0
    var questsDone = 0
    var betsWon = 0
    var tonnage: Double = 0
    var owned: Set<String> = Cosmetics.defaults
    var badges: [String: Date] = [:]
    var events: [CareerEvent] = []
    var reports: [FightReport] = []
    var pendingMiss: Date?
    var idleDays = 0
    var weekSessions = 0
    var quests: [QuestStatus] = []
    var camp = CampStatus()

    var recordWins: Int { wins + campWins }
    var recordLosses: Int { forfeits + campLosses }
    var record: String { "\(recordWins)–\(recordLosses)" }

    var level: Int { Leveling.level(xp: xp).level }
    var tier: Tier { Tier.of(points: points, champion: champion) }
    var rankNumber: Int? { champion ? nil : Tier.rankNumber(points: points) }

    var rankText: String {
        if let n = rankNumber { return "\(tier.title) #\(n)" }
        return tier.title
    }

    /// Completed-week streak plus this week once it counts.
    var displayStreak: Int { streak + (weekSessions >= 2 ? 1 : 0) }

    /// 100 for two idle days, then −15 a day.
    var condition: Int { idleDays <= 2 ? 100 : max(0, 100 - 15 * (idleDays - 2)) }

    var conditionTitle: String {
        switch condition {
        case 80...: "巔峰"
        case 50..<80: "普通"
        case 25..<50: "疲軟"
        default: "生鏽"
        }
    }

    func gearLevel(_ g: GearKind) -> Int {
        switch g {
        case .gloves: min(10, 1 + prCount / 3)
        case .shin: 1 + GearKind.shinWins.filter { recordWins >= $0 }.count
        case .shorts: min(10, 1 + campWins)
        case .robe: 1 + GearKind.robeStreaks.filter { bestStreak >= $0 }.count
        case .belt: champion ? 1 + defenses : 0
        }
    }

    func gearNext(_ g: GearKind) -> String {
        switch g {
        case .gloves:
            return gearLevel(g) >= 10 ? "已滿級" : "再破 \(3 - prCount % 3) 次紀錄升級"
        case .shin:
            guard let next = GearKind.shinWins.first(where: { recordWins < $0 }) else { return "已滿級" }
            return "再 \(next - recordWins) 勝升級"
        case .shorts:
            return gearLevel(g) >= 10 ? "已滿級" : "贏下一場訓練營比賽升級"
        case .robe:
            guard let next = GearKind.robeStreaks.first(where: { bestStreak < $0 }) else { return "已滿級" }
            return "最長連續達 \(next) 週升級"
        case .belt:
            return champion ? "已衛冕 \(defenses) 次" : "贏下頭銜戰"
        }
    }
}

enum Leveling {
    static func need(_ level: Int) -> Int { 200 + 100 * level }

    static func level(xp: Int) -> (level: Int, into: Int, need: Int) {
        var lv = 1
        var rest = xp
        while rest >= need(lv) {
            rest -= need(lv)
            lv += 1
        }
        return (lv, rest, need(lv))
    }
}

// MARK: - Engine

/// Replays the whole history day by day. Deterministic: same inputs, same career.
enum CareerEngine {
    static let campDays = 42

    static func run(_ input: CareerInputs) -> CareerState {
        var replay = Replay(input)
        return replay.run()
    }

    static func current(_ sessions: [WorkoutSession], now: Date = .now) -> CareerState {
        run(CareerInputs.load(sessions.map(FightInput.init), now: now))
    }
}

private struct Replay {
    let input: CareerInputs
    let cal = SharedStore.calendar
    var s = CareerState()

    // Per-exercise history
    var best: [String: Double] = [:]

    // Day bookkeeping
    var missStreak = 0
    var hasTrained = false
    var decayAnnounced = false

    // Week aggregates
    var weekStart = Date.distantPast
    var wSets = 0
    var wPRs = 0
    var wKO = 0
    var wUpper = 0
    var wLower = 0
    var wOnTime = 0
    var wExcused = 0
    var wQuestsDone: Set<QuestKind> = []

    // Camp aggregates
    var campIndex = 0
    var campExcused = 0

    // Current report (while processing a session)
    var report: FightReport?

    init(_ input: CareerInputs) {
        self.input = input
    }

    var campStart: Date { cal.startOfDay(for: input.startDate) }

    func campOf(_ day: Date) -> Int {
        let d = cal.dateComponents([.day], from: campStart, to: day).day ?? 0
        return d < 0 ? -1 : d / CareerEngine.campDays
    }

    func campRange(_ index: Int) -> (Date, Date) {
        let start = cal.date(byAdding: .day, value: index * CareerEngine.campDays, to: campStart)!
        let end = cal.date(byAdding: .day, value: CareerEngine.campDays, to: start)!
        return (start, end)
    }

    var requirement: Int {
        let base = Int((Double(input.goal * 6) * 0.7).rounded(.up))
        return max(1, base - campExcused / 2)
    }

    func excused(_ day: Date) -> Bool {
        input.leave.contains(day) || (input.planLog[day]?.excused ?? false)
    }

    mutating func run() -> CareerState {
        let sessions = input.sessions.sorted { $0.date < $1.date }
        let today = cal.startOfDay(for: input.now)

        if let first = sessions.first {
            var day = cal.startOfDay(for: first.date)
            var idx = 0
            beginWeek(SharedStore.weekStart(day))
            campIndex = max(0, campOf(day))
            let buys = input.cardBuys.sorted()
            var buyIdx = 0

            while day <= today {
                let next = cal.date(byAdding: .day, value: 1, to: day)!

                while buyIdx < buys.count && buys[buyIdx] < next {
                    if buys[buyIdx] >= day, s.purse >= 300, s.cards < 2 {
                        s.purse -= 300
                        s.cards += 1
                        event(day, .neutral, "買了一張保護卡", "花 300 獎金")
                    }
                    buyIdx += 1
                }

                var trainedToday = false
                while idx < sessions.count && sessions[idx].date < next {
                    fight(sessions[idx], day: day)
                    trainedToday = true
                    idx += 1
                }

                if day < today {
                    endOfDay(day, trained: trainedToday)
                    if SharedStore.weekStart(next) != weekStart {
                        endOfWeek()
                        beginWeek(SharedStore.weekStart(next))
                    }
                    let nextCamp = campOf(next)
                    if nextCamp > campIndex {
                        endOfCamp(on: day)
                        campIndex = nextCamp
                    }
                }
                day = next
            }
        } else {
            beginWeek(SharedStore.weekStart(today))
            campIndex = max(0, campOf(today))
        }

        // Current week and camp snapshots.
        s.quests = QuestKind.forWeek(weekStart).map { k in
            QuestStatus(kind: k, title: k.title(goal: input.goal), progress: questProgress(k), target: k.target(goal: input.goal))
        }
        let (cs, ce) = campRange(campIndex)
        s.camp.index = campIndex
        s.camp.start = cs
        s.camp.end = ce
        s.camp.requirement = requirement
        s.camp.opponent = Opponents.forCamp(campIndex)
        s.camp.fightKind = s.champion ? "衛冕戰" : (s.points >= 900 ? "頭銜戰" : "排名賽")
        return s
    }

    // MARK: Fights

    mutating func fight(_ f: FightInput, day: Date) {
        let method = FightMethod(f.length)
        var r = FightReport(date: f.date)
        r.fightNumber = s.wins + 1
        r.method = method
        r.levelBefore = s.level
        r.tierBefore = s.tier
        report = r

        var base = f.sets.count * 10
        report!.lines.append(("完成 \(f.sets.count) 組", f.sets.count * 10))
        base += method.xp
        report!.lines.append((method.title, method.xp))

        if s.pendingMiss != nil {
            base += 50
            report!.lines.append(("逆轉：接住漏練", 50))
            report!.comeback = true
            if method == .dec { award("comeback", day) }
        }
        s.pendingMiss = nil
        missStreak = 0

        // Personal records
        var bestThis: [String: Double] = [:]
        for set in f.sets { bestThis[set.exerciseId] = max(bestThis[set.exerciseId] ?? 0, set.score) }
        var prNames: [String] = []
        for (id, score) in bestThis.sorted(by: { $0.key < $1.key }) {
            if let prev = best[id], score > prev + 0.01 {
                prNames.append(ExerciseLibrary.byId(id)?.name ?? id)
            }
            best[id] = max(best[id] ?? 0, score)
        }
        if !prNames.isEmpty {
            base += 50 * prNames.count
            report!.lines.append(("破紀錄 ×\(prNames.count)", 50 * prNames.count))
            s.prCount += prNames.count
            wPRs += prNames.count
            report!.prs = prNames
        }

        let mult = 1 + 0.05 * Double(min(s.streak, 10))
        report!.multiplier = mult
        let gained = Int((Double(base) * mult).rounded())
        addXP(gained)
        addPurse(method.purse + 50 * prNames.count)
        changePoints(method.points, day)
        report!.points = method.points

        s.wins += 1
        switch method {
        case .ko: s.ko += 1; wKO += 1
        case .sub: s.sub += 1
        case .dec: s.dec += 1
        }
        s.tonnage += f.sets.reduce(0) { $0 + $1.tonnage }
        s.idleDays = 0
        hasTrained = true
        decayAnnounced = false

        s.weekSessions += 1
        wSets += f.sets.count
        if f.isUpper { wUpper += 1 } else { wLower += 1 }
        if input.planLog[day]?.picked == true { wOnTime += 1 }

        // Camp track
        s.camp.sessions += 1
        let req = requirement
        while s.camp.milestones < 4 && s.camp.sessions * 4 >= req * (s.camp.milestones + 1) {
            s.camp.milestones += 1
            addXP(150)
            addPurse(100)
            report!.milestones.append("訓練營進度 \(s.camp.milestones * 25)%")
        }

        checkQuests()
        drop(f, method: method, day: day)

        // Badges
        award("first_win", day)
        if method == .ko { award("first_ko", day) }
        for n in [10, 25, 50, 100, 200] where s.recordWins >= n { award("wins_\(n)", day) }
        for n in [1, 10, 50] where s.prCount >= n { award("pr_\(n)", day) }
        if s.recordWins >= 20 && s.recordLosses == 0 { award("undefeated_20", day) }
        for (i, t) in Badges.tonnage.enumerated() where s.tonnage >= t.kg { award("ton_\(i)", day) }

        report!.levelAfter = s.level
        report!.tierAfter = s.tier
        report!.recordAfter = s.record
        if report!.levelAfter > report!.levelBefore {
            event(day, .good, "升上 Lv.\(report!.levelAfter)", "")
        }
        s.reports.append(report!)
        report = nil
    }

    mutating func drop(_ f: FightInput, method: FightMethod, day: Date) {
        var rng = SplitMix(seed: UInt64(max(0, f.date.timeIntervalSince1970 * 1000)))
        guard Double(rng.next() % 1000) < method.dropChance * 1000 else { return }
        var roll = Int(rng.next() % 100)
        var rarity = Rarity.common
        for r in Rarity.allCases {
            if roll < r.weight { rarity = r; break }
            roll -= r.weight
        }
        let pool = Cosmetics.all.filter { $0.rarity == rarity && !$0.isDefault }
        guard !pool.isEmpty else { return }
        let item = pool[Int(rng.next() % UInt64(pool.count))]
        let dup = s.owned.contains(item.id)
        if dup {
            addPurse(rarity.duplicatePurse)
        } else {
            s.owned.insert(item.id)
            if rarity == .legendary { award("legendary", day) }
        }
        report?.drop = (item, dup)
    }

    // MARK: Quests

    func questProgress(_ k: QuestKind) -> Int {
        switch k {
        case .goal: s.weekSessions
        case .pr: wPRs
        case .ko: wKO
        case .both: (wUpper > 0 ? 1 : 0) + (wLower > 0 ? 1 : 0)
        case .volume: wSets
        case .onTime: wOnTime
        }
    }

    mutating func checkQuests() {
        for k in QuestKind.forWeek(weekStart) where !wQuestsDone.contains(k) {
            if questProgress(k) >= k.target(goal: input.goal) {
                wQuestsDone.insert(k)
                s.questsDone += 1
                addXP(k.xp)
                addPurse(k.purse)
                report?.quests.append(k.title(goal: input.goal))
            }
        }
        if s.questsDone >= 10, let d = report?.date { award("quest_10", cal.startOfDay(for: d)) }
    }

    // MARK: Days, weeks, camps

    mutating func endOfDay(_ day: Date, trained: Bool) {
        let ex = excused(day)
        if ex {
            wExcused += 1
            campExcused += 1
        }
        guard hasTrained, !trained else { return }

        if input.planLog[day]?.picked == true && !ex {
            missStreak += 1
            if missStreak >= 2 {
                s.forfeits += 1
                missStreak = 0
                s.pendingMiss = nil
                changePoints(-15, day)
                event(day, .bad, "棄權敗", "連續兩次排定的訓練都沒練，戰績 \(s.record)")
            } else {
                s.pendingMiss = day
                event(day, .bad, "黃牌警告", "排定的訓練沒練，下次再漏就記一場棄權敗")
            }
        }

        if !ex {
            s.idleDays += 1
            if s.idleDays > 3 {
                if !decayAnnounced {
                    event(day, .bad, "排名開始下滑", "超過 3 天沒練，每天 −2 排名積分")
                    decayAnnounced = true
                }
                changePoints(-2, day)
            }
            if s.champion && s.idleDays > 14 {
                strip(day, reason: "超過 14 天沒練")
            }
        }
    }

    mutating func beginWeek(_ start: Date) {
        weekStart = start
        s.weekSessions = 0
        wSets = 0
        wPRs = 0
        wKO = 0
        wUpper = 0
        wLower = 0
        wOnTime = 0
        wExcused = 0
        wQuestsDone = []
    }

    mutating func endOfWeek() {
        let lastDay = cal.date(byAdding: .day, value: 6, to: weekStart)!
        let minPerWeek = min(2, input.goal)
        if s.weekSessions >= minPerWeek {
            s.streak += 1
            s.bestStreak = max(s.bestStreak, s.streak)
            for n in [4, 8, 12, 26, 52] where s.streak >= n { award("streak_\(n)", lastDay) }
        } else if wExcused >= 4 {
            // A week mostly on leave doesn't count either way.
        } else if s.cards > 0 && s.streak > 0 {
            s.cards -= 1
            event(lastDay, .neutral, "用掉一張保護卡", "這週練不到 2 次，連續 \(s.streak) 週保住了")
        } else if s.streak > 0 {
            event(lastDay, .bad, "連續中斷", "連續 \(s.streak) 週停在這裡（最長 \(s.bestStreak) 週）")
            s.streak = 0
        }

        if s.weekSessions >= input.goal && s.cards < 2 {
            s.cards += 1
            event(lastDay, .good, "得到一張保護卡", "這週練滿 \(input.goal) 次")
        }

        if let stake = input.bets[weekStart] {
            if s.weekSessions >= input.goal {
                addPurse(stake)
                s.betsWon += 1
                award("bet_win", lastDay)
                if s.betsWon >= 5 { award("bet_5", lastDay) }
                event(lastDay, .good, "押注成功", "贏得 \(stake) 獎金")
            } else {
                s.purse = max(0, s.purse - stake)
                event(lastDay, .bad, "押注失敗", "沒收 \(stake) 獎金")
            }
        }
    }

    mutating func endOfCamp(on day: Date) {
        let req = requirement
        let opp = Opponents.forCamp(campIndex)
        let wasChampion = s.champion
        let titleShot = !wasChampion && s.points >= 900
        let won = s.camp.sessions >= req
        let kind = wasChampion ? "衛冕戰" : (titleShot ? "頭銜戰" : "排名賽")

        if won {
            s.campWins += 1
            changePoints(40, day)
            addXP(300)
            addPurse(500)
            award("camp_1", day)
            event(day, .good, "\(kind)勝利", "擊敗「\(opp.nick)」\(opp.name)（\(s.camp.sessions)/\(req) 場）")
            if titleShot {
                s.champion = true
                s.titlesWon += 1
                award("champion", day)
                event(day, .good, "成為冠軍", "冠軍腰帶到手！之後每個訓練營都要衛冕")
            } else if wasChampion {
                s.defenses += 1
                if s.defenses >= 1 { award("defense_1", day) }
                if s.defenses >= 3 { award("defense_3", day) }
            }
        } else {
            s.campLosses += 1
            changePoints(-20, day)
            event(day, .bad, "\(kind)落敗", "輸給「\(opp.nick)」\(opp.name)（\(s.camp.sessions)/\(req) 場）")
            if wasChampion { strip(day, reason: "衛冕失敗") }
        }

        s.camp.sessions = 0
        s.camp.milestones = 0
        campExcused = 0
    }

    mutating func strip(_ day: Date, reason: String) {
        guard s.champion else { return }
        s.champion = false
        s.defenses = 0
        s.points = min(s.points, 850)
        event(day, .bad, "冠軍腰帶被剝奪", reason)
    }

    // MARK: Helpers

    mutating func addXP(_ n: Int) {
        s.xp += n
        report?.xp += n
    }

    mutating func addPurse(_ n: Int) {
        s.purse += n
        report?.purse += n
    }

    mutating func changePoints(_ delta: Int, _ day: Date) {
        let before = s.tier
        s.points = max(0, s.points + delta)
        let after = s.tier
        if after != before {
            event(day, after > before ? .good : .bad,
                  after > before ? "升上「\(after.title)」" : "掉到「\(after.title)」", "排名積分 \(s.points)")
        }
    }

    mutating func award(_ id: String, _ day: Date) {
        guard s.badges[id] == nil else { return }
        s.badges[id] = day
        if let b = Badges.byId(id) {
            report?.badges.append(b.name)
            event(day, .good, "獲得徽章「\(b.name)」", b.detail)
        }
    }

    mutating func event(_ day: Date, _ mood: CareerEvent.Mood, _ title: String, _ detail: String) {
        s.events.append(CareerEvent(date: day, mood: mood, title: title, detail: detail))
    }
}

/// Small deterministic RNG so drops replay the same way every time.
struct SplitMix {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Derived views of the history

struct Attributes: Equatable {
    var power = 1
    var legs = 1
    var stamina = 1
    var grit = 1

    static func compute(_ sessions: [FightInput], streak: Int, now: Date = .now) -> Attributes {
        var first: [String: Double] = [:]
        var best: [String: Double] = [:]
        var upperIds = Set<String>()
        var upperSessions = 0
        var lowerSessions = 0
        let cutoff = now.addingTimeInterval(-28 * 86400)
        var recentSets = 0

        for f in sessions.sorted(by: { $0.date < $1.date }) {
            if f.isUpper { upperSessions += 1 } else { lowerSessions += 1 }
            if f.date >= cutoff && f.date <= now { recentSets += f.sets.count }
            for set in f.sets {
                if f.isUpper { upperIds.insert(set.exerciseId) }
                if first[set.exerciseId] == nil { first[set.exerciseId] = set.score }
                best[set.exerciseId] = max(best[set.exerciseId] ?? 0, set.score)
            }
        }

        func growth(_ ids: [String]) -> Double {
            let ratios = ids.compactMap { id -> Double? in
                guard let f = first[id], f > 0, let b = best[id] else { return nil }
                return b / f
            }
            return ratios.isEmpty ? 1 : ratios.reduce(0, +) / Double(ratios.count)
        }
        let upper = best.keys.filter { upperIds.contains($0) }
        let lower = best.keys.filter { !upperIds.contains($0) }

        func clamp(_ x: Int) -> Int { min(99, max(1, x)) }
        return Attributes(
            power: clamp(20 + Int((growth(upper) - 1) * 150) + min(20, upperSessions / 2)),
            legs: clamp(20 + Int((growth(lower) - 1) * 150) + min(20, lowerSessions / 2)),
            stamina: clamp(recentSets / 4),
            grit: clamp(10 + streak * 6)
        )
    }
}

struct ShadowStats {
    var sessions = 0
    var sets = 0
    var tonnage: Double = 0

    /// Last 28 days and the 28 days before that.
    static func compare(_ sessions: [FightInput], now: Date = .now) -> (now: ShadowStats, before: ShadowStats) {
        var a = ShadowStats()
        var b = ShadowStats()
        let mid = now.addingTimeInterval(-28 * 86400)
        let start = now.addingTimeInterval(-56 * 86400)
        for f in sessions where f.date <= now && f.date >= start {
            let t = f.sets.reduce(0) { $0 + $1.tonnage }
            if f.date >= mid {
                a.sessions += 1; a.sets += f.sets.count; a.tonnage += t
            } else {
                b.sessions += 1; b.sets += f.sets.count; b.tonnage += t
            }
        }
        return (a, b)
    }
}
