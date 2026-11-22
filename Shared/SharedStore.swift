import Foundation

/// Data shared between the app and the home-screen widget through an App Group.
enum SharedStore {
    /// The FlareStore profile only grants these fixed App Group IDs, so pick the
    /// first one this signed build can actually open. The bundle's own group is a
    /// fallback for other certificates.
    static let candidateGroups = (1...5).map { "group.81c139ae9a27a7f8.\($0)" } + ["group.com.mrhaibaoseal.workout"]

    static let groupId: String? = candidateGroups.first {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) != nil
    }

    private static var defaults: UserDefaults {
        groupId.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// Other apps signed with the same certificate may share the group, so prefix keys.
    private static func key(_ name: String) -> String { "workout." + name }

    struct Snapshot {
        var sessionDates: [Date]
        var goal: Int
        var nextDay: String
        /// App 算好的連續週數（含請假、保護卡）；小工具在同一週內優先用它。
        var streak: Int? = nil
        var streakWeek: Date? = nil
    }

    static func save(_ s: Snapshot) {
        let d = defaults
        d.set(s.sessionDates.prefix(200).map(\.timeIntervalSince1970), forKey: key("sessionDates"))
        d.set(s.goal, forKey: key("goal"))
        d.set(s.nextDay, forKey: key("nextDay"))
        if let n = s.streak, let w = s.streakWeek {
            d.set(n, forKey: key("streak"))
            d.set(w.timeIntervalSince1970, forKey: key("streakWeek"))
        }
    }

    static func load() -> Snapshot {
        let d = defaults
        let dates = (d.array(forKey: key("sessionDates")) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
        let goal = d.integer(forKey: key("goal"))
        let week = d.double(forKey: key("streakWeek"))
        return Snapshot(sessionDates: dates,
                        goal: goal == 0 ? 4 : goal,
                        nextDay: d.string(forKey: key("nextDay")) ?? "上半身 A",
                        streak: d.object(forKey: key("streak")) == nil ? nil : d.integer(forKey: key("streak")),
                        streakWeek: week > 0 ? Date(timeIntervalSince1970: week) : nil)
    }

    // MARK: - Week math (Monday-first weeks)

    /// 每次都用目前的時區（`static let` 會停在第一次用的時區，出國後日期邊界會偏）。
    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal
    }

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func countThisWeek(_ dates: [Date], now: Date = .now) -> Int {
        let start = weekStart(now)
        return trainingDays(dates.filter { $0 >= start })
    }

    /// 練了幾天（同一天練兩次算 1 天：週目標算的是天數，不能一天練兩次湊數）。
    static func trainingDays(_ dates: [Date]) -> Int {
        Set(dates.map { calendar.startOfDay(for: $0) }).count
    }

    /// Consecutive weeks (ending this week or last week) with at least `minPerWeek` training days.
    /// 算天數不算次數：同一天練兩次算 1 天，和 `trainingDays`、App 裡的週目標一致。
    static func weekStreak(_ dates: [Date], minPerWeek: Int = 2, now: Date = .now) -> Int {
        var counts: [Date: Int] = [:]
        for day in Set(dates.map { calendar.startOfDay(for: $0) }) { counts[weekStart(day), default: 0] += 1 }

        var week = weekStart(now)
        if (counts[week] ?? 0) < minPerWeek {
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        var streak = 0
        while (counts[week] ?? 0) >= minPerWeek {
            streak += 1
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        return streak
    }

    /// 小工具用：同一週內用 App 算好的值（含請假、保護卡），換週了就自己算。
    static func streak(_ s: Snapshot, now: Date = .now) -> Int {
        let computed = weekStreak(s.sessionDates, now: now)
        if let n = s.streak, let w = s.streakWeek, w == weekStart(now) { return max(n, computed) }
        return computed
    }

    static func trainedToday(_ dates: [Date], now: Date = .now) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: now) }
    }
}
