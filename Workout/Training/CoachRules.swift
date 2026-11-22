import Foundation

extension Keys {
    /// 器材到頂自動升級的動作，JSON [原本 exerciseId: 升級後 exerciseId]（`Upgrade`）
    static let upgrades = "upgrades"
}

// MARK: - 關節（會痛之後的提醒）

/// 動作主要吃力的關節。某個動作最近回報會痛，同一個關節的其他動作在訓練時提醒先輕一點（0.30.0）。
enum Joint: String {
    case shoulder, elbow, lowerBack, knee, hip

    var title: String {
        switch self {
        case .shoulder: "肩膀"
        case .elbow: "手肘"
        case .lowerBack: "下背"
        case .knee: "膝蓋"
        case .hip: "髖部"
        }
    }

    static func of(_ p: MovementPattern) -> Joint? {
        switch p {
        case .hPush, .incline, .vPush, .vPull, .lateral, .rear: .shoulder
        case .hPull, .biceps, .triceps: .elbow
        case .hinge, .core: .lowerBack
        case .squat, .lunge, .hamCurl, .quadIso: .knee
        case .glute: .hip
        case .calf: nil
        }
    }

    /// 最近 14 天回報會痛（減輕或換掉）的動作，各自的關節 → 最近那次的動作名稱。
    static func recentPain(now: Date = .now) -> [Joint: String] {
        let from = now.addingTimeInterval(-14 * 86400).timeIntervalSince1970
        var ids: [(String, Double)] = Avoid.painLog().filter { $0.date >= from }.map { ($0.exerciseId, $0.date) }
        for (id, e) in Avoid.store.load() where e.kind == .pain && e.date >= from { ids.append((id, e.date)) }
        var out: [Joint: (String, Double)] = [:]
        for (id, date) in ids {
            guard let ex = ExerciseLibrary.byId(id), let j = of(ex.pattern) else { continue }
            if let cur = out[j], cur.1 >= date { continue }
            out[j] = (ex.name, date)
        }
        return out.mapValues { $0.0 }
    }

    /// 訓練卡片上的提醒；這個動作本身或關節沒問題就是 nil。
    static func caution(for ex: Exercise, pain: [Joint: String]) -> String? {
        guard let j = of(ex.pattern), let name = pain[j], name != ex.name else { return nil }
        return "最近「\(name)」\(j.title)不舒服：這個動作也會用到\(j.title)，先用輕一點的重量，會痛就停"
    }
}

// MARK: - 器材到頂：升級成更難的版本

/// 在家啞鈴加到最重、每組又都做到次數上限，就自動換成同類型裡「同樣重量更難」的動作（0.30.0）。
enum Upgrade {
    static let store = KeyedStore<String>(key: Keys.upgrades)

    /// 原本 → 更難的版本（同一個動作類型，部位計算不變）。
    static let paths: [String: String] = [
        "goblet_squat": "goblet_15",
        "heel_goblet": "goblet_15",
        "db_squat": "goblet_15",
        "db_rdl": "db_sl_rdl",
        "db_glute_bridge": "db_hip_thrust",
    ]

    /// 排課用：這個動作已經升級過、升級後的動作現在排得了，就回傳升級後的動作。
    static func replacement(for ex: Exercise, equipment: Set<Equipment>, used: Set<String>) -> Exercise? {
        guard let to = store.load()[ex.id], !used.contains(to), let up = ExerciseLibrary.byId(to),
              up.requires.isSubset(of: equipment), !Avoid.isAvoided(to) else { return nil }
        return up
    }

    /// 練完存檔時：重量已經是器材最重、每個正式組都做到次數上限 → 記下升級。回傳升級後的動作。
    @discardableResult
    static func record(item: PlannedExercise, work: [(weight: Double, reps: Int)], ladder: WeightLadder,
                       equipment: Set<Equipment>) -> Exercise? {
        let ex = item.exercise
        guard ex.loaded, !ladder.isEmpty, let to = paths[ex.id], store.load()[ex.id] == nil,
              let up = ExerciseLibrary.byId(to), up.requires.isSubset(of: equipment), !Avoid.isAvoided(to),
              let top = work.map(\.weight).max(), top > 0, ladder.up(top) <= top + 0.01,
              work.allSatisfy({ $0.reps >= item.high }) else { return nil }
        store[ex.id] = to
        return up
    }

    /// 給建議文字用：到頂又全部達標時，下次會換成什麼。
    static func next(for ex: Exercise) -> Exercise? {
        paths[ex.id].flatMap(ExerciseLibrary.byId)
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
