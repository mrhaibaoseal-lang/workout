import Foundation

extension Keys {
    /// 器材到頂自動升級的動作，JSON [原本 exerciseId: 升級後 exerciseId]（`Upgrade`）
    static let upgrades = "upgrades"
}

// MARK: - 關節（會痛之後的提醒）

/// 動作吃力的關節。「會痛…」時使用者自己選哪裡痛（0.32.0）；同一個關節的其他動作在訓練時提醒先輕一點。
enum Joint: String, CaseIterable, Identifiable {
    case shoulder, elbow, lowerBack, knee, hip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shoulder: "肩膀"
        case .elbow: "手肘"
        case .lowerBack: "下背"
        case .knee: "膝蓋"
        case .hip: "髖部"
        }
    }

    /// 這類動作會用到的關節，最吃力的在前。舊的痛紀錄沒有關節時，用第一個推測。
    static func involved(_ p: MovementPattern) -> [Joint] {
        switch p {
        case .hPush, .incline, .vPush: [.shoulder, .elbow]
        case .vPull, .hPull: [.shoulder, .elbow, .lowerBack]
        case .lateral, .rear: [.shoulder]
        case .biceps, .triceps: [.elbow, .shoulder]
        case .hinge: [.lowerBack, .hip, .knee]
        case .core: [.lowerBack, .hip]
        case .squat, .lunge: [.knee, .hip, .lowerBack]
        case .hamCurl, .quadIso: [.knee]
        case .glute: [.hip, .lowerBack, .knee]
        case .calf: []
        }
    }

    static func of(_ p: MovementPattern) -> Joint? { involved(p).first }

    /// 「會痛…」選單的順序：這個動作會用到的關節在前，其他的接在後面。
    static func menuOrder(for p: MovementPattern) -> [Joint] {
        let first = involved(p)
        return first + allCases.filter { !first.contains($0) }
    }

    /// 最近 14 天回報會痛的關節 → 最近那次的動作名稱。
    /// 紀錄有選關節就用選的；舊紀錄（0.32.0 以前）用動作類型推測。
    static func recentPain(now: Date = .now, log: [PainRecord] = Avoid.painLog(),
                           marked: [String: AvoidEntry] = Avoid.store.load()) -> [Joint: String] {
        let from = now.addingTimeInterval(-14 * 86400).timeIntervalSince1970
        var hits: [(Joint, String, Double)] = []
        for r in log where r.date >= from {
            guard let ex = ExerciseLibrary.byId(r.exerciseId),
                  let j = r.joint.flatMap(Joint.init(rawValue:)) ?? of(ex.pattern) else { continue }
            hits.append((j, ex.name, r.date))
        }
        // 標記「會痛、不排」的動作都會另外寫一筆痛紀錄；只有更早、沒有紀錄的才靠推測。
        let logged = Set(log.map(\.exerciseId))
        for (id, e) in marked where e.kind == .pain && e.date >= from && !logged.contains(id) {
            guard let ex = ExerciseLibrary.byId(id), let j = of(ex.pattern) else { continue }
            hits.append((j, ex.name, e.date))
        }
        var out: [Joint: (String, Double)] = [:]
        for (j, name, date) in hits {
            if let cur = out[j], cur.1 >= date { continue }
            out[j] = (name, date)
        }
        return out.mapValues { $0.0 }
    }

    /// 訓練卡片上的提醒；這個動作本身或用到的關節都沒問題就是 nil。
    static func caution(for ex: Exercise, pain: [Joint: String]) -> String? {
        for j in involved(ex.pattern) {
            guard let name = pain[j], name != ex.name else { continue }
            return "最近「\(name)」\(j.title)不舒服：這個動作也會用到\(j.title)，先用輕一點的重量，會痛就停"
        }
        return nil
    }
}

// MARK: - 器材到頂：升級成更難的版本

/// 在家啞鈴加到最重、每組又都做到次數上限，就自動換成同類型裡「同樣重量更難」的動作（0.30.0）。
/// 徒手動作每組都做到次數上限，也換成同類型更難的版本（0.33.0）；可以一路升好幾級（伏地挺身 → 暫停 → 弓箭手）。
enum Upgrade {
    static let store = KeyedStore<String>(key: Keys.upgrades)

    /// 原本 → 更難的版本（同一個動作類型，部位計算不變）。
    static let paths: [String: String] = [
        // 負重：啞鈴到頂
        "goblet_squat": "goblet_15",
        "heel_goblet": "goblet_15",
        "db_squat": "goblet_15",
        "db_rdl": "db_sl_rdl",
        "db_glute_bridge": "db_hip_thrust",
        // 徒手：次數做到上限
        "pushup": "pause_pushup",
        "pause_pushup": "archer_pushup",
        "pike_pushup": "elevated_pike",
        "squat": "slow_squat",
        "reverse_lunge": "split_squat",
        "split_squat": "pause_split_squat",
        "sl_glute_bridge": "sl_hip_thrust",
        "towel_leg_curl": "sl_towel_leg_curl",
        "bench_dip": "elevated_bench_dip",
        "calf_raise": "pause_calf_raise",
        "dead_bug": "reverse_crunch",
    ]

    /// 排課用：這個動作升級過，就一路換到最後一級現在排得了的版本。
    static func replacement(for ex: Exercise, equipment: Set<Equipment>, used: Set<String>) -> Exercise? {
        replacement(for: ex, equipment: equipment, used: used, upgrades: store.load())
    }

    static func replacement(for ex: Exercise, equipment: Set<Equipment>, used: Set<String>,
                            upgrades: [String: String]) -> Exercise? {
        var current: Exercise? = nil
        var id = ex.id
        var seen: Set<String> = [id]
        while let to = upgrades[id], !seen.contains(to) {
            seen.insert(to)
            guard !used.contains(to), let up = ExerciseLibrary.byId(to),
                  up.requires.isSubset(of: equipment), !Avoid.isAvoided(to) else { break }
            current = up
            id = to
        }
        return current
    }

    /// 這組成績夠不夠升級：負重要已經是器材最重；徒手只看次數。每個正式組都要做到次數上限。
    static func qualifies(_ ex: Exercise, high: Int, work: [(weight: Double, reps: Int)], ladder: WeightLadder) -> Bool {
        guard !work.isEmpty, work.allSatisfy({ $0.reps >= high }) else { return false }
        if ex.loaded {
            guard !ladder.isEmpty, let top = work.map(\.weight).max(), top > 0 else { return false }
            return ladder.up(top) <= top + 0.01
        }
        return ex.unit == .reps
    }

    /// 升級的目標：還沒升級過、有路線、器材夠、沒設成避開。建議文字和存檔共用同一個判斷，
    /// 建議才不會答應做不到的升級（例如沒有椅子卻說「下次換成腳抬高屈體伏地挺身」）。
    static func target(for ex: Exercise, equipment: Set<Equipment>) -> Exercise? {
        target(for: ex, equipment: equipment, upgrades: store.load())
    }

    static func target(for ex: Exercise, equipment: Set<Equipment>, upgrades: [String: String]) -> Exercise? {
        guard upgrades[ex.id] == nil, let to = paths[ex.id], let up = ExerciseLibrary.byId(to),
              up.requires.isSubset(of: equipment), !Avoid.isAvoided(to) else { return nil }
        return up
    }

    /// 目前地點的器材（`Progression.suggest` 沒有傳器材進來時用）。
    static var currentEquipment: Set<Equipment> {
        let d = UserDefaults.standard
        return ProgramBuilder.equipment(place: d.string(forKey: Keys.place) ?? TrainingPlace.home.rawValue,
                                        homeRaw: d.string(forKey: Keys.equipment) ?? "")
    }

    /// 夠不夠升級：負重到器材最重、這次每組做到上限就夠；徒手要這次和上一次（`previous`）都每組做到上限
    /// （連續 2 次：一次做到可能只是那天狀態好，或沒改預填的次數就按完成）。
    static func ready(_ ex: Exercise, high: Int, work: [(weight: Double, reps: Int)],
                      previous: [(weight: Double, reps: Int)], ladder: WeightLadder) -> Bool {
        guard qualifies(ex, high: high, work: work, ladder: ladder) else { return false }
        return ex.loaded || qualifies(ex, high: high, work: previous, ladder: ladder)
    }

    /// 練完存檔時：成績夠（`ready`）就記下升級。回傳升級後的動作。
    /// previous：上一次做這個動作的正式組（不含減輕的組）。
    @discardableResult
    static func record(item: PlannedExercise, work: [(weight: Double, reps: Int)],
                       previous: [(weight: Double, reps: Int)], ladder: WeightLadder,
                       equipment: Set<Equipment>) -> Exercise? {
        let ex = item.exercise
        guard let up = target(for: ex, equipment: equipment),
              ready(ex, high: item.high, work: work, previous: previous, ladder: ladder) else { return nil }
        store[ex.id] = up.id
        return up
    }
}

// MARK: - 「還剩幾下」校準

/// 新手常低估自己還能做幾下。同重量的下一組明顯做不到「上一組次數 + 填的剩幾下」附近，就提醒（0.30.0）。
enum RIRCheck {
    /// prev：上一個正式組，cur：剛做完的同重量正式組。回傳提醒文字或 nil。
    static func hint(prevReps: Int, prevRir: Int, prevWeight: Double, curReps: Int, curWeight: Double) -> String? {
        guard prevRir >= 2, abs(prevWeight - curWeight) < 0.01, curReps > 0 else { return nil }
        // 上一組說還剩 ≥2 下，這組卻比上一組少 3 下以上：上一組其實已經很接近力竭
        guard curReps <= prevReps - 3 else { return nil }
        return "上一組填還剩 \(prevRir) 下，這組卻少了 \(prevReps - curReps) 下：上一組其實比你想的更接近極限，下次可以填少一點"
    }

    /// 全部達標但每一組都做到力竭（還剩 0 下）：先不加重，同重量做得輕鬆一點再加。
    static func grinding(_ top: [SetEntry]) -> Bool {
        let filled = top.filter { $0.rir >= 0 }
        return !filled.isEmpty && filled.count == top.count && filled.allSatisfy { $0.rir == 0 }
    }
}
