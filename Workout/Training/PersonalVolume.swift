import SwiftUI

extension Keys {
    /// 練完的部位回報，JSON [MuscleFeedback]
    static let muscleFeedback = "muscleFeedback"
    /// 每個部位的個人組數調整（每週加減幾組），JSON [Muscle.rawValue: Int]
    static let muscleSetAdjust = "muscleSetAdjust"
    /// 每個區塊的組數檢討，JSON [BlockReview]
    static let volumeReviews = "volumeReviews"
    /// 已經檢討到第幾個區塊開始（Int）：等於目前區塊就代表上一個區塊檢討過了
    static let volumeReviewedBlock = "volumeReviewedBlock"
}

// MARK: - 資料

/// 練完回報的一個部位。
struct MuscleFeedback: Codable, Equatable {
    var muscle: String
    /// 秒
    var date: Double
    /// `Recovery.rawValue`；-1 = 沒答
    var recovery: Int
    /// 關節不舒服
    var joint: Bool
}

/// 上次練完的痠痛，這次練之前退了沒。
enum Recovery: Int, CaseIterable, Identifiable {
    case early, onTime, sore

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .early: "早就不痠"
        case .onTime: "剛好退"
        case .sore: "還在痠"
        }
    }

    var color: Color {
        switch self {
        case .early: Theme.accent
        case .onTime: Theme.green
        case .sore: Theme.hot
        }
    }
}

/// 一個部位在區塊結束時的決定。
struct MuscleDecision: Codable, Equatable, Identifiable {
    var muscle: String
    /// -1／0／+1
    var change: Int
    /// 這個區塊推估最大力量的進步幅度（比例）；nil = 紀錄太少
    var gain: Double?
    var reason: String
    /// 調整後，這個部位每週比一般建議多（少）幾組
    var offset: Int

    var id: String { muscle }
    var target: Muscle? { Muscle(rawValue: muscle) }
}

/// 一個區塊（6 週）的組數檢討。
struct BlockReview: Codable, Equatable {
    /// 檢討的是第幾個區塊（0 起算）
    var block: Int
    var date: Double
    var decisions: [MuscleDecision]

    var changes: [MuscleDecision] { decisions.filter { $0.change != 0 } }
}

/// 存在 UserDefaults 的 JSON 陣列。
enum JSONList {
    static func load<T: Decodable>(_ key: String) -> [T] {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let list = try? JSONDecoder().decode([T].self, from: Data(raw.utf8)) else { return [] }
        return list
    }

    static func save<T: Encodable>(_ list: [T], key: String) {
        guard let data = try? JSONEncoder().encode(list), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }
}

// MARK: - 個人組數

/// 學每個部位適合練多少組：練完問恢復，區塊結束時看力量進步和恢復，每個部位 +1／0／−1。
/// +1 = 每次練這個部位多 1 組（一週練 2 次，所以每週 +2 組）。
/// 只自動套用到內建課表（`VolumePlan.balance` 第 4 步）；自訂課表只在每週總結裡建議。
enum PersonalVolume {
    /// 一次調整每週加減幾組
    static let step = 2
    /// 每週最多比一般建議多（少）幾組
    static let limits = -4...6
    /// 一個區塊推估最大力量進步不到這個比例，就算「進步慢」
    static let slowGain = 0.025
    /// 個人加組時，每個動作最多幾組
    static let maxSetsPerExercise = 5

    static let store = KeyedStore<Int>(key: Keys.muscleSetAdjust)

    static func offset(_ m: Muscle) -> Int { store.load()[m.rawValue] ?? 0 }

    static var offsets: [Muscle: Int] {
        var out: [Muscle: Int] = [:]
        for (k, v) in store.load() where v != 0 {
            if let m = Muscle(rawValue: k) { out[m] = v }
        }
        return out
    }

    /// 這個部位的個人目標範圍（一般建議 + 個人調整）。
    static func range(for m: Muscle) -> ClosedRange<Double>? {
        guard let r = VolumePlan.range(for: m) else { return nil }
        let o = Double(offset(m))
        let low = max(2, r.lowerBound + o)
        return low...max(low, r.upperBound + o)
    }

    /// 這種動作主要練到、而且有目標的部位。
    static func targets(_ p: MovementPattern) -> [Muscle] {
        p.muscles.filter { $0.1 >= 1 && VolumePlan.range(for: $0.0) != nil }.map(\.0)
    }

    // MARK: 回報

    static func feedback() -> [MuscleFeedback] { JSONList.load(Keys.muscleFeedback) }

    static func record(_ answers: [MuscleFeedback]) {
        guard !answers.isEmpty else { return }
        var list = feedback() + answers
        if list.count > 400 { list.removeFirst(list.count - 400) }
        JSONList.save(list, key: Keys.muscleFeedback)
    }

    /// 練完要問的部位：今天主要練到，而且 10 天內練過（才有「上次的痠痛」可以問）。正式組多的在前，最多 4 個。
    static func musclesToAsk(done: [(exercise: Exercise, sets: Int)], history: [WorkoutSession], now: Date) -> [Muscle] {
        var today: [Muscle: Int] = [:]
        for d in done where d.sets > 0 {
            for m in targets(d.exercise.pattern) { today[m, default: 0] += d.sets }
        }
        guard !today.isEmpty else { return [] }
        let since = now.addingTimeInterval(-10 * 86400)
        var before = Set<Muscle>()
        for s in history where s.date >= since && s.date < now {
            for e in s.entries where e.isWork {
                if let ex = ExerciseLibrary.byId(e.exerciseId) { before.formUnion(targets(ex.pattern)) }
            }
        }
        return today.filter { before.contains($0.key) }
            .sorted { a, b in a.value != b.value ? a.value > b.value : a.key.groupOrder < b.key.groupOrder }
            .prefix(4).map(\.key)
    }

    // MARK: 區塊檢討

    /// 一個部位這段時間推估最大力量的進步幅度：每個主要練它的動作，比較前 2 次和最後 2 次的平均，
    /// 依次數加權平均。徒手動作用次數。至少要有一個動作練了 3 次以上，不然回傳 nil。
    static func gain(of m: Muscle, sessions: [WorkoutSession], from: Date, to: Date) -> Double? {
        var perExercise: [String: [(date: Date, value: Double)]] = [:]
        for s in sessions where s.date >= from && s.date < to {
            var best: [String: Double] = [:]
            for e in s.entries where e.isWork && e.reps > 0 {
                guard let ex = ExerciseLibrary.byId(e.exerciseId), targets(ex.pattern).contains(m) else { continue }
                let rir = e.rir >= 0 ? e.rir : 1
                let v = ex.loaded && e.weight > 0
                    ? ExerciseRecords.e1RM(weight: e.weight, reps: e.reps + rir)
                    : Double(e.reps)
                best[e.exerciseId] = max(best[e.exerciseId] ?? 0, v)
            }
            for (id, v) in best { perExercise[id, default: []].append((date: s.date, value: v)) }
        }
        var total = 0.0
        var weight = 0.0
        for list in perExercise.values where list.count >= 3 {
            let v = list.sorted { $0.date < $1.date }.map(\.value)
            let first = (v[0] + v[1]) / 2
            let last = (v[v.count - 1] + v[v.count - 2]) / 2
            guard first > 0 else { continue }
            let w = Double(v.count)
            total += (last / first - 1) * w
            weight += w
        }
        return weight > 0 ? total / weight : nil
    }

    enum RecoveryLevel { case good, poor, unknown }

    struct RecoverySummary {
        var answers = 0
        var sore = 0
        var joint = 0
        var pain = 0

        /// 會痛：減輕重量的「會痛」紀錄 1 次以上，或關節不舒服 2 次以上
        var hurts: Bool { pain >= 1 || joint >= 2 }

        var level: RecoveryLevel {
            if hurts || (answers >= 2 && sore * 2 >= answers) { return .poor }
            return answers >= 2 ? .good : .unknown
        }
    }

    static func recovery(of m: Muscle, from: Date, to: Date) -> RecoverySummary {
        var r = RecoverySummary()
        let a = from.timeIntervalSince1970, b = to.timeIntervalSince1970
        for f in feedback() where f.muscle == m.rawValue && f.date >= a && f.date < b {
            if f.recovery >= 0 { r.answers += 1 }
            if f.recovery == Recovery.sore.rawValue { r.sore += 1 }
            if f.joint { r.joint += 1 }
        }
        for p in Avoid.painLog() where p.date >= a && p.date < b {
            if let ex = ExerciseLibrary.byId(p.exerciseId), targets(ex.pattern).contains(m) { r.pain += 1 }
        }
        for item in Avoid.entries() where item.entry.kind == .pain && item.entry.date >= a && item.entry.date < b {
            if let ex = ExerciseLibrary.byId(item.id), targets(ex.pattern).contains(m) { r.pain += 1 }
        }
        return r
    }

    static func percent(_ g: Double) -> String {
        let p = (g * 100).rounded()
        return p > 0 ? "+\(Int(p))%" : "\(Int(p))%"
    }

    /// 一個部位的決定。
    static func decide(_ m: Muscle, gain g: Double?, recovery r: RecoverySummary, old: Int) -> MuscleDecision {
        var change = 0
        var reason: String
        if let g {
            if g >= slowGain {
                reason = "力量進步 \(percent(g))，照這個組數繼續"
            } else {
                switch r.level {
                case .good:
                    change = 1
                    reason = "力量只進步 \(percent(g))，恢復得不錯，每次多練 1 組"
                case .poor:
                    change = -1
                    reason = r.hurts
                        ? "力量只進步 \(percent(g))，而且有會痛的紀錄，每次少練 1 組"
                        : "力量只進步 \(percent(g))，而且常常到下次還在痠，每次少練 1 組"
                case .unknown:
                    reason = "力量只進步 \(percent(g))，但恢復的回報太少，先維持"
                }
            }
        } else {
            reason = "這段時間的紀錄太少，先維持"
        }
        var offset = old
        if change != 0 {
            let next = min(limits.upperBound, max(limits.lowerBound, old + change * step))
            if next == old {
                reason += change > 0 ? "（已經加到上限）" : "（已經減到下限）"
                change = 0
            }
            offset = next
        }
        return MuscleDecision(muscle: m.rawValue, change: change, gain: g, reason: reason, offset: offset)
    }

    /// 第 n 週開始的時間（從開始日算）。
    static func weekStart(_ n: Int, start: Date) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: (n - 1) * 7, to: cal.startOfDay(for: start)) ?? start
    }

    static func reviews() -> [BlockReview] { JSONList.load(Keys.volumeReviews) }

    /// 進到新的區塊時，檢討上一個區塊（不含適應期和減量週），更新個人組數。每個區塊只做一次。
    @discardableResult
    static func reviewIfNeeded(sessions: [WorkoutSession]) -> BlockReview? {
        let d = UserDefaults.standard
        let raw = d.double(forKey: Keys.startDate)
        guard raw > 0 else { return nil }
        let start = Date(timeIntervalSince1970: raw)
        let block = ProgramBuilder.block(week: Stats.week(since: start))
        guard block >= 1, d.integer(forKey: Keys.volumeReviewedBlock) < block else { return nil }
        d.set(block, forKey: Keys.volumeReviewedBlock)

        let prev = block - 1
        let bw = ProgramBuilder.blockWeeks
        let from = weekStart(max(3, prev * bw + 1), start: start)
        let to = weekStart(prev * bw + bw, start: start)   // 減量週之前
        var saved = store.load()
        var decisions: [MuscleDecision] = []
        for m in VolumePlan.targeted {
            let old = saved[m.rawValue] ?? 0
            let decision = decide(m, gain: gain(of: m, sessions: sessions, from: from, to: to),
                                  recovery: recovery(of: m, from: from, to: to), old: old)
            saved[m.rawValue] = decision.offset
            decisions.append(decision)
        }
        store.save(saved)
        let review = BlockReview(block: prev, date: Date.now.timeIntervalSince1970, decisions: decisions)
        var list = reviews().filter { $0.block != prev } + [review]
        if list.count > 12 { list.removeFirst(list.count - 12) }
        JSONList.save(list, key: Keys.volumeReviews)
        return review
    }

    /// 這一週結束時做的檢討（第 n 週是某個區塊的最後一週）。
    static func review(endingWeek n: Int) -> BlockReview? {
        guard n % ProgramBuilder.blockWeeks == 0 else { return nil }
        let block = n / ProgramBuilder.blockWeeks - 1
        return reviews().last { $0.block == block }
    }

    static func reset() {
        store.save([:])
    }
}

// MARK: - 練完的部位回報

/// 練完問今天練到的部位：上次練完的痠痛退了沒、關節舒不舒服。點一下就好，可以跳過。
struct MuscleCheckView: View {
    let muscles: [Muscle]
    let onDone: ([MuscleFeedback]) -> Void

    @State private var recovery: [Muscle: Recovery] = [:]
    @State private var joint: Set<Muscle> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("練到的部位怎麼樣？")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Theme.fg)
                    InfoTip(item: .personalSets)
                }
                Text("上次練完的痠痛，今天練之前退了嗎？App 會用這些回報，決定每個部位要多練還是少練。")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(muscles) { m in row(m) }
                }
                .padding(16)
            }

            HStack(spacing: 10) {
                Button("跳過") { onDone([]) }
                    .buttonStyle(GhostButtonStyle())
                    .frame(width: 96)
                Button("完成") {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDone(answers)
                }
                .buttonStyle(HotButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private var answers: [MuscleFeedback] {
        let now = Date.now.timeIntervalSince1970
        return muscles.compactMap { m in
            let r = recovery[m]
            let j = joint.contains(m)
            guard r != nil || j else { return nil }
            return MuscleFeedback(muscle: m.rawValue, date: now, recovery: r?.rawValue ?? -1, joint: j)
        }
    }

    private func row(_ m: Muscle) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(m.name).font(.headline.weight(.heavy)).foregroundStyle(Theme.fg)
                Spacer()
                let hurt = joint.contains(m)
                Button {
                    if hurt { joint.remove(m) } else { joint.insert(m) }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Label("關節不舒服", systemImage: hurt ? "checkmark.circle.fill" : "circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hurt ? Theme.hotText : Theme.muted)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(hurt ? Theme.hotBg : Theme.sunken, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                ForEach(Recovery.allCases) { r in
                    let on = recovery[m] == r
                    Button {
                        recovery[m] = on ? nil : r
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(r.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(on ? Theme.bg : Theme.fg)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(on ? r.color : Theme.sunken,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
