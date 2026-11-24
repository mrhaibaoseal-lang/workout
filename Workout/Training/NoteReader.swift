import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// 看懂備註（0.37.0，規格 docs/note-reader.md）：
// 模型（或規則）只負責把備註分類成 NoteFinding，怎麼調整由程式決定，使用者按了才生效。

extension Keys {
    /// 備註推出來的「下次調整」，JSON [exerciseId: NoteNudge]。21 天沒用到就失效。
    static let noteNudges = "workout.noteNudges"
    /// 備註推出來的「下次提醒我」，JSON [exerciseId: NoteReminder]。使用者按 ✕ 才刪。
    static let noteReminders = "workout.noteReminders"
}

// MARK: - 結果

enum NoteKind: String, CaseIterable {
    case pain, tooLight, tooHeavy, sideWeak, gear
}

struct NoteFinding: Equatable, Identifiable {
    let kind: NoteKind
    var exerciseId: String? = nil
    /// pain：哪個關節（看不出來就 nil）
    var joint: Joint? = nil
    /// sideWeak：手或腳
    var limb: Limb? = nil
    /// sideWeak：左或右（只會是 .left／.right）
    var side: WeakSide? = nil
    /// gear：20 字以內的摘要
    var summary: String = ""

    var id: String { [kind.rawValue, exerciseId ?? "", limb?.rawValue ?? ""].joined(separator: "|") }
}

// MARK: - 輸入

struct NoteInput {
    struct Item: Equatable {
        let id: String
        let name: String
        let loaded: Bool
        /// 這個動作算手還是腳（沒寫部位的左右差用它推斷）
        let limb: Limb

        init(id: String, name: String, loaded: Bool, limb: Limb) {
            self.id = id; self.name = name; self.loaded = loaded; self.limb = limb
        }

        init(_ ex: Exercise) {
            self.init(id: ex.id, name: ex.name, loaded: ex.loaded, limb: Limb.of(ex))
        }
    }

    /// 今天做過的動作（依訓練順序）
    var items: [Item]
    /// exerciseId → 這次的備註
    var notes: [String: String]
    var sessionNote: String

    /// 有任何一則有內容的備註
    var hasNotes: Bool {
        let clean: (String) -> Bool = { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return notes.values.contains(where: clean) || clean(sessionNote)
    }

    /// 給模型看的文字
    var prompt: String {
        var lines = ["今天做過的動作（id｜名稱｜是否有重量）："]
        lines += items.map { "- \($0.id)｜\($0.name)｜\($0.loaded ? "有重量" : "徒手")" }
        lines.append("各動作的備註：")
        for item in items {
            if let n = notes[item.id], !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("- \(item.id)：「\(n)」")
            }
        }
        let s = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { lines.append("整次訓練的備註：「\(s)」") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 規則版

enum NoteReader {
    /// 模型回傳的原始內容（全部是字串，驗證後才變成 `NoteFinding`）
    struct Raw {
        var kind: String
        var exerciseId: String = ""
        var joint: String = ""
        var limb: String = ""
        var side: String = ""
        var summary: String = ""
    }

    static let maxSummary = 20

    // 否定：先把這些片段拿掉，再找關鍵字。
    private static let negations = [
        "(?:不會|沒有|沒|並不|不太|不)(?:再)?(?:痛|刺痛|不舒服|卡卡)",
        "(?:不會|沒有|沒|並不|不太|不算|沒那麼|不覺得|不)(?:太|很|那麼|會)?(?:重|輕鬆|輕|簡單)",
        "(?:不會|沒有|沒|不)(?:再)?(?:抖|弱|沒力|晃|滑|鬆掉|卡住)",
    ]

    private static let painWords = ["刺痛", "痛", "不舒服", "卡卡"]
    private static let jointWords: [(Joint, [String])] = [
        (.shoulder, ["肩"]), (.elbow, ["肘"]), (.lowerBack, ["下背", "腰"]), (.knee, ["膝"]), (.hip, ["髖", "屁股側"]),
    ]
    private static let lightWords = ["太輕", "很輕鬆", "太簡單", "還能加", "可以再重"]
    private static let heavyWords = ["太重", "做不動", "做不完", "撐不住", "力竭太早"]
    private static let sideWeakWords = ["抖", "弱", "沒力", "先沒", "做不動", "跟不上", "比較差"]
    private static let armWords = ["手", "臂", "肩", "彎舉", "推"]
    private static let legWords = ["腳", "腿", "膝", "臀"]
    private static let gearWords = ["椅", "晃", "握不住", "滑", "卡住", "槓片", "快鎖", "鬆掉", "角度", "調第"]

    /// 規則版：沒有 AI、或 AI 失敗時用。`currentWeak` 讓測試不用碰 UserDefaults。
    static func rules(_ input: NoteInput, currentWeak: (Limb) -> WeakSide = { SideBalance.weak($0) }) -> [NoteFinding] {
        var raw: [NoteFinding] = []

        // 一段文字 + 它屬於哪個動作（可能沒有）
        var pieces: [(text: String, item: NoteInput.Item?)] = []
        for item in input.items {
            if let n = input.notes[item.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
                pieces.append((n, item))
            }
        }
        // 整次備註：一句一句看，有提到今天某個動作的名字才算那個動作的
        for clause in clauses(input.sessionNote) {
            pieces.append((clause, input.items.first { clause.contains($0.name) }))
        }

        for piece in pieces { raw += analyze(piece.text, item: piece.item) }
        return finalize(raw, input: input, currentWeak: currentWeak)
    }

    private static func analyze(_ original: String, item: NoteInput.Item?) -> [NoteFinding] {
        let text = strip(original)
        let chars = Array(text)
        var out: [NoteFinding] = []

        // 左右差：一句一句看，部位才不會跟別句混在一起
        var heavyText = ""
        for clause in clauses(text) {
            if let (limb, side) = sideWeak(in: clause, item: item) {
                out.append(NoteFinding(kind: .sideWeak, exerciseId: item?.id, limb: limb, side: side))
                // 「左手做不動」是左右差，不是太重
                heavyText += clause.replacingOccurrences(of: "做不動", with: "")
            } else {
                heavyText += clause
            }
            heavyText += "，"
        }

        guard let item else { return out }

        if let at = painWords.compactMap({ positions(of: $0, in: chars).first }).min() {
            out.append(NoteFinding(kind: .pain, exerciseId: item.id, joint: nearestJoint(to: at, in: chars)))
        }
        if lightWords.contains(where: { text.contains($0) }) {
            out.append(NoteFinding(kind: .tooLight, exerciseId: item.id))
        }
        if heavyWords.contains(where: { heavyText.contains($0) }) {
            out.append(NoteFinding(kind: .tooHeavy, exerciseId: item.id))
        }
        if gearWords.contains(where: { text.contains($0) }) {
            let s = original.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(NoteFinding(kind: .gear, exerciseId: item.id, summary: String(s.prefix(maxSummary))))
        }
        return out
    }

    /// 左／右後面 6 個字內有「抖、弱…」；部位看同一句裡離它最近的詞，沒寫就用動作的手／腳。
    private static func sideWeak(in clause: String, item: NoteInput.Item?) -> (Limb, WeakSide)? {
        let chars = Array(clause)
        var sides = Set<WeakSide>()
        var firstAt: Int?
        for (i, ch) in chars.enumerated() where ch == "左" || ch == "右" {
            // 「左右」兩個字連在一起是「兩邊」，不算
            if ch == "左", i + 1 < chars.count, chars[i + 1] == "右" { continue }
            if ch == "右", i > 0, chars[i - 1] == "左" { continue }
            let window = String(chars[(i + 1)..<min(chars.count, i + 7)])
            guard sideWeakWords.contains(where: { window.contains($0) }) else { continue }
            sides.insert(ch == "左" ? .left : .right)
            if firstAt == nil { firstAt = i }
        }
        // 兩邊都說弱就看不出是哪邊
        guard sides.count == 1, let side = sides.first, let at = firstAt else { return nil }

        func nearest(_ words: [String]) -> Int? {
            words.flatMap { positions(of: $0, in: chars) }.map { abs($0 - at) }.min()
        }
        let limb: Limb
        switch (nearest(armWords), nearest(legWords)) {
        case let (a?, l?): limb = a <= l ? .arm : .leg
        case (.some, nil): limb = .arm
        case (nil, .some): limb = .leg
        case (nil, nil):
            guard let item else { return nil }
            limb = item.limb
        }
        return (limb, side)
    }

    // MARK: 共用的整理（規則版和 AI 版都走這裡）

    /// 去掉不合規則的、重複的；太輕和太重同時出現就都不列；已經設成同一邊弱的左右差不列。
    static func finalize(_ raw: [NoteFinding], input: NoteInput,
                         currentWeak: (Limb) -> WeakSide = { SideBalance.weak($0) }) -> [NoteFinding] {
        let byId = Dictionary(input.items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        var list: [NoteFinding] = []
        for f in raw {
            switch f.kind {
            case .pain, .gear:
                guard let id = f.exerciseId, byId[id] != nil else { continue }
            case .tooLight, .tooHeavy:
                guard let id = f.exerciseId, byId[id]?.loaded == true else { continue }
            case .sideWeak:
                guard let limb = f.limb, let side = f.side, side == .left || side == .right else { continue }
                if let id = f.exerciseId, byId[id] == nil { continue }
                if currentWeak(limb) == side { continue }
            }
            // 同一個動作同一種 kind 只留一筆；左右差是整體設定，同一隻手／腳同一邊也只留一筆
            let key = f.kind == .sideWeak ? "side|\(f.limb?.rawValue ?? "")|\(f.side?.rawValue ?? "")" : f.id
            guard seen.insert(key).inserted else { continue }
            list.append(f)
        }
        // 太輕和太重同時出現：看不出來該往哪邊調，兩個都不列
        let conflict = Set(list.filter { $0.kind == .tooLight }.compactMap(\.exerciseId))
            .intersection(Set(list.filter { $0.kind == .tooHeavy }.compactMap(\.exerciseId)))
        list.removeAll { ($0.kind == .tooLight || $0.kind == .tooHeavy) && conflict.contains($0.exerciseId ?? "") }
        // 同一隻手／腳兩邊都被說弱：看不出是哪邊，都不列
        let bothSides = Dictionary(grouping: list.filter { $0.kind == .sideWeak }, by: { $0.limb! }).filter { $0.value.count > 1 }.keys
        list.removeAll { $0.kind == .sideWeak && bothSides.contains($0.limb!) }

        let order = Dictionary(input.items.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { a, _ in a })
        let kinds = NoteKind.allCases
        return list.enumerated().sorted { a, b in
            let ia = a.element.exerciseId.flatMap { order[$0] } ?? Int.max
            let ib = b.element.exerciseId.flatMap { order[$0] } ?? Int.max
            if ia != ib { return ia < ib }
            let ka = kinds.firstIndex(of: a.element.kind) ?? 0, kb = kinds.firstIndex(of: b.element.kind) ?? 0
            return ka != kb ? ka < kb : a.offset < b.offset
        }.map { $0.element }
    }

    /// 模型回傳的原始內容，逐筆驗證：id 要在今天清單裡、列舉值合法、摘要 ≤ 20 字且沒有簡體字。不合格的那筆丟掉。
    static func convert(_ raws: [Raw], input: NoteInput) -> [NoteFinding] {
        var out: [NoteFinding] = []
        let ids = Set(input.items.map(\.id))
        for r in raws {
            guard let kind = NoteKind(rawValue: r.kind) else { continue }
            let id: String? = r.exerciseId.isEmpty ? nil : r.exerciseId
            if let id, !ids.contains(id) { continue }
            var f = NoteFinding(kind: kind, exerciseId: id)
            switch kind {
            case .pain:
                guard id != nil else { continue }
                if !r.joint.isEmpty {
                    guard let j = Joint(rawValue: r.joint) else { continue }
                    f.joint = j
                }
            case .tooLight, .tooHeavy:
                guard id != nil else { continue }
            case .sideWeak:
                guard let l = Limb(rawValue: r.limb), let s = WeakSide(rawValue: r.side), s != .none else { continue }
                f.limb = l
                f.side = s
            case .gear:
                let s = r.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard id != nil, !s.isEmpty, s.count <= maxSummary,
                      !s.contains(where: { Coach.simplified.contains($0) }) else { continue }
                f.summary = s
            }
            out.append(f)
        }
        return out
    }

    // MARK: 字串小工具

    private static func strip(_ s: String) -> String {
        negations.reduce(s) { $0.replacingOccurrences(of: $1, with: "", options: .regularExpression) }
    }

    private static func clauses(_ s: String) -> [String] {
        s.components(separatedBy: CharacterSet(charactersIn: "，。；！？、,.;!?\n"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func positions(of word: String, in chars: [Character]) -> [Int] {
        let w = Array(word)
        guard !w.isEmpty, chars.count >= w.count else { return [] }
        return (0...(chars.count - w.count)).filter { Array(chars[$0..<($0 + w.count)]) == w }
    }

    /// 離「痛」最近的關節詞；沒寫就是 nil
    private static func nearestJoint(to at: Int, in chars: [Character]) -> Joint? {
        var best: (Joint, Int)?
        for (joint, words) in jointWords {
            for p in words.flatMap({ positions(of: $0, in: chars) }) {
                let d = abs(p - at)
                if best == nil || d < best!.1 { best = (joint, d) }
            }
        }
        return best?.0
    }
}

// MARK: - Apple Intelligence

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct NoteFindingAI {
    @Guide(description: "只能是這五個英文字之一：pain（會痛）、tooLight（太輕）、tooHeavy（太重）、sideWeak（左右其中一邊比較弱）、gear（器材或姿勢的問題）")
    var kind: String
    @Guide(description: "這筆講的是哪個動作，要照抄清單裡的 id；整次備註裡沒指名動作的左右差就留空字串")
    var exerciseId: String
    @Guide(description: "只有 pain 才填，而且備註看得出哪個關節：shoulder、elbow、lowerBack、knee、hip 其中一個，其他情況留空字串")
    var joint: String
    @Guide(description: "只有 sideWeak 才填：arm（手）或 leg（腳）")
    var limb: String
    @Guide(description: "只有 sideWeak 才填：left（左邊弱）或 right（右邊弱）")
    var side: String
    @Guide(description: "只有 gear 才填：用 20 個字以內的繁體中文摘要備註在說什麼，例如「椅子會晃」")
    var summary: String
}

@available(iOS 26.0, *)
@Generable
struct NoteFindingsAI {
    @Guide(description: "備註裡看到的情況，每種情況一筆；備註沒有提到就是空陣列。同一個動作同一種 kind 只寫一筆")
    var findings: [NoteFindingAI]
}
#endif

enum NoteReaderAI {
    static let instructions = """
    你在幫健身 App「練壯」看使用者練完後寫的備註，只負責分類，不給建議、不改任何數字。
    只找這五種情況：
    - pain：備註說某個動作會痛、刺痛、不舒服（「不痛」「沒有痛」不算）。
    - tooLight：太輕、很輕鬆、還能再加重。只有「有重量」的動作才會有。
    - tooHeavy：太重、做不動、做不完、撐不住。只有「有重量」的動作才會有。
    - sideWeak：左邊或右邊比較弱、先沒力、會抖、跟不上。要寫清楚是手還是腳、左還是右。
    - gear：器材或姿勢的問題，例如椅子會晃、握不住、槓片快鎖不好、要調角度。
    規則：
    - 備註沒有寫的就不要寫，不要猜。
    - exerciseId 只能照抄清單裡的 id。
    - 一句備註可以有好幾種情況；太輕和太重不會同時成立。
    - 使用台灣的繁體中文。
    """

    /// 讀備註。沒有 AI、或出錯就回 nil（改用規則版）。
    static func read(_ input: NoteInput) async -> [NoteFinding]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), CoachAI.status == .ready {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let res = try await session.respond(to: "今天的訓練備註：\n" + input.prompt,
                                                    generating: NoteFindingsAI.self,
                                                    options: GenerationOptions(temperature: 0.1))
                let raws = res.content.findings.map {
                    NoteReader.Raw(kind: $0.kind, exerciseId: $0.exerciseId, joint: $0.joint,
                                   limb: $0.limb, side: $0.side, summary: $0.summary)
                }
                let found = NoteReader.finalize(NoteReader.convert(raws, input: input), input: input)
                // 全部都不合格：這次 AI 不可靠，改用規則版
                if found.isEmpty && !raws.isEmpty { return nil }
                return found
            } catch {
                // 安全過濾、超出長度等：走規則版
            }
        }
        #endif
        return nil
    }
}

/// 練完和 `CoachLoader` 一起開始讀備註。
@MainActor
final class NoteReaderLoader: ObservableObject {
    let input: NoteInput
    /// nil = 還在讀
    @Published private(set) var findings: [NoteFinding]?
    @Published private(set) var source: CoachSource = .basic(nil)

    init(input: NoteInput) {
        self.input = input
        Task { await load() }
    }

    func name(of id: String?) -> String {
        guard let id else { return "" }
        return input.items.first { $0.id == id }?.name ?? ExerciseLibrary.byId(id)?.name ?? id
    }

    private func load() async {
        if let ai = await NoteReaderAI.read(input) {
            source = .ai
            findings = ai
        } else {
            source = .basic(nil)
            findings = NoteReader.rules(input)
        }
    }
}

// MARK: - 存放與套用

enum NudgeKind: String, Codable {
    /// 下次減輕兩成
    case ease
    /// 下次多加一級
    case up
    /// 下次少一級
    case down
}

struct NoteNudge: Codable, Equatable {
    var kind: String
    var date: Double
}

struct NoteReminder: Codable, Equatable {
    var text: String
    var date: Double
}

enum NoteStore {
    static let nudges = KeyedStore<NoteNudge>(key: Keys.noteNudges)
    static let reminders = KeyedStore<NoteReminder>(key: Keys.noteReminders)

    /// 沒用到就失效的天數
    static let nudgeDays = 21

    /// 這個動作現在有效的 nudge（過期的當作沒有）
    static func nudge(for id: String, now: Date = .now) -> NudgeKind? {
        guard let n = nudges[id], now.timeIntervalSince1970 - n.date <= Double(nudgeDays) * 86400 else { return nil }
        return NudgeKind(rawValue: n.kind)
    }

    /// 同一個動作新的蓋掉舊的
    static func setNudge(_ kind: NudgeKind, for id: String, now: Date = .now) {
        nudges[id] = NoteNudge(kind: kind.rawValue, date: now.timeIntervalSince1970)
    }

    static func clearNudge(_ id: String) { nudges[id] = nil }

    static func reminder(for id: String) -> String? { reminders[id]?.text }

    static func setReminder(_ text: String, for id: String, now: Date = .now) {
        reminders[id] = NoteReminder(text: text, date: now.timeIntervalSince1970)
    }

    static func clearReminder(_ id: String) { reminders[id] = nil }
}

enum NoteNudges {
    /// 建 draft 時套用一次：改這個動作的每一組重量（熱身組不動），建議文字前面加一句說明。
    /// 徒手動作或重量 0 的不套用。
    static func apply(_ kind: NudgeKind, to sets: inout [SetDraft], suggestion: Suggestion,
                      ladder: WeightLadder, loaded: Bool) -> Suggestion {
        guard loaded, sets.contains(where: { $0.kind != .warmup && $0.weight > 0 }) else { return suggestion }

        func move(_ w: Double) -> Double {
            switch kind {
            case .ease: ladder.snap(w * 0.8)
            case .up: ladder.up(w)
            case .down: ladder.down(w)
            }
        }
        var changed = false
        for k in sets.indices where sets[k].kind != .warmup && sets[k].weight > 0 {
            let w = move(sets[k].weight)
            if abs(w - sets[k].weight) > 0.01 { changed = true }
            sets[k].weight = w
            if kind == .ease { sets[k].eased = true }
        }
        let prefix: String
        switch kind {
        case .ease: prefix = "上次備註說會痛：先減輕約兩成。"
        case .up: prefix = changed ? "上次備註說太輕：多加一級。" : "上次備註說太輕，但已經是器材最重了。"
        case .down: prefix = changed ? "上次備註說太重：少一級。" : "上次備註說太重，但已經是器材最輕了。"
        }
        return Suggestion(weight: suggestion.weight > 0 ? move(suggestion.weight) : suggestion.weight,
                          reps: suggestion.reps, note: prefix + suggestion.note, tip: suggestion.tip)
    }
}

// MARK: - 教練講評頁的卡片

struct NoteFindingsCard: View {
    @ObservedObject var loader: NoteReaderLoader
    /// finding.id → 按完之後顯示的灰字
    @State private var handled: [String: String] = [:]

    var body: some View {
        if let list = loader.findings, !list.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("從備註看到", systemImage: "note.text.badge.plus")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.accentSoft)
                    Spacer()
                    sourceTag
                }
                ForEach(list) { f in row(f) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.accentDim.opacity(0.6), lineWidth: 1))
        }
    }

    private var sourceTag: some View {
        let ai = loader.source == .ai
        return Text(ai ? "AI" : "自動整理")
            .font(.caption2.weight(.bold))
            .foregroundStyle(ai ? Theme.accent : Theme.muted)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.sunken, in: Capsule())
    }

    private func text(_ f: NoteFinding) -> String {
        let name = "「\(loader.name(of: f.exerciseId))」"
        switch f.kind {
        case .pain: return "\(name)\(f.joint.map { "的\($0.title)" } ?? "")好像會痛"
        case .tooLight: return "\(name)覺得太輕"
        case .tooHeavy: return "\(name)覺得太重"
        case .sideWeak:
            let side = f.side == .right ? "右" : "左"
            return "\(f.limb?.noun ?? "手")的\(side)邊比較弱" + (f.exerciseId == nil ? "" : "（\(name)）")
        case .gear: return "\(name)：\(f.summary)"
        }
    }

    private func row(_ f: NoteFinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let done = handled[f.id] {
                Text(done)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            } else {
                Text(text(f))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    ForEach(Array(actions(f).enumerated()), id: \.offset) { i, a in
                        Button { handled[f.id] = a.run() } label: {
                            Text(a.title)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(i == 0 ? Theme.onHot : Theme.accentSoft)
                                .background(i == 0 ? Theme.hot : Theme.raised, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private struct Action {
        let title: String
        let run: () -> String
    }

    private func actions(_ f: NoteFinding) -> [Action] {
        let skip = Action(title: "不用", run: { "已略過：\(text(f))" })
        let id = f.exerciseId ?? ""
        switch f.kind {
        case .pain:
            return [
                Action(title: "下次減輕兩成") {
                    Avoid.logPain(id, joint: f.joint)
                    NoteStore.setNudge(.ease, for: id)
                    return "已記下：下次「\(loader.name(of: id))」先減輕兩成"
                },
                Action(title: "換掉，之後不排") {
                    Avoid.mark(id, reason: .pain)
                    Avoid.logPain(id, joint: f.joint)
                    return "已記下：之後不排「\(loader.name(of: id))」"
                },
                skip,
            ]
        case .tooLight:
            return [
                Action(title: "下次多加一級") {
                    NoteStore.setNudge(.up, for: id)
                    return "已記下：下次「\(loader.name(of: id))」多加一級"
                },
                skip,
            ]
        case .tooHeavy:
            return [
                Action(title: "下次少一級") {
                    NoteStore.setNudge(.down, for: id)
                    return "已記下：下次「\(loader.name(of: id))」少一級"
                },
                skip,
            ]
        case .sideWeak:
            guard let limb = f.limb, let side = f.side else { return [skip] }
            return [
                Action(title: "設成\(side == .right ? "右" : "左")邊比較弱") {
                    SideBalance.set(side, for: limb)
                    return "已記下：\(limb.noun)的\(side == .right ? "右" : "左")邊比較弱"
                },
                skip,
            ]
        case .gear:
            return [
                Action(title: "下次提醒我") {
                    NoteStore.setReminder(f.summary, for: id)
                    return "已記下：下次「\(loader.name(of: id))」提醒你「\(f.summary)」"
                },
                skip,
            ]
        }
    }
}
