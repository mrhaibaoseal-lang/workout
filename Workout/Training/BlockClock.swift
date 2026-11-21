import Foundation

extension Keys {
    /// 每個區塊的減量週改到第幾週（提早或延後），JSON BlockClock.Store
    static let deloadOverrides = "deloadOverrides"
    /// 「再撐一週」「照原本減量」按過的那一週（程式週數）；同一週不再問
    static let deloadAskedWeek = "deloadAskedWeek"
}

/// 區塊（0.26.0）：一個區塊 = 幾個進步週 + 最後 1 週減量，減量週過後換一批單關節動作。
/// 預設 6 週一個區塊（和 0.25.0 以前一樣）；疲勞高可以提早減量，狀態好可以延後（最長 8 週）。
/// 改過的減量週存成「第幾個區塊 → 第幾週減量」，所以過去的週也算得回來（區塊檢討、每週總結要用）。
enum BlockClock {
    /// 預設一個區塊幾週（含減量週）
    static let defaultWeeks = 6
    /// 一個區塊最長幾週（延後最多 2 週）
    static let maxWeeks = 8
    /// 至少要有幾個進步週，才能提早減量
    static let minNormalWeeks = 3

    struct Location: Equatable {
        /// 第幾個區塊（0 起算）
        let block: Int
        /// 區塊第一週（程式週數，1 起算）
        let start: Int
        /// 這個區塊的減量週
        let deload: Int
        /// 這個區塊原本（沒改過）的減量週
        let planned: Int

        /// 這週是區塊的第幾週（1 起算）
        func weekInBlock(_ week: Int) -> Int { week - start + 1 }
        /// 最早可以提早減量的那週：至少 3 個進步週之後（第一個區塊前兩週是適應期，不算）
        var earliestEarly: Int { max(start, 3) + minNormalWeeks }
        /// 最晚可以延到哪一週
        var latest: Int { start + maxWeeks - 1 }
    }

    private struct Store: Codable {
        /// 這些改動是哪一次開始日的（「從第 1 週重新開始」後舊的改動不算）
        var start: Double
        /// 區塊 → 減量週
        var at: [String: Int]
    }

    private static var defaults: UserDefaults { .standard }

    private static var startRaw: Double { defaults.double(forKey: Keys.startDate) }

    private static func overrides() -> [Int: Int] {
        guard let raw = defaults.string(forKey: Keys.deloadOverrides),
              let s = try? JSONDecoder().decode(Store.self, from: Data(raw.utf8)),
              abs(s.start - startRaw) < 1 else { return [:] }
        var out: [Int: Int] = [:]
        for (k, v) in s.at { if let b = Int(k) { out[b] = v } }
        return out
    }

    private static func save(_ dict: [Int: Int]) {
        let s = Store(start: startRaw, at: Dictionary(uniqueKeysWithValues: dict.map { (String($0.key), $0.value) }))
        guard let data = try? JSONEncoder().encode(s), let raw = String(data: data, encoding: .utf8) else { return }
        defaults.set(raw, forKey: Keys.deloadOverrides)
    }

    /// 第 week 週在哪個區塊。
    static func locate(week: Int) -> Location {
        locate(week: week, overrides: overrides())
    }

    static func locate(week: Int, overrides: [Int: Int]) -> Location {
        var block = 0
        var start = 1
        while true {
            let planned = start + defaultWeeks - 1
            var deload = planned
            if let o = overrides[block] {
                let earliest = max(start, 3) + minNormalWeeks
                deload = min(start + maxWeeks - 1, max(min(earliest, planned), o))
            }
            if week <= deload || block > 500 {
                return Location(block: block, start: start, deload: deload, planned: planned)
            }
            block += 1
            start = deload + 1
        }
    }

    /// 這週提早減量（目前區塊的減量週改成這週）。
    static func deloadNow(week: Int) {
        let loc = locate(week: week)
        var o = overrides()
        o[loc.block] = week
        save(o)
        defaults.set(week, forKey: Keys.deloadAskedWeek)
    }

    /// 減量週往後延 1 週（區塊最長 8 週）。
    @discardableResult
    static func postpone(week: Int) -> Bool {
        let loc = locate(week: week)
        guard loc.deload == week, week + 1 <= loc.latest else { return false }
        var o = overrides()
        o[loc.block] = week + 1
        save(o)
        defaults.set(week, forKey: Keys.deloadAskedWeek)
        return true
    }

    /// 這週問過了（按了「再撐一週」或「照原本減量」）。
    static func markAsked(week: Int) {
        defaults.set(week, forKey: Keys.deloadAskedWeek)
    }

    static func asked(week: Int) -> Bool {
        defaults.integer(forKey: Keys.deloadAskedWeek) == week
    }

    /// 這週所在區塊之前，最近一次減量週是第幾週；還沒減量過是 nil。
    static func lastDeload(before week: Int) -> Int? {
        let loc = locate(week: week)
        return loc.block == 0 ? nil : loc.start - 1
    }
}
