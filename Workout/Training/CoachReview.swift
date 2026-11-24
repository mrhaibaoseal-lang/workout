import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - 交給教練的資料（數字全部由程式算好）

/// 一次訓練的重點。模型只能轉述這裡的內容，不能自己算重量。
struct CoachFacts {
    struct Item {
        let name: String
        let loaded: Bool
        let unit: String
        /// 正式組：重量、次數、判定
        let sets: [(weight: Double, reps: Int, grade: SetGrade?)]
        /// 上次的最重重量和最多次數（第一次做是 nil）
        let lastTop: (weight: Double, reps: Int)?
        let isPR: Bool
        let plateauReset: Bool
        /// 下次預計（照 App 的遞增規則）
        let nextWeight: Double
        let nextReps: Int
        let note: String

        var topWeight: Double { sets.map(\.weight).max() ?? 0 }
        var topReps: Int { sets.filter { $0.weight >= topWeight }.map(\.reps).max() ?? 0 }
        var allHit: Bool { !sets.isEmpty && sets.allSatisfy { $0.grade != .miss } }

        /// 和上次比
        var change: String {
            guard let last = lastTop else { return "第一次做" }
            if loaded && topWeight > last.weight + 0.01 { return "比上次重 \(Progression.format(topWeight - last.weight)) kg" }
            if loaded && topWeight < last.weight - 0.01 { return "比上次輕 \(Progression.format(last.weight - topWeight)) kg" }
            if topReps > last.reps { return "同重量多做 \(topReps - last.reps) \(unit)" }
            if topReps < last.reps { return "比上次少 \(last.reps - topReps) \(unit)" }
            return "和上次一樣"
        }

        var next: String {
            if loaded && nextWeight > 0 {
                if nextWeight > topWeight + 0.01 { return "下次加重到 \(Progression.format(nextWeight)) kg" }
                if nextWeight < topWeight - 0.01 { return "下次用 \(Progression.format(nextWeight)) kg" }
                return "下次維持 \(Progression.format(nextWeight)) kg，目標 \(nextReps) \(unit)"
            }
            return "下次目標 \(nextReps) \(unit)"
        }

        var line: String {
            let setText = sets.map { s in
                let g = s.grade.map { " \($0.title)" } ?? ""
                return loaded && s.weight > 0 ? "\(Progression.format(s.weight))kg×\(s.reps)\(g)" : "\(s.reps)\(unit)\(g)"
            }.joined(separator: "、")
            var parts = ["\(name)：\(setText)", change]
            if isPR { parts.append("破個人紀錄") }
            if plateauReset { parts.append("之前停滯，這次先減重重新往上") }
            parts.append(next)
            if !note.isEmpty { parts.append("備註「\(note)」") }
            return "- " + parts.joined(separator: "；")
        }
    }

    let dayName: String
    let lengthTitle: String
    let phaseTitle: String
    let minutes: Int
    let readiness: Readiness?
    let sessionNote: String
    let items: [Item]
    let perfect: Int
    let good: Int
    let miss: Int

    var prNames: [String] { items.filter(\.isPR).map(\.name) }

    /// 給模型看的文字
    var prompt: String {
        var lines = ["今天練：\(dayName)（\(lengthTitle)，\(phaseTitle)），花了 \(minutes) 分鐘。"]
        if let r = readiness {
            lines.append("練前狀態：睡眠 \(r.sleep)/5、痠痛 \(r.soreness)/5（分數越高越不痠）、精神 \(r.energy)/5。")
        }
        lines.append("正式組判定：PERFECT \(perfect) 組、GOOD \(good) 組、MISS \(miss) 組。")
        lines.append("各動作：")
        lines += items.map(\.line)
        if !sessionNote.isEmpty { lines.append("整次備註：「\(sessionNote)」") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - 講評

struct CoachReply: Equatable {
    var headline: String
    var highlight: String
    var nextTime: String
}

enum CoachSource: Equatable {
    /// Apple Intelligence 寫的
    case ai
    /// 程式寫的，附原因（沒有就不顯示）
    case basic(String?)
}

enum Coach {
    /// 沒有 AI 時的固定文字，也是 AI 失敗時的備案。
    static func basic(_ f: CoachFacts) -> CoachReply {
        let total = f.perfect + f.good + f.miss
        let headline: String
        if !f.prNames.isEmpty {
            headline = "破紀錄了，今天很強！"
        } else if total > 0 && f.miss == 0 {
            headline = "每組都達標，穩穩進步。"
        } else if f.miss > 0 && f.miss * 2 >= total {
            headline = "今天比較吃力，有練完就是賺到。"
        } else {
            headline = "練完了，辛苦了！"
        }

        var good: [String] = []
        if !f.prNames.isEmpty { good.append("\(f.prNames.joined(separator: "、"))破了個人紀錄") }
        let up = f.items.filter { $0.change.hasPrefix("比上次重") || $0.change.hasPrefix("同重量多做") }
        if let u = up.first(where: { !$0.isPR }) { good.append("\(u.name)\(u.change)") }
        if good.isEmpty, f.perfect > 0 { good.append("\(f.perfect) 組 PERFECT，力氣控制得剛好") }
        if good.isEmpty { good.append("完成 \(f.items.count) 個動作，維持訓練習慣最重要") }

        let ups = f.items.filter { $0.loaded && $0.nextWeight > $0.topWeight + 0.01 }
        var next: [String] = ups.prefix(2).map { "\($0.name)\($0.next)" }
        if let m = f.items.first(where: { !$0.allHit }) {
            next.append("\(m.name)先用同樣重量把次數補滿")
        }
        if next.isEmpty { next.append("照課表來，下次挑戰多做 1 下") }

        return CoachReply(headline: headline,
                          highlight: good.joined(separator: "；") + "。",
                          nextTime: next.joined(separator: "；") + "。")
    }

    /// 模型寫的內容只能用資料裡出現過的數字，也不能有簡體字。
    static func isValid(_ r: CoachReply, facts: CoachFacts) -> Bool {
        isValid(r, source: facts.prompt)
    }

    /// source = 交給模型的資料；寫出來的數字都要在裡面出現過。
    static func isValid(_ r: CoachReply, source: String, maxLength: Int = 220) -> Bool {
        guard !r.headline.isEmpty, !r.nextTime.isEmpty else { return false }
        return isValid(text: r.headline + r.highlight + r.nextTime, source: source, maxLength: maxLength)
    }

    /// 一段文字的檢查（排課檢查的說明也用這個）：不能空、長度有限、數字都在資料裡、不能有簡體字。
    static func isValid(text: String, source: String, maxLength: Int) -> Bool {
        guard !text.isEmpty, text.count <= maxLength else { return false }
        if text.contains(where: { simplified.contains($0) }) { return false }
        let allowed = Set(numbers(in: source))
        return numbers(in: text).allSatisfy { allowed.contains($0) }
    }

    /// 數字統一成「去掉多餘的 0」的寫法再比對（12.50 和 12.5 視為同一個）
    static func numbers(in s: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?")
        let ns = s as NSString
        return (regex?.matches(in: s, range: NSRange(location: 0, length: ns.length)) ?? []).map {
            let raw = ns.substring(with: $0.range)
            return Double(raw).map(Progression.format) ?? raw
        }
    }

    /// 常見的簡體字（繁體不會用到的寫法）
    static let simplified: Set<Character> = Set("这们个说为时会对还进没过动练组让给应该觉错吗习实现发经与东两边头长门问间关开体么样当减轻级")
}

// MARK: - Apple Intelligence

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct CoachReplyAI {
    @Guide(description: "一句總評，15 個字以內，口語、有精神")
    var headline: String
    @Guide(description: "今天做得好的地方，1 到 2 句，要點名具體動作，只能用資料裡的數字")
    var highlight: String
    @Guide(description: "下次要怎麼做，1 到 2 句，重量和次數只能照抄資料裡的「下次」，沒有就不要寫數字")
    var nextTime: String
}
#endif

enum CoachAI {
    enum Status { case ready, notEnabled, notReady, unsupported }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return .ready
            case .unavailable(.appleIntelligenceNotEnabled): return .notEnabled
            case .unavailable(.modelNotReady): return .notReady
            default: return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    static let instructions = """
    你是健身 App「練壯」裡的教練，看完使用者今天的訓練紀錄後給簡短講評。
    規則：
    - 只能根據提供的資料講評，不可以自己編重量、次數、組數或任何數字。
    - 下次的重量和次數只能照抄資料裡的「下次」那一段，App 已經算好了。
    - 不要給醫療建議；備註提到痠痛不適時，只提醒量力而為、不舒服就休息。
    - 使用台灣的繁體中文，語氣像朋友，鼓勵但不浮誇，不要用表情符號。
    - 使用者是新手，在家用啞鈴訓練，目標是增肌。
    """

    /// 產生講評，失敗兩次就回傳 nil（改用固定文字）。
    static func review(_ facts: CoachFacts) async -> CoachReply? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), status == .ready {
            for _ in 0..<2 {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let res = try await session.respond(to: "今天的訓練紀錄：\n" + facts.prompt,
                                                        generating: CoachReplyAI.self,
                                                        options: GenerationOptions(temperature: 0.5))
                    let c = res.content
                    let reply = CoachReply(headline: c.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                                           highlight: c.highlight.trimmingCharacters(in: .whitespacesAndNewlines),
                                           nextTime: c.nextTime.trimmingCharacters(in: .whitespacesAndNewlines))
                    if Coach.isValid(reply, facts: facts) { return reply }
                } catch {
                    // 安全過濾、超出長度等：再試一次，還是不行就用固定文字
                }
            }
        }
        #endif
        return nil
    }
}

// MARK: - 畫面

/// 練完就開始寫講評（看成果動畫的時間剛好拿來等模型）。
@MainActor
final class CoachLoader: ObservableObject {
    let facts: CoachFacts
    @Published private(set) var reply: CoachReply?
    @Published private(set) var source: CoachSource = .basic(nil)

    init(facts: CoachFacts) {
        self.facts = facts
        Task { await load() }
    }

    private func load() async {
        let status = CoachAI.status
        if status == .ready, let r = await CoachAI.review(facts) {
            source = .ai
            reply = r
            return
        }
        let why: String? = switch status {
        case .ready: "這次 AI 沒寫出可靠的講評，先用自動整理。"
        case .notEnabled: "打開「設定 › Apple Intelligence 與 Siri」，就會改由 AI 寫講評。"
        case .notReady: "Apple Intelligence 的模型還在下載，好了之後就會改由 AI 寫講評。"
        case .unsupported: nil
        }
        source = .basic(why)
        reply = Coach.basic(facts)
    }
}

/// 練完成果之後的教練講評。
struct CoachReviewView: View {
    @ObservedObject var loader: CoachLoader
    /// 有給就在講評下面多一張「從備註看到」
    var notes: NoteReaderLoader? = nil
    /// 有給就多一顆「練後伸展」按鈕
    var onStretch: (() -> Void)? = nil
    var stretchMinutes = 4
    /// 有給就多一顆「分享」按鈕（練完的圖卡）
    var share: ShareCardData? = nil
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var showShare = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.accent)
                Text("教練講評")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Theme.fg)
                Spacer()
                if loader.reply != nil { sourceTag }
                if share != nil {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(Theme.accentSoft)
                    .accessibilityLabel("分享今天的訓練")
                }
            }
            .padding(.top, 8)

            if let r = loader.reply {
                Text(r.headline)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .modifier(Appear(shown: shown, delay: 0, reduce: reduceMotion))
                block("做得好", icon: "hand.thumbsup.fill", color: Theme.green, text: r.highlight)
                    .modifier(Appear(shown: shown, delay: 0.15, reduce: reduceMotion))
                block("下次", icon: "arrow.up.forward.circle.fill", color: Theme.gold, text: r.nextTime)
                    .modifier(Appear(shown: shown, delay: 0.3, reduce: reduceMotion))
                if case .basic(let why?) = loader.source {
                    Text(why)
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .modifier(Appear(shown: shown, delay: 0.45, reduce: reduceMotion))
                }
            } else {
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    Text("教練正在看你的紀錄…")
                        .font(.headline)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }

            if let notes {
                NoteFindingsCard(loader: notes)
                    .modifier(Appear(shown: shown, delay: 0.6, reduce: reduceMotion))
            }
            }
            }
            .scrollIndicators(.hidden)
            if let onStretch {
                Button(action: onStretch) {
                    Label("練後伸展跟做（約 \(stretchMinutes) 分鐘）", systemImage: "figure.cooldown")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(HotButtonStyle())
                Button("不用，結束") { onDone() }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity)
            } else {
                Button("好") { onDone() }
                    .buttonStyle(HotButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.bg.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { shown = true }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) {
            if let share { ShareCardSheet(data: share) }
        }
        .onAppear { if loader.reply != nil { reveal() } }
        .onChange(of: loader.reply) { _, r in if r != nil { reveal() } }
    }

    private func reveal() {
        guard !shown else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        // 等內容先排好版，下一輪再播進場動畫
        DispatchQueue.main.async { shown = true }
    }

    private var sourceTag: some View {
        let ai = loader.source == .ai
        return Label(ai ? "Apple Intelligence" : "自動整理", systemImage: ai ? "sparkles" : "list.bullet")
            .font(.caption.weight(.bold))
            .foregroundStyle(ai ? Theme.accent : Theme.muted)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Theme.surface, in: Capsule())
    }

    private func block(_ title: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(color)
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.35), lineWidth: 1))
    }
}

private struct Appear: ViewModifier {
    let shown: Bool
    let delay: Double
    let reduce: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduce ? 1 : 0)
            .offset(y: shown || reduce ? 0 : 24)
            .animation(reduce ? nil : .spring(duration: 0.5).delay(delay), value: shown)
    }
}
