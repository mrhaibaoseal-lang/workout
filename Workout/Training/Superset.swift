import Foundation

/// 超級組（2 個動作）／循環組（3–4 個動作）：同一組的動作輪流做，一輪最後一個做完才休息。
/// 只配單關節動作（複合動作不配）。同一組的動作盡量用不同器材，輪流做才不用一直換重量。
enum Superset {
    static let maxSize = 4

    /// 能放進超級組的動作：單關節（沒有推／拉／腿的區域）。
    static func eligible(_ ex: Exercise) -> Bool { ex.pattern.region == nil }

    static func name(size: Int) -> String { size >= 3 ? "循環組" : "超級組" }

    /// 每組 A、B、C⋯⋯（畫面上的代號），依出現順序。
    static func letters(_ groups: [Int?]) -> [Int: String] {
        var out: [Int: String] = [:]
        for g in groups.compactMap({ $0 }) where out[g] == nil {
            let n = out.count
            out[g] = String(UnicodeScalar(UInt8(65 + n % 26)))
        }
        return out
    }

    // MARK: 分組

    /// 依連結旗標分組：link[i] = 第 i 個要和前一個連在一起。只連相鄰、都是單關節、每組最多 4 個。
    static func assignGroups(_ plan: inout [PlannedExercise], link: [Bool]) {
        var next = 1
        for i in plan.indices {
            plan[i].group = nil
            guard i > 0, i < link.count, link[i], eligible(plan[i].exercise), eligible(plan[i - 1].exercise) else { continue }
            if let g = plan[i - 1].group {
                guard plan.filter({ $0.group == g }).count < maxSize else { continue }
                plan[i].group = g
            } else {
                plan[i - 1].group = next
                plan[i].group = next
                next += 1
            }
        }
    }

    /// 內建課表自動配：相鄰的單關節動作兩兩一組。
    static func autoLinks(_ plan: [PlannedExercise]) -> [Bool] {
        var link = Array(repeating: false, count: plan.count)
        var i = 1
        while i < plan.count {
            if eligible(plan[i - 1].exercise) && eligible(plan[i].exercise) {
                link[i] = true
                i += 2
            } else {
                i += 1
            }
        }
        return link
    }

    /// 單獨一個的「組」拆掉（例如精簡版只剩一個）。
    static func dropSingles(_ plan: inout [PlannedExercise]) {
        for i in plan.indices {
            guard let g = plan[i].group else { continue }
            if plan.filter({ $0.group == g }).count < 2 { plan[i].group = nil }
        }
    }

    // MARK: 器材

    /// 這個動作用哪一組器材（槓片會被占住）；徒手、健身房 = nil。
    static func kit(of item: PlannedExercise, gym: Bool, kits: [WeightKit]) -> String? {
        guard !gym, let use = WeightKits.use(for: item.exercise) else { return nil }
        if let k = item.kit { return k }
        return WeightKits.loadings(for: item.exercise, kits: kits).first?.kit
            ?? kits.first { !WeightKits.loadings($0, use).isEmpty }?.name
    }

    /// 同一組裡用到同一組器材的動作，依序：改用另一組啞鈴 → 換成同類型、用別的器材的動作 → 標記要換重量。
    /// `replaceable[i]` = 第 i 個可以換成別的動作（自訂課表指定的動作不換）。
    /// 這場有槓鈴動作時，被拿去接槓鈴的那組器材不拿來用。
    static func separateKits(_ plan: inout [PlannedExercise], gym: Bool, equipment: Set<Equipment>,
                             replaceable: [Bool], kits: [WeightKit] = WeightKits.load()) {
        for i in plan.indices { plan[i].sharedKit = nil }
        guard !gym else { return }
        let ladders = plan.map { WeightLadder.make($0.exercise, gym: false, step: 2.5) }
        let blocked = Set([SetPlanner.barbellKit(in: ladders)].compactMap { $0 })
        func kitOf(_ ex: Exercise) -> String? {
            kit(of: PlannedExercise(exercise: ex, sets: 1, low: 1, high: 1, restSeconds: 0, essential: false), gym: gym, kits: kits)
        }
        for g in Set(plan.compactMap(\.group)).sorted() {
            var used = Set<String>()
            for i in plan.indices where plan[i].group == g {
                guard let k = kit(of: plan[i], gym: gym, kits: kits) else { continue }
                if !used.contains(k) { used.insert(k); continue }
                let taken = used.union(blocked)
                // 1. 同一個動作改用另一組啞鈴
                if let use = WeightKits.use(for: plan[i].exercise), use == .pair || use == .single,
                   let other = kits.first(where: { !taken.contains($0.name) && !WeightKits.loadings($0, use).isEmpty }) {
                    plan[i].kit = other.name
                    used.insert(other.name)
                    continue
                }
                // 2. 換成同類型、用沒被占住的器材的動作；沒有就換徒手的
                if i < replaceable.count, replaceable[i] {
                    let ids = Set(plan.map(\.exercise.id))
                    let options = ExerciseLibrary.candidates(for: plan[i].exercise.pattern, equipment: equipment)
                        .filter { !ids.contains($0.id) }
                    let free = options.first { kitOf($0).map { !taken.contains($0) } ?? false }
                    if let ex = free ?? options.first(where: { kitOf($0) == nil }) {
                        let old = plan[i]
                        var item = old.swapped(to: ex)
                        item.replaced = old.replaced
                        plan[i] = item
                        if let k2 = kitOf(ex) { used.insert(k2) }
                        continue
                    }
                }
                // 3. 分不開：每輪要換重量
                plan[i].sharedKit = k
            }
        }
    }

    // MARK: 順序

    struct Step: Equatable {
        let exercise: Int
        let set: Int
        /// 第幾輪（同一組內；沒分組的動作每組各算一輪）
        let round: Int
        let group: Int?
    }

    /// 整場的做組順序。沒分組的動作照原本順序；同一組的動作輪流：A1 B1 A2 B2⋯⋯
    /// 每個「單位」從一組熱身／正式組開始，後面的 Drop set 跟著它（不休息、不換動作）。
    static func order(groups: [Int?], kinds: [[SetKind]]) -> [Step] {
        var out: [Step] = []
        var i = 0
        while i < kinds.count {
            guard let g = groups[i] else {
                for k in kinds[i].indices { out.append(Step(exercise: i, set: k, round: k, group: nil)) }
                i += 1
                continue
            }
            var members = [i]
            while i + members.count < kinds.count, groups[i + members.count] == g { members.append(i + members.count) }
            let units: [[[Int]]] = members.map { m in
                var u: [[Int]] = []
                for (k, kind) in kinds[m].enumerated() {
                    if kind == .drop, !u.isEmpty { u[u.count - 1].append(k) } else { u.append([k]) }
                }
                return u
            }
            let rounds = units.map(\.count).max() ?? 0
            for r in 0..<rounds {
                for (n, m) in members.enumerated() where r < units[n].count {
                    for k in units[n][r] { out.append(Step(exercise: m, set: k, round: r, group: g)) }
                }
            }
            i += members.count
        }
        return out
    }

    /// 輪內換動作要換重量時，換完多給幾秒走過去。
    static let transitionExtra = 10

    /// 做完這一組之後的休息秒數：超級組一輪結束用同組裡最長的休息。
    static func restSeconds(after st: Step, plan: [PlannedExercise]) -> Int {
        guard let g = st.group else { return plan[st.exercise].restSeconds }
        return plan.filter { $0.group == g }.map(\.restSeconds).max() ?? plan[st.exercise].restSeconds
    }

    /// 做完 cur 之後接 next：同一組、同一輪、換下一個動作 = 輪內換動作，不休息。
    static func isTransition(_ cur: Step, _ next: Step) -> Bool {
        cur.group != nil && cur.group == next.group && cur.exercise != next.exercise && cur.round == next.round
    }
}
