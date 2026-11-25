import SwiftUI
import SwiftData

/// 休息倒數：圓環平滑倒數、頭端有光點；最後 10 秒轉橘、最後 3 秒脈動加震動；時間到按鈕彈出來發光。
struct RestCard: View {
    let end: Date
    let total: Double
    var note: String? = nil
    let onAdd: () -> Void
    let onSkip: () -> Void
    var onExpand: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let left = end.timeIntervalSince(ctx.date)
            if left > 0 {
                running(left: left, now: ctx.date)
            } else {
                finished(over: -left)
            }
        }
        .modifier(SecondTicks(end: end))
    }

    private func running(left: Double, now: Date) -> some View {
        let warm = RestMotion.warm(left: left)
        let col = RestMotion.color(left: left)
        let last3 = left < 3
        // 剩 10 秒變警示色、開始心跳（每秒兩下，越接近 0 越有力）
        let pulse = RestMotion.heartbeat(left: left)
        let beat = reduceMotion ? 1 : 1 + 0.12 * pulse
        let p = left / max(total, 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                HStack(spacing: 14) {
                ZStack {
                    Ring(progress: p, color: col, lineWidth: 7)
                    // 圓環頭端的光點
                    GeometryReader { g in
                        let r = Double(g.size.width) / 2 - 7
                        let a = -Double.pi / 2 + 2 * Double.pi * p
                        let w = Double(g.size.width), h = Double(g.size.height)
                        Circle().fill(.white)
                            .frame(width: 7, height: 7)
                            .shadow(color: col, radius: 6)
                            .position(x: w / 2 + r * cos(a), y: h / 2 + r * sin(a))
                    }
                    Text(timerInterval: now...end, countsDown: true)
                        .font(Theme.number(15))
                        .foregroundStyle(last3 ? col : Theme.fg)
                }
                .frame(width: 64, height: 64)
                .scaleEffect(beat)
                .shadow(color: col.opacity(warm > 0 ? (reduceMotion ? 0.45 : 0.25 + 0.4 * pulse) : 0), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(last3 ? "準備！" : "休息中").font(.subheadline.weight(.bold)).foregroundStyle(last3 ? col : Theme.fg)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("共 \(Int(total)) 秒").font(.caption).foregroundStyle(Theme.muted)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if onExpand != nil {
                        Label("展開", systemImage: "chevron.up").font(.caption2.weight(.bold)).foregroundStyle(Theme.accentSoft)
                    }
                }
                }
                .contentShape(Rectangle())
                .onTapGesture { onExpand?() }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(onExpand != nil ? .isButton : [])
                .accessibilityLabel(onExpand != nil ? "展開休息畫面" : "休息中")
                Spacer(minLength: 0)
                Button("+30 秒", action: onAdd)
                    .buttonStyle(GhostButtonStyle())
                Button("跳過", action: onSkip)
                    .buttonStyle(GhostButtonStyle())
            }
            if let note {
                Label(note, systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accentSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(col.opacity(0.3 + 0.5 * warm), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func finished(over: Double) -> some View {
        let pop = reduceMotion ? 1 : 1 + 0.12 * exp(-over * 5) * cos(over * 16)
        let glow = reduceMotion ? 0.5 : 0.4 + 0.3 * sin(over * 5)
        // 歸零那一下整個閃一次
        let flash = RestMotion.flash(over: over)
        return Button(action: onSkip) {
            Label("休息結束，下一組！", systemImage: "bolt.fill")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    // 一道光掃過按鈕（減少動態效果時不顯示）
                    if !reduceMotion {
                        GeometryReader { g in
                            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: 60)
                                .offset(x: -60 + (Double(g.size.width) + 120) * FXMath.fract(over / 1.6))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.7 * flash))
                        .allowsHitTesting(false)
                }
                .shadow(color: Theme.green.opacity(max(glow, flash)), radius: 14 + 10 * flash)
        }
        .buttonStyle(.plain)
        .scaleEffect(pop)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
