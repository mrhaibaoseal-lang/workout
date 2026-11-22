import Foundation

extension Keys {
    /// 還沒按「完成」的訓練進度（JSON WorkoutSnapshot）
    static let workoutInProgress = "workoutInProgress"
}

/// 訓練到一半的進度（0.34.0）。訓練畫面的成績原本只在記憶體裡，切到背景被系統關掉就整場不見。
/// 每完成一組、App 切到背景時存一份；下次打開今天頁可以「繼續上次的訓練」。
/// 還原時照正常流程排課，再依順序把存的動作和每組成績蓋上去（換過、加練的動作也會還原）。
struct WorkoutSnapshot: Codable, Equatable {
    struct SetSnap: Codable, Equatable {
        var weight: Double
        var reps: Int
        var kind: String
        var kit: String?
        var rir: Int
        var done: Bool
        var target: Int
        var grade: String?
        var oneArm: Bool
        var otherReps: Int
        var otherRir: Int
        var eased: Bool
    }

    struct ExerciseSnap: Codable, Equatable {
        var exerciseId: String
        var note: String
        var sets: [SetSnap]
    }

    var dayId: String
    var dayName: String
    var length: String
    var startedAt: Double
    var savedAt: Double
    var readiness: String
    var sessionNote: String
    var combo: Int
    var bestCombo: Int
    var onTimeRests: Int
    var scoredRests: Int
    var exercises: [ExerciseSnap]

    var doneSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.done).count } }
}

extension SetDraft {
    var snapshot: WorkoutSnapshot.SetSnap {
        .init(weight: weight, reps: reps, kind: kind.rawValue, kit: kit, rir: rir, done: done, target: target,
              grade: grade?.rawValue, oneArm: oneArm, otherReps: otherReps, otherRir: otherRir, eased: eased)
    }

    init(_ s: WorkoutSnapshot.SetSnap) {
        self.init(weight: s.weight, reps: s.reps, kind: SetKind(rawValue: s.kind) ?? .work, kit: s.kit, rir: s.rir,
                  done: s.done, target: s.target, grade: s.grade.flatMap(SetGrade.init(rawValue:)),
                  oneArm: s.oneArm, otherReps: s.otherReps, otherRir: s.otherRir, eased: s.eased)
    }
}

enum WorkoutResume {
    /// 超過這麼久就不問要不要繼續（隔天的訓練當新的一次）
    static let maxAgeHours = 12.0

    static func save(_ s: WorkoutSnapshot) {
        guard let data = try? JSONEncoder().encode(s), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.workoutInProgress)
    }

    /// 還能繼續的進度：有做完至少一組、沒有太舊。
    static func load(now: Date = .now) -> WorkoutSnapshot? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.workoutInProgress),
              let s = try? JSONDecoder().decode(WorkoutSnapshot.self, from: Data(raw.utf8)),
              isFresh(s, now: now) else { return nil }
        return s
    }

    static func isFresh(_ s: WorkoutSnapshot, now: Date = .now) -> Bool {
        s.doneSets > 0 && now.timeIntervalSince1970 - s.savedAt < maxAgeHours * 3600
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.workoutInProgress)
    }
}
