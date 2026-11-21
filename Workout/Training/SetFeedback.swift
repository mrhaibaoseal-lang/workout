import SwiftUI

// 0.18.0 訓練中的回饋：每組判定（PERFECT／GOOD／MISS）、幽靈模式（和上次同一組比）、
// 訓練前狀態檢查、備註、術語說明。

// MARK: - 每組判定

enum SetGrade: String {
    case perfect, good, miss

    var title: String {
        switch self {
        case .perfect: "PERFECT"
        case .good: "GOOD"
        case .miss: "MISS"
        }
    }

    var color: Color {
        switch self {
        case .perfect: Theme.gold
        case .good: Theme.green
        case .miss: Theme.muted
        }
    }

    /// 只判定正式組。
    /// - PERFECT：做到這組的目標次數，而且還剩 1～2 下（沒填「還剩幾下」不能拿 PERFECT）
    /// - GOOD：達到次數下限（做到力竭、或太輕還剩 3 下以上，也只有 GOOD）
    /// - MISS：沒達到下限
    static func judge(reps: Int, rir: Int, target: Int, low: Int) -> SetGrade {
        let floor = min(low, target)
        if reps < floor { return .miss }
        if reps >= target && (1...2).contains(rir) { return .perfect }
        return .good
    }

    /// 判定後補一句為什麼（新手看得懂的話）
    static func reason(_ g: SetGrade, reps: Int, rir: Int, target: Int) -> String {
        switch g {
        case .perfect: return "次數做滿，還留 \(rir) 下力氣，剛剛好"
        case .miss: return "沒達到次數下限，下一組可以減一點重量"
        case .good:
            if rir < 0 { return "填「還剩幾下」才有機會拿 PERFECT" }
            if reps < target { return "差 \(target - reps) 下到目標" }
            if rir == 0 { return "做到力竭了，留 1～2 下就好" }
            return "還剩 \(rir) 下以上，可以加重了"
        }
    }
}

// MARK: - 幽靈模式

/// 和上次同一組比：同重量比次數，不同重量比推估最大力量。
struct GhostDelta {
    enum Trend { case ahead, even, behind }
    let trend: Trend
    let text: String

    var color: Color {
        switch trend {
        case .ahead: Theme.green
        case .even: Theme.accentSoft
        case .behind: Theme.hotText
        }
    }

    var icon: String {
        switch trend {
        case .ahead: "arrow.up.right"
        case .even: "equal"
        case .behind: "arrow.down.right"
        }
    }

    static func compare(weight: Double, reps: Int, last: LastSet, loaded: Bool, unit: String) -> GhostDelta {
        if !loaded || weight <= 0 || last.weight <= 0 || abs(weight - last.weight) < 0.01 {
            let d = reps - last.reps
            if d > 0 { return GhostDelta(trend: .ahead, text: "領先 \(d) \(unit)") }
            if d < 0 { return GhostDelta(trend: .behind, text: "落後 \(-d) \(unit)") }
            return GhostDelta(trend: .even, text: "平手")
        }
        let now = ExerciseRecords.e1RM(weight: weight, reps: reps)
        let then = ExerciseRecords.e1RM(weight: last.weight, reps: last.reps)
        let d = Progression.roundHalf(now - then)
        if d >= 0.5 { return GhostDelta(trend: .ahead, text: "領先，力量多約 \(Progression.format(d)) kg") }
        if d <= -0.5 { return GhostDelta(trend: .behind, text: "落後，力量少約 \(Progression.format(-d)) kg") }
        return GhostDelta(trend: .even, text: "力量差不多")
    }
}

/// 剛做完那一組的結果（休息頁顯示）
struct SetResult {
    let exerciseName: String
    let grade: SetGrade
    let reason: String
    let ghost: GhostDelta?
}

struct GradeMoment: Identifiable, Equatable {
    let id = UUID()
    let grade: SetGrade
    static func == (a: GradeMoment, b: GradeMoment) -> Bool { a.id == b.id }
    static let duration = 1.1
}

// MARK: - 訓練前狀態檢查

/// 睡眠、痠痛、精神各 1–5 分（都是越高越好：痠痛 5 = 完全不痠）。
struct Readiness: Equatable {
    var sleep: Int
    var soreness: Int
    var energy: Int

    var total: Int { sleep + soreness + energy }

    enum Level { case veryLow, low, normal, high }

    var level: Level {
        switch total {
        case ...5: .veryLow
        case ...8: .low
        case 13...: .high
        default: .normal
        }
    }

    /// 開訓練時顯示的說明；normal 不顯示
    var banner: String? {
        switch level {
        case .veryLow: "今天狀態很差（\(total)/15）：每個動作少 1 組，重量降一級。練完比練重要。"
        case .low: "今天狀態偏低（\(total)/15）：每個動作少 1 組，重量照舊。"
        case .high: "今天狀態很好（\(total)/15）：目標次數做滿後，可以試著多做 1 下。重量不自動加。"
        case .normal: nil
        }
    }

    /// 存進 WorkoutSession.readiness：「睡眠,痠痛,精神」
    var encoded: String { "\(sleep),\(soreness),\(energy)" }

    static func decode(_ raw: String) -> Readiness? {
        let v = raw.split(separator: ",").compactMap { Int($0) }
        guard v.count == 3 else { return nil }
        return Readiness(sleep: v[0], soreness: v[1], energy: v[2])
    }

    struct Question: Identifiable {
        let id: Int
        let title: String
        let icon: String
        /// 1～5 分的說明
        let labels: [String]
    }

    static let questions: [Question] = [
        Question(id: 0, title: "昨晚睡得好嗎？", icon: "moon.zzz.fill",
                 labels: ["很差", "不太好", "普通", "不錯", "很好"]),
        Question(id: 1, title: "身體痠痛嗎？", icon: "bandage.fill",
                 labels: ["很痠", "有點痠", "一點點", "幾乎不痠", "完全不痠"]),
        Question(id: 2, title: "現在精神怎麼樣？", icon: "bolt.fill",
                 labels: ["很累", "有點累", "普通", "不錯", "很好"])
    ]
}

// MARK: - 備註

/// 每個動作的備註，存成 JSON [exerciseId: 備註]。
enum ExerciseNotes {
    static func decode(_ raw: String) -> [String: String] {
        guard let data = raw.data(using: .utf8),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    static func encode(_ map: [String: String]) -> String {
        let clean = map.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !clean.isEmpty, let data = try? JSONEncoder().encode(clean) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// 上次這個動作寫的備註（最近一次有寫的那場）
    static func last(for exerciseId: String, in sessions: [WorkoutSession]) -> (note: String, date: Date)? {
        for s in sessions where !s.exerciseNotes.isEmpty {
            if let n = decode(s.exerciseNotes)[exerciseId], !n.isEmpty { return (n, s.date) }
        }
        return nil
    }
}

// MARK: - 歷史小圖

enum ExerciseTrend {
    /// 最近 8 次的推估最大力量（徒手動作用單組最多次數），舊的在前。
    static func points(for exerciseId: String, loaded: Bool, in sessions: [WorkoutSession]) -> [Double] {
        var out: [Double] = []
        for s in sessions {
            let sets = s.entries.filter { $0.exerciseId == exerciseId && $0.isWork }
            guard !sets.isEmpty else { continue }
            let v: Double = loaded
                ? sets.filter { $0.weight > 0 }.map { ExerciseRecords.e1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                : Double(sets.map(\.reps).max() ?? 0)
            if v > 0 { out.append(v) }
            if out.count == 8 { break }
        }
        return out.reversed()
    }
}

/// 簡單的折線小圖，最後一點加亮。
struct Sparkline: View {
    let values: [Double]
    var color: Color = Theme.accent

    var body: some View {
        GeometryReader { g in
            let w = Double(g.size.width), h = Double(g.size.height)
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = max(hi - lo, 0.001)
            let pts: [CGPoint] = values.enumerated().map { i, v in
                let x = values.count > 1 ? w * Double(i) / Double(values.count - 1) : w / 2
                let y = hi - lo < 0.001 ? h / 2 : h - 6 - (h - 12) * (v - lo) / span
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: f)
                    for q in pts.dropFirst() { p.addLine(to: q) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                ForEach(Array(pts.enumerated()), id: \.offset) { i, q in
                    Circle()
                        .fill(i == pts.count - 1 ? Theme.gold : color)
                        .frame(width: i == pts.count - 1 ? 9 : 5, height: i == pts.count - 1 ? 9 : 5)
                        .position(q)
                }
            }
        }
    }
}

// MARK: - 術語說明（ⓘ）

enum Glossary: String, Identifiable {
    case rir, grade, ghost, dropset, pyramid, readiness, record

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rir: "還剩幾下？"
        case .grade: "PERFECT／GOOD／MISS"
        case .ghost: "和上次比"
        case .dropset: "Drop set（遞減組）"
        case .pyramid: "遞增／遞減組"
        case .readiness: "訓練前狀態"
        case .record: "破紀錄"
        }
    }

    var text: String {
        switch self {
        case .rir:
            "做完這組，覺得硬拚還能再做幾下。做 10 下、還能再 2 下，就選 2。\n\n"
            + "每個正式組做完都填，熱身組不用。App 靠它決定下次加不加重：還剩 4 下以上會加重，"
            + "做到力竭又沒達到次數就減重。\n\n新手的目標是停在還剩 1～2 下，不用每組做到力竭。估不準沒關係，大概猜就好。"
        case .grade:
            "PERFECT：做到這組的目標次數，而且還剩 1～2 下。\n"
            + "GOOD：達到次數下限（做到力竭、或太輕還剩很多下，也是 GOOD）。\n"
            + "MISS：沒達到次數下限，下一組減一點重量。\n\n沒填「還剩幾下」最多只有 GOOD。"
        case .ghost:
            "和上次做這個動作時的同一組比（第 1 組比第 1 組）。重量一樣就比次數；"
            + "重量不一樣，就換算成推估的最大力量來比。"
        case .dropset:
            "最後一組做完，馬上換輕一點的重量再做到力竭，中間不休息。新手期 App 不會排，"
            + "之後設定成「自動」時，App 會在適合的時候排在最後一組。你不用自己決定。"
        case .pyramid:
            "遞增：每組加重、次數變少。遞減：第一組最重，之後減重、次數變多。"
            + "新手用「自動」就好，App 會用固定重量，之後再自己調。"
        case .readiness:
            "睡眠、痠痛、精神三題，各 1～5 分。分數低，App 會每個動作少做 1 組（很低再降一級重量）；"
            + "分數高只提醒你可以多做 1 下，不會自動加重。"
        case .record:
            "這個動作做過最重的一次。第一次做不算，之後超過以前的最高重量就會跳「破紀錄」。你不用做任何事，App 會自己記。"
        }
    }
}

/// 術語旁邊的小 ⓘ，點開看白話說明。
struct InfoTip: View {
    let item: Glossary
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "info.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("說明：\(item.title)")
        .alert(item.title, isPresented: $show) {
            Button("懂了") {}
        } message: {
            Text(item.text)
        }
    }
}
