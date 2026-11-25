import SwiftUI
import UIKit

// 訓練中的系統 UI 動畫：打勾、數字滾動、休息倒數環、動作切換、toast。
// 只做呈現，不碰訓練邏輯。所有動畫都有「減少動態效果」的版本（淡入或直接顯示結果），觸覺保留。

enum WorkoutMotion {
    /// 一般互動的彈簧（按鈕回饋 0.3 秒內看得到結果）
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.72)
    /// 卡片切換、版面變化
    static let layout = Animation.spring(response: 0.42, dampingFraction: 0.82)
    /// 數字滾動
    static let roll = Animation.snappy(duration: 0.26)
    /// toast 彈下來：有回彈
    static let toastIn = Animation.spring(response: 0.42, dampingFraction: 0.58)
    /// 沒有動態效果時的淡入
    static let fade = Animation.easeOut(duration: 0.15)

    /// 減少動態效果時換成淡入，否則用傳進來的動畫。
    static func pick(_ reduce: Bool, _ animation: Animation) -> Animation { reduce ? fade : animation }

    // MARK: 觸覺

    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}

// MARK: - 打勾

/// 勾勾用畫線方式出現（trim）；圓底先彈出來。
struct CheckStroke: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.55))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.40, y: r.minY + r.height * 0.82))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.90, y: r.minY + r.height * 0.20))
        return p
    }
}

/// 一組的完成圈：完成時圓底彈出、勾勾畫出來；沒完成是空圈。
/// `animateOnAppear`：這一列是剛做完才出現的（從編輯卡變成完成列），出現時要播畫線動畫。
struct SetCheckMark: View {
    let done: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: 2)
            Circle().fill(Theme.accent)
                .scaleEffect(drawn || reduceMotion ? 1 : 0.2)
                .opacity(drawn ? 1 : 0)
                .animation(reduceMotion ? WorkoutMotion.fade : .spring(response: 0.28, dampingFraction: 0.6), value: drawn)
            CheckStroke()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(Theme.bg, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 14, height: 12)
                // 圓底先彈出，勾勾稍後畫出來
                .animation(reduceMotion ? WorkoutMotion.fade : .easeOut(duration: 0.22).delay(done ? 0.06 : 0), value: drawn)
        }
        .onAppear { drawn = done }
        .onChange(of: done) { _, d in drawn = d }
    }
}

/// 剛完成的那一列：往下壓一下再彈回。只在「出現時已經是完成」的那一次播，連按不會排隊（狀態直接被覆蓋）。
struct SetRowPress: ViewModifier {
    let done: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var squash: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: squash, anchor: .center)
            .onAppear { if done { press() } }
            .onChange(of: done) { _, d in if d { press() } }
    }

    private func press() {
        guard !reduceMotion else { return }
        squash = 0.9
        withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { squash = 1 }
    }
}

/// 下一組亮起來：編輯卡出現時邊框閃一下、光暈慢慢退。
struct SetActiveGlow: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow: Double = 0

    func body(content: Content) -> some View {
        content
            .shadow(color: Theme.hot.opacity(0.55 * glow), radius: 14 * glow)
            .onAppear {
                glow = 1
                withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.7)) { glow = 0 }
            }
    }
}

extension View {
    func setRowPress(done: Bool) -> some View { modifier(SetRowPress(done: done)) }
    func setActiveGlow() -> some View { modifier(SetActiveGlow()) }
}

// MARK: - 數字滾動

/// 像里程表一樣滾動的數字。`value` 變了就滾；減少動態效果時改成淡入。
struct RollingText: View {
    let text: String
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, value: Double) {
        self.text = text
        self.value = value
    }

    var body: some View {
        Text(text)
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(reduceMotion ? WorkoutMotion.fade : WorkoutMotion.roll, value: value)
    }
}

// MARK: - 休息倒數環

/// 倒數環的顏色、心跳和結束閃光。剩 10 秒變警示色並開始心跳，歸零閃一次。
enum RestMotion {
    static let warnAt = 10.0

    /// 0＝還沒到警示、1＝警示色（10 秒時快速換色，不拖）
    static func warm(left: Double) -> Double { FXMath.seg(warnAt - left, 0, 0.5) }

    static func color(left: Double) -> Color { FXMath.mix(Theme.green, Theme.hot, warm(left: left)) }

    /// 心跳：每秒「咚—咚」兩下，越接近 0 越有力。回傳 0…1。剩 10 秒以上是 0。
    static func heartbeat(left: Double) -> Double {
        guard left > 0, left <= warnAt else { return 0 }
        let ph = 1 - FXMath.fract(left)   // 每秒從 0 走到 1
        func bump(_ c: Double, _ w: Double) -> Double { exp(-pow((ph - c) / w, 2)) }
        let strength = 0.55 + 0.45 * (1 - left / warnAt)
        return min(1, (bump(0.06, 0.06) + 0.7 * bump(0.28, 0.06)) * strength)
    }

    /// 歸零後的閃光強度 0…1（約 0.5 秒退光）
    static func flash(over: Double) -> Double { over < 0 ? 0 : exp(-over * 6) }
}

/// 時間到的一圈閃光：圈從外面擴散出去，同時整圈亮一下。放在環的上面。
struct RingFlash: View {
    let over: Double
    var lineWidth: CGFloat = 14
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let f = RestMotion.flash(over: over)
        let q = FXMath.clamp(over / 0.6)
        ZStack {
            Circle().stroke(.white.opacity(0.85 * f), lineWidth: lineWidth)
            if !reduceMotion {
                Circle()
                    .stroke(Theme.green.opacity(0.7 * (1 - q)), lineWidth: lineWidth * (1 - q) + 1)
                    .scaleEffect(1 + 0.35 * FXMath.easeOutCubic(q))
            }
        }
        .padding(lineWidth / 2)
        .allowsHitTesting(false)
    }
}

/// 時間到的觸覺節奏：一下重的、兩下漸弱、最後一下成功。歸零時用。
enum RestHaptics {
    static let finish: [(Double, HapticScript.Kind)] = [
        (0, .heavy), (0.11, .rigid), (0.22, .medium), (0.36, .light), (0.55, .success)
    ]
}

// MARK: - toast

enum ToastKind {
    case success, warning

    /// 依內容決定：提醒類（會痛、太吃力、連擊中斷…）用提醒，其他用成功。
    static func of(_ text: String) -> ToastKind {
        let warn = ["中斷", "不舒服", "太吃力", "減輕", "不排", "注意", "小心", "痛", "掉", "保守"]
        return warn.contains { text.contains($0) } ? .warning : .success
    }

    var fill: Color { self == .warning ? Theme.hot : Theme.green }
    var ink: Color { self == .warning ? Theme.onHot : Theme.bg }

    func haptic() {
        switch self {
        case .success: WorkoutMotion.notify(.success)
        case .warning: WorkoutMotion.notify(.warning)
        }
    }
}

/// 從頂端彈下來的提示。出現／換字時由外層的 `.id(text)` 和 transition 播彈跳。
struct ToastBanner: View {
    let text: String

    var body: some View {
        let kind = ToastKind.of(text)
        Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(kind.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(kind.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
            .padding(.top, 60)
    }
}

// MARK: - 動作切換

extension AnyTransition {
    /// 換動作：舊卡片往側邊推走、新卡片從側邊滑進來。減少動態效果時改淡入。
    static func exercisePush(reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .push(from: .trailing)
    }

    /// toast：從上面彈下來（回彈由動畫給），減少動態效果時只淡入。
    static func toastDrop(reduce: Bool) -> AnyTransition {
        reduce ? .opacity : .move(edge: .top).combined(with: .opacity)
    }
}
