import Foundation

/// 一種槓片：重量 × 片數（整組的總片數）
struct PlateStack: Codable, Hashable, Identifiable {
    var id = UUID()
    var kg: Double
    var count: Int
}

/// 一組可調式啞鈴（兩支把手＋一堆槓片）。用來算「實際裝得出來的重量」和「每邊要裝哪幾片」。
struct WeightKit: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// 一支把手的重量（含鎖頭／固定環）
    var handle: Double
    var plates: [PlateStack]
    /// 兩支把手可以用連接桿接成槓鈴
    var makesBarbell = false
    /// 連接桿重量
    var connector = 0.0
    /// 槓片可以掛到下拉架上
    var onCable = false
}

/// 一個裝得出來的重量，和要怎麼裝
struct Loading: Hashable {
    let weight: Double
    let kit: String
    /// 每邊要裝的槓片（由重到輕）；滑輪則是全部要掛的片
    let plates: [Double]
    let cable: Bool

    var text: String {
        let list = plates.isEmpty ? "只有把手" : plates.map(Progression.format).joined(separator: " + ")
        return cable ? "\(kit)：掛 \(list)" : "\(kit)：每邊 \(list)"
    }
}

enum WeightKits {
    /// 用法：兩手各一支、只拿一支、接成槓鈴、掛在下拉架
    enum Use { case pair, single, barbell, cable }

    static let defaults: [WeightKit] = [
        WeightKit(name: "Tixteel", handle: 2.0,
                  plates: [PlateStack(kg: 2.5, count: 12), PlateStack(kg: 1.25, count: 4)]),
        WeightKit(name: "舊啞鈴", handle: 1.0,
                  plates: [PlateStack(kg: 3, count: 8), PlateStack(kg: 2.5, count: 4), PlateStack(kg: 1.25, count: 4)],
                  makesBarbell: true, connector: 0.5, onCable: true),
    ]

    static func load() -> [WeightKit] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.kits) else { return defaults }
        guard let data = raw.data(using: .utf8),
              let kits = try? JSONDecoder().decode([WeightKit].self, from: data) else { return defaults }
        return kits
    }

    static func save(_ kits: [WeightKit]) {
        if let data = try? JSONEncoder().encode(kits), let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: Keys.kits)
        }
    }

    /// 只拿一支啞鈴的動作（單手划船、高腳杯深蹲、臀推⋯）：整組槓片都能裝在同一支上。
    static let singleDumbbell: Set<String> = [
        "goblet_squat", "db_row", "db_overhead_ext", "db_hip_thrust", "db_glute_bridge",
        "db_calf_raise", "db_sl_rdl", "db_leg_curl", "db_lean_lateral",
    ]

    static func use(for ex: Exercise) -> Use? {
        guard ex.loaded else { return nil }
        if ex.requires.contains(.barbell) { return .barbell }
        if ex.requires.contains(.dumbbell) { return singleDumbbell.contains(ex.id) ? .single : .pair }
        if ex.requires.contains(.cable) { return .cable }
        return nil
    }

    /// 這個動作在家裝得出來的重量（由輕到重）。
    /// 第一組器材（主要啞鈴）優先；後面的器材只補「比前面最重還重」的重量，加重時才不會一直換啞鈴。
    /// 回傳空陣列＝沒有設定器材（例如健身房），改用「每次加重」的設定。
    static func loadings(for ex: Exercise, kits: [WeightKit] = load()) -> [Loading] {
        guard let use = use(for: ex) else { return [] }
        var result: [Loading] = []
        for kit in kits {
            let ceiling = result.last?.weight ?? -1
            let options = loadings(kit, use).sorted {
                $0.weight != $1.weight ? $0.weight < $1.weight : $0.plates.count < $1.plates.count
            }
            for l in options where l.weight > ceiling + 0.01 {
                if let last = result.last, abs(last.weight - l.weight) < 0.01 { continue }
                result.append(l)
            }
        }
        // 槓鈴、滑輪的組合很細，加重一級太少：相鄰兩級至少差 2.5 kg／1.25 kg
        let gap: Double
        switch use {
        case .barbell: gap = 2.5
        case .cable: gap = 1.25
        default: return result
        }
        var thin: [Loading] = []
        for l in result where thin.isEmpty || l.weight - thin[thin.count - 1].weight >= gap - 0.01 {
            thin.append(l)
        }
        return thin
    }

    static func loadings(_ kit: WeightKit, _ use: Use) -> [Loading] {
        let base: Double
        // 每種槓片「每邊」最多幾片（滑輪：全部都能掛，不分邊）
        let limits: [(Double, Int)]
        switch use {
        case .pair:
            base = kit.handle
            limits = kit.plates.map { ($0.kg, $0.count / 4) }
        case .single:
            base = kit.handle
            limits = kit.plates.map { ($0.kg, $0.count / 2) }
        case .barbell:
            guard kit.makesBarbell else { return [] }
            base = kit.handle * 2 + kit.connector
            limits = kit.plates.map { ($0.kg, $0.count / 2) }
        case .cable:
            guard kit.onCable else { return [] }
            base = 0
            limits = kit.plates.map { ($0.kg, $0.count) }
        }
        let sides = use == .cable ? 1.0 : 2.0
        var out: [Loading] = []
        func walk(_ i: Int, _ picked: [Double]) {
            if i == limits.count {
                let w = base + sides * picked.reduce(0, +)
                if use == .cable && picked.isEmpty { return }
                out.append(Loading(weight: w, kit: kit.name, plates: picked.sorted(by: >), cable: use == .cable))
                return
            }
            let (kg, n) = limits[i]
            for k in 0...max(0, n) {
                walk(i + 1, picked + Array(repeating: kg, count: k))
            }
        }
        walk(0, [])
        return out
    }
}

/// 一個動作可用的重量階梯。空的時候退回固定級距（設定裡的「每次加重」）。
struct WeightLadder {
    let loadings: [Loading]
    let step: Double

    var weights: [Double] { loadings.map(\.weight) }
    var isEmpty: Bool { loadings.isEmpty }
    var max: Double? { loadings.last?.weight }

    static func make(_ ex: Exercise, gym: Bool, step: Double) -> WeightLadder {
        WeightLadder(loadings: gym ? [] : WeightKits.loadings(for: ex), step: step)
    }

    /// 比 w 重的下一級
    func up(_ w: Double) -> Double {
        guard !isEmpty else { return w + step }
        return weights.first { $0 > w + 0.01 } ?? w
    }

    /// 比 w 輕的下一級
    func down(_ w: Double) -> Double {
        guard !isEmpty else { return Swift.max(0, w - step) }
        return weights.last { $0 < w - 0.01 } ?? (weights.first ?? w)
    }

    /// 不超過 w 的最近一級（熱身、遞增組、減量週用）
    func snap(_ w: Double) -> Double {
        guard !isEmpty else { return SetPlanner.round(w, step: step) }
        return weights.last { $0 <= w + 0.01 } ?? (weights.first ?? w)
    }

    func loading(_ w: Double) -> Loading? {
        loadings.first { abs($0.weight - w) < 0.01 }
    }
}
