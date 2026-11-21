import SwiftUI
import SwiftData

struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var kind: SetKind = .work
    /// 指定用哪一組啞鈴（Drop set 用另一組先裝好的）
    var kit: String? = nil
    /// 還剩幾下力氣（RIR），-1 = 沒填
    var rir: Int = -1
    var done = false
    /// 這組的目標次數（排課表時的次數；判定 PERFECT 用）
    var target: Int = 0
    /// 做完後的判定（只有正式組）
    var grade: SetGrade? = nil
}

struct ExerciseDraft: Identifiable {
    var item: PlannedExercise
    var suggestion: Suggestion
    /// 「上次 10 kg × 12、11、10」, empty the first time.
    var lastText: String
    var sets: [SetDraft]
    /// 上次這個動作的正式組（休息頁比較用）
    var last: [LastSet] = []
    /// 使用者選的排法（可能是自動）
    var chosen: SetScheme = .auto
    /// 實際用的排法
    var scheme: SetScheme = .straight
    /// 這個動作裝得出來的重量
    var ladder = WeightLadder(loadings: [], step: 2.5)
    /// 這次因為停滯先減重（做完就從這次重新算停滯）
    var plateauReset = false
    /// 這次寫的動作備註
    var note: String = ""
    /// 上次寫的動作備註
    var lastNote: String? = nil
    /// 最近幾次的推估最大力量（休息頁小圖）
    var trend: [Double] = []
    var id: String { item.id }

    /// 上次同一組（第 n 個正式組比第 n 個；上次組數比較少就比上次最後一組）
    func lastFor(_ set: SetDraft) -> LastSet? {
        guard set.kind == .work, !last.isEmpty, let i = sets.firstIndex(where: { $0.id == set.id }) else { return nil }
        let n = sets[...i].filter { $0.kind == .work }.count
        return last[min(n, last.count) - 1]
    }

    /// 已經開始做正式組，就不能再改排法或換動作。
    var locked: Bool { sets.contains { $0.done && $0.kind != .warmup } }
    var hasWarmups: Bool { sets.contains { $0.kind == .warmup } }
}

struct WorkoutView: View {
    let day: DayTemplate
    let length: WorkoutLength
    let week: Int
    var onFinish: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.place) private var placeRaw = TrainingPlace.home.rawValue
    @AppStorage(Keys.autoWarmup) private var autoWarmup = true
    @AppStorage(Keys.limitBarbell) private var limitBarbell = true
    @AppStorage(Keys.increment) private var increment = 2.5

    @State private var drafts: [ExerciseDraft] = []
    @State private var startedAt = Date()
    @State private var restEnd: Date?
    @State private var restTotal: Double = 90
    @State private var focused: UUID?
    @State private var confirmQuit = false
    @State private var showNothingDone = false
    @State private var askMore = false
    /// 每個動作以前的最高重量（破紀錄判斷用），開始訓練時算一次。
    @State private var bests: [String: Double] = [:]
    @State private var prMoment: PRMoment?
    @State private var prCount: Set<String> = []
    @State private var summary: WorkoutSummary?
    @State private var toast: String?
    /// 每組器材現在裝成什麼樣子，用來估換重量要多久
    @State private var rigs: [String: RigState] = [:]
    /// 正在休息：剛做完的是第幾個動作（用來算下一組和要換的重量）
    @State private var restAfter: Int?
    /// 休息頁縮成底部的小卡
    @State private var restMinimized = false
    /// 為什麼休息這麼久
    @State private var restReasons: [String] = []
    /// 守時連擊：休息結束後 15 秒內開始下一組就 +1
    @State private var combo = 0
    @State private var bestCombo = 0
    @State private var onTimeRests = 0
    @State private var scoredRests = 0
    @State private var comboMoment: ComboMoment?
    /// 訓練前狀態（強制回答，回答前不排課表）
    @State private var readiness: Readiness?
    @State private var gradeMoment: GradeMoment?
    /// 剛做完那一組的判定和幽靈比較（休息頁顯示）
    @State private var lastResult: SetResult?
    @State private var sessionNote = ""
    @EnvironmentObject private var inventory: InventoryStore
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4

    private var allDone: Bool {
        drafts.allSatisfy { $0.sets.allSatisfy(\.done) }
    }

    /// The set being worked on: the one the user tapped, else the first unfinished set.
    private var activeSetId: UUID? {
        if let f = focused, drafts.contains(where: { $0.sets.contains { $0.id == f && !$0.done } }) {
            return f
        }
        for d in drafts {
            if let s = d.sets.first(where: { !$0.done }) { return s.id }
        }
        return nil
    }

    private var activeExerciseId: String? {
        guard let id = activeSetId else { return nil }
        return drafts.first { $0.sets.contains { $0.id == id } }?.id
    }

    private var equipment: Set<Equipment> { ProgramBuilder.equipment(place: placeRaw, homeRaw: equipmentRaw) }
    private var isGym: Bool { placeRaw == TrainingPlace.gym.rawValue }
    private var lessBarbell: Bool { limitBarbell && !isGym }

    /// 在家有槓鈴動作：開始前先組好，整場只組一次。另一組啞鈴留給其他動作。
    private var barbellPrep: String? {
        guard !isGym, doneSets == 0 else { return nil }
        let bars = drafts.filter { $0.ladder.loadings.first?.use == .barbell }
        guard let first = bars.first, let kitName = first.ladder.loadings.first?.kit else { return nil }
        let names = bars.map(\.item.exercise.name).joined(separator: "、")
        let secs = Int(WeightKits.load().first { $0.name == kitName }?.assembleSeconds ?? 90)
        return "開始前先用\(kitName)組好槓鈴（約 \(secs) 秒），\(names)用。其他動作用另一組啞鈴，整場不用再拆。"
    }

    private var doneSets: Int { drafts.reduce(0) { $0 + $1.sets.filter(\.done).count } }
    private var totalSets: Int { drafts.reduce(0) { $0 + $1.sets.count } }

    /// Next exercise from the full plan that isn't on screen yet (for the "1 set" ladder).
    private var nextExtra: PlannedExercise? {
        let shown = Set(drafts.map(\.id))
        return ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: .full, limitBarbell: lessBarbell)
            .first { !shown.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                progressBar
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if let r = readiness, let text = r.banner {
                                HStack(alignment: .top, spacing: 4) {
                                    Label(text, systemImage: r.level == .high ? "bolt.heart.fill" : "bed.double.fill")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(r.level == .high ? Theme.green : Theme.accentSoft)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    InfoTip(item: .readiness)
                                }
                                .padding(14)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
                            }
                            if let prep = barbellPrep {
                                Label(prep, systemImage: "wrench.adjustable.fill")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(Theme.hotText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hotLine, lineWidth: 1))
                            }
                            ForEach(Array(drafts.indices), id: \.self) { i in
                                ExerciseCard(draft: $drafts[i], number: i + 1, total: drafts.count,
                                             activeSetId: activeSetId, increment: increment,
                                             swapOptions: isGym ? swapOptions(for: i) : [],
                                             onFocus: { focused = $0 },
                                             onComplete: { id in complete(set: id, in: i) },
                                             onScheme: { setScheme($0, at: i) },
                                             onToggleWarmup: { toggleWarmup(at: i) },
                                             onSwap: { swap(at: i, to: $0) })
                                    .id(drafts[i].id)
                            }
                            if !drafts.isEmpty {
                                sessionNoteField
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: activeExerciseId) { _, id in
                        guard let id else { return }
                        withAnimation(.easeInOut) { proxy.scrollTo(id, anchor: .top) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { restCard }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("好") { hideKeyboard() }
                }
            }
            .confirmationDialog("要放棄這次訓練嗎？", isPresented: $confirmQuit, titleVisibility: .visible) {
                Button("放棄，不儲存", role: .destructive) { dismiss() }
                Button("繼續練", role: .cancel) {}
            } message: {
                Text("就算只做一組也值得按「完成」存起來。")
            }
            .alert("還沒有完成任何一組", isPresented: $showNothingDone) {
                Button("好") {}
            } message: {
                Text("做完一組後按「完成這一組」。")
            }
            .alert("做到了！🎉", isPresented: $askMore) {
                Button("再一組") { addSet() }
                if nextExtra != nil {
                    Button("再加一個動作") { addNextExercise() }
                }
                Button("今天這樣就好", role: .cancel) { finish() }
            } message: {
                Text("你已經贏過想偷懶的自己了，這次也算數。還想再多做一點嗎？")
            }
            .onAppear {
                buildDrafts()
                RestAlerts.requestAuthorization()
                AppCommands.shared.completeSet = { completeFromShortcut() }
            }
            .onDisappear {
                RestAlerts.stop()
                AppCommands.shared.completeSet = nil
            }
            .onChange(of: restActivity) { _, state in
                if let state {
                    RestAlerts.start(day: day.name, state: state)
                } else {
                    RestAlerts.stop()
                }
            }
            .overlay { restScreen }
            .overlay {
                if let g = gradeMoment {
                    GradeBurstView(moment: g).id(g.id)
                }
            }
            .overlay {
                if let m = comboMoment {
                    ComboBurstView(moment: m).id(m.id)
                }
            }
            .overlay(alignment: .top) {
                if let t = toast {
                    Text(t)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.green, in: Capsule())
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .overlay {
                if let pr = prMoment {
                    PRBurstView(pr: pr).id(pr.id)
                }
            }
            .overlay {
                if let s = summary {
                    WorkoutCompleteView(summary: s) {
                        onFinish()
                        dismiss()
                    }
                    .transition(.opacity)
                }
            }
            .overlay {
                if readiness == nil {
                    ReadinessCheckView(onDone: { r in
                        readiness = r
                        drafts = []
                        buildDrafts()
                    }, onQuit: { dismiss() })
                    .transition(.opacity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Top

    private var topBar: some View {
        HStack {
            Button { confirmQuit = true } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(Theme.fg)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
            .accessibilityLabel("離開訓練")
            Spacer()
            VStack(spacing: 0) {
                Text(day.name + (length.tag.map { "（\($0)）" } ?? ""))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.fg)
                Text(startedAt, style: .timer)
                    .font(Theme.number(13, .bold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { finish() } label: {
                Text("完成")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.bg)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(drafts) { d in
                    let total = max(d.sets.count, 1)
                    let frac = Double(d.sets.filter(\.done).count) / Double(total)
                    let isActive = d.id == activeExerciseId
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(frac >= 1 ? Theme.accent : (isActive ? Theme.hot : Theme.accent))
                                .frame(width: geo.size.width * frac)
                        }
                    }
                    .frame(height: 6)
                }
            }
            let current = drafts.firstIndex { $0.id == activeExerciseId }.map { $0 + 1 } ?? drafts.count
            Text("動作 \(current) / \(drafts.count) · 已完成 \(doneSets) / \(totalSets) 組")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    // MARK: Rest

    @ViewBuilder
    private var restCard: some View {
        if let end = restEnd, restMinimized {
            RestCard(end: end, total: restTotal,
                     note: changes.isEmpty ? nil : changes.map(\.text).joined(separator: "\n"),
                     onAdd: addRest, onSkip: endRest,
                     onExpand: { withAnimation(.spring(duration: 0.35)) { restMinimized = false } })
        }
    }

    @ViewBuilder
    private var restScreen: some View {
        if let end = restEnd, !restMinimized {
            let pos = restPosition
            RestScreen(end: end, total: restTotal,
                       next: pos.map { restNext(j: $0.0, k: $0.1) },
                       nextSet: pos.map { $drafts[$0.0].sets[$0.1] } ?? .constant(SetDraft(weight: 0, reps: 0)),
                       changes: changes, reasons: restReasons, combo: combo, result: lastResult,
                       onAdd: addRest, onSkip: endRest,
                       onMinimize: { withAnimation(.spring(duration: 0.35)) { restMinimized = true } })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// 這次休息要換的器材（下一組的重量改了會跟著變）
    private var changes: [RigChange] {
        guard restEnd != nil, let i = restAfter, i < drafts.count else { return [] }
        return restChanges(after: i)
    }

    /// 休息後要做的那一組：(第幾個動作, 第幾組)
    private var restPosition: (Int, Int)? {
        guard restEnd != nil, let i = restAfter, i < drafts.count, let found = nextSet(after: i),
              let k = drafts[found.0].sets.firstIndex(where: { $0.id == found.1.id }) else { return nil }
        return (found.0, k)
    }

    private func restNext(j: Int, k: Int) -> RestNext {
        let d = drafts[j]
        let set = d.sets[k]
        var tag = set.kind.title
        var last: LastSet?
        if set.kind == .work {
            let n = d.sets[...k].filter { $0.kind == .work }.count
            tag = "第 \(n) 組"
            if n - 1 < d.last.count { last = d.last[n - 1] }
        }
        return RestNext(exercise: d.item.exercise, tag: tag, ladder: d.ladder, last: last, newExercise: j != restAfter,
                        lastNote: d.note.isEmpty ? d.lastNote : d.note, trend: d.trend)
    }

    /// 鎖定畫面／通知要顯示的內容；nil = 沒在休息
    private var restActivity: RestActivityAttributes.ContentState? {
        guard let end = restEnd else { return nil }
        var next = "下一組"
        var detail = ""
        if let pos = restPosition {
            let (j, k) = pos
            let d = drafts[j]
            let set = d.sets[k]
            next = d.item.exercise.name + " · " + restNext(j: j, k: k).tag
            detail = d.item.exercise.loaded && set.weight > 0
                ? "\(Progression.format(set.weight)) kg × \(set.reps)"
                : "\(set.reps) \(d.item.exercise.unit.label)"
        }
        return .init(end: end, total: restTotal, next: next, detail: detail, change: changes.first?.short)
    }

    private func addRest() {
        guard let end = restEnd else { return }
        restEnd = end.addingTimeInterval(30)
        restTotal += 30
    }

    private func endRest() {
        scoreRest(grace: RestScreen.comboWindow)
        commitRest()
        withAnimation(.easeOut(duration: 0.25)) { restEnd = nil }
        restMinimized = false
    }

    /// 這次休息有沒有準時：休息結束後 grace 秒內離開休息（提早跳過也算）。
    private func scoreRest(grace: Double) {
        guard let end = restEnd, restAfter != nil else { return }
        scoredRests += 1
        if Date().timeIntervalSince(end) <= grace {
            onTimeRests += 1
            combo += 1
            bestCombo = max(bestCombo, combo)
            if combo >= 2 {
                let m = ComboMoment(combo: combo)
                comboMoment = m
                DispatchQueue.main.asyncAfter(deadline: .now() + ComboMoment.duration + 0.1) {
                    if comboMoment?.id == m.id { comboMoment = nil }
                }
            }
        } else {
            if combo >= 2 { showToast("連擊 ×\(combo) 中斷了，下一組重新開始") }
            combo = 0
        }
    }

    /// 整場守時率換碎片：至少休息 3 次，九成準時 +6、七成 +3。
    private var comboShards: Int {
        guard scoredRests >= 3 else { return 0 }
        let rate = Double(onTimeRests) / Double(scoredRests)
        return rate >= 0.9 ? 6 : (rate >= 0.7 ? 3 : 0)
    }

    /// 休息結束：當作已經照休息頁換好重量。
    private func commitRest() {
        if let i = restAfter, i < drafts.count {
            for c in restChanges(after: i) { rigs[c.kit] = c.target }
        }
        restAfter = nil
    }

    // MARK: Actions

    private func complete(set id: UUID, in exerciseIndex: Int) {
        guard let s = drafts[exerciseIndex].sets.firstIndex(where: { $0.id == id }) else { return }
        if restEnd != nil {
            // 沒按「下一組」直接做完：多給做一組的時間
            scoreRest(grace: RestScreen.comboWindow + 75)
            commitRest()
        }
        if drafts[exerciseIndex].sets[s].done {
            drafts[exerciseIndex].sets[s].done = false
            drafts[exerciseIndex].sets[s].grade = nil
            focused = id
            return
        }
        drafts[exerciseIndex].sets[s].done = true
        focused = nil
        lastResult = nil
        if drafts[exerciseIndex].sets[s].kind == .work {
            let d = drafts[exerciseIndex]
            let done = d.sets[s]
            let g = SetGrade.judge(reps: done.reps, rir: done.rir, target: done.target, low: d.item.low)
            drafts[exerciseIndex].sets[s].grade = g
            let ex = d.item.exercise
            let ghost = d.lastFor(done).map {
                GhostDelta.compare(weight: done.weight, reps: done.reps, last: $0, loaded: ex.loaded, unit: ex.unit.label)
            }
            lastResult = SetResult(exerciseName: ex.name, grade: g,
                                   reason: SetGrade.reason(g, reps: done.reps, rir: done.rir, target: done.target),
                                   ghost: ghost)
            // 破紀錄的特效比較大，有破紀錄就不跳判定
            if !checkRecord(d, set: done) {
                let m = GradeMoment(grade: g)
                gradeMoment = m
                DispatchQueue.main.asyncAfter(deadline: .now() + GradeMoment.duration + 0.1) {
                    if gradeMoment?.id == m.id { gradeMoment = nil }
                }
            }
            autoAdjust(exerciseIndex, after: s)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        let set = drafts[exerciseIndex].sets[s]
        if length == .minimal && allDone {
            restEnd = nil
            restAfter = nil
            askMore = true
        } else if !allDone {
            if let l = loading(of: set, in: drafts[exerciseIndex]) {
                rigs[l.kit] = RigState(use: l.use, plates: l.plates)
            }
            let next = drafts[exerciseIndex].sets.first { !$0.done }?.kind
            var rest = SetPlanner.rest(after: set.kind, next: next, normal: drafts[exerciseIndex].item.restSeconds)
            let chores = restChanges(after: exerciseIndex)
            let change = chores.reduce(0) { $0 + $1.seconds }
            if rest > 0 {
                var reasons: [String] = []
                // 做到力竭（還剩 0 下）恢復比較慢
                if set.kind == .work && set.rir == 0 {
                    rest += 30
                    reasons.append("這組做到力竭，多休息 30 秒")
                }
                // 換重量也算休息，但換完至少還要喘一下
                let needed = change + (set.kind == .warmup ? 20 : 30)
                if needed > rest {
                    rest = needed
                    reasons.append("換重量約 \(change) 秒，換完再喘一下")
                }
                restAfter = exerciseIndex
                restReasons = reasons
                restMinimized = false
                restTotal = Double(rest)
                withAnimation(.spring(duration: 0.4)) {
                    restEnd = Date().addingTimeInterval(TimeInterval(rest))
                }
            } else {
                restEnd = nil
                restAfter = nil
                for c in chores { rigs[c.kit] = c.target }
                let note = chores.map(\.text).joined(separator: "\n")
                showToast(note.isEmpty ? "馬上減重，不休息！" : "馬上減重，不休息！" + note)
            }
        } else {
            restEnd = nil
            restAfter = nil
        }
    }

    /// 捷徑／Siri「完成一組」：用目前這組預定的重量和次數記錄（App 在背景也會跑）。
    private func completeFromShortcut() -> String {
        guard readiness != nil else { return "先回到練壯回答訓練前狀態，再開始第一組。" }
        guard summary == nil else { return "這次訓練已經結束了。" }
        guard let id = activeSetId,
              let i = drafts.firstIndex(where: { $0.sets.contains { $0.id == id } }),
              let set = drafts[i].sets.first(where: { $0.id == id }) else {
            return "全部都做完了，回到練壯按「完成」。"
        }
        let ex = drafts[i].item.exercise
        let what = ex.loaded && set.weight > 0
            ? "\(Progression.format(set.weight)) 公斤 \(set.reps) 下" : "\(set.reps) \(ex.unit == .seconds ? "秒" : "下")"
        complete(set: id, in: i)
        // App 在背景時畫面不一定會更新，onChange 可能不觸發，這裡直接排休息提醒
        if let state = restActivity { RestAlerts.start(day: day.name, state: state) }
        var text = "\(ex.name) \(what)，完成"
        if let end = restEnd {
            text += "。休息 \(Int(end.timeIntervalSinceNow.rounded())) 秒"
        } else if askMore {
            text += "。回到練壯看看要不要再多做一點"
        } else if allDone {
            text += "。全部做完了，回到練壯按「完成」"
        }
        return text
    }

    private func loading(of set: SetDraft, in d: ExerciseDraft) -> Loading? {
        guard d.item.exercise.loaded, set.weight > 0 else { return nil }
        return d.ladder.loading(set.weight, kit: set.kit)
    }

    /// 下一組（這個動作還沒做的，或下一個動作的第一組）
    private func nextSet(after i: Int) -> (Int, SetDraft)? {
        if let s = drafts[i].sets.first(where: { !$0.done }) { return (i, s) }
        for j in drafts.indices where j > i {
            if let s = drafts[j].sets.first(where: { !$0.done }) { return (j, s) }
        }
        return nil
    }

    /// 這次休息要換的器材：換成下一組的重量；下一組是 Drop set 前的最後一組，就先用另一組啞鈴裝好；
    /// 下一組是用另一組啞鈴的熱身，順便把主要啞鈴裝成正式組重量。
    /// 不改 rigs，休息結束（或做下一組）時才當作換好了。
    private func restChanges(after i: Int) -> [RigChange] {
        guard let found = nextSet(after: i) else { return [] }
        let (j, _) = found
        let upcoming = drafts[j].sets.filter { !$0.done }
            .map { SetPlanner.PlanStep(kind: $0.kind, kit: $0.kit, loading: loading(of: $0, in: drafts[j])) }
        let steps = SetPlanner.rigSteps(upcoming: upcoming, sameExercise: j == i,
                                        exerciseName: drafts[j].item.exercise.name,
                                        rigs: rigs, kits: WeightKits.load())
        return steps.map {
            RigChange(label: $0.label, kit: $0.loading.kit, use: $0.loading.use, from: $0.from?.plates,
                      to: $0.loading.plates, seconds: $0.seconds, assemble: $0.assemble)
        }
    }

    /// 依「還剩幾下」自動調整這個動作接下來的正式組：還剩 4 下以上就加重，力竭又沒做到下限就減重。
    private func autoAdjust(_ i: Int, after s: Int) {
        let set = drafts[i].sets[s]
        guard drafts[i].item.exercise.loaded, set.weight > 0, set.rir >= 0 else { return }
        let later = drafts[i].sets.indices.filter { $0 > s && !drafts[i].sets[$0].done && drafts[i].sets[$0].kind == .work }
        guard !later.isEmpty else { return }
        let ladder = drafts[i].ladder
        let up: Bool
        if set.rir >= 4 { up = true }
        else if set.rir == 0 && set.reps < drafts[i].item.low { up = false }
        else { return }
        for j in later {
            let w = drafts[i].sets[j].weight
            drafts[i].sets[j].weight = up ? ladder.up(w) : ladder.down(w)
        }
        let next = drafts[i].sets[later[0]].weight
        showToast(up ? "還很有力氣，接下來改 \(Progression.format(next)) kg" : "太吃力了，接下來改 \(Progression.format(next)) kg")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if toast == text { withAnimation { toast = nil } }
        }
    }

    // MARK: Scheme, warm-up, swap

    private func isFirstInRegion(_ ex: Exercise, before index: Int) -> Bool {
        guard let r = ex.pattern.region else { return false }
        return !drafts.prefix(index).contains { $0.item.exercise.pattern.region == r }
    }

    /// 重新排一個動作的組（還沒做的部分）；已做完的熱身組留著。
    private func rebuild(_ i: Int, item: PlannedExercise? = nil, scheme: SetScheme? = nil) {
        let old = drafts[i]
        let it = item ?? old.item
        var d = makeDraft(it, firstInRegion: isFirstInRegion(it.exercise, before: i), scheme: scheme ?? old.chosen)
        if item == nil { d.note = old.note }
        let doneWarm = old.sets.filter { $0.done && $0.kind == .warmup }
        if !doneWarm.isEmpty {
            d.sets = doneWarm + d.sets.filter { $0.kind != .warmup }
        } else if !old.hasWarmups && item == nil {
            d.sets = d.sets.filter { $0.kind != .warmup }
        }
        drafts[i] = d
    }

    private func setScheme(_ scheme: SetScheme, at i: Int) {
        guard !drafts[i].locked else { return }
        SchemeStore.set(scheme, for: drafts[i].item.exercise.id)
        rebuild(i, scheme: scheme)
    }

    private func toggleWarmup(at i: Int) {
        guard !drafts[i].locked else { return }
        if drafts[i].hasWarmups {
            drafts[i].sets.removeAll { $0.kind == .warmup && !$0.done }
        } else {
            let ex = drafts[i].item.exercise
            let w = drafts[i].sets.first { $0.kind == .work }?.weight ?? 0
            let warm = SetPlanner.warmups(for: ex, workWeight: w, first: isFirstInRegion(ex, before: i),
                                          ladder: drafts[i].ladder, avoidKit: barbellKit)
            if warm.isEmpty {
                showToast(w > 0 ? "這個動作重量不重，不用熱身" : "先填正式組的重量，才能算熱身組")
                return
            }
            drafts[i].sets.insert(contentsOf: warm.map { SetDraft(weight: $0.weight, reps: $0.reps, kind: .warmup, kit: $0.kit) }, at: 0)
        }
    }

    /// 健身房模式：同一類動作、今天還沒排到的都可以換。
    private func swapOptions(for i: Int) -> [Exercise] {
        let ex = drafts[i].item.exercise
        let used = Set(drafts.map(\.id))
        return ExerciseLibrary.candidates(for: ex.pattern, equipment: equipment).filter { !used.contains($0.id) }
    }

    private func swap(at i: Int, to ex: Exercise) {
        guard !drafts[i].locked else { return }
        let old = drafts[i].item
        let range = ex.range ?? old.low...old.high
        let item = PlannedExercise(exercise: ex, sets: old.sets, low: range.lowerBound, high: range.upperBound,
                                   restSeconds: old.restSeconds, essential: old.essential)
        rebuild(i, item: item, scheme: SchemeStore.scheme(for: ex.id))
        showToast("換成「\(ex.name)」")
    }

    /// 這場被拿去接槓鈴的那組器材（熱身不用它）
    private var barbellKit: String? {
        isGym ? nil : SetPlanner.barbellKit(in: drafts.map(\.ladder))
    }

    private func makeDraft(_ item: PlannedExercise, firstInRegion: Bool, scheme chosenOverride: SetScheme? = nil,
                           avoidKit: String? = nil) -> ExerciseDraft {
        let phase = ProgramBuilder.phase(week: week)
        let last = Progression.lastSets(for: item.exercise.id, in: sessions)
        let ladder = WeightLadder.make(item.exercise, gym: isGym, step: increment)
        let chosen = chosenOverride ?? SchemeStore.scheme(for: item.exercise.id)
        let plateau = length == .minimal || phase != .normal ? nil : Plateau.check(exerciseId: item.exercise.id, sessions: sessions)
        let planned = SetPlanner.plannedSets(item: item, last: last, phase: phase, ladder: ladder, chosen: chosen,
                                             minimal: length == .minimal, autoWarmup: autoWarmup,
                                             firstInRegion: firstInRegion, avoidKit: avoidKit ?? barbellKit,
                                             plateau: plateau)
        let s = planned.suggestion
        var sets = planned.sets.map { SetDraft(weight: $0.weight, reps: $0.reps, kind: $0.kind, kit: $0.kit, target: $0.reps) }
        adjustForReadiness(&sets, ladder: ladder, loaded: item.exercise.loaded)
        var lastText = ""
        if !last.isEmpty {
            let reps = last.map { String($0.reps) }.joined(separator: "、")
            let w = last.map(\.weight).max() ?? 0
            lastText = item.exercise.loaded && w > 0
                ? "上次 \(Progression.format(w)) kg × \(reps)"
                : "上次 \(reps) \(item.exercise.unit.label)"
        }
        var draft = ExerciseDraft(item: item, suggestion: s, lastText: lastText, sets: sets,
                                  last: last.map { LastSet(weight: $0.weight, reps: $0.reps) },
                                  chosen: chosen, scheme: planned.scheme, ladder: ladder)
        draft.plateauReset = plateau != nil
        draft.lastNote = ExerciseNotes.last(for: item.exercise.id, in: sessions)?.note
        draft.trend = ExerciseTrend.points(for: item.exercise.id, loaded: item.exercise.loaded, in: sessions)
        return draft
    }

    /// 狀態偏低：每個動作少 1 個正式組（至少留 1 組）；很低再把正式組和遞減組的重量降一級。
    private func adjustForReadiness(_ sets: inout [SetDraft], ladder: WeightLadder, loaded: Bool) {
        guard let level = readiness?.level, level == .low || level == .veryLow else { return }
        let work = sets.indices.filter { sets[$0].kind == .work }
        if work.count >= 2, let lastWork = work.last { sets.remove(at: lastWork) }
        guard level == .veryLow, loaded else { return }
        for k in sets.indices where sets[k].kind != .warmup && sets[k].weight > 0 {
            sets[k].weight = ladder.down(sets[k].weight)
        }
    }

    /// 破個人紀錄：有負重的動作，重量超過以前的最高重量（第一次做不算，和牌位的定義一樣）。
    @discardableResult
    private func checkRecord(_ d: ExerciseDraft, set: SetDraft) -> Bool {
        let ex = d.item.exercise
        guard ex.loaded, set.weight > 0, let old = bests[ex.id], set.weight > old else { return false }
        bests[ex.id] = set.weight
        prCount.insert(ex.id)
        let m = PRMoment(name: ex.name, weight: set.weight, old: old)
        prMoment = m
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + PRMoment.duration + 0.1) {
            if prMoment?.id == m.id { prMoment = nil }
        }
        return true
    }

    private func buildDrafts() {
        guard drafts.isEmpty, readiness != nil else { return }
        var b: [String: Double] = [:]
        for s in sessions {
            for e in s.entries where e.weight > 0 {
                b[e.exerciseId] = max(b[e.exerciseId] ?? 0, e.weight)
            }
        }
        bests = b
        let plan = ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length, limitBarbell: lessBarbell)
        var seen = Set<String>()
        let planBarbellKit = isGym ? nil : SetPlanner.barbellKit(in: plan.map {
            WeightLadder.make($0.exercise, gym: false, step: increment)
        })
        drafts = plan.map { item in
            let region = item.exercise.pattern.region
            let first = region.map { !seen.contains($0) } ?? false
            if let region { seen.insert(region) }
            return makeDraft(item, firstInRegion: first, avoidKit: planBarbellKit)
        }
    }

    private func addSet() {
        guard var lastDraft = drafts.last,
              let lastSet = lastDraft.sets.last(where: { $0.kind == .work }) ?? lastDraft.sets.last else { return }
        lastDraft.sets.append(SetDraft(weight: lastSet.weight, reps: lastSet.reps, target: lastSet.target))
        drafts[drafts.count - 1] = lastDraft
    }

    private func addNextExercise() {
        guard let item = nextExtra else { return }
        drafts.append(makeDraft(item, firstInRegion: isFirstInRegion(item.exercise, before: drafts.count)))
    }

    private func finish() {
        guard doneSets > 0 else {
            showNothingDone = true
            return
        }
        restEnd = nil
        restAfter = nil
        let shards = comboShards
        let bonus = bonusShards
        if shards + bonus.total > 0 { inventory.state.shards += shards + bonus.total }
        let doneWork = drafts.flatMap { $0.sets.filter { $0.done && $0.kind == .work } }
        let now = Date()
        let session = WorkoutSession(date: now, dayKey: day.id, length: length,
                                     durationSeconds: Int(now.timeIntervalSince(startedAt)))
        session.note = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        session.exerciseNotes = ExerciseNotes.encode(Dictionary(drafts.map { ($0.item.exercise.id, $0.note) }, uniquingKeysWith: { a, _ in a }))
        session.readiness = readiness?.encoded ?? ""
        context.insert(session)
        for d in drafts {
            for (i, set) in d.sets.enumerated() where set.done {
                let entry = SetEntry(exerciseId: d.item.exercise.id, setIndex: i,
                                     weight: d.item.exercise.loaded ? set.weight : 0,
                                     reps: set.reps, date: now, kind: set.kind, rir: set.rir)
                entry.session = session
                context.insert(entry)
            }
        }
        try? context.save()
        // 停滯後減重重新爬的動作：從這次之後重新算
        for d in drafts where d.plateauReset && d.sets.contains(where: { $0.done && $0.kind == .work }) {
            Plateau.markReset(d.item.exercise.id)
        }
        // 成果畫面：週目標、連續週數用存檔前的紀錄＋這一次算
        let dates = sessions.filter { $0 !== session }.map(\.date)
        withAnimation(.easeOut(duration: 0.25)) {
            summary = WorkoutSummary(
                sets: drafts.reduce(0) { $0 + $1.sets.filter { $0.done && $0.kind == .work }.count },
                seconds: session.durationSeconds,
                prs: prCount.count,
                points: RankEngine.points(for: length) + min(RankEngine.prCap, prCount.count * RankEngine.prPoints),
                weekDone: SharedStore.countThisWeek(dates + [now]),
                weekGoal: GoalEngine.current(dates: dates + [now], goal: weeklyGoal, ctx: .load()).goal,
                streakBefore: GoalEngine.streak(dates: dates),
                streakAfter: GoalEngine.streak(dates: dates + [now]),
                bestCombo: bestCombo, onTime: onTimeRests, rests: scoredRests, comboShards: shards,
                perfect: doneWork.filter { $0.grade == .perfect }.count,
                good: doneWork.filter { $0.grade == .good }.count,
                miss: doneWork.filter { $0.grade == .miss }.count,
                bonuses: bonus.lines)
        }
    }

    /// 任務獎勵：熱身全部做完每個動作 +1（最多 3）；做完 Drop set 每次 +2（最多 4）。
    private var bonusShards: (total: Int, lines: [String]) {
        let warm = min(3, drafts.filter { d in
            d.hasWarmups && d.sets.filter { $0.kind == .warmup }.allSatisfy(\.done)
        }.count)
        let drops = min(2, drafts.filter { d in d.sets.contains { $0.kind == .drop && $0.done } }.count)
        var lines: [String] = []
        if warm > 0 { lines.append("熱身做完整 +\(warm)") }
        if drops > 0 { lines.append("完成 Drop set +\(drops * 2)") }
        return (warm + drops * 2, lines)
    }

    /// 這次訓練的備註（存檔時一起存）
    private var sessionNoteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("這次訓練的備註", systemImage: "square.and.pencil")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Theme.muted)
            TextField("例如：今天左肩怪怪的", text: $sessionNote, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
                .padding(12)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Exercise card

struct ExerciseCard: View {
    @Binding var draft: ExerciseDraft
    let number: Int
    let total: Int
    let activeSetId: UUID?
    let increment: Double
    var swapOptions: [Exercise] = []
    let onFocus: (UUID) -> Void
    let onComplete: (UUID) -> Void
    var onScheme: (SetScheme) -> Void = { _ in }
    var onToggleWarmup: () -> Void = {}
    var onSwap: (Exercise) -> Void = { _ in }

    private var ex: Exercise { draft.item.exercise }
    private var finished: Bool { draft.sets.allSatisfy(\.done) }
    private var hasActive: Bool { draft.sets.contains { $0.id == activeSetId } }
    @EnvironmentObject private var inventory: InventoryStore

    private var demoStage: some View {
        CharacterView(move: CharacterMove.forExercise(ex), loadout: inventory.state.loadout,
                      animated: true, showStats: false)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RadialGradient(
                    colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                    center: .top, startRadius: 10, endRadius: 260),
                in: RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasActive {
                demoStage
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("動作 \(number) / \(total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hasActive ? Theme.hotText : Theme.muted)
                    Text(ex.name)
                        .font(.system(size: hasActive ? 24 : 18, weight: .black))
                        .foregroundStyle(Theme.fg)
                    Text(target)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                } else if !draft.locked && (ex.loaded || !swapOptions.isEmpty) {
                    optionsMenu
                }
            }

            if hasActive {
                if draft.scheme != .straight {
                    HStack(alignment: .top, spacing: 2) {
                        Label(draft.scheme.explain, systemImage: "chart.bar.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accentSoft)
                        InfoTip(item: draft.scheme == .dropset ? .dropset : .pyramid)
                    }
                }
                Text(draft.suggestion.note)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(draft.suggestion.note.contains("加重") ? Theme.hotText : Theme.accentSoft)
                Text(ex.tip)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                noteEditor
            } else if !draft.note.isEmpty {
                Label(draft.note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(Theme.accentSoft)
            }

            VStack(spacing: 8) {
                ForEach($draft.sets) { $set in
                    let tag = label(for: set)
                    if set.id == activeSetId {
                        ActiveSetEditor(set: $set, tag: tag, exercise: ex, ladder: draft.ladder,
                                        last: draft.lastFor(set), low: draft.item.low) {
                            onComplete(set.id)
                        }
                    } else {
                        CompactSetRow(set: set, tag: tag, exercise: ex) {
                            if set.done { onComplete(set.id) } else { onFocus(set.id) }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(hasActive ? Theme.accentDim : Theme.line, lineWidth: 1))
        .opacity(finished && !hasActive ? 0.7 : 1)
    }

    private var target: String {
        let work = draft.sets.filter { $0.kind == .work }.count
        var base = "目標 \(work) 組 × \(draft.item.low)–\(draft.item.high) \(ex.unit.label)"
        if draft.scheme != .straight { base += " · " + draft.scheme.short }
        return draft.lastText.isEmpty ? base : base + " · " + draft.lastText
    }

    /// 正式組顯示第幾組，熱身組、遞減組顯示「熱」「降」。
    private func label(for set: SetDraft) -> String {
        if let b = set.kind.badge { return b }
        guard let i = draft.sets.firstIndex(where: { $0.id == set.id }) else { return "" }
        return "\(draft.sets[...i].filter { $0.kind == .work }.count)"
    }

    /// 動作備註：上次寫的放上面，這次的可以改（例如「椅子調第 3 格」）
    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastNote = draft.lastNote {
                Label("上次備註：\(lastNote)", systemImage: "note.text")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.gold)
            }
            TextField(draft.lastNote == nil ? "動作備註（例如：椅子調第 3 格）" : "這次的備註", text: $draft.note, axis: .vertical)
                .lineLimit(1...3)
                .font(.caption)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var optionsMenu: some View {
        Menu {
            if ex.loaded {
                Picker("組數排法", selection: Binding(get: { draft.chosen }, set: { onScheme($0) })) {
                    ForEach(SetScheme.allCases) { s in
                        Text(s == .auto ? "自動（\(draft.chosen == .auto ? draft.scheme.short : "依課表")）" : s.title).tag(s)
                    }
                }
                Button(draft.hasWarmups ? "移除熱身組" : "加熱身組", systemImage: "flame") { onToggleWarmup() }
            }
            if !swapOptions.isEmpty {
                Menu("換動作（器材被佔用）") {
                    ForEach(swapOptions) { e in
                        Button(e.name) { onSwap(e) }
                    }
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(Theme.accentSoft)
                .frame(width: 40, height: 40)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel("組數排法與熱身")
    }
}

struct CompactSetRow: View {
    let set: SetDraft
    let tag: String
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(tag)
                    .font(set.kind == .work ? Theme.number(15) : .caption.weight(.heavy))
                    .foregroundStyle(set.kind == .work ? Theme.muted : (set.kind == .warmup ? Theme.accentSoft : Theme.hotText))
                    .frame(width: 24, alignment: .leading)
                Text(label)
                    .font(Theme.number(17))
                    .foregroundStyle(set.done ? Theme.fg : Theme.muted)
                Spacer()
                if let g = set.grade {
                    Text(g.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(g == .miss ? Theme.muted : Theme.bg)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(g == .miss ? Theme.raised : g.color, in: Capsule())
                }
                ZStack {
                    if set.done {
                        Circle().fill(Theme.accent)
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Theme.bg)
                    } else {
                        Circle().stroke(Theme.line, lineWidth: 2)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(set.kind == .warmup && !set.done ? 0.8 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityHint(set.done ? "點一下取消完成" : "點一下改做這一組")
    }

    private var label: String {
        let reps = "\(set.reps) \(exercise.unit.label)"
        guard exercise.loaded else { return reps }
        return "\(Progression.format(set.weight)) kg × \(set.reps)"
    }
}

struct ActiveSetEditor: View {
    @Binding var set: SetDraft
    let tag: String
    let exercise: Exercise
    let ladder: WeightLadder
    /// 上次同一組（幽靈模式）
    var last: LastSet? = nil
    /// 這個動作的次數下限（判定 MISS 用）
    var low: Int = 0
    let onDone: () -> Void
    @State private var holding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(set.kind == .work ? "第 \(tag) 組" : set.kind.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(set.kind == .work ? Theme.fg : (set.kind == .warmup ? Theme.accentSoft : Theme.hotText))
            HStack(spacing: 10) {
                if exercise.loaded {
                    stepperBox(
                        minus: { set.weight = ladder.down(set.weight) },
                        plus: { set.weight = ladder.up(set.weight) },
                        minusLabel: "減少重量", plusLabel: "增加重量"
                    ) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            TextField("0", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(Theme.number(22))
                                .foregroundStyle(Theme.fg)
                                .frame(width: 52)
                            Text("kg").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                stepperBox(
                    minus: { set.reps = max(0, set.reps - repStep) },
                    plus: { set.reps = min(300, set.reps + repStep) },
                    minusLabel: "減少次數", plusLabel: "增加次數"
                ) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(set.reps)").font(Theme.number(22)).foregroundStyle(Theme.fg)
                        Text(exercise.unit.label).font(.caption).foregroundStyle(Theme.muted)
                    }
                    .frame(minWidth: 52)
                }
            }
            if exercise.loaded, set.weight > 0 {
                if let l = ladder.loading(set.weight, kit: set.kit) {
                    Label(l.text, systemImage: "circle.grid.2x1.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accentSoft)
                } else if !ladder.isEmpty {
                    Label("你的器材裝不出 \(Progression.format(set.weight)) kg，按 ＋／− 會跳到裝得出來的重量", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.hotText)
                }
            }
            if set.kind == .work, let last {
                ghostRow(last)
            }
            if set.kind == .work {
                rirPicker
                gradePreview
            }
            if exercise.unit == .seconds {
                Button {
                    holding = true
                } label: {
                    Label("開始計時（倒數 3 秒）", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
            } else {
                TempoBar(exerciseId: exercise.id)
            }
            Button(action: onDone) {
                Text("完成這一組")
            }
            .buttonStyle(HotButtonStyle(height: 52))
        }
        .fullScreenCover(isPresented: $holding) {
            HoldTimerView(name: exercise.name, target: max(set.target, set.reps), onDone: { secs in
                set.reps = secs
                holding = false
            }, onCancel: { holding = false })
        }
        .padding(14)
        .background(Color(gearHex: "#1E2633"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hot, lineWidth: 2))
    }

    private var repStep: Int { exercise.unit == .seconds ? 5 : 1 }

    /// 幽靈模式：和上次同一組比，輸入時即時更新
    private func ghostRow(_ last: LastSet) -> some View {
        let g = GhostDelta.compare(weight: set.weight, reps: set.reps, last: last, loaded: exercise.loaded,
                                   unit: exercise.unit.label)
        let lastText = exercise.loaded && last.weight > 0
            ? "\(Progression.format(last.weight)) kg × \(last.reps)" : "\(last.reps) \(exercise.unit.label)"
        return HStack(spacing: 6) {
            Image(systemName: "person.fill.questionmark")
                .font(.caption)
                .foregroundStyle(Theme.muted.opacity(0.7))
            Text("上次 \(lastText)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Label(g.text, systemImage: g.icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(g.color)
            InfoTip(item: .ghost)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Theme.sunken.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 填好「還剩幾下」後先預告會拿到什麼
    @ViewBuilder
    private var gradePreview: some View {
        let g = SetGrade.judge(reps: set.reps, rir: set.rir, target: set.target, low: low)
        HStack(spacing: 6) {
            Text("目標 \(set.target) \(exercise.unit.label) · 還剩 1～2 下 = PERFECT")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            if set.rir >= 0 {
                Text(g.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(g.color)
            }
            InfoTip(item: .grade)
        }
    }

    /// 做完還剩幾下力氣：用來自動調整下一組，也用來判定 PERFECT。
    private var rirPicker: some View {
        HStack(spacing: 6) {
            Text("還能再做幾下？")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            InfoTip(item: .rir)
            Spacer(minLength: 0)
            ForEach(0..<5, id: \.self) { v in
                let on = set.rir == v
                Button {
                    set.rir = on ? -1 : v
                } label: {
                    Text(v == 4 ? "4+" : "\(v)")
                        .font(Theme.number(14))
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                        .frame(width: 36, height: 32)
                        .background(on ? Theme.accent : Theme.sunken, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(v == 4 ? "還剩 4 下以上" : "還剩 \(v) 下")
            }
        }
    }

    private func stepperBox<Content: View>(minus: @escaping () -> Void, plus: @escaping () -> Void,
                                           minusLabel: String, plusLabel: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            stepButton("minus", label: minusLabel, action: minus)
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            stepButton("plus", label: plusLabel, action: plus)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.fg)
                .frame(width: 44, height: 44)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 休息倒數：圓環平滑倒數、頭端有光點；最後 10 秒轉橘、最後 3 秒脈動加震動；時間到按鈕彈出來發光。
struct RestCard: View {
    let end: Date
    let total: Double
    var note: String? = nil
    let onAdd: () -> Void
    let onSkip: () -> Void
    var onExpand: (() -> Void)? = nil

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let left = end.timeIntervalSince(ctx.date)
            if left > 0 {
                running(left: left, now: ctx.date)
            } else {
                finished(over: -left)
            }
        }
        .modifier(SecondTicks(end: end))
    }

    private func running(left: Double, now: Date) -> some View {
        let warm = FXMath.seg(10 - left, 0, 7)
        let col = FXMath.mix(Theme.green, Theme.hot, warm)
        let last3 = left < 3
        let beat = last3 ? 1 + 0.08 * pow(max(0, sin(.pi * FXMath.fract(left))), 4) : 1
        let p = left / max(total, 1)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Ring(progress: p, color: col, lineWidth: 7)
                    // 圓環頭端的光點
                    GeometryReader { g in
                        let r = Double(g.size.width) / 2 - 7
                        let a = -Double.pi / 2 + 2 * Double.pi * p
                        let w = Double(g.size.width), h = Double(g.size.height)
                        Circle().fill(.white)
                            .frame(width: 7, height: 7)
                            .shadow(color: col, radius: 6)
                            .position(x: w / 2 + r * cos(a), y: h / 2 + r * sin(a))
                    }
                    Text(timerInterval: now...end, countsDown: true)
                        .font(Theme.number(15))
                        .foregroundStyle(last3 ? col : Theme.fg)
                }
                .frame(width: 64, height: 64)
                .scaleEffect(beat)
                .shadow(color: col.opacity(last3 ? 0.6 : 0), radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(last3 ? "準備！" : "休息中").font(.subheadline.weight(.bold)).foregroundStyle(last3 ? col : Theme.fg)
                    Text("共 \(Int(total)) 秒").font(.caption).foregroundStyle(Theme.muted)
                    if onExpand != nil {
                        Label("展開", systemImage: "chevron.up").font(.caption2.weight(.bold)).foregroundStyle(Theme.accentSoft)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onExpand?() }
                Spacer(minLength: 0)
                Button("+30 秒", action: onAdd)
                    .buttonStyle(GhostButtonStyle())
                Button("跳過", action: onSkip)
                    .buttonStyle(GhostButtonStyle())
            }
            if let note {
                Label(note, systemImage: "arrow.left.arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accentSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(col.opacity(0.3 + 0.5 * warm), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    private func finished(over: Double) -> some View {
        let pop = 1 + 0.12 * exp(-over * 5) * cos(over * 16)
        let glow = 0.4 + 0.3 * sin(over * 5)
        return Button(action: onSkip) {
            Label("休息結束，下一組！", systemImage: "bolt.fill")
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.bg)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    // 一道光掃過按鈕
                    GeometryReader { g in
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 60)
                            .offset(x: -60 + (Double(g.size.width) + 120) * FXMath.fract(over / 1.6))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .shadow(color: Theme.green.opacity(glow), radius: 14)
        }
        .buttonStyle(.plain)
        .scaleEffect(pop)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
