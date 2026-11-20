import SwiftUI

// MARK: - Fight method

enum FightMethod: String {
    case ko, sub, dec

    init(_ length: WorkoutLength) {
        switch length {
        case .full: self = .ko
        case .short: self = .sub
        case .minimal: self = .dec
        }
    }

    var title: String {
        switch self {
        case .ko: "KO 勝"
        case .sub: "降伏勝"
        case .dec: "判定勝"
        }
    }

    var xp: Int {
        switch self {
        case .ko: 100
        case .sub: 60
        case .dec: 40
        }
    }

    var purse: Int { xp }

    var points: Int {
        switch self {
        case .ko: 10
        case .sub: 7
        case .dec: 4
        }
    }

    var dropChance: Double {
        switch self {
        case .ko: 0.35
        case .sub: 0.25
        case .dec: 0.20
        }
    }
}

// MARK: - Ranking tiers

enum Tier: Int, CaseIterable, Comparable {
    case amateur, regional, prospect, ranked, contender, champion

    static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .amateur: "業餘"
        case .regional: "地區賽"
        case .prospect: "職業新秀"
        case .ranked: "排名選手"
        case .contender: "頭銜挑戰者"
        case .champion: "冠軍"
        }
    }

    var minPoints: Int {
        switch self {
        case .amateur: 0
        case .regional: 100
        case .prospect: 250
        case .ranked: 500
        case .contender: 900
        case .champion: 900
        }
    }

    static func of(points: Int, champion: Bool) -> Tier {
        if champion { return .champion }
        if points >= 900 { return .contender }
        if points >= 500 { return .ranked }
        if points >= 250 { return .prospect }
        if points >= 100 { return .regional }
        return .amateur
    }

    /// "#15" ... "#1" inside the ranked tier.
    static func rankNumber(points: Int) -> Int? {
        guard points >= 500 && points < 900 else { return nil }
        let n = 15 - Int(Double(points - 500) / 400 * 15)
        return min(15, max(1, n))
    }
}

// MARK: - Cosmetics

enum GearSlot: String, CaseIterable, Identifiable {
    case gloves, shorts, robe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gloves: "拳套"
        case .shorts: "短褲"
        case .robe: "出場袍"
        }
    }

    var symbol: String {
        switch self {
        case .gloves: "hand.raised.fill"
        case .shorts: "rectangle.portrait.fill"
        case .robe: "tshirt.fill"
        }
    }
}

enum Rarity: Int, CaseIterable, Comparable {
    case common, rare, epic, legendary

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var title: String {
        switch self {
        case .common: "普通"
        case .rare: "稀有"
        case .epic: "史詩"
        case .legendary: "傳說"
        }
    }

    var color: Color {
        switch self {
        case .common: .gray
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        }
    }

    /// Out of 100.
    var weight: Int {
        switch self {
        case .common: 60
        case .rare: 28
        case .epic: 10
        case .legendary: 2
        }
    }

    var duplicatePurse: Int {
        switch self {
        case .common: 30
        case .rare: 80
        case .epic: 200
        case .legendary: 500
        }
    }
}

struct Cosmetic: Identifiable, Hashable {
    let id: String
    let slot: GearSlot
    let name: String
    let rarity: Rarity
    let hex: UInt32
    var isDefault = false

    var color: Color { Color(hex: hex) }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Cosmetics {
    static let all: [Cosmetic] = [
        Cosmetic(id: "gloves_red", slot: .gloves, name: "經典紅", rarity: .common, hex: 0xD42F28, isDefault: true),
        Cosmetic(id: "gloves_black", slot: .gloves, name: "夜黑", rarity: .common, hex: 0x26262B),
        Cosmetic(id: "gloves_white", slot: .gloves, name: "雪白", rarity: .common, hex: 0xE9E9EC),
        Cosmetic(id: "gloves_navy", slot: .gloves, name: "海軍藍", rarity: .rare, hex: 0x1F3A8A),
        Cosmetic(id: "gloves_camo", slot: .gloves, name: "迷彩綠", rarity: .rare, hex: 0x4B6B3A),
        Cosmetic(id: "gloves_pink", slot: .gloves, name: "霓虹粉", rarity: .epic, hex: 0xFF3EA5),
        Cosmetic(id: "gloves_lava", slot: .gloves, name: "熔岩橘", rarity: .epic, hex: 0xFF6A13),
        Cosmetic(id: "gloves_gold", slot: .gloves, name: "黃金", rarity: .legendary, hex: 0xE6C14A),

        Cosmetic(id: "shorts_red", slot: .shorts, name: "經典紅", rarity: .common, hex: 0xD42F28, isDefault: true),
        Cosmetic(id: "shorts_black", slot: .shorts, name: "夜黑", rarity: .common, hex: 0x26262B),
        Cosmetic(id: "shorts_grey", slot: .shorts, name: "鐵灰", rarity: .common, hex: 0x6B6B72),
        Cosmetic(id: "shorts_blue", slot: .shorts, name: "藍角", rarity: .rare, hex: 0x2F6FD6),
        Cosmetic(id: "shorts_tiger", slot: .shorts, name: "虎紋", rarity: .epic, hex: 0xF29E1F),
        Cosmetic(id: "shorts_gold", slot: .shorts, name: "黃金", rarity: .legendary, hex: 0xE6C14A),

        Cosmetic(id: "robe_black", slot: .robe, name: "黑金", rarity: .common, hex: 0x2B2D35, isDefault: true),
        Cosmetic(id: "robe_white", slot: .robe, name: "純白", rarity: .common, hex: 0xF2F2F2),
        Cosmetic(id: "robe_red", slot: .robe, name: "戰紅", rarity: .rare, hex: 0xB3201B),
        Cosmetic(id: "robe_dragon", slot: .robe, name: "龍紋", rarity: .epic, hex: 0x0F7B6C),
        Cosmetic(id: "robe_champ", slot: .robe, name: "冠軍金", rarity: .legendary, hex: 0xC9A227),
    ]

    static let defaults: Set<String> = Set(all.filter(\.isDefault).map(\.id))

    static func byId(_ id: String) -> Cosmetic? { all.first { $0.id == id } }

    static func equipped(_ slot: GearSlot, owned: Set<String>) -> Cosmetic {
        if let id = CareerStore.equipped()[slot], owned.contains(id), let c = byId(id) { return c }
        return all.first { $0.slot == slot && $0.isDefault }!
    }
}

// MARK: - Gear levels

enum GearKind: String, CaseIterable, Identifiable {
    case gloves, shin, shorts, robe, belt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gloves: "拳套"
        case .shin: "護脛"
        case .shorts: "短褲"
        case .robe: "出場袍"
        case .belt: "冠軍腰帶"
        }
    }

    var symbol: String {
        switch self {
        case .gloves: "hand.raised.fill"
        case .shin: "shield.lefthalf.filled"
        case .shorts: "rectangle.portrait.fill"
        case .robe: "tshirt.fill"
        case .belt: "crown.fill"
        }
    }

    var rule: String {
        switch self {
        case .gloves: "每破 3 次紀錄升 1 級"
        case .shin: "總勝場越多越高級"
        case .shorts: "每贏 1 場訓練營比賽升 1 級"
        case .robe: "最長連續週數越長越華麗"
        case .belt: "當上冠軍才拿得到"
        }
    }

    static let shinWins = [10, 25, 50, 100, 150, 200, 300, 400, 500]
    static let robeStreaks = [2, 4, 8, 12, 20, 26, 36, 52]
}

// MARK: - Badges

struct Badge: Identifiable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
}

enum Badges {
    static let tonnage: [(kg: Double, name: String)] = [
        (150, "一台機車"), (300, "一台鋼琴"), (600, "一頭乳牛"), (1_300, "一台小客車"), (3_000, "一頭河馬"),
        (6_000, "一頭大象"), (12_000, "一台公車"), (20_000, "一隻鯨鯊"), (41_000, "一架波音 737"), (150_000, "一頭藍鯨"),
    ]

    static let all: [Badge] = {
        var list: [Badge] = [
            Badge(id: "first_win", name: "出道戰", detail: "拿下第一場勝利", symbol: "figure.boxing"),
            Badge(id: "first_ko", name: "第一次 KO", detail: "完成第一次完整版", symbol: "bolt.fill"),
            Badge(id: "comeback", name: "懶人也是勇者", detail: "漏練之後用「只做 1 組」接回來", symbol: "tortoise.fill"),
        ]
        for n in [10, 25, 50, 100, 200] {
            list.append(Badge(id: "wins_\(n)", name: "\(n) 勝", detail: "累積 \(n) 場勝利", symbol: "trophy.fill"))
        }
        for n in [4, 8, 12, 26, 52] {
            list.append(Badge(id: "streak_\(n)", name: "連續 \(n) 週", detail: "連續 \(n) 週每週練 2 次以上", symbol: "flame.fill"))
        }
        list += [
            Badge(id: "pr_1", name: "突破", detail: "第一次破個人紀錄", symbol: "arrow.up.right"),
            Badge(id: "pr_10", name: "破紀錄機器", detail: "破紀錄 10 次", symbol: "chart.line.uptrend.xyaxis"),
            Badge(id: "pr_50", name: "怪物", detail: "破紀錄 50 次", symbol: "chart.line.uptrend.xyaxis.circle.fill"),
            Badge(id: "camp_1", name: "大賽首勝", detail: "贏下第一場訓練營比賽", symbol: "flag.checkered"),
            Badge(id: "champion", name: "世界冠軍", detail: "贏下頭銜戰", symbol: "crown.fill"),
            Badge(id: "defense_1", name: "首次衛冕", detail: "成功衛冕一次", symbol: "shield.fill"),
            Badge(id: "defense_3", name: "王朝", detail: "成功衛冕三次", symbol: "shield.checkered"),
            Badge(id: "quest_10", name: "任務達人", detail: "完成 10 個週任務", symbol: "checklist"),
            Badge(id: "bet_win", name: "敢押就敢練", detail: "押注成功一次", symbol: "dollarsign.circle.fill"),
            Badge(id: "bet_5", name: "穩賺不賠", detail: "押注成功 5 次", symbol: "banknote.fill"),
            Badge(id: "legendary", name: "傳說降臨", detail: "掉落一件傳說配色", symbol: "sparkles"),
            Badge(id: "undefeated_20", name: "不敗神話", detail: "20 勝 0 敗", symbol: "star.fill"),
        ]
        for (i, t) in tonnage.enumerated() {
            list.append(Badge(id: "ton_\(i)", name: "舉起\(t.name)",
                              detail: "累積總重量 \(Int(t.kg).formatted()) kg", symbol: "scalemass.fill"))
        }
        return list
    }()

    static func byId(_ id: String) -> Badge? { all.first { $0.id == id } }
}

// MARK: - Opponents and quests

enum Opponents {
    static let all: [(nick: String, name: String)] = [
        ("鐵牆", "王大衛"), ("颱風", "林宇翔"), ("剃刀", "陳柏諺"), ("山貓", "吳建廷"),
        ("狼牙", "許哲維"), ("推土機", "黃志豪"), ("幽靈", "蔡承恩"), ("鬥牛", "劉冠宇"),
    ]

    static func forCamp(_ index: Int) -> (nick: String, name: String) {
        all[((index % all.count) + all.count) % all.count]
    }
}

enum QuestKind: String, CaseIterable {
    case goal, pr, ko, both, volume, onTime

    var xp: Int {
        switch self {
        case .goal: 150
        case .pr: 150
        case .ko, .volume, .onTime: 120
        case .both: 100
        }
    }

    var purse: Int {
        switch self {
        case .goal: 100
        case .pr: 80
        case .ko, .volume, .onTime: 60
        case .both: 50
        }
    }

    func target(goal: Int) -> Int {
        switch self {
        case .goal: goal
        case .pr: 1
        case .ko: 2
        case .both: 2
        case .volume: 50
        case .onTime: 3
        }
    }

    func title(goal: Int) -> String {
        switch self {
        case .goal: "本週練滿 \(goal) 次"
        case .pr: "破 1 次個人紀錄"
        case .ko: "完成 2 次完整版"
        case .both: "上半身、下半身各練 1 次"
        case .volume: "本週完成 50 組"
        case .onTime: "在排定的日子練 3 次"
        }
    }

    static let pool: [QuestKind] = [.pr, .ko, .both, .volume, .onTime]

    /// Three quests for a week: the weekly goal plus two picked by the week number.
    static func forWeek(_ weekStart: Date) -> [QuestKind] {
        let seed = Int(weekStart.timeIntervalSince1970 / 86400 / 7)
        let n = pool.count
        let a = ((seed % n) + n) % n
        let b = (a + 1 + ((seed / n) % (n - 1) + (n - 1)) % (n - 1)) % n
        return [.goal, pool[a], pool[b]]
    }
}
