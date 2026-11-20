import SwiftUI
import SwiftData

struct SetDraft: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var done = false
}

struct ExerciseDraft: Identifiable {
    let item: PlannedExercise
    let suggestion: Suggestion
    /// 「上次 10 kg × 12、11、10」, empty the first time.
    let lastText: String
    var sets: [SetDraft]
    var id: String { item.id }
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
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.maxDumbbell) private var maxDumbbell = 20.0
    @AppStorage(Keys.maxBarbell) private var maxBarbell = 40.0

    @State private var drafts: [ExerciseDraft] = []
    @State private var startedAt = Date()
    @State private var restEnd: Date?
    @State private var restTotal: Double = 90
    @State private var focused: UUID?
    @State private var confirmQuit = false
    @State private var showNothingDone = false
    @State private var askMore = false

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

    private var doneSets: Int { drafts.reduce(0) { $0 + $1.sets.filter(\.done).count } }
    private var totalSets: Int { drafts.reduce(0) { $0 + $1.sets.count } }

    /// Next exercise from the full plan that isn't on screen yet (for the "1 set" ladder).
    private var nextExtra: PlannedExercise? {
        let shown = Set(drafts.map(\.id))
        return ProgramBuilder.plan(day: day, equipment: Equipment.parse(equipmentRaw), week: week, length: .full)
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
                            ForEach(Array(drafts.indices), id: \.self) { i in
                                ExerciseCard(draft: $drafts[i], number: i + 1, total: drafts.count,
                                             activeSetId: activeSetId, increment: increment,
                                             onFocus: { focused = $0 },
                                             onComplete: { id in complete(set: id, in: i) })
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
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = end.timeIntervalSince(ctx.date)
                if left > 0 {
                    HStack(spacing: 14) {
                        ZStack {
                            Ring(progress: left / max(restTotal, 1), color: Theme.green, lineWidth: 7)
                            Text(timerInterval: ctx.date...end, countsDown: true)
                                .font(Theme.number(15))
                                .foregroundStyle(Theme.fg)
                        }
                        .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("休息中").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                            Text("共 \(Int(restTotal)) 秒").font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        Button("+30 秒") {
                            restEnd = end.addingTimeInterval(30)
                            restTotal += 30
                        }
                        .buttonStyle(GhostButtonStyle())
                        Button("跳過") { restEnd = nil }
                            .buttonStyle(GhostButtonStyle())
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                } else {
                    Button { restEnd = nil } label: {
                        Label("休息結束，下一組！", systemImage: "bolt.fill")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(Theme.bg)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Theme.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
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
        if length == .minimal && allDone {
            restEnd = nil
            askMore = true
        } else if !allDone {
            let rest = drafts[exerciseIndex].item.restSeconds
            restTotal = Double(rest)
            restEnd = Date().addingTimeInterval(TimeInterval(rest))
        } else {
            restEnd = nil
        }
    }

    private func makeDraft(_ item: PlannedExercise) -> ExerciseDraft {
        let phase = ProgramBuilder.phase(week: week)
        let last = Progression.lastSets(for: item.exercise.id, in: sessions)
        let cap = Progression.maxWeight(for: item.exercise, dumbbell: maxDumbbell, barbell: maxBarbell)
        let s = Progression.suggest(item, last: last, phase: phase, increment: increment, maxWeight: cap)
        let sets = (0..<item.sets).map { _ in SetDraft(weight: s.weight, reps: s.reps) }
        var lastText = ""
        if !last.isEmpty {
            let reps = last.map { String($0.reps) }.joined(separator: "、")
            let w = last.map(\.weight).max() ?? 0
            lastText = item.exercise.loaded && w > 0
                ? "上次 \(Progression.format(w)) kg × \(reps)"
                : "上次 \(reps) \(item.exercise.unit.label)"
        }
        return ExerciseDraft(item: item, suggestion: s, lastText: lastText, sets: sets)
    }

    private func buildDrafts() {
        guard drafts.isEmpty else { return }
        let plan = ProgramBuilder.plan(day: day, equipment: Equipment.parse(equipmentRaw), week: week, length: length)
        drafts = plan.map(makeDraft)
    }

    private func addSet() {
        guard var lastDraft = drafts.last, let lastSet = lastDraft.sets.last else { return }
        lastDraft.sets.append(SetDraft(weight: lastSet.weight, reps: lastSet.reps))
        drafts[drafts.count - 1] = lastDraft
    }

    private func addNextExercise() {
        guard let item = nextExtra else { return }
        drafts.append(makeDraft(item))
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
                                     reps: set.reps, date: now)
                entry.session = session
                context.insert(entry)
            }
        }
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
        dismiss()
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
    let onFocus: (UUID) -> Void
    let onComplete: (UUID) -> Void

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
                }
            }

            if hasActive {
                Text(draft.suggestion.note)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(draft.suggestion.note.contains("加重") ? Theme.hotText : Theme.accentSoft)
                Text(ex.tip)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }

            VStack(spacing: 8) {
                ForEach($draft.sets) { $set in
                    let index = (draft.sets.firstIndex { $0.id == set.id } ?? 0) + 1
                    if set.id == activeSetId {
                        ActiveSetEditor(set: $set, index: index, exercise: ex, increment: increment) {
                            onComplete(set.id)
                        }
                    } else {
                        CompactSetRow(set: set, index: index, exercise: ex) {
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
        let base = "目標 \(draft.item.sets) 組 × \(draft.item.low)–\(draft.item.high) \(ex.unit.label)"
        return draft.lastText.isEmpty ? base : base + " · " + draft.lastText
    }
}

struct CompactSetRow: View {
    let set: SetDraft
    let index: Int
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.muted)
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
    let index: Int
    let exercise: Exercise
    let increment: Double
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("第 \(index) 組")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.fg)
            HStack(spacing: 10) {
                if exercise.loaded {
                    stepperBox(
                        minus: { set.weight = max(0, set.weight - increment) },
                        plus: { set.weight += increment },
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
