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
    let short: Bool
    let week: Int
    var onFinish: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.increment) private var increment = 2.5

    @State private var drafts: [ExerciseDraft] = []
    @State private var startedAt = Date()
    @State private var restEnd: Date?
    @State private var confirmQuit = false
    @State private var showNothingDone = false

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
                                restEnd = Date().addingTimeInterval(TimeInterval(draft.item.restSeconds))
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
            .navigationTitle(day.name + (short ? "（精簡）" : ""))
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
                Text("就算只做一個動作也值得按「完成」存起來。")
            }
            .alert("還沒有完成任何一組", isPresented: $showNothingDone) {
                Button("好") {}
            } message: {
                Text("做完一組後按右邊的圓圈打勾。")
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

    private func buildDrafts() {
        guard drafts.isEmpty else { return }
        let phase = ProgramBuilder.phase(week: week)
        let plan = ProgramBuilder.plan(day: day, equipment: Equipment.parse(equipmentRaw), week: week, short: short)
        drafts = plan.map { item in
            let last = Progression.lastSets(for: item.exercise.id, in: sessions)
            let s = Progression.suggest(item, last: last, phase: phase, increment: increment)
            let sets = (0..<item.sets).map { _ in SetDraft(weight: s.weight, reps: s.reps) }
            return ExerciseDraft(item: item, suggestion: s, sets: sets)
        }
    }

    private func finish() {
        let doneSets = drafts.flatMap { d in d.sets.filter(\.done).map { (d.item.exercise, $0) } }
        guard !doneSets.isEmpty else {
            showNothingDone = true
            return
        }
        let now = Date()
        let session = WorkoutSession(date: now, dayKey: day.id, isShort: short,
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
