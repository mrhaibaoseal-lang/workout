import Foundation

struct Slot {
    let pattern: MovementPattern
    let sets: Int
    let low: Int
    let high: Int
    /// Kept in the 20-minute short version.
    let essential: Bool
    /// 「少排槓鈴」時，這個位置仍然優先用槓鈴（槓鈴臀推：啞鈴壓髖部太輕）。
    var keepBarbell = false
    /// 自訂課表：指定的動作。器材不夠或已刪除時，改用同類型自動挑。
    var exerciseId: String? = nil
    /// 自訂課表：完整版的休息秒數（內建課表依重點動作 120／60 秒）。
    var rest: Int? = nil
    /// 自訂課表：和上一個動作連成超級組／循環組。
    var linkPrev = false
}

struct DayTemplate: Identifiable {
    let id: String
    let name: String
    let focus: String
    /// B days start from the second exercise variant so A and B differ.
    var variant: Int = 0
    /// 自訂課表的一天：組數照使用者填的，不自動 +1。
    var custom = false
    let slots: [Slot]

    /// 週任務「上下半身都練」用。內建看 id，自訂看動作類型（全身日兩邊都算）。
    var halves: (upper: Bool, lower: Bool) {
        if id.hasPrefix("upper") { return (true, false) }
        if id.hasPrefix("lower") { return (false, true) }
        let patterns = slots.map(\.pattern)
        return (patterns.contains { $0.isUpper }, patterns.contains { $0.isLower })
    }
}

enum Phase {
    case rampUp, normal, deload

    var title: String {
        switch self {
        case .rampUp: "適應期"
        case .normal: "進步期"
        case .deload: "減量週"
        }
    }

    var note: String {
        switch self {
        case .rampUp: "前兩週練輕一點，每組留 3 下的力氣。先養成習慣，不要練到爆痠。"
        case .normal: "每組做到還剩 1–2 下的力氣就停。每組都做到次數上限，下次就加重。"
        case .deload: "這週組數減少、重量減輕，讓身體恢復。下週會換一批動作。"
        }
    }
}

enum WorkoutLength: String, CaseIterable, Identifiable {
    case full, short, minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "完整 60 分"
        case .short: "精簡 20 分"
        case .minimal: "只做 1 組"
        }
    }

    var tag: String? {
        switch self {
        case .full: nil
        case .short: "精簡"
        case .minimal: "1 組起"
        }
    }
}

struct PlannedExercise: Identifiable {
    let exercise: Exercise
    let sets: Int
    let low: Int
    let high: Int
    let restSeconds: Int
    let essential: Bool
    /// 自訂課表指定的動作今天排不了（器材不夠或已刪除），改用這個動作時，記原本的名字。
    var replaced: String? = nil
    /// 超級組／循環組：同一個數字的相鄰動作輪流做（`Superset`）。
    var group: Int? = nil
    /// 指定用哪一組器材（超級組裡另一個動作已經用主要啞鈴時，改用另一組）。
    var kit: String? = nil
    /// 超級組裡和別的動作共用這組器材（分不開），每輪要換重量。
    var sharedKit: String? = nil

    var id: String { exercise.id }
}

enum ProgramBuilder {
    static let blockWeeks = 6

    /// 新手增肌的上下半身分化（每週 4 天，每個部位一週練 2 次）。
    /// 每個肌群一週大約 9–12 個正式組：新手這個量就會一直長，不用練到爆。
    /// 複合動作 6–12 下、單關節動作 10–20 下；每組留 1–2 下的力氣，達標就加重（雙重進步法）。
    /// 健身房才有的動作（例如腿伸展機），在家會自動跳過。
    /// 現在用的課表：選了自訂課表就用它，不然用內建。
    static var days: [DayTemplate] {
        CustomPrograms.active.map(CustomPrograms.templates) ?? builtInDays
    }

    /// 自訂課表的名字；用內建課表時是 nil。
    static var customName: String? { CustomPrograms.active?.name }

    /// 舊紀錄的 dayKey 找回那一天（內建或任何一份自訂課表）。
    static func template(id: String) -> DayTemplate? {
        builtInDays.first { $0.id == id } ?? CustomPrograms.day(templateId: id)
    }

    static let builtInDays: [DayTemplate] = [
        DayTemplate(id: "upperA", name: "上半身 A", focus: "胸、背為主", slots: [
            Slot(pattern: .hPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .incline, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "lowerA", name: "下半身 A", focus: "大腿前側、臀", slots: [
            Slot(pattern: .squat, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hinge, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .lunge, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .quadIso, sets: 3, low: 12, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "upperB", name: "上半身 B", focus: "肩、背、手臂", variant: 1, slots: [
            Slot(pattern: .vPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 10, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .rear, sets: 2, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .triceps, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "lowerB", name: "下半身 B", focus: "臀、大腿後側", variant: 1, slots: [
            Slot(pattern: .hinge, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .glute, sets: 3, low: 8, high: 12, essential: true, keepBarbell: true),
            Slot(pattern: .lunge, sets: 3, low: 10, high: 15, essential: true),
            Slot(pattern: .hamCurl, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
    ]

    /// 練的動作要用什麼器材：在家用設定裡勾的，健身房全部都有。
    static func equipment(place: String, homeRaw: String) -> Set<Equipment> {
        (TrainingPlace(rawValue: place) ?? .home).equipment(homeRaw: homeRaw)
    }

    static func phase(week: Int) -> Phase {
        if Plateau.deloadActive { return .deload }
        if week <= 2 { return .rampUp }
        if week % blockWeeks == 0 { return .deload }
        return .normal
    }

    /// Exercise variants rotate after every deload week.
    static func block(week: Int) -> Int {
        (week - 1) / blockWeeks
    }

    /// limitBarbell：槓鈴組裝麻煩時，除了 keepBarbell 的位置，其他都先用啞鈴等器材。
    static func plan(day: DayTemplate, equipment: Set<Equipment>, week: Int, length: WorkoutLength,
                     limitBarbell: Bool = false, gym: Bool = false) -> [PlannedExercise] {
        let phase = phase(week: week)
        let block = block(week: week)
        var usedIds = Set<String>()
        let siblings = days

        var slotOf: [Int] = []
        var all: [PlannedExercise] = day.slots.enumerated().compactMap { n, slot -> PlannedExercise? in
            if length != .full && !slot.essential { return nil }
            // 自訂課表指定的動作：器材夠、沒被刪掉就直接用
            var replaced: String? = nil
            if let fid = slot.exerciseId, let fixed = ExerciseLibrary.byId(fid), !usedIds.contains(fid) {
                if fixed.requires.isSubset(of: equipment) && !CustomExercises.isHidden(fid) {
                    usedIds.insert(fid)
                    slotOf.append(n)
                    return planned(fixed, slot: slot, day: day, phase: phase, length: length, replaced: nil)
                }
                replaced = fixed.name
            }
            var options = ExerciseLibrary.candidates(for: slot.pattern, equipment: equipment)
                .filter { !usedIds.contains($0.id) }
            if limitBarbell && !slot.keepBarbell {
                let noBar = options.filter { !$0.requires.contains(.barbell) }
                if !noBar.isEmpty { options = noBar + options.filter { $0.requires.contains(.barbell) } }
            }
            guard !options.isEmpty else { return nil }
            // 有負重的動作優先輪替（避免 B 日掉到徒手版）
            let loaded = options.filter(\.loaded)
            let top = Array((loaded.isEmpty ? options : loaded).prefix(2))
            // 這類動作在另一天（同為上半身或下半身）也有，B 日才換第二個動作；一週只練一次的就用首選
            let variant: Int
            if day.custom {
                // 自訂課表：前面幾天也有同類型（自動挑）的，就往後換一個，各天才不會都一樣
                variant = siblings.prefix(while: { $0.id != day.id })
                    .filter { d in d.slots.contains { $0.pattern == slot.pattern && $0.exerciseId == nil } }.count
            } else {
                let half = day.id.prefix(5)
                let shared = siblings.contains { d in
                    d.id != day.id && d.id.prefix(5) == half && d.slots.contains { $0.pattern == slot.pattern }
                }
                variant = shared ? day.variant : 0
            }
            let exercise = slot.keepBarbell ? top[0] : top[(block + variant) % top.count]
            usedIds.insert(exercise.id)
            slotOf.append(n)
            return planned(exercise, slot: slot, day: day, phase: phase, length: length, replaced: replaced)
        }
        if length == .minimal { return Array(all.prefix(1)) }
        // 超級組：自訂課表照每格的「和上一個連在一起」（中間的格子沒排到就不連）；內建課表看設定
        let link: [Bool]
        if day.custom {
            link = all.indices.map { i in
                i > 0 && day.slots[slotOf[i]].linkPrev && slotOf[i - 1] == slotOf[i] - 1
            }
        } else {
            link = UserDefaults.standard.bool(forKey: Keys.autoSuperset) ? Superset.autoLinks(all) : []
        }
        Superset.assignGroups(&all, link: link)
        let replaceable = all.indices.map { day.slots[slotOf[$0]].exerciseId == nil || all[$0].replaced != nil }
        Superset.separateKits(&all, gym: gym, equipment: equipment, replaceable: replaceable)
        return all
    }

    private static func planned(_ exercise: Exercise, slot: Slot, day: DayTemplate, phase: Phase,
                                length: WorkoutLength, replaced: String?) -> PlannedExercise {
        var sets = slot.sets
        if length == .full && slot.essential && !day.custom { sets += 1 }
        if phase != .normal { sets = max(2, sets - 1) }

        let rest: Int
        switch length {
        case .full: rest = slot.rest ?? (slot.essential ? 120 : 60)
        case .short: rest = min(slot.rest ?? 60, 60)
        case .minimal: rest = 90
        }

        let range = exercise.range ?? slot.low...slot.high
        return PlannedExercise(
            exercise: exercise,
            sets: length == .minimal ? 1 : sets,
            low: range.lowerBound,
            high: range.upperBound,
            restSeconds: rest,
            essential: slot.essential,
            replaced: replaced
        )
    }

    /// 照實際排出來的組（含熱身）、換重量和組槓鈴的時間估算。
    static func estimatedMinutes(_ plan: [PlannedExercise], sessions: [WorkoutSession], gym: Bool, increment: Double,
                                 autoWarmup: Bool, week: Int, length: WorkoutLength) -> Int {
        WorkoutTimeEstimator.minutes(plan: plan, sessions: sessions, gym: gym, increment: increment,
                                     autoWarmup: autoWarmup, week: week, length: length)
    }

    static func estimatedMinutes(_ plan: [PlannedExercise]) -> Int {
        let seconds = plan.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }
        return max(5, Int((Double(seconds) / 60).rounded()) + 5)
    }

    static func nextDay(after sessions: [WorkoutSession]) -> DayTemplate {
        let days = self.days
        guard let last = sessions.first,
              let idx = days.firstIndex(where: { $0.id == last.dayKey }) else {
            return days[0]
        }
        return days[(idx + 1) % days.count]
    }
}

struct Suggestion {
    let weight: Double
    let reps: Int
    let note: String
}

enum Progression {
    /// Sets from the most recent session that included this exercise.
    /// `sessions` must be sorted newest first.
    static func lastSets(for exerciseId: String, in sessions: [WorkoutSession]) -> [SetEntry] {
        for session in sessions {
            let sets = session.entries.filter { $0.exerciseId == exerciseId && $0.isWork }
            if !sets.isEmpty { return sets.sorted { $0.setIndex < $1.setIndex } }
        }
        return []
    }

    /// ladder：這個動作裝得出來的重量（沒有設定器材時用固定級距）。
    static func suggest(_ item: PlannedExercise, last: [SetEntry], phase: Phase, ladder: WeightLadder,
                        scheme: SetScheme = .straight) -> Suggestion {
        let ex = item.exercise
        guard !last.isEmpty else {
            let note = ex.loaded
                ? "第一次做：選一個能輕鬆做 \(item.high) \(ex.unit.label)的重量"
                : "第一次做：先把動作做標準"
            return Suggestion(weight: 0, reps: item.low, note: note)
        }

        let lastWeight = last.map(\.weight).max() ?? 0
        // 只看最重的那幾組（遞增／遞減組的輕組不算）
        let top = last.filter { $0.weight >= lastWeight }
        let bestReps = top.map(\.reps).max() ?? item.low
        let target = SetPlanner.targetReps(scheme: scheme, low: item.low, high: item.high)
        let allHitTop = top.allSatisfy { $0.reps >= target }

        switch phase {
        case .deload:
            return Suggestion(weight: ex.loaded ? ladder.snap(lastWeight * 0.8) : lastWeight, reps: item.low,
                              note: "減量週：重量減輕約兩成，輕鬆做完")
        case .rampUp:
            return Suggestion(weight: lastWeight, reps: min(bestReps, item.high),
                              note: "適應期：用上次的重量，別拚到力竭")
        case .normal:
            if allHitTop {
                if ex.loaded {
                    let next = ladder.up(lastWeight)
                    if next <= lastWeight + 0.01 {
                        return Suggestion(weight: lastWeight, reps: bestReps + 1,
                                          note: "已經是你器材最重的了，改成多做 1 下，或下放放慢到 3 秒")
                    }
                    var note = "上次全部達標 💪 加重 \(format(next - lastWeight)) kg"
                    if let l = ladder.loading(next) { note += "（\(l.text)）" }
                    return Suggestion(weight: next, reps: item.low, note: note)
                }
                return Suggestion(weight: lastWeight, reps: item.high,
                                  note: "已經達標，下放放慢到 3 秒增加難度")
            }
            return Suggestion(weight: lastWeight, reps: min(bestReps + 1, item.high),
                              note: "目標：比上次多做 1 \(ex.unit.label)")
        }
    }

    static func roundHalf(_ x: Double) -> Double {
        (x * 2).rounded() / 2
    }

    static func format(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
    }
}

enum Stats {
    static var calendar: Calendar { SharedStore.calendar }

    static func weekStart(_ date: Date) -> Date {
        SharedStore.weekStart(date)
    }

    static func sessionsThisWeek(_ sessions: [WorkoutSession]) -> Int {
        SharedStore.countThisWeek(sessions.map(\.date))
    }

    /// 每週練 2 次以上的連續週數；請假週、用掉保護卡的週不會中斷。
    static func weekStreak(_ sessions: [WorkoutSession]) -> Int {
        GoalEngine.streak(dates: sessions.map(\.date))
    }

    static func week(since start: Date) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: .now)).day ?? 0
        return max(1, days / 7 + 1)
    }

    /// True when the most recent planned training day before today passed with no workout
    /// on or after it. Without planned weekdays, falls back to "3+ days since last workout".
    /// `sessions` must be sorted newest first.
    static func missedLastPlanned(_ sessions: [WorkoutSession], weekdays: Set<Int>) -> Bool {
        guard let last = sessions.first?.date else { return false }
        let cal = Calendar.current
        if cal.isDateInToday(last) { return false }
        let today = cal.startOfDay(for: .now)

        if weekdays.isEmpty {
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            return gap >= 3
        }
        for back in 1...7 {
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            if weekdays.contains(cal.component(.weekday, from: day)) {
                return last < day
            }
        }
        return false
    }
}
