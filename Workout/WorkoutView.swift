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
}

struct ExerciseDraft: Identifiable {
    var item: PlannedExercise
    var suggestion: Suggestion
    /// 「上次 10 kg × 12、11、10」, empty the first time.
    var lastText: String
    var sets: [SetDraft]
    /// 使用者選的排法（可能是自動）
    var chosen: SetScheme = .auto
    /// 實際用的排法
    var scheme: SetScheme = .straight
    /// 這個動作裝得出來的重量
    var ladder = WeightLadder(loadings: [], step: 2.5)
    var id: String { item.id }

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
    /// 休息時要做的事（換重量、先裝好 Drop set）
    @State private var restNote: String?
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
            .onAppear(perform: buildDrafts)
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
        if let end = restEnd {
            RestCard(end: end, total: restTotal, note: restNote,
                     onAdd: {
                         restEnd = end.addingTimeInterval(30)
                         restTotal += 30
                     },
                     onSkip: { restEnd = nil })
        }
    }

    // MARK: Actions

    private func complete(set id: UUID, in exerciseIndex: Int) {
        guard let s = drafts[exerciseIndex].sets.firstIndex(where: { $0.id == id }) else { return }
        if drafts[exerciseIndex].sets[s].done {
            drafts[exerciseIndex].sets[s].done = false
            focused = id
            return
        }
        drafts[exerciseIndex].sets[s].done = true
        focused = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let set = drafts[exerciseIndex].sets[s]
        if set.kind == .work {
            checkRecord(drafts[exerciseIndex], set: set)
            autoAdjust(exerciseIndex, after: s)
        }
        if length == .minimal && allDone {
            restEnd = nil
            askMore = true
        } else if !allDone {
            if let l = loading(of: set, in: drafts[exerciseIndex]) {
                rigs[l.kit] = RigState(use: l.use, plates: l.plates)
            }
            let next = drafts[exerciseIndex].sets.first { !$0.done }?.kind
            var rest = SetPlanner.rest(after: set.kind, next: next, normal: drafts[exerciseIndex].item.restSeconds)
            let (change, note) = restChores(after: exerciseIndex)
            if rest > 0 {
                // 換重量也算休息，但換完至少還要喘一下
                rest = max(rest, change + (set.kind == .warmup ? 20 : 30))
                restNote = note
                restTotal = Double(rest)
                restEnd = Date().addingTimeInterval(TimeInterval(rest))
            } else {
                restEnd = nil
                showToast(note.map { "馬上減重，不休息！" + $0 } ?? "馬上減重，不休息！")
            }
        } else {
            restEnd = nil
        }
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

    /// 這次休息要做的事和大概的秒數：換成下一組的重量；下一組是 Drop set 前的最後一組，就先用另一組啞鈴裝好。
    private func restChores(after i: Int) -> (Int, String?) {
        let kits = WeightKits.load()
        var seconds = 0
        var notes: [String] = []
        func prepare(_ l: Loading, label: String) {
            guard let kit = kits.first(where: { $0.name == l.kit }) else { return }
            let target = RigState(use: l.use, plates: l.plates)
            guard rigs[l.kit] != target else { return }
            let t = WeightKits.changeSeconds(kit: kit, from: rigs[l.kit], to: l)
            seconds += t
            notes.append("\(label)\(l.text)（約 \(t) 秒）")
            rigs[l.kit] = target
        }
        guard let found = nextSet(after: i) else { return (0, nil) }
        let (j, next) = found
        if let l = loading(of: next, in: drafts[j]) {
            prepare(l, label: j == i ? "換重量：" : "下一個動作（\(drafts[j].item.exercise.name)）：")
        }
        // 下一組做完就要 Drop set：趁現在把另一組啞鈴裝好
        let rest = drafts[j].sets.filter { !$0.done }
        if next.kind == .work, rest.count >= 2, rest[1].kind == .drop, rest[1].kit != nil,
           let l = loading(of: rest[1], in: drafts[j]) {
            prepare(l, label: "順便裝好 Drop set：")
        }
        return (seconds, notes.isEmpty ? nil : notes.joined(separator: "\n"))
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
            let warm = SetPlanner.warmups(for: ex, workWeight: w, first: isFirstInRegion(ex, before: i), ladder: drafts[i].ladder)
            if warm.isEmpty {
                showToast(w > 0 ? "這個動作重量不重，不用熱身" : "先填正式組的重量，才能算熱身組")
                return
            }
            drafts[i].sets.insert(contentsOf: warm.map { SetDraft(weight: $0.weight, reps: $0.reps, kind: .warmup) }, at: 0)
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

    private func makeDraft(_ item: PlannedExercise, firstInRegion: Bool, scheme chosenOverride: SetScheme? = nil) -> ExerciseDraft {
        let phase = ProgramBuilder.phase(week: week)
        let last = Progression.lastSets(for: item.exercise.id, in: sessions)
        let ladder = WeightLadder.make(item.exercise, gym: isGym, step: increment)
        let chosen = chosenOverride ?? SchemeStore.scheme(for: item.exercise.id)
        // 只做 1 組的日子不排遞增／遞減
        let scheme = length == .minimal ? .straight : SetPlanner.resolve(chosen, exercise: item.exercise, phase: phase)
        let s = Progression.suggest(item, last: last, phase: phase, ladder: ladder, scheme: scheme)
        let work = SetPlanner.workSets(scheme: scheme, count: item.sets, weight: s.weight, reps: s.reps,
                                       low: item.low, high: item.high, ladder: ladder)
        let warm = autoWarmup && length != .minimal
            ? SetPlanner.warmups(for: item.exercise, workWeight: work.first?.weight ?? 0, first: firstInRegion, ladder: ladder)
            : []
        let sets = (warm + work).map { SetDraft(weight: $0.weight, reps: $0.reps, kind: $0.kind, kit: $0.kit) }
        var lastText = ""
        if !last.isEmpty {
            let reps = last.map { String($0.reps) }.joined(separator: "、")
            let w = last.map(\.weight).max() ?? 0
            lastText = item.exercise.loaded && w > 0
                ? "上次 \(Progression.format(w)) kg × \(reps)"
                : "上次 \(reps) \(item.exercise.unit.label)"
        }
        return ExerciseDraft(item: item, suggestion: s, lastText: lastText, sets: sets, chosen: chosen, scheme: scheme, ladder: ladder)
    }

    /// 破個人紀錄：有負重的動作，重量超過以前的最高重量（第一次做不算，和牌位的定義一樣）。
    private func checkRecord(_ d: ExerciseDraft, set: SetDraft) {
        let ex = d.item.exercise
        guard ex.loaded, set.weight > 0, let old = bests[ex.id], set.weight > old else { return }
        bests[ex.id] = set.weight
        prCount.insert(ex.id)
        let m = PRMoment(name: ex.name, weight: set.weight, old: old)
        prMoment = m
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + PRMoment.duration + 0.1) {
            if prMoment?.id == m.id { prMoment = nil }
        }
    }

    private func buildDrafts() {
        guard drafts.isEmpty else { return }
        var b: [String: Double] = [:]
        for s in sessions {
            for e in s.entries where e.weight > 0 {
                b[e.exerciseId] = max(b[e.exerciseId] ?? 0, e.weight)
            }
        }
        bests = b
        let plan = ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length, limitBarbell: lessBarbell)
        var seen = Set<String>()
        drafts = plan.map { item in
            let region = item.exercise.pattern.region
            let first = region.map { !seen.contains($0) } ?? false
            if let region { seen.insert(region) }
            return makeDraft(item, firstInRegion: first)
        }
    }

    private func addSet() {
        guard var lastDraft = drafts.last,
              let lastSet = lastDraft.sets.last(where: { $0.kind == .work }) ?? lastDraft.sets.last else { return }
        lastDraft.sets.append(SetDraft(weight: lastSet.weight, reps: lastSet.reps))
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
        let now = Date()
        let session = WorkoutSession(date: now, dayKey: day.id, length: length,
                                     durationSeconds: Int(now.timeIntervalSince(startedAt)))
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
                streakAfter: GoalEngine.streak(dates: dates + [now]))
        }
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
                    Label(draft.scheme.explain, systemImage: "chart.bar.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accentSoft)
                }
                Text(draft.suggestion.note)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(draft.suggestion.note.contains("加重") ? Theme.hotText : Theme.accentSoft)
                Text(ex.tip)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 8) {
                ForEach($draft.sets) { $set in
                    let tag = label(for: set)
                    if set.id == activeSetId {
                        ActiveSetEditor(set: $set, tag: tag, exercise: ex, ladder: draft.ladder) {
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
        var base = "目標 \(draft.item.sets) 組 × \(draft.item.low)–\(draft.item.high) \(ex.unit.label)"
        if draft.scheme != .straight { base += " · " + draft.scheme.short }
        return draft.lastText.isEmpty ? base : base + " · " + draft.lastText
    }

    /// 正式組顯示第幾組，熱身組、遞減組顯示「熱」「降」。
    private func label(for set: SetDraft) -> String {
        if let b = set.kind.badge { return b }
        guard let i = draft.sets.firstIndex(where: { $0.id == set.id }) else { return "" }
        return "\(draft.sets[...i].filter { $0.kind == .work }.count)"
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
    let onDone: () -> Void

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
            if set.kind == .work {
                rirPicker
            }
            Button(action: onDone) {
                Text("完成這一組")
            }
            .buttonStyle(HotButtonStyle(height: 52))
        }
        .padding(14)
        .background(Color(gearHex: "#1E2633"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hot, lineWidth: 2))
    }

    private var repStep: Int { exercise.unit == .seconds ? 5 : 1 }

    /// 做完還剩幾下力氣（選填）：用來自動調整下一組。
    private var rirPicker: some View {
        HStack(spacing: 6) {
            Text("還剩幾下力氣？")
                .font(.caption)
                .foregroundStyle(Theme.muted)
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
                }
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

/// 最後 3 秒每秒震一下，時間到震一下成功。
private struct SecondTicks: ViewModifier {
    let end: Date
    @State private var fired: Set<Int> = []

    func body(content: Content) -> some View {
        content.background {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let left = Int(ceil(end.timeIntervalSince(ctx.date)))
                Color.clear.onChange(of: left) { _, n in
                    guard n <= 3, n >= 0, !fired.contains(n) else { return }
                    fired.insert(n)
                    if n == 0 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    }
                }
            }
        }
        .onChange(of: end) { fired = [] }
    }
}
