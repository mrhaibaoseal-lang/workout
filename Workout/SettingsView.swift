import SwiftUI

/// Muted section header / footer text for dark Forms.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(Theme.muted)
    }
}

extension View {
    /// Dark stage styling for Form / List screens.
    func themeForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .tint(Theme.accent)
    }
}

struct EquipmentPicker: View {
    @Binding var raw: String

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Equipment.homeChoices) { eq in
                let on = binding(for: eq)
                Button {
                    on.wrappedValue.toggle()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: eq.icon)
                            .font(.title2)
                            .foregroundStyle(on.wrappedValue ? Theme.accent : Theme.muted)
                            .frame(height: 28)
                        Text(eq.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.fg)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .padding(.horizontal, 8)
                    .background(on.wrappedValue ? Theme.accent.opacity(0.15) : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(on.wrappedValue ? Theme.accent : Theme.line, lineWidth: on.wrappedValue ? 2 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on.wrappedValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(eq.name)
                .accessibilityAddTraits(on.wrappedValue ? .isSelected : [])
            }
        }
    }

    private func binding(for eq: Equipment) -> Binding<Bool> {
        Binding(
            get: { Equipment.parse(raw).contains(eq) },
            set: { on in
                var set = Equipment.parse(raw)
                if on { set.insert(eq) } else { set.remove(eq) }
                raw = Equipment.encode(set)
            }
        )
    }
}

struct SettingsView: View {
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.autoWarmup) private var autoWarmup = true
    @AppStorage(Keys.limitBarbell) private var limitBarbell = true
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.maxDumbbell) private var maxDumbbell = 20.0
    @AppStorage(Keys.maxBarbell) private var maxBarbell = 40.0
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.reminderOn) private var reminderOn = true
    @AppStorage(Keys.reminderLead) private var reminderLead = 0
    @AppStorage(Keys.commuteSchool) private var commuteSchool = 15
    @AppStorage(Keys.commuteWork) private var commuteWork = 5
    @AppStorage(Keys.earliestHour) private var earliestHour = 12
    @AppStorage(Keys.preferredHour) private var preferredHour = 14
    @AppStorage(Keys.latestHour) private var latestHour = 25
    @AppStorage(Keys.tiredHours) private var tiredHours = 6
    @AppStorage(Keys.readPhoneCalendar) private var readPhoneCalendar = false
    @State private var confirmRestart = false
    @State private var shiftInfo = ShiftReader.load()

    private func hourLabel(_ h: Int) -> String {
        h >= 24 ? "凌晨 \(h - 24):00" : "\(h):00"
    }

    private var shiftStatus: String {
        guard shiftInfo.found else { return "讀不到。請更新「打工薪水帳」到 3.0.7 以上並打開一次。" }
        let upcoming = shiftInfo.shifts.filter { $0.end > .now }.count
        let updated = shiftInfo.updatedAt.map { "，更新於 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
        return "已讀到，接下來 \(upcoming) 個班\(updated)"
    }

    private var reminderSummary: String {
        guard reminderOn else { return "關閉" }
        return reminderLead == 0 ? "準時" : "提前 \(reminderLead) 分"
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
                    EquipmentPicker(raw: $equipmentRaw)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                } header: {
                    SectionLabel("我的器材")
                } footer: {
                    SectionLabel("徒手動作永遠可用。點選後課表會自動換成適合的動作。")
                }
                .listRowBackground(Color.clear)

                Section {
                    Toggle(isOn: $autoWarmup) {
                        Label("自動排熱身組", systemImage: "flame")
                    }
                    Toggle(isOn: $limitBarbell) {
                        Label("槓鈴要組裝，在家少排槓鈴", systemImage: "wrench.adjustable")
                    }
                } header: {
                    SectionLabel("訓練")
                } footer: {
                    SectionLabel("依正式組的重量自動算熱身組（例如 50% × 10、75% × 5），每個部位的第一個動作才做完整熱身。熱身組不算進步和破紀錄。每個動作的「遞增／遞減／Drop set」在訓練畫面右上角的按鈕調整。開啟「少排槓鈴」時，在家只有下半身 B 的臀推用槓鈴，其他都用啞鈴。")
                }

                Section {
                    NavigationLink {
                        ClassScheduleView()
                    } label: {
                        Label("課表", systemImage: "graduationcap")
                    }
                    NavigationLink {
                        ShiftListView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("班表（打工薪水帳）", systemImage: "briefcase")
                            Text(shiftStatus).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    Toggle(isOn: $readPhoneCalendar) {
                        Label("也讀 iPhone 行事曆", systemImage: "calendar")
                    }
                    .onChange(of: readPhoneCalendar) { _, on in
                        guard on else { return }
                        Task {
                            if !(await PhoneCalendar.requestAccess()) { readPhoneCalendar = false }
                        }
                    }
                    Stepper("到學校 \(commuteSchool) 分鐘", value: $commuteSchool, in: 0...120, step: 5)
                    Stepper("到打工地點 \(commuteWork) 分鐘", value: $commuteWork, in: 0...120, step: 5)
                    Picker("最早開始", selection: $earliestHour) {
                        ForEach(6...18, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("偏好開始", selection: $preferredHour) {
                        ForEach(6...22, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("最晚結束", selection: $latestHour) {
                        ForEach(20...28, id: \.self) { Text(hourLabel($0)).tag($0) }
                    }
                    Picker("打工／拍片超過", selection: $tiredHours) {
                        Text("4 小時不排完整版").tag(4)
                        Text("6 小時不排完整版").tag(6)
                        Text("8 小時不排完整版").tag(8)
                        Text("不限制").tag(0)
                    }
                } header: {
                    SectionLabel("自動排程")
                } footer: {
                    SectionLabel("App 會扣掉上課、打工、活動和通勤時間，找出每天的空檔，自動排出這週要練哪幾天、練多久、幾點開始。這只是建議：首頁隨時可以改成完整版、精簡版或只做 1 組。班表直接從「打工薪水帳」讀取，改班後打開練壯就會重新排。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Toggle("練習提醒", isOn: $reminderOn)
                    if reminderOn {
                        Picker("提醒時間", selection: $reminderLead) {
                            Text("排定時間").tag(0)
                            Text("提前 15 分鐘").tag(15)
                            Text("提前 30 分鐘").tag(30)
                            Text("提前 1 小時").tag(60)
                        }
                    }
                } header: {
                    SectionLabel("提醒")
                } footer: {
                    SectionLabel("照自動排出的時間提醒。當天已經練過就不會提醒。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Stepper("每週 \(weeklyGoal) 次", value: $weeklyGoal, in: 2...6)
                    Stepper("每次加重 \(Progression.format(increment)) kg", value: $increment, in: 0.5...5, step: 0.5)
                    Stepper("啞鈴最重（每支）\(Progression.format(maxDumbbell)) kg", value: $maxDumbbell, in: 5...60, step: 2.5)
                    Stepper("槓鈴最重（含槓）\(Progression.format(maxBarbell)) kg", value: $maxBarbell, in: 10...150, step: 5)
                } header: {
                    SectionLabel("目標")
                }
                .listRowBackground(Theme.surface)

                Section {
                    LabeledContent("目前", value: "第 \(Stats.week(since: Date(timeIntervalSince1970: startDate))) 週")
                    Button("從第 1 週重新開始") { confirmRestart = true }
                        .foregroundStyle(Theme.hotText)
                        .frame(minHeight: 44)
                } header: {
                    SectionLabel("週期")
                } footer: {
                    SectionLabel("第 1-2 週是適應期，之後每 6 週有一次減量週，減量週後換一批動作。重新開始不會刪除紀錄。")
                }
                .listRowBackground(Theme.surface)
            }
            .themeForm()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { shiftInfo = ShiftReader.load() }
            .confirmationDialog("從第 1 週重新開始？", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("重新開始") { startDate = Date().timeIntervalSince1970 }
            } message: {
                Text("適合停練一段時間後回來，會重新進入兩週適應期。")
            }
        }
    }
}

struct OnboardingView: View {
    @AppStorage(Keys.onboarded) private var onboarded = false
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("這次不一樣")
                            .font(.title.bold())
                            .foregroundStyle(Theme.fg)
                        Text("每週 4 次，每次照著做就好。忙的時候選精簡版，20 分鐘也算數。中斷了也不用從頭來，只要接著下一天練。")
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Theme.surface)
                Section {
                    EquipmentPicker(raw: $equipmentRaw)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                } header: {
                    SectionLabel("你家裡有什麼器材？")
                }
                .listRowBackground(Color.clear)
                Section {
                    Button {
                        startDate = Date().timeIntervalSince1970
                        onboarded = true
                    } label: {
                        Text("開始第 1 週")
                    }
                    .buttonStyle(HotButtonStyle())
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }
                .listRowBackground(Color.clear)
            }
            .themeForm()
            .navigationTitle("練壯")
        }
    }
}

struct WeekdayPicker: View {
    @Binding var raw: String

    /// Monday-first display order, as Calendar weekday numbers (1 = Sunday).
    private let order: [(Int, String)] = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]

    var body: some View {
        let selected = Keys.parseWeekdays(raw)
        HStack(spacing: 6) {
            ForEach(order.indices, id: \.self) { i in
                let (day, label) = order[i]
                let on = selected.contains(day)
                Button {
                    var s = selected
                    if on { s.remove(day) } else { s.insert(day) }
                    raw = s.sorted().map(String.init).joined(separator: ",")
                } label: {
                    Text(label)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? Theme.accent : Theme.raised,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
