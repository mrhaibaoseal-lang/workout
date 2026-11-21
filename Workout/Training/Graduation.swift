import SwiftUI

extension Keys {
    /// TrainingLevel.rawValue：新手／中階
    static let trainingLevel = "trainingLevel"
    /// 按「再等等」的時間（秒）：之後 2 週不再問
    static let graduationSnooze = "graduationSnooze"
    /// 升中階的時間（秒）
    static let graduatedAt = "graduatedAt"
}

enum TrainingLevel: String, CaseIterable, Identifiable {
    case beginner, intermediate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "新手"
        case .intermediate: "中階"
        }
    }

    var detail: String {
        switch self {
        case .beginner: "每個動作固定一個次數範圍，做到上限就加重。"
        case .intermediate: "主要動作一天重（6–8 下）、一天輕（12–15 下），區塊裡每 2 週加組數。"
        }
    }
}

/// 主要動作這天練重、輕還是中（中階才有）。
enum Intensity {
    case heavy, light, medium

    var range: ClosedRange<Int>? {
        switch self {
        case .heavy: 6...8
        case .light: 12...15
        case .medium: nil
        }
    }

    var tag: String? {
        switch self {
        case .heavy: "重"
        case .light: "輕"
        case .medium: nil
        }
    }
}

/// 新手畢業到中階（0.26.0）。
/// 條件：至少 12 個有練的週（一週練 2 次以上），減量後主要動作還是六成以上 3 週沒進步，疲勞也不高（高的話先減量）。
/// 條件到了今天頁問使用者，按了才換；設定裡可以切回新手。
enum Graduation {
    static let minTrainedWeeks = 12
    static let stallShare = 0.6
    static let snoozeDays = 14

    static var level: TrainingLevel {
        TrainingLevel(rawValue: UserDefaults.standard.string(forKey: Keys.trainingLevel) ?? "") ?? .beginner
    }

    /// 中階排法只套用在內建課表（自訂課表照使用者填的）。
    static var intermediateActive: Bool {
        level == .intermediate && CustomPrograms.active == nil
    }

    static func setLevel(_ l: TrainingLevel) {
        let d = UserDefaults.standard
        d.set(l.rawValue, forKey: Keys.trainingLevel)
        if l == .intermediate { d.set(Date.now.timeIntervalSince1970, forKey: Keys.graduatedAt) }
    }

    static func snooze() {
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Keys.graduationSnooze)
    }

    /// 這天的主要動作練重還是輕。4 天上下肢：A 重、B 輕；3 天全身：A 重、B 輕、C 中。
    static func intensity(dayId: String) -> Intensity {
        switch dayId {
        case "upperA", "lowerA", "fullA": .heavy
        case "upperB", "lowerB", "fullB": .light
        default: .medium
        }
    }

    /// 有練的週數（一週練 2 次以上）。
    static func trainedWeeks(_ sessions: [WorkoutSession]) -> Int {
        let byWeek = Dictionary(grouping: sessions, by: { SharedStore.weekStart($0.date) })
        return byWeek.values.filter { $0.count >= 2 }.count
    }

    struct Offer {
        let weeks: Int
        let stalled: [String]
        let evaluated: Int
    }

    /// 今天頁要不要問升中階。sessions 由新到舊。
    static func offer(week: Int, sessions: [WorkoutSession], now: Date = .now) -> Offer? {
        guard level == .beginner, CustomPrograms.active == nil else { return nil }
        let d = UserDefaults.standard
        let snoozed = d.double(forKey: Keys.graduationSnooze)
        if snoozed > 0, now.timeIntervalSince1970 - snoozed < Double(snoozeDays) * 86_400 { return nil }
        guard ProgramBuilder.phase(week: week) == .normal else { return nil }
        let weeks = trainedWeeks(sessions)
        guard weeks >= minTrainedWeeks else { return nil }
        // 先減量再判斷：要減量過，而且減量後至少練了 2 週（這週是第 3 週以上）
        guard let lastDeload = BlockClock.lastDeload(before: week), week - lastDeload >= 3 else { return nil }
        // 疲勞高 → 先走減量，不判畢業
        if Fatigue.report(sessions: sessions, now: now).level == .high { return nil }
        let start = Date(timeIntervalSince1970: d.double(forKey: Keys.startDate))
        // 看最近 3 週（不超過減量之後）
        let from = PersonalVolume.weekStart(max(lastDeload + 1, week - 2), start: start)
        let t = MainLifts.trend(sessions: sessions, from: from)
        guard t.evaluated >= 3, Double(t.stalled.count) / Double(t.evaluated) >= stallShare else { return nil }
        return Offer(weeks: weeks, stalled: t.stalled, evaluated: t.evaluated)
    }

    /// 剛換成重日／輕日：上次的次數離新範圍太遠（多或少 3 下以上），用推估最大力量換算這次的重量（留 2 下）。
    static func rangeSwitch(_ item: PlannedExercise, top: [SetEntry], lastWeight: Double,
                            ladder: WeightLadder) -> Suggestion? {
        guard let i = item.intensity, i != .medium, item.exercise.loaded, lastWeight > 0 else { return nil }
        let best = top.map(\.reps).max() ?? 0
        guard best > item.high + 2 || best < item.low - 2 else { return nil }
        let e1 = top.map { Comeback.e1rm(weight: $0.weight, reps: $0.reps, rir: $0.rir) }.max() ?? 0
        guard e1 > 0 else { return nil }
        let target = (item.low + item.high) / 2
        let w = ladder.snap(e1 / (1 + Double(target + 2) / 30))
        guard w > 0, abs(w - lastWeight) > 0.01 else { return nil }
        let day = i == .heavy ? "重日" : "輕日"
        return Suggestion(weight: w, reps: item.low,
                          note: "\(day)改做 \(item.low)–\(item.high) 下：用上次的推估最大力量換算成 \(Progression.format(w)) kg。第一組做完填還剩幾下，後面會自動校準",
                          tip: .graduation)
    }

    /// 中階：區塊裡每 2 週每個部位多練的組數（每週，一個部位一週練 2 次，所以一次 +1 組 = 每週 +2）。
    static func rampOffset(week: Int) -> Int {
        guard intermediateActive, ProgramBuilder.phase(week: week) == .normal else { return 0 }
        let inBlock = BlockClock.locate(week: week).weekInBlock(week)
        return min(2, (inBlock - 1) / 2) * PersonalVolume.step
    }

    /// 個人組數加上中階的區塊加組，不超過個人組數的上限。
    static func offsets(week: Int) -> [Muscle: Int] {
        let ramp = rampOffset(week: week)
        var out = PersonalVolume.offsets
        guard ramp > 0 else { return out }
        for m in VolumePlan.targeted {
            out[m] = min(PersonalVolume.limits.upperBound, (out[m] ?? 0) + ramp)
        }
        return out
    }
}

// MARK: - 今天頁的卡片

struct GraduationCard: View {
    let offer: Graduation.Offer
    let onAccept: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("可以升中階了", systemImage: "graduationcap.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.gold)
                Spacer()
                InfoTip(item: .graduation)
            }
            Text("你已經穩定練了 \(offer.weeks) 週，減量後 \(offer.evaluated) 個主要動作還有 \(offer.stalled.count) 個加不上去。新手的「做到上限就加重」差不多用完了，換中階排法：同一個部位一天練重、一天練輕，區塊裡逐步加組數。")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            let names = offer.stalled.prefix(3).compactMap { ExerciseLibrary.byId($0)?.name }
            if !names.isEmpty {
                Text("卡住的：\(names.joined(separator: "、"))")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 10) {
                Button(action: onAccept) { Text("升中階") }
                    .buttonStyle(HotButtonStyle(height: 44))
                Button(action: onSnooze) {
                    Text("再等等").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
                .frame(maxWidth: 110)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - 升中階慶祝畫面

/// 光芒、衝擊波、粒子，觸覺節奏；「減少動態效果」時直接顯示結尾，點畫面跳到結尾。
struct GraduationCelebration: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    @State private var skipped = false

    private static let duration = 2.2

    var body: some View {
        TimelineView(.animation(paused: skipped || reduceMotion)) { ctx in
            let t = (skipped || reduceMotion) ? Self.duration : min(Self.duration, ctx.date.timeIntervalSince(start))
            ZStack {
                Theme.bg.ignoresSafeArea()
                rays(t)
                shockwave(t)
                particles(t)
                VStack(spacing: 18) {
                    badge(t)
                    VStack(spacing: 8) {
                        Text("升上中階")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundStyle(Theme.fg)
                        Text("主要動作一天重（6–8 下）、一天輕（12–15 下）。\n區塊裡每 2 週每個部位多 1 組。\n重日在家啞鈴到頂時，改慢速或單側版本。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.muted)
                    }
                    .opacity(ease((t - 0.9) / 0.5))
                    .offset(y: 12 * (1 - ease((t - 0.9) / 0.5)))
                    Button(action: onDone) { Text("開始中階") }
                        .buttonStyle(HotButtonStyle(height: 50))
                        .padding(.horizontal, 32)
                        .opacity(ease((t - 1.5) / 0.4))
                }
                .padding(24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { skipped = true }
        .task { await haptics() }
    }

    private func ease(_ x: Double) -> Double {
        let c = min(1, max(0, x))
        return 1 - pow(1 - c, 3)
    }

    private func badge(_ t: Double) -> some View {
        // 0.25 秒彈出，0.45 秒回彈
        let p = ease((t - 0.15) / 0.45)
        let overshoot = t < 0.6 ? 1 + 0.18 * sin(min(1, max(0, (t - 0.15) / 0.45)) * .pi) : 1
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.gold.opacity(0.55), .clear], center: .center, startRadius: 4, endRadius: 90))
                .frame(width: 180, height: 180)
            GradHexagon()
                .fill(LinearGradient(colors: [Theme.gold, Theme.hot], startPoint: .top, endPoint: .bottom))
                .frame(width: 112, height: 122)
            GradHexagon()
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: 96, height: 106)
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Theme.bg)
        }
        .scaleEffect(p * overshoot)
        .opacity(p)
    }

    private func rays(_ t: Double) -> some View {
        let p = ease((t - 0.3) / 0.6)
        return ZStack {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(Theme.gold.opacity(0.22))
                    .frame(width: 6, height: 220)
                    .offset(y: -150)
                    .rotationEffect(.degrees(Double(i) * 30 + t * 18))
            }
        }
        .scaleEffect(0.6 + 0.4 * p)
        .opacity(p)
        .offset(y: -90)
    }

    private func shockwave(_ t: Double) -> some View {
        let p = min(1, max(0, (t - 0.35) / 0.7))
        return Circle()
            .stroke(Theme.gold.opacity(1 - p), lineWidth: 6 * (1 - p) + 1)
            .frame(width: 120 + 380 * p, height: 120 + 380 * p)
            .offset(y: -90)
            .opacity(p > 0 && p < 1 ? 1 : 0)
    }

    private func particles(_ t: Double) -> some View {
        let p = min(1, max(0, (t - 0.35) / 1.4))
        return ZStack {
            ForEach(0..<28, id: \.self) { i in
                let angle = Double(i) * 2.399 // 黃金角，散得均勻
                let speed = 120 + Double((i * 37) % 90)
                let r = speed * ease(p)
                let fall = 60 * p * p
                RoundedRectangle(cornerRadius: 2)
                    .fill(i % 3 == 0 ? Theme.hot : (i % 3 == 1 ? Theme.gold : Theme.accent))
                    .frame(width: 6, height: i % 2 == 0 ? 10 : 6)
                    .rotationEffect(.degrees(Double(i) * 47 + t * 240))
                    .offset(x: cos(angle) * r, y: sin(angle) * r + fall - 90)
                    .opacity(1 - p)
            }
        }
    }

    @MainActor
    private func haptics() async {
        guard !reduceMotion else { return }
        let light = UIImpactFeedbackGenerator(style: .light)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let success = UINotificationFeedbackGenerator()
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard !skipped else { return }
        light.impactOccurred()
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard !skipped else { return }
        heavy.impactOccurred()
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !skipped else { return }
        success.notificationOccurred(.success)
    }
}

private struct GradHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.25))
        p.addLine(to: CGPoint(x: w, y: h * 0.75))
        p.addLine(to: CGPoint(x: w / 2, y: h))
        p.addLine(to: CGPoint(x: 0, y: h * 0.75))
        p.addLine(to: CGPoint(x: 0, y: h * 0.25))
        p.closeSubpath()
        return p
    }
}
