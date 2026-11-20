import SwiftUI

struct EquipmentPicker: View {
    @Binding var raw: String

    var body: some View {
        ForEach(Equipment.allCases) { eq in
            Toggle(isOn: binding(for: eq)) {
                Label(eq.name, systemImage: eq.icon)
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EquipmentPicker(raw: $equipmentRaw)
                } header: {
                    Text("我的器材")
                } footer: {
                    Text("徒手動作永遠可用。勾選後課表會自動換成適合的動作。")
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
                            Text(shiftStatus).font(.caption).foregroundStyle(.secondary)
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
                    Text("自動排程")
                } footer: {
                    Text("App 會扣掉上課、打工、活動和通勤時間，找出每天的空檔，自動排出這週要練哪幾天、練多久、幾點開始。這只是建議：首頁隨時可以改成完整版、精簡版或只做 1 組。班表直接從「打工薪水帳」讀取，改班後打開練壯就會重新排。")
                }

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
                    Text("提醒")
                } footer: {
                    Text("照自動排出的時間提醒。當天已經練過就不會提醒。")
                }

                Section("目標") {
                    Stepper("每週 \(weeklyGoal) 次", value: $weeklyGoal, in: 2...6)
                    Stepper("每次加重 \(Progression.format(increment)) kg", value: $increment, in: 0.5...5, step: 0.5)
                    Stepper("啞鈴最重（每支）\(Progression.format(maxDumbbell)) kg", value: $maxDumbbell, in: 5...60, step: 2.5)
                    Stepper("槓鈴最重（含槓）\(Progression.format(maxBarbell)) kg", value: $maxBarbell, in: 10...150, step: 5)
                }

                Section {
                    LabeledContent("目前", value: "第 \(Stats.week(since: Date(timeIntervalSince1970: startDate))) 週")
                    Button("從第 1 週重新開始") { confirmRestart = true }
                } header: {
                    Text("週期")
                } footer: {
                    Text("第 1-2 週是適應期，之後每 6 週有一次減量週，減量週後換一批動作。重新開始不會刪除紀錄。")
                }
            }
            .navigationTitle("設定")
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
                        Text("這次不一樣").font(.title.bold())
                        Text("每週 4 次，每次照著做就好。忙的時候選精簡版，20 分鐘也算數。中斷了也不用從頭來，只要接著下一天練。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section("你家裡有什麼器材？") {
                    EquipmentPicker(raw: $equipmentRaw)
                }
                Section {
                    Button {
                        startDate = Date().timeIntervalSince1970
                        onboarded = true
                    } label: {
                        Text("開始第 1 週").font(.headline).frame(maxWidth: .infinity)
                    }
                }
            }
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
                        .frame(width: 36, height: 36)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                        .foregroundStyle(on ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
