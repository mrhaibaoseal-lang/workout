import Foundation

struct Slot {
    let pattern: MovementPattern
    let sets: Int
    let low: Int
    let high: Int
    /// Kept in the 20-minute short version.
    let essential: Bool
    /// 「少排槓鈴」時，這個位置仍然優先用槓鈴（槓鈴臀推：啞鈴壓髖部太輕）。
    var keepBarbell = false
    /// 自訂課表：指定的動作。器材不夠或已刪除時，改用同類型自動挑。
    var exerciseId: String? = nil
    /// 自訂課表：完整版的休息秒數（內建課表依重點動作 120／60 秒）。
    var rest: Int? = nil
    /// 自訂課表：和上一個動作連成超級組／循環組。
    var linkPrev = false
    /// 全身日（併天）：這格來自哪一天，選動作時照那一天的順位，才會和原本那天排到同一個動作。
    var source: String? = nil
}

struct DayTemplate: Identifiable {
    let id: String
    let name: String
    let focus: String
    /// B days start from the second exercise variant so A and B differ.
    var variant: Int = 0
    /// 自訂課表的一天：組數照使用者填的，不自動 +1。
    var custom = false
    let slots: [Slot]

    /// 週任務「上下半身都練」用。內建看 id，自訂看動作類型（全身日兩邊都算）。
    var halves: (upper: Bool, lower: Bool) {
        if id.hasPrefix("upper") { return (true, false) }
        if id.hasPrefix("lower") { return (false, true) }
        let patterns = slots.map(\.pattern)
        return (patterns.contains { $0.isUpper }, patterns.contains { $0.isLower })
    }
}

enum Phase: String {
    case rampUp, normal, deload

    var title: String {
        switch self {
        case .rampUp: "適應期"
        case .normal: "進步期"
        case .deload: "減量週"
        }
    }

    var note: String {
        switch self {
        case .rampUp: "前兩週練輕一點，每組留 3 下的力氣。先養成習慣，不要練到爆痠。"
        case .normal: "每組做到還剩 1–2 下的力氣就停。每組都做到次數上限，下次就加重。"
        case .deload: "這週組數減半、重量減輕一成，讓身體恢復。下週回到原本的重量繼續進步；小肌群的動作會換一批。"
        }
    }
}

enum WorkoutLength: String, CaseIterable, Identifiable {
    case full, short, minimal

    /// 使用者設的預設長度（問卷「每次 30 分鐘以內」或設定 → 訓練）：只有完整／精簡兩種，沒設就是完整。
    static var preferred: WorkoutLength {
        UserDefaults.standard.string(forKey: Keys.defaultLength) == WorkoutLength.short.rawValue ? .short : .full
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: "完整"
        case .short: "精簡"
        case .minimal: "只做 1 組"
        }
    }

    var tag: String? {
        switch self {
        case .full: nil
        case .short: "精簡"
        case .minimal: "1 組起"
        }
    }
}

struct PlannedExercise: Identifiable {
    let exercise: Exercise
    var sets: Int
    let low: Int
    let high: Int
    /// 沒被「重量跳太大」調整過的原本次數範圍（`JumpGuard`）；nil = 沒調整，就是 low...high。
    var base: ClosedRange<Int>? = nil
    let restSeconds: Int
    let essential: Bool
    /// 自訂課表指定的動作今天排不了（器材不夠或已刪除），改用這個動作時，記原本的名字。
    var replaced: String? = nil
    /// 超級組／循環組：同一個數字的相鄰動作輪流做（`Superset`）。
    var group: Int? = nil
    /// 指定用哪一組器材（超級組裡另一個動作已經用主要啞鈴時，改用另一組）。
    var kit: String? = nil
    /// 超級組裡和別的動作共用這組器材（分不開），每輪要換重量。
    var sharedKit: String? = nil
    /// 中階排法：這天的主要動作練重還是輕（`Graduation`）；新手、自訂課表是 nil。
    var intensity: Intensity? = nil
    /// 器材到頂自動升級（`Upgrade`）：原本的動作名稱。
    var upgradedFrom: String? = nil

    var id: String { exercise.id }
    var baseLow: Int { base?.lowerBound ?? low }
    var baseHigh: Int { base?.upperBound ?? high }

    /// 換成同類型的另一個動作：組數、休息照舊，次數範圍用原本的（再套這個新動作自己的「重量跳太大」狀態）。
    func swapped(to ex: Exercise) -> PlannedExercise {
        let range = ex.range ?? baseLow...baseHigh
        let adj = JumpGuard.adjust(id: ex.id, low: range.lowerBound, high: range.upperBound)
        var extra = 0
        if JumpGuard.hasExtraSet(ex.id) { extra += 1 }
        if JumpGuard.hasExtraSet(exercise.id) { extra -= 1 }
        var item = PlannedExercise(exercise: ex, sets: max(1, sets + extra), low: adj.low, high: adj.high, base: range,
                                   restSeconds: restSeconds, essential: essential)
        item.group = group
        item.intensity = intensity
        return item
    }
}

enum ProgramBuilder {

    /// 新手增肌的上下半身分化（每週 4 天，每個部位一週練 2 次）。
    /// 每個肌群一週大約 9–12 個正式組：新手這個量就會一直長，不用練到爆。
    /// 複合動作 6–12 下、單關節動作 10–20 下；每組留 1–2 下的力氣，達標就加重（雙重進步法）。
    /// 健身房才有的動作（例如腿伸展機），在家會自動跳過。
    /// 現在用的課表：選了自訂課表就用它，不然用內建。
    static var days: [DayTemplate] {
        CustomPrograms.active.map(CustomPrograms.templates) ?? builtInDays
    }

    /// 自訂課表的名字；用內建課表時是 nil。
    static var customName: String? { CustomPrograms.active?.name }

    /// 舊紀錄的 dayKey 找回那一天（內建兩份、任何一份自訂課表、併成的全身日）。
    static func template(id: String) -> DayTemplate? {
        if id.hasPrefix(WeekFit.prefix) { return WeekFit.template(id: id) }
        return (builtInDays + splitDays + fullBodyDays + upperDays).first { $0.id == id }
            ?? CustomPrograms.day(templateId: id)
    }

    /// 內建課表：照設定選的那一份（4 天上下分化／3 天全身／上半身為主 4 天）。
    /// 手臂／肩膀專項期的進步週，各天多排手臂、肩膀的動作（`Specialization`）。
    static var builtInDays: [DayTemplate] {
        Specialization.augment(BuiltInProgram.current.days, week: Plateau.currentWeek)
    }

    /// 上半身為主 4 天的 day id 前綴（`variant(of:)`、`siblingDays` 靠它認）。
    static let upperPrefix = "u4"

    /// 內建「上半身為主 4 天」（0.55.0）：3 天上半身＋1 天全身（腿日）。
    /// - 胸每週 2 次（A、C）、背 3 次（A／C 划船、B 下拉）、側三角 3 次、二頭 3 次、三頭 2 次（推的動作再帶到）、腿 1 次、腹 2 次。
    /// - B 不排胸：一週 3 天上半身一定有兩天相鄰，胸恢復要 60 小時。
    /// - 每天同一部位正式組（次要出力算半組）≤ 約 10 組；上半身日約 20～22 組。
    /// - 腿只求維持（每週 1 次、接近力竭、重量不降），`VolumePlan` 不把腿補到 10 組。
    /// 同一個動作類型出現在兩天時，後面那天用下一順位的動作（`variant(of:)`）。建議順序 A → B → 全身 → C。
    static let upperDays: [DayTemplate] = [
        DayTemplate(id: "u4A", name: "上半身 A", focus: "胸、背", slots: [
            Slot(pattern: .hPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .incline, sets: 3, low: 8, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 4, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .triceps, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "u4B", name: "上半身 B", focus: "肩、背、手臂（不練胸）", slots: [
            Slot(pattern: .vPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .vPull, sets: 4, low: 8, high: 12, essential: true),
            Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .triceps, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "u4L", name: "全身（腿日）", focus: "腿、臀，帶一點手臂", slots: [
            Slot(pattern: .squat, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .glute, sets: 3, low: 8, high: 12, essential: true, keepBarbell: true),
            Slot(pattern: .hinge, sets: 2, low: 8, high: 12, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "u4C", name: "上半身 C", focus: "胸、背、腹", slots: [
            Slot(pattern: .hPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .incline, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .vPull, sets: 3, low: 10, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
    ]

    /// 內建 3 天全身（0.25.0）：每個部位一週練 3 次、每次組數少一點，每週總組數和分化差不多（再由 `VolumePlan` 平衡）。
    /// 同一個動作類型出現在兩天時，後面那天用第二順位的動作（`variant(of:)`）。
    static let fullBodyDays: [DayTemplate] = [
        DayTemplate(id: "fullA", name: "全身 A", focus: "深蹲、臥推、划船", slots: [
            Slot(pattern: .squat, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hamCurl, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .lateral, sets: 4, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
        ]),
        DayTemplate(id: "fullB", name: "全身 B", focus: "硬舉、肩推、下拉", slots: [
            Slot(pattern: .hinge, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .vPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .incline, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .lunge, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .lateral, sets: 4, low: 12, high: 20, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
        ]),
        DayTemplate(id: "fullC", name: "全身 C", focus: "臀推、上斜推、划船", slots: [
            Slot(pattern: .glute, sets: 3, low: 8, high: 12, essential: true, keepBarbell: true),
            Slot(pattern: .incline, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 10, high: 12, essential: true),
            Slot(pattern: .squat, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
    ]

    static let splitDays: [DayTemplate] = [
        DayTemplate(id: "upperA", name: "上半身 A", focus: "胸、背為主", slots: [
            Slot(pattern: .hPush, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .incline, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 4, low: 12, high: 20, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "lowerA", name: "下半身 A", focus: "大腿前側、臀", slots: [
            Slot(pattern: .squat, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hinge, sets: 3, low: 8, high: 12, essential: true),
            // 分腿蹲左右各做、很花時間：下半身 A 只當輔助 2 組（0.33.0），重點在下半身 B
            Slot(pattern: .lunge, sets: 2, low: 8, high: 12, essential: false),
            Slot(pattern: .quadIso, sets: 3, low: 12, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "upperB", name: "上半身 B", focus: "肩、背、手臂", variant: 1, slots: [
            Slot(pattern: .vPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPull, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .hPush, sets: 3, low: 8, high: 12, essential: true),
            Slot(pattern: .vPull, sets: 3, low: 10, high: 12, essential: false),
            Slot(pattern: .lateral, sets: 4, low: 12, high: 20, essential: false),
            Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false),
            Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false),
        ]),
        DayTemplate(id: "lowerB", name: "下半身 B", focus: "臀、大腿後側", variant: 1, slots: [
            Slot(pattern: .hinge, sets: 3, low: 6, high: 10, essential: true),
            Slot(pattern: .glute, sets: 3, low: 8, high: 12, essential: true, keepBarbell: true),
            Slot(pattern: .lunge, sets: 3, low: 10, high: 15, essential: true),
            Slot(pattern: .hamCurl, sets: 3, low: 10, high: 15, essential: false),
            Slot(pattern: .calf, sets: 3, low: 12, high: 20, essential: false),
            Slot(pattern: .core, sets: 3, low: 10, high: 15, essential: false),
        ]),
    ]

    /// 練的動作要用什麼器材：在家用設定裡勾的，健身房全部都有。
    static func equipment(place: String, homeRaw: String) -> Set<Equipment> {
        (TrainingPlace(rawValue: place) ?? .home).equipment(homeRaw: homeRaw)
    }

    static func phase(week: Int) -> Phase {
        if Plateau.deloadActive { return .deload }
        // 停 21 天以上回來的那一週當適應期（`Comeback`）
        if Comeback.rampUpActive { return .rampUp }
        if week <= 2 { return .rampUp }
        // 減量週照區塊時鐘：預設每 6 週，疲勞高可以提早、狀態好可以延後（`BlockClock`、`Fatigue`）
        // 剛停練兩週以上回來，等於已經休息過，不再減量
        if BlockClock.locate(week: week).deload == week && !Comeback.restedRecently { return .deload }
        return .normal
    }

    /// Exercise variants rotate after every deload week.
    static func block(week: Int) -> Int {
        BlockClock.locate(week: week).block
    }

    /// 一天排好的動作（還沒分超級組）。slotOf = 每個動作來自課表的第幾格。
    struct RawPlan {
        var items: [PlannedExercise]
        var slotOf: [Int]
    }

    /// 這一格自動挑動作時，候選的前兩個（有負重的優先；少排槓鈴時沒槓鈴的排前面）。
    static func topChoices(slot: Slot, equipment: Set<Equipment>, limitBarbell: Bool,
                           used: Set<String> = []) -> [Exercise] {
        var options = ExerciseLibrary.candidates(for: slot.pattern, equipment: equipment)
            .filter { !used.contains($0.id) }
        if limitBarbell && !slot.keepBarbell {
            let noBar = options.filter { !$0.requires.contains(.barbell) }
            if !noBar.isEmpty { options = noBar + options.filter { $0.requires.contains(.barbell) } }
        }
        // 重點動作（主項）不用平衡受限的單腳版本、擺盪：放到最後，沒別的才用
        if slot.essential {
            let main = options.filter { !ExerciseLibrary.notMain.contains($0.id) }
            if !main.isEmpty { options = main + options.filter { ExerciseLibrary.notMain.contains($0.id) } }
        }
        // 有負重的動作優先輪替（避免 B 日掉到徒手版）
        let loaded = options.filter(\.loaded)
        // 單關節動作每個區塊輪替，候選多一點才有變化；複合動作只在前兩個之間選
        let width = slot.pattern.region == nil ? 4 : 2
        return Array((loaded.isEmpty ? options : loaded).prefix(width))
    }

    /// 同一類動作在另一天（同為上半身或下半身）也有，B 日才換第二個；一週只練一次的用首選。
    /// 自訂課表：前面幾天也有同類型（自動挑）的，就往後換一個，各天才不會都一樣。
    private static func variant(of slot: Slot, in day: DayTemplate, siblings: [DayTemplate]) -> Int {
        // 自訂課表、內建全身、上半身為主：前面幾天也有這個動作類型的，就往後換一個
        if day.custom || day.id.hasPrefix("full") || day.id.hasPrefix(upperPrefix) {
            return siblings.prefix(while: { $0.id != day.id })
                .filter { d in d.slots.contains { $0.pattern == slot.pattern && $0.exerciseId == nil } }.count
        }
        let half = day.id.prefix(5)
        let shared = siblings.contains { d in
            d.id != day.id && d.id.prefix(5) == half && d.slots.contains { $0.pattern == slot.pattern }
        }
        return shared ? day.variant : 0
    }

    /// 選第幾個候選。複合動作（有 region）不隨區塊輪替，新手要先練熟；單關節動作每 6 週換。
    /// shift 是使用者按「換一個動作」累積的位移。
    private static func pickIndex(slot: Slot, block: Int, variant: Int, shift: Int, count: Int) -> Int {
        let rotate = slot.pattern.region != nil ? 0 : block
        return (rotate + variant + shift) % max(1, count)
    }

    private static func siblingDays(for day: DayTemplate) -> [DayTemplate] {
        if day.custom { return days }
        if day.id.hasPrefix(upperPrefix) { return upperDays }
        return day.id.hasPrefix("full") ? fullBodyDays : splitDays
    }

    /// 排出一天的動作（不含平衡、不含超級組）。
    static func rawPlan(day: DayTemplate, equipment: Set<Equipment>, week: Int, length: WorkoutLength,
                        limitBarbell: Bool) -> RawPlan {
        let phase = phase(week: week)
        let block = block(week: week)
        var usedIds = Set<String>()

        var slotOf: [Int] = []
        let items: [PlannedExercise] = day.slots.enumerated().compactMap { n, slot -> PlannedExercise? in
            if length != .full && !slot.essential { return nil }
            // 自訂課表指定的動作：器材夠、沒被刪掉、沒被標記「會痛／不喜歡」就直接用
            var replaced: String? = nil
            if let fid = slot.exerciseId, let fixed = ExerciseLibrary.byId(fid), !usedIds.contains(fid) {
                if fixed.requires.isSubset(of: equipment) && !CustomExercises.isHidden(fid) && !Avoid.isAvoided(fid) {
                    usedIds.insert(fid)
                    slotOf.append(n)
                    return planned(fixed, slot: slot, day: day, phase: phase, length: length, replaced: nil)
                }
                replaced = fixed.name
            }
            let top = topChoices(slot: slot, equipment: equipment, limitBarbell: limitBarbell, used: usedIds)
            guard !top.isEmpty else { return nil }
            var exercise: Exercise
            if slot.keepBarbell {
                exercise = top[0]
            } else {
                // 全身日（併天）的格子照原本那一天選，才會和原本排到同一個動作
                let src = slot.source.flatMap(template(id:)) ?? day
                let i = pickIndex(slot: slot, block: block,
                                  variant: variant(of: slot, in: src, siblings: siblingDays(for: src)),
                                  shift: PatternShift.value(day: src.id, pattern: slot.pattern), count: top.count)
                exercise = top[i]
            }
            // 在家啞鈴到頂、已經升級過的動作，換成更難的版本（`Upgrade`）
            var upgradedFrom: String? = nil
            if let up = Upgrade.replacement(for: exercise, equipment: equipment, used: usedIds) {
                upgradedFrom = exercise.name
                exercise = up
            }
            usedIds.insert(exercise.id)
            slotOf.append(n)
            var item = planned(exercise, slot: slot, day: day, phase: phase, length: length, replaced: replaced)
            item.upgradedFrom = upgradedFrom
            return item
        }
        return RawPlan(items: items, slotOf: slotOf)
    }

    /// 內建課表完整版：4 天一起排，再用「每個部位每週組數」平衡（`VolumePlan`）。
    /// 回傳每一天平衡後的動作；平衡只改組數，不增減動作。
    static func balancedWeek(equipment: Set<Equipment>, week: Int, limitBarbell: Bool) -> [[PlannedExercise]] {
        let templates = builtInDays
        let phase = phase(week: week)
        let raws = templates.map { rawPlan(day: $0, equipment: equipment, week: week, length: .full, limitBarbell: limitBarbell) }
        let inputs: [VolumePlan.DayInput] = zip(templates, raws).map { day, raw in
            let skipped = day.slots.indices.filter { !raw.slotOf.contains($0) }
            return VolumePlan.DayInput(
                patterns: raw.items.map { $0.exercise.pattern },
                sets: raw.items.map(\.sets),
                lost: skipped.map { i in
                    (pattern: day.slots[i].pattern,
                     sets: slotSets(day.slots[i], day: day, phase: phase, length: .full, extra: false))
                })
        }
        // 個人組數＋中階的區塊加組＋重點部位＋專項期（`Focus.offsets`）
        let result = VolumePlan.balance(days: inputs, phase: phase, personal: Focus.offsets(week: week),
                                        maintain: BuiltInProgram.current.maintained)
        return zip(raws, result).map { raw, counts in
            var items = raw.items
            for i in items.indices where i < counts.count { items[i].sets = counts[i] }
            return items
        }
    }

    /// 一週（每個課表日各一次）完整版排出來的動作，給「本週預計組數」用。
    /// 內建課表有平衡；自訂課表照使用者填的。
    static func weeklyPlans(equipment: Set<Equipment>, week: Int, limitBarbell: Bool, gym: Bool) -> [[PlannedExercise]] {
        if CustomPrograms.active == nil {
            return balancedWeek(equipment: equipment, week: week, limitBarbell: limitBarbell)
        }
        return days.map { plan(day: $0, equipment: equipment, week: week, length: .full,
                               limitBarbell: limitBarbell, gym: gym) }
    }

    /// limitBarbell：槓鈴組裝麻煩時，除了 keepBarbell 的位置，其他都先用啞鈴等器材。
    static func plan(day: DayTemplate, equipment: Set<Equipment>, week: Int, length: WorkoutLength,
                     limitBarbell: Bool = false, gym: Bool = false) -> [PlannedExercise] {
        let raw = rawPlan(day: day, equipment: equipment, week: week, length: length, limitBarbell: limitBarbell)
        var all = raw.items
        let slotOf = raw.slotOf
        // 內建課表完整版：4 天一起看每個部位的每週組數，補不足、扣過多（只改組數）
        if length == .full && !day.custom,
           let idx = builtInDays.firstIndex(where: { $0.id == day.id }) {
            let week4 = balancedWeek(equipment: equipment, week: week, limitBarbell: limitBarbell)
            if idx < week4.count, week4[idx].count == all.count { all = week4[idx] }
        }
        if length == .minimal { return Array(all.prefix(1)) }
        // 超級組：自訂課表照每格的「和上一個連在一起」（中間的格子沒排到就不連）；內建課表看設定
        let link: [Bool]
        if day.custom {
            link = all.indices.map { i in
                i > 0 && day.slots[slotOf[i]].linkPrev && slotOf[i - 1] == slotOf[i] - 1
            }
        } else {
            link = UserDefaults.standard.bool(forKey: Keys.autoSuperset) ? Superset.autoLinks(all) : []
        }
        Superset.assignGroups(&all, link: link)
        let replaceable = all.indices.map { day.slots[slotOf[$0]].exerciseId == nil || all[$0].replaced != nil }
        Superset.separateKits(&all, gym: gym, equipment: equipment, replaceable: replaceable)
        return all
    }

    /// 這一格排出的正式組數：重點動作完整版 +1、「重量跳太大」多 1 組、適應期／減量週 −1。
    /// 0.30.0：只有每天第一個重點動作（主項）+1，其他重點動作照課表，一次不要練太多組。
    /// 減量週組數減半（至少 1 組）；適應期少 1 組（至少 2 組）。
    static func slotSets(_ slot: Slot, day: DayTemplate, phase: Phase, length: WorkoutLength, extra: Bool) -> Int {
        var sets = slot.sets
        if length == .full && !day.custom && isMainSlot(slot, in: day) { sets += 1 }
        if extra { sets += 1 }
        switch phase {
        case .deload: sets = max(1, (sets + 1) / 2)
        case .rampUp: sets = max(2, sets - 1)
        case .normal: break
        }
        return sets
    }

    /// 這天的主項：第一個重點動作（全身日的格子看原本那一天）。
    static func isMainSlot(_ slot: Slot, in day: DayTemplate) -> Bool {
        guard slot.essential else { return false }
        if let src = slot.source, let origin = template(id: src) {
            return origin.slots.first(where: \.essential)?.pattern == slot.pattern
        }
        return day.slots.first(where: \.essential)?.pattern == slot.pattern
    }

    private static func planned(_ exercise: Exercise, slot: Slot, day: DayTemplate, phase: Phase,
                                length: WorkoutLength, replaced: String?) -> PlannedExercise {
        let sets = slotSets(slot, day: day, phase: phase, length: length, extra: JumpGuard.hasExtraSet(exercise.id))

        // 中階：內建課表的主要動作一天重（6–8 下）、一天輕（12–15 下）；全身日照原本那一天
        var intensity: Intensity? = nil
        if Graduation.intermediateActive, !day.custom, slot.essential, slot.pattern.region != nil,
           exercise.range == nil, exercise.loaded {
            intensity = Graduation.intensity(dayId: slot.source ?? day.id)
        }

        var rest: Int
        switch length {
        case .full: rest = slot.rest ?? (slot.essential ? 120 : 60)
        case .short: rest = min(slot.rest ?? 60, 60)
        case .minimal: rest = 90
        }
        if length == .full, intensity == .heavy { rest = max(rest, 150) }
        if length == .full, intensity == .light { rest = min(rest, 90) }

        let range = exercise.range ?? intensity?.range ?? slot.low...slot.high
        // 「重量跳太大」暫時拉長的次數上限、降低的次數範圍
        let adj = JumpGuard.adjust(id: exercise.id, low: range.lowerBound, high: range.upperBound)
        return PlannedExercise(
            exercise: exercise,
            sets: length == .minimal ? 1 : sets,
            low: adj.low,
            high: adj.high,
            base: range,
            restSeconds: rest,
            essential: slot.essential,
            replaced: replaced,
            intensity: intensity
        )
    }

    // MARK: 升級遷移與「換一個動作」

    /// 目前的設定（給不在 View 裡、要自己排課的地方用）。
    private static func currentSetup() -> (equipment: Set<Equipment>, limitBarbell: Bool, gym: Bool, week: Int) {
        let d = UserDefaults.standard
        let place = TrainingPlace(rawValue: d.string(forKey: Keys.place) ?? "") ?? .home
        let limit = (d.object(forKey: Keys.limitBarbell) as? Bool ?? true) && place == .home
        let start = d.double(forKey: Keys.startDate)
        let week = start > 0 ? Stats.week(since: Date(timeIntervalSince1970: start)) : 1
        return (place.equipment(homeRaw: d.string(forKey: Keys.equipment) ?? ""), limit, place == .gym, week)
    }

    /// 0.23.0 升級遷移：複合動作不再每 6 週輪替。舊規則在第 2 個區塊以後會選另一個動作，
    /// 為了讓使用者正在練的動作不變，把「舊規則和新規則的差」寫進 `PatternShift`。只做一次，要在第一次排課前呼叫。
    static func migrateV023() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Keys.pinnedV023) else { return }
        defer { d.set(true, forKey: Keys.pinnedV023) }
        // 還沒設定過的新使用者，直接用新規則
        guard d.bool(forKey: Keys.onboarded), d.double(forKey: Keys.startDate) > 0 else { return }
        let setup = currentSetup()
        let block = block(week: setup.week)
        guard block > 0 else { return }
        let templates = builtInDays + CustomPrograms.visible.flatMap { CustomPrograms.templates($0) }
        var shifts = PatternShift.store.load()
        for t in templates {
            for slot in t.slots where slot.pattern.region != nil && !slot.keepBarbell && slot.exerciseId == nil {
                let n = topChoices(slot: slot, equipment: setup.equipment, limitBarbell: setup.limitBarbell).count
                guard n > 1 else { continue }
                // (舊: block + variant) % n = (新: variant + 位移) % n，所以位移 = block % n
                let shift = block % n
                if shift > 0 { shifts[PatternShift.key(day: t.id, pattern: slot.pattern)] = shift }
            }
        }
        PatternShift.store.save(shifts)
    }

    /// 現在課表裡排到這個動作、而且能換成別的候選的課表格（key 是 "dayId|pattern"）。
    /// 自訂課表指定動作的格子不算（那是使用者自己選的）。
    static func shiftKeys(exerciseId: String) -> [String] {
        let setup = currentSetup()
        var keys: [String] = []
        for day in days {
            let raw = rawPlan(day: day, equipment: setup.equipment, week: setup.week, length: .full,
                              limitBarbell: setup.limitBarbell)
            for (k, item) in raw.items.enumerated() where item.exercise.id == exerciseId {
                let slot = day.slots[raw.slotOf[k]]
                guard slot.exerciseId == nil, !slot.keepBarbell else { continue }
                // 排除這個動作之後還有別的候選，換才有意義
                let others = topChoices(slot: slot, equipment: setup.equipment, limitBarbell: setup.limitBarbell)
                    .filter { $0.id != exerciseId }
                if !others.isEmpty { keys.append(PatternShift.key(day: day.id, pattern: slot.pattern)) }
            }
        }
        return keys
    }

    /// 停滯時按「換一個動作」：這個動作所在的課表格，下次選動作往後換一個。
    @discardableResult
    static func shiftExercise(_ exerciseId: String) -> Bool {
        let keys = shiftKeys(exerciseId: exerciseId)
        for key in keys { PatternShift.bump(key) }
        return !keys.isEmpty
    }

    /// 照實際排出來的組（含熱身）、換重量和組槓鈴的時間估算。
    static func estimatedMinutes(_ plan: [PlannedExercise], sessions: [WorkoutSession], gym: Bool, increment: Double,
                                 autoWarmup: Bool, week: Int, length: WorkoutLength) -> Int {
        WorkoutTimeEstimator.minutes(plan: plan, sessions: sessions, gym: gym, increment: increment,
                                     autoWarmup: autoWarmup, week: week, length: length)
    }

    static func estimatedMinutes(_ plan: [PlannedExercise]) -> Int {
        let seconds = plan.reduce(0) { $0 + $1.sets * (45 + $1.restSeconds) }
        return max(5, Int((Double(seconds) / 60).rounded()) + 5)
    }

    /// 下一次練哪一天（0.25.0 起以週為單位）：這週答應併成的全身日 → 課表裡這週還沒練的第一天 →
    /// 這週都練完了（多練）才照上次的下一天輪。所以一週沒練完，下週還是從第一天開始（少的那天用「併成全身日」補）。
    /// 0.51.0 起：這週還沒練的天裡，挑主要肌肉最恢復的（`MuscleStats.readiness`）；差不多（差距 < `pickMargin`）就照課表順序。
    static func nextDay(after sessions: [WorkoutSession], now: Date = .now) -> DayTemplate {
        let days = self.days
        if let merged = WeekFit.acceptedDay(sessions: sessions) { return merged }
        let done = WeekFit.doneThisWeek(sessions)
        let left = days.filter { !done.contains($0.id) }
        if let first = left.first {
            return mostRecovered(left, sessions: sessions, now: now) ?? first
        }
        guard let last = sessions.first,
              let idx = days.firstIndex(where: { $0.id == WeekFit.parts(last.dayKey).last }) else {
            return days[0]
        }
        return days[(idx + 1) % days.count]
    }

    /// 恢復度要比課表順序的第一天高這麼多，才換成別天（避免為了一點點差距跳來跳去）。
    static let pickMargin = 0.15

    /// 候選天（照課表順序）裡挑主要肌肉最恢復的；第一天就夠好或算不出來回 nil。
    static func mostRecovered(_ candidates: [DayTemplate], sessions: [WorkoutSession], now: Date = .now) -> DayTemplate? {
        guard candidates.count > 1, let first = candidates.first else { return nil }
        let rec = MuscleStats.recovery(sessions, now: now)
        let base = MuscleStats.readiness(first, recovery: rec) ?? 1
        var best: (day: DayTemplate, score: Double)?
        for d in candidates.dropFirst() {
            guard let s = MuscleStats.readiness(d, recovery: rec), s >= base + pickMargin else { continue }
            if best == nil || s > best!.score { best = (d, s) }
        }
        return best?.day
    }
}

struct Suggestion {
    let weight: Double
    let reps: Int
    let note: String
    /// 建議文字旁邊要不要放 ⓘ 說明（重量跳太大時）
    var tip: Glossary? = nil
}

enum Progression {
    /// Sets from the most recent session that included this exercise.
    /// `sessions` must be sorted newest first.
    /// 減量週、刻意減輕的那一次（練前狀態很差、會痛先減輕）不算基準，不然減量完會卡在減輕的重量（`SessionPhase`）。
    /// 找不到正常的那一次，才退回用最近一次。
    static func lastSets(for exerciseId: String, in sessions: [WorkoutSession]) -> [SetEntry] {
        var fallback: [SetEntry] = []
        for session in sessions {
            let sets = session.entries.filter { $0.exerciseId == exerciseId && $0.isWork }
            if sets.isEmpty { continue }
            let sorted = sets.sorted { $0.setIndex < $1.setIndex }
            if SessionPhase.isBaseline(session, sets: sorted) { return sorted }
            if fallback.isEmpty { fallback = sorted }
        }
        return fallback
    }

    /// ladder：這個動作裝得出來的重量（沒有設定器材時用固定級距）。
    static func suggest(_ item: PlannedExercise, last: [SetEntry], phase: Phase, ladder: WeightLadder,
                        scheme: SetScheme = .straight) -> Suggestion {
        let ex = item.exercise
        guard !last.isEmpty else {
            guard ex.loaded else { return Suggestion(weight: 0, reps: item.low, note: "第一次做：先把動作做標準") }
            if let est = StartWeight.estimate(item, ladder: ladder) {
                let w = phase == .deload ? ladder.snap(est.weight * 0.8) : est.weight
                return Suggestion(weight: w, reps: item.high,
                                  note: "第一次做：參考「\(est.reference.name)」推估。第一組做完填還剩幾下，後面會自動校準",
                                  tip: .startWeight)
            }
            if let w = StartWeight.noviceEstimate(item, ladder: ladder) {
                let note = LevelTest.current != nil ? "第一次做：依你的程度評估推估一個保守的重量"
                    : StartWeight.bodyWeight > 0 ? "第一次做：依你的體重推估一個保守的重量（設定裡做程度評估會更準）"
                    : "第一次做：先用一個保守的重量（設定裡做程度評估會推得更準）"
                return Suggestion(weight: phase == .deload ? ladder.snap(w * 0.8) : w, reps: item.high,
                                  note: note + "。第一組做完填還剩幾下，後面會自動校準", tip: .startWeight)
            }
            return Suggestion(weight: 0, reps: item.high,
                              note: "第一次做：選一個能輕鬆做 \(item.high) \(ex.unit.label)的重量，第一組做完填還剩幾下，後面會自動校準",
                              tip: .startWeight)
        }

        let lastWeight = last.map(\.weight).max() ?? 0
        // 只看最重的那幾組（遞增／遞減組的輕組不算）
        let top = last.filter { $0.weight >= lastWeight }
        let bestReps = top.map(\.reps).max() ?? item.low
        let target = SetPlanner.targetReps(scheme: scheme, low: item.low, high: item.high)
        let allHitTop = top.allSatisfy { $0.reps >= target }

        // 停練 10 天以上回來：先減重；減重後全部達標就回到停練前的重量（減量週照減量週）
        if phase != .deload,
           let back = Comeback.suggest(item, lastWeight: lastWeight, bestReps: bestReps, allHit: allHitTop, ladder: ladder) {
            return back
        }

        switch phase {
        case .deload:
            return Suggestion(weight: ex.loaded ? ladder.snap(lastWeight * 0.9) : lastWeight, reps: item.low,
                              note: "減量週：組數減半、重量減輕約一成，輕鬆做完")
        case .rampUp:
            return Suggestion(weight: lastWeight, reps: min(bestReps, item.high),
                              note: "適應期：用上次的重量，別拚到力竭")
        case .normal:
            // 中階：次數範圍換成重日／輕日，上次的重量差太多時用推估最大力量換算
            if let sw = Graduation.rangeSwitch(item, top: top, lastWeight: lastWeight, ladder: ladder) {
                return sw
            }
            if ex.loaded, let t = JumpGuard.tempRange(ex.id) {
                if lastWeight <= t.from + 0.01 {
                    // 上次決定「加重但暫時降低次數」，這次換上新重量
                    let next = ladder.up(lastWeight)
                    if next > lastWeight + 0.01 { return tempJump(item, from: lastWeight, next: next, low: t.low) }
                } else if allHitTop {
                    return Suggestion(weight: lastWeight, reps: min(bestReps + 1, item.baseHigh),
                                      note: JumpGuard.recoveredNote(item), tip: .bigJump)
                }
            }
            if allHitTop {
                // 全部達標但每組都做到力竭：先用同重量做得輕鬆一點，下次再加
                if ex.loaded && RIRCheck.grinding(top) {
                    return Suggestion(weight: lastWeight, reps: item.high,
                                      note: "上次每組都做到力竭才達標：這次同重量，做到還剩 1 下就好，做得輕鬆再加重")
                }
                if ex.loaded {
                    let next = ladder.up(lastWeight)
                    if next <= lastWeight + 0.01 {
                        if let up = Upgrade.target(for: ex, equipment: Upgrade.currentEquipment) {
                            return Suggestion(weight: lastWeight, reps: item.high,
                                              note: "已經是你器材最重的了：這次全部做到 \(item.high) 下，下次自動換成更難的「\(up.name)」")
                        }
                        if item.intensity == .heavy {
                            return Suggestion(weight: lastWeight, reps: item.high,
                                              note: "器材最重了：重日改慢速（下放 3 秒、最低點停 1 秒）做 \(item.low)–\(item.high) 下，或按「換一個動作」換單側版本")
                        }
                        return Suggestion(weight: lastWeight, reps: bestReps + 1,
                                          note: "已經是你器材最重的了，改成多做 1 下，或下放放慢到 3 秒")
                    }
                    return loadedJump(item, lastWeight: lastWeight, top: top, next: next, ladder: ladder)
                }
                // 徒手要連續 2 次都做到上限才升級（`Upgrade.ready`）：上次做到了，這次再做到就換
                if ex.unit == .reps, let up = Upgrade.target(for: ex, equipment: Upgrade.currentEquipment) {
                    return Suggestion(weight: lastWeight, reps: item.high,
                                      note: "上次每組都做到 \(item.high) 下：這次再全部做到，下次自動換成更難的「\(up.name)」")
                }
                return Suggestion(weight: lastWeight, reps: item.high,
                                  note: "已經達標，下放放慢到 3 秒增加難度")
            }
            return Suggestion(weight: lastWeight, reps: min(bestReps + 1, item.high),
                              note: "目標：比上次多做 1 \(ex.unit.label)")
        }
    }

    /// 有負重、全部達標、下一級比較重：先估加重後能做幾下，跳太大就走「延長」（`JumpGuard`）。
    private static func loadedJump(_ item: PlannedExercise, lastWeight: Double, top: [SetEntry], next: Double,
                                   ladder: WeightLadder) -> Suggestion {
        let bestReps = top.map(\.reps).max() ?? item.low
        // 上次已經決定「先多做 1 組」：這次照排（組數已經 +1），全部做到上限才加重
        if JumpGuard.hasExtraSet(item.exercise.id) {
            return Suggestion(weight: lastWeight, reps: item.high,
                              note: "重量跳太大，次數上限已到，這次多做 1 組（共 \(item.sets) 組），全部做到 \(item.high) \(item.exercise.unit.label)再加重",
                              tip: .bigJump)
        }
        let unit = item.exercise.unit.label
        switch JumpGuard.evaluate(item: item, lastWeight: lastWeight, top: top, next: next) {
        case .heavy(let reps):
            return Suggestion(weight: next, reps: reps, note: raiseNote(next, from: lastWeight, ladder: ladder))
        case .extend(let ceiling, let pct):
            return Suggestion(weight: lastWeight, reps: min(bestReps + 1, ceiling),
                              note: "重量跳太大（+\(pct)%），先做到 \(ceiling) \(unit)再加重", tip: .bigJump)
        case .extraSet(let pct):
            return Suggestion(weight: lastWeight, reps: item.high,
                              note: "重量跳太大（+\(pct)%），次數上限已到，下次多做 1 組再加重", tip: .bigJump)
        case .heavyTemp(_, let low, _, _):
            return tempJump(item, from: lastWeight, next: next, low: low)
        }
    }

    /// 加重，但次數會掉很多：暫時用較低的次數範圍（`JumpGuard.tempRange`）爬回原本的範圍。
    private static func tempJump(_ item: PlannedExercise, from last: Double, next: Double, low: Int) -> Suggestion {
        let unit = item.exercise.unit.label
        let note = "加重 \(format(next - last)) kg 後次數會掉到約 \(low) \(unit)，先用 \(low)–\(item.baseLow) \(unit)爬回原本範圍"
        return Suggestion(weight: next, reps: low, note: note, tip: .bigJump)
    }

    private static func raiseNote(_ next: Double, from last: Double, ladder: WeightLadder) -> String {
        var note = "上次全部達標 💪 加重 \(format(next - last)) kg"
        if let l = ladder.loading(next) { note += "（\(l.text)）" }
        return note
    }

    static func roundHalf(_ x: Double) -> Double {
        (x * 2).rounded() / 2
    }

    static func format(_ x: Double) -> String {
        x == x.rounded() ? String(Int(x)) : String(format: "%.1f", x)
    }
}

enum Stats {
    static var calendar: Calendar { SharedStore.calendar }

    static func weekStart(_ date: Date) -> Date {
        SharedStore.weekStart(date)
    }

    static func sessionsThisWeek(_ sessions: [WorkoutSession]) -> Int {
        SharedStore.countThisWeek(sessions.map(\.date))
    }

    /// 每週練 2 次以上的連續週數；請假週、用掉保護卡的週不會中斷。
    static func weekStreak(_ sessions: [WorkoutSession]) -> Int {
        GoalEngine.streak(dates: sessions.map(\.date))
    }

    /// 程式第幾週；停練暫停的週不算（`TrainingPause`）。
    static func week(since start: Date, at date: Date = .now) -> Int {
        TrainingPause.week(since: start, at: date, pauses: TrainingPause.current)
    }

    /// True when the most recent planned training day before today passed with no workout
    /// on or after it. Without planned weekdays, falls back to "3+ days since last workout".
    /// `sessions` must be sorted newest first.
    static func missedLastPlanned(_ sessions: [WorkoutSession], weekdays: Set<Int>) -> Bool {
        guard let last = sessions.first?.date else { return false }
        let cal = Calendar.current
        if cal.isDateInToday(last) { return false }
        let today = cal.startOfDay(for: .now)

        if weekdays.isEmpty {
            let gap = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: today).day ?? 0
            return gap >= 3
        }
        for back in 1...7 {
            let day = cal.date(byAdding: .day, value: -back, to: today)!
            if weekdays.contains(cal.component(.weekday, from: day)) {
                return last < day
            }
        }
        return false
    }
}
