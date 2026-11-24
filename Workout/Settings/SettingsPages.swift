import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// The five pages behind the settings home. Contents are the same controls that used to
// live in one long Form; they are only regrouped.

// MARK: - 器材

struct EquipmentSettingsView: View {
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.limitBarbell) private var limitBarbell = true
    @AppStorage(Keys.increment) private var increment = 2.5

    var body: some View {
        Form {
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
                NavigationLink {
                    KitEditorView()
                } label: {
                    Label("我的啞鈴與槓片", systemImage: "dumbbell")
                }
                Toggle(isOn: $limitBarbell) {
                    Label("槓鈴要組裝，在家少排槓鈴", systemImage: "wrench.adjustable")
                }
            } header: {
                SectionLabel("在家")
            } footer: {
                SectionLabel("加重建議只會跳到你的啞鈴裝得出來的重量。少排槓鈴：在家只有臀推用槓鈴。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Stepper("每次加重 \(Progression.format(increment)) kg", value: $increment, in: 0.5...5, step: 0.5)
            } header: {
                SectionLabel("健身房")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("器材")
    }
}

// MARK: - 訓練

struct TrainingSettingsView: View {
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.trainingLevel) private var levelRaw = TrainingLevel.beginner.rawValue
    @AppStorage(Keys.autoWarmup) private var autoWarmup = true
    @AppStorage(Keys.autoSuperset) private var autoSuperset = false
    @AppStorage(Keys.weakSide) private var weakSide = WeakSide.none.rawValue
    @AppStorage(Keys.weakExtra) private var weakExtra = true
    @AppStorage(Keys.weakLeg) private var weakLeg = WeakSide.none.rawValue
    @AppStorage(Keys.defaultLength) private var defaultLength = ""
    @State private var confirmRestart = false
    @State private var showQuestionnaire = false

    var body: some View {
        Form {
            Section {
                Stepper("每週 \(weeklyGoal) 次", value: $weeklyGoal, in: 2...6)
                Picker(selection: $defaultLength) {
                    Text("完整").tag("")
                    Text("精簡").tag(WorkoutLength.short.rawValue)
                } label: {
                    Label("預設長度", systemImage: "timer")
                }
                Toggle(isOn: $autoWarmup) {
                    Label("自動排熱身組", systemImage: "flame")
                }
                Toggle(isOn: $autoSuperset) {
                    Label("單關節動作配成超級組", systemImage: "arrow.triangle.2.circlepath")
                }
            } header: {
                SectionLabel("每次訓練")
            } footer: {
                SectionLabel("熱身組依正式組重量自動算。超級組只是省時間，不會長得比較快。")
            }
            .listRowBackground(Theme.surface)

            Section {
                NavigationLink {
                    LevelTestView()
                } label: {
                    LabeledContent {
                        Text(LevelTest.summary)
                    } label: {
                        Label("程度評估", systemImage: "gauge.with.dots.needle.50percent")
                    }
                }
                .frame(minHeight: 44)
                Button {
                    showQuestionnaire = true
                } label: {
                    Label("重新填問卷", systemImage: "list.clipboard")
                }
                .frame(minHeight: 44)
            } footer: {
                SectionLabel("評估：用 3 個簡單測試推算沒做過的動作第一次用多重。重新填問卷只會更新你有填的欄位，訓練紀錄和其他設定不會動。")
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
                SectionLabel("前 2 週適應期，之後約每 6 週一次減量週（會先問你要不要提早或延後）。"
                             + "\(TrainingLevel(rawValue: levelRaw)?.detail ?? TrainingLevel.beginner.detail)重新開始不會刪除紀錄。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Picker(selection: $weakSide) {
                    ForEach(WeakSide.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Label("手", systemImage: "hand.raised.fill")
                }
                Picker(selection: $weakLeg) {
                    ForEach(WeakSide.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Label("腳", systemImage: "figure.walk")
                }
                if weakSide != WeakSide.none.rawValue || weakLeg != WeakSide.none.rawValue {
                    Toggle(isOn: $weakExtra) {
                        Label("弱的那邊多做一組加強組", systemImage: "plus.circle")
                    }
                }
            } header: {
                HStack(spacing: 4) {
                    SectionLabel("左右平衡")
                    InfoTip(item: .sides)
                }
            } footer: {
                SectionLabel("單臂划船、分腿蹲這類動作兩邊分開記，連續 3 次某一邊少 2 下以上，今天頁會問你要不要開。開了以後弱的那邊先做、最後多一組。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("訓練")
        .fullScreenCover(isPresented: $showQuestionnaire) {
            OnboardingView(mode: .redo)
        }
        .confirmationDialog("從第 1 週重新開始？", isPresented: $confirmRestart, titleVisibility: .visible) {
            Button("重新開始") { startDate = Date().timeIntervalSince1970 }
        } message: {
            Text("適合停練一段時間後回來，會重新進入兩週適應期。")
        }
    }
}

// MARK: - 課表與動作

struct ProgramSettingsView: View {
    @AppStorage(Keys.activeProgram) private var activeProgram = ""
    @AppStorage(Keys.builtInProgram) private var builtInRaw = ""
    @AppStorage(Keys.customPrograms) private var programsRaw = ""
    @AppStorage(Keys.focusMuscles) private var focusRaw = ""
    @AppStorage(Keys.specialization) private var specRaw = ""
    @AppStorage(Keys.customInAutoPick) private var customInAutoPick = false

    private var programStatus: String {
        _ = (activeProgram, programsRaw, builtInRaw)
        return ProgramBuilder.customName.map { "使用中：\($0)" } ?? "使用中：\(BuiltInProgram.current.title)"
    }

    private var focusStatus: String {
        _ = (focusRaw, specRaw, activeProgram, builtInRaw)
        var parts: [String] = []
        let list = Focus.muscles
        parts.append(list.isEmpty ? "沒有重點部位" : "重點：" + list.map(\.name).joined(separator: "、"))
        switch Specialization.status(week: Plateau.currentWeek) {
        case .scheduled(let w): parts.append("專項期第 \(w) 週開始")
        case .running: parts.append("專項期進行中")
        default: break
        }
        return parts.joined(separator: "・")
    }

    var body: some View {
        Form {
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
                    FocusSettingsView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("重點部位與專項期", systemImage: "scope")
                        Text(focusStatus).font(.caption).foregroundStyle(Theme.muted)
                    }
                }
            } header: {
                SectionLabel("課表")
            } footer: {
                SectionLabel("自訂課表和內建課表分開存，選哪一份就用哪一份。")
            }
            .listRowBackground(Theme.surface)

            Section {
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
                SectionLabel("動作")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("課表與動作")
    }
}

// MARK: - 排程與提醒

struct ScheduleSettingsView: View {
    @AppStorage(Keys.reminderOn) private var reminderOn = true
    @AppStorage(Keys.reminderLead) private var reminderLead = 0
    @AppStorage(Keys.commuteSchool) private var commuteSchool = 15
    @AppStorage(Keys.commuteWork) private var commuteWork = 5
    @AppStorage(Keys.earliestHour) private var earliestHour = 12
    @AppStorage(Keys.preferredHour) private var preferredHour = 14
    @AppStorage(Keys.latestHour) private var latestHour = 25
    @AppStorage(Keys.tiredHours) private var tiredHours = 6
    @AppStorage(Keys.readPhoneCalendar) private var readPhoneCalendar = false
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
        Form {
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
            } header: {
                SectionLabel("要避開的時間")
            } footer: {
                SectionLabel("扣掉上課、打工、活動和通勤，自動排出這週哪幾天練、幾點開始。首頁隨時可以改長度。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Stepper("到學校 \(commuteSchool) 分鐘", value: $commuteSchool, in: 0...120, step: 5)
                Stepper("到打工地點 \(commuteWork) 分鐘", value: $commuteWork, in: 0...120, step: 5)
            } header: {
                SectionLabel("通勤")
            }
            .listRowBackground(Theme.surface)

            Section {
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
                SectionLabel("時段")
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
        }
        .themeForm()
        .navigationTitle("排程與提醒")
        .onAppear { shiftInfo = ShiftReader.load() }
    }
}

// MARK: - 資料

struct DataSettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var inventory: InventoryStore
    @State private var exportFiles: ExportFiles?
    @State private var exportError: String?
    /// 完整備份：選好的檔案（確認後才匯入）
    @State private var pendingImport: FullBackup.File?
    @State private var showImporter = false
    @State private var importDone = false

    var body: some View {
        Form {
            Section {
                Button {
                    exportFull()
                } label: {
                    Label("匯出完整備份", systemImage: "externaldrive.badge.icloud")
                }
                .frame(minHeight: 44)
                Button {
                    showImporter = true
                } label: {
                    Label("從備份還原", systemImage: "arrow.down.doc")
                }
                .frame(minHeight: 44)
            } header: {
                SectionLabel("完整備份")
            } footer: {
                SectionLabel("訓練紀錄、身體數據、角色背包、目標和所有設定存成一個檔，存到「檔案」App 或傳給自己。重裝 App、換憑證或換手機時用「從備份還原」拿回來。建議每週存一次。")
            }
            .listRowBackground(Theme.surface)

            CloudSettingsSection()

            Section {
                Button {
                    export()
                } label: {
                    Label("匯出 CSV", systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
            } footer: {
                SectionLabel("匯出成 CSV（重量是 kg），可以用 Excel、Numbers 打開。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("資料")
        .sheet(item: $exportFiles) { f in
            ShareSheet(items: f.urls)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            pickBackup(result)
        }
        .confirmationDialog("用備份取代目前的資料？", isPresented: Binding(get: { pendingImport != nil },
                                                                   set: { if !$0 { pendingImport = nil } }),
                            titleVisibility: .visible) {
            Button("取代並還原", role: .destructive) { restore() }
            Button("取消", role: .cancel) { pendingImport = nil }
        } message: {
            if let f = pendingImport {
                Text("備份裡有 \(f.sessions.count) 次訓練、\(f.bodies.count) 筆身體數據（\(f.exportedAt.formatted(date: .abbreviated, time: .shortened)) 存的）。目前 App 裡的紀錄和設定會全部被取代，沒辦法復原。")
            }
        }
        .alert("還原好了", isPresented: $importDone) {
            Button("好") {}
        } message: {
            Text("建議把 App 完全關掉再打開一次，讓所有畫面重新讀取。")
        }
        .alert("沒辦法完成", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("好") {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func exportFull() {
        do {
            exportFiles = ExportFiles(urls: [try FullBackup.exportFile(context: context)])
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func pickBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try FullBackup.decode(Data(contentsOf: url))
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func restore() {
        guard let f = pendingImport else { return }
        pendingImport = nil
        do {
            try FullBackup.restore(f, context: context)
            inventory.reload()
            importDone = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func export() {
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

private struct ExportFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}
