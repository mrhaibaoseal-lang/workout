import Foundation

extension Keys {
    /// 停練暫停的週（JSON TrainingPause.Store）
    static let trainingPauses = "trainingPauses"
}

/// 停練時週數暫停（0.33.0，0.33.1 修正）：停練滿 14 天起，程式週數停住不走（前 14 天照常算，當作休息）。
/// 區塊時鐘、減量週、區塊檢討、每週總結都從 `Stats.week` 和 `PersonalVolume.weekStart` 算週數，
/// 這兩個都會扣掉暫停的天數，所以停練期間區塊和減量週不往前走。
/// 暫停一律是 7 的倍數，所以「每週從星期幾開始」不會變。
/// - 暫停從停練第 14 天開始，不回頭扣已經走過的天數：週數不會往回跳。
/// - 還沒回來時，暫停涵蓋到目前這一週的結尾，所以週數一直停住（0.33.0 是無條件捨去，週數會在兩週之間來回跳）。
/// - 回來時取進位：回來後週數再停到原本的週界才繼續走，前後連續。
enum TrainingPause {
    /// 停練幾天以上才暫停
    static let minGapDays = 14

    struct Pause: Codable, Equatable {
        /// 暫停開始那天（startOfDay 的 timeIntervalSince1970）
        var from: Double
        /// 暫停幾天（7 的倍數）
        var days: Int
    }

    private struct Store: Codable {
        /// 這些暫停是哪一次開始日的（「從第 1 週重新開始」後舊的不算）
        var start: Double
        var pauses: [Pause]
    }

    private static var cal: Calendar { Stats.calendar }

    /// 停練前最後一次訓練是 last、到 until 為止。ongoing = 還沒回來（until 是今天）；否則 until 是回來那天。
    /// 不夠長回傳 nil。
    static func pause(lastBefore last: Date, until: Date, ongoing: Bool) -> Pause? {
        let a = cal.startOfDay(for: last), b = cal.startOfDay(for: until)
        let gap = cal.dateComponents([.day], from: a, to: b).day ?? 0
        guard gap >= minGapDays, let from = cal.date(byAdding: .day, value: minGapDays, to: a) else { return nil }
        let over = gap - minGapDays
        // 還沒回來：蓋到這一週結尾（之後每天重算會再延長）；回來了：進位到 7 的倍數
        let weeks = ongoing ? over / 7 + 1 : (over + 6) / 7
        guard weeks > 0 else { return nil }
        return Pause(from: from.timeIntervalSince1970, days: weeks * 7)
    }

    /// 到 date 為止暫停了幾天（暫停中的那段只算到 date）。
    static func pausedDays(before date: Date, pauses: [Pause]) -> Int {
        let d = cal.startOfDay(for: date)
        var total = 0
        for p in pauses {
            let from = Date(timeIntervalSince1970: p.from)
            let into = cal.dateComponents([.day], from: from, to: d).day ?? 0
            total += min(max(into, 0), p.days)
        }
        return total
    }

    /// 程式第幾週（扣掉暫停）。
    static func week(since start: Date, at date: Date, pauses: [Pause]) -> Int {
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)).day ?? 0
        let active = days - pausedDays(before: date, pauses: pauses)
        return max(1, active / 7 + 1)
    }

    /// 第 n 週開始的那天（加回在它之前的暫停）。
    static func weekStart(_ n: Int, start: Date, pauses: [Pause]) -> Date {
        var d = cal.date(byAdding: .day, value: (n - 1) * 7, to: cal.startOfDay(for: start)) ?? start
        for p in pauses.sorted(by: { $0.from < $1.from }) where p.from < d.timeIntervalSince1970 - 1 {
            d = cal.date(byAdding: .day, value: p.days, to: d) ?? d
        }
        return d
    }

    // MARK: 存取

    private static var startRaw: Double { UserDefaults.standard.double(forKey: Keys.startDate) }

    /// 上次解碼的原始字串和結果：`Stats.week` 在很多畫面的 body 裡呼叫，字串沒變就不重新解 JSON。
    private static var cache: (raw: String, store: Store?)?

    private static func loadStore() -> Store? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.trainingPauses) else { return nil }
        if let c = cache, c.raw == raw { return c.store }
        let s = try? JSONDecoder().decode(Store.self, from: Data(raw.utf8))
        cache = (raw, s)
        return s
    }

    /// 目前開始日的暫停（開始日改過就是空的）。
    static var current: [Pause] {
        guard let s = loadStore(), abs(s.start - startRaw) < 1 else { return [] }
        return s.pauses
    }

    /// 停練偵測（`TrainingHistory.refresh`）後呼叫：記下或延長這次停練的暫停。同一次停練只有一筆。
    static func record(lastBefore: Date, returned: Date?, now: Date = .now) {
        guard startRaw > 0, lastBefore.timeIntervalSince1970 >= startRaw - 1,
              let p = pause(lastBefore: lastBefore, until: returned ?? now, ongoing: returned == nil) else { return }
        // 同一次停練的舊紀錄（包括 0.33.0 從第 7 天開始算的）換掉
        let a = cal.startOfDay(for: lastBefore).timeIntervalSince1970
        var list = current.filter { !($0.from > a && $0.from <= p.from) }
        list.append(p)
        list.sort { $0.from < $1.from }
        let s = Store(start: startRaw, pauses: list)
        guard let data = try? JSONEncoder().encode(s), let raw = String(data: data, encoding: .utf8) else { return }
        guard raw != UserDefaults.standard.string(forKey: Keys.trainingPauses) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.trainingPauses)
    }
}
