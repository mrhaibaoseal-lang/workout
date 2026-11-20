import SwiftUI
import SwiftData
import WidgetKit

@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [WorkoutSession.self, SetEntry.self])
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
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

    /// Changes whenever anything the widget or reminders depend on changes.
    private var syncKey: String {
        "\(onboarded)-\(sessions.count)-\(sessions.first?.date.timeIntervalSince1970 ?? 0)-\(weeklyGoal)-\(reminderOn)-\(reminderLead)-\(classesRaw.hashValue)-\(commuteSchool)-\(commuteWork)-\(earliestHour)-\(preferredHour)-\(latestHour)-\(eventsRaw.hashValue)-\(tiredHours)"
    }

    var body: some View {
        Group {
            if onboarded {
                TabView {
                    TodayView()
                        .tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
                    CareerView()
                        .tabItem { Label("選手", systemImage: "figure.boxing") }
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
        .onAppear { sync() }
        .onChange(of: syncKey) { sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync() }
        }
    }

    private func sync() {
        guard onboarded else { return }
        let plans = Planner.makePlan(sessions: sessions)
        // Remember what was planned for each day, so a missed day can be judged later.
        let dayStart = Calendar.current.startOfDay(for: .now)
        CareerStore.record(plans: Planner.makePlan(sessions: sessions, now: dayStart))
        let next = plans.first { !$0.done && $0.length != nil }
        let nextText: String
        if let n = next, let start = n.start, let length = n.length {
            let day = Calendar.current.isDateInToday(n.day) ? "今天" : "週" + TimeFmt.weekday(n.day)
            nextText = "\(day) \(TimeFmt.hm(start)) \(length == .full ? "60 分" : "20 分")"
        } else {
            nextText = ProgramBuilder.nextDay(after: sessions).name
        }
        SharedStore.save(.init(sessionDates: sessions.map(\.date), goal: weeklyGoal, nextDay: nextText))
        WidgetCenter.shared.reloadAllTimelines()

        let missed = Stats.missedLastPlanned(sessions, weekdays: [])
        let on = reminderOn
        let lead = reminderLead
        Task {
            await Reminders.reschedule(enabled: on, plans: plans, leadMinutes: lead, missedLast: missed)
        }
    }
}
