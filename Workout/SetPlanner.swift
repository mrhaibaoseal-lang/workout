import Foundation

/// 每一組的類型。只有正式組算進步、破紀錄和訓練量。
enum SetKind: String {
    case warmup, work, drop

    /// 組號位置顯示的短標籤（正式組顯示數字）
    var badge: String? {
        switch self {
        case .warmup: "熱"
        case .work: nil
        case .drop: "降"
        }
    }

    var title: String {
        switch self {
        case .warmup: "熱身組"
        case .work: "正式組"
        case .drop: "遞減組（不休息）"
        }
    }
}

/// 一個動作的組數排法。auto 交給程式依動作和週期決定。
enum SetScheme: String, CaseIterable, Identifiable {
    case auto, straight, pyramid, reverse, dropset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "自動"
        case .straight: "固定重量"
        case .pyramid: "遞增組（金字塔）"
        case .reverse: "遞減組（倒金字塔）"
        case .dropset: "最後一組 Drop set"
        }
    }

    var short: String {
        switch self {
        case .auto: "自動"
        case .straight: "固定"
        case .pyramid: "遞增"
        case .reverse: "遞減"
        case .dropset: "Drop set"
        }
    }

    var explain: String {
        switch self {
        case .auto: "新手期用固定重量；單關節動作在進步期最後一組加 Drop set。"
        case .straight: "每組同樣的重量，最適合新手練動作、穩定進步。"
        case .pyramid: "從輕到重：每組加重、次數變少，最後一組最重。"
        case .reverse: "先做最重的一組，之後每組減重約 10%、多做 2 下。"
        case .dropset: "正式組做完，馬上減重約 25% 再做到力竭，連降 2 次，中間不休息。"
        }
    }
}

/// 使用者對每個動作選的排法（沒選＝自動）。
enum SchemeStore {
    static func load() -> [String: String] {
        guard let data = UserDefaults.standard.string(forKey: Keys.schemes)?.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    static func scheme(for exerciseId: String) -> SetScheme {
        load()[exerciseId].flatMap(SetScheme.init(rawValue:)) ?? .auto
    }

    static func set(_ scheme: SetScheme, for exerciseId: String) {
        var dict = load()
        dict[exerciseId] = scheme == .auto ? nil : scheme.rawValue
        if let data = try? JSONEncoder().encode(dict), let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: Keys.schemes)
        }
    }
}

/// 一組的計畫：重量、次數、類型。
struct PlannedSet {
    var weight: Double
    var reps: Int
    var kind: SetKind
}

enum SetPlanner {
    static let barWeight = 20.0

    /// 單關節動作：自動模式下進步期最後一組加 Drop set。
    static let isolation: Set<MovementPattern> = [.biceps, .triceps, .lateral, .rear]

    /// 把 auto 換成實際的排法。
    static func resolve(_ scheme: SetScheme, exercise: Exercise, phase: Phase) -> SetScheme {
        guard exercise.loaded else { return .straight }
        guard scheme == .auto else { return scheme }
        if phase == .normal && isolation.contains(exercise.pattern) { return .dropset }
        return .straight
    }

    /// 達標門檻：遞增／遞減組看最重那組有沒有做到「下限 + 2」，其他看上限。
    static func targetReps(scheme: SetScheme, low: Int, high: Int) -> Int {
        switch scheme {
        case .pyramid, .reverse: min(high, low + 2)
        default: high
        }
    }

    static func round(_ x: Double, step: Double) -> Double {
        let s = step > 0 ? step : 0.5
        return max(s, (x / s).rounded() * s)
    }

    /// 正式組（含 Drop set 的遞減組）。weight 是建議的「最重那組」重量。
    static func workSets(scheme: SetScheme, count: Int, weight: Double, reps: Int,
                         low: Int, high: Int, step: Double) -> [PlannedSet] {
        let n = max(1, count)
        guard weight > 0 else {
            // 不知道重量（第一次做）或徒手：先用固定排法
            return Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
        }
        switch scheme {
        case .auto, .straight:
            return Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
        case .pyramid:
            return (0..<n).map { i in
                let t = n == 1 ? 1 : Double(i) / Double(n - 1)
                let w = round(weight * (0.8 + 0.2 * t), step: step)
                let r = Int((Double(high) - Double(high - low) * t).rounded())
                return PlannedSet(weight: w, reps: r, kind: .work)
            }
        case .reverse:
            return (0..<n).map { i in
                let w = round(weight * (1 - 0.1 * Double(i)), step: step)
                return PlannedSet(weight: w, reps: min(high, low + 2 * i), kind: .work)
            }
        case .dropset:
            var out = Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
            let d1 = round(weight * 0.75, step: step)
            let d2 = round(weight * 0.55, step: step)
            if d1 < weight { out.append(PlannedSet(weight: d1, reps: reps, kind: .drop)) }
            if d2 < d1 { out.append(PlannedSet(weight: d2, reps: reps, kind: .drop)) }
            return out
        }
    }

    /// 熱身組。first = 這個部位（推／拉／腿）今天第一個動作，做完整熱身；之後的複合動作只做 1 組。
    static func warmups(for exercise: Exercise, workWeight w: Double, first: Bool, step: Double) -> [PlannedSet] {
        guard exercise.loaded, w > 0, exercise.pattern.region != nil else { return [] }
        var out: [PlannedSet] = []
        if !first {
            let x = round(w * 0.6, step: step)
            if w >= 10 && x < w { out.append(PlannedSet(weight: x, reps: 6, kind: .warmup)) }
            return out
        }
        if exercise.requires.contains(.barbell) {
            guard w > barWeight else { return [] }
            out.append(PlannedSet(weight: barWeight, reps: 10, kind: .warmup))
            for (pct, reps) in [(0.5, 8), (0.7, 5), (0.85, 3)] {
                let x = round(w * pct, step: step)
                if x > (out.last?.weight ?? 0) && x < w { out.append(PlannedSet(weight: x, reps: reps, kind: .warmup)) }
            }
        } else {
            let plan: [(Double, Int)] = w >= 8 ? [(0.5, 10), (0.75, 5)] : (w >= 4 ? [(0.5, 10)] : [])
            for (pct, reps) in plan {
                let x = round(w * pct, step: step)
                if x > (out.last?.weight ?? 0) && x < w { out.append(PlannedSet(weight: x, reps: reps, kind: .warmup)) }
            }
        }
        return out
    }

    /// 這組做完要休息幾秒。下一組是遞減組就不休息；熱身組休息短一點。
    static func rest(after done: SetKind, next: SetKind?, normal: Int) -> Int {
        if next == .drop { return 0 }
        if done == .warmup { return next == .warmup ? 45 : 75 }
        return normal
    }
}
