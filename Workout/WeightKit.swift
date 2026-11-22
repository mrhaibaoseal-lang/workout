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
    /// 一支把手拆下再鎖上鎖頭要幾秒（快鎖很快，旋轉固定環比較慢）
    var lockSeconds = 8.0
    /// 拿下或裝上一片要幾秒
    var plateSeconds = 3.0
    /// 兩支把手接成槓鈴（或拆回來）要幾秒
    var assembleSeconds = 90.0
}

extension WeightKit {
    /// 舊版存檔沒有後來加的欄位，缺的用預設值。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "啞鈴"
        handle = try c.decodeIfPresent(Double.self, forKey: .handle) ?? 1
        plates = try c.decodeIfPresent([PlateStack].self, forKey: .plates) ?? []
        makesBarbell = try c.decodeIfPresent(Bool.self, forKey: .makesBarbell) ?? false
        connector = try c.decodeIfPresent(Double.self, forKey: .connector) ?? 0
        onCable = try c.decodeIfPresent(Bool.self, forKey: .onCable) ?? false
        lockSeconds = try c.decodeIfPresent(Double.self, forKey: .lockSeconds) ?? 8
        plateSeconds = try c.decodeIfPresent(Double.self, forKey: .plateSeconds) ?? 3
        assembleSeconds = try c.decodeIfPresent(Double.self, forKey: .assembleSeconds) ?? 90
    }
}

/// 一組器材現在裝成什麼樣子（換重量要花多久，從這裡算）
struct RigState: Equatable {
    var use: WeightKits.Use
    /// 每邊的槓片（滑輪：全部掛上去的片）
    var plates: [Double]
}

/// 一個裝得出來的重量，和要怎麼裝
struct Loading: Hashable {
    let weight: Double
    let kit: String
    /// 每邊要裝的槓片（由重到輕）；滑輪則是全部要掛的片
    let plates: [Double]
    let use: WeightKits.Use

    var cable: Bool { use == .cable }

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
                  plates: [PlateStack(kg: 2.5, count: 12), PlateStack(kg: 1.25, count: 4)],
                  lockSeconds: 6, plateSeconds: 3),
        WeightKit(name: "舊啞鈴", handle: 0.5,
                  plates: [PlateStack(kg: 3, count: 8), PlateStack(kg: 2.5, count: 4), PlateStack(kg: 1.25, count: 4)],
                  makesBarbell: true, connector: 0.3, onCable: true,
                  lockSeconds: 15, plateSeconds: 4, assembleSeconds: 90),
    ]

    static func load() -> [WeightKit] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.kits) else { return defaults }
        guard let data = raw.data(using: .utf8),
              var kits = try? JSONDecoder().decode([WeightKit].self, from: data) else { return defaults }
        // 0.12 存的資料沒有換重量的秒數，舊啞鈴的把手重量也是當時的估計：沒改過的就換成新的預設
        if !raw.contains("lockSeconds") {
            for i in kits.indices {
                guard let d = defaults.first(where: { $0.name == kits[i].name }) else { continue }
                if kits[i].name == "舊啞鈴" && kits[i].handle == 1.0 && kits[i].connector == 0.5 {
                    kits[i].handle = d.handle
                    kits[i].connector = d.connector
                }
                kits[i].lockSeconds = d.lockSeconds
                kits[i].plateSeconds = d.plateSeconds
                kits[i].assembleSeconds = d.assembleSeconds
            }
        }
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
        "heel_goblet", "goblet_15", "db_pullover", "db_concentration_curl",
    ]

    /// 從 from 換成 to 大概要幾秒：拆裝鎖頭＋每片槓片＋（啞鈴↔槓鈴）組裝。
    static func changeSeconds(kit: WeightKit, from: RigState?, to: Loading) -> Int {
        let start = from ?? RigState(use: to.use, plates: [])
        var removed = start.plates
        var added: [Double] = []
        for p in to.plates {
            if let i = removed.firstIndex(where: { abs($0 - p) < 0.01 }) { removed.remove(at: i) } else { added.append(p) }
        }
        let units: Double = to.use == .pair ? 2 : 1
        let sides: Double = to.use == .cable ? 1 : 2
        let moves = Double(removed.count + added.count) * sides * units
        let assembling = (start.use == .barbell) != (to.use == .barbell) && from != nil
        var t = moves * kit.plateSeconds
        if moves > 0 && to.use != .cable { t += kit.lockSeconds * units }
        if assembling { t += kit.assembleSeconds }
        return Int(t.rounded())
    }

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
        guard let kind = use(for: ex) else { return [] }
        var result: [Loading] = []
        for kit in kits {
            let ceiling = result.last?.weight ?? -1
            let options = loadings(kit, kind).sorted {
                $0.weight != $1.weight ? $0.weight < $1.weight : $0.plates.count < $1.plates.count
            }
            for l in options where l.weight > ceiling + 0.01 {
                if let last = result.last, abs(last.weight - l.weight) < 0.01 { continue }
                result.append(l)
            }
        }
        // 槓鈴、滑輪的組合很細，加重一級太少：相鄰兩級至少差 2.5 kg／1.25 kg
        let gap: Double
        switch kind {
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
                out.append(Loading(weight: w, kit: kit.name, plates: picked.sorted(by: >), use: use))
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
    /// 每組器材各自的所有裝法（指定用哪一組時查這裡，例如 Drop set 用另一組啞鈴）
    var all: [Loading] = []

    var weights: [Double] { loadings.map(\.weight) }
    var isEmpty: Bool { loadings.isEmpty }
    var max: Double? { loadings.last?.weight }

    static func make(_ ex: Exercise, gym: Bool, step: Double) -> WeightLadder {
        guard !gym, let use = WeightKits.use(for: ex) else { return WeightLadder(loadings: [], step: step) }
        let kits = WeightKits.load()
        return WeightLadder(loadings: WeightKits.loadings(for: ex, kits: kits), step: step,
                            all: kits.flatMap { WeightKits.loadings($0, use) })
    }

    /// 這個動作今天用的階梯：超級組指定了器材，就只用那一組。
    static func make(_ item: PlannedExercise, gym: Bool, step: Double) -> WeightLadder {
        let base = make(item.exercise, gym: gym, step: step)
        guard !gym, let kit = item.kit else { return base }
        let pinned = base.only(kit: kit)
        return pinned.isEmpty ? base : pinned
    }

    /// 只用某一組器材的階梯（同重量取片數最少的裝法）
    func only(kit: String) -> WeightLadder {
        var best: [Loading] = []
        for l in all.filter({ $0.kit == kit }).sorted(by: { $0.weight != $1.weight ? $0.weight < $1.weight : $0.plates.count < $1.plates.count }) {
            if let last = best.last, abs(last.weight - l.weight) < 0.01 { continue }
            best.append(l)
        }
        return WeightLadder(loadings: best, step: step, all: all)
    }

    /// 主要器材以外、也能做這個動作的另一組器材
    var otherKit: String? {
        guard let main = loadings.first?.kit else { return nil }
        return all.first { $0.kit != main }?.kit
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

    /// 這個重量怎麼裝。kit 指定用哪一組；沒指定用主要階梯。
    func loading(_ w: Double, kit: String? = nil) -> Loading? {
        if let kit, let l = only(kit: kit).loadings.first(where: { abs($0.weight - w) < 0.01 }) { return l }
        return loadings.first { abs($0.weight - w) < 0.01 }
    }
}
