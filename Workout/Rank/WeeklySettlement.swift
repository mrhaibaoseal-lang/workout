import SwiftUI

/// 上週結算的內容：結算項目、結算前後的分數。
struct WeeklySettlement: Identifiable {
    let id = UUID()
    let events: [RankEvent]
    let before: Int
    let after: Int
}

/// 每週結算：週一第一次打開時，結算卡一張張翻開，分數跟著跳。
struct WeeklySettlementView: View {
    let settlement: WeeklySettlement
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skip: Double = 0
    @State private var haptics = HapticScript()

    private var total: Int { settlement.events.reduce(0) { $0 + $1.delta } }
    private var good: Bool { total >= 0 }
    private var cardStart: Double { 0.7 }
    private var cardGap: Double { 0.55 }
    private var totalAt: Double { cardStart + Double(settlement.events.count) * cardGap + 0.2 }
    private var end: Double { totalAt + 1.6 }
    private var accent: Color { good ? Theme.gold : Theme.hot }

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start) + skip
            ZStack {
                Canvas { c, size in background(&c, size: size, t: t) }
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    Spacer(minLength: 20)
                    header(t)
                    VStack(spacing: 10) {
                        ForEach(Array(settlement.events.enumerated()), id: \.offset) { i, e in
                            card(e, t: t - cardStart - Double(i) * cardGap)
                        }
                    }
                    totals(t)
                    Spacer(minLength: 0)
                    Button(good ? "收下" : "知道了") { dismiss() }
                        .buttonStyle(HotButtonStyle())
                        .opacity(FXMath.seg(t, end - 0.6, end - 0.2))
                        .allowsHitTesting(t > end - 0.4)
                }
                .padding(24)
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
            var list: [(Double, HapticScript.Kind)] = [(0.3, .medium)]
            for (i, e) in settlement.events.enumerated() {
                list.append((cardStart + Double(i) * cardGap + 0.15, e.delta >= 0 ? .rigid : .light))
            }
            list.append((totalAt + 0.6, good ? .success : .warning))
            haptics.play(list)
        }
        .onDisappear { haptics.cancel() }
        .preferredColorScheme(.dark)
    }

    private func background(_ c: inout GraphicsContext, size: CGSize, t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.2)
        FX.glow(&c, center: center, radius: max(size.width, size.height) * 0.7, color: accent, alpha: 0.18)
        if good {
            FX.rays(&c, center: center, radius: max(size.width, size.height), count: 12, angle: t * 0.15,
                    color: Theme.gold, alpha: 0.12 * FXMath.seg(t, 0, 0.6))
            let tau = t - totalAt - 0.6
            FX.confetti(&c, center: CGPoint(x: size.width / 2, y: size.height * 0.62), tau: tau, count: 60,
                        colors: [Theme.gold, .white, Theme.green, Theme.accent], height: size.height, power: 0.8)
        } else {
            FX.dust(&c, size: size, t: t, count: 24, alpha: 1)
        }
    }

    private func header(_ t: Double) -> some View {
        let p = FXMath.seg(t, 0.05, 0.45)
        return VStack(spacing: 6) {
            Image(systemName: good ? "trophy.fill" : "calendar.badge.exclamationmark")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.8), radius: 16)
                .rotationEffect(.degrees(good ? sin(t * 2) * 6 : 0))
            Text("上週結算")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(Theme.fg)
            if let d = settlement.events.last?.date {
                let startDay = Calendar.current.date(byAdding: .day, value: -6, to: d) ?? d
                Text("\(startDay.formatted(.dateTime.month().day())) – \(d.formatted(.dateTime.month().day()))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .scaleEffect(1 + 0.8 * (1 - FXMath.easeOutBack(p)))
        .opacity(p)
    }

    /// 一張結算卡：從側面翻過來，數字彈出；扣分的卡會抖一下。
    private func card(_ e: RankEvent, t: Double) -> some View {
        let p = FXMath.seg(t, 0, 0.45)
        let up = e.delta >= 0
        let neutral = e.delta == 0
        let col = neutral ? Theme.accent : (up ? Theme.gold : Theme.hot)
        let shake = up ? 0 : 6 * exp(-max(0, t - 0.4) * 8) * sin(t * 50) * (t > 0.4 ? 1 : 0)
        let numPop = 1 + 0.5 * exp(-max(0, t - 0.35) * 7) * (t > 0.35 ? 1 : 0)
        return HStack {
            Image(systemName: icon(e))
                .font(.title3)
                .foregroundStyle(col)
            Text(e.reason)
                .font(.headline)
                .foregroundStyle(Theme.fg)
            Spacer()
            Text(e.displayValue)
                .font(Theme.number(neutral ? 18 : 24))
                .foregroundStyle(col)
                .shadow(color: col.opacity(0.7), radius: 8)
                .scaleEffect(numPop)
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(col.opacity(0.6), lineWidth: 1.5))
        .rotation3DEffect(.degrees(-90 * (1 - FXMath.easeOutBack(p))), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .opacity(p > 0 ? 1 : 0)
        .offset(x: shake)
    }

    private func icon(_ e: RankEvent) -> String {
        switch e.kind {
        case .shield: return "shield.lefthalf.filled"
        case .bet: return "diamond.fill"
        default:
            if e.delta == 0 { return "bed.double.fill" }
            if e.delta < 0 { return "xmark.octagon.fill" }
            return e.reason.contains("連續") ? "flame.fill" : "checkmark.seal.fill"
        }
    }

    private func totals(_ t: Double) -> some View {
        let p = FXMath.seg(t, totalAt, totalAt + 0.3)
        let count = FXMath.smooth(FXMath.seg(t, totalAt + 0.2, totalAt + 1.2))
        let shown = Int((Double(settlement.before) + Double(settlement.after - settlement.before) * count).rounded())
        let pop = 1 + 0.25 * exp(-max(0, t - totalAt - 1.2) * 6) * (t > totalAt + 1.2 ? 1 : 0)
        return VStack(spacing: 4) {
            Text("合計 \(good ? "+" : "−")\(abs(total))")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(accent)
            Text("\(shown) 分")
                .font(Theme.number(44))
                .foregroundStyle(Theme.fg)
                .scaleEffect(pop)
            let r = Rank(points: shown)
            Text(r.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(r.tier.light)
        }
        .opacity(p)
        .scaleEffect(0.8 + 0.2 * FXMath.easeOutBack(p))
    }
}
