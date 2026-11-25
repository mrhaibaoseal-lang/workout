import SwiftUI
import SwiftData

enum OnboardingMode {
    /// 第一次開 App：寫完設定、排好第 1 週
    case first
    /// 設定 → 訓練 →「重新填問卷」：只更新有填的欄位
    case redo
}

/// 單選的按鈕列：再點一次已選的 = 取消選擇（回到「沒填」）。
struct ChoiceChips<T: Hashable>: View {
    let options: [T]
    let title: (T) -> String
    @Binding var selection: T?
    var enabled = true

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { option in
                let on = selection == option
                Button {
                    selection = on ? nil : option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.bold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 6)
                        .background(on ? Theme.accent : Theme.raised,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                        .animation(.easeOut(duration: 0.15), value: on)
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .opacity(enabled ? 1 : 0.5)
        .allowsHitTesting(enabled)
    }
}

/// 第一次開 App 的問卷（0.43.0）：分頁，每一頁都能略過。
/// 身體資料 → 訓練經驗 → 每週幾天、每次多久 → 會痛的部位 → 器材 → 程度評估 → 左右平衡 →（雲端備份）。
struct OnboardingView: View {
    var mode: OnboardingMode = .first

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage(Keys.onboarded) private var onboarded = false
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970

    private enum Step: Int, CaseIterable {
        case welcome, body, experience, schedule, pain, equipment, levelTest, sides, cloud

        var title: String {
            switch self {
            case .welcome: "練壯"
            case .body: "身體資料"
            case .experience: "訓練經驗"
            case .schedule: "練習時間"
            case .pain: "會痛的地方"
            case .equipment: "器材"
            case .levelTest: "程度評估"
            case .sides: "左右平衡"
            case .cloud: "加密雲端備份"
            }
        }
    }

    @State private var step: Step = .welcome
    @State private var answers = OnboardingAnswers()
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var minutes: OnboardingFlow.SessionMinutes?
    @State private var weekdaysRaw = ""
    @State private var weekdaysManual = false
    @State private var painNone = false
    @State private var hadInjury = false
    @State private var injuryText = ""
    @State private var showRestore = false
    @State private var showCloudSetup = false
    @State private var cloudOn = CloudSync.isEnabled
    /// 這次問卷開始的時間：只有在這之後做的程度評估，才拿來蓋掉自己填的弱邊
    @State private var startedAt = Date().timeIntervalSince1970
    @State private var summary: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 換頁方向：true = 往前（新頁從右邊推進），false = 往回（從左邊推進）
    @State private var forward = true
    /// 要換去的頁。先讓 `forward` 畫進一次，再真的換頁，離場的那一頁才會用到正確方向。
    @State private var pendingStep: Step?

    private var steps: [Step] {
        Step.allCases.filter { $0 != .cloud || CloudConfig.isConfigured }
    }

    private var index: Int { steps.firstIndex(of: step) ?? 0 }
    private var isLast: Bool { index == steps.count - 1 }

    /// 這次問卷做的划船實測，兩手差 2 下以上時的弱手
    private var measuredArm: WeakSide? {
        guard let r = LevelTest.current, r.date >= startedAt else { return nil }
        return LevelTest.measuredWeakArm(r)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                page
                    .id(step)
                    .transition(pageTransition)
            }
                .themeForm()
                .navigationTitle(step.title)
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    StepProgressBar(fraction: Double(index + 1) / Double(steps.count))
                        .background(Theme.bg)
                }
                .safeAreaInset(edge: .bottom) { bottomBar }
                .onChange(of: pendingStep) { _, target in
                    guard let target else { return }
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)) {
                        step = target
                    }
                    pendingStep = nil
                }
                .toolbar {
                    if mode == .redo {
                        ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showRestore) {
            CloudRestoreView()
        }
        .sheet(isPresented: $showCloudSetup, onDismiss: { cloudOn = CloudSync.isEnabled }) {
            CloudSetupView()
        }
        .alert("設定好了", isPresented: Binding(get: { summary != nil }, set: { if !$0 { summary = nil; dismiss() } })) {
            Button("好") {}
        } message: {
            Text(summary ?? "")
        }
    }

    // MARK: 頁面

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome: welcomePage
        case .body: bodyPage
        case .experience: experiencePage
        case .schedule: schedulePage
        case .pain: painPage
        case .equipment: equipmentPage
        case .levelTest: LevelTestView(onDone: next)
        case .sides: sidesPage
        case .cloud: cloudPage
        }
    }

    private var welcomePage: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .first ? "這次不一樣" : "重新填問卷")
                        .font(.title.bold())
                        .foregroundStyle(Theme.fg)
                    Text(mode == .first
                         ? "回答幾個問題，App 會幫你排好第一週的課表和第一次的重量。每一題都可以略過，之後隨時能在設定裡改。"
                         : "只有你填的欄位會更新，沒填、略過的都不會動到；訓練紀錄也不會被清掉。")
                        .foregroundStyle(Theme.muted)
                    Text("大約 2 分鐘。忙的時候選精簡版，20 分鐘也算數；中斷了也不用從頭來，只要接著下一天練。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Theme.surface)

            if mode == .first && CloudConfig.isConfigured {
                Section {
                    Button {
                        showRestore = true
                    } label: {
                        Label("我換手機了，用恢復碼還原", systemImage: "icloud.and.arrow.down")
                    }
                    .frame(minHeight: 44)
                } footer: {
                    SectionLabel("以前開過加密雲端備份的話，輸入當時抄下來的恢復碼，就能把紀錄和設定都拿回來。")
                }
                .listRowBackground(Theme.surface)
            }
        }
    }

    private var bodyPage: some View {
        Form {
            Section {
                LabeledContent("身高") {
                    HStack(spacing: 4) {
                        TextField("例如 172", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("cm").foregroundStyle(Theme.muted)
                    }
                }
                .frame(minHeight: 44)
                LabeledContent("體重") {
                    HStack(spacing: 4) {
                        TextField("例如 65", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg").foregroundStyle(Theme.muted)
                    }
                }
                .frame(minHeight: 44)
                Picker("出生年", selection: Binding(get: { answers.birthYear ?? 0 },
                                                 set: { answers.birthYear = $0 == 0 ? nil : $0 })) {
                    Text("不填").tag(0)
                    ForEach(UserProfile.birthYearChoices(), id: \.self) { Text(String($0)).tag($0) }
                }
                .frame(minHeight: 44)
            } footer: {
                SectionLabel("體重會記成第一筆身體數據，推第一次的重量也用得到。身高、年齡、性別用來估每天大概消耗多少熱量。")
            }
            .listRowBackground(Theme.surface)

            Section {
                ChoiceChips(options: Sex.allCases, title: \.title, selection: $answers.sex)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("性別")
            } footer: {
                SectionLabel("選「不想說」或不選，熱量就不估，只看增重速度。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var experiencePage: some View {
        Form {
            Section {
                ChoiceChips(options: TrainingExperience.allCases, title: \.title, selection: $answers.experience)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("你規律重量訓練多久了？")
            } footer: {
                SectionLabel("練了 2 年以上直接用中階排法（主要動作一天重、一天輕）；其他都從新手開始，做到上限就加重，之後練夠了 App 會問你要不要升中階。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var schedulePage: some View {
        Form {
            Section {
                ChoiceChips(options: [2, 3, 4, 5, 6], title: { "\($0) 天" },
                            selection: Binding(get: { answers.daysPerWeek },
                                               set: { setDays($0) }))
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("每週練幾天？")
            } footer: {
                SectionLabel("3 天（含以下）用「3 天全身」課表，4 天以上用「上下半身分化」。之後可以在設定 → 課表與動作換。")
            }
            .listRowBackground(Theme.surface)

            if answers.daysPerWeek != nil {
                Section {
                    WeekdayPicker(raw: $weekdaysRaw)
                        .onChange(of: weekdaysRaw) { _, new in
                            if let n = answers.daysPerWeek,
                               Keys.parseWeekdays(new) != OnboardingFlow.suggestedWeekdays(days: n) {
                                weekdaysManual = true
                            }
                        }
                } header: {
                    SectionLabel("通常哪幾天？")
                } footer: {
                    SectionLabel("練習提醒會用這幾天。每天的時間之後會依行事曆自動排。")
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                ChoiceChips(options: OnboardingFlow.SessionMinutes.allCases, title: \.title, selection: $minutes)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("每次大概能練多久？")
            } footer: {
                SectionLabel("30 分鐘以內：預設排精簡版（只留重點動作，組數少一半左右）；其他預設完整版。今天頁隨時可以改，按鈕上會寫今天幾組。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var painPage: some View {
        Form {
            Section {
                let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(Joint.allCases) { joint in
                        let on = answers.painJoints?.contains(joint) ?? false
                        chip(joint.title, on: on) { toggle(joint) }
                    }
                    chip("都沒有", on: painNone) {
                        painNone.toggle()
                        if painNone { answers.painJoints = [] }
                        else if answers.painJoints?.isEmpty ?? true { answers.painJoints = nil }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("哪裡會痛，或受過傷？（可複選）")
            } footer: {
                SectionLabel("選了的關節，會用到它的動作會標成「會痛」，自動排課就不會排（每一類會留一個比較溫和的動作）。想放回來，到設定 → 課表與動作 → 不排的動作取消標記。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var equipmentPage: some View {
        Form {
            Section {
                EquipmentPicker(raw: $equipmentRaw)
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
            } header: {
                SectionLabel("你家裡有什麼器材？")
            } footer: {
                SectionLabel("徒手動作永遠可用。去健身房可以在設定切換。")
            }
            .listRowBackground(Color.clear)
        }
    }

    private var sidesPage: some View {
        Form {
            if let r = LevelTest.current, let l = r.rowLeftReps, let rt = r.rowRightReps, r.date >= startedAt {
                Section {
                    if let arm = measuredArm {
                        Label("划船實測：左 \(l) 下、右 \(rt) 下，\(arm.hand)手比較弱。已經幫你把手的弱邊設成「\(arm.hand)手」。",
                              systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.green)
                        if let mine = answers.weakArm, mine != arm {
                            Text("你自己選的是「\(mine.title)」，和實測不一樣，以實測為準。")
                                .font(.footnote)
                                .foregroundStyle(Theme.muted)
                        }
                    } else {
                        Text("划船實測：左 \(l) 下、右 \(rt) 下，差不到 2 下，不用特別設。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                ChoiceChips(options: WeakSide.allCases, title: { armTitle($0) },
                            selection: Binding(get: { measuredArm ?? answers.weakArm },
                                               set: { answers.weakArm = $0 }),
                            enabled: measuredArm == nil)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("手：哪一邊比較弱？")
            }
            .listRowBackground(Theme.surface)

            Section {
                ChoiceChips(options: WeakSide.allCases, title: { legTitle($0) }, selection: $answers.weakLeg)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            } header: {
                SectionLabel("腳：哪一邊比較弱？")
            } footer: {
                SectionLabel("弱的那邊會先做，另一邊做到一樣的次數就停；不確定就選「沒有」，之後 App 會看紀錄提醒你。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("以前有受過傷", isOn: $hadInjury)
                if hadInjury {
                    TextField("例如：左肩脫臼過、右腳踝扭傷", text: $injuryText, axis: .vertical)
                        .lineLimit(2...4)
                }
            } footer: {
                SectionLabel("只是給你自己的備註，不會改變課表。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var cloudPage: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("要不要開啟加密雲端備份？")
                        .font(.headline)
                        .foregroundStyle(Theme.fg)
                    Text("訓練紀錄和設定會在你的手機上先加密，再傳到雲端；伺服器看不到內容，只有你抄下來的「恢復碼」打得開。換手機時輸入恢復碼就能拿回所有資料。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Theme.surface)

            Section {
                if cloudOn {
                    Label("已開啟", systemImage: "checkmark.icloud.fill")
                        .foregroundStyle(Theme.green)
                } else {
                    Button {
                        showCloudSetup = true
                    } label: {
                        Label("開啟，並抄下恢復碼", systemImage: "icloud.and.arrow.up")
                    }
                    .frame(minHeight: 44)
                }
            } footer: {
                SectionLabel("預設是關閉的。之後可以在設定 → 資料開關。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    // MARK: 小元件

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? Theme.accent : Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(on ? Theme.bg : Theme.fg)
                .animation(.easeOut(duration: 0.15), value: on)
        }
        .buttonStyle(PressScaleButtonStyle())
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func armTitle(_ s: WeakSide) -> String {
        switch s {
        case .none: "沒有明顯差"
        case .left: "左手較弱"
        case .right: "右手較弱"
        }
    }

    private func legTitle(_ s: WeakSide) -> String {
        switch s {
        case .none: "沒有明顯差"
        case .left: "左腳較弱"
        case .right: "右腳較弱"
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if index > 0 {
                Button("返回") { back() }
                    .buttonStyle(GhostButtonStyle())
            }
            if step != .welcome {
                Button("略過") { skip() }
                    .buttonStyle(GhostButtonStyle())
            }
            if step != .levelTest {
                Button(isLast ? (mode == .first ? "完成，開始第 1 週" : "完成") : "下一步") { next() }
                    .buttonStyle(HotButtonStyle(height: 48))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.bg)
    }

    // MARK: 動作

    private func toggle(_ joint: Joint) {
        var set = answers.painJoints ?? []
        if set.contains(joint) { set.remove(joint) } else { set.insert(joint) }
        painNone = false
        answers.painJoints = set.isEmpty ? nil : set
    }

    private func setDays(_ n: Int?) {
        answers.daysPerWeek = n
        guard let n else { return }
        if !weekdaysManual || weekdaysRaw.isEmpty {
            weekdaysRaw = OnboardingFlow.suggestedWeekdays(days: n).sorted().map(String.init).joined(separator: ",")
            weekdaysManual = false
        }
    }

    /// 往前從右邊推進、往回從左邊推進；減少動態效果時改成淡入淡出。
    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let edge: Edge = forward ? .trailing : .leading
        let out: Edge = forward ? .leading : .trailing
        return .asymmetric(insertion: .move(edge: edge).combined(with: .opacity),
                           removal: .move(edge: out).combined(with: .opacity))
    }

    private func go(to target: Step, forward isForward: Bool) {
        guard pendingStep == nil else { return }
        forward = isForward
        pendingStep = target
    }

    private func back() {
        guard index > 0 else { return }
        go(to: steps[index - 1], forward: false)
    }

    private func next() {
        if isLast { finish() } else { go(to: steps[index + 1], forward: true) }
    }

    /// 略過這一頁：這一頁填的都不算。
    private func skip() {
        switch step {
        case .body:
            heightText = ""; weightText = ""
            answers.birthYear = nil; answers.sex = nil
        case .experience: answers.experience = nil
        case .schedule:
            answers.daysPerWeek = nil; minutes = nil; weekdaysRaw = ""; weekdaysManual = false
        case .pain: answers.painJoints = nil; painNone = false
        case .sides:
            answers.weakArm = nil; answers.weakLeg = nil; hadInjury = false; injuryText = ""
        default: break
        }
        next()
    }

    /// 輸入框的字 → 數字；不合理的當沒填。
    static func number(_ text: String, in range: ClosedRange<Double>) -> Double? {
        let t = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let v = Double(t), range.contains(v) else { return nil }
        return v
    }

    private func finish() {
        var a = answers
        a.heightCm = Self.number(heightText, in: 100...230)
        a.weightKg = Self.number(weightText, in: 25...250)
        a.shortSessions = minutes?.isShort
        let days = Keys.parseWeekdays(weekdaysRaw)
        a.weekdays = a.daysPerWeek != nil && !days.isEmpty ? days : nil
        if hadInjury {
            let note = injuryText.trimmingCharacters(in: .whitespacesAndNewlines)
            a.injuryNote = note.isEmpty ? "有受過傷（沒寫是哪裡）" : note
        }
        let marked = OnboardingFlow.apply(a, measuredArm: measuredArm, context: context)
        switch mode {
        case .first:
            startDate = Date().timeIntervalSince1970
            onboarded = true
            CloudSync.shared.scheduleUpload()
        case .redo:
            CloudSync.shared.scheduleUpload()
            summary = marked > 0
                ? "有填的欄位已經更新。另外把 \(marked) 個會用到痛處關節的動作標成「會痛」，排課不會再排。"
                : "有填的欄位已經更新，訓練紀錄沒有動。"
        }
    }
}
