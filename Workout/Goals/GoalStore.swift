import Foundation

/// 一天的排程紀錄：那天有沒有排練、是不是整天有活動。
/// 每次開 App 重記今天和之後的日子，過去的日子固定不變。
struct DayLog: Codable, Equatable {
    var planned: Bool
    var allDay: Bool
}

enum LeaveReason: String, CaseIterable, Identifiable, Codable {
    case sick, injury, tired, travel, busy, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sick: "生病"
        case .injury: "受傷／痠痛"
        case .tired: "太累"
        case .travel: "出遠門"
        case .busy: "臨時有事"
        case .other: "其他"
        }
    }

    var icon: String {
        switch self {
        case .sick: "thermometer.medium"
        case .injury: "bandage.fill"
        case .tired: "bed.double.fill"
        case .travel: "airplane"
        case .busy: "briefcase.fill"
        case .other: "ellipsis.circle.fill"
        }
    }
}

/// 押注：押某一週會練滿週目標。
struct Bet: Codable, Identifiable, Equatable {
    var id = UUID()
    /// 那一週的週一 0 點
    var week: Date
    var stake: Int
    var placedAt: Date
    /// 已經結算、碎片已經入帳
    var paid = false
}

/// 選手模式搬過來的那幾個機制要另外存的資料。其他都從訓練紀錄重算。
enum GoalStore {
    private static var d: UserDefaults { .standard }

    // MARK: 啟用日

    /// 這版第一次開啟的時間。新規則（請假、保護卡、週任務、逆轉、押注）只從這一週開始算，
    /// 以前的週維持舊規則，牌位分數不會被回頭改掉。
    static func ensureSince() {
        if d.object(forKey: Keys.goalsSince) == nil {
            d.set(Date().timeIntervalSince1970, forKey: Keys.goalsSince)
        }
    }

    static var sinceWeek: Date {
        let t = d.double(forKey: Keys.goalsSince)
        return SharedStore.weekStart(t > 0 ? Date(timeIntervalSince1970: t) : .now)
    }

    // MARK: 日期 key

    static func key(_ day: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func day(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }

    // MARK: JSON

    static func decode<T: Decodable>(_ type: T.Type, _ raw: String) -> T? {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func string(_ key: String) -> String { d.string(forKey: key) ?? "" }

    // MARK: 請假

    static func leaves(_ raw: String? = nil) -> [String: LeaveReason] {
        decode([String: LeaveReason].self, raw ?? string(Keys.leaves)) ?? [:]
    }

    static func setLeave(_ day: Date, _ reason: LeaveReason?) {
        var all = leaves()
        all[key(day)] = reason
        d.set(encode(all), forKey: Keys.leaves)
    }

    // MARK: 排程紀錄

    static func planLog(_ raw: String? = nil) -> [String: DayLog] {
        decode([String: DayLog].self, raw ?? string(Keys.planLog)) ?? [:]
    }

    /// 把今天和之後的排程記下來（覆蓋），已經過去的日子不動。
    static func record(_ plans: [DayPlan]) {
        let today = Calendar.current.startOfDay(for: .now)
        var log = planLog()
        let before = log
        for p in plans where p.day >= today {
            let allDay = p.busy.contains { $0.label.hasPrefix("整天") }
            log[key(p.day)] = DayLog(planned: p.picked || p.done, allDay: allDay)
        }
        // 只留最近一年
        let cutoff = key(Calendar.current.date(byAdding: .day, value: -400, to: today)!)
        log = log.filter { $0.key >= cutoff }
        if log != before { d.set(encode(log), forKey: Keys.planLog) }
    }

    // MARK: 保護卡（買的）

    static func shieldBuys(_ raw: String? = nil) -> [Date] {
        (decode([Double].self, raw ?? string(Keys.shieldBuys)) ?? []).map(Date.init(timeIntervalSince1970:))
    }

    static func addShieldBuy(_ date: Date = .now) {
        let list = shieldBuys() + [date]
        d.set(encode(list.map(\.timeIntervalSince1970)), forKey: Keys.shieldBuys)
    }

    // MARK: 押注

    static func bets(_ raw: String? = nil) -> [Bet] {
        decode([Bet].self, raw ?? string(Keys.bets)) ?? []
    }

    static func saveBets(_ list: [Bet]) {
        d.set(encode(list), forKey: Keys.bets)
    }
}

/// 引擎計算時用的一份快照。
struct GoalContext {
    var since: Date
    var leaves: [String: LeaveReason]
    var log: [String: DayLog]
    var shieldBuys: [Date]
    var bets: [Bet]

    static func load() -> GoalContext {
        GoalContext(since: GoalStore.sinceWeek, leaves: GoalStore.leaves(), log: GoalStore.planLog(),
                    shieldBuys: GoalStore.shieldBuys(), bets: GoalStore.bets())
    }

    func leave(_ day: Date) -> LeaveReason? { leaves[GoalStore.key(day)] }

    /// 請假或整天有活動：這天不算可以練的日子。
    func excused(_ day: Date) -> Bool {
        let k = GoalStore.key(day)
        return leaves[k] != nil || log[k]?.allDay == true
    }

    /// nil = 沒有那天的排程紀錄（裝這版以前）。
    func planned(_ day: Date) -> Bool? {
        log[GoalStore.key(day)]?.planned
    }

    var hasLog: Bool { !log.isEmpty }
}
