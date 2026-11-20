import SwiftUI

extension Color {
    /// "#RRGGBB" 轉 Color；格式錯誤時回傳灰色。
    init(gearHex: String) {
        var s = gearHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        if s.count == 6, Scanner(string: s).scanHexInt64(&v) {
            let r = Double((v >> 16) & 0xFF) / 255.0
            let g = Double((v >> 8) & 0xFF) / 255.0
            let b = Double(v & 0xFF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
        } else {
            self.init(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
        }
    }
}

enum Rarity: Int, CaseIterable, Comparable {
    case common = 1, rare = 2, epic = 3, legendary = 4

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .common: return "普通"
        case .rare: return "稀有"
        case .epic: return "史詩"
        case .legendary: return "傳說"
        }
    }

    var hex: String {
        switch self {
        case .common: return "#8A949F"
        case .rare: return "#2F7BEA"
        case .epic: return "#8A4FE0"
        case .legendary: return "#E0A21B"
        }
    }

    var color: Color { Color(gearHex: hex) }

    /// 抽到已擁有的裝備時換成的碎片數。
    var shardValue: Int {
        switch self {
        case .common: return 5
        case .rare: return 10
        case .epic: return 25
        case .legendary: return 60
        }
    }

    /// 碎片兌換所需數量。
    var exchangeCost: Int {
        switch self {
        case .common: return 20
        case .rare: return 50
        case .epic: return 120
        case .legendary: return 300
        }
    }

    /// 戰力加成。
    var powerBonus: Int {
        switch self {
        case .common: return 60
        case .rare: return 140
        case .epic: return 260
        case .legendary: return 480
        }
    }
}

enum GearSlot: String, CaseIterable, Identifiable, Hashable {
    case head, top, bottom, feet, hands, back, bell, fx

    var id: String { rawValue }

    var name: String {
        switch self {
        case .head: return "頭部"
        case .top: return "上衣"
        case .bottom: return "下身"
        case .feet: return "鞋子"
        case .hands: return "手部"
        case .back: return "背部"
        case .bell: return "啞鈴造型"
        case .fx: return "特效"
        }
    }

    /// 該部位沒有裝備時的顯示名稱。
    var emptyName: String {
        switch self {
        case .feet: return "赤腳"
        case .top: return "赤膊"
        case .bottom: return "內褲"
        case .bell: return "預設"
        default: return "無"
        }
    }
}

struct Series: Identifiable, Hashable {
    let id: String
    let name: String
    let rarity: Rarity
    let c1: String
    let c2: String
    let c3: String
    let glow: String
    let hero: String?

    /// 標籤文字：英雄類顯示類型，其他顯示稀有度系列。
    var label: String { hero ?? rarity.name + "系列" }
    var isGold: Bool { id == "gold" }
}

struct GearItem: Identifiable, Hashable {
    let id: String          // "\(series).\(slot)"
    let series: String
    let slot: GearSlot
    let name: String
    let form: String
    let c: String
    let c2: String?
    let rarity: Rarity
    let cover: [String]
    let pauldron: Bool
    let emblem: String?
    let glow: Bool

    /// 黃金系列只能靠里程碑取得。
    var isGold: Bool { series == "gold" }
}

enum GearCatalog {
    static let series: [Series] = [
        Series(id: "basic", name: "基本款", rarity: .common, c1: "#3E4652", c2: "#F4F5F7", c3: "#9AA4AF", glow: "#C9D1DA", hero: nil),
        Series(id: "street", name: "街頭", rarity: .rare, c1: "#2F6FE0", c2: "#F4F5F7", c3: "#FFCC33", glow: "#4D8DFF", hero: nil),
        Series(id: "neon", name: "霓虹", rarity: .epic, c1: "#141A24", c2: "#19E3FF", c3: "#FF3DCB", glow: "#19E3FF", hero: nil),
        Series(id: "lava", name: "熔岩", rarity: .epic, c1: "#2A1A16", c2: "#FF5A1F", c3: "#FFC23D", glow: "#FF5A1F", hero: nil),
        Series(id: "frost", name: "冰霜", rarity: .epic, c1: "#DDF4FF", c2: "#4FB8FF", c3: "#FFFFFF", glow: "#8FDBFF", hero: nil),
        Series(id: "gold", name: "黃金", rarity: .legendary, c1: "#F2B630", c2: "#FFF1B8", c3: "#C8302C", glow: "#FFC83D", hero: nil),
        Series(id: "shadow", name: "暗影", rarity: .legendary, c1: "#1A1424", c2: "#9B5CFF", c3: "#E2D4FF", glow: "#9B5CFF", hero: nil),
        Series(id: "titan", name: "鈦甲", rarity: .legendary, c1: "#8C98A8", c2: "#31F2D4", c3: "#2A3340", glow: "#31F2D4", hero: "科技裝甲"),
        Series(id: "night", name: "夜巡者", rarity: .epic, c1: "#1C2230", c2: "#FF8A1F", c3: "#3B4558", glow: "#FF8A1F", hero: "黑夜義警"),
        Series(id: "dawn", name: "曙光", rarity: .legendary, c1: "#EEF3FA", c2: "#E0A21B", c3: "#2E6BFF", glow: "#FFD45C", hero: "披風英雄"),
        Series(id: "rune", name: "符文戰神", rarity: .legendary, c1: "#2C2F3A", c2: "#3DF5A0", c3: "#C9A86A", glow: "#3DF5A0", hero: "奇幻戰士"),
        Series(id: "astral", name: "星界魔導", rarity: .legendary, c1: "#22184A", c2: "#FF6BD6", c3: "#8FE3FF", glow: "#FF6BD6", hero: "奇幻法師")
    ]

    private struct Spec {
        let form: String
        let name: String
        let c: String
        let c2: String?
        let pa: Bool
        let em: String?
        let gl: Bool
    }

    private static func s(_ form: String, _ name: String, _ c: String, _ c2: String? = nil,
                          pa: Bool = false, em: String? = nil, gl: Bool = false) -> Spec {
        Spec(form: form, name: name, c: c, c2: c2, pa: pa, em: em, gl: gl)
    }

    private static let cover: [String: [String]] = [
        "armor": ["torso", "upper", "fore"],
        "greaves": ["thigh", "shin"],
        "tank": ["torso"],
        "tee": ["torso", "upper"],
        "comp": ["torso", "upper", "fore"],
        "shorts": ["thigh"],
        "jogger": ["thigh", "shin"]
    ]

    /// 每個系列在每個部位長什麼樣。
    private static let form: [String: [GearSlot: Spec]] = {
        var d: [String: [GearSlot: Spec]] = [:]
        d["basic"] = [.head: s("band", "吸汗頭帶", "c2"), .top: s("tank", "灰背心", "c1"),
                  .bottom: s("shorts", "黑短褲", "#22272E"), .feet: s("shoe", "白球鞋", "c2"),
                  .hands: s("wrist", "白護腕", "c2"), .bell: s("bell", "鑄鐵啞鈴", "#1B2027")]
        d["street"] = [.head: s("cap", "街頭棒球帽", "c1"), .top: s("tee", "街頭帽T", "c1", "c2"),
                   .bottom: s("shorts", "白籃球褲", "c2", "c1"), .feet: s("shoe", "藍色球鞋", "c1"),
                   .hands: s("glove", "街頭手套", "c2"), .bell: s("bell", "電鍍啞鈴", "#C9D1DA")]
        d["neon"] = [.head: s("visor", "霓虹護目鏡", "c2"), .top: s("comp", "霓虹緊身衣", "c1", "c2"),
                 .bottom: s("jogger", "霓虹長褲", "c1", "c3"), .feet: s("shoe", "發光跑鞋", "c3"),
                 .hands: s("glove", "電光手套", "c2"), .back: s("ring", "能量背環", "c2"),
                 .bell: s("bell", "霓虹啞鈴", "c2"), .fx: s("bolt", "電光", "c2")]
        d["lava"] = [.head: s("band", "火焰頭帶", "c2", "c3"), .top: s("tank", "熔岩背心", "c1", "c2"),
                 .bottom: s("shorts", "岩漿短褲", "c2", "c3"), .feet: s("shoe", "熔岩戰靴", "c2"),
                 .hands: s("glove", "火拳手套", "c2"), .back: s("cape", "火焰披風", "c2", "c3"),
                 .bell: s("bell", "岩漿啞鈴", "c2"), .fx: s("fire", "火焰", "c2")]
        d["frost"] = [.head: s("beanie", "冰晶毛帽", "c2", "c3"), .top: s("tee", "冰霜 T 恤", "c1", "c2"),
                  .bottom: s("jogger", "冰霜長褲", "c2", "c3"), .feet: s("shoe", "冰刃鞋", "c3"),
                  .hands: s("glove", "霜凍手套", "c3"), .back: s("cape", "冰晶披風", "c2", "c3"),
                  .bell: s("bell", "冰塊啞鈴", "c1"), .fx: s("ice", "冰晶", "c2")]
        d["gold"] = [.head: s("crown", "王者之冠", "c1"), .top: s("tank", "黃金背心", "c1", "c3"),
                 .bottom: s("shorts", "黃金短褲", "c3", "c1"), .feet: s("shoe", "黃金戰靴", "c1"),
                 .hands: s("glove", "黃金拳套", "c1"), .back: s("cape", "王者披風", "c3", "c1"),
                 .bell: s("bell", "純金啞鈴", "c1"), .fx: s("gold", "金光", "c1")]
        d["shadow"] = [.head: s("mask", "暗影面罩", "c1", "c2"), .top: s("comp", "暗影戰衣", "c1", "c2"),
                   .bottom: s("jogger", "暗影長褲", "c1", "c2"), .feet: s("shoe", "無聲靴", "c1"),
                   .hands: s("glove", "暗影手甲", "c1"), .back: s("cape", "暗影披風", "c1", "c2"),
                   .bell: s("bell", "虛空啞鈴", "c2"), .fx: s("smoke", "暗影煙", "c1")]
        d["titan"] = [.head: s("helmet", "鈦甲頭盔", "c1", "c2"),
                  .top: s("armor", "鈦甲胸甲", "c1", "c2", pa: true, em: "core", gl: true),
                  .bottom: s("greaves", "鈦甲腿甲", "c1", "c2", gl: true),
                  .feet: s("shoe", "推進靴", "c3"), .hands: s("glove", "鈦甲手甲", "c1"),
                  .back: s("jets", "背部推進器", "c2"), .bell: s("bell", "能量啞鈴", "c2"),
                  .fx: s("scan", "全像掃描", "c2")]
        d["night"] = [.head: s("hood", "義警兜帽", "c1", "c3"),
                  .top: s("armor", "戰術背心", "c3", "c2", em: "chevron"),
                  .bottom: s("jogger", "戰術長褲", "c1", "c2"), .feet: s("shoe", "戰術靴", "c1"),
                  .hands: s("glove", "戰術手套", "c1"), .back: s("cape", "夜行斗篷", "c1", "c2"),
                  .bell: s("bell", "消光啞鈴", "#2A303A"), .fx: s("rain", "夜雨", "c2")]
        d["dawn"] = [.head: s("circlet", "曙光頭環", "c2", "c3"),
                 .top: s("comp", "曙光戰衣", "c1", "c2", em: "star"),
                 .bottom: s("jogger", "曙光長褲", "c3", "c2"), .feet: s("shoe", "曙光長靴", "c3"),
                 .hands: s("glove", "曙光護手", "c2"), .back: s("cape", "曙光披風", "c3", "c2"),
                 .bell: s("bell", "聖光啞鈴", "c2"), .fx: s("rays", "聖光", "c2")]
        d["rune"] = [.head: s("horns", "戰神角盔", "c3", "c1"),
                 .top: s("armor", "符文戰甲", "c1", "c2", pa: true, em: "rune", gl: true),
                 .bottom: s("greaves", "符文腿甲", "c1", "c2", gl: true),
                 .feet: s("shoe", "青銅戰靴", "c3"), .hands: s("glove", "符文拳套", "c3"),
                 .back: s("sword", "背負巨劍", "c3", "c2"), .bell: s("bell", "符文啞鈴", "c2"),
                 .fx: s("magic", "符文法陣", "c2")]
        d["astral"] = [.head: s("tiara", "星晶冠", "c2", "c3"),
                   .top: s("comp", "星界法袍", "c1", "c2", em: "diamond", gl: true),
                   .bottom: s("jogger", "星界長褲", "c1", "c3"), .feet: s("shoe", "星光鞋", "c3"),
                   .hands: s("glove", "星界護手", "c2"), .back: s("wings", "能量羽翼", "c2", "c3"),
                   .bell: s("bell", "星核啞鈴", "c3"), .fx: s("stars", "星塵", "c2")]
        return d
    }()

    private static func resolve(_ v: String?, _ se: Series) -> String? {
        guard let v = v else { return nil }
        switch v {
        case "c1": return se.c1
        case "c2": return se.c2
        case "c3": return se.c3
        default: return v
        }
    }

    /// 全部裝備，依部位、再依系列順序排列。
    static let items: [GearItem] = {
        var out: [GearItem] = []
        for slot in GearSlot.allCases {
            for se in series {
                guard let sp = form[se.id]?[slot] else { continue }
                out.append(GearItem(
                    id: "\(se.id).\(slot.rawValue)",
                    series: se.id,
                    slot: slot,
                    name: sp.name,
                    form: sp.form,
                    c: resolve(sp.c, se) ?? "#888888",
                    c2: resolve(sp.c2, se),
                    rarity: se.rarity,
                    cover: cover[sp.form] ?? [],
                    pauldron: sp.pa,
                    emblem: sp.em,
                    glow: sp.gl))
            }
        }
        return out
    }()

    private static let itemById: [String: GearItem] = {
        var d: [String: GearItem] = [:]
        for it in items { d[it.id] = it }
        return d
    }()

    static func item(_ id: String) -> GearItem? { itemById[id] }

    static func seriesById(_ id: String) -> Series? { series.first { $0.id == id } }

    static func items(for slot: GearSlot) -> [GearItem] { items.filter { $0.slot == slot } }

    static func basicItems() -> [GearItem] { items.filter { $0.series == "basic" } }
}

/// 目前穿戴：部位 -> 裝備 id。
struct Loadout: Codable, Equatable {
    var slots: [String: String] = [:]

    subscript(_ slot: GearSlot) -> String? {
        get { slots[slot.rawValue] }
        set { slots[slot.rawValue] = newValue }
    }

    func item(_ slot: GearSlot) -> GearItem? {
        guard let id = slots[slot.rawValue], let it = GearCatalog.item(id), it.slot == slot else { return nil }
        return it
    }

    /// 同系列 4 件以上才算套裝；回傳件數最多的系列（同數量取先出現的）。
    var setBonus: (series: Series, count: Int)? {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for slot in GearSlot.allCases {
            if let it = item(slot) {
                if counts[it.series] == nil { order.append(it.series) }
                counts[it.series, default: 0] += 1
            }
        }
        var best: String?
        for id in order {
            let n = counts[id] ?? 0
            if n >= 4 {
                if let b = best {
                    if n > (counts[b] ?? 0) { best = id }
                } else {
                    best = id
                }
            }
        }
        if let b = best, let se = GearCatalog.seriesById(b) {
            return (se, counts[b] ?? 0)
        }
        return nil
    }

    /// 0 表示什麼都沒穿。
    var topRarity: Int {
        var m = 0
        for slot in GearSlot.allCases {
            if let it = item(slot) { m = max(m, it.rarity.rawValue) }
        }
        return m
    }

    var power: Int {
        var p = 320
        for slot in GearSlot.allCases {
            if let it = item(slot) { p += it.rarity.powerBonus }
        }
        if setBonus != nil { p = Int((Double(p) * 1.2).rounded()) }
        return p
    }
}
