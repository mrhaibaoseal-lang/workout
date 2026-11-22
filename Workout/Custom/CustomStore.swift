import Foundation

// MARK: - 自訂動作

/// 使用者自己加的動作。id 一律 `custom_` 開頭，建立後不改（紀錄、PR、備註都用 id 存）。
/// 刪除只設 hidden：舊紀錄還要查得到名字。
struct CustomExercise: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// MovementPattern.rawValue：決定部位熱圖、熱身、自動挑動作時算哪一類
    var pattern: String
    /// Equipment.rawValue；空的 = 徒手
    var requires: [String]
    var loaded: Bool
    /// RepUnit.rawValue
    var unit: String
    /// 都有值 = 固定次數範圍；nil = 照課表那一格的範圍
    var low: Int?
    var high: Int?
    var tip: String
    var hidden: Bool

    static func blank() -> CustomExercise {
        CustomExercise(id: CustomExercises.newId(), name: "", pattern: MovementPattern.hPush.rawValue,
                       requires: [Equipment.dumbbell.rawValue], loaded: true, unit: RepUnit.reps.rawValue,
                       low: nil, high: nil, tip: "", hidden: false)
    }

    var movement: MovementPattern { MovementPattern(rawValue: pattern) ?? .core }
    var repUnit: RepUnit { RepUnit(rawValue: unit) ?? .reps }
    var equipment: Set<Equipment> { Set(requires.compactMap(Equipment.init(rawValue:))) }

    var exercise: Exercise {
        var range: ClosedRange<Int>? = nil
        if let low, let high, low >= 1, high >= low { range = low...high }
        let trimmed = tip.trimmingCharacters(in: .whitespacesAndNewlines)
        return Exercise(id: id, name: name.isEmpty ? "自訂動作" : name, pattern: movement, requires: equipment,
                        loaded: loaded, unit: repUnit, range: range,
                        tip: trimmed.isEmpty ? "自訂動作" : trimmed)
    }
}

enum CustomExercises {
    static let idPrefix = "custom_"

    private static var cacheRaw: String?
    private static var cache: [CustomExercise] = []

    /// 全部（含已刪除）。UserDefaults 的字串沒變就用快取，不用每次解 JSON。
    static func load() -> [CustomExercise] {
        let raw = UserDefaults.standard.string(forKey: Keys.customExercises) ?? ""
        if raw == cacheRaw { return cache }
        cacheRaw = raw
        cache = (try? JSONDecoder().decode([CustomExercise].self, from: Data(raw.utf8))) ?? []
        return cache
    }

    static func save(_ list: [CustomExercise]) {
        guard let data = try? JSONEncoder().encode(list), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.customExercises)
    }

    static func upsert(_ item: CustomExercise) {
        var list = load()
        if let i = list.firstIndex(where: { $0.id == item.id }) { list[i] = item } else { list.append(item) }
        save(list)
    }

    static func hide(_ id: String) {
        var list = load()
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].hidden = true
        save(list)
    }

    static var visible: [Exercise] {
        load().filter { !$0.hidden }.map(\.exercise)
    }

    static func isHidden(_ id: String) -> Bool {
        load().first { $0.id == id }?.hidden ?? false
    }

    /// 設定「自動挑動作時也排自訂動作」，預設關。
    static var inAutoPick: Bool {
        UserDefaults.standard.bool(forKey: Keys.customInAutoPick)
    }

    static func newId() -> String {
        idPrefix + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
    }
}

// MARK: - 自訂課表

/// 課表裡的一格：指定動作（exerciseId）或只指定動作類型（自動挑）。
struct CustomSlot: Codable, Identifiable, Equatable {
    var id: String
    var pattern: String
    var exerciseId: String?
    var sets: Int
    var low: Int
    var high: Int
    /// 休息秒數（完整版用；精簡版最多 60 秒）
    var rest: Int
    /// 精簡 20 分、只做 1 組也要做
    var essential: Bool
    /// 從內建課表複製來的臀推位置：「少排槓鈴」時仍用槓鈴。畫面上不顯示。
    var keepBarbell: Bool
    /// 和上一個動作連成超級組／循環組（舊資料沒有這欄 = nil）
    var linkPrev: Bool? = nil

    static func blank(pattern: MovementPattern = .hPush) -> CustomSlot {
        CustomSlot(id: CustomPrograms.newId(), pattern: pattern.rawValue, exerciseId: nil,
                   sets: 3, low: 8, high: 12, rest: 90, essential: false, keepBarbell: false)
    }

    var movement: MovementPattern { MovementPattern(rawValue: pattern) ?? .core }
}

struct CustomDay: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var focus: String
    var slots: [CustomSlot]
}

struct CustomProgram: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var days: [CustomDay]
    var hidden: Bool

    /// 至少一天有動作才能用。
    var usable: Bool { days.contains { !$0.slots.isEmpty } }
}

enum CustomPrograms {
    private static var cacheRaw: String?
    private static var cache: [CustomProgram] = []

    /// 全部（含已刪除：舊紀錄的 dayKey 還要查得到名字）。
    static func load() -> [CustomProgram] {
        let raw = UserDefaults.standard.string(forKey: Keys.customPrograms) ?? ""
        if raw == cacheRaw { return cache }
        cacheRaw = raw
        cache = (try? JSONDecoder().decode([CustomProgram].self, from: Data(raw.utf8))) ?? []
        return cache
    }

    static func save(_ list: [CustomProgram]) {
        guard let data = try? JSONEncoder().encode(list), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.customPrograms)
    }

    static func upsert(_ program: CustomProgram) {
        var list = load()
        if let i = list.firstIndex(where: { $0.id == program.id }) { list[i] = program } else { list.append(program) }
        save(list)
    }

    static func hide(_ id: String) {
        var list = load()
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].hidden = true
        save(list)
        if activeId == id { activeId = "" }
    }

    static var visible: [CustomProgram] { load().filter { !$0.hidden } }

    /// 空字串 = 內建課表。
    static var activeId: String {
        get { UserDefaults.standard.string(forKey: Keys.activeProgram) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.activeProgram) }
    }

    /// 正在用的自訂課表；沒選、被刪掉或還是空的，就回到內建。
    static var active: CustomProgram? {
        let id = activeId
        guard !id.isEmpty else { return nil }
        return load().first { $0.id == id && !$0.hidden && $0.usable }
    }

    static func newId() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8).lowercased()
    }

    static let dayPrefix = "c_"

    static func template(_ day: CustomDay) -> DayTemplate {
        DayTemplate(id: dayPrefix + day.id, name: day.name.isEmpty ? "未命名" : day.name, focus: day.focus,
                    custom: true,
                    slots: day.slots.map {
                        Slot(pattern: $0.movement, sets: max(1, $0.sets), low: max(1, $0.low),
                             high: max($0.low, $0.high), essential: $0.essential, keepBarbell: $0.keepBarbell,
                             exerciseId: $0.exerciseId, rest: $0.rest, linkPrev: $0.linkPrev ?? false)
                    })
    }

    static func templates(_ program: CustomProgram) -> [DayTemplate] {
        program.days.filter { !$0.slots.isEmpty }.map(template)
    }

    /// 任何一份自訂課表（含已刪除）裡的某一天。
    static func day(templateId: String) -> DayTemplate? {
        guard templateId.hasPrefix(dayPrefix) else { return nil }
        let raw = String(templateId.dropFirst(dayPrefix.count))
        for p in load() {
            if let d = p.days.first(where: { $0.id == raw }) { return template(d) }
        }
        return nil
    }

    /// 複製內建課表：組數、休息換成內建完整版實際排的（主項 +1 組、重點動作休息 120 秒）。
    static func copyOfBuiltIn(name: String) -> CustomProgram {
        let days = ProgramBuilder.builtInDays.map { d in
            CustomDay(id: newId(), name: d.name, focus: d.focus, slots: d.slots.map { s in
                CustomSlot(id: newId(), pattern: s.pattern.rawValue, exerciseId: nil,
                           sets: s.sets + (ProgramBuilder.isMainSlot(s, in: d) ? 1 : 0), low: s.low, high: s.high,
                           rest: s.essential ? 120 : 60, essential: s.essential, keepBarbell: s.keepBarbell)
            })
        }
        return CustomProgram(id: newId(), name: name, days: days, hidden: false)
    }

    static func blank(name: String) -> CustomProgram {
        CustomProgram(id: newId(), name: name,
                      days: [CustomDay(id: newId(), name: "第 1 天", focus: "", slots: [])], hidden: false)
    }
}
