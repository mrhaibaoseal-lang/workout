import SwiftUI

/// 疲勞決定減量時機（0.26.0）：看最近 2 週的趨勢，決定要不要提早減量、能不能延後。
/// 訊號：訓練前狀態下滑、同重量越來越吃力、做到力竭的組變多、練完回報還在痠、好幾個動作卡住。
/// 0 個 = 正常，1 個 = 注意，2 個以上 = 該減量。
enum Fatigue {
    enum Level: Int, Comparable {
        case ok, watch, high
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }

        var title: String {
            switch self {
            case .ok: "正常"
            case .watch: "注意"
            case .high: "該減量"
            }
        }
    }

    struct Report {
        var level: Level
        /// 每個成立的訊號一句白話
        var reasons: [String]
        /// 最近幾次訓練前狀態的平均（3–15）；沒資料是 nil
        var readiness: Double?
        /// 個人基準（之前的中位數）；資料不夠是 nil
        var baseline: Double?
    }

    static let recentDays = 14
    static let baselineDays = 56

    /// sessions 要由新到舊排好。
    static func report(sessions: [WorkoutSession], now: Date = .now) -> Report {
        let recentFrom = now.addingTimeInterval(-Double(recentDays) * 86_400)
        let baseFrom = now.addingTimeInterval(-Double(baselineDays) * 86_400)
        var reasons: [String] = []

        // 1. 訓練前狀態：最近 4 次平均比之前的中位數低 2 分以上（基準不夠就看絕對值 ≤ 8）
        let scored = sessions.compactMap { s -> (Date, Int)? in
            Readiness.decode(s.readiness).map { (s.date, $0.total) }
        }
        let recent = scored.filter { $0.0 >= recentFrom }.prefix(4).map { Double($0.1) }
        let base = scored.filter { $0.0 < recentFrom && $0.0 >= baseFrom }.map { Double($0.1) }
        let recentAvg: Double? = recent.isEmpty ? nil : recent.reduce(0, +) / Double(recent.count)
        let baseline: Double? = base.count >= 4 ? median(base) : nil
        if let avg = recentAvg, recent.count >= 2 {
            if let b = baseline, b - avg >= 2 {
                reasons.append("訓練前狀態最近平均 \(fmt(avg)) 分，比你平常（\(fmt(b)) 分）低")
            } else if baseline == nil, recent.count >= 3, avg <= 8 {
                reasons.append("訓練前狀態最近平均只有 \(fmt(avg)) 分")
            }
        }

        // 2. 同重量越來越吃力：每個動作最近一次和前一次比，同重量的能力（次數＋還剩幾下）少 2 下以上
        let harder = harderExercises(sessions: sessions, from: recentFrom)
        if harder.compared >= 2, harder.ids.count >= 2,
           Double(harder.ids.count) / Double(harder.compared) >= 0.3 {
            let names = harder.ids.prefix(2).compactMap { ExerciseLibrary.byId($0)?.name }
            reasons.append("\(harder.ids.count) 個動作同樣重量越來越吃力（\(names.joined(separator: "、"))）")
        }

        // 3. 做到力竭（還剩 0 下）的組變多
        func failure(_ from: Date, _ to: Date) -> (n: Int, zero: Int) {
            let sets = sessions.filter { $0.date >= from && $0.date < to }
                .flatMap(\.entries).filter { $0.isWork && $0.rir >= 0 }
            return (sets.count, sets.filter { $0.rir == 0 }.count)
        }
        let fNow = failure(recentFrom, now.addingTimeInterval(1))
        let fBefore = failure(baseFrom, recentFrom)
        if fNow.n >= 8 {
            let r = Double(fNow.zero) / Double(fNow.n)
            let rb = fBefore.n >= 8 ? Double(fBefore.zero) / Double(fBefore.n) : 0.1
            if r >= 0.35 && r - rb >= 0.15 {
                reasons.append("最近 \(Int((r * 100).rounded()))% 的組做到力竭（還剩 0 下）")
            }
        }

        // 4. 練完回報「還在痠」變多
        let fb = PersonalVolume.feedback().filter { $0.date >= recentFrom.timeIntervalSince1970 && $0.recovery >= 0 }
        let sore = fb.filter { $0.recovery == Recovery.sore.rawValue }.count
        if sore >= 3, Double(sore) / Double(fb.count) >= 0.5 {
            reasons.append("練完回報有 \(sore) 次部位「還在痠」")
        }

        // 5. 好幾個動作卡住（原本的「停滯建議減量」）
        let stalled = Plateau.stalled(sessions: sessions).filter { $0.lastDate >= recentFrom }
        if stalled.count >= 3 {
            reasons.append("\(stalled.count) 個動作連續好幾次沒進步")
        }

        let level: Level = reasons.count >= 2 ? .high : (reasons.count == 1 ? .watch : .ok)
        return Report(level: level, reasons: reasons, readiness: recentAvg, baseline: baseline)
    }

    /// 最近一次訓練（在 from 之後）和上一次比，同重量能力掉 2 下以上的動作。
    private static func harderExercises(sessions: [WorkoutSession], from: Date) -> (compared: Int, ids: [String]) {
        var latest: [String: [SetEntry]] = [:]
        var previous: [String: [SetEntry]] = [:]
        for s in sessions {
            let byEx = Dictionary(grouping: s.entries.filter { $0.isWork && $0.weight > 0 && $0.reps > 0 },
                                  by: \.exerciseId)
            for (id, sets) in byEx {
                if latest[id] == nil {
                    if s.date >= from { latest[id] = sets }
                    else { latest[id] = [] }   // 最近沒練，不比
                } else if previous[id] == nil, !(latest[id] ?? []).isEmpty {
                    previous[id] = sets
                }
            }
        }
        var compared = 0
        var ids: [String] = []
        for (id, now) in latest where !now.isEmpty {
            guard let before = previous[id], !before.isEmpty else { continue }
            // 兩次都有做的最重重量，各取第一組（最不累的一組）
            let common = Set(now.map(\.weight)).intersection(before.map(\.weight))
            guard let w = common.max(),
                  let a = now.filter({ $0.weight == w }).min(by: { $0.setIndex < $1.setIndex }),
                  let b = before.filter({ $0.weight == w }).min(by: { $0.setIndex < $1.setIndex }) else { continue }
            compared += 1
            let useRir = a.rir >= 0 && b.rir >= 0
            let capA = a.reps + (useRir ? a.rir : 0)
            let capB = b.reps + (useRir ? b.rir : 0)
            if capB - capA >= 2 { ids.append(id) }
        }
        return (compared, ids.sorted())
    }

    private static func median(_ xs: [Double]) -> Double {
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    static func fmt(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
    }

    // MARK: 減量時機

    enum Offer {
        /// 疲勞高，建議提早減量
        case early(Report)
        /// 到了預定的減量週，狀態好、主項還在進步，可以延後
        case postpone(Report, improving: Int, total: Int)
    }

    /// 今天頁要不要問。sessions 由新到舊。
    static func offer(week: Int, sessions: [WorkoutSession], now: Date = .now) -> Offer? {
        guard !BlockClock.asked(week: week), !Comeback.rampUpActive, !Plateau.deloadActive else { return nil }
        let phase = ProgramBuilder.phase(week: week)
        let loc = BlockClock.locate(week: week)
        switch phase {
        case .normal:
            guard week >= loc.earliestEarly else { return nil }
            let r = report(sessions: sessions, now: now)
            return r.level == .high ? .early(r) : nil
        case .deload:
            // 只在減量週還沒開始練、而且是原本排的（沒有提早）時問
            guard week + 1 <= loc.latest, loc.deload >= loc.planned else { return nil }
            let weekStart = PersonalVolume.weekStart(week, start: Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Keys.startDate)))
            guard !sessions.contains(where: { $0.date >= weekStart }) else { return nil }
            let r = report(sessions: sessions, now: now)
            guard r.level == .ok else { return nil }
            if let avg = r.readiness, let b = r.baseline, avg < b { return nil }
            let blockFrom = PersonalVolume.weekStart(max(3, loc.start), start: Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Keys.startDate)))
            let t = MainLifts.trend(sessions: sessions, from: blockFrom)
            guard t.evaluated >= 2, Double(t.improved) / Double(t.evaluated) >= 0.5 else { return nil }
            return .postpone(r, improving: t.improved, total: t.evaluated)
        case .rampUp:
            return nil
        }
    }
}

/// 主要複合動作（不隨區塊輪替的那些）的進步趨勢。
enum MainLifts {
    static func isMain(_ id: String) -> Bool {
        ExerciseLibrary.byId(id)?.pattern.region != nil
    }

    /// 一次訓練裡這個動作的表現：負重看推估最大力量，徒手看最多次數。
    static func value(_ sets: [SetEntry], loaded: Bool) -> Double {
        let valid = sets.filter { $0.isWork && $0.reps > 0 && (!loaded || $0.weight > 0) }
        if loaded {
            return valid.map { ExerciseRecords.e1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
        }
        return Double(valid.map(\.reps).max() ?? 0)
    }

    /// from 以後練 2 次以上、之前也練過的主項：有沒有超過之前的最佳。sessions 由新到舊。
    static func trend(sessions: [WorkoutSession], from: Date) -> (evaluated: Int, improved: Int, stalled: [String]) {
        var inWindow: [String: [Double]] = [:]
        var before: [String: Double] = [:]
        for s in sessions {
            for (id, sets) in Dictionary(grouping: s.entries.filter(\.isWork), by: \.exerciseId) where isMain(id) {
                guard let ex = ExerciseLibrary.byId(id) else { continue }
                let v = value(sets, loaded: ex.loaded)
                guard v > 0 else { continue }
                if s.date >= from { inWindow[id, default: []].append(v) }
                else { before[id] = max(before[id] ?? 0, v) }
            }
        }
        var evaluated = 0
        var improved = 0
        var stalled: [String] = []
        for (id, vs) in inWindow where vs.count >= 2 {
            guard let b = before[id] else { continue }
            evaluated += 1
            if (vs.max() ?? 0) > b + 0.001 { improved += 1 } else { stalled.append(id) }
        }
        return (evaluated, improved, stalled.sorted())
    }
}

// MARK: - 今天頁的卡片

struct DeloadOfferCard: View {
    let offer: Fatigue.Offer
    let onAccept: () -> Void
    let onDecline: () -> Void

    private var isEarly: Bool {
        switch offer {
        case .early: return true
        case .postpone: return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(isEarly ? "建議這週減量" : "狀態很好，要延後減量嗎？",
                      systemImage: isEarly ? "arrow.down.heart.fill" : "flame.fill")
                    .font(.headline)
                    .foregroundStyle(isEarly ? Theme.gold : Theme.green)
                Spacer()
                InfoTip(item: .fatigue)
            }
            switch offer {
            case .early(let r):
                Text("最近疲勞在累積，這週先減量（組數少一點、重量輕兩成），恢復後下週換一批動作再衝。")
                    .font(.subheadline).foregroundStyle(Theme.fg)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(r.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "exclamationmark.circle")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            case .postpone(_, improving: let improving, total: let total):
                Text("這週原本是減量週。最近狀態穩定，\(total) 個主要動作有 \(improving) 個還在進步，可以多練 1 週再減量。")
                    .font(.subheadline).foregroundStyle(Theme.fg)
            }
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text(isEarly ? "這週減量" : "延後 1 週")
                }
                .buttonStyle(HotButtonStyle(height: 44))
                Button(action: onDecline) {
                    Text(isEarly ? "再撐一週" : "照原本減量").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
                .frame(maxWidth: 130)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(isEarly ? Theme.gold.opacity(0.5) : Theme.accentDim, lineWidth: 1))
    }
}
