import Foundation

/// 次數區間（找「某個次數下最重能做多少」）。
enum RepRange: Int, CaseIterable, Identifiable, Comparable {
    case r1to5, r6to8, r9to12, r13to15, r16plus

    var id: Int { rawValue }

    static func < (a: RepRange, b: RepRange) -> Bool { a.rawValue < b.rawValue }

    static func of(_ reps: Int) -> RepRange {
        switch reps {
        case ..<6: return .r1to5
        case 6...8: return .r6to8
        case 9...12: return .r9to12
        case 13...15: return .r13to15
        default: return .r16plus
        }
    }

    var title: String {
        switch self {
        case .r1to5: "1–5 下"
        case .r6to8: "6–8 下"
        case .r9to12: "9–12 下"
        case .r13to15: "13–15 下"
        case .r16plus: "16 下以上"
        }
    }
}

/// 一組的重量 × 次數，和它發生的時間。
struct RecordMark: Equatable {
    let weight: Double
    let reps: Int
    let date: Date
}

struct E1RMMark: Equatable {
    let value: Double
    let weight: Double
    let reps: Int
    let date: Date
}

struct VolumeMark: Equatable {
    let value: Double
    let date: Date
}

/// 曲線上的一個點（每天一個）：負重動作是估算 1RM，徒手動作是單組最多次數。
struct HistoryPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// 破紀錄的那一刻。第一次做不算。
struct RecordEvent: Identifiable {
    let id: Int
    let exerciseId: String
    let date: Date
    let kindLabel: String
    let newText: String
    let oldText: String
}

struct ExerciseRecords {
    let exerciseId: String
    let exercise: Exercise

    private(set) var maxWeight: RecordMark? = nil
    private(set) var bestE1RM: E1RMMark? = nil
    private(set) var repRangeBests: [RepRange: RecordMark] = [:]
    private(set) var bestSetVolume: VolumeMark? = nil
    private(set) var bestSessionVolume: VolumeMark? = nil
    /// 徒手動作：單組最多的下數（或秒數）。
    private(set) var maxReps: RecordMark? = nil
    private(set) var history: [HistoryPoint] = []
    private(set) var timeline: [RecordEvent] = []
    private(set) var setCount: Int = 0
    private(set) var lastDate: Date? = nil

    var lastRecordDate: Date? { timeline.last?.date }

    static func e1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    /// a 是不是比 b 好：重量大，或同重量次數多。
    private static func better(_ a: SetEntry, than b: SetEntry) -> Bool {
        a.weight != b.weight ? a.weight > b.weight : a.reps > b.reps
    }

    private static func mark(_ e: SetEntry) -> RecordMark {
        RecordMark(weight: e.weight, reps: e.reps, date: e.date)
    }

    private static func fmt(_ x: Double) -> String { Progression.format(x) }

    init(exercise: Exercise, entries: [SetEntry]) {
        self.exerciseId = exercise.id
        self.exercise = exercise

        let cal = Calendar.current
        let loaded = exercise.loaded
        let work = entries.filter { e in
            e.isWork && e.exerciseId == exercise.id && e.reps > 0 && (!loaded || e.weight > 0)
        }
        let sorted = work.sorted { a, b in
            a.date != b.date ? a.date < b.date : a.setIndex < b.setIndex
        }
        setCount = sorted.count
        lastDate = sorted.last?.date

        let byDay = Dictionary(grouping: sorted) { cal.startOfDay(for: $0.date) }
        let unitLabel = exercise.unit.label
        var nextId = 0
        var events: [RecordEvent] = []
        func emit(_ date: Date, _ label: String, _ new: String, _ old: String) {
            events.append(RecordEvent(id: nextId, exerciseId: exercise.id, date: date,
                                      kindLabel: label, newText: new, oldText: old))
            nextId += 1
        }

        var maxW: RecordMark?
        var bestE: E1RMMark?
        var ranges: [RepRange: RecordMark] = [:]
        var bestSet: VolumeMark?
        var bestSession: VolumeMark?
        var maxR: RecordMark?
        var points: [HistoryPoint] = []

        for day in byDay.keys.sorted() {
            let sets = byDay[day] ?? []
            if sets.isEmpty { continue }

            if loaded {
                // 最大重量
                var topOpt: SetEntry? = nil
                for e in sets {
                    if let a = topOpt {
                        if ExerciseRecords.better(e, than: a) { topOpt = e }
                    } else {
                        topOpt = e
                    }
                }
                if let top = topOpt {
                    let m = ExerciseRecords.mark(top)
                    if let old = maxW {
                        if top.weight > old.weight + 0.001 {
                            emit(top.date, "最大重量", "\(ExerciseRecords.fmt(top.weight)) kg", "\(ExerciseRecords.fmt(old.weight)) kg")
                            maxW = m
                        }
                    } else {
                        maxW = m
                    }
                }

                // 估算 1RM（只看 12 下以內）
                let eligible = sets.filter { $0.reps <= 12 }
                if let topE = eligible.max(by: {
                    ExerciseRecords.e1RM(weight: $0.weight, reps: $0.reps) < ExerciseRecords.e1RM(weight: $1.weight, reps: $1.reps)
                }) {
                    let v = ExerciseRecords.e1RM(weight: topE.weight, reps: topE.reps)
                    points.append(HistoryPoint(date: day, value: v))
                    if let old = bestE {
                        if v > old.value + 0.001 {
                            emit(topE.date, "推估最大力量", "\(ExerciseRecords.fmt(Progression.roundHalf(v))) kg",
                                 "\(ExerciseRecords.fmt(Progression.roundHalf(old.value))) kg")
                            bestE = E1RMMark(value: v, weight: topE.weight, reps: topE.reps, date: topE.date)
                        }
                    } else {
                        bestE = E1RMMark(value: v, weight: topE.weight, reps: topE.reps, date: topE.date)
                    }
                }

                // 各次數區間
                let grouped = Dictionary(grouping: sets) { RepRange.of($0.reps) }
                for range in RepRange.allCases {
                    guard let group = grouped[range], !group.isEmpty else { continue }
                    var top = group[0]
                    for e in group.dropFirst() where ExerciseRecords.better(e, than: top) { top = e }
                    if let old = ranges[range] {
                        let isBetter = top.weight != old.weight ? top.weight > old.weight : top.reps > old.reps
                        if isBetter {
                            emit(top.date, "\(range.title)最佳",
                                 "\(ExerciseRecords.fmt(top.weight)) kg × \(top.reps)",
                                 "\(ExerciseRecords.fmt(old.weight)) kg × \(old.reps)")
                            ranges[range] = ExerciseRecords.mark(top)
                        }
                    } else {
                        ranges[range] = ExerciseRecords.mark(top)
                    }
                }

                // 單組量
                if let topV = sets.max(by: { $0.weight * Double($0.reps) < $1.weight * Double($1.reps) }) {
                    let v = topV.weight * Double(topV.reps)
                    if let old = bestSet {
                        if v > old.value + 0.001 {
                            emit(topV.date, "單組量", "\(ExerciseRecords.fmt(v)) kg", "\(ExerciseRecords.fmt(old.value)) kg")
                            bestSet = VolumeMark(value: v, date: topV.date)
                        }
                    } else {
                        bestSet = VolumeMark(value: v, date: topV.date)
                    }
                }

                // 單次訓練量（以一天為一次訓練）
                let total = sets.reduce(0.0) { $0 + $1.weight * Double($1.reps) }
                let when = sets.last?.date ?? day
                if let old = bestSession {
                    if total > old.value + 0.001 {
                        emit(when, "單次訓練量", "\(ExerciseRecords.fmt(total.rounded())) kg", "\(ExerciseRecords.fmt(old.value.rounded())) kg")
                        bestSession = VolumeMark(value: total, date: when)
                    }
                } else {
                    bestSession = VolumeMark(value: total, date: when)
                }
            } else {
                guard let topR = sets.max(by: { $0.reps < $1.reps }) else { continue }
                points.append(HistoryPoint(date: day, value: Double(topR.reps)))
                let label = exercise.unit == .seconds ? "最久秒數" : "最多下數"
                if let old = maxR {
                    if topR.reps > old.reps {
                        emit(topR.date, label, "\(topR.reps) \(unitLabel)", "\(old.reps) \(unitLabel)")
                        maxR = RecordMark(weight: 0, reps: topR.reps, date: topR.date)
                    }
                } else {
                    maxR = RecordMark(weight: 0, reps: topR.reps, date: topR.date)
                }
            }
        }

        maxWeight = maxW
        bestE1RM = bestE
        repRangeBests = ranges
        bestSetVolume = bestSet
        bestSessionVolume = bestSession
        maxReps = maxR
        history = points
        timeline = events
    }
}

enum RecordBook {
    /// 每個動作的紀錄；只看正式組，不認得的動作 id 會略過。
    static func all(entries: [SetEntry]) -> [String: ExerciseRecords] {
        let work = entries.filter(\.isWork)
        let grouped = Dictionary(grouping: work, by: \.exerciseId)
        var out: [String: ExerciseRecords] = [:]
        for (id, list) in grouped {
            guard let ex = ExerciseLibrary.byId(id) else { continue }
            out[id] = ExerciseRecords(exercise: ex, entries: list)
        }
        return out
    }

    static func records(for exerciseId: String, entries: [SetEntry]) -> ExerciseRecords? {
        guard let ex = ExerciseLibrary.byId(exerciseId) else { return nil }
        return ExerciseRecords(exercise: ex, entries: entries.filter { $0.exerciseId == exerciseId })
    }

    /// 全部動作的破紀錄時刻，新的在前。
    static func allEvents(_ book: [String: ExerciseRecords]) -> [RecordEvent] {
        book.values.flatMap(\.timeline).sorted { $0.date > $1.date }
    }
}
