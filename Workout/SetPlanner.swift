import Foundation

/// 每一組的類型。只有正式組算進步、破紀錄和訓練量。
enum SetKind: String {
    case warmup, work, drop
    /// 左右平衡：只做弱的那手的加強組（不算進步、紀錄、每週組數）
    case weak

    /// 組號位置顯示的短標籤（正式組顯示數字）
    var badge: String? {
        switch self {
        case .warmup: "熱"
        case .work: nil
        case .drop: "降"
        case .weak: "加"
        }
    }

    var title: String {
        switch self {
        case .warmup: "熱身組"
        case .work: "正式組"
        case .drop: "遞減組（不休息）"
        case .weak: "加強組（只做弱的那邊）"
        }
    }
}

/// 一個動作的組數排法。auto 交給程式依動作和週期決定。
enum SetScheme: String, CaseIterable, Identifiable {
    case auto, straight, pyramid, reverse, dropset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: "自動"
        case .straight: "固定重量"
        case .pyramid: "遞增組（金字塔）"
        case .reverse: "遞減組（倒金字塔）"
        case .dropset: "最後一組 Drop set"
        }
    }

    var short: String {
        switch self {
        case .auto: "自動"
        case .straight: "固定"
        case .pyramid: "遞增"
        case .reverse: "遞減"
        case .dropset: "Drop set"
        }
    }

    var explain: String {
        switch self {
        case .auto: "新手用固定重量；升中階後，單關節動作在進步期最後一組加 Drop set。"
        case .straight: "每組同樣的重量，最適合新手練動作、穩定進步。"
        case .pyramid: "從輕到重：每組加重、次數變少，最後一組最重。"
        case .reverse: "先做最重的一組，之後每組減重約 10%、多做 2 下。"
        case .dropset: "正式組做完，馬上減重約 25% 再做到力竭，中間不休息。啞鈴動作用另一組先裝好的啞鈴降 1 次；滑輪拔片快，降 2 次。"
        }
    }
}

/// 使用者對每個動作選的排法（沒選＝自動）。
enum SchemeStore {
    static func load() -> [String: String] {
        guard let data = UserDefaults.standard.string(forKey: Keys.schemes)?.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return dict
    }

    static func scheme(for exerciseId: String) -> SetScheme {
        load()[exerciseId].flatMap(SetScheme.init(rawValue:)) ?? .auto
    }

    static func set(_ scheme: SetScheme, for exerciseId: String) {
        var dict = load()
        dict[exerciseId] = scheme == .auto ? nil : scheme.rawValue
        if let data = try? JSONEncoder().encode(dict), let raw = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(raw, forKey: Keys.schemes)
        }
    }
}

/// 一組的計畫：重量、次數、類型。
struct PlannedSet {
    var weight: Double
    var reps: Int
    var kind: SetKind
    /// 指定用哪一組器材（Drop set 用另一組先裝好的啞鈴）
    var kit: String? = nil
}

enum SetPlanner {
    static let barWeight = 20.0

    /// 單關節動作：自動模式下進步期最後一組加 Drop set。
    static let isolation: Set<MovementPattern> = [.biceps, .triceps, .lateral, .rear]

    /// 把 auto 換成實際的排法。
    /// grouped：在超級組裡（輪流做、另一組啞鈴可能被另一個動作用），自動模式不排 Drop set。
    static func resolve(_ scheme: SetScheme, exercise: Exercise, phase: Phase, grouped: Bool = false) -> SetScheme {
        guard exercise.loaded else { return .straight }
        guard scheme == .auto else { return scheme }
        // 新手用固定重量就會一直進步；Drop set 疲勞多、效益小，升中階後才自動排
        if phase == .normal && Graduation.intermediateActive && isolation.contains(exercise.pattern) && !grouped {
            return .dropset
        }
        return .straight
    }

    /// 達標門檻：遞增／遞減組看最重那組有沒有做到「下限 + 2」，其他看上限。
    static func targetReps(scheme: SetScheme, low: Int, high: Int) -> Int {
        switch scheme {
        case .pyramid, .reverse: min(high, low + 2)
        default: high
        }
    }

    static func round(_ x: Double, step: Double) -> Double {
        let s = step > 0 ? step : 0.5
        return max(s, (x / s).rounded() * s)
    }

    /// 正式組（含 Drop set 的遞減組）。weight 是建議的「最重那組」重量。
    static func workSets(scheme: SetScheme, count: Int, weight: Double, reps: Int,
                         low: Int, high: Int, ladder: WeightLadder) -> [PlannedSet] {
        let n = max(1, count)
        guard weight > 0 else {
            // 不知道重量（第一次做）或徒手：先用固定排法
            return Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
        }
        switch scheme {
        case .auto, .straight:
            return Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
        case .pyramid:
            return (0..<n).map { i in
                let t = n == 1 ? 1 : Double(i) / Double(n - 1)
                let w = ladder.snap(weight * (0.8 + 0.2 * t))
                let r = Int((Double(high) - Double(high - low) * t).rounded())
                return PlannedSet(weight: w, reps: r, kind: .work)
            }
        case .reverse:
            return (0..<n).map { i in
                let w = ladder.snap(weight * (1 - 0.1 * Double(i)))
                return PlannedSet(weight: w, reps: min(high, low + 2 * i), kind: .work)
            }
        case .dropset:
            var out = Array(repeating: PlannedSet(weight: weight, reps: reps, kind: .work), count: n)
            // 兩手各拿一支的啞鈴動作：換片來不及，用另一組啞鈴先裝好減重後的重量，只降一次
            if let other = pairKit(ladder) {
                let alt = ladder.only(kit: other)
                let d = alt.snap(weight * 0.75)
                if d < weight, alt.loading(d) != nil {
                    out.append(PlannedSet(weight: d, reps: reps, kind: .drop, kit: other))
                }
                return out
            }
            let d1 = ladder.snap(weight * 0.75)
            let d2 = ladder.snap(weight * 0.55)
            if d1 < weight { out.append(PlannedSet(weight: d1, reps: reps, kind: .drop)) }
            if d2 < d1 { out.append(PlannedSet(weight: d2, reps: reps, kind: .drop)) }
            return out
        }
    }

    /// 兩手各一支的啞鈴動作，而且有第二組啞鈴可以先裝好
    private static func pairKit(_ ladder: WeightLadder) -> String? {
        guard ladder.loadings.first?.use == .pair else { return nil }
        return ladder.otherKit
    }

    /// 熱身組。first = 這個部位（推／拉／腿）今天第一個動作，做完整熱身；之後的複合動作只做 1 組。
    /// 兩手各一支的啞鈴動作，如果有另一組啞鈴可以用，熱身組改指定用另一組（主要啞鈴只裝一次正式組重量）。
    /// avoidKit：這場另一組啞鈴已經接成槓鈴時傳它的名字，熱身就不用它。
    static func warmups(for exercise: Exercise, workWeight w: Double, first: Bool, ladder: WeightLadder,
                        avoidKit: String? = nil) -> [PlannedSet] {
        let base = baseWarmups(for: exercise, workWeight: w, first: first, ladder: ladder)
        guard !base.isEmpty, let other = warmupKit(ladder, workWeight: w, avoid: avoidKit) else { return base }
        let alt = ladder.only(kit: other)
        let ws = alt.weights
        guard let lowest = ws.first else { return base }
        var out: [PlannedSet] = []
        for s in base {
            // 不超過目標的最近一級；都比目標重就用最輕的；永遠不超過正式組重量
            let x = ws.last { $0 <= s.weight + 0.01 } ?? lowest
            guard x < w - 0.01 else { continue }
            if let last = out.last, x <= last.weight + 0.01 { continue }
            out.append(PlannedSet(weight: x, reps: s.reps, kind: .warmup, kit: other))
        }
        return out.isEmpty ? base : out
    }

    /// 熱身可以改用的另一組啞鈴：兩手各一支、正式組用主要啞鈴裝得出來、另一組沒被拿去接槓鈴。
    static func warmupKit(_ ladder: WeightLadder, workWeight w: Double, avoid: String?) -> String? {
        guard let other = pairKit(ladder), other != avoid,
              let main = ladder.loadings.first?.kit,
              ladder.loading(w)?.kit == main else { return nil }
        return other
    }

    /// 這場有槓鈴動作（在家）時，被拿去接槓鈴的那組器材名字。
    static func barbellKit(in ladders: [WeightLadder]) -> String? {
        ladders.first { $0.loadings.first?.use == .barbell }?.loadings.first?.kit
    }

    private static func baseWarmups(for exercise: Exercise, workWeight w: Double, first: Bool, ladder: WeightLadder) -> [PlannedSet] {
        guard exercise.loaded, w > 0, exercise.pattern.region != nil else { return [] }
        var out: [PlannedSet] = []
        if !first {
            let x = ladder.snap(w * 0.6)
            if w >= 10 && x < w { out.append(PlannedSet(weight: x, reps: 6, kind: .warmup)) }
            return out
        }
        if exercise.requires.contains(.barbell) {
            let bar = ladder.weights.first ?? barWeight
            guard w > bar else { return [] }
            out.append(PlannedSet(weight: bar, reps: 10, kind: .warmup))
            for (pct, reps) in [(0.5, 8), (0.7, 5), (0.85, 3)] {
                let x = ladder.snap(w * pct)
                if x > (out.last?.weight ?? 0) && x < w { out.append(PlannedSet(weight: x, reps: reps, kind: .warmup)) }
            }
        } else {
            let plan: [(Double, Int)] = w >= 8 ? [(0.5, 10), (0.75, 5)] : (w >= 4 ? [(0.5, 10)] : [])
            for (pct, reps) in plan {
                let x = ladder.snap(w * pct)
                if x > (out.last?.weight ?? 0) && x < w { out.append(PlannedSet(weight: x, reps: reps, kind: .warmup)) }
            }
        }
        return out
    }

    /// 一個動作排好的組（建議重量、排法、全部的組）。makeDraft 和預估時間共用，才不會算出不一樣的東西。
    struct ExercisePlan {
        let scheme: SetScheme
        let suggestion: Suggestion
        let sets: [PlannedSet]
    }

    static func plannedSets(item: PlannedExercise, last: [SetEntry], phase: Phase, ladder: WeightLadder,
                            chosen: SetScheme, minimal: Bool, autoWarmup: Bool,
                            firstInRegion: Bool, avoidKit: String?, plateau: PlateauInfo? = nil) -> ExercisePlan {
        // 只做 1 組的日子不排遞增／遞減
        let scheme: SetScheme = minimal ? .straight : resolve(chosen, exercise: item.exercise, phase: phase, grouped: item.group != nil)
        // 連續 3 次沒進步：先減重重新爬（Plateau.adjust）
        let s = Plateau.adjust(Progression.suggest(item, last: last, phase: phase, ladder: ladder, scheme: scheme),
                               item: item, info: plateau, ladder: ladder, phase: phase)
        let work = workSets(scheme: scheme, count: item.sets, weight: s.weight, reps: s.reps,
                            low: item.low, high: item.high, ladder: ladder)
        let warm = autoWarmup && !minimal
            ? warmups(for: item.exercise, workWeight: work.first?.weight ?? 0, first: firstInRegion,
                      ladder: ladder, avoidKit: avoidKit)
            : []
        // 左右平衡：最後多一組只做弱的那手，重量、次數和最後一個正式組一樣
        var extra: [PlannedSet] = []
        if SideBalance.wantsExtra(item.exercise, phase: phase, minimal: minimal),
           let w = work.last(where: { $0.kind == .work }) {
            extra = [PlannedSet(weight: w.weight, reps: w.reps, kind: .weak)]
        }
        return ExercisePlan(scheme: scheme, suggestion: s, sets: warm + work + extra)
    }

    /// 還沒做的一組，算換重量用的最少資訊
    struct PlanStep {
        var kind: SetKind
        var kit: String?
        var loading: Loading?
    }

    /// 休息時要做的一件換重量的事
    struct RigStep {
        let label: String
        let loading: Loading
        let from: RigState?
        let seconds: Int
        let assemble: Bool
    }

    /// 下一組（upcoming 的第一個，後面是同一個動作還沒做的組）要換什麼：
    /// 換成下一組的重量；下一組做完就要 Drop set，就先用另一組啞鈴裝好；
    /// 下一組是用另一組啞鈴的（最後一個）熱身，順便把主要啞鈴裝成正式組重量。
    /// 不改 rigs，呼叫的人自己決定什麼時候當作換好了。
    /// also：超級組一輪結束的休息，順便把同一組其他動作下一輪的重量裝好（名字、裝法）。
    static func rigSteps(upcoming: [PlanStep], sameExercise: Bool, exerciseName: String,
                         rigs: [String: RigState], kits: [WeightKit],
                         also: [(name: String, loading: Loading)] = []) -> [RigStep] {
        var state = rigs
        var out: [RigStep] = []
        func prepare(_ l: Loading, label: String) {
            guard let kit = kits.first(where: { $0.name == l.kit }) else { return }
            let target = RigState(use: l.use, plates: l.plates)
            let from = state[l.kit]
            guard from != target else { return }
            let t = WeightKits.changeSeconds(kit: kit, from: from, to: l)
            if from == nil && l.plates.isEmpty { return }
            out.append(RigStep(label: label, loading: l, from: from, seconds: t,
                               assemble: from.map { ($0.use == .barbell) != (l.use == .barbell) } ?? false))
            state[l.kit] = target
        }
        guard let next = upcoming.first else { return [] }
        if let l = next.loading {
            prepare(l, label: sameExercise ? "換重量" : "下一個動作（\(exerciseName)）")
        }
        if next.kind == .work, upcoming.count >= 2, upcoming[1].kind == .drop, upcoming[1].kit != nil,
           let l = upcoming[1].loading {
            prepare(l, label: "順便裝好 Drop set")
        }
        if next.kind == .warmup, let warmKit = next.kit,
           !upcoming.dropFirst().contains(where: { $0.kind == .warmup }),
           let work = upcoming.first(where: { $0.kind == .work }),
           let l = work.loading, l.kit != warmKit {
            prepare(l, label: "順便裝好正式組")
        }
        // 同一組器材被下一組用到的，不能先裝成別的
        var busy = Set([next.loading?.kit].compactMap { $0 })
        for a in also where !busy.contains(a.loading.kit) {
            prepare(a.loading, label: "順便裝好「\(a.name)」（超級組）")
            busy.insert(a.loading.kit)
        }
        return out
    }

    /// 這組做完要休息幾秒。下一組是遞減組就不休息；熱身組休息短一點。
    static func rest(after done: SetKind, next: SetKind?, normal: Int) -> Int {
        if next == .drop { return 0 }
        // 弱邊加強組：另一手做的時候弱邊已經在休息了
        if next == .weak { return 45 }
        if done == .warmup { return next == .warmup ? 45 : 75 }
        return normal
    }
}

/// 預估整場訓練要花多久：照 makeDraft 一樣排好每一組，再照順序走一遍，
/// 加上換重量、組槓鈴的時間（休息裡的換重量算在休息內，和訓練時的規則一樣）。
enum WorkoutTimeEstimator {
    /// 做一組大約幾秒
    static let setSeconds = 45

    private struct Entry {
        let name: String
        let kind: SetKind
        let kit: String?
        let loading: Loading?
        /// 單手輪流做，一組要做兩次
        var oneArm = false
    }

    static func seconds(plan: [PlannedExercise], sessions: [WorkoutSession], gym: Bool, increment: Double,
                        autoWarmup: Bool, week: Int, length: WorkoutLength) -> Int {
        guard !plan.isEmpty else { return 0 }
        let phase = ProgramBuilder.phase(week: week)
        let minimal = length == .minimal
        let kits = WeightKits.load()
        let ladders = plan.map { WeightLadder.make($0, gym: gym, step: increment) }
        let barKit = SetPlanner.barbellKit(in: ladders)

        // sets[n][k]：第 n 個動作的第 k 組
        var sets: [[Entry]] = []
        var seen = Set<String>()
        for (n, item) in plan.enumerated() {
            let ex = item.exercise
            let region = ex.pattern.region
            let first = region.map { !seen.contains($0) } ?? false
            if let region { seen.insert(region) }
            let last = Progression.lastSets(for: ex.id, in: sessions)
            let p = SetPlanner.plannedSets(item: item, last: last, phase: phase, ladder: ladders[n],
                                           chosen: SchemeStore.scheme(for: ex.id), minimal: minimal,
                                           autoWarmup: autoWarmup, firstInRegion: first, avoidKit: barKit)
            sets.append(p.sets.map { s in
                let l: Loading? = ex.loaded && s.weight > 0 ? ladders[n].loading(s.weight, kit: s.kit) : nil
                return Entry(name: ex.name, kind: s.kind, kit: s.kit, loading: l,
                             oneArm: s.kind == .work && SideBalance.sided(ex))
            })
        }
        // 照實際做的順序（超級組輪流做）
        let order = Superset.order(groups: plan.map(\.group), kinds: sets.map { $0.map(\.kind) })
        guard !order.isEmpty else { return 0 }

        var total = 0
        var rigs: [String: RigState] = [:]
        // 槓鈴整場只組一次
        if let barKit, let kit = kits.first(where: { $0.name == barKit }) {
            total += Int(kit.assembleSeconds)
        }
        /// 從 order[index] 開始要換的；roundEnd = 超級組一輪結束，順便裝好同組其他動作。
        func steps(from index: Int, sameExercise: Bool, roundEnd: Bool) -> [SetPlanner.RigStep] {
            let st = order[index]
            let upcoming = order[index...].filter { $0.exercise == st.exercise }
                .map { sets[$0.exercise][$0.set] }
                .map { SetPlanner.PlanStep(kind: $0.kind, kit: $0.kit, loading: $0.loading) }
            var also: [(name: String, loading: Loading)] = []
            if roundEnd, let g = st.group {
                var got = Set([st.exercise])
                for o in order[index...] where o.group == g && !got.contains(o.exercise) {
                    got.insert(o.exercise)
                    if let l = sets[o.exercise][o.set].loading { also.append((plan[o.exercise].exercise.name, l)) }
                }
            }
            return SetPlanner.rigSteps(upcoming: upcoming, sameExercise: sameExercise, exerciseName: sets[st.exercise][st.set].name,
                                       rigs: rigs, kits: kits, also: also)
        }
        func apply(_ list: [SetPlanner.RigStep]) {
            for c in list { rigs[c.loading.kit] = RigState(use: c.loading.use, plates: c.loading.plates) }
        }
        // 第一組開始前先裝好
        let startSteps = steps(from: 0, sameExercise: false, roundEnd: true)
        total += startSteps.reduce(0) { $0 + $1.seconds }
        apply(startSteps)

        for (k, st) in order.enumerated() {
            let e = sets[st.exercise][st.set]
            total += setSeconds + (e.oneArm ? 30 : 0)
            if let l = e.loading { rigs[l.kit] = RigState(use: l.use, plates: l.plates) }
            guard k + 1 < order.count else { break }
            let nx = order[k + 1]
            let transition = Superset.isTransition(st, nx)
            let chores = steps(from: k + 1, sameExercise: nx.exercise == st.exercise, roundEnd: !transition)
            let change = chores.reduce(0) { $0 + $1.seconds }
            if transition {
                // 超級組輪內換動作：不休息，要換重量就花換的時間
                total += change > 0 ? change + Superset.transitionExtra : 0
            } else {
                var rest = SetPlanner.rest(after: e.kind, next: sets[nx.exercise][nx.set].kind,
                                           normal: Superset.restSeconds(after: st, plan: plan))
                if rest > 0 {
                    rest = max(rest, change + (e.kind == .warmup ? 20 : 30))
                    total += rest
                } else {
                    // 不休息的遞減組：換的時間照樣要花
                    total += change
                }
            }
            apply(chores)
        }
        return total
    }

    static func minutes(plan: [PlannedExercise], sessions: [WorkoutSession], gym: Bool, increment: Double,
                        autoWarmup: Bool, week: Int, length: WorkoutLength) -> Int {
        let s = seconds(plan: plan, sessions: sessions, gym: gym, increment: increment,
                        autoWarmup: autoWarmup, week: week, length: length)
        return max(5, Int((Double(s) / 60).rounded()) + 5)
    }
}
