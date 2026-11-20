import Foundation

struct Slot {
    let pattern: MovementPattern
    let sets: Int
    let low: Int
    let high: Int
    /// Kept in the 20-minute short version.
    let essential: Bool
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
        case .normal: "每組做到快做不動（還剩 1-2 下）就停。達標就加重。"
        case .deload: "這週組數減少、重量減輕，讓身體恢復。下週會換一批動作。"
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

    static let days: [DayTemplate] = [
        DayTemplate(id: "upperA", name: "上半身 A", focus: "胸、背、肩", slots: [
            Slot(pattern: .hPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .vPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "lowerA", name: "下半身 A", focus: "腿、臀、核心", slots: [
            Slot(pattern: .squat, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hinge, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .lunge, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .glute, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 8, high: 15, essential: false),
        ]),
        DayTemplate(id: "upperB", name: "上半身 B", focus: "肩、背、手臂", variant: 1, slots: [
            Slot(pattern: .vPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 6, high: 10, essential: false),
            Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
        ]),
        DayTemplate(id: "lowerB", name: "下半身 B", focus: "臀、後腿、核心", variant: 1, slots: [
            Slot(pattern: .hinge, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .lunge, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .glute, sets: 3, low: 10, high: 15, essential: true),
            Slot(pattern: .squat, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 8, high: 15, essential: false),
        ]),
    ]

    static func phase(week: Int) -> Phase {
        if week <= 2 { return .rampUp }
        if week % blockWeeks == 0 { return .deload }
        return .normal
    }

    /// Exercise variants rotate after every deload week.
    static func block(week: Int) -> Int {
        (week - 1) / blockWeeks
    }

    static func plan(day: DayTemplate, equipment: Set<Equipment>, week: Int, short: Bool) -> [PlannedExercise] {
        let phase = phase(week: week)
        let block = block(week: week)
        var usedIds = Set<String>()

        return day.slots.compactMap { slot in
            if short && !slot.essential { return nil }
            let options = ExerciseLibrary.candidates(for: slot.pattern, equipment: equipment)
                .filter { !usedIds.contains($0.id) }
            guard !options.isEmpty else { return nil }
            let top = Array(options.prefix(2))
            let exercise = top[(block + day.variant) % top.count]
            usedIds.insert(exercise.id)

            var sets = slot.sets
            if phase != .normal { sets = max(2, sets - 1) }

            let range = exercise.range ?? slot.low...slot.high
            return PlannedExercise(
                exercise: exercise,
                sets: sets,
                low: range.lowerBound,
                high: range.upperBound,
                restSeconds: slot.essential ? 90 : 60,
                essential: slot.essential
            )
        }
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
            let sets = session.entries.filter { $0.exerciseId == exerciseId }
            if !sets.isEmpty { return sets.sorted { $0.setIndex < $1.setIndex } }
        }
        return []
    }

    static func suggest(_ item: PlannedExercise, last: [SetEntry], phase: Phase, increment: Double) -> Suggestion {
        let ex = item.exercise
        guard !last.isEmpty else {
            let note = ex.loaded
                ? "第一次做：選一個能輕鬆做 \(item.high) \(ex.unit.label)的重量"
                : "第一次做：先把動作做標準"
            return Suggestion(weight: 0, reps: item.low, note: note)
        }

        let lastWeight = last.map(\.weight).max() ?? 0
        let bestReps = last.map(\.reps).max() ?? item.low
        let allHitTop = last.allSatisfy { $0.reps >= item.high }

        switch phase {
        case .deload:
            return Suggestion(weight: roundHalf(lastWeight * 0.8), reps: item.low,
                              note: "減量週：重量減輕約兩成，輕鬆做完")
        case .rampUp:
            return Suggestion(weight: lastWeight, reps: min(bestReps, item.high),
                              note: "適應期：用上次的重量，別拚到力竭")
        case .normal:
            if allHitTop {
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

    static func roundHalf(_ x: Double) -> Double {
        (x * 2).rounded() / 2
    }

    static func format(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
    }
}

enum Stats {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // 週一開始
        return cal
    }()

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func sessionsThisWeek(_ sessions: [WorkoutSession]) -> Int {
        let start = weekStart(.now)
        return sessions.filter { $0.date >= start }.count
    }

    /// Consecutive weeks (ending this week or last week) with at least `minPerWeek` sessions.
    static func weekStreak(_ sessions: [WorkoutSession], minPerWeek: Int = 2) -> Int {
        var counts: [Date: Int] = [:]
        for s in sessions { counts[weekStart(s.date), default: 0] += 1 }

        var week = weekStart(.now)
        if (counts[week] ?? 0) < minPerWeek {
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        var streak = 0
        while (counts[week] ?? 0) >= minPerWeek {
            streak += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        return streak
    }

    static func week(since start: Date) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: .now)).day ?? 0
        return max(1, days / 7 + 1)
    }
}
