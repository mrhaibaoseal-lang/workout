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
    @State private var confirmQuit = false
    @State private var showNothingDone = false
    @State private var askMore = false

    private var allDone: Bool {
        drafts.allSatisfy { $0.sets.allSatisfy(\.done) }
    }

    /// Next exercise from the full plan that isn't on screen yet (for the "1 set" ladder).
    private var nextExtra: PlannedExercise? {
        let shown = Set(drafts.map(\.id))
        return ProgramBuilder.plan(day: day, equipment: Equipment.parse(equipmentRaw), week: week, length: .full)
            .first { !shown.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach($drafts) { $draft in
                    Section {
                        Text(draft.suggestion.note)
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                        Text(draft.item.exercise.tip)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach($draft.sets) { $set in
                            let index = draft.sets.firstIndex { $0.id == set.id } ?? 0
                            SetRow(set: $set, index: index, exercise: draft.item.exercise) {
                                setCompleted(rest: draft.item.restSeconds)
                            }
                        }
                    } header: {
                        HStack {
                            Text(draft.item.exercise.name).font(.headline)
                            Spacer()
                            Text("\(draft.item.low)-\(draft.item.high) \(draft.item.exercise.unit.label)")
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { restBanner }
            .navigationTitle(day.name + (length.tag.map { "（\($0)）" } ?? ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("離開") { confirmQuit = true }
                }
                ToolbarItem(placement: .principal) {
                    Text(startedAt, style: .timer)
                        .monospacedDigit()
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { finish() }.bold()
                }
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
                Text("做完一組後按右邊的圓圈打勾。")
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
    }

    @ViewBuilder
    private var restBanner: some View {
        if let end = restEnd {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                if context.date < end {
                    HStack {
                        Image(systemName: "timer")
                        Text("休息")
                        Text(timerInterval: context.date...end, countsDown: true)
                            .monospacedDigit()
                            .bold()
                        Spacer()
                        Button("+30 秒") { restEnd = end.addingTimeInterval(30) }
                        Button("跳過") { restEnd = nil }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                } else {
                    Label("休息結束，下一組！", systemImage: "bolt.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                        .onTapGesture { restEnd = nil }
                }
            }
        }
    }

    private func setCompleted(rest: Int) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if length == .minimal && allDone {
            restEnd = nil
            askMore = true
        } else {
            restEnd = Date().addingTimeInterval(TimeInterval(rest))
        }
    }

    private func makeDraft(_ item: PlannedExercise) -> ExerciseDraft {
        let phase = ProgramBuilder.phase(week: week)
        let last = Progression.lastSets(for: item.exercise.id, in: sessions)
        let cap = Progression.maxWeight(for: item.exercise, dumbbell: maxDumbbell, barbell: maxBarbell)
        let s = Progression.suggest(item, last: last, phase: phase, increment: increment, maxWeight: cap)
        let sets = (0..<item.sets).map { _ in SetDraft(weight: s.weight, reps: s.reps) }
        return ExerciseDraft(item: item, suggestion: s, sets: sets)
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
        let doneCount = drafts.reduce(0) { $0 + $1.sets.filter(\.done).count }
        guard doneCount > 0 else {
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

struct SetRow: View {
    @Binding var set: SetDraft
    let index: Int
    let exercise: Exercise
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.headline)
                .frame(width: 22)
                .foregroundStyle(.secondary)

            if exercise.loaded {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 52)
                    .textFieldStyle(.roundedBorder)
                Text("kg").foregroundStyle(.secondary)
            }

            Stepper(value: $set.reps, in: 0...300, step: exercise.unit == .seconds ? 5 : 1) {
                Text("\(set.reps) \(exercise.unit.label)")
                    .monospacedDigit()
            }

            Button {
                set.done.toggle()
                if set.done { onDone() }
            } label: {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
