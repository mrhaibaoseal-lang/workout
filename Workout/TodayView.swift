import SwiftUI
import SwiftData

struct ActiveWorkout: Identifiable {
    let day: DayTemplate
    let length: WorkoutLength
    var id: String { day.id + "-" + length.rawValue }
}

struct TodayView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    // Read so the view refreshes when any planner input changes.
    @AppStorage(ClassStore.key) private var classesRaw = ""
    @AppStorage(Keys.commuteSchool) private var commuteSchool = 15
    @AppStorage(Keys.commuteWork) private var commuteWork = 5
    @AppStorage(Keys.earliestHour) private var earliestHour = 12
    @AppStorage(Keys.preferredHour) private var preferredHour = 14
    @AppStorage(Keys.latestHour) private var latestHour = 25
    @AppStorage(EventStore.key) private var eventsRaw = ""
    @AppStorage(Keys.tiredHours) private var tiredHours = 6
    @Environment(\.scenePhase) private var scenePhase
    @State private var refresh = 0
    @State private var lengthChosen = false

    @State private var length: WorkoutLength = .full
    @State private var pickedDay: DayTemplate?
    @State private var active: ActiveWorkout?

    private var week: Int { Stats.week(since: Date(timeIntervalSince1970: startDate)) }
    private var phase: Phase { ProgramBuilder.phase(week: week) }
    private var day: DayTemplate { pickedDay ?? ProgramBuilder.nextDay(after: sessions) }
    private var equipment: Set<Equipment> { Equipment.parse(equipmentRaw) }
    private var plan: [PlannedExercise] {
        ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length)
    }
    private var trainedToday: Bool {
        sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }
    private var missed: Bool {
        Stats.missedLastPlanned(sessions, weekdays: [])
    }
    private var plans: [DayPlan] {
        _ = refresh
        _ = (classesRaw, commuteSchool, commuteWork, earliestHour, preferredHour, latestHour, weeklyGoal, eventsRaw, tiredHours)
        return Planner.makePlan(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if missed {
                        MissedCard {
                            active = ActiveWorkout(day: day, length: .minimal)
                        }
                    }
                    let plans = self.plans
                    if let today = plans.first {
                        TodayPlanCard(plan: today)
                    }
                    WeekStrip(plans: plans)
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
            .onAppear {
                guard !lengthChosen, let today = plans.first, !today.done else { return }
                length = today.length ?? .minimal
            }
            .onChange(of: length) { lengthChosen = true }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh += 1 }
            }
            .fullScreenCover(item: $active) { a in
                WorkoutView(day: a.day, length: a.length, week: week) {
                    pickedDay = nil
                }
            }
        }
    }

    private var lengthHint: String {
        switch length {
        case .full: "有空、有心情的日子，練好練滿"
        case .short: "很累、很忙的日子，只做最重要的 3 個動作"
        case .minimal: "超懶的日子：換好衣服，做 1 組就好。做完再決定要不要繼續"
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

            Picker("長度", selection: $length) {
                ForEach(WorkoutLength.allCases) { l in
                    Text(l.title).tag(l)
                }
            }
            .pickerStyle(.segmented)

            Text(lengthHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if length != .minimal {
                Text("約 \(ProgramBuilder.estimatedMinutes(plan)) 分鐘 · \(plan.count) 個動作")
                    .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(plan) { item in
                    HStack {
                        Text(item.exercise.name)
                        Spacer()
                        Text("\(item.sets) 組 × \(item.low)-\(item.high) \(item.exercise.unit.label)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }

            if plan.isEmpty {
                Text("目前器材找不到適合的動作，請到「設定」勾選你的器材。")
                    .foregroundStyle(.orange)
            }

            Button {
                active = ActiveWorkout(day: day, length: length)
            } label: {
                Text(length == .minimal ? "做 1 組就好" : "開始訓練")
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

struct MissedCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("上次排定的練習沒做到", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("沒關係，但規則是**絕不連續兩次**。以前放棄，都是從漏練一次、再漏一次開始的。今天就算只做 1 組也算數。")
                .font(.subheadline)
            Button(action: onStart) {
                Text("現在做 1 組")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
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

struct TodayPlanCard: View {
    let plan: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天的安排").font(.caption.bold()).foregroundStyle(.secondary)
            if plan.done {
                Label("今天練完了", systemImage: "checkmark.seal.fill")
                    .font(.title3.bold()).foregroundStyle(.green)
            } else if let length = plan.length, let start = plan.start {
                HStack(alignment: .firstTextBaseline) {
                    Text(length.title).font(.title2.bold())
                    Spacer()
                    Text("\(TimeFmt.hm(start)) 開始").font(.title3.bold()).monospacedDigit()
                }
            } else {
                Text("今天休息").font(.title2.bold())
                Text("想動的話，下面選「只做 1 組」也算數。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text(plan.reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct WeekStrip: View {
    let plans: [DayPlan]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(plans) { p in
                VStack(spacing: 4) {
                    Text(Calendar.current.isDateInToday(p.day) ? "今" : TimeFmt.weekday(p.day))
                        .font(.caption.bold())
                    Text("\(Calendar.current.component(.day, from: p.day))")
                        .font(.caption2).foregroundStyle(.secondary)
                    symbol(p)
                        .frame(height: 22)
                    Text(p.start.map(TimeFmt.hm) ?? " ")
                        .font(.system(size: 10)).monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Calendar.current.isDateInToday(p.day) ? Color.accentColor.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func symbol(_ p: DayPlan) -> some View {
        if p.done {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if p.length == .full {
            Text("60").font(.subheadline.bold()).foregroundStyle(.tint)
        } else if p.length == .short {
            Text("20").font(.subheadline.bold()).foregroundStyle(.orange)
        } else {
            Image(systemName: "moon.zzz").foregroundStyle(.secondary)
        }
    }
}
