import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

extension Keys {
    /// 看過的最後一週總結（週數）
    static let weeklySummarySeen = "weeklySummarySeen"
}

// MARK: - 一週的資料（數字全部由程式算好）

struct WeeklyFacts {
    let week: Int
    let sessions: Int
    let goal: Int
    let minutes: Int
    let workSets: Int
    /// 每個部位實際練了幾組（主要 1、次要 0.5）
    let muscleSets: [Muscle: Double]
    let prs: [String]
    let stalled: [String]
    /// 練前狀態平均總分（滿分 15）
    let readiness: Double?
    let sore: [String]
    let joint: [String]
    let pain: [String]
    /// 這週是區塊最後一週時，下個區塊的組數調整
    let review: BlockReview?
    /// 用自訂課表（組數調整不會自動套用）
    let custom: Bool
    /// 增重速度（`Nutrition`），算不出來是 nil
    var pace: Nutrition.Pace = .unknown
    /// 每週體重變化（kg）
    var weeklyGain: Double? = nil
    /// 那一週有記錄的日子平均蛋白質（g）、目標、記了幾天
    var protein: (avg: Int, target: Int, logged: Int)? = nil

    func range(_ m: Muscle) -> ClosedRange<Double>? {
        custom ? VolumePlan.range(for: m) : PersonalVolume.range(for: m)
    }

    var lacking: [Muscle] {
        VolumePlan.targeted.filter { m in range(m).map { (muscleSets[m] ?? 0) < $0.lowerBound } ?? false }
    }

    var over: [Muscle] {
        VolumePlan.targeted.filter { m in range(m).map { (muscleSets[m] ?? 0) > $0.upperBound } ?? false }
    }

    static func changeText(_ d: MuscleDecision) -> String {
        d.change > 0 ? "每次多練 1 組" : "每次少練 1 組"
    }

    /// 給模型看的文字
    var prompt: String {
        var lines = ["第 \(week) 週：練了 \(sessions) 次（目標 \(goal) 次），正式組共 \(workSets) 組，總共 \(minutes) 分鐘。"]
        let parts = VolumePlan.targeted.compactMap { m -> String? in
            guard let r = range(m) else { return nil }
            return "\(m.name) \(Progression.format(muscleSets[m] ?? 0))（\(Int(r.lowerBound))–\(Int(r.upperBound))）"
        }
        lines.append("各部位實際組數（目標範圍）：" + parts.joined(separator: "、"))
        if !lacking.isEmpty { lines.append("組數不夠的部位：" + lacking.map(\.name).joined(separator: "、")) }
        if !over.isEmpty { lines.append("組數偏多的部位：" + over.map(\.name).joined(separator: "、")) }
        if !prs.isEmpty { lines.append("破個人紀錄：" + prs.joined(separator: "、")) }
        if !stalled.isEmpty { lines.append("卡住沒進步的動作：" + stalled.joined(separator: "、")) }
        if let r = readiness { lines.append("練前狀態平均 \(Progression.format((r * 10).rounded() / 10))/15。") }
        if !sore.isEmpty { lines.append("回報到下次還在痠的部位：" + sore.joined(separator: "、")) }
        if !joint.isEmpty { lines.append("回報關節不舒服的部位：" + joint.joined(separator: "、")) }
        if !pain.isEmpty { lines.append("會痛的動作：" + pain.joined(separator: "、")) }
        if let g = weeklyGain, pace != .unknown {
            lines.append("體重每週 \(g >= 0 ? "+" : "")\(String(format: "%.2f", g)) kg，增重速度\(pace.title)。")
        }
        if let p = protein {
            lines.append("這週記了 \(p.logged) 天蛋白質，有記的日子平均 \(p.avg) g（目標 \(p.target) g）。")
        }
        if let review {
            let changes = review.changes
            if changes.isEmpty {
                lines.append("這週是這個區塊最後一週。下個區塊每個部位的組數都不變。")
            } else {
                lines.append("這週是這個區塊最後一週。下個區塊的組數調整：")
                for d in changes {
                    guard let m = d.target else { continue }
                    lines.append("- \(m.name)：\(Self.changeText(d))（\(d.reason)）")
                }
                if custom { lines.append("用的是自訂課表，App 不會自動改，要自己照這個調整。") }
            }
        }
        return lines.joined(separator: "\n")
    }
}

enum WeeklySummary {
    /// 第 w 週的資料。sessions 新到舊。
    static func facts(week w: Int, start: Date, sessions all: [WorkoutSession], goal: Int) -> WeeklyFacts {
        let from = PersonalVolume.weekStart(w, start: start)
        let to = PersonalVolume.weekStart(w + 1, start: start)
        let inWeek = all.filter { $0.date >= from && $0.date < to }
        let before = all.filter { $0.date < from }

        var muscle: [Muscle: Double] = [:]
        var workSets = 0
        var best: [String: Double] = [:]
        for s in inWeek {
            for e in s.entries where e.isWork {
                workSets += 1
                guard let ex = ExerciseLibrary.byId(e.exerciseId) else { continue }
                for (m, c) in ex.trainedMuscles { muscle[m, default: 0] += c }
                let v = ex.loaded ? e.weight : Double(e.reps)
                best[e.exerciseId] = max(best[e.exerciseId] ?? 0, v)
            }
        }
        // 破紀錄：這週最好的比以前都好（以前沒做過不算）
        var old: [String: Double] = [:]
        for s in before {
            for e in s.entries where e.isWork && best[e.exerciseId] != nil {
                let loaded = ExerciseLibrary.byId(e.exerciseId)?.loaded ?? true
                old[e.exerciseId] = max(old[e.exerciseId] ?? 0, loaded ? e.weight : Double(e.reps))
            }
        }
        let prs = best.compactMap { id, v -> String? in
            guard let o = old[id], v > o + 0.001 else { return nil }
            return ExerciseLibrary.byId(id)?.name
        }.sorted()

        let stalled = Plateau.stalled(sessions: all.filter { $0.date < to })
            .compactMap { ExerciseLibrary.byId($0.exerciseId)?.name }

        let readiness = inWeek.compactMap { Readiness.decode($0.readiness) }
        let a = from.timeIntervalSince1970, b = to.timeIntervalSince1970
        let feedback = PersonalVolume.feedback().filter { $0.date >= a && $0.date < b }
        func names(_ f: (MuscleFeedback) -> Bool) -> [String] {
            let set = Set(feedback.filter(f).compactMap { Muscle(rawValue: $0.muscle) })
            return Muscle.ordered.filter { set.contains($0) }.map(\.name)
        }
        let painIds = Set(Avoid.painLog().filter { $0.date >= a && $0.date < b }.map(\.exerciseId))

        return WeeklyFacts(
            week: w,
            sessions: inWeek.count,
            goal: goal,
            minutes: inWeek.reduce(0) { $0 + $1.durationSeconds } / 60,
            workSets: workSets,
            muscleSets: muscle,
            prs: prs,
            stalled: Array(stalled.prefix(3)),
            readiness: readiness.isEmpty ? nil : Double(readiness.map(\.total).reduce(0, +)) / Double(readiness.count),
            sore: names { $0.recovery == Recovery.sore.rawValue },
            joint: names(\.joint),
            pain: painIds.compactMap { ExerciseLibrary.byId($0)?.name }.sorted(),
            review: PersonalVolume.review(endingWeek: w),
            custom: CustomPrograms.active != nil)
    }

    /// 要顯示總結的週（上一週）；看過了、或上週沒練也沒有檢討就是 nil。
    static func pendingWeek(start: Date, seen: Int, sessions: [WorkoutSession]) -> Int? {
        let w = Stats.week(since: start) - 1
        guard w >= 1, seen < w else { return nil }
        let from = PersonalVolume.weekStart(w, start: start)
        let to = PersonalVolume.weekStart(w + 1, start: start)
        let trained = sessions.contains { $0.date >= from && $0.date < to }
        return trained || PersonalVolume.review(endingWeek: w) != nil ? w : nil
    }

    /// 沒有 AI 時的固定文字，也是 AI 失敗時的備案。三段：總評、這週、下週重點。
    static func basic(_ f: WeeklyFacts) -> CoachReply {
        let headline: String
        if f.sessions == 0 {
            headline = "上週沒練到，這週重新開始。"
        } else if f.sessions >= f.goal {
            headline = "週目標達成，很穩！"
        } else {
            headline = "上週練了 \(f.sessions) 次，繼續保持。"
        }

        var week: [String] = []
        if f.sessions > 0 { week.append("練了 \(f.sessions) 次、\(f.workSets) 個正式組") }
        if !f.prs.isEmpty { week.append("\(f.prs.prefix(3).joined(separator: "、"))破了個人紀錄") }
        if !f.lacking.isEmpty { week.append("\(f.lacking.prefix(3).map(\.name).joined(separator: "、"))的組數不太夠") }
        if week.isEmpty { week.append("這週是休息週") }

        var next: [String] = []
        if let r = f.review {
            let up = r.changes.filter { $0.change > 0 }.compactMap { $0.target?.name }
            let down = r.changes.filter { $0.change < 0 }.compactMap { $0.target?.name }
            if !up.isEmpty { next.append("\(up.joined(separator: "、"))每次多練 1 組") }
            if !down.isEmpty { next.append("\(down.joined(separator: "、"))每次少練 1 組") }
            if !next.isEmpty && f.custom { next.append("自訂課表要自己調整") }
        }
        if let s = f.stalled.first { next.append("\(s)卡住了，照停滯建議先減重再爬") }
        if !f.sore.isEmpty { next.append("\(f.sore.prefix(2).joined(separator: "、"))恢復比較慢，多睡一點") }
        if !f.pain.isEmpty { next.append("\(f.pain.first!)會痛就先減輕或換掉") }
        switch f.pace {
        case .losing, .slow: next.append("增重速度\(f.pace.title)，每天再多吃一點")
        case .fast: next.append("體重長太快，每天少吃一點")
        default: break
        }
        if let p = f.protein {
            if p.logged < Nutrition.minLoggedDays {
                next.append("蛋白質這週只記了 \(p.logged) 天，多記幾天才看得出夠不夠")
            } else if p.avg < p.target * 8 / 10 {
                next.append("蛋白質平均 \(p.avg) g，離 \(p.target) g 還差一些")
            }
        }
        if next.isEmpty { next.append("照課表練，每組都做到次數上限就加重") }

        return CoachReply(headline: headline,
                          highlight: week.joined(separator: "；") + "。",
                          nextTime: next.joined(separator: "；") + "。")
    }
}

// MARK: - Apple Intelligence

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct WeeklyReplyAI {
    @Guide(description: "一句總評，15 個字以內，口語、有精神")
    var headline: String
    @Guide(description: "這週練得怎麼樣，1 到 2 句，要提到具體部位或動作，只能用資料裡的數字")
    var summary: String
    @Guide(description: "下週的重點，1 到 2 句；有組數調整就照抄是哪些部位多練或少練，不要自己編數字")
    var focus: String
}
#endif

enum WeeklyAI {
    static let instructions = """
    你是健身 App「練壯」裡的教練，看完使用者上週的訓練總結後，寫一段簡短的每週講評。
    規則：
    - 只能根據提供的資料講評，不可以自己編重量、次數、組數或任何數字。
    - 組數調整是 App 算好的，只能照資料轉述是哪些部位多練或少練、為什麼。
    - 不要給醫療建議；有會痛或關節不舒服時，只提醒減輕重量、不舒服就休息或換動作。
    - 使用台灣的繁體中文，語氣像朋友，鼓勵但不浮誇，不要用表情符號。
    - 使用者是新手，在家用啞鈴訓練，目標是增肌。
    """

    static func review(_ facts: WeeklyFacts) async -> CoachReply? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), CoachAI.status == .ready {
            for _ in 0..<2 {
                do {
                    let session = LanguageModelSession(instructions: instructions)
                    let res = try await session.respond(to: "上週的訓練總結：\n" + facts.prompt,
                                                        generating: WeeklyReplyAI.self,
                                                        options: GenerationOptions(temperature: 0.5))
                    let c = res.content
                    let reply = CoachReply(headline: c.headline.trimmingCharacters(in: .whitespacesAndNewlines),
                                           highlight: c.summary.trimmingCharacters(in: .whitespacesAndNewlines),
                                           nextTime: c.focus.trimmingCharacters(in: .whitespacesAndNewlines))
                    if Coach.isValid(reply, source: facts.prompt, maxLength: 260) { return reply }
                } catch {
                    // 再試一次，還是不行就用固定文字
                }
            }
        }
        #endif
        return nil
    }
}

@MainActor
final class WeeklyLoader: ObservableObject {
    let facts: WeeklyFacts
    @Published private(set) var reply: CoachReply?
    @Published private(set) var source: CoachSource = .basic(nil)

    init(facts: WeeklyFacts) {
        self.facts = facts
        Task { await load() }
    }

    private func load() async {
        if CoachAI.status == .ready, let r = await WeeklyAI.review(facts) {
            source = .ai
            reply = r
            return
        }
        source = .basic(nil)
        reply = WeeklySummary.basic(facts)
    }
}

// MARK: - 畫面

/// 今天頁：上週總結的入口。
struct WeeklySummaryCard: View {
    let week: Int
    let hasReview: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: hasReview ? "slider.horizontal.3" : "text.book.closed.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.gold)
                    .frame(width: 40, height: 40)
                    .background(Theme.goldBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("第 \(week) 週總結").font(.subheadline.weight(.heavy)).foregroundStyle(Theme.fg)
                    Text(hasReview ? "區塊結束：看看每個部位的組數調整" : "教練幫你整理了上週的訓練")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.gold.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct WeeklySummaryView: View {
    @StateObject private var loader: WeeklyLoader
    let onDone: () -> Void

    init(facts: WeeklyFacts, onDone: @escaping () -> Void) {
        _loader = StateObject(wrappedValue: WeeklyLoader(facts: facts))
        self.onDone = onDone
    }

    private var facts: WeeklyFacts { loader.facts }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 2) {
                        Text("第 \(facts.week) 週總結")
                            .font(.title2.weight(.black))
                            .foregroundStyle(Theme.fg)
                        InfoTip(item: .weeklySummary)
                        Spacer()
                        if loader.reply != nil { sourceTag }
                    }
                    if let r = loader.reply {
                        Text(r.headline)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(Theme.fg)
                            .fixedSize(horizontal: false, vertical: true)
                        block("這週", icon: "calendar", color: Theme.green, text: r.highlight)
                        block("下週重點", icon: "arrow.up.forward.circle.fill", color: Theme.gold, text: r.nextTime)
                    } else {
                        HStack(spacing: 12) {
                            ProgressView().tint(Theme.accent)
                            Text("教練正在整理…").font(.headline).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                    }
                    if let review = facts.review { reviewSection(review) }
                    section("這週實際組數") {
                        VolumeTable(sets: facts.muscleSets, personal: !facts.custom)
                    }
                }
                .padding(20)
            }
            Button("好") { onDone() }
                .buttonStyle(HotButtonStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func reviewSection(_ review: BlockReview) -> some View {
        section("下個區塊的組數") {
            VStack(alignment: .leading, spacing: 10) {
                let changes = review.changes
                if changes.isEmpty {
                    Text("每個部位都維持原本的組數。").font(.subheadline).foregroundStyle(Theme.fg)
                }
                ForEach(changes) { d in
                    HStack(alignment: .top, spacing: 10) {
                        Text(d.change > 0 ? "+1" : "−1")
                            .font(Theme.number(15))
                            .foregroundStyle(d.change > 0 ? Theme.green : Theme.hotText)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(d.target?.name ?? d.muscle)：\(WeeklyFacts.changeText(d))")
                                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                            Text(d.reason).font(.caption).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                let kept = review.decisions.count - changes.count
                if kept > 0 && !changes.isEmpty {
                    Text("其他 \(kept) 個部位維持。").font(.caption).foregroundStyle(Theme.muted)
                }
                if facts.custom && !changes.isEmpty {
                    Text("你用的是自訂課表，App 不會自動改，可以照這個自己調整組數。")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.heavy)).foregroundStyle(Theme.fg)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
