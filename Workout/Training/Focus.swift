import SwiftUI
import SwiftData

extension Keys {
    /// 重點部位（弱點加強），Muscle.rawValue 用逗號隔開，最多 2 個
    static let focusMuscles = "focusMuscles"
    /// 弱點分析卡片問過的區塊（同一個區塊不再問）
    static let focusAskedBlock = "focusAskedBlock"
    /// 手臂／肩膀專項期，JSON Specialization.State
    static let specialization = "specialization"
}

// MARK: - 弱點加強（0.27.0）

/// 弱點加強：使用者選的重點部位，每週多 2 組（一個部位一週練 2 次，等於每次 +1 組）。
/// 「哪裡長得慢」看重量進步（推估最大力量），不量圍度：比較每個部位最近 12 週的進步幅度，
/// 明顯落後其他部位的就是弱點，今天頁每個區塊問一次要不要列為重點。
enum Focus {
    /// 最多選幾個重點部位（再多就等於全部加，沒有重點）
    static let maxCount = 2
    /// 每個重點部位每週多幾組
    static let extraSets = 2
    /// 個人組數＋重點＋專項期＋中階加組，合計的範圍
    static let limits = -4...8
    /// 可以選的部位：主要部位＋後三角肌、小腿（腹肌、前三角肌、斜方肌被複合動作練得夠多）
    static let choices: [Muscle] = [.chest, .lats, .sideDelt, .rearDelt, .biceps, .triceps,
                                    .quads, .hamstrings, .glutes, .calves]
    /// 分析看最近幾週
    static let windowWeeks = 12
    /// 至少有幾個部位算得出進步，才比較得出誰落後
    static let minMeasured = 5
    /// 至少練了幾週（一週 2 次以上）才分析
    static let minTrainedWeeks = 6

    static var muscles: [Muscle] {
        let raw = UserDefaults.standard.string(forKey: Keys.focusMuscles) ?? ""
        return raw.split(separator: ",").compactMap { Muscle(rawValue: String($0)) }.filter { choices.contains($0) }
    }

    static func set(_ list: [Muscle]) {
        let unique = choices.filter { list.contains($0) }.prefix(maxCount)
        UserDefaults.standard.set(unique.map(\.rawValue).joined(separator: ","), forKey: Keys.focusMuscles)
    }

    static func toggle(_ m: Muscle) {
        var list = muscles
        if let i = list.firstIndex(of: m) { list.remove(at: i) }
        else if list.count < maxCount { list.append(m) }
        set(list)
    }

    /// 重點＋專項期，這週每個部位多（少）幾組（不含個人組數、中階加組）。
    static func extra(week: Int) -> [Muscle: Int] {
        var out: [Muscle: Int] = [:]
        for m in muscles { out[m, default: 0] += extraSets }
        if Specialization.active(week: week) {
            for (m, d) in Specialization.deltas { out[m, default: 0] += d }
        }
        return out
    }

    /// 給 `VolumePlan.balance` 的每週加減組數：個人組數＋中階加組＋重點＋專項期。
    static func offsets(week: Int) -> [Muscle: Int] {
        var out = Graduation.offsets(week: week)
        for (m, d) in extra(week: week) { out[m, default: 0] += d }
        for (m, v) in out { out[m] = min(limits.upperBound, max(limits.lowerBound, v)) }
        return out
    }

    /// 畫面上「你 +N」：個人組數＋重點＋專項期（這週）。
    static func displayOffset(_ m: Muscle) -> Int {
        let v = PersonalVolume.offset(m) + (extra(week: Plateau.currentWeek)[m] ?? 0)
        return min(limits.upperBound, max(limits.lowerBound, v))
    }

    // MARK: 分析

    struct Analysis {
        /// 每個部位的進步幅度（算得出來的才有）
        let gains: [Muscle: Double]
        /// 中位數
        let median: Double
        /// 明顯落後的部位，最慢的在前，最多 2 個
        let weak: [Muscle]
    }

    /// 最近 12 週（不含適應期、不含這週）每個部位的推估最大力量進步，和中位數比。
    /// 落後 = 不到中位數的一半，而且差 3 個百分點以上（大家都慢時不硬挑）。
    static func analyze(sessions: [WorkoutSession], week: Int) -> Analysis? {
        let raw = UserDefaults.standard.double(forKey: Keys.startDate)
        guard raw > 0 else { return nil }
        let start = Date(timeIntervalSince1970: raw)
        let from = PersonalVolume.weekStart(max(3, week - windowWeeks), start: start)
        let to = PersonalVolume.weekStart(week, start: start)
        guard to > from else { return nil }
        var gains: [Muscle: Double] = [:]
        for m in choices {
            if let g = PersonalVolume.gain(of: m, sessions: sessions, from: from, to: to) { gains[m] = g }
        }
        guard gains.count >= minMeasured else { return nil }
        let sorted = gains.values.sorted()
        let n = sorted.count
        let median = n % 2 == 1 ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2
        let weak = gains
            .filter { $0.value <= median / 2 && median - $0.value >= 0.03 }
            .sorted { $0.value < $1.value }
            .prefix(maxCount).map { $0.key }
        return Analysis(gains: gains, median: median, weak: Array(weak))
    }

    /// 今天頁要不要問「設為重點部位」：內建課表、進步週、每個區塊問一次、練夠久、有落後而且還不是重點。
    static func offer(week: Int, sessions: [WorkoutSession]) -> Analysis? {
        guard CustomPrograms.active == nil, ProgramBuilder.phase(week: week) == .normal else { return nil }
        let block = BlockClock.locate(week: week).block
        let d = UserDefaults.standard
        if d.object(forKey: Keys.focusAskedBlock) != nil, d.integer(forKey: Keys.focusAskedBlock) >= block { return nil }
        guard Graduation.trainedWeeks(sessions) >= minTrainedWeeks,
              let a = analyze(sessions: sessions, week: week), !a.weak.isEmpty,
              !Set(a.weak).isSubset(of: Set(muscles)) else { return nil }
        return a
    }

    static func markAsked(week: Int) {
        UserDefaults.standard.set(BlockClock.locate(week: week).block, forKey: Keys.focusAskedBlock)
    }
}

// MARK: - 手臂／肩膀專項期（0.27.0）

/// 一個完整區塊（進步週＋減量週）把手臂、肩膀練多一點，其他大部位降到維持量，總時間差不多。
/// - 下半身日多排手臂／肩膀的單關節動作，一週練到 4 次（頻率比組數更重要）。
/// - 側肩、後肩、二頭、三頭每週再 +2 組；胸、背闊、股四頭、大腿後側、臀每週 −2 組。
/// - 只用在內建課表；減量週照一般減量（不加）。結束後自動回到原本的排法，今天頁顯示這段的進步。
enum Specialization {
    static let muscles: [Muscle] = [.sideDelt, .rearDelt, .biceps, .triceps]
    static let deltas: [Muscle: Int] = [
        .sideDelt: 2, .rearDelt: 2, .biceps: 2, .triceps: 2,
        .chest: -2, .lats: -2, .quads: -2, .hamstrings: -2, .glutes: -2,
    ]

    /// 專項期加在各天的動作（放在核心之前）
    static func extraSlots(dayId: String) -> [Slot] {
        switch dayId {
        case "lowerA": [Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false),
                        Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false)]
        case "lowerB": [Slot(pattern: .rear, sets: 3, low: 12, high: 20, essential: false),
                        Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false)]
        case "fullA": [Slot(pattern: .triceps, sets: 2, low: 10, high: 15, essential: false)]
        case "fullB": [Slot(pattern: .biceps, sets: 2, low: 10, high: 15, essential: false)]
        case "fullC": [Slot(pattern: .lateral, sets: 3, low: 12, high: 20, essential: false)]
        default: []
        }
    }

    struct State: Codable {
        /// 哪個區塊（`BlockClock` 的 block）
        var block: Int
        /// 開始日（`Keys.startDate`），「從第 1 週重新開始」後失效
        var start: Double
        /// 結束卡片看過了
        var endSeen = false
    }

    static func load() -> State? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.specialization),
              let s = try? JSONDecoder().decode(State.self, from: Data(raw.utf8)),
              abs(s.start - UserDefaults.standard.double(forKey: Keys.startDate)) < 1 else { return nil }
        return s
    }

    private static func save(_ s: State?) {
        let d = UserDefaults.standard
        guard let s, let data = try? JSONEncoder().encode(s), let raw = String(data: data, encoding: .utf8) else {
            d.removeObject(forKey: Keys.specialization)
            return
        }
        d.set(raw, forKey: Keys.specialization)
    }

    enum Status: Equatable {
        case none
        /// 排好了，第幾週開始
        case scheduled(startWeek: Int)
        /// 進行中：第幾週／共幾個進步週，減量週是第幾週
        case running(weekInBlock: Int, normalWeeks: Int, deload: Int)
        /// 結束了，還沒看結果
        case ended(block: Int)
    }

    static func status(week: Int) -> Status {
        guard CustomPrograms.active == nil, let s = load() else { return .none }
        let loc = BlockClock.locate(week: week)
        if loc.block < s.block {
            var w = week
            while BlockClock.locate(week: w).block < s.block && w < week + 20 { w += 1 }
            return .scheduled(startWeek: w)
        }
        if loc.block == s.block {
            return .running(weekInBlock: loc.weekInBlock(week), normalWeeks: loc.deload - loc.start, deload: loc.deload)
        }
        return s.endSeen ? .none : .ended(block: s.block)
    }

    /// 這週有沒有加手臂／肩膀（減量週、適應期不加）。
    static func active(week: Int) -> Bool {
        guard CustomPrograms.active == nil, let s = load() else { return false }
        return BlockClock.locate(week: week).block == s.block && ProgramBuilder.phase(week: week) == .normal
    }

    /// 開始：這個區塊還在前 2 週（而且不是第一個區塊）就從這個區塊開始，不然從下個區塊開始，
    /// 才有完整的 4–5 個進步週。
    static func begin(week: Int) {
        let loc = BlockClock.locate(week: week)
        let now = loc.block >= 1 && loc.weekInBlock(week) <= 2 && ProgramBuilder.phase(week: week) == .normal
        save(State(block: now ? loc.block : loc.block + 1, start: UserDefaults.standard.double(forKey: Keys.startDate)))
    }

    static func cancel() { save(nil) }

    static func markEndSeen() {
        guard var s = load() else { return }
        s.endSeen = true
        save(s)
    }

    /// 課表加上專項期的動作（核心之前）。
    static func augment(_ days: [DayTemplate], week: Int) -> [DayTemplate] {
        guard active(week: week) else { return days }
        return days.map { day in
            let extra = extraSlots(dayId: day.id)
            guard !extra.isEmpty else { return day }
            var slots = day.slots
            let at = slots.firstIndex { $0.pattern == .core } ?? slots.count
            slots.insert(contentsOf: extra, at: at)
            return DayTemplate(id: day.id, name: day.name, focus: day.focus, variant: day.variant,
                               custom: day.custom, slots: slots)
        }
    }

    /// 專項期的成果：每個加強部位在專項期（不含減量週）和前一個區塊的進步，以及其他部位的中位數。
    struct Report {
        struct Row: Identifiable {
            let muscle: Muscle
            let gain: Double?
            let before: Double?
            var id: String { muscle.rawValue }
        }
        let rows: [Row]
        let othersMedian: Double?
    }

    static func report(block: Int, sessions: [WorkoutSession]) -> Report {
        let raw = UserDefaults.standard.double(forKey: Keys.startDate)
        let start = Date(timeIntervalSince1970: raw)
        // 找出這個區塊和前一個區塊的週
        var w = 1
        while BlockClock.locate(week: w).block < block && w < 600 { w += 1 }
        let loc = BlockClock.locate(week: w)
        let from = PersonalVolume.weekStart(loc.start, start: start)
        let to = PersonalVolume.weekStart(loc.deload, start: start)
        var beforeFrom: Date?
        if loc.start > 1 {
            let prev = BlockClock.locate(week: loc.start - 1)
            beforeFrom = PersonalVolume.weekStart(max(3, prev.start), start: start)
        }
        let beforeTo = PersonalVolume.weekStart(max(1, loc.start - 1), start: start)
        let rows = muscles.map { m in
            Report.Row(muscle: m,
                       gain: PersonalVolume.gain(of: m, sessions: sessions, from: from, to: to),
                       before: beforeFrom.flatMap { bf in
                           bf < beforeTo ? PersonalVolume.gain(of: m, sessions: sessions, from: bf, to: beforeTo) : nil
                       })
        }
        let others = Focus.choices.filter { !muscles.contains($0) }
            .compactMap { PersonalVolume.gain(of: $0, sessions: sessions, from: from, to: to) }.sorted()
        let median: Double? = others.isEmpty ? nil
            : (others.count % 2 == 1 ? others[others.count / 2]
               : (others[others.count / 2 - 1] + others[others.count / 2]) / 2)
        return Report(rows: rows, othersMedian: median)
    }
}

// MARK: - 今天頁的卡片

/// 弱點分析：每個區塊問一次要不要把進步最慢的部位列為重點。
struct FocusOfferCard: View {
    let analysis: Focus.Analysis
    let onFocus: () -> Void
    let canSpecialize: Bool
    let onSpecialize: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("有部位進步比較慢", systemImage: "scope")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Spacer()
                InfoTip(item: .focus)
            }
            let names = analysis.weak.map(\.name).joined(separator: "、")
            Text("最近 12 週的重量進步，\(names)明顯落後其他部位（中位數 \(PersonalVolume.percent(analysis.median))）。列為重點部位，每週各多練 \(Focus.extraSets) 組。")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            Text(analysis.weak.map { "\($0.name) \(PersonalVolume.percent(analysis.gains[$0] ?? 0))" }.joined(separator: "　"))
                .font(.caption).foregroundStyle(Theme.muted)
            HStack(spacing: 10) {
                Button(action: onFocus) { Text("設為重點") }
                    .buttonStyle(HotButtonStyle(height: 44))
                Button(action: onDismiss) {
                    Text("不用").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
                .frame(maxWidth: 90)
            }
            if canSpecialize {
                Button(action: onSpecialize) {
                    Label("改試手臂／肩膀專項期", systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
    }
}

/// 專項期排好／進行中的一行狀態。
struct SpecializationStatusRow: View {
    let status: Specialization.Status

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("手臂／肩膀專項期").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            InfoTip(item: .specialization)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.gold.opacity(0.45), lineWidth: 1))
    }

    private var detail: String {
        switch status {
        case .scheduled(let w): return "第 \(w) 週開始（下個區塊），從頭練完整的一段"
        case .running(let n, let total, let deload):
            return n > total ? "這週減量，練完就結束" : "第 \(n)／\(total) 週・第 \(deload) 週減量後結束"
        default: return ""
        }
    }
}

/// 專項期結束：這段的進步和前一個區塊比。
struct SpecializationEndCard: View {
    let report: Specialization.Report
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("手臂／肩膀專項期結束", systemImage: "flag.checkered")
                .font(.headline)
                .foregroundStyle(Theme.gold)
            Text("已經回到原本的排法。這段推估最大力量的進步（括號是前一個區塊）：")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            VStack(spacing: 6) {
                ForEach(report.rows) { r in
                    HStack {
                        Text(r.muscle.name).font(.subheadline).foregroundStyle(Theme.fg)
                        Spacer()
                        Text(r.gain.map(PersonalVolume.percent) ?? "紀錄太少")
                            .font(Theme.number(15))
                            .foregroundStyle(better(r) ? Theme.green : Theme.fg)
                        Text(r.before.map { "（\(PersonalVolume.percent($0))）" } ?? "（—）")
                            .font(.caption).foregroundStyle(Theme.muted)
                            .frame(minWidth: 64, alignment: .trailing)
                    }
                }
            }
            if let m = report.othersMedian {
                Text("其他部位這段的中位數：\(PersonalVolume.percent(m))。手臂、肩膀想再加強，隔一個區塊以上再開一次，關節比較吃得消。")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Button(action: onDone) { Text("好") }
                .buttonStyle(HotButtonStyle(height: 44))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
    }

    private func better(_ r: Specialization.Report.Row) -> Bool {
        guard let g = r.gain, let b = r.before else { return false }
        return g > b
    }
}

// MARK: - 設定頁

struct FocusSettingsView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.focusMuscles) private var focusRaw = ""
    @AppStorage(Keys.specialization) private var specRaw = ""
    @AppStorage(Keys.activeProgram) private var activeProgram = ""
    @AppStorage(Keys.deloadOverrides) private var deloadRaw = ""
    @State private var confirmCancel = false

    private var week: Int { Plateau.currentWeek }

    var body: some View {
        let _ = (focusRaw, specRaw, activeProgram, deloadRaw)
        let custom = CustomPrograms.active != nil
        let analysis = Focus.analyze(sessions: sessions, week: week)
        Form {
            if custom {
                Section {
                    Text("你現在用自訂課表。重點部位和專項期只會自動調整內建課表；自訂課表請自己在課表裡加組。")
                        .font(.subheadline).foregroundStyle(Theme.hotText)
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                ForEach(Focus.choices) { m in
                    let on = Focus.muscles.contains(m)
                    Button {
                        Focus.toggle(m)
                    } label: {
                        HStack {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Theme.accent : Theme.muted)
                            Text(m.name).foregroundStyle(Theme.fg)
                            if analysis?.weak.contains(m) == true { Tag(text: "落後") }
                            Spacer()
                            if let g = analysis?.gains[m] {
                                Text(PersonalVolume.percent(g)).font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!on && Focus.muscles.count >= Focus.maxCount)
                }
            } header: {
                SectionLabel("重點部位（最多 \(Focus.maxCount) 個）")
            } footer: {
                let note = analysis.map { a in
                    "右邊是最近 12 週推估最大力量的進步（中位數 \(PersonalVolume.percent(a.median))），標「落後」的是明顯比其他部位慢的。"
                } ?? "練滿幾週、每個部位都有幾次紀錄後，這裡會顯示各部位的進步，找出落後的。"
                SectionLabel(note + "每個重點部位每週多 \(Focus.extraSets) 組，加在練它的單關節動作上。")
            }
            .listRowBackground(Theme.surface)

            Section {
                switch Specialization.status(week: week) {
                case .none, .ended:
                    Button("開始專項期") { Specialization.begin(week: week) }
                        .disabled(custom)
                        .frame(minHeight: 44)
                case .scheduled, .running:
                    SpecializationStatusRow(status: Specialization.status(week: week))
                        .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                        .listRowBackground(Color.clear)
                    Button("取消專項期") { confirmCancel = true }
                        .foregroundStyle(Theme.hotText)
                        .frame(minHeight: 44)
                }
            } header: {
                SectionLabel("手臂／肩膀專項期")
            } footer: {
                SectionLabel("一個完整區塊（約 5 個進步週＋減量週）：下半身日多排側平舉、後肩、二頭、三頭，手臂和肩膀一週練到 4 次、每週再多 2 組；胸、背、腿每週少 2 組，維持就好，總時間差不多。這個區塊才剛開始就從現在開始，不然從下個區塊開始。結束後自動回到原本的排法，今天頁會顯示這段的進步。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("重點部位")
        .confirmationDialog("取消專項期？", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("取消專項期", role: .destructive) { Specialization.cancel() }
        } message: {
            Text("馬上回到原本的排法。")
        }
    }
}
