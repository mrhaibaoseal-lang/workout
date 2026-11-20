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
}

struct DayTemplate: Identifiable {
    let id: String
    let name: String
    let focus: String
    /// B days start from the second exercise variant so A and B differ.
    var variant: Int = 0
    let slots: [Slot]
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

    var id: String { exercise.id }
}

enum ProgramBuilder {
    static let blockWeeks = 6

    /// 新手增肌的上下半身分化（每週 4 天，每個部位一週練 2 次）。
    /// 每個肌群一週大約 9–12 個正式組：新手這個量就會一直長，不用練到爆。
    /// 複合動作 6–12 下、單關節動作 10–20 下；每組留 1–2 下的力氣，達標就加重（雙重進步法）。
    /// 健身房才有的動作（例如腿伸展機），在家會自動跳過。
    static let days: [DayTemplate] = [
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
                     limitBarbell: Bool = false) -> [PlannedExercise] {
        let phase = phase(week: week)
        let block = block(week: week)
        var usedIds = Set<String>()

        let all: [PlannedExercise] = day.slots.compactMap { slot in
            if length != .full && !slot.essential { return nil }
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
            let half = day.id.prefix(5)
            let shared = days.contains { d in
                d.id != day.id && d.id.prefix(5) == half && d.slots.contains { $0.pattern == slot.pattern }
            }
            let exercise = slot.keepBarbell ? top[0] : top[(block + (shared ? day.variant : 0)) % top.count]
            usedIds.insert(exercise.id)

            var sets = slot.sets
            if length == .full && slot.essential { sets += 1 }
            if phase != .normal { sets = max(2, sets - 1) }

            let rest: Int
            switch length {
            case .full: rest = slot.essential ? 120 : 60
            case .short: rest = 60
            case .minimal: rest = 90
            }

            let range = exercise.range ?? slot.low...slot.high
            return PlannedExercise(
                exercise: exercise,
                sets: length == .minimal ? 1 : sets,
                low: range.lowerBound,
                high: range.upperBound,
                restSeconds: rest,
                essential: slot.essential
            )
        }
        return length == .minimal ? Array(all.prefix(1)) : all
    }

    static func estimatedMinutes(_ plan: [PlannedExercise]) -> Int {
        let seconds = plan.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }
        return max(5, Int((Double(seconds) / 60).rounded()) + 5)
    }

    static func nextDay(after sessions: [WorkoutSession]) -> DayTemplate {
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

    static func suggest(_ item: PlannedExercise, last: [SetEntry], phase: Phase, increment: Double,
                        maxWeight: Double? = nil, scheme: SetScheme = .straight) -> Suggestion {
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
            return Suggestion(weight: roundHalf(lastWeight * 0.8), reps: item.low,
                              note: "減量週：重量減輕約兩成，輕鬆做完")
        case .rampUp:
            return Suggestion(weight: lastWeight, reps: min(bestReps, item.high),
                              note: "適應期：用上次的重量，別拚到力竭")
        case .normal:
            if allHitTop {
                if ex.loaded, let cap = maxWeight, lastWeight + increment > cap {
                    return Suggestion(weight: lastWeight, reps: bestReps + 1,
                                      note: "已到器材最大重量，改成多做 1 下或下放放慢到 3 秒")
                }
                if ex.loaded {
                    return Suggestion(weight: lastWeight + increment, reps: item.low,
                                      note: "上次全部達標 💪 加重 \(format(increment)) kg")
                }
                return Suggestion(weight: lastWeight, reps: item.high,
                                  note: "已經達標，下放放慢到 3 秒增加難度")
            }
            return Suggestion(weight: lastWeight, reps: min(bestReps + 1, item.high),
                              note: "目標：比上次多做 1 \(ex.unit.label)")
        }
    }

    /// Heaviest load the user's equipment allows for this exercise.
    static func maxWeight(for ex: Exercise, dumbbell: Double, barbell: Double) -> Double? {
        if ex.requires.contains(.barbell) { return barbell }
        if ex.requires.contains(.dumbbell) { return dumbbell }
        return nil
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

    static func weekStreak(_ sessions: [WorkoutSession], minPerWeek: Int = 2) -> Int {
        SharedStore.weekStreak(sessions.map(\.date), minPerWeek: minPerWeek)
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
