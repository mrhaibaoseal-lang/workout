import SwiftUI

extension Keys {
    /// 內建課表選哪一份：split4（4 天上下分化，預設）／fullBody3（3 天全身）
    static let builtInProgram = "builtInProgram"
    /// 這週答應併成全身日的天，JSON WeekFit.Accepted
    static let weekMerge = "weekMerge"
    /// 這週按過「不用」的週一（timeIntervalSince1970）
    static let weekMergeDismissed = "weekMergeDismissed"
}

/// 內建課表的兩種版本（0.25.0）。換的時候順便改每週目標，排程和提醒跟著改。
enum BuiltInProgram: String, CaseIterable, Identifiable {
    case split4, fullBody3

    var id: String { rawValue }

    static var current: BuiltInProgram {
        BuiltInProgram(rawValue: UserDefaults.standard.string(forKey: Keys.builtInProgram) ?? "") ?? .split4
    }

    var title: String {
        switch self {
        case .split4: "內建：上下半身分化"
        case .fullBody3: "內建：3 天全身"
        }
    }

    var detail: String {
        switch self {
        case .split4: "每週 4 天 · 每個部位一週 2 次"
        case .fullBody3: "每週 3 天 · 每個部位一週 3 次，每次少練幾組"
        }
    }

    /// 每週目標
    var goal: Int { self == .split4 ? 4 : 3 }

    /// 選這份內建課表：用內建（不用自訂）、每週目標改成這份的天數。
    func activate() {
        let d = UserDefaults.standard
        d.set(rawValue, forKey: Keys.builtInProgram)
        d.set("", forKey: Keys.activeProgram)
        d.set(goal, forKey: Keys.weeklyGoal)
    }
}

/// 這週天數不夠時，把課表剩下的幾天併成一天全身日（排課 6）。
/// 今天頁出卡片問，按了才併；下週從第一天重新開始（`ProgramBuilder.nextDay`）。
enum WeekFit {
    /// 全身日的 dayKey：「merge:」+ 併進來的天 id 用「+」接起來（舊紀錄靠它找回名字和部位）
    static let prefix = "merge:"
    /// 全身日最多幾個動作
    static let maxSlots = 9

    static func id(for ids: [String]) -> String { prefix + ids.joined(separator: "+") }

    /// 這筆紀錄練了課表的哪幾天（全身日拆開）
    static func parts(_ key: String) -> [String] {
        guard key.hasPrefix(prefix) else { return [key] }
        return key.dropFirst(prefix.count).split(separator: "+").map(String.init)
    }

    static func template(id: String) -> DayTemplate? {
        let days = parts(id).filter { !$0.hasPrefix(prefix) }.compactMap(ProgramBuilder.template(id:))
        return days.isEmpty ? nil : merged(days)
    }

    // MARK: 排全身日

    private static func primary(_ p: MovementPattern) -> [Muscle] {
        p.muscles.filter { $0.1 >= 1 }.map(\.0)
    }

    /// 小部位補動作的順序：先每週目標 10 組以上的，再小部位
    private static let fillOrder: [Muscle] = [.sideDelt, .biceps, .triceps, .rearDelt, .calves, .abs]

    /// 把幾天併成一天：
    /// 1. 依序取每天的重點動作，主要部位已經有動作練到就不重複。
    /// 2. 補其他動作裡、主要部位還沒練到的（側肩、二頭、三頭、後肩、小腿、腹肌的順序）。
    /// 每格組數 −1（至少 2 組；內建重點動作完整版還會 +1，所以大動作 3 組、小動作 2–3 組），最多 9 個動作。
    static func merged(_ days: [DayTemplate]) -> DayTemplate {
        var slots: [Slot] = []
        var covered = Set<Muscle>()
        var patterns = Set<MovementPattern>()

        func add(_ s: Slot, from day: DayTemplate) {
            var copy = Slot(pattern: s.pattern, sets: max(2, s.sets - 1), low: s.low, high: s.high,
                            essential: s.essential, keepBarbell: s.keepBarbell, exerciseId: s.exerciseId,
                            rest: s.rest)
            copy.source = day.id
            slots.append(copy)
            patterns.insert(s.pattern)
            covered.formUnion(primary(s.pattern))
        }

        for day in days {
            for s in day.slots where s.essential && !patterns.contains(s.pattern) {
                if primary(s.pattern).contains(where: { !covered.contains($0) }) { add(s, from: day) }
            }
        }
        var extras: [(Slot, DayTemplate)] = []
        for day in days {
            for s in day.slots where !s.essential && !patterns.contains(s.pattern)
                && !extras.contains(where: { $0.0.pattern == s.pattern }) {
                if primary(s.pattern).contains(where: { !covered.contains($0) }) { extras.append((s, day)) }
            }
        }
        func rank(_ s: Slot) -> Int {
            primary(s.pattern).compactMap { fillOrder.firstIndex(of: $0) }.min() ?? fillOrder.count
        }
        for (s, day) in extras.sorted(by: { rank($0.0) < rank($1.0) }) where slots.count < maxSlots {
            if primary(s.pattern).contains(where: { !covered.contains($0) }) { add(s, from: day) }
        }

        return DayTemplate(id: id(for: days.map(\.id)), name: "全身日",
                           focus: "併了" + days.map(\.name).joined(separator: "＋"),
                           custom: days.first?.custom ?? false, slots: Array(slots.prefix(maxSlots)))
    }

    // MARK: 這週

    private static func weekStart(_ d: Date) -> Date { SharedStore.weekStart(d) }

    /// 這週練過課表的哪幾天
    static func doneThisWeek(_ sessions: [WorkoutSession], now: Date = .now) -> Set<String> {
        let week = weekStart(now)
        return Set(sessions.filter { weekStart($0.date) == week }.flatMap { parts($0.dayKey) })
    }

    struct Accepted: Codable {
        var week: Double
        var ids: [String]
    }

    static func accepted() -> Accepted? {
        let raw = UserDefaults.standard.string(forKey: Keys.weekMerge) ?? ""
        return try? JSONDecoder().decode(Accepted.self, from: Data(raw.utf8))
    }

    /// 這週答應的全身日，還沒練、而且那幾天還在目前的課表裡才算。
    static func acceptedDay(sessions: [WorkoutSession], now: Date = .now) -> DayTemplate? {
        guard let a = accepted(), a.week == weekStart(now).timeIntervalSince1970 else { return nil }
        let done = doneThisWeek(sessions, now: now)
        let current = ProgramBuilder.days
        let days = a.ids.compactMap { id in current.first { $0.id == id } }
        guard days.count == a.ids.count, days.count >= 2, !days.contains(where: { done.contains($0.id) }) else { return nil }
        return merged(days)
    }

    struct Offer {
        /// 要併成今天全身日的天
        let merge: [DayTemplate]
        /// 這週還能練幾天（含今天）
        let available: Int
        /// 課表這週還剩幾天
        let remaining: Int
    }

    /// 今天還沒練、這週剩下能練的天數（今天 + 排程排到的日子）比課表剩下的天少，就建議把前面幾天併成今天的全身日。
    static func offer(sessions: [WorkoutSession], plans: [DayPlan], now: Date = .now) -> Offer? {
        let cal = Calendar.current
        if let last = sessions.first?.date, cal.isDateInToday(last) { return nil }
        let week = weekStart(now)
        let d = UserDefaults.standard
        if d.double(forKey: Keys.weekMergeDismissed) == week.timeIntervalSince1970 { return nil }
        if acceptedDay(sessions: sessions, now: now) != nil { return nil }
        let done = doneThisWeek(sessions, now: now)
        let remaining = ProgramBuilder.days.filter { !done.contains($0.id) }
        guard remaining.count >= 2 else { return nil }
        let today = cal.startOfDay(for: now)
        let future = plans.filter { $0.day > today && weekStart($0.day) == week && $0.picked && !$0.done }.count
        let available = 1 + future
        guard remaining.count > available else { return nil }
        let n = remaining.count - available + 1
        return Offer(merge: Array(remaining.prefix(n)), available: available, remaining: remaining.count)
    }

    static func accept(_ offer: Offer, now: Date = .now) {
        let a = Accepted(week: weekStart(now).timeIntervalSince1970, ids: offer.merge.map(\.id))
        if let data = try? JSONEncoder().encode(a), let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: Keys.weekMerge)
        }
    }

    /// 「不用」或「改回分開練」：這週不再問。
    static func dismiss(now: Date = .now) {
        let d = UserDefaults.standard
        d.set("", forKey: Keys.weekMerge)
        d.set(weekStart(now).timeIntervalSince1970, forKey: Keys.weekMergeDismissed)
    }
}

/// 今天頁：這週天數不夠，問要不要併成全身日。
struct MergeDayCard: View {
    let offer: WeekFit.Offer
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("這週天數不夠", systemImage: "rectangle.stack.badge.plus")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                InfoTip(item: .mergeDay)
            }
            Text("這週還能練 \(offer.available) 天（含今天），課表還剩 \(offer.remaining) 天。把「\(offer.merge.map(\.name).joined(separator: "」＋「"))」併成今天的全身日，每個部位這週都練得到。")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    Text("併成全身日")
                }
                .buttonStyle(HotButtonStyle(height: 44))
                Button(action: onDismiss) {
                    Text("不用").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
                .frame(maxWidth: 110)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accentDim, lineWidth: 1))
    }
}
