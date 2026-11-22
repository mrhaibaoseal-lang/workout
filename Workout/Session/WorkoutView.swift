import SwiftUI
import SwiftData

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
    @State private var bests: [String: PRBest] = [:]
    @State private var prMoment: PRMoment?
    @State private var prCount: Set<String> = []
    @State private var summary: WorkoutSummary?
    /// 練完的教練講評（成果畫面按「好」之後顯示）
    @State private var coach: CoachLoader?
    @State private var showCoach = false
    /// 練完問的部位（上次的痠痛退了沒、關節）；空的就不問
    @State private var askMuscles: [Muscle] = []
    @State private var showMuscleCheck = false
    @State private var toast: String?
    /// 每組器材現在裝成什麼樣子，用來估換重量要多久
    @State private var rigs: [String: RigState] = [:]
    /// 正在休息：剛做完的是第幾個動作（用來算下一組和要換的重量）
    /// 剛做完、正在休息的那一組
    @State private var restAfter: UUID?
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
    /// 練前動態熱身、練後伸展跟做
    @State private var showWarmup = false
    @State private var warmupDismissed = false
    @State private var showStretch = false
    @State private var stretchDone = false
    @EnvironmentObject private var inventory: InventoryStore
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4

    private var allDone: Bool {
        drafts.allSatisfy { $0.sets.allSatisfy(\.done) }
    }

    /// The set being worked on: the one the user tapped, else the first unfinished set (in superset order).
    private var activeSetId: UUID? {
        if let f = focused, drafts.contains(where: { $0.sets.contains { $0.id == f && !$0.done } }) {
            return f
        }
        return order.first { !drafts[$0.exercise].sets[$0.set].done }.map { drafts[$0.exercise].sets[$0.set].id }
    }

    /// 整場做組的順序（超級組輪流做）
    private var order: [Superset.Step] {
        Superset.order(groups: drafts.map(\.item.group), kinds: drafts.map { $0.sets.map(\.kind) })
    }

    private func step(of id: UUID) -> Superset.Step? {
        order.first { drafts[$0.exercise].sets[$0.set].id == id }
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
                            if showWarmupCard {
                                warmupCard
                            }
                            ForEach(Array(drafts.indices), id: \.self) { i in
                                exerciseCard(i)
                                linkButton(after: i)
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
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Theme.green, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 24)
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
            .overlay { finishOverlay }
            .fullScreenCover(isPresented: $showWarmup) {
                MobilityFlowView(kind: .warmup, steps: warmupSteps, doneLabel: "開始訓練") { _ in
                    warmupDismissed = true
                    showWarmup = false
                }
                .environmentObject(inventory)
            }
            .fullScreenCover(isPresented: $showStretch, onDismiss: {
                if stretchDone {
                    onFinish()
                    dismiss()
                }
            }) {
                MobilityFlowView(kind: .cooldown, steps: stretchSteps) { _ in
                    stretchDone = true
                    showStretch = false
                }
                .environmentObject(inventory)
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

    /// 練完：先看成果畫面，按「好」再問部位恢復，最後看教練講評。抽出來是為了讓 body 的型別檢查不要太久。
    @ViewBuilder
    private var finishOverlay: some View {
        if showCoach, let c = coach {
            CoachReviewView(loader: c, onStretch: stretchSteps.isEmpty ? nil : { showStretch = true },
                            stretchMinutes: Self.minutes(stretchSteps, kind: .cooldown)) {
                onFinish()
                dismiss()
            }
            .transition(.opacity)
        } else if showMuscleCheck {
            MuscleCheckView(muscles: askMuscles) { answers in
                PersonalVolume.record(answers)
                toCoach()
            }
            .transition(.opacity)
        } else if let s = summary {
            WorkoutCompleteView(summary: s) {
                if askMuscles.isEmpty {
                    toCoach()
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { showMuscleCheck = true }
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: 熱身、伸展

    private var warmupSteps: [MobilityStep] {
        Mobility.warmup(patterns: drafts.map { $0.item.exercise.pattern })
    }

    /// 只看有做的動作
    private var stretchSteps: [MobilityStep] {
        Mobility.cooldown(patterns: drafts.filter { $0.sets.contains(where: \.done) }.map { $0.item.exercise.pattern })
    }

    static func minutes(_ steps: [MobilityStep], kind: MobilityKind) -> Int {
        let s = steps.reduce(0.0) { $0 + Double($1.totalSeconds) + kind.gap + ($1.perSide ? MobilityPhase.switchSeconds : 0) }
        return max(1, Int((s / 60).rounded()))
    }

    /// 還沒做任何一組、沒按過略過
    private var showWarmupCard: Bool {
        readiness != nil && !warmupDismissed && !drafts.isEmpty
            && !drafts.contains { $0.sets.contains(where: \.done) }
    }

    private var warmupCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.flexibility")
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.hot)
                .frame(width: 44, height: 44)
                .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("先動態熱身 \(Self.minutes(warmupSteps, kind: .warmup)) 分鐘")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.fg)
                Text("照今天的動作挑的，角色帶你做")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Button("開始") { showWarmup = true }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.onHot)
                .padding(.horizontal, 14).frame(height: 36)
                .background(Theme.hot, in: Capsule())
            Button {
                withAnimation { warmupDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("略過熱身")
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hotLine, lineWidth: 1))
    }

    private func toCoach() {
        if coach != nil {
            withAnimation(.easeOut(duration: 0.25)) { showCoach = true }
        } else {
            onFinish()
            dismiss()
        }
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
        guard restEnd != nil, let id = restAfter else { return [] }
        return restChanges(after: id)
    }

    /// 休息後要做的那一組：(第幾個動作, 第幾組)
    private var restPosition: (Int, Int)? {
        guard restEnd != nil, let id = restAfter, let found = nextSet(after: id),
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
        return RestNext(exercise: d.item.exercise, tag: tag, ladder: d.ladder, last: last, newExercise: j != restAfter.flatMap { step(of: $0) }?.exercise,
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
        if let id = restAfter {
            for c in restChanges(after: id) { rigs[c.kit] = c.target }
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
            // 「還剩幾下」填得太保守：同重量下一組掉很多下就提醒（`RIRCheck`）
            let prevWork = d.sets[..<s].last { $0.kind == .work && $0.done }
            if let p = prevWork, let hint = RIRCheck.hint(prevReps: p.reps, prevRir: p.rir, prevWeight: p.weight,
                                                          curReps: done.reps, curWeight: done.weight) {
                showToast(hint)
            }
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
            let nextFound = nextSet(after: id)
            let cur = step(of: id)
            let nextStep = nextFound.flatMap { step(of: $0.1.id) }
            let chores = restChanges(after: id)
            let change = chores.reduce(0) { $0 + $1.seconds }
            if let cur, let nextStep, Superset.isTransition(cur, nextStep), let nextFound {
                // 超級組輪內換動作：不休息；要換重量就給換的時間
                let name = drafts[nextFound.0].item.exercise.name
                if change > 0 {
                    restAfter = id
                    restReasons = ["超級組換動作：換重量約 \(change) 秒，換完直接做「\(name)」"]
                    restMinimized = false
                    let rest = change + Superset.transitionExtra
                    restTotal = Double(rest)
                    withAnimation(.spring(duration: 0.4)) {
                        restEnd = Date().addingTimeInterval(TimeInterval(rest))
                    }
                } else {
                    restEnd = nil
                    restAfter = nil
                    showToast("\(groupName(of: exerciseIndex))：接著做「\(name)」，不休息")
                }
                return
            }
            let normal = cur.map { Superset.restSeconds(after: $0, plan: drafts.map(\.item)) } ?? drafts[exerciseIndex].item.restSeconds
            var rest = SetPlanner.rest(after: set.kind, next: nextFound?.1.kind, normal: normal)
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
                if cur?.group != nil && nextStep?.group == cur?.group && nextStep?.exercise != cur?.exercise {
                    reasons.append("\(groupName(of: exerciseIndex))這一輪做完了，現在才休息")
                }
                restAfter = id
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

    /// 做完 id 這組之後的下一組（照整場順序，超級組輪流；後面都做完了就從前面沒做的找）
    private func nextSet(after id: UUID) -> (Int, SetDraft)? {
        let ord = order
        let pending = { (st: Superset.Step) in !drafts[st.exercise].sets[st.set].done }
        let p = ord.firstIndex { drafts[$0.exercise].sets[$0.set].id == id }
        let st = (p.flatMap { ord[($0 + 1)...].first(where: pending) }) ?? ord.first(where: pending)
        return st.map { ($0.exercise, drafts[$0.exercise].sets[$0.set]) }
    }

    /// 這個動作所在的超級組／循環組名稱
    private func groupName(of i: Int) -> String {
        guard let g = drafts[i].item.group else { return "" }
        return Superset.name(size: drafts.filter { $0.item.group == g }.count)
    }

    /// 這次休息要換的器材：換成下一組的重量；下一組是 Drop set 前的最後一組，就先用另一組啞鈴裝好；
    /// 下一組是用另一組啞鈴的熱身，順便把主要啞鈴裝成正式組重量。
    /// 不改 rigs，休息結束（或做下一組）時才當作換好了。
    /// 超級組一輪結束的休息：順便把同一組其他動作下一輪的重量裝好。
    private func restChanges(after id: UUID) -> [RigChange] {
        guard let found = nextSet(after: id) else { return [] }
        let (j, nextDraft) = found
        let cur = step(of: id)
        let nextStep = step(of: nextDraft.id)
        let i = cur?.exercise ?? j
        let upcoming = drafts[j].sets.filter { !$0.done }
            .map { SetPlanner.PlanStep(kind: $0.kind, kit: $0.kit, loading: loading(of: $0, in: drafts[j])) }
        var also: [(name: String, loading: Loading)] = []
        if let g = drafts[j].item.group, let cur, let nextStep, !Superset.isTransition(cur, nextStep) {
            var got: Set<Int> = [j]
            for st in order where st.group == g && !got.contains(st.exercise) && !drafts[st.exercise].sets[st.set].done {
                got.insert(st.exercise)
                let d = drafts[st.exercise]
                if let l = loading(of: d.sets[st.set], in: d) { also.append((d.item.exercise.name, l)) }
            }
        }
        let steps = SetPlanner.rigSteps(upcoming: upcoming, sameExercise: j == i,
                                        exerciseName: drafts[j].item.exercise.name,
                                        rigs: rigs, kits: WeightKits.load(), also: also)
        return steps.map {
            RigChange(label: $0.label, kit: $0.loading.kit, use: $0.loading.use, from: $0.from?.plates,
                      to: $0.loading.plates, seconds: $0.seconds, assemble: $0.assemble)
        }
    }

    /// 依「還剩幾下」自動調整這個動作接下來的正式組：還剩 4 下以上就加重，力竭又沒做到下限就減重。
    private func autoAdjust(_ i: Int, after s: Int) {
        let set = drafts[i].sets[s]
        // 試重組只有第一個正式組；做完（不管有沒有填）就不再是試重
        let isTrial = drafts[i].trial
        drafts[i].trial = false
        guard drafts[i].item.exercise.loaded, set.weight > 0, set.rir >= 0 else { return }
        let later = drafts[i].sets.indices.filter { $0 > s && !drafts[i].sets[$0].done && drafts[i].sets[$0].kind == .work }
        guard !later.isEmpty else { return }
        let ladder = drafts[i].ladder
        if isTrial {
            calibrate(i, from: set, later: later, ladder: ladder)
            return
        }
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

    /// 試重組做完：用這組的推估最大力量，把後面每組調到「做到目標次數還剩 2 下」的重量（可以一次跳好幾級）。
    private func calibrate(_ i: Int, from set: SetDraft, later: [Int], ladder: WeightLadder) {
        var changed = false
        for j in later {
            let target = drafts[i].sets[j].target > 0 ? drafts[i].sets[j].target : drafts[i].item.high
            let w = StartWeight.calibrated(weight: set.weight, reps: set.reps, rir: set.rir, target: target, ladder: ladder)
            if w > 0 && abs(w - drafts[i].sets[j].weight) > 0.01 {
                drafts[i].sets[j].weight = w
                changed = true
            }
        }
        let next = drafts[i].sets[later[0]].weight
        showToast(changed ? "試重完成：接下來用 \(Progression.format(next)) kg" : "試重完成：這個重量剛好")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(duration: 0.3)) { toast = text }
        // 長的提醒多留一點時間讀
        let seconds = max(2.5, Double(text.count) / 12)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
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
        if it.exercise.id == old.item.exercise.id { d.note = old.note }
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

    /// 一個動作的卡片。抽出來，避免 body 太長編譯器 type-check 逾時。
    private func exerciseCard(_ i: Int) -> some View {
        ExerciseCard(draft: $drafts[i], number: i + 1, total: drafts.count,
                     activeSetId: activeSetId, increment: increment,
                     swapOptions: isGym ? swapOptions(for: i) : [],
                     onFocus: { focused = $0 },
                     onComplete: { id in complete(set: id, in: i) },
                     onScheme: { setScheme($0, at: i) },
                     onToggleWarmup: { toggleWarmup(at: i) },
                     onSwap: { swap(at: i, to: $0) },
                     group: groupBadge(i),
                     canReplace: replacement(for: i) != nil,
                     onEasePain: { easePain(at: i, joint: $0) },
                     onAvoid: { avoid(at: i, reason: $0, joint: $1) },
                     onLogPain: { logPainOnly(at: i, joint: $0) })
            .id(drafts[i].id)
    }

    // MARK: 會痛／不喜歡

    /// 還沒做任何一組（含熱身）才能換掉；換成同類型下一個沒被標記、今天還沒排到的動作。
    private func replacement(for i: Int) -> Exercise? {
        guard drafts.indices.contains(i), !drafts[i].sets.contains(where: \.done) else { return nil }
        let current = drafts[i].item.exercise
        let used = Set(drafts.map(\.id))
        return ExerciseLibrary.candidates(for: current.pattern, equipment: equipment)
            .first { !used.contains($0.id) && $0.id != current.id }
    }

    /// 「這次減輕 20% 試試」：這個動作還沒做的組，重量降到階梯上不超過 80% 的那一級，並記一筆痛的紀錄（不標記動作）。
    private func easePain(at i: Int, joint: Joint?) {
        guard drafts.indices.contains(i) else { return }
        let ladder = drafts[i].ladder
        for k in drafts[i].sets.indices where !drafts[i].sets[k].done && drafts[i].sets[k].weight > 0 {
            drafts[i].sets[k].weight = ladder.snap(drafts[i].sets[k].weight * 0.8)
            drafts[i].sets[k].eased = true
        }
        Avoid.logPain(drafts[i].item.exercise.id, joint: joint)
        refreshCautions()
        showToast("這個動作剩下的組減輕約兩成，不舒服就停下來")
    }

    /// 只記一筆痛的紀錄（沒有重量可減、也不能換的時候）。
    private func logPainOnly(at i: Int, joint: Joint?) {
        guard drafts.indices.contains(i) else { return }
        Avoid.logPain(drafts[i].item.exercise.id, joint: joint)
        refreshCautions()
        showToast("記下來了，不舒服就停下來")
    }

    /// 剛回報會痛：今天其他用到同一個關節的動作，卡片上馬上出現提醒。
    private func refreshCautions() {
        let pain = Joint.recentPain()
        for k in drafts.indices {
            drafts[k].caution = Joint.caution(for: drafts[k].item.exercise, pain: pain)
        }
    }

    /// 標記會痛／不喜歡，並換成同類型下一個候選（之後排課也不會再排它）。
    private func avoid(at i: Int, reason: AvoidReason, joint: Joint? = nil) {
        guard drafts.indices.contains(i), let next = replacement(for: i) else { return }
        let old = drafts[i].item.exercise
        Avoid.mark(old.id, reason: reason)
        if reason == .pain { Avoid.logPain(old.id, joint: joint) }
        swap(at: i, to: next)
        if reason == .pain { refreshCautions() }
        showToast("之後不排「\(old.name)」，換成「\(next.name)」")
    }

    private func swap(at i: Int, to ex: Exercise) {
        guard !drafts[i].locked else { return }
        let item = drafts[i].item.swapped(to: ex)
        rebuild(i, item: item, scheme: SchemeStore.scheme(for: ex.id))
        showToast("換成「\(ex.name)」")
    }

    /// 這場被拿去接槓鈴的那組器材（熱身不用它）
    private var barbellKit: String? {
        isGym ? nil : SetPlanner.barbellKit(in: drafts.map(\.ladder))
    }

    private func makeDraft(_ item: PlannedExercise, firstInRegion: Bool, scheme chosenOverride: SetScheme? = nil,
                           avoidKit: String? = nil) -> ExerciseDraft {
        TrainingHistory.sync(sessions)
        let phase = ProgramBuilder.phase(week: week)
        let last = Progression.lastSets(for: item.exercise.id, in: sessions)
        let ladder = WeightLadder.make(item, gym: isGym, step: increment)
        let chosen = chosenOverride ?? SchemeStore.scheme(for: item.exercise.id)
        let plateau = length == .minimal || phase != .normal ? nil : Plateau.check(exerciseId: item.exercise.id, sessions: sessions)
        let planned = SetPlanner.plannedSets(item: item, last: last, phase: phase, ladder: ladder, chosen: chosen,
                                             minimal: length == .minimal, autoWarmup: autoWarmup,
                                             firstInRegion: firstInRegion, avoidKit: avoidKit ?? barbellKit,
                                             plateau: plateau)
        let s = planned.suggestion
        let oneArm = SideBalance.sided(item.exercise)
        var sets = planned.sets.map {
            SetDraft(weight: $0.weight, reps: $0.reps, kind: $0.kind, kit: $0.kit, target: $0.reps,
                     oneArm: oneArm && $0.kind == .work)
        }
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
        draft.trial = last.isEmpty && item.exercise.loaded && length != .minimal
        draft.lastNote = ExerciseNotes.last(for: item.exercise.id, in: sessions)?.note
        draft.caution = Joint.caution(for: item.exercise, pain: Joint.recentPain())
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
            sets[k].eased = true
        }
    }

    /// 破個人紀錄：有負重的動作，重量超過以前的最高重量，或用最高重量做更多下（`PRRule`，第一次做不算，和牌位的定義一樣）。
    @discardableResult
    private func checkRecord(_ d: ExerciseDraft, set: SetDraft) -> Bool {
        let ex = d.item.exercise
        guard ex.loaded, set.kind == .work, set.weight > 0, let old = bests[ex.id],
              let kind = PRRule.check(weight: set.weight, reps: set.reps, best: old) else { return false }
        bests[ex.id] = PRRule.merge(old, weight: set.weight, reps: set.reps)
        prCount.insert(ex.id)
        let m = PRMoment(name: ex.name, weight: set.weight, kind: kind, reps: set.reps)
        prMoment = m
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + PRMoment.duration + 0.1) {
            if prMoment?.id == m.id { prMoment = nil }
        }
        return true
    }

    private func buildDrafts() {
        guard drafts.isEmpty, readiness != nil else { return }
        bests = PRRule.bests(sessions)
        let plan = ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length, limitBarbell: lessBarbell,
                                       gym: isGym)
        var seen = Set<String>()
        let planBarbellKit = isGym ? nil : SetPlanner.barbellKit(in: plan.map {
            WeightLadder.make($0, gym: false, step: increment)
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
        lastDraft.sets.append(SetDraft(weight: lastSet.weight, reps: lastSet.reps, target: lastSet.target,
                                       oneArm: lastSet.kind == .work && lastSet.oneArm))
        drafts[drafts.count - 1] = lastDraft
    }

    private func addNextExercise() {
        guard var item = nextExtra else { return }
        item.group = nil
        item.kit = nil
        item.sharedKit = nil
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
        session.phase = ProgramBuilder.phase(week: week).rawValue
        context.insert(session)
        for d in drafts {
            for (i, set) in d.sets.enumerated() where set.done {
                let entry = SetEntry(exerciseId: d.item.exercise.id, setIndex: i,
                                     weight: d.item.exercise.loaded ? set.weight : 0,
                                     reps: set.reps, date: now, kind: set.kind, rir: set.rir)
                entry.eased = set.eased
                if set.oneArm || set.kind == .weak { entry.side = SideBalance.first(for: d.item.exercise).rawValue }
                if set.oneArm {
                    entry.otherReps = set.otherReps < 0 ? set.reps : set.otherReps
                    entry.otherRir = set.otherRir
                }
                entry.session = session
                context.insert(entry)
            }
        }
        try? context.save()
        recordJumpState(at: now)
        // 在家啞鈴到頂（或徒手動作）、每組都做到上限：下次自動換成更難的版本（`Upgrade`）
        for d in drafts where !isGym || !d.item.exercise.loaded {
            let work = d.sets.filter { $0.done && $0.kind == .work && !$0.eased }.map { (weight: $0.weight, reps: $0.reps) }
            guard !work.isEmpty, ProgramBuilder.phase(week: week) == .normal else { continue }
            Upgrade.record(item: d.item, work: work, ladder: d.ladder, equipment: equipment)
        }
        coach = CoachLoader(facts: coachFacts(session: session))
        askMuscles = PersonalVolume.musclesToAsk(
            done: drafts.map { d in (exercise: d.item.exercise, sets: d.sets.filter { $0.done && $0.kind == .work }.count) },
            history: sessions.filter { $0 !== session }, now: now)
        // 停滯後減重重新爬的動作：從這次之後重新算
        for d in drafts where d.plateauReset && d.sets.contains(where: { $0.done && $0.kind == .work }) {
            Plateau.markReset(d.item.exercise.id)
        }
        // 成果畫面：週目標、連續週數用存檔前的紀錄＋這一次算
        let dates = sessions.filter { $0 !== session }.map(\.date)
        // 今天稍早已經拿過的訓練分（同一天只算最高的一次，和牌位一樣）
        let paidToday = sessions.filter { $0 !== session && Calendar.current.isDateInToday($0.date) }
            .map { RankEngine.points(for: $0.length) }.max() ?? 0
        withAnimation(.easeOut(duration: 0.25)) {
            summary = WorkoutSummary(
                sets: drafts.reduce(0) { $0 + $1.sets.filter { $0.done && $0.kind == .work }.count },
                seconds: session.durationSeconds,
                prs: prCount.count,
                points: max(0, RankEngine.points(for: length) - paidToday) + min(RankEngine.prCap, prCount.count * RankEngine.prPoints),
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

    /// 「重量跳太大」：依這次的成績更新次數上限、多 1 組、暫時次數範圍（`JumpGuard`）。
    /// 要在算教練講評的「下次預計」之前做，下次預計才會反映新的狀態。
    private func recordJumpState(at date: Date) {
        let phase = ProgramBuilder.phase(week: week)
        TrainingHistory.noteFinished(drafts.filter { $0.sets.contains { $0.done && $0.kind == .work } }.map(\.item.exercise.id),
                                     at: date)
        for d in drafts {
            let ex = d.item.exercise
            let work = d.sets.filter { $0.done && $0.kind == .work }
            guard ex.loaded, !work.isEmpty, !work.allSatisfy(\.eased) else { continue }
            let entries = work.enumerated().map { i, s in
                SetEntry(exerciseId: ex.id, setIndex: i, weight: s.weight, reps: s.reps, date: date, rir: s.rir)
            }
            JumpGuard.record(item: d.item, last: entries, phase: phase, ladder: d.ladder, scheme: d.scheme)
        }
    }

    /// 教練講評用的資料：這次做了什麼、和上次比、下次照規則會排多少。
    private func coachFacts(session: WorkoutSession) -> CoachFacts {
        let phase = ProgramBuilder.phase(week: week)
        let notes = ExerciseNotes.decode(session.exerciseNotes)
        let items: [CoachFacts.Item] = drafts.compactMap { d in
            let ex = d.item.exercise
            let work = d.sets.filter { $0.done && $0.kind == .work }
            guard !work.isEmpty else { return nil }
            // 只拿來算下次的建議，不會存進資料庫
            let entries = work.enumerated().map { i, s in
                SetEntry(exerciseId: ex.id, setIndex: i, weight: ex.loaded ? s.weight : 0, reps: s.reps, date: session.date)
            }
            let next = Progression.suggest(d.item, last: entries, phase: phase, ladder: d.ladder, scheme: d.scheme)
            let lastTop: (weight: Double, reps: Int)? = d.last.isEmpty ? nil : {
                let w = d.last.map(\.weight).max() ?? 0
                return (w, d.last.filter { $0.weight >= w }.map(\.reps).max() ?? 0)
            }()
            return CoachFacts.Item(
                name: ex.name, loaded: ex.loaded, unit: ex.unit.label,
                sets: work.map { (weight: ex.loaded ? $0.weight : 0, reps: $0.reps, grade: $0.grade) },
                lastTop: lastTop, isPR: prCount.contains(ex.id), plateauReset: d.plateauReset,
                nextWeight: ex.loaded ? next.weight : 0, nextReps: next.reps,
                note: notes[ex.id] ?? "")
        }
        let graded = drafts.flatMap { $0.sets.filter { $0.done && $0.kind == .work } }
        return CoachFacts(dayName: day.name, lengthTitle: length.title, phaseTitle: phase.title,
                          minutes: max(1, session.durationSeconds / 60), readiness: readiness,
                          sessionNote: session.note, items: items,
                          perfect: graded.filter { $0.grade == .perfect }.count,
                          good: graded.filter { $0.grade == .good }.count,
                          miss: graded.filter { $0.grade == .miss }.count)
    }

    // MARK: Superset

    private func members(_ g: Int?) -> [Int] {
        guard let g else { return [] }
        return drafts.indices.filter { drafts[$0].item.group == g }
    }

    private func groupBadge(_ i: Int) -> GroupBadge? {
        let item = drafts[i].item
        guard let g = item.group else { return nil }
        let m = members(g)
        let letter = Superset.letters(drafts.map(\.item.group))[g] ?? "A"
        let others = m.filter { $0 != i }.map { "「\(drafts[$0].item.exercise.name)」" }.joined(separator: "")
        var note: String?
        if let k = item.sharedKit {
            note = "和同組動作都用\(k)，每輪要換重量"
        } else if let k = item.kit {
            note = "改用\(k)，同組動作輪流不用換重量"
        }
        return GroupBadge(title: "\(Superset.name(size: m.count)) \(letter)\((m.firstIndex(of: i) ?? 0) + 1)",
                          detail: "和\(others)輪流做，一輪做完才休息", note: note)
    }

    /// 兩個動作中間的「連成超級組／拆開」：只有單關節動作、都還沒開始做才能改。
    @ViewBuilder
    private func linkButton(after i: Int) -> some View {
        if i + 1 < drafts.count, length != .minimal,
           Superset.eligible(drafts[i].item.exercise), Superset.eligible(drafts[i + 1].item.exercise),
           !drafts[i].sets.contains(where: \.done), !drafts[i + 1].sets.contains(where: \.done) {
            let a = drafts[i].item.group, b = drafts[i + 1].item.group
            let linked = a != nil && a == b
            let size = max(1, members(a).count) + max(1, members(b).count)
            if linked || size <= Superset.maxSize {
                Button {
                    withAnimation(.spring(duration: 0.3)) { linked ? unlink(after: i) : link(after: i) }
                } label: {
                    Label(linked ? "拆開" : (size >= 3 ? "連成循環組" : "連成超級組"),
                          systemImage: linked ? "scissors" : "link")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(linked ? Theme.muted : Theme.accentSoft)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.surface, in: Capsule())
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func link(after i: Int) {
        var items = drafts.map(\.item)
        let g = items[i].group ?? items[i + 1].group ?? ((items.compactMap(\.group).max() ?? 0) + 1)
        let old = items[i + 1].group
        items[i].group = g
        for k in items.indices where k == i + 1 || (old != nil && items[k].group == old) { items[k].group = g }
        Superset.separateKits(&items, gym: isGym, equipment: equipment, replaceable: items.map { _ in false })
        apply(items)
        showToast("\(Superset.name(size: items.filter { $0.group == g }.count))：輪流做，一輪做完才休息")
    }

    private func unlink(after i: Int) {
        var items = drafts.map(\.item)
        guard let g = items[i].group else { return }
        let fresh = (items.compactMap(\.group).max() ?? 0) + 1
        for k in items.indices where k > i && items[k].group == g { items[k].group = fresh }
        Superset.dropSingles(&items)
        for k in items.indices where items[k].group == nil { items[k].kit = nil }
        Superset.separateKits(&items, gym: isGym, equipment: equipment, replaceable: items.map { _ in false })
        apply(items)
    }

    /// 套用新的分組：器材或分組變了、還沒開始做的動作重新排組（Drop set、器材跟著變）。
    private func apply(_ items: [PlannedExercise]) {
        for k in items.indices {
            let old = drafts[k].item
            guard old.group != items[k].group || old.kit != items[k].kit || old.sharedKit != items[k].sharedKit else { continue }
            if drafts[k].sets.contains(where: \.done) {
                drafts[k].item.group = items[k].group
                drafts[k].item.sharedKit = items[k].sharedKit
            } else {
                rebuild(k, item: items[k])
            }
        }
    }

    /// 任務獎勵：熱身全部做完每個動作 +1（最多 3）；做完 Drop set 每次 +2（最多 4）；
    /// 超級組／循環組每組的正式組全部做完 +2（最多 4）。
    private var bonusShards: (total: Int, lines: [String]) {
        let warm = min(3, drafts.filter { d in
            d.hasWarmups && d.sets.filter { $0.kind == .warmup }.allSatisfy(\.done)
        }.count)
        let drops = min(2, drafts.filter { d in d.sets.contains { $0.kind == .drop && $0.done } }.count)
        let groups = Set(drafts.compactMap(\.item.group)).filter { g in
            drafts.filter { $0.item.group == g }.allSatisfy { d in d.sets.filter { $0.kind == .work }.allSatisfy(\.done) }
        }
        let supers = min(2, groups.count)
        var lines: [String] = []
        if warm > 0 { lines.append("熱身做完整 +\(warm)") }
        if drops > 0 { lines.append("完成 Drop set +\(drops * 2)") }
        if supers > 0 { lines.append("完成超級組 +\(supers * 2)") }
        return (warm + drops * 2 + supers * 2, lines)
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
