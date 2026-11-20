import SwiftUI

extension Font {
    static func rounded(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

enum CareerColors {
    static let fight = Color(hex: 0xD92D26)
    static let gold = Color(hex: 0xD4A82A)

    static func condition(_ value: Int) -> Color {
        switch value {
        case 80...: .green
        case 50..<80: .yellow
        case 25..<50: .orange
        default: .red
        }
    }
}

/// Placeholder fighter until the art style is decided.
struct FighterAvatar: View {
    let owned: Set<String>
    var size: CGFloat = 44

    var body: some View {
        let gloves = Cosmetics.equipped(.gloves, owned: owned)
        let robe = Cosmetics.equipped(.robe, owned: owned)
        ZStack {
            Circle().fill(Color(white: 0.1))
            Circle().strokeBorder(robe.color, lineWidth: max(2, size / 18))
            Image(systemName: "figure.boxing")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(gloves.color)
        }
        .frame(width: size, height: size)
    }
}

struct XPBar: View {
    let xp: Int

    var body: some View {
        let l = Leveling.level(xp: xp)
        VStack(alignment: .leading, spacing: 4) {
            ProgressView(value: Double(l.into), total: Double(l.need))
                .tint(CareerColors.fight)
            HStack {
                Text("再 \(l.need - l.into) XP 升 Lv.\(l.level + 1)")
                Spacer()
                Text("\(l.into) / \(l.need) XP")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

struct Chip: View {
    let text: String
    let symbol: String
    var color: Color = .secondary

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// Small card on the Today screen.
struct CareerSummaryCard: View {
    let state: CareerState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FighterAvatar(owned: state.owned)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv.\(state.level)").font(.rounded(.title3))
                    Text(state.rankText).font(.caption.bold()).foregroundStyle(CareerColors.gold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("戰績").font(.caption).foregroundStyle(.secondary)
                    Text(state.record).font(.rounded(.title3)).monospacedDigit()
                }
            }
            XPBar(xp: state.xp)
            HStack(spacing: 6) {
                Chip(text: "狀態 \(state.conditionTitle)", symbol: "heart.fill",
                     color: CareerColors.condition(state.condition))
                if state.cards > 0 {
                    Chip(text: "保護卡 \(state.cards)", symbol: "shield.fill", color: .blue)
                }
                Spacer()
                Chip(text: "\(state.purse)", symbol: "dollarsign.circle.fill", color: CareerColors.gold)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct QuestCard: View {
    let quests: [QuestStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本週任務").font(.headline)
                Spacer()
                Text("\(quests.filter(\.done).count) / \(quests.count)")
                    .font(.subheadline.bold()).monospacedDigit().foregroundStyle(.secondary)
            }
            ForEach(quests) { q in
                HStack(spacing: 10) {
                    Image(systemName: q.done ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(q.done ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(q.title).font(.subheadline)
                            Spacer()
                            Text("\(min(q.progress, q.target))/\(q.target)")
                                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(min(q.progress, q.target)), total: Double(max(1, q.target)))
                            .tint(q.done ? Color.green : Color.orange)
                    }
                    Text("+\(q.kind.xp)")
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(CareerColors.gold)
                        .frame(width: 38, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct LeaveSheet: View {
    var preset: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var choice = 0
    @State private var reason: LeaveReason = .sick

    private var cal: Calendar { SharedStore.calendar }
    private var today: Date { cal.startOfDay(for: .now) }
    private var yesterday: Date { cal.date(byAdding: .day, value: -1, to: today)! }

    private var presetIsOther: Bool {
        guard let p = preset.map({ cal.startOfDay(for: $0) }) else { return false }
        return p != today && p != yesterday
    }

    private var chosenDay: Date {
        switch choice {
        case 1: yesterday
        case 2: preset.map { cal.startOfDay(for: $0) } ?? today
        default: today
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("日期", selection: $choice) {
                        Text("今天").tag(0)
                        Text("昨天").tag(1)
                        if presetIsOther, let p = preset {
                            Text(p.formatted(.dateTime.month().day())).tag(2)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("請假的日子不算漏練，排名不會下滑、狀態不會下降。只罰「可以練卻沒練」，所以請誠實使用。")
                }
                Section("原因") {
                    Picker("原因", selection: $reason) {
                        ForEach(LeaveReason.allCases) { r in
                            Text(r.title).tag(r)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("請假")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("請假") {
                        CareerStore.addLeave(chosenDay, reason: reason)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                guard let p = preset.map({ cal.startOfDay(for: $0) }) else { return }
                choice = p == today ? 0 : (p == yesterday ? 1 : 2)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
