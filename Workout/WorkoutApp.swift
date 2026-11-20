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
    @AppStorage(Keys.reminderWeekdays) private var weekdaysRaw = Keys.defaultWeekdays
    @AppStorage(Keys.reminderMinutes) private var reminderMinutes = Keys.defaultMinutes

    /// Changes whenever anything the widget or reminders depend on changes.
    private var syncKey: String {
        "\(onboarded)-\(sessions.count)-\(sessions.first?.date.timeIntervalSince1970 ?? 0)-\(weeklyGoal)-\(reminderOn)-\(weekdaysRaw)-\(reminderMinutes)"
    }

    var body: some View {
        Group {
            if onboarded {
                TabView {
                    TodayView()
                        .tabItem { Label("今天", systemImage: "figure.strengthtraining.traditional") }
                    ProgressScreen()
                        .tabItem { Label("進步", systemImage: "chart.line.uptrend.xyaxis") }
                    HistoryView()
                        .tabItem { Label("紀錄", systemImage: "list.bullet.rectangle") }
                    SettingsView()
                        .tabItem { Label("設定", systemImage: "gearshape") }
                }
            } else {
                OnboardingView()
            }
        }
        .onChange(of: syncKey) { sync() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { sync() }
        }
    }

    private func sync() {
        guard onboarded else { return }
        let dates = sessions.map(\.date)
        SharedStore.save(.init(sessionDates: dates, goal: weeklyGoal,
                               nextDay: ProgramBuilder.nextDay(after: sessions).name))
        WidgetCenter.shared.reloadAllTimelines()

        let weekdays = Keys.parseWeekdays(weekdaysRaw)
        let trained = SharedStore.trainedToday(dates)
        let missed = Stats.missedLastPlanned(sessions, weekdays: weekdays)
        let on = reminderOn
        let minutes = reminderMinutes
        Task {
            await Reminders.reschedule(enabled: on, weekdays: weekdays, minutes: minutes,
                                       trainedToday: trained, missedLast: missed)
        }
    }
}
