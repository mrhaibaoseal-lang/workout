import SwiftUI

/// 自己畫的牌位獎章：牌位越高，盾牌外加的裝飾越多（翅膀、寶石、皇冠、光芒）。
struct RankBadge: View {
    let tier: RankTier
    var division: Int? = nil
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            if tier == .champion {
                Rays()
                    .fill(RadialGradient(colors: [tier.light.opacity(0.7), .clear],
                                         center: .center, startRadius: 0, endRadius: size * 0.75))
                    .frame(width: size * 1.5, height: size * 1.5)
            }
            if tier.rawValue >= RankTier.gold.rawValue {
                HStack(spacing: size * 0.42) {
                    Wing().fill(tier.gradient).scaleEffect(x: -1)
                    Wing().fill(tier.gradient)
                }
                .frame(width: size * 1.35, height: size * 0.5)
                .offset(y: -size * 0.05)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
            }
            Shield()
                .fill(tier.gradient)
                .overlay(Shield().stroke(tier.dark, lineWidth: size * 0.04))
                .overlay(
                    Shield()
                        .inset(by: size * 0.1)
                        .stroke(.white.opacity(0.45), lineWidth: size * 0.025)
                )
                .frame(width: size * 0.7, height: size * 0.82)
                .shadow(color: tier.dark.opacity(0.5), radius: size * 0.04, y: size * 0.02)
            emblem
                .offset(y: -size * 0.03)
            if tier.rawValue >= RankTier.master.rawValue {
                Crown()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4),
                                                  Color(red: 0.85, green: 0.6, blue: 0.1)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(Crown().stroke(Color(red: 0.55, green: 0.35, blue: 0.05), lineWidth: size * 0.015))
                    .frame(width: size * 0.42, height: size * 0.22)
                    .offset(y: -size * 0.5)
            }
            if let d = division {
                HStack(spacing: size * 0.04) {
                    ForEach(0..<(4 - d), id: \.self) { _ in
                        Image(systemName: "chevron.up")
                            .font(.system(size: size * 0.11, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: tier.dark, radius: 1)
                .offset(y: size * 0.24)
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .accessibilityLabel(division.map { "\(tier.name) 第 \($0) 段" } ?? tier.name)
    }

    @ViewBuilder
    private var emblem: some View {
        if tier.rawValue >= RankTier.platinum.rawValue {
            Gem()
                .fill(LinearGradient(colors: [.white, tier.light, tier.dark],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Gem().stroke(.white.opacity(0.8), lineWidth: size * 0.015))
                .frame(width: size * 0.24, height: size * 0.3)
        } else {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: size * 0.2, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(color: tier.dark, radius: 1)
                .rotationEffect(.degrees(-30))
        }
    }
}

extension RankTier {
    var light: Color {
        switch self {
        case .iron: Color(red: 0.62, green: 0.62, blue: 0.64)
        case .bronze: Color(red: 0.86, green: 0.58, blue: 0.36)
        case .silver: Color(red: 0.88, green: 0.9, blue: 0.93)
        case .gold: Color(red: 1, green: 0.85, blue: 0.4)
        case .platinum: Color(red: 0.55, green: 0.92, blue: 0.86)
        case .diamond: Color(red: 0.62, green: 0.75, blue: 1)
        case .master: Color(red: 0.82, green: 0.6, blue: 1)
        case .champion: Color(red: 1, green: 0.55, blue: 0.45)
        }
    }

    var dark: Color {
        switch self {
        case .iron: Color(red: 0.3, green: 0.3, blue: 0.33)
        case .bronze: Color(red: 0.5, green: 0.28, blue: 0.14)
        case .silver: Color(red: 0.5, green: 0.54, blue: 0.6)
        case .gold: Color(red: 0.72, green: 0.5, blue: 0.08)
        case .platinum: Color(red: 0.1, green: 0.5, blue: 0.5)
        case .diamond: Color(red: 0.25, green: 0.3, blue: 0.8)
        case .master: Color(red: 0.45, green: 0.18, blue: 0.7)
        case .champion: Color(red: 0.75, green: 0.12, blue: 0.2)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [light, dark], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Shapes

struct Shield: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.12),
                       control: CGPoint(x: r.midX + r.width * 0.3, y: r.minY + r.height * 0.1))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.minY + r.height * 0.82))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5),
                       control: CGPoint(x: r.minX, y: r.minY + r.height * 0.82))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.12))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY),
                       control: CGPoint(x: r.midX - r.width * 0.3, y: r.minY + r.height * 0.1))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Shield {
        var s = self
        s.insetAmount += amount
        return s
    }
}

/// 右邊的翅膀（左邊用 scaleEffect 翻過去）。三片羽毛。
struct Wing: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        for i in 0..<3 {
            let y = rect.minY + h * (0.1 + Double(i) * 0.25)
            let len = w * (1 - Double(i) * 0.22)
            p.move(to: CGPoint(x: rect.minX, y: y + h * 0.05))
            p.addQuadCurve(to: CGPoint(x: rect.minX + len, y: y - h * 0.05),
                           control: CGPoint(x: rect.minX + len * 0.6, y: y - h * 0.12))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: y + h * 0.3),
                           control: CGPoint(x: rect.minX + len * 0.55, y: y + h * 0.22))
            p.closeSubpath()
        }
        return p
    }
}

struct Gem: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.38))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.38))
        p.closeSubpath()
        return p
    }
}

struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.27, y: rect.minY + h * 0.6))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.27, y: rect.minY + h * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct Rays: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let count = 12
        for i in 0..<count {
            let a = Double(i) / Double(count) * 2 * .pi
            let half = .pi / Double(count) * 0.45
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + r * cos(a - half), y: c.y + r * sin(a - half)))
            p.addLine(to: CGPoint(x: c.x + r * cos(a + half), y: c.y + r * sin(a + half)))
            p.closeSubpath()
        }
        return p
    }
}
