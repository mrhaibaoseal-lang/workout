import Foundation

extension Keys {
    /// 停練暫停的週（JSON TrainingPause.Store）
    static let trainingPauses = "trainingPauses"
}

/// 停練時週數暫停（0.33.0）：停練 14 天以上，第一個 7 天照常算（當作休息週），之後每滿 7 天，程式週數就少走 1 週。
/// 區塊時鐘、減量週、區塊檢討、每週總結都從 `Stats.week` 和 `PersonalVolume.weekStart` 算週數，
/// 這兩個都會扣掉暫停的天數，所以停練期間區塊和減量週不往前走。
/// 暫停一律是 7 的倍數，所以「每週從星期幾開始」不會變。
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

    /// 停練前最後一次訓練是 last、到 now 為止還沒回來（或 now = 回來那天）：暫停哪一段。不夠長回傳 nil。
    static func pause(lastBefore last: Date, until now: Date) -> Pause? {
        let a = cal.startOfDay(for: last), b = cal.startOfDay(for: now)
        let gap = cal.dateComponents([.day], from: a, to: b).day ?? 0
        guard gap >= minGapDays else { return nil }
        let weeks = gap / 7 - 1
        guard weeks > 0, let from = cal.date(byAdding: .day, value: 7, to: a) else { return nil }
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

    /// 目前開始日的暫停（開始日改過就是空的）。
    static var current: [Pause] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.trainingPauses),
              let s = try? JSONDecoder().decode(Store.self, from: Data(raw.utf8)),
              abs(s.start - startRaw) < 1 else { return [] }
        return s.pauses
    }

    /// 停練偵測（`TrainingHistory.refresh`）後呼叫：記下或延長這次停練的暫停。同一次停練只有一筆。
    static func record(lastBefore: Date, returned: Date?, now: Date = .now) {
        guard startRaw > 0, lastBefore.timeIntervalSince1970 >= startRaw - 1,
              let p = pause(lastBefore: lastBefore, until: returned ?? now) else { return }
        var list = current.filter { $0.from != p.from }
        list.append(p)
        list.sort { $0.from < $1.from }
        let s = Store(start: startRaw, pauses: list)
        guard let data = try? JSONEncoder().encode(s), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.trainingPauses)
    }
}
