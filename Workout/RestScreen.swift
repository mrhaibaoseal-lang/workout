import SwiftUI
import AudioToolbox

/// 上次同一組的成績
struct LastSet {
    let weight: Double
    let reps: Int
}

/// 休息時要換的一組器材：從現在裝的樣子換成下一組要的樣子。
struct RigChange: Identifiable {
    let id = UUID()
    /// 「換重量」「下一個動作（啞鈴肩推）」「順便裝好 Drop set」
    let label: String
    let kit: String
    let use: WeightKits.Use
    /// 現在每邊的槓片；nil = 不知道（這場還沒用過，當作空把手）
    let from: [Double]?
    let to: [Double]
    let seconds: Int
    /// 啞鈴↔槓鈴要組裝或拆開
    let assemble: Bool

    var target: RigState { RigState(use: use, plates: to) }

    /// 要拿掉的、要加上的（每邊）
    var removed: [Double] { diff(from ?? [], to).removed }
    var added: [Double] { diff(from ?? [], to).added }

    private func diff(_ a: [Double], _ b: [Double]) -> (removed: [Double], added: [Double]) {
        var rest = a
        var add: [Double] = []
        for p in b {
            if let i = rest.firstIndex(where: { abs($0 - p) < 0.01 }) { rest.remove(at: i) } else { add.append(p) }
        }
        return (rest, add)
    }

    var useText: String {
        switch use {
        case .pair: "兩支啞鈴，每支的兩邊都一樣"
        case .single: "一支啞鈴，兩邊一樣"
        case .barbell: "槓鈴，兩邊一樣"
        case .cable: "下拉架，全部掛上去"
        }
    }

    /// 鎖定畫面用的短版
    var short: String {
        let list = to.isEmpty ? "只有把手" : to.map(Progression.format).joined(separator: " + ")
        return "\(label)：" + (use == .cable ? "掛 \(list)" : "每邊 \(list)")
    }

    /// 一行文字版（通知、縮小的休息卡用）
    var text: String {
        let list = to.isEmpty ? "只有把手" : to.map(Progression.format).joined(separator: " + ")
        let how = use == .cable ? "掛 \(list)" : "每邊 \(list)"
        return "\(label)：\(kit) \(how)（約 \(seconds) 秒）"
    }
}

/// 休息頁要顯示的下一組
struct RestNext {
    let exercise: Exercise
    /// 「第 2 組」「熱身組」「遞減組」
    let tag: String
    let ladder: WeightLadder
    let last: LastSet?
    /// 下一組是不是換到下一個動作
    let newExercise: Bool
}

/// 每個動作的重點：動作本身的提示＋同一類動作通用的 1–2 句。
enum ExerciseCues {
    static func cues(for ex: Exercise) -> [String] {
        Array(([ex.tip] + (byPattern[ex.pattern] ?? [])).prefix(3))
    }

    private static let byPattern: [MovementPattern: [String]] = [
        .hPush: ["下放 2 秒、推起 1 秒，不要在底部反彈", "推起時吐氣，肩膀不要聳起來"],
        .incline: ["手肘和身體約 45 度，不要整個打開", "推起時想像兩手往中間靠攏"],
        .vPush: ["肋骨往下收，不要拱腰往後倒", "推起吐氣，推到頂時頭在兩手之間"],
        .hPull: ["先把肩胛往後收，再用手肘往後拉", "放回去慢 2 秒，感覺背被拉長"],
        .vPull: ["肩膀先往下壓，不要聳肩", "拉到底停 1 秒，再慢慢放回去"],
        .squat: ["膝蓋和腳尖同方向，不要往內夾", "整個腳掌踩穩，用腳跟推地站起來"],
        .hinge: ["想著屁股往後推，不是彎腰", "大腿後側有拉緊感就停，背不要圓"],
        .lunge: ["前腳膝蓋對準腳尖，身體直上直下", "用前腳腳跟推回來"],
        .glute: ["頂到最高點夾臀停 1 秒", "下巴微收，肋骨不要往上翻"],
        .hamCurl: ["屁股不要翹起來借力", "放回去慢 2–3 秒"],
        .quadIso: ["最高點停 1 秒，大腿前側出力", "放回去要慢，不要甩"],
        .calf: ["最低點拉長停 1 秒", "踮到最高再慢慢放下"],
        .biceps: ["手肘固定在身側，身體不要晃", "放下要慢，手臂快打直才算一下"],
        .triceps: ["上臂固定不動，只動前臂", "打直時用力夾 1 秒"],
        .lateral: ["手肘微彎帶動，抬到肩膀高就好", "不要聳肩，放下慢一點"],
        .rear: ["用後肩把手往兩側打開，不是夾背", "重量輕一點，動作做清楚"],
        .core: ["腰不要塌，身體保持一直線", "穩定呼吸，不要憋氣"],
    ]
}

// MARK: - 全螢幕休息頁

/// 休息時蓋滿整個畫面：大圓環倒數、下一組（可以直接改重量）、換重量圖解、動作要點。
struct RestScreen: View {
    let end: Date
    let total: Double
    let next: RestNext?
    @Binding var nextSet: SetDraft
    let changes: [RigChange]
    /// 為什麼休息這麼久（「力竭了，多休息 30 秒」）
    let reasons: [String]
    /// 目前連擊（休息結束後準時開始下一組的次數）
    var combo: Int = 0
    let onAdd: () -> Void
    let onSkip: () -> Void
    let onMinimize: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var inventory: InventoryStore

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                        let left = end.timeIntervalSince(ctx.date)
                        VStack(spacing: 12) {
                            HStack(spacing: 6) {
                                character(left: left)
                                if left > 0 {
                                    countdown(left: left, now: ctx.date)
                                } else {
                                    doneButton(over: -left)
                                }
                            }
                            .frame(height: 214)
                            footer(left: left)
                        }
                    }
                    .frame(height: 290)
                    if !reasons.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(reasons, id: \.self) { r in
                                Label(r, systemImage: "info.circle").font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    // 換重量放最上面：休息一開始就要動手
                    ForEach(changes) { c in
                        PlateChangeCard(change: c)
                    }
                    if let next {
                        nextCard(next)
                    }
                    if let next {
                        cuesCard(next.exercise)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(
            ZStack {
                Theme.bg
                RadialGradient(colors: [Theme.accent.opacity(0.18), .clear], center: .top, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        )
        .modifier(SecondTicks(end: end))
    }

    private var header: some View {
        HStack {
            Button(action: onMinimize) {
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundStyle(Theme.fg)
                    .frame(width: 44, height: 44)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel("縮小休息頁，回到課表")
            Spacer()
            if combo > 0 {
                Label("連擊 ×\(combo)", systemImage: "flame.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 12).frame(height: 34)
                    .background(Theme.goldBg, in: Capsule())
                    .overlay(Capsule().stroke(Theme.gold.opacity(0.6), lineWidth: 1))
            } else {
                Text("休息").font(.headline.weight(.heavy)).foregroundStyle(Theme.fg)
            }
            Spacer()
            Button("跳過", action: onSkip)
                .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: 倒數

    private func countdown(left: Double, now: Date) -> some View {
        let warm = FXMath.seg(10 - left, 0, 7)
        let col = FXMath.mix(Theme.green, Theme.hot, warm)
        let last3 = left < 3
        let beat = last3 && !reduceMotion ? 1 + 0.06 * pow(max(0, sin(.pi * FXMath.fract(left))), 4) : 1
        let p = left / max(total, 1)
        return ZStack {
                Circle().fill(col.opacity(last3 ? 0.10 : 0.05)).padding(14)
                Ring(progress: p, color: col, lineWidth: 14)
                GeometryReader { g in
                    let w = Double(g.size.width), h = Double(g.size.height)
                    let r = w / 2 - 14
                    let a = -Double.pi / 2 + 2 * Double.pi * p
                    Circle().fill(.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: col, radius: 10)
                        .position(x: w / 2 + r * cos(a), y: h / 2 + r * sin(a))
                }
                VStack(spacing: 2) {
                    Text(last3 ? "準備！" : "休息中")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(last3 ? col : Theme.muted)
                    Text(timerInterval: now...end, countsDown: true)
                        .font(Theme.number(54))
                        .monospacedDigit()
                        .foregroundStyle(last3 ? col : Theme.fg)
                    Text("共 \(Int(total)) 秒").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 210, height: 210)
            .scaleEffect(beat)
            .shadow(color: col.opacity(last3 ? 0.55 : 0.15), radius: last3 ? 22 : 12)
            .frame(maxWidth: .infinity)
    }

    private func doneButton(over: Double) -> some View {
        let pop = reduceMotion ? 1 : 1 + 0.08 * exp(-over * 5) * cos(over * 16)
        let glow = reduceMotion ? 0.5 : 0.4 + 0.3 * sin(over * 5)
        return Button(action: onSkip) {
            VStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 42, weight: .black))
                Text("休息結束").font(.title2.weight(.black))
                Text("點一下開始下一組").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Theme.bg)
            .frame(width: 210, height: 210)
            .background(Circle().fill(Theme.green))
            .shadow(color: Theme.green.opacity(glow), radius: 26)
        }
        .buttonStyle(.plain)
        .scaleEffect(pop)
        .frame(maxWidth: .infinity)
    }

    // MARK: 角色和連擊

    /// 休息中角色在旁邊喘氣、每隔一陣子喝口水，最後 3 秒擺出準備姿勢。
    private func character(left: Double) -> some View {
        let move: CharacterMove
        if left <= 3 {
            move = .ready
        } else {
            let cycle = (total - left).truncatingRemainder(dividingBy: 18)
            move = cycle >= 10 && cycle < 15.2 ? .drink : .breathe
        }
        return CharacterView(move: move, loadout: inventory.state.loadout, animated: !reduceMotion, showStats: false)
            .id(move)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: move)
            .frame(width: 128)
    }

    /// 倒數時是 +30 秒；時間到後顯示「幾秒內開始可以接上連擊」。
    @ViewBuilder
    private func footer(left: Double) -> some View {
        if left > 0 {
            Button("+30 秒", action: onAdd)
                .buttonStyle(GhostButtonStyle())
                .frame(width: 120)
        } else {
            let over = -left
            let rest = max(0, RestScreen.comboWindow - over)
            VStack(spacing: 6) {
                if rest > 0 {
                    Text(combo > 0 ? "\(Int(ceil(rest))) 秒內開始 → 連擊 ×\(combo + 1)" : "\(Int(ceil(rest))) 秒內開始 → 開始連擊")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(Theme.gold)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.line)
                            Capsule().fill(Theme.gold).frame(width: g.size.width * rest / RestScreen.comboWindow)
                        }
                    }
                    .frame(width: 220, height: 6)
                } else {
                    Text(combo > 0 ? "超過 \(Int(over)) 秒，連擊 ×\(combo) 會中斷" : "超過 \(Int(over)) 秒")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 44)
        }
    }

    /// 休息結束後幾秒內開始下一組算準時
    static let comboWindow: Double = 15

    // MARK: 下一組

    private func nextCard(_ n: RestNext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(n.newExercise ? "下一個動作" : "下一組")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.hotText)
                Spacer()
                if let last = n.last {
                    Text("上次這一組：" + lastText(last, n.exercise))
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(n.exercise.name).font(.title3.weight(.black)).foregroundStyle(Theme.fg)
                Text(n.tag).font(.subheadline.weight(.bold)).foregroundStyle(Theme.accentSoft)
            }
            HStack(spacing: 10) {
                if n.exercise.loaded {
                    stepper(value: "\(Progression.format(nextSet.weight))", unit: "kg",
                            minus: { nextSet.weight = n.ladder.down(nextSet.weight) },
                            plus: { nextSet.weight = n.ladder.up(nextSet.weight) },
                            labels: ("減少重量", "增加重量"))
                }
                let step = n.exercise.unit == .seconds ? 5 : 1
                stepper(value: "\(nextSet.reps)", unit: n.exercise.unit.label,
                        minus: { nextSet.reps = max(0, nextSet.reps - step) },
                        plus: { nextSet.reps = min(300, nextSet.reps + step) },
                        labels: ("減少次數", "增加次數"))
            }
            if let last = n.last, n.exercise.loaded, nextSet.weight > 0 {
                compare(last)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hotLine, lineWidth: 1))
    }

    private func lastText(_ l: LastSet, _ ex: Exercise) -> String {
        ex.loaded && l.weight > 0 ? "\(Progression.format(l.weight)) kg × \(l.reps)" : "\(l.reps) \(ex.unit.label)"
    }

    private func compare(_ last: LastSet) -> some View {
        let d = nextSet.weight - last.weight
        let text: String
        let color: Color
        if d > 0.01 { text = "比上次重 \(Progression.format(d)) kg 💪"; color = Theme.hotText }
        else if d < -0.01 { text = "比上次輕 \(Progression.format(-d)) kg"; color = Theme.muted }
        else { text = nextSet.reps > last.reps ? "同重量，目標多做 \(nextSet.reps - last.reps) 下" : "和上次一樣重"; color = Theme.accentSoft }
        return Text(text).font(.caption.weight(.bold)).foregroundStyle(color)
    }

    private func stepper(value: String, unit: String, minus: @escaping () -> Void, plus: @escaping () -> Void,
                         labels: (String, String)) -> some View {
        HStack(spacing: 0) {
            stepButton("minus", label: labels.0, action: minus)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Theme.number(24)).foregroundStyle(Theme.fg)
                Text(unit).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            stepButton("plus", label: labels.1, action: plus)
        }
        .padding(4)
        .frame(maxWidth: .infinity)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Theme.fg)
                .frame(width: 44, height: 44)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: 動作要點

    private func cuesCard(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("動作要點").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
            ForEach(Array(ExerciseCues.cues(for: ex).enumerated()), id: \.offset) { i, cue in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1)")
                        .font(Theme.number(12))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 20, height: 20)
                        .background(Theme.accent, in: Circle())
                    Text(cue).font(.subheadline).foregroundStyle(Theme.fg)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - 換重量圖解

/// 一組器材的換法：上排是現在每邊裝的槓片（要拆的打叉），下排是換好的樣子（新加的發亮）。
struct PlateChangeCard: View {
    let change: RigChange

    var body: some View {
        let removed = change.removed
        let added = change.added
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(change.label, systemImage: "arrow.left.arrow.right")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.hotText)
                Spacer()
                Text("約 \(change.seconds) 秒").font(Theme.number(13, .bold)).foregroundStyle(Theme.muted)
            }
            Text("\(change.kit) · \(change.useText)").font(.caption).foregroundStyle(Theme.muted)
            if change.assemble {
                Label(change.use == .barbell ? "先把兩支把手接成槓鈴" : "先把槓鈴拆回兩支把手",
                      systemImage: "wrench.adjustable.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.gold)
            }
            row(title: change.from == nil ? "空把手" : "現在", plates: change.from ?? [], marked: removed, mode: .remove)
            Image(systemName: "arrow.down").font(.caption.weight(.heavy)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
            row(title: "換成", plates: change.to, marked: added, mode: .add)
            summary(removed: removed, added: added)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private enum Mode { case remove, add }

    /// 一邊的槓片：左邊是把手，往右由重到輕（靠把手的最重）。
    private func row(title: String, plates: [Double], marked: [Double], mode: Mode) -> some View {
        var pool = marked
        let flags: [Bool] = plates.map { p in
            if let i = pool.firstIndex(where: { abs($0 - p) < 0.01 }) { pool.remove(at: i); return true }
            return false
        }
        return HStack(spacing: 10) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.muted).frame(width: 40, alignment: .leading)
            HStack(alignment: .center, spacing: 3) {
                // 把手（或槓）
                Capsule().fill(Theme.muted.opacity(0.7)).frame(width: 46, height: 14)
                if change.use != .cable {
                    RoundedRectangle(cornerRadius: 3).fill(Theme.muted).frame(width: 7, height: 32)
                }
                ForEach(Array(plates.enumerated()), id: \.offset) { i, kg in
                    PlateShape(kg: kg, state: flags[i] ? (mode == .remove ? PlateShape.Mark.remove : .add) : .keep)
                }
                if plates.isEmpty {
                    Text("不裝槓片").font(.caption2).foregroundStyle(Theme.muted)
                }
                Capsule().fill(Theme.muted.opacity(0.5)).frame(width: 20, height: 12)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 110)
    }

    private func summary(removed: [Double], added: [Double]) -> some View {
        func group(_ list: [Double]) -> String {
            var counts: [(Double, Int)] = []
            for p in list.sorted(by: >) {
                if let i = counts.firstIndex(where: { abs($0.0 - p) < 0.01 }) { counts[i].1 += 1 } else { counts.append((p, 1)) }
            }
            return counts.map { "\(Progression.format($0.0)) kg ×\($0.1)" }.joined(separator: "、")
        }
        let per = change.use == .cable ? "" : (change.use == .pair ? "（每支每邊）" : "（每邊）")
        var parts: [String] = []
        if !removed.isEmpty { parts.append("拆 " + group(removed)) }
        if !added.isEmpty { parts.append("加 " + group(added)) }
        return Text(parts.isEmpty ? "槓片不用動" : parts.joined(separator: "，") + per)
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.fg)
    }
}

/// 一片槓片：越重越大、顏色不同；要拆的打叉變暗，要加的發亮。
struct PlateShape: View {
    enum Mark { case keep, remove, add }
    let kg: Double
    let state: Mark

    private var height: CGFloat {
        switch kg {
        case ..<1.3: 45
        case ..<2.6: 63
        case ..<3.1: 72
        case ..<5.1: 84
        default: 96
        }
    }

    private var width: CGFloat { kg < 1.3 ? 14 : (kg < 3.1 ? 18 : 22) }

    private var color: Color {
        switch kg {
        case ..<1.3: Color(gearHex: "#6FB7FF")
        case ..<2.6: Color(gearHex: "#5BD69A")
        case ..<3.1: Color(gearHex: "#F2C14E")
        case ..<5.1: Color(gearHex: "#FF8757")
        default: Color(gearHex: "#FF5A6E")
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color.opacity(state == .remove ? 0.25 : 1))
                    .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(state == .add ? .white : .black.opacity(0.35), lineWidth: state == .add ? 2 : 1))
                    .shadow(color: state == .add ? color : .clear, radius: 6)
                if state == .remove {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Color(gearHex: "#FF5A6E"))
                }
            }
            .frame(width: width, height: height)
            Text(Progression.format(kg))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(state == .remove ? Color(gearHex: "#FF5A6E") : (state == .add ? Theme.green : Theme.muted))
                .fixedSize()
                .frame(width: max(width, 24))
        }
        .accessibilityLabel("\(Progression.format(kg)) 公斤" + (state == .remove ? "，拆掉" : state == .add ? "，加上" : ""))
    }
}

// MARK: - 震動和聲音

/// 最後 3 秒每秒震一下、響一聲，時間到再震一下。
struct SecondTicks: ViewModifier {
    let end: Date
    @State private var fired: Set<Int> = []

    func body(content: Content) -> some View {
        content.background {
            TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
                let left = Int(ceil(end.timeIntervalSince(ctx.date)))
                Color.clear.onChange(of: left) { _, n in
                    guard n <= 3, n >= 0, !fired.contains(n) else { return }
                    fired.insert(n)
                    if n == 0 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        AudioServicesPlaySystemSound(1005)
                    } else {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        AudioServicesPlaySystemSound(1057)
                    }
                }
            }
        }
        .onChange(of: end) { fired = [] }
    }
}

// MARK: - 連擊特效

struct ComboMoment: Identifiable, Equatable {
    let id = UUID()
    let combo: Int
    static let duration = 1.3
}

/// 準時開始下一組：「連擊 ×N」從中間彈出、噴星星，越高越華麗（5、10 連擊加光環）。
struct ComboBurstView: View {
    let moment: ComboMoment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSince(start)
            let n = moment.combo
            let big = n >= 10 ? 2 : (n >= 5 ? 1 : 0)
            let col = big == 2 ? Theme.hot : Theme.gold
            let fade = 1 - FXMath.seg(t, ComboMoment.duration - 0.35, ComboMoment.duration)
            GeometryReader { geo in
                let c = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.34)
                ZStack {
                    if !reduceMotion {
                        Canvas { g, _ in
                            FX.glow(&g, center: c, radius: 150 + 40 * Double(big), color: col, alpha: 0.35 * fade)
                            if big > 0 {
                                FX.ring(&g, center: c, progress: FXMath.seg(t, 0, 0.6), maxRadius: 220, color: col)
                            }
                            FX.sparkBurst(&g, center: c, tau: t, count: 14 + 10 * big, speed: 260 + 80 * Double(big),
                                          colors: [col, .white, Theme.gold])
                        }
                    }
                    VStack(spacing: -4) {
                        Text("COMBO")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .tracking(4)
                            .foregroundStyle(.white)
                        Text("×\(n)")
                            .font(.system(size: 72 + 8 * CGFloat(big), weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.white, col], startPoint: .top, endPoint: .bottom))
                            .shadow(color: col.opacity(0.8), radius: 14)
                        Text(n >= 10 ? "停不下來！" : (n >= 5 ? "節奏超穩！" : "準時開練"))
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(col)
                    }
                    .scaleEffect(reduceMotion ? 1 : 0.4 + 0.6 * FXMath.easeOutBack(FXMath.seg(t, 0, 0.3)))
                    .position(c)
                }
                .opacity(fade)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            UIImpactFeedbackGenerator(style: moment.combo >= 5 ? .heavy : .medium).impactOccurred()
            if moment.combo >= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}

