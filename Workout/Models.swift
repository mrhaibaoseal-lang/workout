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
    /// SetKind.rawValue：warmup／work／drop。舊紀錄沒有這個欄位，預設是正式組。
    var kind: String = "work"
    /// 做完還剩幾下（RIR），-1 = 沒填。
    var rir: Int = -1

    init(exerciseId: String, setIndex: Int, weight: Double, reps: Int, date: Date,
         kind: SetKind = .work, rir: Int = -1) {
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.date = date
        self.kind = kind.rawValue
        self.rir = rir
    }

    /// 正式組才算進步、破紀錄和訓練量；熱身組和 drop set 不算。
    var isWork: Bool { kind == SetKind.work.rawValue }
}

/// 身體數據（不拍照，只記數字）。0 = 這次沒量。
@Model
final class BodyLog {
    var date: Date
    var weight: Double = 0
    var bodyFat: Double = 0
    var shoulders: Double = 0
    var chest: Double = 0
    var arm: Double = 0
    var waist: Double = 0
    var hips: Double = 0
    var thigh: Double = 0
    var calf: Double = 0

    init(date: Date = .now) {
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
    /// 上次看到的牌位（Rank.index），用來判斷要不要跳晉級畫面。
    static let lastRankIndex = "lastRankIndex"
    /// TrainingPlace.rawValue：在家／健身房
    static let place = "place"
    /// 每個動作選的組數模式，JSON [exerciseId: SetScheme.rawValue]
    static let schemes = "schemes"
    /// 自動排熱身組
    static let autoWarmup = "autoWarmup"
    /// 身高（公分），身體數據用
    static let height = "height"
    /// 槓鈴要自己用啞鈴組裝：在家少排槓鈴
    static let limitBarbell = "limitBarbell"
    /// 啞鈴組和槓片，JSON [WeightKit]
    static let kits = "kits"
    /// 上次看到的牌位分數，用來播「分數入帳」動畫。
    static let lastRankPoints = "lastRankPoints"
    /// 上次看到分數的時間（找出這段時間新增的加減分）。
    static let lastRankCheck = "lastRankCheck"
    /// 已經播過結算動畫的最後一週（結算時間）。
    static let lastSettledWeek = "lastSettledWeek"
    /// 請假、保護卡、週任務等新規則從哪一天開始算（秒）。
    static let goalsSince = "goalsSince"
    /// 請假，JSON [yyyy-MM-dd: LeaveReason]
    static let leaves = "leaves"
    /// 每天的排程紀錄，JSON [yyyy-MM-dd: DayLog]
    static let planLog = "planLog"
    /// 用碎片買保護卡的時間，JSON [秒]
    static let shieldBuys = "shieldBuys"
    /// 押注，JSON [Bet]
    static let bets = "bets"

    static let defaultWeekdays = "2,3,5,7"
    static let defaultMinutes = 21 * 60

    static func parseWeekdays(_ raw: String) -> Set<Int> {
        Set(raw.split(separator: ",").compactMap { Int($0) })
    }
}

enum Equipment: String, CaseIterable, Identifiable {
    case dumbbell, barbell, kettlebell, bench, cable, band, pullupBar, rack, machine

    /// 設定頁「在家的器材」能勾的項目；健身房器械只在健身房模式用。
    static var homeChoices: [Equipment] { allCases.filter { $0 != .machine } }
    /// 健身房模式：假設什麼都有。
    static var gym: Set<Equipment> { Set(allCases) }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .dumbbell: "啞鈴"
        case .barbell: "槓鈴"
        case .bench: "可調式健身椅"
        case .cable: "高位下拉架（滑輪）"
        case .band: "彈力帶／彈力繩"
        case .pullupBar: "單槓"
        case .kettlebell: "壺鈴（含啞鈴改壺鈴把手）"
        case .rack: "深蹲架／臥推架"
        case .machine: "健身房器械"
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
        case .rack: "square.split.bottomrightquarter"
        case .machine: "gearshape.2.fill"
        }
    }

    static func parse(_ raw: String) -> Set<Equipment> {
        Set(raw.split(separator: ",").compactMap { Equipment(rawValue: String($0)) })
    }

    static func encode(_ set: Set<Equipment>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}

/// 在家／健身房。在家用設定裡勾的器材；健身房什麼都有，而且可以換動作（器材被佔用時）。
enum TrainingPlace: String, CaseIterable, Identifiable {
    case home, gym

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "在家"
        case .gym: "健身房"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .gym: "building.2.fill"
        }
    }

    func equipment(homeRaw: String) -> Set<Equipment> {
        switch self {
        case .home: Equipment.parse(homeRaw)
        case .gym: Equipment.gym
        }
    }
}
