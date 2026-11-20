import Foundation
import EventKit

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case date, shoot, meal, drink, trip, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: "接女友 / 約會"
        case .shoot: "拍片"
        case .meal: "吃飯"
        case .drink: "喝酒"
        case .trip: "出去玩"
        case .other: "其他"
        }
    }

    var icon: String {
        switch self {
        case .date: "heart.fill"
        case .shoot: "video.fill"
        case .meal: "fork.knife"
        case .drink: "wineglass.fill"
        case .trip: "car.fill"
        case .other: "calendar"
        }
    }

    /// How the planner treats it, shown under the picker.
    var effect: String {
        switch self {
        case .shoot: "拍片很耗體力，會跟打工一起算進當天的勞累時數。"
        case .drink: "喝酒後不適合練，活動開始後當天都不排。"
        default: "活動前後各留 15 分鐘移動時間。"
        }
    }
}

struct LifeEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var category: EventCategory
    var start: Date
    var end: Date
    var allDay = false
    /// Events read from the iPhone Calendar are shown but not editable here.
    var fromPhone = false

    var displayTitle: String { title.isEmpty ? category.title : title }

    var timeText: String {
        allDay ? "整天" : "\(TimeFmt.hm(start))–\(TimeFmt.hm(end))"
    }

    enum CodingKeys: String, CodingKey { case id, title, category, start, end, allDay }
}

enum EventStore {
    static let key = "lifeEvents"

    static func decode(_ raw: String) -> [LifeEvent] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([LifeEvent].self, from: data) else { return [] }
        return list
    }

    static func encode(_ list: [LifeEvent]) -> String {
        // Drop events that ended more than 60 days ago to keep storage small.
        let cutoff = Date().addingTimeInterval(-60 * 86400)
        let kept = list.filter { $0.end > cutoff }.sorted { $0.start < $1.start }
        guard let data = try? JSONEncoder().encode(kept) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func load() -> [LifeEvent] {
        decode(UserDefaults.standard.string(forKey: key) ?? "")
    }

    /// In-app events plus, if enabled, events from the iPhone Calendar.
    static func all(from: Date, to: Date) -> [LifeEvent] {
        load().filter { $0.end > from && $0.start < to } + PhoneCalendar.events(from: from, to: to)
    }
}

/// Optional read-only access to the iPhone Calendar.
enum PhoneCalendar {
    static let store = EKEventStore()

    static var enabled: Bool { UserDefaults.standard.bool(forKey: Keys.readPhoneCalendar) }

    static var authorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    static func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    static func events(from: Date, to: Date) -> [LifeEvent] {
        guard enabled, authorized else { return [] }
        // Skip ShiftPay's own calendar (shifts come from the App Group), birthdays and subscribed holiday calendars.
        let calendars = store.calendars(for: .event).filter {
            $0.title != "💰 打工班表" && $0.type != .birthday && $0.type != .subscription
        }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: calendars)
        return store.events(matching: predicate).map { ev in
            LifeEvent(title: ev.title ?? "行事曆活動", category: .other,
                      start: ev.startDate, end: ev.endDate, allDay: ev.isAllDay, fromPhone: true)
        }
    }
}
