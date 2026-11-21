import SwiftUI

// MARK: - 自訂動作

/// 設定 → 自訂動作。刪除只是隱藏，舊紀錄和 PR 還看得到名字。
struct CustomExerciseListView: View {
    @AppStorage(Keys.customExercises) private var raw = ""
    @State private var editing: CustomExercise?

    private var items: [CustomExercise] {
        _ = raw
        return CustomExercises.load().filter { !$0.hidden }
    }

    var body: some View {
        Form {
            Section {
                if items.isEmpty {
                    Text("還沒有自訂動作").foregroundStyle(Theme.muted)
                }
                ForEach(items) { item in
                    Button { editing = item } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name.isEmpty ? "自訂動作" : item.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.fg)
                            Text(CustomExerciseEditor.summary(item))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .onDelete { offsets in
                    let list = items
                    for i in offsets { CustomExercises.hide(list[i].id) }
                }
                Button("新增動作", systemImage: "plus") { editing = .blank() }
            } footer: {
                SectionLabel("動作類型決定部位熱圖、要不要排熱身，以及自動挑動作時算哪一類。刪除後舊紀錄和 PR 還會保留。自訂課表可以直接指定這些動作；內建課表要在設定開「自動挑動作時也排自訂動作」才會排到。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("自訂動作")
        .sheet(item: $editing) { item in
            NavigationStack {
                CustomExerciseEditor(item: item) { CustomExercises.upsert($0) }
            }
        }
    }
}

struct CustomExerciseEditor: View {
    @State var item: CustomExercise
    let onSave: (CustomExercise) -> Void
    @Environment(\.dismiss) private var dismiss

    static func summary(_ item: CustomExercise) -> String {
        let eq = item.equipment.isEmpty ? "徒手" : Equipment.allCases.filter { item.equipment.contains($0) }.map(\.name).joined(separator: "、")
        var parts = [item.movement.title, eq, item.loaded ? "負重" : "不負重"]
        if let low = item.low, let high = item.high {
            parts.append("\(low)–\(high) \(item.repUnit.label)")
        } else if item.repUnit == .seconds {
            parts.append("算秒數")
        }
        return parts.joined(separator: " · ")
    }

    private var fixedRange: Binding<Bool> {
        Binding(
            get: { item.low != nil && item.high != nil },
            set: { on in
                if on {
                    let seconds = item.repUnit == .seconds
                    item.low = seconds ? 30 : 8
                    item.high = seconds ? 60 : 12
                } else {
                    item.low = nil
                    item.high = nil
                }
            }
        )
    }

    private func equipmentBinding(_ eq: Equipment) -> Binding<Bool> {
        Binding(
            get: { item.requires.contains(eq.rawValue) },
            set: { on in
                item.requires.removeAll { $0 == eq.rawValue }
                if on { item.requires.append(eq.rawValue) }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("動作名稱，例如：啞鈴窄握臥推", text: $item.name)
                Picker("動作類型", selection: $item.pattern) {
                    ForEach(MovementPattern.allCases) { p in
                        Text(p.title).tag(p.rawValue)
                    }
                }
            } header: {
                SectionLabel("動作")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(Equipment.allCases) { eq in
                    Toggle(isOn: equipmentBinding(eq)) {
                        Label(eq.name, systemImage: eq.icon)
                    }
                }
            } header: {
                SectionLabel("需要的器材")
            } footer: {
                SectionLabel("都不勾 = 徒手，哪裡都能做。在家時缺了任何一項就不會排這個動作。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Toggle("有負重（進步時加重量）", isOn: $item.loaded)
                Picker("記錄方式", selection: $item.unit) {
                    Text("次數").tag(RepUnit.reps.rawValue)
                    Text("秒數").tag(RepUnit.seconds.rawValue)
                }
                .pickerStyle(.segmented)
                Toggle("固定次數範圍（不照課表）", isOn: fixedRange)
                if let low = item.low, let high = item.high {
                    let unit = item.repUnit.label
                    Stepper("最少 \(low) \(unit)", value: Binding(
                        get: { low },
                        set: { item.low = $0; if (item.high ?? 0) < $0 { item.high = $0 } }
                    ), in: 1...300)
                    Stepper("最多 \(high) \(unit)", value: Binding(
                        get: { high },
                        set: { item.high = max($0, item.low ?? 1) }
                    ), in: 1...300)
                }
            } header: {
                SectionLabel("怎麼記")
            } footer: {
                SectionLabel("有負重：每組都做到上限就建議加重。沒負重：達標就建議多做幾下。")
            }
            .listRowBackground(Theme.surface)

            Section {
                TextField("動作要點（選填）", text: $item.tip, axis: .vertical)
                    .lineLimit(2...5)
            } header: {
                SectionLabel("要點")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle(item.name.isEmpty ? "新的動作" : item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("儲存") {
                    item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(item)
                    dismiss()
                }
                .disabled(item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

// MARK: - 自訂課表

/// 設定 → 訓練課表。內建課表固定一份；自訂課表可以存好幾份，選一份來用。
struct ProgramListView: View {
    @AppStorage(Keys.customPrograms) private var raw = ""
    @AppStorage(Keys.activeProgram) private var activeId = ""
    @State private var openId: String?

    private var programs: [CustomProgram] {
        _ = raw
        return CustomPrograms.visible
    }

    var body: some View {
        Form {
            Section {
                choice(title: "內建課表", detail: "上下半身分化 · 每週 4 天", id: "", usable: true)
                ForEach(programs) { p in
                    choice(title: p.name.isEmpty ? "未命名課表" : p.name,
                           detail: p.usable ? "\(p.days.filter { !$0.slots.isEmpty }.count) 天" : "還沒有動作，不能用",
                           id: p.id, usable: p.usable)
                }
            } header: {
                SectionLabel("使用中")
            } footer: {
                SectionLabel("換課表不會刪除紀錄。自訂課表一樣有適應期、減量週、熱身和加重建議，只是動作和組數照你排的。")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(programs) { p in
                    NavigationLink(value: p.id) {
                        Text(p.name.isEmpty ? "未命名課表" : p.name).foregroundStyle(Theme.fg)
                    }
                }
                .onDelete { offsets in
                    let list = programs
                    for i in offsets { CustomPrograms.hide(list[i].id) }
                }
                Button("複製內建課表來改", systemImage: "doc.on.doc") {
                    let p = CustomPrograms.copyOfBuiltIn(name: "我的課表 \(programs.count + 1)")
                    CustomPrograms.upsert(p)
                    openId = p.id
                }
                Button("從空白開始", systemImage: "plus") {
                    let p = CustomPrograms.blank(name: "我的課表 \(programs.count + 1)")
                    CustomPrograms.upsert(p)
                    openId = p.id
                }
            } header: {
                SectionLabel("我的課表")
            } footer: {
                SectionLabel("建議從內建課表複製再改，比較不會漏練某個部位。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("訓練課表")
        .navigationDestination(for: String.self) { id in
            ProgramEditor(programId: id)
        }
        .navigationDestination(item: $openId) { id in
            ProgramEditor(programId: id)
        }
    }

    /// 正在用的：選到的自訂課表被刪掉或還是空的，就是內建。
    private var current: String {
        programs.first { $0.id == activeId && $0.usable }?.id ?? ""
    }

    private func choice(title: String, detail: String, id: String, usable: Bool) -> some View {
        Button {
            if usable { activeId = id }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                    Text(detail).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                if current == id {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                }
            }
        }
        .disabled(!usable)
    }
}

/// 一份自訂課表：名稱、哪幾天。改完立刻存。
struct ProgramEditor: View {
    let programId: String
    @State private var program: CustomProgram?

    var body: some View {
        Group {
            if let binding = Binding($program) {
                content(binding)
            } else {
                Text("找不到這份課表").foregroundStyle(Theme.muted)
            }
        }
        .themeForm()
        .onAppear {
            if program == nil { program = CustomPrograms.load().first { $0.id == programId } }
        }
        .onChange(of: program) { _, new in
            if let new { CustomPrograms.upsert(new) }
        }
    }

    private func content(_ p: Binding<CustomProgram>) -> some View {
        Form {
            Section {
                TextField("課表名稱", text: p.name)
            } header: {
                SectionLabel("名稱")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach(p.days) { $day in
                    NavigationLink {
                        DayEditor(day: $day)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.name.isEmpty ? "未命名" : day.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.fg)
                            Text(day.slots.isEmpty ? "還沒有動作" : "\(day.slots.count) 個動作 · \(day.slots.reduce(0) { $0 + $1.sets }) 組")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .onDelete { p.wrappedValue.days.remove(atOffsets: $0) }
                .onMove { p.wrappedValue.days.move(fromOffsets: $0, toOffset: $1) }
                if p.wrappedValue.days.count < 7 {
                    Button("新增一天", systemImage: "plus") {
                        let n = p.wrappedValue.days.count + 1
                        p.wrappedValue.days.append(CustomDay(id: CustomPrograms.newId(), name: "第 \(n) 天", focus: "", slots: []))
                    }
                }
            } header: {
                HStack {
                    SectionLabel("每天練什麼（依順序輪流）")
                    Spacer()
                    EditButton().font(.caption)
                }
            } footer: {
                SectionLabel("練完一天，下次就排下一天，做完最後一天再從頭。哪幾天練由自動排程決定，首頁也可以「換一天」。")
            }
            .listRowBackground(Theme.surface)

            volumeSection(p.wrappedValue)
        }
        .navigationTitle(p.wrappedValue.name.isEmpty ? "課表" : p.wrappedValue.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ProgramEditor {
    /// 每週組數：每一天各練一次，照每格填的組數和動作類型算（次要出力算半組）。只提醒，不會自動改。
    fileprivate func volumeSection(_ program: CustomProgram) -> some View {
        var slots: [(pattern: MovementPattern, sets: Int)] = []
        for day in program.days {
            for slot in day.slots { slots.append((pattern: slot.movement, sets: slot.sets)) }
        }
        let sets = VolumePlan.weekly(slots: slots)
        let advice = VolumePlan.advice(sets, upper: 20)
        return Section {
            VolumeTable(sets: sets, upper: 20)
            if advice.isEmpty {
                Text("每個部位都在建議範圍內。").font(.caption).foregroundStyle(Theme.green)
            } else {
                ForEach(advice, id: \.self) { line in
                    Text(line).font(.caption).foregroundStyle(Theme.hotText)
                }
            }
        } header: {
            HStack(spacing: 2) {
                SectionLabel("每週組數（每天各練一次）")
                InfoTip(item: .weeklySets)
            }
        } footer: {
            SectionLabel("只是提醒，不會自動改你的課表。低於下限或超過 20 組的部位會標色。")
        }
        .listRowBackground(Theme.surface)
    }
}

/// 自訂課表的一天：名稱、重點、動作清單。
struct DayEditor: View {
    @Binding var day: CustomDay
    @AppStorage(Keys.customExercises) private var exercisesRaw = ""

    var body: some View {
        Form {
            Section {
                TextField("名稱，例如：推日", text: $day.name)
                TextField("重點（選填），例如：胸、肩、三頭", text: $day.focus)
            } header: {
                SectionLabel("這一天")
            }
            .listRowBackground(Theme.surface)

            Section {
                ForEach($day.slots) { $slot in
                    let n = day.slots.firstIndex { $0.id == slot.id } ?? 0
                    NavigationLink {
                        SlotEditor(slot: $slot, previous: n > 0 ? day.slots[n - 1] : nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(SlotEditor.title(slot, raw: exercisesRaw))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.fg)
                            Text(SlotEditor.detail(slot))
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .onDelete { day.slots.remove(atOffsets: $0) }
                .onMove { day.slots.move(fromOffsets: $0, toOffset: $1) }
                Button("新增動作", systemImage: "plus") {
                    var slot = CustomSlot.blank()
                    if day.slots.isEmpty { slot.essential = true }
                    day.slots.append(slot)
                }
            } header: {
                HStack {
                    SectionLabel("動作（依順序做）")
                    Spacer()
                    EditButton().font(.caption)
                }
            } footer: {
                SectionLabel("「自動挑」會依你現在的器材挑這類動作，每 6 週換一批；「指定動作」固定做同一個，在家器材不夠時會自動換成同類動作。大動作排前面。單關節動作可以在動作裡設定「和上一個動作輪流做」（超級組）。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle(day.name.isEmpty ? "這一天" : day.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 一格：自動挑（動作類型）或指定動作，加上組數、次數、休息。
struct SlotEditor: View {
    @Binding var slot: CustomSlot
    /// 上一格（設定超級組用）
    var previous: CustomSlot? = nil
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.customExercises) private var exercisesRaw = ""

    static func title(_ slot: CustomSlot, raw: String) -> String {
        _ = raw
        if let id = slot.exerciseId, let ex = ExerciseLibrary.byId(id) { return ex.name }
        return "自動挑：" + slot.movement.title
    }

    static func detail(_ slot: CustomSlot) -> String {
        var parts = ["\(slot.sets) 組 × \(slot.low)–\(slot.high)", "休息 \(slot.rest) 秒"]
        if slot.essential { parts.append("精簡版也做") }
        if slot.linkPrev == true && slot.movement.region == nil { parts.append("和上一個輪流") }
        return parts.joined(separator: " · ")
    }

    private var fixed: Binding<Bool> {
        Binding(
            get: { slot.exerciseId != nil },
            set: { on in
                slot.exerciseId = on ? options.first?.id : nil
            }
        )
    }

    /// 這類動作全部（不管在家有沒有器材），內建的在前、自訂的在後。
    private var options: [Exercise] {
        _ = exercisesRaw
        return ExerciseLibrary.all.filter { $0.pattern == slot.movement }
    }

    private var home: Set<Equipment> { Equipment.parse(equipmentRaw) }

    var body: some View {
        Form {
            Section {
                Picker("動作類型", selection: Binding(
                    get: { slot.pattern },
                    set: { new in
                        slot.pattern = new
                        if slot.exerciseId != nil { slot.exerciseId = options.first?.id }
                    }
                )) {
                    ForEach(MovementPattern.allCases) { p in
                        Text(p.title).tag(p.rawValue)
                    }
                }
                Toggle("指定動作", isOn: fixed)
                if slot.exerciseId != nil {
                    Picker("動作", selection: Binding(
                        get: { slot.exerciseId ?? "" },
                        set: { slot.exerciseId = $0 }
                    )) {
                        ForEach(options) { ex in
                            let missing = !ex.requires.isSubset(of: home)
                            Text(ex.name + (ex.isCustom ? "（自訂）" : "") + (missing ? "（家裡沒器材）" : ""))
                                .tag(ex.id)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                SectionLabel("動作")
            } footer: {
                SectionLabel(slot.exerciseId == nil
                             ? "依你現在的器材自動挑這類動作，有負重的優先。"
                             : "標「家裡沒器材」的動作，在家時會自動換成同類動作，去健身房才會做。")
            }
            .listRowBackground(Theme.surface)

            Section {
                Stepper("\(slot.sets) 組", value: $slot.sets, in: 1...8)
                Stepper("最少 \(slot.low) 下", value: Binding(
                    get: { slot.low },
                    set: { slot.low = $0; if slot.high < $0 { slot.high = $0 } }
                ), in: 1...100)
                Stepper("最多 \(slot.high) 下", value: Binding(
                    get: { slot.high },
                    set: { slot.high = max($0, slot.low) }
                ), in: 1...100)
                Stepper("休息 \(slot.rest) 秒", value: $slot.rest, in: 0...300, step: 15)
                Toggle("精簡 20 分也要做", isOn: $slot.essential)
            } header: {
                SectionLabel("組數和次數")
            } footer: {
                SectionLabel("次數範圍用來判斷加重：每組都做到「最多」就建議加重。棒式這類算秒數的動作會用動作自己的範圍。適應期和減量週會自動少 1 組。精簡版休息最多 60 秒。")
            }
            .listRowBackground(Theme.surface)

            if let prev = previous {
                let ok = slot.movement.region == nil && prev.movement.region == nil
                Section {
                    Toggle("和上一個動作輪流做", isOn: Binding(
                        get: { ok && slot.linkPrev == true },
                        set: { slot.linkPrev = $0 }
                    ))
                    .disabled(!ok)
                } header: {
                    SectionLabel("超級組")
                } footer: {
                    SectionLabel(ok
                                 ? "和上一個動作（\(Self.title(prev, raw: exercisesRaw))）輪流做，一輪做完才休息；連續勾可以串成 3～4 個的循環組。休息用這組裡最長的。兩個動作會盡量分到不同器材。"
                                 : "只有單關節動作（手臂、肩膀、小腿、核心、腿彎舉、腿伸展）能輪流做，深蹲、臥推、划船這類大動作不配。")
                }
                .listRowBackground(Theme.surface)
            }
        }
        .themeForm()
        .navigationTitle(Self.title(slot, raw: exercisesRaw))
        .navigationBarTitleDisplayMode(.inline)
    }
}
