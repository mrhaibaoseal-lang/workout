import Foundation

extension Keys {
    /// 出生年（西元）；0 = 沒填
    static let birthYear = "birthYear"
    /// Sex.rawValue；空的 = 沒填
    static let sex = "sex"
    /// TrainingExperience.rawValue；空的 = 沒填
    static let experience = "trainingExperience"
    /// 以前受過傷的備註（問卷填的，只給自己看）
    static let injuryNote = "injuryNote"
    /// 預設的訓練長度（WorkoutLength.rawValue）；空的 = 完整版。每次 30 分鐘以內的人設成精簡版
    static let defaultLength = "defaultLength"
    /// 最近一次填完問卷的時間（秒）
    static let questionnaireDate = "questionnaireDate"
}

/// 性別：只用在熱量估算，「不想說」就用不含性別的算法。
enum Sex: String, CaseIterable, Identifiable {
    case male, female, undisclosed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: "男"
        case .female: "女"
        case .undisclosed: "不想說"
        }
    }
}

/// 訓練經驗。2 年以上直接從中階排法開始。
enum TrainingExperience: String, CaseIterable, Identifiable {
    case none, underHalfYear, halfToTwo, overTwo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "沒練過"
        case .underHalfYear: "半年內"
        case .halfToTwo: "半年～2 年"
        case .overTwo: "2 年以上"
        }
    }

    var startsIntermediate: Bool { self == .overTwo }
}

/// 問卷填的個人資料（身高、年齡、性別）。體重在身體數據（`StartWeight.bodyWeight`）。
enum UserProfile {
    static var birthYear: Int { UserDefaults.standard.integer(forKey: Keys.birthYear) }

    static var sex: Sex? {
        Sex(rawValue: UserDefaults.standard.string(forKey: Keys.sex) ?? "")
    }

    static var experience: TrainingExperience? {
        TrainingExperience(rawValue: UserDefaults.standard.string(forKey: Keys.experience) ?? "")
    }

    static var heightCm: Double { UserDefaults.standard.double(forKey: Keys.height) }

    /// 年齡（歲）；沒填或不合理回傳 nil
    static func age(birthYear: Int = UserProfile.birthYear, now: Date = .now) -> Int? {
        guard birthYear > 0 else { return nil }
        let year = Calendar.current.component(.year, from: now)
        let a = year - birthYear
        return (10...100).contains(a) ? a : nil
    }

    /// 問卷能選的出生年（由新到舊）
    static func birthYearChoices(now: Date = .now) -> [Int] {
        let year = Calendar.current.component(.year, from: now)
        return Array((year - 80)...(year - 12)).reversed()
    }
}
