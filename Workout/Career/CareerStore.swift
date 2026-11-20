import Foundation

/// What the planner said about one day, frozen once the day has passed.
struct PlanLogEntry: Codable, Equatable {
    var picked: Bool
    var excused: Bool
}

enum LeaveReason: String, Codable, CaseIterable, Identifiable {
    case sick, injury, exam, family, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sick: "生病"
        case .injury: "受傷"
        case .exam: "考試／報告"
        case .family: "家裡有事"
        case .other: "其他"
        }
    }
}

struct LeaveDay: Codable, Identifiable, Equatable {
    var day: Date
    var reason: LeaveReason
    var id: Date { day }
}

struct Bet: Codable, Identifiable, Equatable {
    var weekStart: Date
    var stake: Int
    var id: Date { weekStart }
}

/// Everything the career engine needs that isn't in the workout history.
/// Stored as JSON strings so views can watch them with @AppStorage.
enum CareerStore {
    static let planLogKey = "careerPlanLog"
    static let leaveKey = "careerLeave"
    static let betKey = "careerBets"
    static let cardBuyKey = "careerCardBuys"
    static let equippedKey = "careerEquipped"
    static let nameKey = "careerName"
    static let nicknameKey = "careerNickname"

    static var cal: Calendar { SharedStore.calendar }
    private static var defaults: UserDefaults { .standard }

    private static func read<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let raw = defaults.string(forKey: key), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value),
              let raw = String(data: data, encoding: .utf8) else { return }
        defaults.set(raw, forKey: key)
    }

    static func dayKey(_ date: Date) -> String {
        String(Int(cal.startOfDay(for: date).timeIntervalSince1970))
    }

    // MARK: Plan log

    static func planLog() -> [Date: PlanLogEntry] {
        let raw = read(planLogKey, as: [String: PlanLogEntry].self) ?? [:]
        var out: [Date: PlanLogEntry] = [:]
        for (k, v) in raw {
            if let t = Double(k) { out[Date(timeIntervalSince1970: t)] = v }
        }
        return out
    }

    /// Record today's and future days' plans. Past days are never touched.
    /// `plans` should come from `Planner.makePlan(sessions:now:)` with `now` = start of today,
    /// so the time of day doesn't make today look unplanned.
    static func record(plans: [DayPlan], now: Date = .now) {
        var raw = read(planLogKey, as: [String: PlanLogEntry].self) ?? [:]
        let today = cal.startOfDay(for: now)
        guard let last = plans.last?.day else { return }
        let events = EventStore.all(from: today, to: last.addingTimeInterval(86400))
        for p in plans where p.day >= today {
            let key = dayKey(p.day)
            let dayEnd = p.day.addingTimeInterval(86400)
            let allDay = events.contains { $0.allDay && $0.start < dayEnd && $0.end > p.day }
            var picked = p.picked
            // Once trained, the planner stops "picking" the day; keep what it said before.
            if p.done, let old = raw[key] { picked = old.picked }
            raw[key] = PlanLogEntry(picked: picked, excused: allDay)
        }
        // Keep about a year and a half.
        let cutoff = today.addingTimeInterval(-550 * 86400).timeIntervalSince1970
        raw = raw.filter { (Double($0.key) ?? 0) >= cutoff }
        write(raw, planLogKey)
    }

    // MARK: Leave

    static func leaves() -> [LeaveDay] {
        read(leaveKey, as: [LeaveDay].self) ?? []
    }

    static func addLeave(_ day: Date, reason: LeaveReason) {
        let start = cal.startOfDay(for: day)
        var list = leaves().filter { $0.day != start }
        list.append(LeaveDay(day: start, reason: reason))
        write(list.sorted { $0.day < $1.day }, leaveKey)
    }

    static func removeLeave(_ day: Date) {
        let start = cal.startOfDay(for: day)
        write(leaves().filter { $0.day != start }, leaveKey)
    }

    // MARK: Bets

    static func bets() -> [Bet] {
        read(betKey, as: [Bet].self) ?? []
    }

    static func placeBet(weekStart: Date, stake: Int) {
        var list = bets().filter { $0.weekStart != weekStart }
        list.append(Bet(weekStart: weekStart, stake: stake))
        write(list.sorted { $0.weekStart < $1.weekStart }, betKey)
    }

    static func cancelBet(weekStart: Date) {
        write(bets().filter { $0.weekStart != weekStart }, betKey)
    }

    // MARK: Protection card purchases

    static func cardBuys() -> [Date] {
        read(cardBuyKey, as: [Date].self) ?? []
    }

    static func buyCard(now: Date = .now) {
        write(cardBuys() + [now], cardBuyKey)
    }

    // MARK: Equipped cosmetics

    static func equipped() -> [GearSlot: String] {
        let raw = read(equippedKey, as: [String: String].self) ?? [:]
        var out: [GearSlot: String] = [:]
        for (k, v) in raw {
            if let slot = GearSlot(rawValue: k) { out[slot] = v }
        }
        return out
    }

    static func equip(_ item: Cosmetic) {
        var raw = read(equippedKey, as: [String: String].self) ?? [:]
        raw[item.slot.rawValue] = item.id
        write(raw, equippedKey)
    }
}
