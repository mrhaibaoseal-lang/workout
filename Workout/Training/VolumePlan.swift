import SwiftUI

/// 依「每個部位每週組數」平衡課表。部位怎麼算沿用 `MovementPattern.muscles`
/// （主要出力 1 組、次要出力算半組），和部位熱圖一致。
///
/// 目標：主要部位（胸、背闊、股四頭、大腿後側、臀、側三角肌、二頭、三頭）每週 10～16 組；
/// 次要部位（後三角肌、小腿、腹肌、前三角肌、斜方肌）下限 6、上限 16。前臂、腹斜肌、下背不管。
enum VolumePlan {
    static let primary: [Muscle] = [.chest, .lats, .quads, .hamstrings, .glutes, .sideDelt, .biceps, .triceps]
    static let secondary: [Muscle] = [.rearDelt, .calves, .abs, .frontDelt, .traps]
    /// 每個動作最多排幾個正式組（平衡時不會超過）。
    static let maxSetsPerExercise = 4
    /// 每天最多因為平衡多加幾組。
    static let maxAddPerDay = 2
    /// 平衡後一天比平衡前最多多幾組，超過就扣。
    static let maxExtraPerDay = 3

    static func range(for m: Muscle) -> ClosedRange<Double>? {
        if primary.contains(m) { return 10...16 }
        if secondary.contains(m) { return 6...16 }
        return nil
    }

    /// 有目標的部位，依畫面分組排好。
    static var targeted: [Muscle] { Muscle.ordered.filter { range(for: $0) != nil } }

    /// 低於下限用 `MuscleStats` 的「太少／快達標」，範圍內「剛好」，超過 upper「偏多」。
    static func status(_ m: Muscle, sets: Double, upper: Double? = nil, range custom: ClosedRange<Double>? = nil) -> MuscleStatus {
        guard let r = custom ?? range(for: m) else { return MuscleStats.status(sets) }
        if sets <= 0 { return .none }
        if sets < r.lowerBound { return sets < 6 ? .low : .building }
        if sets > (upper ?? r.upperBound) { return .high }
        return .good
    }

    // MARK: 算組數

    /// 每週每個部位的組數。plans = 每個課表日排出來的動作。
    static func weekly(plans: [[PlannedExercise]]) -> [Muscle: Double] {
        var slots: [(pattern: MovementPattern, sets: Int)] = []
        for day in plans {
            for item in day { slots.append((pattern: item.exercise.pattern, sets: item.sets)) }
        }
        return weekly(slots: slots)
    }

    /// 直接用「動作類型 + 組數」算（自訂課表編輯用，不用真的排）。
    static func weekly(slots: [(pattern: MovementPattern, sets: Int)]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for s in slots {
            for (m, w) in s.pattern.muscles { out[m, default: 0] += w * Double(s.sets) }
        }
        return out
    }

    private static func weekly(patterns: [[MovementPattern]], sets: [[Int]]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for d in patterns.indices {
            for i in patterns[d].indices where i < sets[d].count {
                for (m, w) in patterns[d][i].muscles { out[m, default: 0] += w * Double(sets[d][i]) }
            }
        }
        return out
    }

    static func primaryMuscles(_ p: MovementPattern) -> Set<Muscle> {
        Set(p.muscles.filter { $0.1 >= 1 }.map { $0.0 })
    }

    // MARK: 平衡

    /// 一個課表日的輸入：每個動作的類型和組數（已經套用適應期／減量週），
    /// 以及因為器材沒有而跳過的課表格（類型和原本會排的組數）。
    struct DayInput {
        var patterns: [MovementPattern]
        var sets: [Int]
        var lost: [(pattern: MovementPattern, sets: Int)]
    }

    /// 回傳每天每個動作平衡後的組數（動作數量不變）。
    /// 1. 因器材跳過的格子，把組數補到同一天、主要部位相同的動作（每個動作最多 4 組）。
    /// 2. 進步期：部位一週組數低於下限，就在它「主要出力的單關節動作」加組（每個動作最多 4 組、每天最多加 2 組），輪流加到達標或加不了。
    ///    適應期／減量週本來就刻意少練，不補。
    /// 3. 某天比平衡前多超過 3 組，從「最超過上限的部位」的動作扣（不扣到低於 2 組）。
    /// 4. 進步期：個人組數（`PersonalVolume`，區塊檢討的結果），每週對這個部位加減幾組。
    static func balance(days: [DayInput], phase: Phase, personal: [Muscle: Int] = [:]) -> [[Int]] {
        let patterns = days.map(\.patterns)
        var sets = days.map(\.sets)
        let before = sets.map { $0.reduce(0, +) }

        // 1. 補回跳過的格子
        for d in days.indices {
            for lost in days[d].lost {
                let wanted = primaryMuscles(lost.pattern)
                var remaining = lost.sets
                while remaining > 0 {
                    let open = patterns[d].indices.filter { i in
                        sets[d][i] < maxSetsPerExercise && !wanted.isDisjoint(with: primaryMuscles(patterns[d][i]))
                    }
                    guard let pick = open.min(by: { sets[d][$0] < sets[d][$1] }) else { break }
                    sets[d][pick] += 1
                    remaining -= 1
                }
            }
        }

        // 2. 補不足的部位
        if phase == .normal {
            var added = Array(repeating: 0, count: days.count)
            while let (d, i) = nextAddition(patterns: patterns, sets: sets, added: added) {
                sets[d][i] += 1
                added[d] += 1
            }
        }

        // 3. 一天不要多太多
        for d in days.indices {
            var extra = sets[d].reduce(0, +) - before[d]
            while extra > maxExtraPerDay {
                let total = weekly(patterns: patterns, sets: sets)
                var pick: Int?
                var bestScore = -Double.infinity
                for i in patterns[d].indices where sets[d][i] > 2 {
                    let score = overshoot(patterns[d][i], total: total)
                    if score >= bestScore { bestScore = score; pick = i }
                }
                guard let i = pick else { break }
                sets[d][i] -= 1
                extra -= 1
            }
        }

        // 4. 個人組數
        if phase == .normal {
            for m in targeted {
                guard let delta = personal[m], delta != 0 else { continue }
                applyPersonal(m, delta: delta, patterns: patterns, sets: &sets)
            }
        }
        return sets
    }

    /// 對部位 m 加（減）|delta| 組：輪流分到不同天；加組優先單關節、組數少的，減組優先單關節、組數多的。
    private static func applyPersonal(_ m: Muscle, delta: Int, patterns: [[MovementPattern]], sets: inout [[Int]]) {
        var perDay = Array(repeating: 0, count: patterns.count)
        for _ in 0..<abs(delta) {
            var best: (d: Int, i: Int)?
            var bestKey = (Int.max, Int.max, Int.max)
            for d in patterns.indices {
                for i in patterns[d].indices where primaryMuscles(patterns[d][i]).contains(m) {
                    let n = sets[d][i]
                    if (delta > 0 && n >= PersonalVolume.maxSetsPerExercise) || (delta < 0 && n <= 2) { continue }
                    let key = (perDay[d], patterns[d][i].region == nil ? 0 : 1, delta > 0 ? n : -n)
                    if key < bestKey { bestKey = key; best = (d, i) }
                }
            }
            guard let b = best else { return }
            sets[b.d][b.i] += delta > 0 ? 1 : -1
            perDay[b.d] += 1
        }
    }

    /// 這個動作主要出力的部位，最超過上限多少組（沒有目標的部位不算）。
    private static func overshoot(_ p: MovementPattern, total: [Muscle: Double]) -> Double {
        let scores = p.muscles.compactMap { m, c -> Double? in
            guard c >= 1, let r = range(for: m) else { return nil }
            return (total[m] ?? 0) - r.upperBound
        }
        return scores.max() ?? -100
    }

    /// 下一個要加 1 組的位置：缺最多的部位，在它主要出力的單關節動作裡挑目前組數最少的。
    private static func nextAddition(patterns: [[MovementPattern]], sets: [[Int]], added: [Int]) -> (Int, Int)? {
        let total = weekly(patterns: patterns, sets: sets)
        let lacking = targeted
            .compactMap { m -> (Muscle, Double)? in
                guard let r = range(for: m), (total[m] ?? 0) < r.lowerBound else { return nil }
                return (m, r.lowerBound - (total[m] ?? 0))
            }
            .sorted { $0.1 > $1.1 }
        for (m, _) in lacking {
            var best: (Int, Int)?
            for d in patterns.indices where added[d] < maxAddPerDay {
                for i in patterns[d].indices {
                    let p = patterns[d][i]
                    guard p.region == nil, sets[d][i] < maxSetsPerExercise, primaryMuscles(p).contains(m) else { continue }
                    if let b = best, sets[b.0][b.1] <= sets[d][i] { continue }
                    best = (d, i)
                }
            }
            if let best { return best }
        }
        return nil
    }

    // MARK: 提醒（自訂課表用）

    /// 自訂課表：低於下限或超過 upper 的部位，各一句白話提醒。
    static func advice(_ sets: [Muscle: Double], upper: Double = 20) -> [String] {
        var out: [String] = []
        for m in targeted {
            guard let r = range(for: m) else { continue }
            let s = sets[m] ?? 0
            if s < r.lowerBound {
                out.append("\(m.name)每週只有 \(Progression.format(s)) 組，低於 \(Int(r.lowerBound)) 組，成長會比較慢。")
            } else if s > upper {
                out.append("\(m.name)每週 \(Progression.format(s)) 組，超過 \(Int(upper)) 組，恢復可能跟不上。")
            }
        }
        return out
    }
}

/// 每個有目標的部位一行：組數、目標範圍、顏色。
struct VolumeTable: View {
    let sets: [Muscle: Double]
    /// 超過這個數字標成「偏多」；nil = 用部位自己的上限（16）。
    var upper: Double? = nil
    /// 目標用個人組數（`PersonalVolume`）：內建課表用
    var personal = false

    var body: some View {
        let muscles = VolumePlan.targeted
        VStack(spacing: 0) {
            ForEach(muscles) { m in
                row(m)
                if m != muscles.last { Divider().overlay(Theme.divider) }
            }
        }
    }

    private func row(_ m: Muscle) -> some View {
        let value = sets[m] ?? 0
        let range = personal ? PersonalVolume.range(for: m) : VolumePlan.range(for: m)
        let status = VolumePlan.status(m, sets: value, upper: personal ? nil : upper, range: range)
        let target = range.map { "目標 \(Int($0.lowerBound))–\(Int($0.upperBound))" } ?? ""
        let offset = personal ? PersonalVolume.offset(m) : 0
        return HStack(spacing: 10) {
            Circle().fill(status.color).frame(width: 9, height: 9)
            Text(m.name).font(.subheadline).foregroundStyle(Theme.fg)
            if offset != 0 {
                Text(offset > 0 ? "你 +\(offset)" : "你 \(offset)")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(offset > 0 ? Theme.green : Theme.hotText)
            }
            Spacer()
            Text(target).font(.caption).foregroundStyle(Theme.muted)
            Text(Progression.format(value))
                .font(Theme.number(15))
                .foregroundStyle(status.color)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .padding(.vertical, 7)
    }
}

/// 今天頁的「本週預計組數」：點開才算。
struct WeeklyVolumeCard: View {
    let plans: () -> [[PlannedExercise]]
    /// 內建課表：目標用個人組數
    var personal = false
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 2) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { open.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .foregroundStyle(Theme.accent)
                        Text("本週預計組數").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                        Spacer(minLength: 0)
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.bold)).foregroundStyle(Theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                InfoTip(item: .weeklySets)
            }
            if open {
                VolumeTable(sets: VolumePlan.weekly(plans: plans()), personal: personal)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
