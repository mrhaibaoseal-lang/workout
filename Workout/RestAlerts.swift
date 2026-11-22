import Foundation
import ActivityKit
import UserNotifications

/// 休息結束提醒：切到背景時跳本地通知；鎖定畫面／動態島顯示倒數（Live Activity）。
/// App 在前景時不會跳通知（沒有設定通知 delegate，系統預設不顯示）。
enum RestAlerts {
    static let notificationId = "rest-end"

    static func requestAuthorization() {
        Task { _ = await Reminders.requestAuthorization() }
    }

    /// 開始或延長休息：排通知、更新 Live Activity。
    static func start(day: String, state: RestActivityAttributes.ContentState) {
        scheduleNotification(state)
        updateActivity(day: day, state: state)
    }

    /// 休息結束（跳過、時間到按下一組、離開訓練）。
    static func stop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationId])
        endActivities()
    }

    private static func scheduleNotification(_ s: RestActivityAttributes.ContentState) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId])
        let wait = s.end.timeIntervalSinceNow
        guard wait > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "休息結束，下一組！"
        content.body = s.next + " · " + s.detail + (s.change.map { "\n" + $0 } ?? "")
        content.sound = .default
        // 不用 .timeSensitive：那要 time-sensitive entitlement，FlareStore 憑證沒列（只有 App Groups），系統會默默降級。
        // 專注模式下要收到，請在「專注模式 › App」把練壯加進允許清單。
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
        center.add(UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger))
    }

    // MARK: Live Activity

    private static func updateActivity(day: String, state: RestActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: state.end.addingTimeInterval(120))
        let running = Activity<RestActivityAttributes>.activities
        if let a = running.first {
            Task { await a.update(content) }
            for extra in running.dropFirst() {
                Task { await extra.end(nil, dismissalPolicy: .immediate) }
            }
        } else {
            _ = try? Activity.request(attributes: RestActivityAttributes(day: day), content: content)
        }
    }

    private static func endActivities() {
        for a in Activity<RestActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
