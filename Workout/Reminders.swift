import Foundation
import UserNotifications

/// Schedules one-shot reminders at the times the planner picked.
/// Rescheduled whenever the app becomes active or a workout is saved, so a
/// trained day gets no reminder and changed shifts move the reminder.
enum Reminders {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(enabled: Bool, plans: [DayPlan], leadMinutes: Int, missedLast: Bool) async {
        let center = UNUserNotificationCenter.current()
        // 只清掉訓練提醒，休息結束的通知（RestAlerts）要留著
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("train-") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard enabled else { return }
        guard await requestAuthorization() else { return }

        let cal = Calendar.current
        var first = true
        for (i, p) in plans.enumerated() {
            guard !p.done, let length = p.length, let start = p.start else { continue }
            let fire = start.addingTimeInterval(TimeInterval(-leadMinutes * 60))
            guard fire > .now else { continue }

            let content = UNMutableNotificationContent()
            if first && missedLast {
                content.title = "絕不連續兩次 🔥"
                content.body = "上次沒練到，今天 \(TimeFmt.hm(start)) 別再漏了。真的很累就做 1 組，也算數。"
            } else {
                content.title = "\(TimeFmt.hm(start)) 練\(length == .full ? "完整 60 分" : "精簡 20 分")"
                let lines = [
                    "換好衣服，先做 1 組再說 💪",
                    "累的話改精簡版，20 分鐘也算數。",
                    "不用練滿，開始就贏一半。",
                    "未來的你會感謝現在的你。",
                ]
                content.body = lines[i % lines.count]
            }
            content.sound = .default
            first = false

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "train-\(i)", content: content, trigger: trigger))
        }
    }
}
