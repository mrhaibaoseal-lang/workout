import SwiftUI

/// 16 個追蹤的肌肉部位。rawValue 和 MuscleArt 的 muscle id 一致。
enum Muscle: String, CaseIterable, Identifiable {
    case traps, frontDelt, sideDelt, rearDelt, chest, biceps, triceps, forearms
    case abs, obliques, lats, lowerBack, glutes, quads, hamstrings, calves

    var id: String { rawValue }

    var name: String {
        switch self {
        case .traps: return "斜方肌"
        case .frontDelt: return "前三角肌"
        case .sideDelt: return "側三角肌"
        case .rearDelt: return "後三角肌"
        case .chest: return "胸"
        case .biceps: return "二頭"
        case .triceps: return "三頭"
        case .forearms: return "前臂"
        case .abs: return "腹肌"
        case .obliques: return "腹斜肌"
        case .lats: return "背闊肌"
        case .lowerBack: return "下背"
        case .glutes: return "臀"
        case .quads: return "股四頭"
        case .hamstrings: return "大腿後側"
        case .calves: return "小腿"
        }
    }

    /// 列表分組與順序：推、拉、腿、核心。
    var group: String {
        switch self {
        case .chest, .frontDelt, .sideDelt, .triceps: return "推"
        case .lats, .traps, .rearDelt, .biceps, .forearms: return "拉"
        case .quads, .hamstrings, .glutes, .calves: return "腿"
        case .abs, .obliques, .lowerBack: return "核心"
        }
    }

    var groupOrder: Int {
        switch group {
        case "推": return 0
        case "拉": return 1
        case "腿": return 2
        default: return 3
        }
    }

    /// 前臂、腹斜肌只會被當成次要出力，不另外排專門動作。
    var tracked: Bool { self != .forearms && self != .obliques }

    /// 依分組排好的順序（列表用）。
    static var ordered: [Muscle] {
        allCases.enumerated()
            .sorted { ($0.element.groupOrder, $0.offset) < ($1.element.groupOrder, $1.offset) }
            .map { $0.element }
    }
}

extension MovementPattern {
    /// 這種動作練到哪些肌肉：主要 1.0、次要 0.5。
    var muscles: [(Muscle, Double)] {
        switch self {
        case .hPush, .incline: return [(.chest, 1), (.frontDelt, 0.5), (.triceps, 0.5)]
        case .vPush: return [(.frontDelt, 1), (.sideDelt, 0.5), (.triceps, 0.5)]
        case .hPull: return [(.lats, 1), (.traps, 0.5), (.rearDelt, 0.5), (.biceps, 0.5)]
        case .vPull: return [(.lats, 1), (.biceps, 0.5), (.traps, 0.5)]
        case .squat: return [(.quads, 1), (.glutes, 0.5)]
        case .hinge: return [(.hamstrings, 1), (.glutes, 1), (.lowerBack, 0.5)]
        case .lunge: return [(.quads, 1), (.glutes, 0.5)]
        case .glute: return [(.glutes, 1), (.hamstrings, 0.5)]
        case .hamCurl: return [(.hamstrings, 1)]
        case .quadIso: return [(.quads, 1)]
        case .calf: return [(.calves, 1)]
        case .biceps: return [(.biceps, 1), (.forearms, 0.5)]
        case .triceps: return [(.triceps, 1)]
        case .lateral: return [(.sideDelt, 1)]
        case .rear: return [(.rearDelt, 1), (.traps, 0.5)]
        case .core: return [(.abs, 1), (.obliques, 0.5)]
        }
    }
}

enum MuscleStatus {
    case none, low, building, good, high

    var label: String {
        switch self {
        case .none: return "還沒練"
        case .low: return "太少"
        case .building: return "快達標"
        case .good: return "剛好"
        case .high: return "偏多"
        }
    }

    var color: Color {
        switch self {
        case .none: return Theme.raised
        case .low: return Theme.hot
        case .building: return Theme.gold
        case .good: return Theme.green
        case .high: return Theme.accent
        }
    }
}

enum MuscleStats {
    /// 增肌建議每個部位一週的組數範圍。
    static let target: ClosedRange<Double> = 10...20

    static func status(_ sets: Double) -> MuscleStatus {
        if sets <= 0 { return .none }
        if sets < 6 { return .low }
        if sets < 10 { return .building }
        if sets <= 20 { return .good }
        return .high
    }

    /// 指定日期那一週，每個部位的有效組數（正式組；次要出力算半組）。
    static func weeklySets(_ sessions: [WorkoutSession], weekOf date: Date = .now) -> [Muscle: Double] {
        let start = SharedStore.weekStart(date)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)
        var out: [Muscle: Double] = [:]
        for s in sessions {
            for e in s.entries where e.isWork && e.date >= start && e.date < end {
                guard let ex = ExerciseLibrary.byId(e.exerciseId) else { continue }
                for (m, w) in ex.trainedMuscles { out[m, default: 0] += w }
            }
        }
        return out
    }

    /// 0 = 剛練完很累，1 = 完全恢復。最近 4 天的組數，隨時間指數衰減（半衰約 30 小時）。
    static func recovery(_ sessions: [WorkoutSession], now: Date = .now) -> [Muscle: Double] {
        var fatigue: [Muscle: Double] = [:]
        for s in sessions {
            for e in s.entries where e.isWork {
                let hours = now.timeIntervalSince(e.date) / 3600
                if hours < 0 || hours > 96 { continue }
                guard let ex = ExerciseLibrary.byId(e.exerciseId) else { continue }
                let decay = exp(-hours / 30)
                for (m, w) in ex.trainedMuscles { fatigue[m, default: 0] += w * decay }
            }
        }
        var out: [Muscle: Double] = [:]
        for m in Muscle.allCases {
            out[m] = max(0, 1 - (fatigue[m] ?? 0) / 6)
        }
        return out
    }

    /// 今天適合練哪一天：該天主要肌肉（權重 1）平均恢復度最高的。
    static func suggestedDay(recovery: [Muscle: Double]) -> DayTemplate? {
        var best: DayTemplate?
        var bestScore = -1.0
        for day in ProgramBuilder.days {
            var primary = Set<Muscle>()
            for slot in day.slots {
                for (m, w) in slot.pattern.muscles where w >= 1 { primary.insert(m) }
            }
            if primary.isEmpty { continue }
            let score = primary.reduce(0.0) { $0 + (recovery[$1] ?? 1) } / Double(primary.count)
            if score > bestScore {
                bestScore = score
                best = day
            }
        }
        return best
    }
}
