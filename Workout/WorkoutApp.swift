import SwiftUI
import SwiftData
import WidgetKit

@main
struct WorkoutApp: App {
    init() {
        SettingsBackup.start()
        ProgramBuilder.migrateV023()
        GoalStore.ensureSince()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutSession.self, SetEntry.self, BodyLog.self, IntervalLog.self])
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @StateObject private var inventory = InventoryStore()
    @ObservedObject private var commands = AppCommands.shared
    @State private var tab = 0
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
                TabView(selection: $tab) {
                    TodayView()
                        .tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
                        .tag(0)
                    CharacterScreen()
                        .tabItem { Label("角色", systemImage: "figure.strengthtraining.functional") }
                        .tag(1)
                        .badge(inventory.boxesAvailable(sessionCount: GoalEngine.boxTotal(sessions: sessions, goal: weeklyGoal)))
                    ProgressScreen()
                        .tabItem { Label("進步", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(2)
                    AgendaView()
                        .tabItem { Label("行程", systemImage: "calendar") }
                        .tag(3)
                    SettingsView()
                        .tabItem { Label("設定", systemImage: "gearshape") }
                        .tag(4)
                }
                // 切換分頁的選擇觸覺。系統 tab bar 的圖示不吃 symbolEffect（UIKit 畫的），所以只配觸覺
                .sensoryFeedback(.selection, trigger: tab)
            } else {
                OnboardingView()
            }
        }
        .environmentObject(inventory)
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .onChange(of: syncKey) { sync() }
        // 捷徑「開始今天的訓練」：先切到今天頁，今天頁會打開訓練畫面
        .onReceive(commands.$pendingStart) { if $0 { tab = 0 } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync() }
            if phase != .active {
                SettingsBackup.flush()
                CloudSync.shared.scheduleUpload()
            }
        }
        .onAppear { CloudSync.shared.context = modelContext }
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
        Reminders.schedule(enabled: reminderOn, plans: plans, leadMinutes: reminderLead, missedLast: missed)
    }
}
