import SwiftUI
import SwiftData
import WidgetKit

@main
struct WorkoutApp: App {
    init() {
        SettingsBackup.start()
        GoalStore.ensureSince()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutSession.self, SetEntry.self, BodyLog.self])
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @StateObject private var inventory = InventoryStore()
    @AppStorage(Keys.onboarded) private var onboarded = false
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.reminderOn) private var reminderOn = true
    @AppStorage(Keys.reminderLead) private var reminderLead = 0
    @AppStorage(ClassStore.key) private var classesRaw = ""
    @AppStorage(Keys.commuteSchool) private var commuteSchool = 15
    @AppStorage(Keys.commuteWork) private var commuteWork = 5
    @AppStorage(Keys.earliestHour) private var earliestHour = 12
    @AppStorage(Keys.preferredHour) private var preferredHour = 14
    @AppStorage(Keys.latestHour) private var latestHour = 25
    @AppStorage(EventStore.key) private var eventsRaw = ""
    @AppStorage(Keys.tiredHours) private var tiredHours = 6
    @AppStorage(Keys.leaves) private var leavesRaw = ""

    /// Changes whenever anything the widget or reminders depend on changes.
    private var syncKey: String {
        "\(onboarded)-\(sessions.count)-\(sessions.first?.date.timeIntervalSince1970 ?? 0)-\(weeklyGoal)-\(reminderOn)-\(reminderLead)-\(classesRaw.hashValue)-\(commuteSchool)-\(commuteWork)-\(earliestHour)-\(preferredHour)-\(latestHour)-\(eventsRaw.hashValue)-\(tiredHours)-\(leavesRaw.hashValue)"
    }

    var body: some View {
        Group {
            if onboarded {
                TabView {
                    TodayView()
                        .tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
                    CharacterScreen()
                        .tabItem { Label("角色", systemImage: "figure.strengthtraining.functional") }
                        .badge(inventory.boxesAvailable(sessionCount: GoalEngine.boxTotal(sessions: sessions, goal: weeklyGoal)))
                    ProgressScreen()
                        .tabItem { Label("進步", systemImage: "chart.line.uptrend.xyaxis") }
                    AgendaView()
                        .tabItem { Label("行程", systemImage: "calendar") }
                    SettingsView()
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .environmentObject(inventory)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onChange(of: syncKey) { sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync() }
        }
    }

    private func sync() {
        guard onboarded else { return }
        let plans = Planner.makePlan(sessions: sessions)
        // 排程紀錄用今天 0 點算，晚上打開也不會因為時間過了就變成「今天沒排」
        GoalStore.record(Planner.makePlan(sessions: sessions, now: Calendar.current.startOfDay(for: .now)))
        let next = plans.first { !$0.done && $0.length != nil }
        let nextText: String
        if let n = next, let start = n.start, let length = n.length {
            let day = Calendar.current.isDateInToday(n.day) ? "今天" : "週" + TimeFmt.weekday(n.day)
            nextText = "\(day) \(TimeFmt.hm(start)) \(length == .full ? "60 分" : "20 分")"
        } else {
            nextText = ProgramBuilder.nextDay(after: sessions).name
        }
        let dates = sessions.map(\.date)
        let current = GoalEngine.current(dates: dates, goal: weeklyGoal, ctx: .load())
        SharedStore.save(.init(sessionDates: dates, goal: current.goal, nextDay: nextText,
                               streak: current.streak, streakWeek: current.week))
        WidgetCenter.shared.reloadAllTimelines()

        let missed = GoalEngine.missedLastPlanned(dates: dates)
        let on = reminderOn
        let lead = reminderLead
        Task {
            await Reminders.reschedule(enabled: on, plans: plans, leadMinutes: lead, missedLast: missed)
        }
    }
}
