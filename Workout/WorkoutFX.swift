import SwiftUI

// 訓練中的特效：破個人紀錄、完成訓練、裝備閃光。全部只靠經過時間算出來。

/// 破紀錄的那一刻。
struct PRMoment: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let weight: Double
    let old: Double
    let start = Date()

    static let duration = 2.0
}

/// 破紀錄：金色光芒＋火花噴出，大字砸下來。不擋操作。
struct PRBurstView: View {
    let pr: PRMoment

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(pr.start)
            let fadeOut = 1 - FXMath.seg(t, PRMoment.duration - 0.4, PRMoment.duration)
            let slam = FXMath.seg(t, 0.05, 0.35)
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.38)
                ZStack {
                    Canvas { g, size in
                        let a = fadeOut
                        FX.glow(&g, center: c, radius: 220, color: Theme.gold, alpha: 0.55 * a * FXMath.seg(t, 0, 0.2))
                        FX.rays(&g, center: c, radius: 320, count: 16, angle: t * 0.6, color: Theme.gold, alpha: 0.35 * a)
                        FX.ring(&g, center: c, progress: FXMath.seg(t, 0.25, 0.85), maxRadius: 260, color: Theme.gold)
                        FX.sparkBurst(&g, center: c, tau: t - 0.25, count: 36, speed: 520,
                                      colors: [Theme.gold, .white, Theme.hot])
                    }
                    VStack(spacing: 4) {
                        Text("破紀錄！")
                            .font(.system(size: 46, weight: .black))
                            .foregroundStyle(LinearGradient(colors: [.white, Theme.gold], startPoint: .top, endPoint: .bottom))
                            .shadow(color: Theme.hot.opacity(0.9), radius: 14)
                            .scaleEffect(1 + 2 * (1 - FXMath.easeOutBack(slam)))
                            .opacity(slam)
                        Text("\(pr.name) \(Progression.format(pr.weight)) kg")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .opacity(FXMath.seg(t, 0.35, 0.6))
                        Text("比之前多 \(Progression.format(pr.weight - pr.old)) kg")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.gold)
                            .opacity(FXMath.seg(t, 0.5, 0.75))
                    }
                    .position(c)
                }
                .opacity(fadeOut)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// 練完的成果。
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let sets: Int
    let seconds: Int
    let prs: Int
    let points: Int
    let weekDone: Int
    let weekGoal: Int
    let streakBefore: Int
    let streakAfter: Int
    /// 守時連擊
    var bestCombo = 0
    var onTime = 0
    var rests = 0
    var comboShards = 0
}

private struct CheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.27, y: r.minY + r.height * 0.53))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.43, y: r.minY + r.height * 0.69))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.75, y: r.minY + r.height * 0.35))
        return p
    }
}

/// 完成訓練：打勾描邊 → 爆開 → 成果一格格彈出 → 牌位分、週目標、連續週數。
struct WorkoutCompleteView: View {
    let summary: WorkoutSummary
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skip: Double = 0
    @State private var haptics = HapticScript()

    private let end = 3.4
    private var goalHit: Bool { summary.weekDone == summary.weekGoal }
    private var streakUp: Bool { summary.streakAfter > summary.streakBefore }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start) + skip
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.24)
                ZStack {
                    Canvas { g, size in
                        FX.glow(&g, center: c, radius: max(size.width, size.height) * 0.7, color: Theme.green,
                                alpha: 0.25 * FXMath.seg(t, 0.5, 1))
                        FX.rays(&g, center: c, radius: max(size.width, size.height), count: 14, angle: t * 0.25,
                                color: Theme.green, alpha: 0.16 * FXMath.seg(t, 0.6, 1.2))
                        FX.ring(&g, center: c, progress: FXMath.seg(t, 0.75, 1.4), maxRadius: 300, color: Theme.green)
                        FX.sparkBurst(&g, center: c, tau: t - 0.75, count: 30, speed: 420, colors: [Theme.green, .white, Theme.gold])
                        FX.confetti(&g, center: c, tau: t - 0.8, count: 70,
                                    colors: [Theme.green, Theme.gold, .white, Theme.accent, Theme.hot], height: size.height)
                    }
                    VStack(spacing: 18) {
                        check(t)
                            .frame(width: 120, height: 120)
                            // VStack 有 24 的內距，扣掉才會和背後光芒的中心對齊
                            .position(x: c.x - 24, y: c.y - 24)
                            .frame(height: c.y - 24 + 60)
                        Text("訓練完成！")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(Theme.fg)
                            .scaleEffect(1 + 1.2 * (1 - FXMath.easeOutBack(FXMath.seg(t, 0.85, 1.15))))
                            .opacity(FXMath.seg(t, 0.85, 1.0))
                        HStack(spacing: 10) {
                            stat("組數", "\(count(summary.sets, t, 1.1))", t - 1.1)
                            stat("時間", "\(summary.seconds / 60) 分", t - 1.25)
                            stat("破紀錄", "\(count(summary.prs, t, 1.4))", t - 1.4, hot: summary.prs > 0)
                        }
                        pointsRow(t)
                        weekRow(t)
                        if summary.rests > 0 {
                            comboRow(t)
                        }
                        Spacer(minLength: 0)
                        Button("好") { onDone() }
                            .buttonStyle(HotButtonStyle())
                            .opacity(FXMath.seg(t, end - 0.4, end))
                            .allowsHitTesting(t > end - 0.3)
                    }
                    .padding(24)
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            let now = Date().timeIntervalSince(start) + skip
            if now < end { skip += end - now; haptics.cancel() }
        }
        .onAppear {
            start = Date()
            if reduceMotion { skip = end; return }
            var list: [(Double, HapticScript.Kind)] = [(0.75, .heavy), (0.85, .success), (1.1, .light), (1.25, .light), (1.4, .light)]
            list.append((1.8, .rigid))
            if goalHit { list.append((2.4, .success)) }
            if streakUp { list.append((2.8, .medium)) }
            if summary.comboShards > 0 { list.append((3.0, .success)) }
            haptics.play(list)
        }
        .onDisappear { haptics.cancel() }
        .preferredColorScheme(.dark)
    }

    private func count(_ n: Int, _ t: Double, _ at: Double) -> Int {
        Int((Double(n) * FXMath.easeOutCubic(FXMath.seg(t, at, at + 0.5))).rounded())
    }

    private func check(_ t: Double) -> some View {
        let ringP = FXMath.easeOutCubic(FXMath.seg(t, 0.05, 0.5))
        let checkP = FXMath.easeOutCubic(FXMath.seg(t, 0.45, 0.75))
        let pop = t > 0.75 ? 1 + 0.2 * exp(-(t - 0.75) * 7) * cos((t - 0.75) * 18) : 1
        return ZStack {
            Circle().fill(Theme.green.opacity(0.18 * FXMath.seg(t, 0.4, 0.75)))
            Circle().trim(from: 0, to: ringP)
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            CheckShape().trim(from: 0, to: checkP)
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
        }
        .shadow(color: Theme.green.opacity(0.7), radius: 16)
        .scaleEffect(pop)
    }

    private func stat(_ label: String, _ value: String, _ t: Double, hot: Bool = false) -> some View {
        let p = FXMath.seg(t, 0, 0.35)
        return VStack(spacing: 4) {
            Text(value).font(Theme.number(26)).foregroundStyle(hot ? Theme.gold : Theme.fg)
            Text(label).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(hot ? Theme.gold.opacity(0.7) : Theme.line, lineWidth: 1))
        .scaleEffect(0.5 + 0.5 * FXMath.easeOutBack(p))
        .opacity(p)
    }

    private func pointsRow(_ t: Double) -> some View {
        let p = FXMath.seg(t, 1.7, 2.0)
        let n = Int((Double(summary.points) * FXMath.easeOutCubic(FXMath.seg(t, 1.8, 2.3))).rounded())
        let glow = 0.5 + 0.5 * sin(t * 4)
        return HStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled")
            Text("牌位分 +\(n)")
        }
        .font(.headline.weight(.heavy))
        .foregroundStyle(Theme.bg)
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Theme.gold, in: Capsule())
        .shadow(color: Theme.gold.opacity(0.4 + 0.4 * glow), radius: 12)
        .scaleEffect(0.3 + 0.7 * FXMath.easeOutBack(p))
        .opacity(p)
    }

    /// 最高連擊、守時次數、換到的碎片
    private func comboRow(_ t: Double) -> some View {
        let p = FXMath.seg(t, 2.6, 2.9)
        let gem = FXMath.seg(t, 2.95, 3.25)
        return HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(Theme.gold)
                .frame(width: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("最高連擊 ×\(summary.bestCombo)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.gold)
                Text("準時開始 \(summary.onTime) / \(summary.rests) 次")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if summary.comboShards > 0 {
                Label("+\(summary.comboShards)", systemImage: "diamond.fill")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.gold, in: Capsule())
                    .scaleEffect(0.3 + 0.7 * FXMath.easeOutBack(gem))
                    .opacity(gem)
                    .accessibilityLabel("獲得 \(summary.comboShards) 碎片")
            }
        }
        .padding(14)
        .background(Theme.goldBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.gold.opacity(0.5), lineWidth: 1))
        .offset(y: 30 * (1 - FXMath.easeOutCubic(p)))
        .opacity(p)
    }

    private func weekRow(_ t: Double) -> some View {
        let p = FXMath.seg(t, 2.1, 2.4)
        let fill = FXMath.easeOutCubic(FXMath.seg(t, 2.2, 2.7))
        let goal = max(1, summary.weekGoal)
        let from = Double(max(0, summary.weekDone - 1)) / Double(goal)
        let to = Double(summary.weekDone) / Double(goal)
        let flameP = FXMath.seg(t, 2.7, 3.0)
        return HStack(spacing: 14) {
            ZStack {
                Ring(progress: from + (to - from) * fill, color: goalHit ? Theme.gold : Theme.accent, lineWidth: 7)
                Text("\(summary.weekDone)/\(goal)").font(Theme.number(14)).foregroundStyle(Theme.fg)
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(goalHit ? "週目標達成！" : "本週第 \(summary.weekDone) 次")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(goalHit ? Theme.gold : Theme.fg)
                    .scaleEffect(goalHit && t > 2.7 ? 1 + 0.2 * exp(-(t - 2.7) * 6) : 1, anchor: .leading)
                if summary.streakAfter > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Theme.hot)
                            .scaleEffect(streakUp ? 1 + 0.6 * exp(-max(0, t - 2.7) * 5) * flameP : 1)
                        Text("連續 \(summary.streakAfter) 週")
                            .foregroundStyle(Theme.hotText)
                        if streakUp {
                            Text("+1")
                                .foregroundStyle(Theme.gold)
                                .opacity(flameP * (1 - FXMath.seg(t, 4.5, 5)))
                                .offset(y: -10 * flameP)
                        }
                    }
                    .font(.subheadline.weight(.bold))
                }
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(goalHit ? Theme.gold.opacity(0.7) : Theme.line, lineWidth: 1))
        .offset(y: 30 * (1 - FXMath.easeOutCubic(p)))
        .opacity(p)
    }
}

/// 裝備時的閃光：一圈光往外擴、星星噴出。放在要閃的格子上當 overlay。
struct EquipFlash: View {
    let start: Date
    let color: Color

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            Canvas { g, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2)
                FX.glow(&g, center: c, radius: size.width * 0.7, color: color, alpha: 0.6 * (1 - FXMath.seg(t, 0, 0.6)))
                FX.ring(&g, center: c, progress: FXMath.seg(t, 0, 0.5), maxRadius: size.width * 0.6, color: color, width: 6)
                FX.sparkBurst(&g, center: c, tau: t, count: 14, speed: 160, colors: [color, .white])
            }
        }
        .allowsHitTesting(false)
    }
}
