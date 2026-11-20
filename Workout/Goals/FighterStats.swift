import SwiftUI

/// 角色屬性（0–99），由訓練紀錄算出。
struct FighterStats {
    var strength = 0
    var legs = 0
    var stamina = 0
    var grit = 0

    var total: Int { strength + legs + stamina + grit }
    /// 加在角色戰力上的數字
    var power: Int { total * 3 }

    private static let upper: Set<MovementPattern> = [.hPush, .incline, .vPush, .hPull, .vPull, .biceps, .triceps, .lateral, .rear]
    private static let lower: Set<MovementPattern> = [.squat, .hinge, .lunge, .glute, .hamCurl, .quadIso, .calf]

    static func compute(sessions: [WorkoutSession], streak: Int, now: Date = .now) -> FighterStats {
        var first: [String: Double] = [:]
        var best: [String: Double] = [:]
        var upperSessions = 0, lowerSessions = 0
        var recentSets = 0
        let cutoff = now.addingTimeInterval(-28 * 86400)
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            var hitUpper = false, hitLower = false
            var dayBest: [String: Double] = [:]
            for e in s.entries where e.isWork {
                guard let ex = ExerciseLibrary.byId(e.exerciseId) else { continue }
                let v = ex.loaded ? e.weight * (1 + Double(e.reps) / 30) : Double(e.reps)
                dayBest[e.exerciseId] = max(dayBest[e.exerciseId] ?? 0, v)
                if upper.contains(ex.pattern) { hitUpper = true }
                if lower.contains(ex.pattern) { hitLower = true }
                if s.date >= cutoff { recentSets += 1 }
            }
            for (id, v) in dayBest {
                if first[id] == nil { first[id] = v }
                best[id] = max(best[id] ?? 0, v)
            }
            if hitUpper { upperSessions += 1 }
            if hitLower { lowerSessions += 1 }
        }

        func growth(_ patterns: Set<MovementPattern>) -> Double {
            let ratios = first.compactMap { id, f -> Double? in
                guard f > 0, let ex = ExerciseLibrary.byId(id), patterns.contains(ex.pattern) else { return nil }
                return (best[id] ?? f) / f
            }
            return ratios.isEmpty ? 1 : ratios.reduce(0, +) / Double(ratios.count)
        }
        func clamp(_ x: Double) -> Int { max(0, min(99, Int(x.rounded()))) }

        var st = FighterStats()
        guard !sessions.isEmpty else { return st }
        st.strength = clamp(20 + (growth(upper) - 1) * 150 + min(20, Double(upperSessions) / 2))
        st.legs = clamp(20 + (growth(lower) - 1) * 150 + min(20, Double(lowerSessions) / 2))
        st.stamina = clamp(Double(recentSets) / 4)
        st.grit = clamp(10 + Double(streak) * 6)
        return st
    }
}

/// 角色頁：狀態＋四個屬性。
struct FighterStatsCard: View {
    let stats: FighterStats
    let condition: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let c = condition {
                let col = conditionColor(c)
                HStack(spacing: 10) {
                    Image(systemName: conditionIcon(c)).foregroundStyle(col).frame(width: 22)
                    Text("狀態").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Text(GoalEngine.conditionName(c)).font(.subheadline.weight(.heavy)).foregroundStyle(col)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(col).frame(width: g.size.width * Double(c) / 100)
                        }
                    }
                    .frame(height: 6)
                    Text("\(c)").font(Theme.number(14)).foregroundStyle(Theme.fg).frame(width: 30, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("狀態 \(GoalEngine.conditionName(c))，\(c)")
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 10) {
                stat("力量", "上半身進步", stats.strength, Theme.hot, "figure.arms.open")
                stat("下盤", "下半身進步", stats.legs, Theme.accent, "figure.strengthtraining.functional")
                stat("耐力", "近 28 天組數", stats.stamina, Theme.green, "heart.fill")
                stat("韌性", "連續週數", stats.grit, Theme.gold, "flame.fill")
            }
        }
        .themeCard(padding: 14)
    }

    private func stat(_ name: String, _ hint: String, _ v: Int, _ col: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2).foregroundStyle(col)
                Text(name).font(.caption.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                Text("\(v)").font(Theme.number(15)).foregroundStyle(Theme.fg)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(col).frame(width: g.size.width * Double(v) / 99)
                }
            }
            .frame(height: 5)
            Text(hint).font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(v)，依\(hint)")
    }

    private func conditionColor(_ c: Int) -> Color {
        switch c {
        case 80...: Theme.green
        case 50..<80: Theme.accent
        case 25..<50: Theme.gold
        default: Theme.hot
        }
    }

    private func conditionIcon(_ c: Int) -> String {
        switch c {
        case 80...: "bolt.heart.fill"
        case 50..<80: "heart.fill"
        case 25..<50: "battery.25"
        default: "zzz"
        }
    }
}
