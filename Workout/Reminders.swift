import Foundation
import UserNotifications

/// Schedules one-shot reminders for the next two weeks of planned training days.
/// Rescheduled whenever the app becomes active or a workout is saved, so a day
/// that's already trained gets no reminder.
enum Reminders {
    static let horizonDays = 14

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule(enabled: Bool, weekdays: Set<Int>, minutes: Int,
                           trainedToday: Bool, missedLast: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard enabled, !weekdays.isEmpty else { return }
        guard await requestAuthorization() else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var firstUpcoming = true

        for offset in 0..<horizonDays {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(cal.component(.weekday, from: day)) else { continue }
            if offset == 0 && trainedToday { continue }
            guard let fire = cal.date(byAdding: .minute, value: minutes, to: day), fire > .now else { continue }

            let content = UNMutableNotificationContent()
            if firstUpcoming && missedLast {
                content.title = "絕不連續兩次 🔥"
                content.body = "上次沒練到，今天別再漏了。換好衣服，做 1 組就算數。"
            } else {
                let lines = [
                    "換好衣服，做 1 組就好 💪",
                    "不用練滿，先開始再說。",
                    "累的話選精簡版，20 分鐘也算數。",
                    "未來的你會感謝現在的你。做 1 組就好。",
                ]
                content.title = "該練了"
                content.body = lines[offset % lines.count]
            }
            content.sound = .default
            firstUpcoming = false

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "train-\(offset)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
