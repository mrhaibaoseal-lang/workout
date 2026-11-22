import Foundation

/// 破個人紀錄的定義（訓練中、牌位、週任務共用）。0.30.0 起：
/// - 重量紀錄：最重的正式組超過這個動作以前的最高重量；
/// - 次數紀錄：用以前的最高重量，做了比以前更多下（在家啞鈴加到頂後還有紀錄可以破）。
/// 第一次做不算。只看有負重動作的正式組。
struct PRBest: Equatable {
    var weight: Double
    /// 用最高重量做過最多幾下
    var reps: Int
}

enum PRKind: Equatable {
    case weight(old: Double)
    case reps(old: Int)
}

enum PRRule {
    /// 這組和以前的最佳比：破了哪一種紀錄（沒有 = nil）。
    static func check(weight: Double, reps: Int, best: PRBest?) -> PRKind? {
        guard weight > 0, reps > 0, let best else { return nil }
        if weight > best.weight + 0.01 { return .weight(old: best.weight) }
        if abs(weight - best.weight) <= 0.01 && reps > best.reps { return .reps(old: best.reps) }
        return nil
    }

    /// 把這組算進最佳。
    static func merge(_ best: PRBest?, weight: Double, reps: Int) -> PRBest {
        guard let best else { return PRBest(weight: weight, reps: reps) }
        if weight > best.weight + 0.01 { return PRBest(weight: weight, reps: reps) }
        if abs(weight - best.weight) <= 0.01 { return PRBest(weight: best.weight, reps: max(best.reps, reps)) }
        return best
    }

    /// 一次訓練裡一個動作的正式組：有沒有破紀錄（每個動作最多算 1 個），並回傳更新後的最佳。
    static func session(sets: [(weight: Double, reps: Int)], best: PRBest?) -> (pr: Bool, best: PRBest) {
        var pr = false
        var b = best
        for s in sets where s.weight > 0 && s.reps > 0 {
            if b != nil, check(weight: s.weight, reps: s.reps, best: b) != nil { pr = true }
            b = merge(b, weight: s.weight, reps: s.reps)
        }
        return (pr && best != nil, b ?? PRBest(weight: 0, reps: 0))
    }

    /// 以前所有紀錄的最佳（正式組）。
    static func bests(_ sessions: [WorkoutSession]) -> [String: PRBest] {
        var out: [String: PRBest] = [:]
        for s in sessions {
            for e in s.entries where e.isWork && e.weight > 0 && e.reps > 0 {
                out[e.exerciseId] = merge(out[e.exerciseId], weight: e.weight, reps: e.reps)
            }
        }
        return out
    }
}
