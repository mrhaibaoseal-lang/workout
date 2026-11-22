import Foundation

extension Keys {
    /// 每次訓練發了什麼（JSON [String: SessionGrants.Grant]，key = 訓練時間），刪除那筆紀錄時收回
    static let sessionGrants = "sessionGrants"
}

/// 練完發的東西有些不是從紀錄算出來的（碎片直接加進背包、動作升級記在 `Upgrade.store`），
/// 刪掉那筆紀錄也不會跟著消失：刪錯一筆升級退不回去，也能「練完 → 刪掉 → 再練」刷碎片（0.34.0）。
/// 練完時記下這次發了什麼，刪除時照記錄收回。牌位、補給箱數量是從紀錄算的，刪掉就自動重算，不用記。
enum SessionGrants {
    struct Grant: Codable, Equatable {
        var shards: Int = 0
        /// 這次記下的升級：原本的動作 id → 升級後的 id
        var upgrades: [String: String] = [:]

        var isEmpty: Bool { shards == 0 && upgrades.isEmpty }
    }

    /// 只留最近幾天的（更舊的紀錄刪掉就不收回）
    static let keepDays = 180

    static func key(_ date: Date) -> String { String(Int(date.timeIntervalSince1970.rounded())) }

    static func load() -> [String: Grant] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.sessionGrants),
              let d = try? JSONDecoder().decode([String: Grant].self, from: Data(raw.utf8)) else { return [:] }
        return d
    }

    private static func save(_ all: [String: Grant], now: Date = .now) {
        let cutoff = Int(now.timeIntervalSince1970) - keepDays * 86400
        let kept = all.filter { (Int($0.key) ?? 0) >= cutoff }
        guard let data = try? JSONEncoder().encode(kept), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.sessionGrants)
    }

    /// 練完存檔時記下。
    static func record(_ grant: Grant, for date: Date) {
        guard !grant.isEmpty else { return }
        var all = load()
        all[key(date)] = grant
        save(all)
    }

    /// 刪除紀錄時：拿出那次發的東西（並從清單移除）。沒有記錄回傳 nil。
    static func take(for date: Date) -> Grant? {
        var all = load()
        guard let g = all.removeValue(forKey: key(date)) else { return nil }
        save(all)
        return g
    }

    /// 收回升級：只收回現在還是這次記的那一條（之後又改過就不動）。純函式，給測試用。
    static func revertUpgrades(_ current: [String: String], granted: [String: String]) -> [String: String] {
        var out = current
        for (from, to) in granted where out[from] == to { out[from] = nil }
        return out
    }

    /// 刪除紀錄時呼叫：碎片扣回來（最少扣到 0）、升級退回。
    static func revoke(for date: Date, inventory: InventoryStore) {
        guard let g = take(for: date) else { return }
        if g.shards > 0 { inventory.state.shards = max(0, inventory.state.shards - g.shards) }
        if !g.upgrades.isEmpty {
            Upgrade.store.save(revertUpgrades(Upgrade.store.load(), granted: g.upgrades))
        }
    }
}
