import SwiftUI

/// 自己畫的牌位獎章（Canvas，120×120 座標）。牌位越高裝飾越多：
/// 鐵＝鉚釘；銅起月桂葉；銀起側刃；金起翅膀；白金起寶石；鑽石加頂端水晶；大師加皇冠與光芒；王者光芒更多。
struct RankBadge: View {
    let tier: RankTier
    var division: Int? = nil
    var size: CGFloat = 80

    var body: some View {
        Canvas { c, sz in
            let k = sz.width / 120
            c.scaleBy(x: k, y: k)
            BadgePainter(tier: tier, division: division).draw(&c)
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .accessibilityElement()
        .accessibilityLabel(division.map { "\(tier.name) 第 \($0) 段" } ?? tier.name)
    }
}

private struct BadgePainter {
    let tier: RankTier
    let division: Int?

    private var lt: Color { tier.light }
    private var md: Color { tier.mid }
    private var dk: Color { tier.dark }
    private var lv: Int { tier.rawValue }

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private var metal: GraphicsContext.Shading {
        .linearGradient(Gradient(stops: [.init(color: lt, location: 0), .init(color: md, location: 0.55),
                                         .init(color: dk, location: 1)]),
                        startPoint: p(60, 18), endPoint: p(60, 102))
    }
    private var rim: GraphicsContext.Shading {
        .linearGradient(Gradient(stops: [.init(color: lt, location: 0), .init(color: dk, location: 0.5),
                                         .init(color: md, location: 0.75), .init(color: dk, location: 1)]),
                        startPoint: p(26, 16), endPoint: p(94, 104))
    }

    /// 盾牌外形，以 (60,60) 為中心縮放。
    private func shield(_ s: CGFloat, leftHalfOnly: Bool = false) -> Path {
        func q(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 60 + (x - 60) * s, y: 60 + (y - 60) * s) }
        var path = Path()
        path.move(to: q(60, 22))
        if leftHalfOnly {
            path.addLine(to: q(60, 98))
        } else {
            path.addQuadCurve(to: q(88, 28), control: q(74, 30))
            path.addLine(to: q(88, 62))
            path.addQuadCurve(to: q(60, 98), control: q(88, 84))
        }
        path.addQuadCurve(to: q(32, 62), control: q(32, 84))
        path.addLine(to: q(32, 28))
        path.addQuadCurve(to: q(60, 22), control: q(46, 30))
        path.closeSubpath()
        return path
    }

    private func mirrored(_ path: Path) -> Path {
        path.applying(CGAffineTransform(translationX: 120, y: 0).scaledBy(x: -1, y: 1))
    }

    private func poly(_ pts: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(pts)
        path.closeSubpath()
        return path
    }

    func draw(_ c: inout GraphicsContext) {
        // 光芒（大師起）
        if lv >= RankTier.master.rawValue {
            let champ = tier == .champion
            c.fill(Path(ellipseIn: CGRect(x: 2, y: 0, width: 116, height: 116)),
                   with: .radialGradient(Gradient(colors: [md.opacity(0.9), md.opacity(0)]),
                                         center: p(60, 58), startRadius: 0, endRadius: 58))
            let n = champ ? 16 : 10
            let r: CGFloat = champ ? 60 : 52
            var rays = Path()
            for i in 0..<n {
                let a = CGFloat(i) / CGFloat(n) * 2 * .pi
                let h = CGFloat.pi / CGFloat(n) * 0.42
                rays.addLines([p(60, 58), p(60 + r * cos(a - h), 58 + r * sin(a - h)),
                               p(60 + r * cos(a + h), 58 + r * sin(a + h))])
                rays.closeSubpath()
            }
            c.fill(rays, with: .color(lt.opacity(0.35)))
        }

        // 側刃（銀起）
        if lv >= RankTier.silver.rawValue {
            let blade = poly([p(40, 46), p(10, lv >= RankTier.platinum.rawValue ? 30 : 36), p(36, 60)])
            for b in [blade, mirrored(blade)] {
                c.fill(b, with: metal)
                c.stroke(b, with: .color(dk), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }

        // 翅膀（金起）
        if lv >= RankTier.gold.rawValue {
            let n = lv >= RankTier.diamond.rawValue ? 5 : 4
            for i in stride(from: n - 1, through: 0, by: -1) {
                let y = 40 + CGFloat(i) * 9
                let len = 34 - CGFloat(i) * 5 - (n > 4 ? 0 : 2)
                let x0: CGFloat = 82
                let ty = y - 10 + CGFloat(i) * 2
                var f = Path()
                f.move(to: p(x0, y))
                f.addQuadCurve(to: p(x0 + len, ty), control: p(x0 + len * 0.55, ty - 6))
                f.addQuadCurve(to: p(x0, y + 9), control: p(x0 + len * 0.6, y + 7))
                f.closeSubpath()
                for side in [f, mirrored(f)] {
                    c.fill(side, with: .color(i % 2 == 1 ? md : lt))
                    c.stroke(side, with: .color(dk), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                }
            }
        }

        // 月桂葉（銅起）
        if lv >= RankTier.bronze.rawValue {
            let leaf = lv >= RankTier.gold.rawValue ? Color(red: 1, green: 0.88, blue: 0.54) : lt
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                let a = CGFloat.pi * (0.62 + 0.33 * t)
                let cx = 60 + 40 * cos(a)
                let cy = 62 + 38 * sin(a)
                let ang = a + .pi / 2 + .pi / 6
                let e = Path(ellipseIn: CGRect(x: -3.3, y: -7, width: 6.6, height: 14))
                    .applying(CGAffineTransform(translationX: cx, y: cy).rotated(by: ang))
                for side in [e, mirrored(e)] {
                    c.fill(side, with: .color(leaf))
                    c.stroke(side, with: .color(dk), lineWidth: 1.3)
                }
            }
        }

        // 盾牌：外框、金屬邊、本體、左半高光
        c.fill(shield(1.12), with: .color(dk))
        c.fill(shield(1.06), with: rim)
        c.fill(shield(0.92), with: metal)
        c.fill(shield(0.92, leftHalfOnly: true), with: .color(.white.opacity(0.18)))
        c.stroke(shield(0.92), with: .color(dk.opacity(0.6)), lineWidth: 1.5)

        // 鉚釘（鐵）
        if tier == .iron {
            for (x, y) in [(40.0, 34.0), (80, 34), (40, 70), (80, 70)] {
                let r = Path(ellipseIn: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8))
                c.fill(r, with: .color(lt))
                c.stroke(r, with: .color(dk), lineWidth: 1)
            }
        }

        // 中央圓章
        let medal = Path(ellipseIn: CGRect(x: 43, y: 39, width: 34, height: 34))
        c.fill(medal, with: .color(dk))
        c.stroke(medal, with: .color(lt), lineWidth: 2)

        if lv < RankTier.platinum.rawValue {
            // 啞鈴
            var d = c
            d.translateBy(x: 60, y: 56)
            d.rotate(by: .degrees(-30))
            d.translateBy(x: -60, y: -56)
            let parts: [(CGRect, CGFloat)] = [
                (CGRect(x: 52, y: 54.5, width: 16, height: 3), 0),
                (CGRect(x: 47, y: 48, width: 5, height: 16), 1.5),
                (CGRect(x: 68, y: 48, width: 5, height: 16), 1.5),
                (CGRect(x: 43, y: 51, width: 4, height: 10), 1.2),
                (CGRect(x: 73, y: 51, width: 4, height: 10), 1.2)
            ]
            for (r, rad) in parts {
                let path = Path(roundedRect: r, cornerRadius: rad)
                d.fill(path, with: .color(lt))
                d.stroke(path, with: .color(dk), lineWidth: 1)
            }
        } else {
            // 寶石
            let top = p(60, 42), right = p(72, 52), bottom = p(60, 71), left = p(48, 52), mid = p(60, 56)
            c.fill(poly([top, right, bottom, left]), with: .color(md))
            c.fill(poly([top, right, mid]), with: .color(.white.opacity(0.85)))
            c.fill(poly([top, left, mid]), with: .color(lt))
            c.fill(poly([left, mid, bottom]), with: .color(md))
            c.fill(poly([right, mid, bottom]), with: .color(dk))
            c.stroke(poly([top, right, bottom, left]), with: .color(.white.opacity(0.8)), lineWidth: 1)
        }

        // 頂端水晶（鑽石）
        if tier == .diamond {
            let main = poly([p(60, 4), p(66, 18), p(60, 24), p(54, 18)])
            c.fill(main, with: .color(lt))
            c.stroke(main, with: .color(dk), lineWidth: 1.5)
            let side = poly([p(48, 12), p(52, 22), p(47, 24)])
            for s in [side, mirrored(side)] {
                c.fill(s, with: .color(md))
                c.stroke(s, with: .color(dk), lineWidth: 1.2)
            }
        }

        // 皇冠（大師起）
        if lv >= RankTier.master.rawValue {
            let brown = Color(red: 0.42, green: 0.26, blue: 0.02)
            let crown = poly([p(42, 22), p(40, 6), p(50, 14), p(60, 2), p(70, 14), p(80, 6), p(78, 22)])
            c.fill(crown, with: .color(Color(red: 1, green: 0.89, blue: 0.48)))
            c.stroke(crown, with: .color(brown), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            c.fill(Path(CGRect(x: 42, y: 17, width: 36, height: 5)),
                   with: .color(Color(red: 0.79, green: 0.54, blue: 0.06)))
            let jewel = Path(ellipseIn: CGRect(x: 57.4, y: 8.4, width: 5.2, height: 5.2))
            c.fill(jewel, with: .color(tier == .champion ? Color(red: 1, green: 0.29, blue: 0.35)
                                                         : Color(red: 0.69, green: 0.49, blue: 1)))
            c.stroke(jewel, with: .color(brown), lineWidth: 1)
        }

        // 小段緞帶：III=1 個箭頭，I=3 個
        if let d = division {
            let ribbon = poly([p(40, 92), p(80, 92), p(84, 100), p(80, 108), p(40, 108), p(36, 100)])
            c.fill(ribbon, with: .color(dk))
            c.stroke(ribbon, with: .color(lt), lineWidth: 1.5)
            let n = max(0, 4 - d)
            var chev = Path()
            for i in 0..<n {
                let cx = 60 + (CGFloat(i) - CGFloat(n - 1) / 2) * 9
                chev.move(to: p(cx - 3.5, 103))
                chev.addLine(to: p(cx, 97))
                chev.addLine(to: p(cx + 3.5, 103))
            }
            c.stroke(chev, with: .color(.white), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
        }
    }
}

extension RankTier {
    private var palette: (String, String, String) {
        switch self {
        case .iron: ("#B9BEC6", "#5C626C", "#2A2E35")
        case .bronze: ("#F0B07A", "#A0582B", "#4A2410")
        case .silver: ("#F4F7FB", "#9AA6B6", "#3E4756")
        case .gold: ("#FFE48A", "#D69A1E", "#6A4205")
        case .platinum: ("#B8FFF0", "#2FB7A6", "#0B4D4A")
        case .diamond: ("#CFE0FF", "#5B7BF0", "#1C2370")
        case .master: ("#EBC8FF", "#9B4BE0", "#3A0F63")
        case .champion: ("#FFD0A8", "#F0523C", "#6A0A1A")
        }
    }

    var light: Color { Color(gearHex: palette.0) }
    var mid: Color { Color(gearHex: palette.1) }
    var dark: Color { Color(gearHex: palette.2) }

    var gradient: LinearGradient {
        LinearGradient(colors: [light, mid, dark], startPoint: .top, endPoint: .bottom)
    }
}
