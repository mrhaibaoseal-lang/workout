import Foundation
import SwiftUI

/// 背包：擁有的裝備、穿戴、碎片、開箱進度、已領取的里程碑。
struct InventoryState: Codable, Equatable {
    var owned: Set<String> = []
    var loadout: Loadout = Loadout()
    var shards: Int = 0
    var boxesOpened: Int = 0
    var pity: Int = 0
    var claimedMilestones: Set<String> = []

    /// 初始狀態：沒有任何裝備，只穿內褲。基本款要從補給箱開。
    static func starter() -> InventoryState {
        InventoryState()
    }

    /// 舊版初始會送全套基本款。那時候開到基本款一定是重複、已換成碎片，
    /// 所以背包裡的基本款都是贈送的，收回並脫掉。
    mutating func removeStarterGift() {
        for it in GearCatalog.basicItems() {
            owned.remove(it.id)
            if loadout[it.slot] == it.id { loadout[it.slot] = nil }
        }
    }

    /// 舊版初始會把基本款全部穿上；還維持那個樣子（沒換過裝）的就脫掉。
    var isUntouchedOldStarter: Bool {
        let basics = GearCatalog.basicItems()
        return !basics.isEmpty && basics.allSatisfy { loadout[$0.slot] == $0.id }
            && loadout.slots.count == basics.count
    }
}

struct BoxResult {
    let item: GearItem
    let isNew: Bool
    let shards: Int
}

/// 里程碑用的統計。
struct MilestoneStats {
    var sessionCount: Int = 0
    var weekStreak: Int = 0
    var prCount: Int = 0

    static func compute(sessions: [WorkoutSession]) -> MilestoneStats {
        var stats = MilestoneStats()
        stats.sessionCount = sessions.count
        stats.weekStreak = Stats.weekStreak(sessions)

        var all: [SetEntry] = []
        for s in sessions { all.append(contentsOf: s.entries.filter(\.isWork)) }
        all.sort { a, b in
            if a.date != b.date { return a.date < b.date }
            return a.setIndex < b.setIndex
        }
        var best: [String: Double] = [:]
        var prs = 0
        for e in all {
            guard e.weight > 0 else { continue }
            guard let ex = ExerciseLibrary.byId(e.exerciseId), ex.loaded else { continue }
            if let prev = best[e.exerciseId] {
                if e.weight > prev {
                    prs += 1
                    best[e.exerciseId] = e.weight
                }
            } else {
                best[e.exerciseId] = e.weight
            }
        }
        stats.prCount = prs
        return stats
    }
}

struct Milestone: Identifiable {
    enum Kind {
        case sessions
        case streak
        case records
    }

    let id: String
    let itemId: String
    let kind: Kind
    let goal: Int

    var item: GearItem? { GearCatalog.item(itemId) }

    var title: String {
        guard let it = item else { return id }
        return "\(it.slot.name)・\(it.name)"
    }

    var condition: String {
        switch kind {
        case .sessions: return "累積 \(goal) 次訓練"
        case .streak: return "連續 \(goal) 週達標"
        case .records: return "破個人紀錄 \(goal) 次"
        }
    }

    func current(_ stats: MilestoneStats) -> Int {
        switch kind {
        case .sessions: return stats.sessionCount
        case .streak: return stats.weekStreak
        case .records: return stats.prCount
        }
    }

    func isMet(_ stats: MilestoneStats) -> Bool { current(stats) >= goal }

    func progressText(_ stats: MilestoneStats) -> String {
        "\(min(current(stats), goal)) / \(goal)"
    }

    func progress(_ stats: MilestoneStats) -> Double {
        guard goal > 0 else { return 1 }
        return min(1, Double(current(stats)) / Double(goal))
    }

    static let all: [Milestone] = [
        Milestone(id: "gold.fx", itemId: "gold.fx", kind: .sessions, goal: 10),
        Milestone(id: "gold.bottom", itemId: "gold.bottom", kind: .sessions, goal: 25),
        Milestone(id: "gold.top", itemId: "gold.top", kind: .sessions, goal: 50),
        Milestone(id: "gold.head", itemId: "gold.head", kind: .sessions, goal: 100),
        Milestone(id: "gold.feet", itemId: "gold.feet", kind: .streak, goal: 4),
        Milestone(id: "gold.back", itemId: "gold.back", kind: .streak, goal: 8),
        Milestone(id: "gold.hands", itemId: "gold.hands", kind: .records, goal: 10),
        Milestone(id: "gold.bell", itemId: "gold.bell", kind: .records, goal: 30)
    ]
}

final class InventoryStore: ObservableObject {
    static let key = "workout.character.inventory"

    @Published var state: InventoryState {
        didSet { save() }
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: InventoryStore.key),
           let data = raw.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(InventoryState.self, from: data) {
            var s = decoded
            // 一次性：舊的初始穿搭改成只穿內褲。
            let flag = "workout.character.nakedStart"
            if !UserDefaults.standard.bool(forKey: flag) {
                UserDefaults.standard.set(true, forKey: flag)
                if s.isUntouchedOldStarter { s.loadout = Loadout() }
            }
            // 一次性：收回舊版送的基本款。
            let giftFlag = "workout.character.noStarterGear"
            if !UserDefaults.standard.bool(forKey: giftFlag) {
                UserDefaults.standard.set(true, forKey: giftFlag)
                s.removeStarterGift()
            }
            state = s
        } else {
            UserDefaults.standard.set(true, forKey: "workout.character.nakedStart")
            UserDefaults.standard.set(true, forKey: "workout.character.noStarterGear")
            state = InventoryState.starter()
        }
    }

    /// 從完整備份匯入後重新讀（記憶體裡的舊狀態不然會在下次存檔時蓋掉匯入的）。
    func reload() {
        guard let raw = UserDefaults.standard.string(forKey: InventoryStore.key),
              let decoded = try? JSONDecoder().decode(InventoryState.self, from: Data(raw.utf8)) else {
            state = InventoryState.starter()
            return
        }
        state = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(state),
              let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: InventoryStore.key)
    }

    // MARK: 補給箱

    func boxesAvailable(sessionCount: Int) -> Int {
        max(0, sessionCount - state.boxesOpened)
    }

    /// 開一箱。沒有可開的箱子時回傳 nil。
    func openBox(sessionCount: Int) -> BoxResult? {
        guard boxesAvailable(sessionCount: sessionCount) > 0 else { return nil }

        var rarity: Int
        if state.pity >= 9 {
            rarity = Double.random(in: 0..<1) < 0.83 ? 3 : 4
        } else {
            let roll = Int.random(in: 1...100)
            if roll <= 60 { rarity = 1 }
            else if roll <= 88 { rarity = 2 }
            else if roll <= 98 { rarity = 3 }
            else { rarity = 4 }
        }

        var pool = GearCatalog.items.filter { $0.rarity.rawValue == rarity && !$0.isGold }
        if pool.isEmpty {
            rarity = 1
            pool = GearCatalog.items.filter { $0.rarity.rawValue == 1 && !$0.isGold }
        }

        var next = state
        next.boxesOpened += 1
        if rarity >= 3 { next.pity = 0 } else { next.pity += 1 }

        guard let item = pool.randomElement() else {
            state = next
            return nil
        }

        let result: BoxResult
        if next.owned.contains(item.id) {
            let gain = item.rarity.shardValue
            next.shards += gain
            result = BoxResult(item: item, isNew: false, shards: gain)
        } else {
            next.owned.insert(item.id)
            result = BoxResult(item: item, isNew: true, shards: 0)
        }
        state = next
        return result
    }

    // MARK: 穿戴

    func isOwned(_ item: GearItem) -> Bool { state.owned.contains(item.id) }

    func equip(_ item: GearItem) {
        guard state.owned.contains(item.id) else { return }
        state.loadout[item.slot] = item.id
    }

    func unequip(_ slot: GearSlot) {
        state.loadout.slots.removeValue(forKey: slot.rawValue)
    }

    func isEquipped(_ item: GearItem) -> Bool {
        state.loadout[item.slot] == item.id
    }

    // MARK: 碎片兌換

    func canExchange(_ item: GearItem) -> Bool {
        !item.isGold && !state.owned.contains(item.id) && state.shards >= item.rarity.exchangeCost
    }

    @discardableResult
    func exchange(_ item: GearItem) -> Bool {
        guard canExchange(item) else { return false }
        var next = state
        next.shards -= item.rarity.exchangeCost
        next.owned.insert(item.id)
        state = next
        return true
    }

    // MARK: 里程碑

    func isClaimed(_ m: Milestone) -> Bool { state.claimedMilestones.contains(m.id) }

    /// 領取（只解鎖，不自動穿上）。
    @discardableResult
    func claim(_ m: Milestone, stats: MilestoneStats) -> Bool {
        guard m.isMet(stats), !isClaimed(m), let it = m.item else { return false }
        var next = state
        next.claimedMilestones.insert(m.id)
        next.owned.insert(it.id)
        state = next
        return true
    }
}
