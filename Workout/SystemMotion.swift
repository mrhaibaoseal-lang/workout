import SwiftUI

// 系統層的小動畫元件（分頁、雲端同步、問卷共用）。
// 全部尊重「減少動態效果」：搖動、縮放、推移改成靜態或淡入。

/// 輕輕左右搖一下。`trigger` 每變一次就搖一次；減少動態效果時不搖。
private struct ShakeOnTrigger: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-6, duration: 0.06)
                    CubicKeyframe(6, duration: 0.08)
                    CubicKeyframe(-4, duration: 0.08)
                    CubicKeyframe(3, duration: 0.08)
                    CubicKeyframe(0, duration: 0.1)
                }
            }
        }
    }
}

extension View {
    /// `trigger` 變動時左右輕搖一下（錯誤提示用）。
    func shake(trigger: Int) -> some View {
        modifier(ShakeOnTrigger(trigger: trigger))
    }
}

/// 選項按下去的回饋：縮一點點、彈回來。減少動態效果時只變暗，不縮放。
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        PressScaleBody(configuration: configuration, scale: scale)
    }

    private struct PressScaleBody: View {
        let configuration: ButtonStyleConfiguration
        let scale: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
                .opacity(configuration.isPressed ? 0.85 : 1)
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.55),
                           value: configuration.isPressed)
        }
    }
}

/// 頂部細進度條：`fraction`（0…1）改變時平滑變長。
struct StepProgressBar: View {
    let fraction: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .animation(reduceMotion ? nil : .smooth(duration: 0.4), value: fraction)
        .accessibilityElement()
        .accessibilityLabel("問卷進度")
        .accessibilityValue("\(Int((fraction * 100).rounded()))%")
    }
}
