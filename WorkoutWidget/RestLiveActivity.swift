import ActivityKit
import SwiftUI
import WidgetKit

/// 休息倒數：鎖定畫面一張卡，動態島顯示剩幾秒。
struct RestLiveActivity: Widget {
    private static let green = Color(red: 0.36, green: 0.84, blue: 0.60)
    private static let hot = Color(red: 1.0, green: 0.53, blue: 0.34)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            lockScreen(context.state)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.055, green: 0.07, blue: 0.094))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("休息", systemImage: "timer").font(.caption.bold()).foregroundStyle(Self.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(s).font(.title2.bold()).foregroundStyle(Self.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.next).font(.headline).lineLimit(1)
                        Text(s.detail).font(.subheadline.bold()).foregroundStyle(Self.hot)
                        if let c = s.change {
                            Text(c).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        ProgressView(timerInterval: Date.now...max(s.end, .now), countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                            .tint(Self.green)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(Self.green)
            } compactTrailing: {
                timer(s).foregroundStyle(Self.green).frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(Self.green)
            }
        }
    }

    private func timer(_ s: RestActivityAttributes.ContentState) -> some View {
        Text(timerInterval: Date.now...max(s.end, .now), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    private func lockScreen(_ s: RestActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("休息中 · 下一組").font(.caption.bold()).foregroundStyle(Self.green)
                Text(s.next).font(.headline).foregroundStyle(.white).lineLimit(1)
                Text(s.detail).font(.title3.bold()).foregroundStyle(Self.hot)
                if let c = s.change {
                    Text(c).font(.caption).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            timer(s)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 110, alignment: .trailing)
        }
    }
}
