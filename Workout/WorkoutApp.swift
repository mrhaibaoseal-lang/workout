import SwiftUI
import SwiftData

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
    @AppStorage(Keys.onboarded) private var onboarded = false

    var body: some View {
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
}
