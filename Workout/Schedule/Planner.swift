import Foundation

struct BusyBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    let label: String
    let isWork: Bool
}

struct PlanOption {
    let length: WorkoutLength
    let start: Date
    let score: Double
}

struct DayPlan: Identifiable {
    let day: Date
    let busy: [BusyBlock]
    let option: PlanOption?
    let picked: Bool
    let done: Bool
    let reason: String

    var id: Date { day }
    var length: WorkoutLength? { picked ? option?.length : nil }
    var start: Date? { picked ? option?.start : nil }
}

/// Looks at classes and shifts, finds free time each day, and spreads the
/// weekly goal over the days with the most room.
enum Planner {
    static let fullNeeds = 75   // 60 分鐘 + 換衣服、喝水
    static let shortNeeds = 30

    static func makePlan(sessions: [WorkoutSession], now: Date = .now, horizon: Int = 7) -> [DayPlan] {
        let cfg = PlannerConfig.load()
        let classes = ClassStore.load()
        let shifts = ShiftReader.load().shifts
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        // Plan whole weeks so the weekly goal is spread properly.
        let lastShown = cal.date(byAdding: .day, value: horizon - 1, to: today)!
        let planEnd = cal.date(byAdding: .day, value: 7, to: SharedStore.weekStart(lastShown))!
        let events = EventStore.all(from: today, to: planEnd.addingTimeInterval(86400))
        let leaves = GoalStore.leaves()

        var evaluated: [(day: Date, busy: [BusyBlock], option: PlanOption?, tired: Bool)] = []
        var d = today
        while d < planEnd {
            var e = evaluate(day: d, now: now, cfg: cfg, classes: classes, shifts: shifts, events: events)
            // 請假的日子不排
            if let r = leaves[GoalStore.key(d)] {
                e.option = nil
                e.busy.insert(BusyBlock(start: d, end: d.addingTimeInterval(86400), label: "請假：\(r.title)", isWork: false), at: 0)
            }
            evaluated.append((d, e.busy, e.option, e.tired))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        let sessionDates = sessions.map(\.date)
        let trainedDays = Set(sessionDates.map { cal.startOfDay(for: $0) })
        var selected = Set<Date>()

        let weeks = Dictionary(grouping: evaluated) { SharedStore.weekStart($0.day) }
        for week in weeks.keys.sorted() {
            let doneThisWeek = sessionDates.filter { SharedStore.weekStart($0) == week }.count
            var remaining = cfg.goal - doneThisWeek
            let candidates = weeks[week]!
                .filter { !trainedDays.contains($0.day) && $0.option != nil }
                .sorted { a, b in
                    let sa = a.option!.score, sb = b.option!.score
                    return sa != sb ? sa > sb : a.day < b.day
                }
            // 內建 3 天全身：先挑前後一天都沒練的日子（全身每次都練到同樣的部位，中間要休一天），不夠再放寬
            let spread = BuiltInProgram.current == .fullBody3 && CustomPrograms.active == nil
            for strict in spread ? [true, false] : [false] {
                for c in candidates where remaining > 0 && !selected.contains(c.day) {
                    let taken = trainedDays.union(selected)
                    if threeInARow(c.day, with: taken) { continue }
                    if strict && nextToAny(c.day, in: taken) { continue }
                    selected.insert(c.day)
                    remaining -= 1
                }
            }
        }

        return evaluated.prefix(horizon).map { e in
            let done = trainedDays.contains(e.day)
            let picked = selected.contains(e.day)
            return DayPlan(day: e.day, busy: e.busy, option: e.option, picked: picked, done: done,
                           reason: reason(busy: e.busy, option: e.option, picked: picked, done: done, tired: e.tired))
        }
    }

    private static func nextToAny(_ day: Date, in set: Set<Date>) -> Bool {
        let cal = Calendar.current
        return set.contains(cal.date(byAdding: .day, value: -1, to: day)!)
            || set.contains(cal.date(byAdding: .day, value: 1, to: day)!)
    }

    private static func threeInARow(_ day: Date, with set: Set<Date>) -> Bool {
        let cal = Calendar.current
        func has(_ offset: Int) -> Bool { set.contains(cal.date(byAdding: .day, value: offset, to: day)!) }
        return (has(-2) && has(-1)) || (has(-1) && has(1)) || (has(1) && has(2))
    }

    private static func evaluate(day: Date, now: Date, cfg: PlannerConfig,
                                 classes: [ClassBlock], shifts: [WorkShift], events: [LifeEvent])
    -> (busy: [BusyBlock], option: PlanOption?, tired: Bool) {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: day)
        let dayEnd = day.addingTimeInterval(86400)
        func at(_ minutes: Int) -> Date { day.addingTimeInterval(TimeInterval(minutes * 60)) }

        var busy: [BusyBlock] = []
        var classMinutes = 0
        for c in classes where c.weekday == weekday {
            busy.append(BusyBlock(start: at(c.startMin - cfg.commuteSchool), end: at(c.endMin + cfg.commuteSchool),
                                  label: "上課 \(c.timeText)", isWork: false))
            classMinutes += c.endMin - c.startMin
        }
        var workMinutes = 0
        for s in shifts where s.start < at(cfg.latestHour * 60) && s.end > day {
            busy.append(BusyBlock(start: s.start.addingTimeInterval(TimeInterval(-cfg.commuteWork * 60)),
                                  end: s.end.addingTimeInterval(TimeInterval(cfg.commuteWork * 60)),
                                  label: "打工 \(TimeFmt.hm(s.start))–\(TimeFmt.hm(s.end))", isWork: true))
            if s.start >= day && s.start < dayEnd {
                workMinutes += Int(s.end.timeIntervalSince(s.start) / 60)
            }
        }
        let eventBuffer: TimeInterval = 15 * 60
        var allDayEvent = false
        for e in events where e.start < dayEnd && e.end > day {
            if e.allDay {
                allDayEvent = true
                busy.append(BusyBlock(start: day, end: dayEnd.addingTimeInterval(TimeInterval((cfg.latestHour - 24) * 3600)),
                                      label: "整天：\(e.displayTitle)", isWork: false))
                continue
            }
            let end = e.category == .drink ? at(cfg.latestHour * 60) : e.end.addingTimeInterval(eventBuffer)
            busy.append(BusyBlock(start: e.start.addingTimeInterval(-eventBuffer), end: end,
                                  label: "\(e.displayTitle) \(e.timeText)", isWork: e.category == .shoot))
            if e.category == .shoot {
                workMinutes += Int(e.end.timeIntervalSince(e.start) / 60)
            }
        }
        busy.sort { $0.start < $1.start }

        var lower = at(cfg.earliestHour * 60)
        if cal.isDate(day, inSameDayAs: now) {
            lower = max(lower, now.addingTimeInterval(10 * 60))
        }
        let upper = at(cfg.latestHour * 60)

        var windows: [(start: Date, end: Date)] = []
        var cursor = lower
        for b in busy {
            if b.start > cursor { windows.append((cursor, min(b.start, upper))) }
            cursor = max(cursor, b.end)
        }
        if cursor < upper { windows.append((cursor, upper)) }
        windows = windows.filter { $0.end.timeIntervalSince($0.start) >= Double(shortNeeds * 60) }

        let preferred = at(cfg.preferredHour * 60)
        func fit(_ minutes: Int) -> (start: Date, early: Bool)? {
            let need = TimeInterval(minutes * 60)
            for w in windows {
                let s = max(w.start, preferred)
                if s.addingTimeInterval(need) <= w.end { return (roundUp(s), false) }
            }
            for w in windows where w.start < preferred && w.start.addingTimeInterval(need) <= w.end {
                return (roundUp(w.start), true)
            }
            return nil
        }

        let tired = cfg.tiredHours > 0 && workMinutes >= cfg.tiredHours * 60
        let load = Double(classMinutes + workMinutes) / 600
        var option: PlanOption?
        if allDayEvent {
            option = nil
        } else if !tired, let f = fit(fullNeeds) {
            option = PlanOption(length: .full, start: f.start, score: 3 - (f.early ? 0.7 : 0) - load)
        } else if let s = fit(shortNeeds) {
            option = PlanOption(length: .short, start: s.start,
                                score: 1.5 - (s.early ? 0.5 : 0) - (tired ? 0.8 : 0) - load)
        }
        return (busy, option, tired)
    }

    /// Round to the next 5 minutes so suggested times look sane.
    private static func roundUp(_ date: Date) -> Date {
        let step = 300.0
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.up) * step)
    }

    private static func reason(busy: [BusyBlock], option: PlanOption?, picked: Bool, done: Bool, tired: Bool) -> String {
        if done { return "今天練完了 ✓" }
        let summary = busy.isEmpty ? "整天沒課沒班" : busy.map(\.label).joined(separator: "、")
        if picked {
            return tired ? "打工／拍片時間長，先排精簡版；精神好的話直接選完整版。\n\(summary)" : summary
        }
        if option == nil {
            return tired ? "打工／拍片時間長（\(summary)），建議休息" : "沒有空檔（\(summary)）"
        }
        return "這週已經排滿，當休息日"
    }
}
