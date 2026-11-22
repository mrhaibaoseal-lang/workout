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
    case rir, grade, ghost, dropset, pyramid, readiness, record, superset
    case weeklySets, bigJump, fixedCompound, personalSets, weeklySummary
    case startWeight, comeback, mergeDay, fatigue, graduation
    case focus, specialization

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
        case .superset: "超級組／循環組"
        case .weeklySets: "每週組數"
        case .bigJump: "重量跳太大"
        case .fixedCompound: "為什麼主要動作不常換"
        case .personalSets: "個人組數"
        case .weeklySummary: "每週總結"
        case .startWeight: "第一次做的重量"
        case .comeback: "停練回來"
        case .mergeDay: "併成全身日"
        case .fatigue: "疲勞決定減量時機"
        case .graduation: "新手畢業到中階"
        case .focus: "重點部位（弱點加強）"
        case .specialization: "手臂／肩膀專項期"
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
        case .superset:
            "2 個動作輪流做叫超級組，3～4 個叫循環組：A 做一組、馬上做 B 一組，一輪做完才休息。"
            + "主要是省時間，肌肉不會長得比較快。只配手臂、肩膀、小腿、核心這類單關節動作。\n\n"
            + "同一組的動作會盡量用不同器材（例如一個用快鎖啞鈴、一個用舊啞鈴或下拉架），輪流做才不用一直換重量。"
        case .weeklySets:
            "把這週課表裡，每個部位會練到的正式組加起來。主要動作練到的部位算 1 組，次要出力的部位算半組"
            + "（例如臥推主要練胸，三頭和前肩各算 0.5 組）。\n\n"
            + "增肌常見的建議是每個部位每週 10～16 組：太少長得慢，太多恢復不了。小腿、後肩、腹肌這類比較小的部位，至少 6 組就有感。"
            + "顏色橘／黃 = 還不夠，綠 = 剛好，藍 = 偏多。這只是預估，實際以你練完的紀錄為準。"
        case .bigJump:
            "啞鈴最小只能加 2.5 kg，輕的動作（例如側平舉從 5 kg 加到 7.5 kg）一次就重 50%，加上去次數會掉到很少，也比較容易受傷。\n\n"
            + "所以 App 先估一下加重後你大概能做幾下：夠多就直接加重；太少就先把次數上限拉長（側平舉最多到 25 下、大動作 15 下），"
            + "做到了再多加 1 組，最後才加重，並暫時用比較少的次數慢慢爬回原本的範圍。"
        case .fixedCompound:
            "臥推、划船、深蹲這類大動作需要練很多次才會熟，新手進步最快的就是「同一個動作越練越重」。"
            + "所以大動作不會每 6 週自動換，會一直練到卡住（停滯）、會痛、或你自己想換才換。\n\n"
            + "手臂、肩膀這類單關節動作比較單純，還是每 6 週換一批，避免太無聊。"
        case .personalSets:
            "每個人適合的組數不一樣。練完 App 會問今天練到的部位：上次的痠痛退了沒、關節舒不舒服，點一下就好。\n\n"
            + "每 6 週（一個區塊）結束時，App 看每個部位相關動作的推估最大力量進步多少，再配合你的回報：\n"
            + "・進步慢、恢復得好 → 每次多練 1 組\n"
            + "・進步慢、常常還在痠或會痛 → 每次少練 1 組\n"
            + "・進步正常 → 不變\n\n"
            + "調整會記住，下個區塊從這裡開始。內建課表會自動照著排；自訂課表不會自動改，只在每週總結裡建議。"
        case .weeklySummary:
            "每週一開始，總結上週練了幾次、每個部位實際練了幾組、破了哪些紀錄、哪些動作卡住。"
            + "區塊結束的那週，還會列出每個部位的組數調整和理由。\n\n"
            + "數字都是 App 算的；有 Apple Intelligence 時由 AI 寫成白話，沒有就自動整理。"
        case .startWeight:
            "第一次做的動作，App 會找你做過、練到同一個部位的動作（例如做過啞鈴臥推，就拿來推估上斜臥推），"
            + "照兩個動作平常的重量比例換算，再打 9 折、取你的器材裝得出來的重量。\n\n"
            + "第一組是試重組：做完一定要填「還剩幾下」，App 會用這組重新算，把後面的組調到還剩 2 下左右的重量，"
            + "一次可以跳好幾級。找不到相近的動作時，就自己挑一個輕鬆的重量，一樣靠第一組校準。"
        case .comeback:
            "隔 10 天以上沒練，力量和耐受度會掉一點，直接用原本的重量容易受傷或痠很久。\n\n"
            + "・停 10～20 天：每個動作回來第一次，重量減 10%\n"
            + "・停 21 天以上：減 20%，而且回來那一週當適應期（少 1 組、不拚力竭）\n\n"
            + "肌肉記憶回來得很快：減重後只要全部做到次數，下次就直接回到停練前的重量，不用一級一級爬。請假的日子也算在停練天數裡。"
        case .mergeDay:
            "這週剩下能練的天數，排不完課表剩下的天時，App 會建議把幾天併成一天全身日，每個部位至少練到一次。\n\n"
            + "全身日挑每天的主要動作，同一個部位已經有動作練到就不重複，再補側平舉、手臂、後肩這類小部位，"
            + "每個動作 2～3 組，比平常長一點。併了之後，剩下的天照原本的課表；下週從第一天重新開始。"
        case .fatigue:
            "減量週本來固定每 6 週一次。現在 App 會看最近 2 週的疲勞，決定提早還是延後：\n\n"
            + "・訓練前狀態比你平常低 2 分以上\n"
            + "・同一個重量，能做的下數（次數＋還剩幾下）少了 2 下以上\n"
            + "・做到力竭（還剩 0 下）的組變多\n"
            + "・練完回報「還在痠」變多\n"
            + "・好幾個動作連續沒進步\n\n"
            + "有 2 項以上就建議提早減量（至少練滿 3 個進步週）。到了減量週，如果狀態好、主要動作還在進步，"
            + "可以延後 1 週，最多延 2 次。都會先問你。"
        case .graduation:
            "新手每次做到次數上限就加重，進步很快。練了一段時間後，主要動作會加不上去，這時換中階排法：\n\n"
            + "・主要動作一天練重（6–8 下、休息久一點）、一天練輕（12–15 下）\n"
            + "・區塊裡每 2 週，每個部位每次多練 1 組\n"
            + "・啞鈴到頂的重日，改慢速或單側版本\n\n"
            + "條件：至少練滿 12 週（一週 2 次以上）、減量後主要動作六成以上還是 3 週沒進步。"
            + "剛換範圍時，App 會用推估最大力量換算第一次的重量。設定裡可以切回新手。"
        case .focus:
            "每個部位長得快慢不一樣。App 看最近 12 週每個部位的重量進步（推估最大力量），"
            + "明顯比其他部位慢的就是弱點：不到中位數的一半，而且差 3 個百分點以上。\n\n"
            + "列為重點部位後，每週多練 2 組（一週練 2 次，等於每次多 1 組），加在練它的單關節動作上。"
            + "最多選 2 個，選太多等於沒有重點。每個區塊問一次，設定 →「重點部位與專項期」可以自己改。"
        case .specialization:
            "一段時間集中練手臂和肩膀，其他部位先維持：\n\n"
            + "・下半身日多排側平舉、後肩、二頭、三頭，一週練到 4 次\n"
            + "・側肩、後肩、二頭、三頭每週再多 2 組\n"
            + "・胸、背、腿每週少 2 組（這個量還是會維持住）\n\n"
            + "長度是一個完整區塊（約 5 個進步週＋減量週），結束後自動回到原本的排法。"
            + "手肘、肩膀的關節負擔比較大，建議隔一個區塊以上再開下一次。"
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
