import WidgetKit
import SwiftUI

struct WeekEntry: TimelineEntry {
    let date: Date
    let done: Int
    let goal: Int
    let streak: Int
    let nextDay: String
    let trainedToday: Bool
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: .now, done: 2, goal: 4, streak: 3, nextDay: "上半身 A", trainedToday: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        // Refresh just after midnight so "today" and the week count roll over.
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        let refresh = tomorrow.addingTimeInterval(60)
        completion(Timeline(entries: [entry(at: .now)], policy: .after(refresh)))
    }

    private func entry(at date: Date) -> WeekEntry {
        let s = SharedStore.load()
        return WeekEntry(date: date,
                         done: SharedStore.countThisWeek(s.sessionDates, now: date),
                         goal: s.goal,
                         streak: SharedStore.streak(s, now: date),
                         nextDay: s.nextDay,
                         trainedToday: SharedStore.trainedToday(s.sessionDates, now: date))
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeekEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(min(entry.done, entry.goal)), in: 0...Double(max(entry.goal, 1))) {
                Image(systemName: "dumbbell.fill")
            } currentValueLabel: {
                Text("\(entry.done)/\(entry.goal)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("本週 \(entry.done)/\(entry.goal) 次").font(.headline)
                Text(entry.trainedToday ? "今天練完了 ✓" : "下次：\(entry.nextDay)")
                if entry.streak > 0 { Text("🔥 連續 \(entry.streak) 週") }
            }
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本週").font(.caption.bold()).foregroundStyle(.secondary)
                Spacer()
                if entry.streak > 0 {
                    Text("🔥\(entry.streak)").font(.caption.bold())
                }
            }
            Text("\(entry.done)/\(entry.goal)")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 4) {
                ForEach(0..<max(entry.goal, entry.done), id: \.self) { i in
                    Capsule()
                        .fill(i < entry.done ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 6)
                }
            }
            Spacer(minLength: 0)
            Text(entry.trainedToday ? "今天練完了 ✓" : "下次：\(entry.nextDay)")
                .font(.caption)
                .foregroundStyle(entry.trainedToday ? .green : .primary)
                .lineLimit(1)
        }
    }
}

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekWidget", provider: WeekProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("本週進度")
        .description("本週練了幾次、連續幾週、下次練什麼。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        WeekWidget()
        RestLiveActivity()
    }
}
