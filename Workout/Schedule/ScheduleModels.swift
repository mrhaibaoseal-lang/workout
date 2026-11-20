import Foundation

// MARK: - 課表

struct ClassBlock: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Calendar weekday: 1 = 週日, 2 = 週一 … 7 = 週六
    var weekday: Int
    /// Minutes after midnight.
    var startMin: Int
    var endMin: Int
    var name: String
    var room: String = ""

    var timeText: String { "\(TimeFmt.hm(startMin))–\(TimeFmt.hm(endMin))" }
}

enum ClassStore {
    static let key = "classBlocks"

    /// 世新大學這學期的課表（依使用者提供的截圖）。
    static let seed: [ClassBlock] = [
        ClassBlock(weekday: 2, startMin: 610, endMin: 720, name: "電影技術專題（一）", room: "G503"),
        ClassBlock(weekday: 2, startMin: 790, endMin: 900, name: "傳播理論", room: "A201"),
        ClassBlock(weekday: 2, startMin: 910, endMin: 1020, name: "導演分析", room: "CB307"),
        ClassBlock(weekday: 3, startMin: 490, endMin: 600, name: "類型分析", room: "R402"),
        ClassBlock(weekday: 3, startMin: 610, endMin: 720, name: "電影劇本分析", room: "C318"),
        ClassBlock(weekday: 5, startMin: 910, endMin: 1020, name: "電影燈光設計", room: "G503, L101"),
        ClassBlock(weekday: 5, startMin: 1030, endMin: 1140, name: "電影史（一）", room: "R201"),
        ClassBlock(weekday: 6, startMin: 610, endMin: 720, name: "電影攝製實務", room: "J306"),
        ClassBlock(weekday: 6, startMin: 790, endMin: 900, name: "通識：電影文學", room: "R502"),
        ClassBlock(weekday: 6, startMin: 910, endMin: 1020, name: "通識：秒讚的文案", room: "R201"),
    ]

    static func decode(_ raw: String) -> [ClassBlock] {
        guard !raw.isEmpty, let data = raw.data(using: .utf8),
              let blocks = try? JSONDecoder().decode([ClassBlock].self, from: data) else { return seed }
        return blocks
    }

    static func encode(_ blocks: [ClassBlock]) -> String {
        guard let data = try? JSONEncoder().encode(blocks) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func load() -> [ClassBlock] {
        decode(UserDefaults.standard.string(forKey: key) ?? "")
    }
}

// MARK: - 班表（讀取「打工薪水帳」寫進 App Group 的資料）

struct WorkShift: Equatable {
    let start: Date
    let end: Date
    let name: String
}

enum ShiftReader {
    struct Result {
        var shifts: [WorkShift]
        var updatedAt: Date?
        var found: Bool
    }

    private struct ShiftFile: Decodable {
        let shifts: [String: Shift]
        struct Shift: Decodable {
            let name: String?
            let start: String?
            let end: String?
            let otMin: Int?
            let status: String?
            let leaveType: String?
        }
    }

    static func load() -> Result {
        let fm = FileManager.default
        for group in SharedStore.candidateGroups {
            guard let url = fm.containerURL(forSecurityApplicationGroupIdentifier: group)?
                .appendingPathComponent("shiftpay_state.json"),
                  let data = try? Data(contentsOf: url) else { continue }
            let updated = (try? fm.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
            guard let file = try? JSONDecoder().decode(ShiftFile.self, from: data) else {
                return Result(shifts: [], updatedAt: updated, found: true)
            }
            return Result(shifts: parse(file), updatedAt: updated, found: true)
        }
        return Result(shifts: [], updatedAt: nil, found: false)
    }

    private static func parse(_ file: ShiftFile) -> [WorkShift] {
        let cal = Calendar(identifier: .gregorian)
        return file.shifts.compactMap { key, s in
            // 無薪假（請假 + 整天請假）不用上班
            if s.status == "leave" && s.leaveType == "leave" { return nil }
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3,
                  let day = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
                  let startMin = TimeFmt.parse(s.start ?? ""),
                  let endMin = TimeFmt.parse(s.end ?? "") else { return nil }
            let start = day.addingTimeInterval(TimeInterval(startMin * 60))
            var end = day.addingTimeInterval(TimeInterval((endMin + max(0, s.otMin ?? 0)) * 60))
            if end <= start { end = end.addingTimeInterval(86400) }
            return WorkShift(start: start, end: end, name: s.name ?? "打工")
        }
        .sorted { $0.start < $1.start }
    }
}

// MARK: - 排程設定

struct PlannerConfig {
    var goal: Int
    var commuteSchool: Int
    var commuteWork: Int
    /// 可以開始練的最早時間（小時）
    var earliestHour: Int
    /// 偏好開始的時間（小時），早於這個時間的空檔會被扣分
    var preferredHour: Int
    /// 最晚結束時間（小時，可超過 24 表示隔天凌晨）
    var latestHour: Int
    /// 打工＋拍片超過幾小時就不排完整版（0 = 不限制）
    var tiredHours: Int

    static func load() -> PlannerConfig {
        let d = UserDefaults.standard
        func int(_ key: String, _ def: Int) -> Int { d.object(forKey: key) == nil ? def : d.integer(forKey: key) }
        return PlannerConfig(
            goal: int(Keys.weeklyGoal, 4),
            commuteSchool: int(Keys.commuteSchool, 15),
            commuteWork: int(Keys.commuteWork, 5),
            earliestHour: int(Keys.earliestHour, 12),
            preferredHour: int(Keys.preferredHour, 14),
            latestHour: int(Keys.latestHour, 25),
            tiredHours: int(Keys.tiredHours, 6)
        )
    }
}

enum TimeFmt {
    static func hm(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func hm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func parse(_ text: String) -> Int? {
        let p = text.replacingOccurrences(of: "：", with: ":").split(separator: ":").compactMap { Int($0) }
        guard p.count == 2, (0..<48).contains(p[0]), (0..<60).contains(p[1]) else { return nil }
        return p[0] * 60 + p[1]
    }

    static let weekdayShort = ["日", "一", "二", "三", "四", "五", "六"]

    static func weekday(_ date: Date) -> String {
        weekdayShort[Calendar.current.component(.weekday, from: date) - 1]
    }
}
