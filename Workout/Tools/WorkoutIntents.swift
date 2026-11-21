import AppIntents
import SwiftUI

/// 捷徑／Siri 和畫面之間的橋：Intent 在這裡留話，畫面看到就照做。
@MainActor
final class AppCommands: ObservableObject {
    static let shared = AppCommands()

    /// 「開始今天的訓練」：今天頁看到就打開訓練畫面
    @Published var pendingStart = false
    /// 訓練畫面開著時才有：完成目前這一組，回傳要給 Siri 說的話
    var completeSet: (() -> String)?
}

struct StartTodayWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "開始今天的訓練"
    static var description = IntentDescription("打開練壯，直接進入今天的課表。")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCommands.shared.pendingStart = true
        return .result()
    }
}

struct CompleteSetIntent: AppIntent {
    static var title: LocalizedStringResource = "完成一組"
    static var description = IntentDescription("用目前這組預定的重量和次數記錄，並開始休息計時。要先在練壯開始訓練。")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let handler = AppCommands.shared.completeSet else {
            return .result(dialog: "現在沒有進行中的訓練")
        }
        let text = handler()
        return .result(dialog: "\(text)")
    }
}

struct WorkoutShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTodayWorkoutIntent(),
                    phrases: ["\(.applicationName)開始今天的訓練", "用\(.applicationName)開始訓練"],
                    shortTitle: "開始今天的訓練",
                    systemImageName: "figure.strengthtraining.traditional")
        AppShortcut(intent: CompleteSetIntent(),
                    phrases: ["\(.applicationName)完成一組", "在\(.applicationName)完成這一組"],
                    shortTitle: "完成一組",
                    systemImageName: "checkmark.circle.fill")
    }
}
