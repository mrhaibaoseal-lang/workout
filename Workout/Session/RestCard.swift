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
        let warm = FXMath.seg(10 - left, 0, 7)
        let col = FXMath.mix(Theme.green, Theme.hot, warm)
        let last3 = left < 3
        let beat = last3 ? 1 + 0.08 * pow(max(0, sin(.pi * FXMath.fract(left))), 4) : 1
        let p = left / max(total, 1)
        return VStack(alignment: .leading, spacing: 10) {
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
                .shadow(color: col.opacity(last3 ? 0.6 : 0), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(last3 ? "準備！" : "休息中").font(.subheadline.weight(.bold)).foregroundStyle(last3 ? col : Theme.fg)
                    Text("共 \(Int(total)) 秒").font(.caption).foregroundStyle(Theme.muted)
                    if onExpand != nil {
                        Label("展開", systemImage: "chevron.up").font(.caption2.weight(.bold)).foregroundStyle(Theme.accentSoft)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onExpand?() }
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
        let pop = 1 + 0.12 * exp(-over * 5) * cos(over * 16)
        let glow = 0.4 + 0.3 * sin(over * 5)
        return Button(action: onSkip) {
            Label("休息結束，下一組！", systemImage: "bolt.fill")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    // 一道光掃過按鈕
                    GeometryReader { g in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 60)
                            .offset(x: -60 + (Double(g.size.width) + 120) * FXMath.fract(over / 1.6))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .shadow(color: Theme.green.opacity(glow), radius: 14)
        }
        .buttonStyle(.plain)
        .scaleEffect(pop)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
