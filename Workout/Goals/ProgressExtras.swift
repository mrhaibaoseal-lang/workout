import SwiftUI

// MARK: - 影子對手：最近 28 天 vs 前 28 天的自己

struct ShadowRivalCard: View {
    let sessions: [WorkoutSession]

    private struct Row: Identifiable {
        let title: String
        let me: Double
        let shadow: Double
        let unit: String
        var id: String { title }
    }

    private struct Window {
        var sessions = 0
        var sets = 0
        var volume = 0.0
    }

    private func window(from: Date, to: Date) -> Window {
        var w = Window()
        for s in sessions where s.date >= from && s.date < to {
            w.sessions += 1
            for e in s.entries where e.isWork {
                w.sets += 1
                w.volume += e.weight * Double(e.reps)
            }
        }
        return w
    }

    var body: some View {
        let now = Date()
        let mid = now.addingTimeInterval(-28 * 86400)
        let me = window(from: mid, to: now.addingTimeInterval(1))
        let shadow = window(from: now.addingTimeInterval(-56 * 86400), to: mid)
        let rows = [
            Row(title: "訓練次數", me: Double(me.sessions), shadow: Double(shadow.sessions), unit: "次"),
            Row(title: "正式組", me: Double(me.sets), shadow: Double(shadow.sets), unit: "組"),
            Row(title: "總重量", me: me.volume, shadow: shadow.volume, unit: "kg"),
        ]
        let wins = rows.filter { $0.me > $0.shadow }.count
        let losses = rows.filter { $0.me < $0.shadow }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("影子對手").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text("最近 28 天 vs 前 28 天的自己").font(.caption).foregroundStyle(Theme.muted)
                Spacer()
                Text(wins > losses ? "領先" : wins < losses ? "落後" : "平手")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(wins > losses ? Theme.green : wins < losses ? Theme.hotText : Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.raised, in: Capsule())
            }
            ForEach(rows) { r in
                bar(r.title, me: r.me, shadow: r.shadow, unit: r.unit)
            }
        }
        .themeCard()
    }

    private func fmt(_ x: Double, _ unit: String) -> String {
        if unit == "kg" && x >= 1000 { return String(format: "%.1f t", x / 1000) }
        return "\(Int(x.rounded())) \(unit)"
    }

    private func bar(_ title: String, me: Double, shadow: Double, unit: String) -> some View {
        let top = max(me, shadow, 1)
        let ahead = me >= shadow
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                Text(fmt(me, unit)).font(Theme.number(12, .bold)).foregroundStyle(ahead ? Theme.green : Theme.hotText)
                Text("vs \(fmt(shadow, unit))").font(Theme.number(12, .medium)).foregroundStyle(Theme.muted)
            }
            GeometryReader { g in
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(ahead ? Theme.green : Theme.hot).frame(width: max(4, g.size.width * me / top), height: 7)
                    Capsule().fill(Theme.muted.opacity(0.35)).frame(width: max(4, g.size.width * shadow / top), height: 7)
                }
            }
            .frame(height: 17)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title)：這 28 天 \(fmt(me, unit))，前 28 天 \(fmt(shadow, unit))")
    }
}

// MARK: - 總重量里程碑

struct TonnageMilestone {
    let emoji: String
    let name: String
    let kg: Double

    static let all: [TonnageMilestone] = [
        .init(emoji: "🛵", name: "機車", kg: 150),
        .init(emoji: "🎹", name: "鋼琴", kg: 400),
        .init(emoji: "🐄", name: "乳牛", kg: 700),
        .init(emoji: "🚗", name: "小客車", kg: 1_500),
        .init(emoji: "🦛", name: "河馬", kg: 3_000),
        .init(emoji: "🐘", name: "大象", kg: 6_000),
        .init(emoji: "🚌", name: "公車", kg: 12_000),
        .init(emoji: "🦈", name: "鯨鯊", kg: 20_000),
        .init(emoji: "✈️", name: "波音 737", kg: 41_000),
        .init(emoji: "🐋", name: "藍鯨", kg: 150_000),
        .init(emoji: "🚀", name: "火箭", kg: 550_000),
        .init(emoji: "🗼", name: "艾菲爾鐵塔", kg: 7_300_000),
    ]
}

struct TonnageCard: View {
    let sessions: [WorkoutSession]

    var body: some View {
        let total = sessions.reduce(0.0) { sum, s in
            sum + s.entries.filter(\.isWork).reduce(0.0) { $0 + $1.weight * Double($1.reps) }
        }
        let list = TonnageMilestone.all
        let reached = list.last { total >= $0.kg }
        let next = list.first { total < $0.kg }
        let lower = reached?.kg ?? 0
        let p = next.map { min(1, (total - lower) / ($0.kg - lower)) } ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("累積舉起").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                Text(total >= 1000 ? String(format: "%.1f 噸", total / 1000) : "\(Int(total)) kg")
                    .font(Theme.number(22)).foregroundStyle(Theme.fg)
            }
            HStack(spacing: 14) {
                Text(reached?.emoji ?? "🪶").font(.system(size: 44))
                    .frame(width: 60, height: 60)
                    .background(Theme.goldBg, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text(reached.map { "已經舉起一台\($0.name)的重量" } ?? "還沒到第一個里程碑")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.gold)
                    if let n = next {
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Theme.line)
                                Capsule().fill(Theme.gold).frame(width: g.size.width * p)
                            }
                        }
                        .frame(height: 6)
                        Text("下一個：\(n.emoji) \(n.name)（還差 \(format(n.kg - total))）")
                            .font(.caption).foregroundStyle(Theme.muted)
                    } else {
                        Text("全部達成！").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(list, id: \.name) { m in
                    Text(m.emoji)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity)
                        .opacity(total >= m.kg ? 1 : 0.25)
                        .grayscale(total >= m.kg ? 0 : 1)
                }
            }
            Text("正式組的重量 × 次數加總（徒手動作不算）").font(.caption2).foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    private func format(_ kg: Double) -> String {
        kg >= 1000 ? String(format: "%.1f 噸", kg / 1000) : "\(Int(kg.rounded())) kg"
    }
}
