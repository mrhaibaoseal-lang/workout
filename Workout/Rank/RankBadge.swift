import SwiftUI

/// 牌位獎章。每一階外框都不同（鐵＝八角鐵板、銅＝齒輪＋月桂、銀＝盾＋雙劍、金＝太陽圓牌＋翅膀、
/// 白金＝六角水晶、鑽石＝菱形水晶＋羽翼、大師＝星徽＋皇冠、王者＝火焰盾＋寶石皇冠）。
/// 中央是肌肉手臂，牌位越高肌肉越大。形狀資料在 RankBadgeArt.swift，由 scripts/art/badges.js 產生。
struct RankBadge: View {
    enum Motion {
        /// 靜態（列表、小圖示）
        case still
        /// 出現時反光掃過一次（今天頁、進步頁的小卡）
        case shine
        /// 完整待機動畫：各部位動作、粒子、反光（詳情頁、預覽）
        case live
    }

    let tier: RankTier
    var division: Int? = nil
    var size: CGFloat = 80
    var motion: Motion = .still

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var shineDone = false

    /// 動畫時畫布比獎章大一圈，粒子才不會被切掉；用負的 padding 讓排版大小不變。
    private var margin: CGFloat { motion == .live && !reduceMotion ? 0.18 : 0 }

    var body: some View {
        let side = size * 1.2
        Group {
            switch reduceMotion ? Motion.still : motion {
            case .still:
                canvas(fx: .still)
            case .shine:
                TimelineView(.animation(minimumInterval: 1 / 60, paused: shineDone)) { ctx in
                    canvas(fx: Self.shineFX(ctx.date.timeIntervalSince(start)))
                }
                .task {
                    start = Date()
                    shineDone = false
                    try? await Task.sleep(for: .seconds(1.4))
                    shineDone = true
                }
            case .live:
                TimelineView(.animation) { ctx in
                    canvas(fx: Self.liveFX(ctx.date.timeIntervalSince(start)))
                }
            }
        }
        .frame(width: side * (1 + margin * 2), height: side * (1 + margin * 2))
        .padding(-side * margin)
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel(division.map { "\(tier.name) 第 \($0) 段" } ?? tier.name)
    }

    static func shineFX(_ t: Double) -> BadgeFX {
        var fx = BadgeFX()
        let u = FXMath.clamp((t - 0.35) / 0.9)
        fx.sheen = u > 0 && u < 1 ? u : nil
        return fx
    }

    static func liveFX(_ t: Double) -> BadgeFX {
        var fx = BadgeFX()
        fx.t = t
        fx.idle = true
        fx.particles = FXMath.clamp(t / 0.6)
        fx.sheen = -1
        return fx
    }

    private func canvas(fx: BadgeFX) -> some View {
        let m = margin
        return Canvas { c, sz in
            let k = sz.width / (1 + m * 2) / 120
            c.translateBy(x: sz.width * m / (1 + m * 2), y: sz.height * m / (1 + m * 2))
            c.scaleBy(x: k, y: k)
            BadgeRenderer.draw(&c, tier: tier.rawValue, division: division, fx: fx)
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
