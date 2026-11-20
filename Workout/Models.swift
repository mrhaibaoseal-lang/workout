import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date
    var dayKey: String
    var isShort: Bool
    var durationSeconds: Int
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.session)
    var entries: [SetEntry] = []

    init(date: Date = .now, dayKey: String, isShort: Bool, durationSeconds: Int) {
        self.date = date
        self.dayKey = dayKey
        self.isShort = isShort
        self.durationSeconds = durationSeconds
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
}

enum Equipment: String, CaseIterable, Identifiable {
    case dumbbell, bench, band, pullupBar, kettlebell

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dumbbell: "啞鈴"
        case .bench: "健身椅 / 穩固長椅"
        case .band: "彈力帶"
        case .pullupBar: "單槓"
        case .kettlebell: "壺鈴"
        }
    }

    var icon: String {
        switch self {
        case .dumbbell: "dumbbell.fill"
        case .bench: "bed.double.fill"
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
