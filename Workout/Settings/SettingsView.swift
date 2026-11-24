import SwiftUI

/// Settings home: a summary card and one row per settings page.
/// Each page owns its own storage; this screen only reads enough to show a one-line status.
struct SettingsView: View {
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.trainingLevel) private var levelRaw = TrainingLevel.beginner.rawValue
    @AppStorage(Keys.weakSide) private var weakSide = WeakSide.none.rawValue
    @AppStorage(Keys.weakLeg) private var weakLeg = WeakSide.none.rawValue
    @AppStorage(Keys.activeProgram) private var activeProgram = ""
    @AppStorage(Keys.builtInProgram) private var builtInRaw = ""
    @AppStorage(Keys.customPrograms) private var programsRaw = ""
    @AppStorage(Keys.reminderOn) private var reminderOn = true
    @AppStorage(Keys.reminderLead) private var reminderLead = 0
    @AppStorage(Keys.readPhoneCalendar) private var readPhoneCalendar = false

    private var reminderSummary: String {
        guard reminderOn else { return "關閉" }
        return reminderLead == 0 ? "準時" : "提前 \(reminderLead) 分"
    }

    private var equipmentStatus: String {
        let owned = Equipment.parse(equipmentRaw)
        let names = Equipment.allCases.filter { owned.contains($0) }.map(\.name)
        return names.isEmpty ? "只用徒手動作" : names.joined(separator: "、")
    }

    private var trainingStatus: String {
        let week = Stats.week(since: Date(timeIntervalSince1970: startDate))
        let level = TrainingLevel(rawValue: levelRaw)?.title ?? TrainingLevel.beginner.title
        var parts = ["第 \(week) 週", level]
        if weakSide != WeakSide.none.rawValue || weakLeg != WeakSide.none.rawValue { parts.append("左右平衡開") }
        return parts.joined(separator: "・")
    }

    private var programStatus: String {
        _ = (activeProgram, programsRaw, builtInRaw)
        return ProgramBuilder.customName ?? BuiltInProgram.current.title
    }

    private var scheduleStatus: String {
        var parts = ["提醒：\(reminderSummary)"]
        if readPhoneCalendar { parts.append("讀 iPhone 行事曆") }
        return parts.joined(separator: "・")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("設定")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Theme.fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 12, leading: 4, bottom: 0, trailing: 4))
                    summaryCard
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                Section {
                    row("器材", icon: "dumbbell.fill", tint: Theme.accent, status: equipmentStatus) {
                        EquipmentSettingsView()
                    }
                    row("訓練", icon: "flame.fill", tint: Theme.hot, status: trainingStatus) {
                        TrainingSettingsView()
                    }
                    row("課表與動作", icon: "list.bullet.rectangle.fill", tint: Theme.green, status: programStatus) {
                        ProgramSettingsView()
                    }
                    row("排程與提醒", icon: "calendar.badge.clock", tint: Theme.gold, status: scheduleStatus) {
                        ScheduleSettingsView()
                    }
                    row("資料", icon: "square.and.arrow.up.fill", tint: Theme.muted, status: "匯出 CSV") {
                        DataSettingsView()
                    }
                    row("3D 測試", icon: "cube.fill", tint: Theme.accent, status: "3D 角色技術驗證") {
                        Hero3DLabView()
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .themeForm()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func row<Destination: View>(_ title: String, icon: String, tint: Color, status: String,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.bg)
                    .frame(width: 32, height: 32)
                    .background(tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body.weight(.semibold)).foregroundStyle(Theme.fg)
                    Text(status).font(.caption).foregroundStyle(Theme.muted).lineLimit(1)
                }
            }
            .frame(minHeight: 48)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryTile(value: "\(Equipment.parse(equipmentRaw).count)", unit: "項", label: "器材")
            Rectangle().fill(Theme.divider).frame(width: 1, height: 40)
            summaryTile(value: "\(weeklyGoal)", unit: "次", label: "每週目標")
            Rectangle().fill(Theme.divider).frame(width: 1, height: 40)
            summaryTile(value: reminderSummary, unit: nil, label: "提醒")
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func summaryTile(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Theme.number(24))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit).font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                }
            }
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
