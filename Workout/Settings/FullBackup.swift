import Foundation
import SwiftData

/// 完整備份（0.34.0）：訓練紀錄、身體數據、間歇紀錄，加上 App 自己的所有設定和狀態（背包、目標、請假、升級……），
/// 存成一個 JSON 檔，可以存到「檔案」App；重裝或換手機時再匯入。
/// Keychain 的 `SettingsBackup` 只存設定、不存紀錄，換憑證（Team ID 不同）也可能讀不回來，所以要有這個。
enum FullBackup {
    static let version = 1

    struct File: Codable {
        var version: Int
        var exportedAt: Date
        var appVersion: String
        var sessions: [Session]
        var bodies: [BodyEntry]
        var intervals: [Interval]
        /// App 自己的 UserDefaults（binary plist）
        var defaults: Data
    }

    struct Session: Codable {
        var date: Date
        var dayKey: String
        var isShort: Bool
        var durationSeconds: Int
        var mode: String
        var note: String
        var exerciseNotes: String
        var readiness: String
        var phase: String
        var entries: [Entry]
    }

    struct Entry: Codable {
        var exerciseId: String
        var setIndex: Int
        var weight: Double
        var reps: Int
        var date: Date
        var kind: String
        var rir: Int
        var otherReps: Int
        var otherRir: Int
        var side: String
        var eased: Bool
    }

    struct BodyEntry: Codable {
        var date: Date
        var weight, bodyFat, shoulders, chest, arm, waist, hips, thigh, calf: Double
    }

    struct Interval: Codable {
        var date: Date
        var kind: String
        var detail: String
        var durationSeconds: Int
        var rounds: Int
        var stoppedEarly: Bool
    }

    enum BackupError: LocalizedError {
        case unreadable, newerVersion(Int)
        var errorDescription: String? {
            switch self {
            case .unreadable: "這不是練壯的備份檔，或檔案壞掉了。"
            case .newerVersion(let v): "這個備份是新版 App 存的（格式 \(v)），請先更新 App 再匯入。"
            }
        }
    }

    // MARK: 匯出

    private static var domain: String { Bundle.main.bundleIdentifier ?? "com.mrhaibaoseal.workout" }

    /// 不放進備份的 key：訓練到一半的進度（換手機後接著練沒有意義）
    static let skippedKeys: Set<String> = [Keys.workoutInProgress]

    static func make(context: ModelContext, now: Date = .now) throws -> File {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date)]))
        let bodies = try context.fetch(FetchDescriptor<BodyLog>(sortBy: [SortDescriptor(\.date)]))
        let intervals = try context.fetch(FetchDescriptor<IntervalLog>(sortBy: [SortDescriptor(\.date)]))
        let prefs = (UserDefaults.standard.persistentDomain(forName: domain) ?? [:])
            .filter { !skippedKeys.contains($0.key) }
        let plist = try PropertyListSerialization.data(fromPropertyList: prefs, format: .binary, options: 0)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return File(
            version: Self.version, exportedAt: now, appVersion: version,
            sessions: sessions.map { s in
                Session(date: s.date, dayKey: s.dayKey, isShort: s.isShort, durationSeconds: s.durationSeconds,
                        mode: s.mode, note: s.note, exerciseNotes: s.exerciseNotes, readiness: s.readiness,
                        phase: s.phase,
                        entries: s.entries.sorted { ($0.date, $0.setIndex) < ($1.date, $1.setIndex) }.map { e in
                            Entry(exerciseId: e.exerciseId, setIndex: e.setIndex, weight: e.weight, reps: e.reps,
                                  date: e.date, kind: e.kind, rir: e.rir, otherReps: e.otherReps,
                                  otherRir: e.otherRir, side: e.side, eased: e.eased)
                        })
            },
            bodies: bodies.map { b in
                BodyEntry(date: b.date, weight: b.weight, bodyFat: b.bodyFat, shoulders: b.shoulders, chest: b.chest,
                     arm: b.arm, waist: b.waist, hips: b.hips, thigh: b.thigh, calf: b.calf)
            },
            intervals: intervals.map { i in
                Interval(date: i.date, kind: i.kind, detail: i.detail, durationSeconds: i.durationSeconds,
                         rounds: i.rounds, stoppedEarly: i.stoppedEarly)
            },
            defaults: plist)
    }

    static func encode(_ f: File) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(f)
    }

    static func decode(_ data: Data) throws -> File {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        guard let f = try? dec.decode(File.self, from: data) else { throw BackupError.unreadable }
        guard f.version <= version else { throw BackupError.newerVersion(f.version) }
        return f
    }

    /// 寫成暫存檔，給分享選單存到「檔案」。
    static func exportFile(context: ModelContext) throws -> URL {
        let data = try encode(make(context: context))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("backup", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let url = dir.appendingPathComponent("練壯_完整備份_\(f.string(from: .now)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: 匯入

    /// 用備份取代目前所有資料（紀錄全部刪掉再寫入，設定整組換掉）。
    static func restore(_ f: File, context: ModelContext) throws {
        let prefs = (try PropertyListSerialization.propertyList(from: f.defaults, format: nil)) as? [String: Any] ?? [:]

        try context.delete(model: SetEntry.self)
        try context.delete(model: WorkoutSession.self)
        try context.delete(model: BodyLog.self)
        try context.delete(model: IntervalLog.self)

        for s in f.sessions {
            let session = WorkoutSession(date: s.date, dayKey: s.dayKey,
                                         length: WorkoutLength(rawValue: s.mode) ?? (s.isShort ? .short : .full),
                                         durationSeconds: s.durationSeconds)
            session.isShort = s.isShort
            session.mode = s.mode
            session.note = s.note
            session.exerciseNotes = s.exerciseNotes
            session.readiness = s.readiness
            session.phase = s.phase
            context.insert(session)
            for e in s.entries {
                let entry = SetEntry(exerciseId: e.exerciseId, setIndex: e.setIndex, weight: e.weight, reps: e.reps,
                                     date: e.date, kind: SetKind(rawValue: e.kind) ?? .work, rir: e.rir)
                entry.kind = e.kind
                entry.otherReps = e.otherReps
                entry.otherRir = e.otherRir
                entry.side = e.side
                entry.eased = e.eased
                entry.session = session
                context.insert(entry)
            }
        }
        for b in f.bodies {
            let log = BodyLog(date: b.date)
            log.weight = b.weight; log.bodyFat = b.bodyFat; log.shoulders = b.shoulders; log.chest = b.chest
            log.arm = b.arm; log.waist = b.waist; log.hips = b.hips; log.thigh = b.thigh; log.calf = b.calf
            context.insert(log)
        }
        for i in f.intervals {
            let log = IntervalLog(date: i.date, kind: IntervalKind(rawValue: i.kind) ?? .custom, detail: i.detail,
                                  durationSeconds: i.durationSeconds, rounds: i.rounds, stoppedEarly: i.stoppedEarly)
            log.kind = i.kind
            context.insert(log)
        }
        try context.save()

        // 設定整組換掉；訓練到一半的進度不管備份裡有沒有都清掉
        let d = UserDefaults.standard
        for key in (d.persistentDomain(forName: domain) ?? [:]).keys { d.removeObject(forKey: key) }
        for (key, value) in prefs where !skippedKeys.contains(key) { d.set(value, forKey: key) }
        SettingsBackup.flush()
    }
}
