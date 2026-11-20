import SwiftUI

/// Direction A: dark stage, blue accent, orange only where the app wants you to act
/// (start, add weight, personal records). Matches the character tab's stage.
enum Theme {
    static let bg = Color(gearHex: "#0E1218")
    static let surface = Color(gearHex: "#19202A")
    static let sunken = Color(gearHex: "#141A22")
    static let raised = Color(gearHex: "#232C39")
    static let line = Color(gearHex: "#2A3340")
    static let divider = Color(gearHex: "#222A35")
    static let fg = Color(gearHex: "#E9EDF2")
    static let muted = Color(gearHex: "#9AA5B1")
    static let accent = Color(gearHex: "#7D9BFF")
    static let accentDim = Color(gearHex: "#4A5C94")
    static let accentSoft = Color(gearHex: "#C9D3E6")
    static let hot = Color(gearHex: "#FF8757")
    static let hotText = Color(gearHex: "#FF9A6E")
    static let hotBg = Color(gearHex: "#2A1A12")
    static let hotLine = Color(gearHex: "#5A3220")
    static let onHot = Color(gearHex: "#1A0E08")
    static let green = Color(gearHex: "#5BD69A")
    static let gold = Color(gearHex: "#F2C14E")
    static let goldBg = Color(gearHex: "#2E2614")

    static let heroGradient = RadialGradient(
        colors: [Color(gearHex: "#2B3A66"), Color(gearHex: "#18213A"), Color(gearHex: "#131A2B")],
        center: UnitPoint(x: 0.85, y: 0), startRadius: 0, endRadius: 420)

    /// Rounded numbers for weights, counts and timers.
    static func number(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }
}

extension View {
    /// The standard surface card.
    func themeCard(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    /// Dark page background behind a ScrollView.
    func themeScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
    }
}

/// Small rounded tag, e.g. 「加重」「完整版」.
struct Tag: View {
    let text: String
    var fg: Color = Theme.hotText
    var bg: Color = Theme.hotBg

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(bg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

/// Circular progress ring.
struct Ring: View {
    let progress: Double
    var color: Color = Theme.accent
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// Big filled orange call-to-action button.
struct HotButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(Theme.onHot)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Theme.hot.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Outlined secondary button.
struct GhostButtonStyle: ButtonStyle {
    var stroke: Color = Theme.line

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Theme.fg)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(configuration.isPressed ? Theme.raised : .clear,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(stroke, lineWidth: 1))
    }
}
