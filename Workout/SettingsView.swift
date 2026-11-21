import SwiftUI
import SwiftData

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
    @AppStorage(Keys.customInAutoPick) private var customInAutoPick = false
    @AppStorage(Keys.autoSuperset) private var autoSuperset = false
    @AppStorage(Keys.activeProgram) private var activeProgram = ""
    @AppStorage(Keys.builtInProgram) private var builtInRaw = ""
    @AppStorage(Keys.customPrograms) private var programsRaw = ""
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.trainingLevel) private var levelRaw = TrainingLevel.beginner.rawValue
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
    @Environment(\.modelContext) private var context
    @State private var exportFiles: ExportFiles?
    @State private var exportError: String?

    private func hourLabel(_ h: Int) -> String {
        h >= 24 ? "凌晨 \(h - 24):00" : "\(h):00"
    }

    private var shiftStatus: String {
        guard shiftInfo.found else { return "讀不到。請更新「打工薪水帳」到 3.0.7 以上並打開一次。" }
        let upcoming = shiftInfo.shifts.filter { $0.end > .now }.count
        let updated = shiftInfo.updatedAt.map { "，更新於 \($0.formatted(date: .abbreviated, time: .shortened))" } ?? ""
        return "已讀到，接下來 \(upcoming) 個班\(updated)"
    }

    private var programStatus: String {
        _ = (activeProgram, programsRaw, builtInRaw)
        return ProgramBuilder.customName.map { "使用中：\($0)" } ?? "使用中：\(BuiltInProgram.current.title)"
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
                    Toggle(isOn: $autoSuperset) {
                        Label("單關節動作配成超級組（省時間）", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    SectionLabel("訓練")
                } footer: {
                    SectionLabel("依正式組的重量自動算熱身組（例如 50% × 10、75% × 5），每個部位的第一個動作才做完整熱身。熱身組不算進步和破紀錄。每個動作的「遞增／遞減／Drop set」在訓練畫面右上角的按鈕調整。開啟「少排槓鈴」時，在家只有下半身 B 的臀推用槓鈴，其他都用啞鈴。超級組：內建課表裡相鄰的手臂、肩膀、小腿、核心動作兩兩輪流做，一輪做完才休息，兩個動作會分到不同器材。只是省時間，不會長得比較快。自訂課表在每個動作裡設定。")
                }

                Section {
                    NavigationLink {
                        ProgramListView()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("訓練課表", systemImage: "list.bullet.rectangle")
                            Text(programStatus).font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    NavigationLink {
                        CustomExerciseListView()
                    } label: {
                        Label("自訂動作", systemImage: "plus.square.on.square")
                    }
                    NavigationLink {
                        AvoidListView()
                    } label: {
                        Label("不排的動作", systemImage: "hand.raised")
                    }
                    Toggle(isOn: $customInAutoPick) {
                        Label("自動挑動作時也排自訂動作", systemImage: "wand.and.stars")
                    }
                } header: {
                    SectionLabel("課表與動作")
                } footer: {
                    SectionLabel("自訂課表和內建課表分開存，選哪一份就用哪一份。開關關著時，自訂動作只會出現在你指定它的自訂課表裡。")
                }
                .listRowBackground(Theme.surface)

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
                    NavigationLink {
                        KitEditorView()
                    } label: {
                        Label("我的啞鈴與槓片", systemImage: "dumbbell")
                    }
                    Stepper("健身房每次加重 \(Progression.format(increment)) kg", value: $increment, in: 0.5...5, step: 0.5)
                } header: {
                    SectionLabel("目標")
                } footer: {
                    SectionLabel("在家時，加重建議只會跳到你的啞鈴裝得出來的重量，還會告訴你每邊要裝哪幾片。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    LabeledContent("目前", value: "第 \(Stats.week(since: Date(timeIntervalSince1970: startDate))) 週")
                    Picker("排法", selection: $levelRaw) {
                        ForEach(TrainingLevel.allCases) { l in
                            Text(l.title).tag(l.rawValue)
                        }
                    }
                    .frame(minHeight: 44)
                    Button("從第 1 週重新開始") { confirmRestart = true }
                        .foregroundStyle(Theme.hotText)
                        .frame(minHeight: 44)
                } header: {
                    SectionLabel("週期")
                } footer: {
                    SectionLabel("第 1-2 週是適應期，之後大約每 6 週有一次減量週（疲勞高會提早、狀態好可以延後，都會先問你），減量週後換一批動作。"
                                 + "\(TrainingLevel(rawValue: levelRaw)?.detail ?? TrainingLevel.beginner.detail)中階只套用在內建課表。重新開始不會刪除紀錄。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button {
                        export()
                    } label: {
                        Label("匯出 CSV", systemImage: "square.and.arrow.up")
                    }
                    .frame(minHeight: 44)
                } header: {
                    SectionLabel("資料")
                } footer: {
                    SectionLabel("「每組紀錄」和「身體數據」各一個檔（有間歇紀錄會多一個），可以用 Excel、Numbers 打開。重量一律是 kg。用分享選單存到「檔案」。")
                }
                .listRowBackground(Theme.surface)
            }
            .themeForm()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { shiftInfo = ShiftReader.load() }
            .sheet(item: $exportFiles) { f in
                ShareSheet(items: f.urls)
            }
            .alert("匯出失敗", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("好") {}
            } message: {
                Text(exportError ?? "")
            }
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

private struct ExportFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

private extension SettingsView {
    func export() {
        do {
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            let bodies = try context.fetch(FetchDescriptor<BodyLog>())
            let intervals = try context.fetch(FetchDescriptor<IntervalLog>())
            exportFiles = ExportFiles(urls: try CSVExport.files(sessions: sessions, bodies: bodies, intervals: intervals))
        } catch {
            exportError = error.localizedDescription
        }
    }
}
