import SwiftUI

/// 牌位獎章。每一階外框都不同（鐵＝八角鐵板、銅＝齒輪＋月桂、銀＝盾＋雙劍、金＝太陽圓牌＋翅膀、
/// 白金＝六角水晶、鑽石＝菱形水晶＋羽翼、大師＝星徽＋皇冠、王者＝火焰盾＋寶石皇冠）。
/// 形狀資料在 RankBadgeArt.swift，由 scripts/art/badges.js 產生。
struct RankBadge: View {
    let tier: RankTier
    var division: Int? = nil
    var size: CGFloat = 80

    var body: some View {
        Canvas { c, sz in
            let k = sz.width / 120
            c.scaleBy(x: k, y: k)
            // 小段越高外框越華麗：III → II → I；沒指定小段（牌位一覽）畫最完整的那組
            let looks = RankBadgeArt.tiers[tier.rawValue]
            let lv = division.map { 3 - $0 } ?? (looks.count - 1)
            looks[max(0, min(looks.count - 1, lv))].draw(&c)
            if let d = division {
                RankBadgeArt.ribbons[tier.rawValue].draw(&c)
                RankBadgeArt.numerals[max(0, min(3, d))].draw(&c)
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .accessibilityElement()
        .accessibilityLabel(division.map { "\(tier.name) 第 \($0) 段" } ?? tier.name)
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
