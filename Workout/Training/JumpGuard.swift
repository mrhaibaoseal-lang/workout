import Foundation

extension Keys {
    /// 「重量跳太大」時暫時拉長的次數上限，JSON [exerciseId: Int]
    static let repCeiling = "repCeiling"
    /// 這個動作暫時多 1 組，JSON [exerciseId: Bool]
    static let extraSet = "extraSet"
    /// 加重後次數會掉很多，暫時降低的次數範圍，JSON [exerciseId: [low, high]]
    static let tempRange = "tempRange"
}

/// 啞鈴最小只能加 2.5 kg，輕重量一次就跳 20% 以上。直接加重次數會掉到很少，
/// 所以先拉長次數上限、再加一組，最後才加重並暫時降低次數範圍。
///
/// 狀態存在 UserDefaults（三個 Keys），`Progression.suggest` 只讀不寫；
/// 練完存檔時 `record` 才依這次的成績更新，所以建議是穩定可重現的。
enum JumpGuard {
    static let ceilings = KeyedStore<Int>(key: Keys.repCeiling)
    static let extras = KeyedStore<Bool>(key: Keys.extraSet)
    static let temps = KeyedStore<[Int]>(key: Keys.tempRange)

    /// 單關節動作次數上限最多拉到 25，複合動作 15。
    static func ceilingLimit(_ ex: Exercise) -> Int {
        ex.pattern.region == nil ? 25 : 15
    }

    static func ceiling(_ id: String) -> Int? { ceilings[id] }
    static func hasExtraSet(_ id: String) -> Bool { extras[id] ?? false }
    static func tempRange(_ id: String) -> (low: Int, high: Int)? {
        guard let t = temps[id], t.count == 2 else { return nil }
        return (t[0], t[1])
    }

    /// 排課時套用：暫時範圍取代原範圍；否則次數上限用延長後的；多 1 組。
    static func adjust(id: String, low: Int, high: Int, sets: Int) -> (low: Int, high: Int, sets: Int) {
        var out = (low: low, high: high, sets: sets)
        if let t = tempRange(id) {
            out.low = t.low
            out.high = max(t.low, t.high)
        } else if let c = ceiling(id), c > high {
            out.high = c
        }
        if hasExtraSet(id) { out.sets += 1 }
        return out
    }

    private static func clearLadder(_ id: String) {
        if ceilings[id] != nil { ceilings[id] = nil }
        if extras[id] != nil { extras[id] = nil }
    }

    // MARK: 判斷

    /// 用 Epley 公式估：在 next 這個重量，做到力竭能做幾下；扣 1 下當作留力氣。
    static func predictedReps(weight w: Double, reps: Int, rir: Int, next: Double) -> Int {
        guard w > 0, next > 0 else { return 0 }
        let e1rm = w * (1 + Double(reps + rir) / 30)
        let toFailure = 30 * (e1rm / next - 1)
        return Int(toFailure.rounded(.down)) - 1
    }

    enum Decision: Equatable {
        /// 照常加重，建議這麼多下
        case heavy(reps: Int)
        /// 先不加重，把次數上限拉長
        case extend(ceiling: Int, pct: Int)
        /// 次數上限到了，加 1 組
        case extraSet(pct: Int)
        /// 該做的都做了，加重，並暫時降低次數範圍（reps = 預計能做的下數）
        case heavyTemp(reps: Int, low: Int, high: Int, pct: Int)
    }

    /// last = 上次的正式組（top = 最重那幾組）。只在「全部達標、下一級比較重」時呼叫。
    static func evaluate(item: PlannedExercise, lastWeight w: Double, top: [SetEntry], next: Double) -> Decision {
        let best = top.max { $0.reps < $1.reps }
        let reps = best?.reps ?? item.low
        let rir = (best?.rir ?? -1) >= 0 ? (best?.rir ?? 1) : 1
        let pred = predictedReps(weight: w, reps: reps, rir: rir, next: next)
        let pct = Int(((next - w) / w * 100).rounded())
        if pred >= item.low {
            return .heavy(reps: min(max(pred, item.low), item.baseHigh))
        }
        let limit = ceilingLimit(item.exercise)
        if item.high < limit { return .extend(ceiling: limit, pct: pct) }
        if !hasExtraSet(item.exercise.id) { return .extraSet(pct: pct) }
        let n = max(pred, 5)
        if n >= item.baseLow { return .heavy(reps: min(n, item.baseHigh)) }
        return .heavyTemp(reps: n, low: n, high: item.baseLow, pct: pct)
    }

    /// 暫時範圍進行中、而且又全部做到暫時上限：已經爬回原本的範圍，不再加重。
    static func recoveredNote(_ item: PlannedExercise) -> String {
        "已經爬回原本的次數範圍，先維持這個重量，做到 \(item.baseHigh) 下再加重"
    }

    // MARK: 練完存檔

    /// 練完一個動作後更新狀態。last = 這次做完的正式組。只在進步期、有負重的動作處理。
    static func record(item: PlannedExercise, last: [SetEntry], phase: Phase, ladder: WeightLadder, scheme: SetScheme) {
        guard phase == .normal, item.exercise.loaded, !last.isEmpty else { return }
        let id = item.exercise.id
        let w = last.map(\.weight).max() ?? 0
        guard w > 0 else { return }
        let top = last.filter { $0.weight >= w }
        // 暫時範圍：某次全部組都做到原本的下限，就回到原本的範圍
        if tempRange(id) != nil {
            if top.allSatisfy({ $0.reps >= item.baseLow }) { temps[id] = nil }
            return
        }
        let target = SetPlanner.targetReps(scheme: scheme, low: item.low, high: item.high)
        guard top.allSatisfy({ $0.reps >= target }) else { return }
        let next = ladder.up(w)
        guard next > w + 0.01 else { return }
        switch evaluate(item: item, lastWeight: w, top: top, next: next) {
        case .heavy:
            clearLadder(id)
        case .extend(let c, _):
            ceilings[id] = c
        case .extraSet:
            extras[id] = true
        case .heavyTemp(_, let lo, let hi, _):
            clearLadder(id)
            temps[id] = [lo, hi]
        }
    }
}
