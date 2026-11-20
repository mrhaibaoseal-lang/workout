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
    }

    static func save(_ s: Snapshot) {
        let d = defaults
        d.set(s.sessionDates.prefix(200).map(\.timeIntervalSince1970), forKey: key("sessionDates"))
        d.set(s.goal, forKey: key("goal"))
        d.set(s.nextDay, forKey: key("nextDay"))
    }

    static func load() -> Snapshot {
        let d = defaults
        let dates = (d.array(forKey: key("sessionDates")) as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
        let goal = d.integer(forKey: key("goal"))
        return Snapshot(sessionDates: dates,
                        goal: goal == 0 ? 4 : goal,
                        nextDay: d.string(forKey: key("nextDay")) ?? "上半身 A")
    }

    // MARK: - Week math (Monday-first weeks)

    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        return cal
    }()

    static func weekStart(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func countThisWeek(_ dates: [Date], now: Date = .now) -> Int {
        let start = weekStart(now)
        return dates.filter { $0 >= start }.count
    }

    /// Consecutive weeks (ending this week or last week) with at least `minPerWeek` sessions.
    static func weekStreak(_ dates: [Date], minPerWeek: Int = 2, now: Date = .now) -> Int {
        var counts: [Date: Int] = [:]
        for d in dates { counts[weekStart(d), default: 0] += 1 }

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

    static func trainedToday(_ dates: [Date], now: Date = .now) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: now) }
    }
}
