import Foundation
import SwiftData

/// 問卷的答案。每個欄位都可以是 nil（= 略過或沒填）；寫入時只動有填的欄位，
/// 所以「重新填問卷」不會把以前的設定清掉，也不會動訓練紀錄。
struct OnboardingAnswers: Equatable {
    var heightCm: Double?
    var birthYear: Int?
    var sex: Sex?
    var weightKg: Double?
    var experience: TrainingExperience?
    var daysPerWeek: Int?
    var weekdays: Set<Int>?
    /// true = 每次 30 分鐘以內（預設精簡版）；false = 超過 30 分鐘
    var shortSessions: Bool?
    /// 會痛或受過傷的關節；nil = 略過，空集合 = 選了「都沒有」
    var painJoints: Set<Joint>?
    var weakArm: WeakSide?
    var weakLeg: WeakSide?
    /// 以前受過傷的備註；nil = 略過
    var injuryNote: String?
}

enum OnboardingFlow {
    /// 每次練多久的選項
    enum SessionMinutes: String, CaseIterable, Identifiable {
        case under30, between, over60

        var id: String { rawValue }

        var title: String {
            switch self {
            case .under30: "30 分鐘以內"
            case .between: "30～60 分鐘"
            case .over60: "60 分鐘以上"
            }
        }

        /// 30 分鐘以內 → 預設精簡版
        var isShort: Bool { self == .under30 }
    }

    /// 一週練幾天，建議練哪幾天（Calendar 星期：1 = 週日）。中間隔開，讓肌肉有時間恢復。
    static func suggestedWeekdays(days: Int) -> Set<Int> {
        switch days {
        case ...2: [2, 5]
        case 3: [2, 4, 6]
        case 4: [2, 3, 5, 7]
        case 5: [2, 3, 4, 6, 7]
        default: [2, 3, 4, 5, 6, 7]
        }
    }

    /// 3 天（含）以下用內建 3 天全身，4 天以上用上下半身分化。
    static func program(forDays days: Int) -> BuiltInProgram {
        days <= 3 ? .fullBody3 : .split4
    }

    /// 選了會痛的關節 → 要標「會痛」的動作 id。
    /// 規則：動作類型最吃力的關節（`Joint.of`）是選的那個，這類的內建動作都標起來，
    /// 但每一類至少留一個現在排得了的（優先不用器材的），免得整個部位排不出動作。
    /// 原本就標過（會痛或不喜歡）的不重複標。
    static func painExerciseIds(joints: Set<Joint>, equipment: Set<Equipment>) -> [String] {
        var out: [String] = []
        for pattern in MovementPattern.allCases {
            guard let primary = Joint.of(pattern), joints.contains(primary) else { continue }
            let all = ExerciseLibrary.builtIn.filter { $0.pattern == pattern }
            let usable = all.filter { $0.requires.isSubset(of: equipment) }
            let keep = usable.first { $0.requires.isEmpty } ?? usable.first
            out += all.filter { $0.id != keep?.id && !Avoid.isAvoided($0.id) }.map(\.id)
        }
        return out
    }

    /// 把答案寫進設定。`measuredArm` 是程度評估划船實測的弱手（兩手差 2 下以上），有的話以實測為準。
    /// 回傳這次標了「會痛」的動作數（畫面上告訴使用者）。
    @discardableResult
    static func apply(_ a: OnboardingAnswers, measuredArm: WeakSide?, context: ModelContext, now: Date = .now) -> Int {
        let d = UserDefaults.standard
        if let h = a.heightCm, h > 0 { d.set(h, forKey: Keys.height) }
        if let y = a.birthYear, y > 0 { d.set(y, forKey: Keys.birthYear) }
        if let s = a.sex { d.set(s.rawValue, forKey: Keys.sex) }
        if let w = a.weightKg, w > 0 {
            let log = BodyLog(date: now)
            log.weight = w
            context.insert(log)
            try? context.save()
            StartWeight.noteBodyWeight(w, date: now)
        }

        if let e = a.experience {
            d.set(e.rawValue, forKey: Keys.experience)
            // 2 年以上直接中階；其他維持原樣（新手，或已經畢業的不降回去）
            if e.startsIntermediate, Graduation.level != .intermediate { Graduation.setLevel(.intermediate) }
        }

        if let n = a.daysPerWeek {
            if CustomPrograms.active == nil { program(forDays: n).activate() }
            d.set(n, forKey: Keys.weeklyGoal)
        }
        if let wd = a.weekdays, !wd.isEmpty {
            d.set(wd.sorted().map(String.init).joined(separator: ","), forKey: Keys.reminderWeekdays)
        }
        if let short = a.shortSessions {
            d.set(short ? WorkoutLength.short.rawValue : "", forKey: Keys.defaultLength)
        }

        var marked = 0
        if let joints = a.painJoints, !joints.isEmpty {
            let equipment = TrainingPlace(rawValue: d.string(forKey: Keys.place) ?? "")?
                .equipment(homeRaw: d.string(forKey: Keys.equipment) ?? "") ?? Equipment.parse(d.string(forKey: Keys.equipment) ?? "")
            for id in painExerciseIds(joints: joints, equipment: equipment) {
                Avoid.mark(id, reason: .pain)
                marked += 1
            }
        }

        if let arm = measuredArm ?? a.weakArm { SideBalance.set(arm, for: .arm) }
        if let leg = a.weakLeg { SideBalance.set(leg, for: .leg) }
        if let note = a.injuryNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            d.set(note, forKey: Keys.injuryNote)
        }
        d.set(now.timeIntervalSince1970, forKey: Keys.questionnaireDate)
        return marked
    }
}
