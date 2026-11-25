import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 排課檢查（第二意見）

/// 檢查找到的一個問題。數字全部由程式算好，AI 只負責轉成白話。
struct PlanFinding: Identifiable, Equatable {
    enum Level: Equatable {
        /// 注意：建議處理
        case warn
        /// 建議：參考就好
        case tip

        var title: String { self == .warn ? "注意" : "建議" }
    }

    /// 同一類最多留 2 條
    enum Category: String {
        case time, volume, recovery, pattern, joint, week, deload, equipment, superset
    }

    let level: Level
    let category: Category
    let title: String
    let detail: String

    var id: String { category.rawValue + "|" + title }

    init(level: Level, category: Category, title: String, detail: String) {
        self.level = level
        self.category = category
        self.title = title
        self.detail = detail
    }
}

/// 排好今天的課之後，用另一套規則從結果和紀錄重新算一遍，找不合理的地方。
/// 只提醒，不改課表；不呼叫排課本身的決策（只讀它的結果）。
enum PlanCheck {
    /// 時間超過目標這個倍數才提醒
    static let timeLimitFactor = 1.25
    /// 單日同一部位的正式組上限
    static let maxDailySets = 10
    /// 恢復衝突：各部位看自己的 `Muscle.recoveryHours` 內有沒有練過（0.54.0 起，原本固定 48 小時）。
    static var longestRecovery: Double { Muscle.allCases.map(\.recoveryHours).max() ?? 72 }
    static let maxPerCategory = 2
    static let maxTotal = 5

    /// 這個長度的目標分鐘（完整約 60 分、精簡約 20 分）；只做 1 組不檢查。
    static func targetMinutes(_ length: WorkoutLength) -> Int? {
        switch length {
        case .full: return 60
        case .short: return 20
        case .minimal: return nil
        }
    }

    static func run(plan: [PlannedExercise], day: DayTemplate, length: WorkoutLength, phase: Phase,
                    sessions: [WorkoutSession], minutes: Int, equipment: Set<Equipment>,
                    now: Date = .now,
                    feedback: [MuscleFeedback] = PersonalVolume.feedback(),
                    painLog: [PainRecord] = Avoid.painLog(),
                    marked: [String: AvoidEntry] = Avoid.store.load()) -> [PlanFinding] {
        guard length != .minimal, !plan.isEmpty else { return [] }
        var out: [PlanFinding] = []
        out += timeFindings(minutes: minutes, length: length)
        out += dailyVolumeFindings(plan: plan)
        out += recoveryFindings(plan: plan, sessions: sessions, feedback: feedback, now: now)
        out += patternFindings(plan: plan)
        out += jointFindings(plan: plan, painLog: painLog, marked: marked, now: now)
        out += weeklyFindings(plan: plan, sessions: sessions, now: now)
        out += deloadFindings(plan: plan, day: day, length: length, phase: phase)
        out += equipmentFindings(plan: plan, equipment: equipment)
        out += supersetFindings(plan: plan)
        return finalize(out)
    }

    /// 注意在前；同一類最多 2 條；總共最多 5 條。同級照規則順序。
    static func finalize(_ all: [PlanFinding]) -> [PlanFinding] {
        let indexed = Array(all.enumerated())
        let sorted = indexed.sorted { a, b in
            let la = a.element.level == .warn ? 0 : 1
            let lb = b.element.level == .warn ? 0 : 1
            return la != lb ? la < lb : a.offset < b.offset
        }
        var perCategory: [PlanFinding.Category: Int] = [:]
        var out: [PlanFinding] = []
        for (_, f) in sorted {
            if perCategory[f.category, default: 0] >= maxPerCategory { continue }
            perCategory[f.category, default: 0] += 1
            out.append(f)
            if out.count >= maxTotal { break }
        }
        return out
    }

    // MARK: 1. 時間

    private static func timeFindings(minutes: Int, length: WorkoutLength) -> [PlanFinding] {
        guard let target = targetMinutes(length), Double(minutes) > Double(target) * timeLimitFactor else { return [] }
        return [PlanFinding(level: .warn, category: .time, title: "預估時間偏長",
                            detail: "預估要 \(minutes) 分鐘，比這個長度的目標 \(target) 分鐘多了 \(minutes - target) 分鐘。")]
    }

    // MARK: 2. 單日同部位太多

    private static func dailyVolumeFindings(plan: [PlannedExercise]) -> [PlanFinding] {
        var sets: [Muscle: Int] = [:]
        for item in plan {
            for m in VolumePlan.primaryMuscles(item.exercise.pattern) { sets[m, default: 0] += item.sets }
        }
        let over = sets.filter { $0.value > maxDailySets }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
        var out: [PlanFinding] = []
        for entry in over {
            out.append(PlanFinding(level: .tip, category: .volume, title: "\(entry.key.name)今天排很多",
                                   detail: "今天\(entry.key.name)排了 \(entry.value) 組，超過單日 \(maxDailySets) 組，後面幾組品質可能下降。"))
        }
        return out
    }

    // MARK: 3. 恢復衝突

    /// 這次紀錄的次數下限：動作自己有範圍就用它，不然看當時那一天課表同類型的格子。
    private static func lowTarget(_ ex: Exercise, dayKey: String) -> Int? {
        if let r = ex.range { return r.lowerBound }
        guard let t = ProgramBuilder.template(id: dayKey),
              let slot = t.slots.first(where: { $0.pattern == ex.pattern }) else { return nil }
        return slot.low
    }

    private static func recoveryFindings(plan: [PlannedExercise], sessions: [WorkoutSession],
                                         feedback: [MuscleFeedback], now: Date) -> [PlanFinding] {
        let since = now.addingTimeInterval(-longestRecovery * 3600)
        func within(_ m: Muscle, _ date: Date) -> Bool { now.timeIntervalSince(date) <= m.recoveryHours * 3600 }
        var missed = Set<Muscle>()
        for s in sessions where s.date >= since && s.date < now {
            for e in s.entries where e.isWork {
                guard let ex = ExerciseLibrary.byId(e.exerciseId),
                      let low = lowTarget(ex, dayKey: s.dayKey), e.reps < low else { continue }
                missed.formUnion(VolumePlan.primaryMuscles(ex.pattern).filter { within($0, s.date) })
            }
        }
        var sore = Set<Muscle>()
        for f in feedback where f.recovery == Recovery.sore.rawValue && f.date >= since.timeIntervalSince1970
            && f.date <= now.timeIntervalSince1970 {
            if let m = Muscle(rawValue: f.muscle), within(m, Date(timeIntervalSince1970: f.date)) { sore.insert(m) }
        }
        let tired = missed.union(sore)
        guard !tired.isEmpty else { return [] }

        var out: [PlanFinding] = []
        for m in Muscle.ordered where tired.contains(m) {
            let names = plan.filter { $0.essential && VolumePlan.primaryMuscles($0.exercise.pattern).contains(m) }
                .map(\.exercise.name)
            guard !names.isEmpty else { continue }
            let why = missed.contains(m) ? "有沒做到次數的組" : "回報還在痠"
            out.append(PlanFinding(level: .warn, category: .recovery, title: "\(m.name)還沒恢復",
                                   detail: "\(Int(m.recoveryHours)) 小時內練過\(m.name)，\(why)，今天又排了\(names.prefix(2).joined(separator: "、"))。"))
        }
        return out
    }

    // MARK: 4. 同天重複動作類型

    private static func patternFindings(plan: [PlannedExercise]) -> [PlanFinding] {
        var order: [MovementPattern] = []
        var names: [MovementPattern: [String]] = [:]
        for item in plan {
            let p = item.exercise.pattern
            if names[p] == nil { order.append(p) }
            names[p, default: []].append(item.exercise.name)
        }
        return order.compactMap { p in
            guard let list = names[p], list.count >= 2 else { return nil }
            return PlanFinding(level: .tip, category: .pattern, title: "有兩個很像的動作",
                               detail: "\(list.prefix(2).joined(separator: "和"))都是「\(p.title)」，今天做了 \(list.count) 個同類型動作。")
        }
    }

    // MARK: 5. 關節

    private static func jointFindings(plan: [PlannedExercise], painLog: [PainRecord],
                                      marked: [String: AvoidEntry], now: Date) -> [PlanFinding] {
        let from = now.addingTimeInterval(-14 * 86400).timeIntervalSince1970
        var painful = Set(painLog.filter { $0.date >= from }.map(\.exerciseId))
        for (id, e) in marked where e.kind == .pain && e.date >= from { painful.insert(id) }

        var out: [PlanFinding] = []
        for item in plan where painful.contains(item.exercise.id) {
            out.append(PlanFinding(level: .warn, category: .joint, title: "排了會痛的動作",
                                   detail: "「\(item.exercise.name)」14 天內回報過會痛，今天還排著。"))
        }
        let pain = Joint.recentPain(now: now, log: painLog, marked: marked)
        var seen = Set<Joint>()
        for item in plan where !painful.contains(item.exercise.id) {
            for j in Joint.involved(item.exercise.pattern) {
                guard let name = pain[j], name != item.exercise.name, !seen.contains(j) else { continue }
                seen.insert(j)
                out.append(PlanFinding(level: .warn, category: .joint, title: "\(j.title)最近不舒服",
                                       detail: "14 天內「\(name)」\(j.title)會痛，今天的「\(item.exercise.name)」也會用到\(j.title)。"))
            }
        }
        return out
    }

    // MARK: 6. 本週組數、減量週

    private static func fmt(_ v: Double) -> String { Progression.format(v) }

    private static func weeklyFindings(plan: [PlannedExercise], sessions: [WorkoutSession], now: Date) -> [PlanFinding] {
        let done = MuscleStats.weeklySets(sessions, weekOf: now)
        let today = VolumePlan.weekly(plans: [plan])
        struct Row { let muscle: Muscle; let done: Double; let today: Double; let total: Double; let upper: Double }
        var rows: [Row] = []
        for m in VolumePlan.targeted {
            guard let range = VolumePlan.range(for: m), let t = today[m], t > 0 else { continue }
            let d = done[m] ?? 0
            if d + t > range.upperBound {
                rows.append(Row(muscle: m, done: d, today: t, total: d + t, upper: range.upperBound))
            }
        }
        rows.sort { ($0.total - $0.upper) > ($1.total - $1.upper) }
        var out: [PlanFinding] = []
        for r in rows {
            out.append(PlanFinding(level: .tip, category: .week, title: "\(r.muscle.name)本週偏多",
                                   detail: "這週\(r.muscle.name)已練 \(fmt(r.done)) 組，加上今天 \(fmt(r.today)) 組共 \(fmt(r.total)) 組，超過每週 \(fmt(r.upper)) 組的上限。"))
        }
        return out
    }

    private static func deloadFindings(plan: [PlannedExercise], day: DayTemplate, length: WorkoutLength,
                                       phase: Phase) -> [PlanFinding] {
        guard phase == .deload else { return [] }
        var bad: [String] = []
        for item in plan {
            guard let slot = day.slots.first(where: { $0.pattern == item.exercise.pattern }) else { continue }
            let normal = ProgramBuilder.slotSets(slot, day: day, phase: .normal, length: length,
                                                 extra: JumpGuard.hasExtraSet(item.exercise.id))
            if item.sets > (normal + 1) / 2 { bad.append("\(item.exercise.name)（\(item.sets) 組，正常 \(normal) 組）") }
        }
        guard !bad.isEmpty else { return [] }
        return [PlanFinding(level: .warn, category: .deload, title: "減量週組數沒減",
                            detail: "減量週組數要減半，但\(bad.prefix(2).joined(separator: "、"))沒有減到一半。")]
    }

    // MARK: 7. 器材

    private static func equipmentFindings(plan: [PlannedExercise], equipment: Set<Equipment>) -> [PlanFinding] {
        let bad = plan.filter { !$0.exercise.requires.isSubset(of: equipment) }
        guard !bad.isEmpty else { return [] }
        let names = bad.prefix(2).map(\.exercise.name).joined(separator: "、")
        return [PlanFinding(level: .warn, category: .equipment, title: "器材不符",
                            detail: "目前勾選的器材做不了：\(names)，共 \(bad.count) 個動作，請到設定確認器材。")]
    }

    // MARK: 8. 超級組

    private static func supersetFindings(plan: [PlannedExercise]) -> [PlanFinding] {
        var groups: [Int: [PlannedExercise]] = [:]
        var order: [Int] = []
        for item in plan {
            guard let g = item.group else { continue }
            if groups[g] == nil { order.append(g) }
            groups[g, default: []].append(item)
        }
        var out: [PlanFinding] = []
        for g in order {
            let items = groups[g] ?? []
            var found: PlanFinding?
            outer: for i in items.indices {
                for j in items.indices where j > i {
                    let a = items[i], b = items[j]
                    if let shared = sharedEquipment(a, b) {
                        found = PlanFinding(level: .tip, category: .superset, title: "超級組共用器材",
                                            detail: "「\(a.exercise.name)」和「\(b.exercise.name)」排在同一組超級組，都要用\(shared)，輪流做會一直換。")
                        break outer
                    }
                    let same = VolumePlan.primaryMuscles(a.exercise.pattern).intersection(VolumePlan.primaryMuscles(b.exercise.pattern))
                    if let m = Muscle.ordered.first(where: { same.contains($0) }) {
                        found = PlanFinding(level: .tip, category: .superset, title: "超級組練同一部位",
                                            detail: "「\(a.exercise.name)」和「\(b.exercise.name)」排在同一組超級組，主要都練\(m.name)，中間幾乎沒有休息。")
                        break outer
                    }
                }
            }
            if let f = found { out.append(f) }
        }
        return out
    }

    /// 兩個動作共用的器材名稱；沒有共用就是 nil。啞鈴和椅子很常一起用，不算；
    /// 兩個都用啞鈴時，看排課有沒有標示共用同一組。
    private static func sharedEquipment(_ a: PlannedExercise, _ b: PlannedExercise) -> String? {
        let common = a.exercise.requires.intersection(b.exercise.requires).subtracting([.dumbbell, .bench])
        if let e = Equipment.allCases.first(where: { common.contains($0) }) { return e.name }
        if a.exercise.requires.contains(.dumbbell), b.exercise.requires.contains(.dumbbell) {
            let sameKit = a.kit != nil && a.kit == b.kit
            if sameKit || a.sharedKit != nil || b.sharedKit != nil { return Equipment.dumbbell.name }
        }
        return nil
    }
}

// MARK: - AI 白話說明

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct PlanCheckSummaryAI {
    @Guide(description: "一段話，160 個字以內，把檢查發現的問題講成白話，只能轉述資料")
    var summary: String
}
#endif

enum PlanCheckAI {
    static let maxLength = 160

    static let instructions = """
    你是健身 App「練壯」裡的教練，要把排課檢查找到的問題轉成一小段白話提醒。
    規則：
    - 只能轉述提供的檢查結果，不可以自己加任何數字、組數、重量或時間。
    - 不要建議換成別的動作，也不要建議改課表；最多提醒使用者可以自己決定。
    - 不要給醫療建議；提到痛的時候只說先輕一點、會痛就停。
    - 使用台灣的繁體中文，語氣像朋友，不要用表情符號。
    """

    /// 給模型的資料（驗證數字也用這份）。
    static func prompt(findings: [PlanFinding], plan: [PlannedExercise]) -> String {
        var lines = ["今天的動作："]
        lines += plan.map { "- \($0.exercise.name)：\($0.sets) 組" }
        lines.append("檢查結果：")
        lines += findings.map { "- [\($0.level.title)] \($0.title)：\($0.detail)" }
        return lines.joined(separator: "\n")
    }

    /// 沒有 AI 或 AI 失敗時的整理：直接用規則寫的標題。
    static func basicSummary(_ findings: [PlanFinding]) -> String {
        let warn = findings.filter { $0.level == .warn }.count
        let tip = findings.count - warn
        var parts: [String] = []
        if warn > 0 { parts.append("\(warn) 點要注意") }
        if tip > 0 { parts.append("\(tip) 點建議參考") }
        return "排課檢查找到" + parts.joined(separator: "、") + "：" + findings.map(\.title).joined(separator: "、") + "。"
    }

    /// 模型寫的內容：數字都要在資料裡出現過、不能有簡體字、長度有限。
    static func isValid(_ text: String, source: String) -> Bool {
        Coach.isValid(text: text, source: source, maxLength: maxLength)
    }

    /// 產生說明；沒有 AI、沒有問題、或兩次都不合格就回傳 nil（改用規則文字）。
    static func summarize(findings: [PlanFinding], plan: [PlannedExercise]) async -> String? {
        guard !findings.isEmpty else { return nil }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), CoachAI.status == .ready {
            let source = prompt(findings: findings, plan: plan)
            for _ in 0..<2 {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let res = try await session.respond(to: source, generating: PlanCheckSummaryAI.self,
                                                        options: GenerationOptions(temperature: 0.4))
                    let text = res.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                    if isValid(text, source: source) { return text }
                } catch {
                    // 安全過濾、超出長度等：再試一次，還是不行就用規則文字
                }
            }
        }
        #endif
        return nil
    }
}

// MARK: - 畫面

/// 主卡下面的一小列。
struct PlanCheckRow: View {
    let findings: [PlanFinding]
    let action: () -> Void

    private var hasWarn: Bool { findings.contains { $0.level == .warn } }

    private var label: String {
        if findings.isEmpty { return "排課檢查 ✓ 沒發現問題" }
        return "排課檢查：\(findings.count) 點"
    }

    private var color: Color {
        if findings.isEmpty { return Theme.muted }
        return hasWarn ? Theme.hotText : Theme.accentSoft
    }

    private var icon: String {
        if findings.isEmpty { return "checkmark.circle" }
        return hasWarn ? "exclamationmark.triangle.fill" : "lightbulb"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(hasWarn ? Theme.hotLine : Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(findings.isEmpty ? "排課檢查，沒發現問題"
                            : "排課檢查，\(findings.count) 點提醒\(hasWarn ? "，有需要注意的" : "")，點兩下查看")
    }
}

/// 打開才讓 AI 寫說明（`.task`），畫面重繪不會重跑。
struct PlanCheckSheet: View {
    let findings: [PlanFinding]
    let plan: [PlannedExercise]
    @State private var aiText: String?
    @State private var loading = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if findings.isEmpty {
                        Text("今天的課表沒發現問題。")
                            .font(.subheadline).foregroundStyle(Theme.fg)
                            .themeCard()
                    } else {
                        summaryCard
                        VStack(spacing: 0) {
                            ForEach(Array(findings.enumerated()), id: \.element.id) { i, f in
                                if i > 0 { Divider().overlay(Theme.divider) }
                                row(f)
                            }
                        }
                        .themeCard(padding: 4)
                    }
                    Text("只是提醒，不會自動改課表；要換動作用「換一個動作」。")
                        .font(.footnote).foregroundStyle(Theme.muted)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .themeScreen()
            .navigationTitle("排課檢查")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .task {
            guard aiText == nil, !findings.isEmpty else { return }
            loading = true
            aiText = await PlanCheckAI.summarize(findings: findings, plan: plan)
            loading = false
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(aiText != nil ? "Apple Intelligence 整理" : "自動整理")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
            if let aiText {
                Text(aiText).font(.subheadline).foregroundStyle(Theme.fg)
            } else if loading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("整理中⋯").font(.subheadline).foregroundStyle(Theme.muted)
                }
            } else {
                Text(PlanCheckAI.basicSummary(findings)).font(.subheadline).foregroundStyle(Theme.fg)
            }
        }
        .themeCard()
    }

    private func row(_ f: PlanFinding) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: f.level == .warn ? "exclamationmark.triangle.fill" : "lightbulb")
                .foregroundStyle(f.level == .warn ? Theme.hotText : Theme.accentSoft)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(f.title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text(f.detail).font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(f.level.title)：\(f.title)。\(f.detail)")
    }
}
