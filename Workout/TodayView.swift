import SwiftUI
import SwiftData

struct ActiveWorkout: Identifiable {
    let day: DayTemplate
    let short: Bool
    var id: String { day.id + (short ? "-short" : "") }
}

struct TodayView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4

    @State private var short = false
    @State private var pickedDay: DayTemplate?
    @State private var active: ActiveWorkout?

    private var week: Int { Stats.week(since: Date(timeIntervalSince1970: startDate)) }
    private var phase: Phase { ProgramBuilder.phase(week: week) }
    private var day: DayTemplate { pickedDay ?? ProgramBuilder.nextDay(after: sessions) }
    private var plan: [PlannedExercise] {
        ProgramBuilder.plan(day: day, equipment: Equipment.parse(equipmentRaw), week: week, short: short)
    }
    private var trainedToday: Bool {
        sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WeekCard(week: week, phase: phase,
                             done: Stats.sessionsThisWeek(sessions), goal: weeklyGoal,
                             streak: Stats.weekStreak(sessions))
                    if trainedToday {
                        Label("今天已經練完了，好好休息！", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    }
                    workoutCard
                }
                .padding()
            }
            .navigationTitle("今天練什麼")
            .fullScreenCover(item: $active) { a in
                WorkoutView(day: a.day, short: a.short, week: week) {
                    pickedDay = nil
                }
            }
        }
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.name).font(.title2.bold())
                    Text(day.focus).foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(ProgramBuilder.days) { d in
                        Button(d.name) { pickedDay = d }
                    }
                } label: {
                    Label("換一天", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
            }

            Picker("長度", selection: $short) {
                Text("完整版").tag(false)
                Text("忙碌精簡版").tag(true)
            }
            .pickerStyle(.segmented)

            Text("約 \(ProgramBuilder.estimatedMinutes(plan)) 分鐘 · \(plan.count) 個動作")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan) { item in
                    HStack {
                        Text(item.exercise.name)
                        Spacer()
                        Text("\(item.sets) 組 × \(item.low)-\(item.high) \(item.exercise.unit.label)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.body)
                }
            }

            if plan.isEmpty {
                Text("目前器材找不到適合的動作，請到「設定」勾選你的器材。")
                    .foregroundStyle(.orange)
            }

            Button {
                active = ActiveWorkout(day: day, short: short)
            } label: {
                Text("開始訓練")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(plan.isEmpty)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WeekCard: View {
    let week: Int
    let phase: Phase
    let done: Int
    let goal: Int
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("第 \(week) 週").font(.title3.bold())
                Text(phase.title)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.tint.opacity(0.15), in: Capsule())
                Spacer()
                if streak > 0 {
                    Label("連續 \(streak) 週", systemImage: "flame.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }
            Text(phase.note)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<max(goal, done), id: \.self) { i in
                    Capsule()
                        .fill(i < done ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 10)
                }
            }
            Text(done >= goal ? "本週目標達成 🎉" : "本週 \(done) / \(goal) 次")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}
