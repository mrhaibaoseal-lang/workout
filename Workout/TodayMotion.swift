import SwiftUI
import UIKit

// 今天頁的系統 UI 動畫：卡片依序進場、開始按鈕呼吸光暈與按壓、本週進度點亮。
// 只有呈現層，不碰排課與資料。所有動畫都跟著「減少動態效果」：改成淡入或直接顯示結果。

// MARK: - 1. 卡片依序進場

/// 今天頁進場時的排隊器：每張卡第一次出現時領一個號碼，號碼越小越早浮上來。
/// 是一般的 class（不是 ObservableObject），改它的值不會讓整頁重算。
final class TodayEntrance {
    /// 進場期間為 true；時間到之後才出現的卡（例如補上來的提示卡）直接顯示，不再排隊
    var playing = true
    private var next = 0

    func claim() -> Int {
        defer { next += 1 }
        return next
    }
}

private struct TodayEntranceModifier: ViewModifier {
    let entrance: TodayEntrance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool

    init(entrance: TodayEntrance) {
        self.entrance = entrance
        // 進場期之後才建立的卡，一開始就是顯示的，不閃一格
        _shown = State(initialValue: !entrance.playing)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)
            .onAppear {
                guard !shown else { return }
                let slot = min(entrance.claim(), 14)
                if reduceMotion {
                    withAnimation(.easeOut(duration: 0.25).delay(Double(slot) * 0.03)) { shown = true }
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86).delay(Double(slot) * 0.05)) {
                        shown = true
                    }
                }
            }
    }
}

extension View {
    /// 第一次出現時由上到下一張接一張浮上來（位移 12pt ＋ 淡入，間隔 0.05 秒）。只播一次。
    func todayEntrance(_ entrance: TodayEntrance) -> some View {
        modifier(TodayEntranceModifier(entrance: entrance))
    }
}

// MARK: - 2. 開始訓練按鈕

/// 「開始訓練」：平常有很淡的呼吸光暈，按下去縮一下並有觸覺。
/// 呼吸動畫的狀態只放在光暈這個小 View 裡，不會讓上層（整頁）重算。
struct StartButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    /// 按鈕不能按時不呼吸
    var glow: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(Theme.onHot)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                Theme.hot.opacity(configuration.isPressed ? 0.8 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .background { if glow { BreathingGlow(cornerRadius: 16) } }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, pressed in
                pressed ? .impact(weight: .medium) : nil
            }
    }
}

/// 慢、低調的呼吸光暈（約 3.2 秒一個來回）。
private struct BreathingGlow: View {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var inhale = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.hot)
            .blur(radius: 14)
            .opacity(reduceMotion ? 0.2 : (inhale ? 0.34 : 0.12))
            .scaleEffect(reduceMotion ? 1 : (inhale ? 1.05 : 0.98))
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { inhale = true }
            }
    }
}

extension View {
    /// 開始按鈕當 zoom 轉場的起點（iOS 18 以上才有；更舊的系統什麼都不做）
    @ViewBuilder
    func todayZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    /// 訓練畫面（全螢幕蓋上來的那頁）用 zoom 展開。
    /// `enabled` 為 false（減少動態效果、或不是從開始按鈕進來的）、或系統不到 iOS 18 時，保持原本的蓋上來方式。
    @ViewBuilder
    func todayZoomDestination(enabled: Bool, id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *), enabled {
            navigationTransition(.zoom(sourceID: id, in: namespace))
                // zoom 轉場預設可以往下滑關掉；訓練中不能這樣關，維持原本全螢幕蓋上來的行為
                .interactiveDismissDisabled(true)
        } else {
            self
        }
    }
}

// MARK: - 3. 本週進度

/// 這個 View 是否有露出在螢幕上（捲動時持續更新）。只用來決定什麼時候播動畫，卡片在螢幕外時不播。
private struct VisibilityTracker: ViewModifier {
    @Binding var visible: Bool

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                let frame = geo.frame(in: .global)
                let screen = UIScreen.main.bounds.height
                let now = frame.minY < screen - 40 && frame.maxY > 40
                Color.clear
                    .onAppear { if visible != now { visible = now } }
                    .onChange(of: now) { _, v in visible = v }
            }
        }
    }
}

extension View {
    func trackVisibility(_ visible: Binding<Bool>) -> some View {
        modifier(VisibilityTracker(visible: visible))
    }
}

/// 當天剛完成時的小爆光：一圈擴散的光環加一團光暈，一次就好。
struct DayBurstFX: View {
    @State private var go = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.accent)
                .blur(radius: 6)
                .scaleEffect(go ? 1.9 : 0.9)
                .opacity(go ? 0 : 0.7)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.accentSoft, lineWidth: 2)
                .scaleEffect(go ? 2.1 : 1)
                .opacity(go ? 0 : 0.9)
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { go = true } }
    }
}

/// 「今天已經爆光過」的記號，一天只爆一次，重開 App 也不重播。
enum DayBurstMemo {
    private static let key = "workout.today.burstDay"

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static var played: Bool { UserDefaults.standard.string(forKey: key) == dayKey() }
    static func markPlayed() { UserDefaults.standard.set(dayKey(), forKey: key) }
}
