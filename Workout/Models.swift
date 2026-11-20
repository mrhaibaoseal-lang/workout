import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date
    var dayKey: String
    var isShort: Bool
    var durationSeconds: Int
    var mode: String = "full"
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session)
    var entries: [SetEntry] = []

    init(date: Date = .now, dayKey: String, length: WorkoutLength, durationSeconds: Int) {
        self.date = date
        self.dayKey = dayKey
        self.isShort = length != .full
        self.mode = length.rawValue
        self.durationSeconds = durationSeconds
    }

    var length: WorkoutLength {
        WorkoutLength(rawValue: mode) ?? (isShort ? .short : .full)
    }

    var dayName: String {
        ProgramBuilder.days.first { $0.id == dayKey }?.name ?? dayKey
    }
}

@Model
final class SetEntry {
    var exerciseId: String
    var setIndex: Int
    var weight: Double
    var reps: Int
    var date: Date
    var session: WorkoutSession?

    init(exerciseId: String, setIndex: Int, weight: Double, reps: Int, date: Date) {
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.date = date
    }
}

/// UserDefaults keys used with @AppStorage.
enum Keys {
    static let onboarded = "onboarded"
    static let equipment = "equipment"
    static let startDate = "startDate"
    static let weeklyGoal = "weeklyGoal"
    static let increment = "increment"
    static let maxDumbbell = "maxDumbbell"
    static let maxBarbell = "maxBarbell"
    static let reminderOn = "reminderOn"
    /// Calendar weekdays (1 = Sunday ... 7 = Saturday), comma separated.
    static let reminderWeekdays = "reminderWeekdays"
    /// Minutes after midnight.
    static let reminderMinutes = "reminderMinutes"

    static let commuteSchool = "commuteSchool"
    static let commuteWork = "commuteWork"
    static let earliestHour = "earliestHour"
    static let preferredHour = "preferredHour"
    static let latestHour = "latestHour"
    static let reminderLead = "reminderLead"
    static let tiredHours = "tiredHours"
    static let readPhoneCalendar = "readPhoneCalendar"

    static let defaultWeekdays = "2,3,5,7"
    static let defaultMinutes = 21 * 60

    static func parseWeekdays(_ raw: String) -> Set<Int> {
        Set(raw.split(separator: ",").compactMap { Int($0) })
    }
}

enum Equipment: String, CaseIterable, Identifiable {
    case dumbbell, barbell, kettlebell, bench, cable, band, pullupBar

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dumbbell: "啞鈴"
        case .barbell: "槓鈴"
        case .bench: "可調式健身椅"
        case .cable: "高位下拉架（滑輪）"
        case .band: "彈力帶"
        case .pullupBar: "單槓"
        case .kettlebell: "壺鈴"
        }
    }

    var icon: String {
        switch self {
        case .dumbbell: "dumbbell.fill"
        case .barbell: "figure.strengthtraining.traditional"
        case .bench: "bed.double.fill"
        case .cable: "arrow.down.to.line"
        case .band: "lasso"
        case .pullupBar: "figure.climbing"
        case .kettlebell: "scalemass.fill"
        }
    }

    static func parse(_ raw: String) -> Set<Equipment> {
        Set(raw.split(separator: ",").compactMap { Equipment(rawValue: String($0)) })
    }

    static func encode(_ set: Set<Equipment>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}
