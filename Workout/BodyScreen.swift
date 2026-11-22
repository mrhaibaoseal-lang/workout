import SwiftUI
import SwiftData
import Charts

/// 身體數據的項目。不拍照，只記數字，再用畫出來的身形圖和曲線看變化。
enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, bodyFat, shoulders, chest, arm, waist, hips, thigh, calf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "體重"
        case .bodyFat: "體脂"
        case .shoulders: "肩寬（圍）"
        case .chest: "胸圍"
        case .arm: "上臂圍"
        case .waist: "腰圍"
        case .hips: "臀圍"
        case .thigh: "大腿圍"
        case .calf: "小腿圍"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .bodyFat: "%"
        default: "cm"
        }
    }

    var keyPath: ReferenceWritableKeyPath<BodyLog, Double> {
        switch self {
        case .weight: \.weight
        case .bodyFat: \.bodyFat
        case .shoulders: \.shoulders
        case .chest: \.chest
        case .arm: \.arm
        case .waist: \.waist
        case .hips: \.hips
        case .thigh: \.thigh
        case .calf: \.calf
        }
    }

    /// 增肌時往哪個方向是好事：腰圍、體脂變小是好事，其他變大是好事。
    var upIsGood: Bool { self != .waist && self != .bodyFat }

    var howTo: String {
        switch self {
        case .weight: "早上起床、上完廁所、吃東西前量，最準。"
        case .bodyFat: "體脂計或 InBody 的數字，沒有可以不填。"
        case .shoulders: "雙手自然垂下，皮尺繞過兩邊肩膀最寬的地方。"
        case .chest: "吐氣後，皮尺繞過乳頭高度，保持水平。"
        case .arm: "手臂放鬆垂下，量上臂最粗的地方（慣用手）。"
        case .waist: "肚臍高度，自然吐氣、不要縮小腹。"
        case .hips: "屁股最翹的地方，雙腳併攏。"
        case .thigh: "站直，量大腿最粗的地方（臀線下方）。"
        case .calf: "站直，量小腿最粗的地方。"
        }
    }

    func value(_ log: BodyLog) -> Double? {
        let v = log[keyPath: keyPath]
        return v > 0 ? v : nil
    }
}

struct BodyScreen: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyLog.date) private var logs: [BodyLog]
    @AppStorage(Keys.height) private var height = 0.0
    @State private var metric: BodyMetric = .weight
    @State private var showEntry = false
    @State private var editing: BodyLog?

    private var first: BodyLog? { logs.first }
    private var latest: BodyLog? { logs.last }

    /// 某個項目第一次和最近一次有填的數字
    private func range(_ m: BodyMetric) -> (first: Double, last: Double)? {
        let vals = logs.compactMap { m.value($0) }
        guard let f = vals.first, let l = vals.last else { return nil }
        return (f, l)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                header
                NutritionCard(weights: logs.filter { $0.weight > 0 }.map { (date: $0.date, weight: $0.weight) })
                figureCard
                if !logs.isEmpty {
                    tiles
                    chartCard
                    historyCard
                } else {
                    Text("量一次就會畫出你的身形圖。之後每 2–4 週量一次，圖會跟著你的圍度變化，第一次的輪廓用虛線疊在後面對照。不用拍照。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accentSoft)
                        .themeCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .themeScreen()
        .navigationTitle("身體數據")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEntry) {
            BodyEntrySheet(previous: latest, log: nil)
        }
        .sheet(item: $editing) { log in
            BodyEntrySheet(previous: nil, log: log)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("身體數據").font(.system(size: 26, weight: .black)).foregroundStyle(Theme.fg)
                Text(latest.map { "上次量：\($0.date.formatted(.dateTime.month(.defaultDigits).day()))" } ?? "還沒量過")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { showEntry = true } label: {
                Label("量一次", systemImage: "ruler")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.top, 8)
    }

    // MARK: 身形圖

    private var figureCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("身形變化").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                if logs.count > 1 {
                    HStack(spacing: 10) {
                        legend(dashed: true, "第一次")
                        legend(dashed: false, "現在")
                    }
                }
            }
            BodyFigure(scales: scales, ghost: logs.count > 1, labels: figureLabels)
                .frame(height: 400)
                .frame(maxWidth: .infinity)
            Text(logs.count > 1
                 ? "圍度的變化放大 3 倍畫出來，比較看得出差別。綠色＝往好的方向。"
                 : "這是依你的數字畫的基準身形，之後量的會疊上來比較。")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    private func legend(dashed: Bool, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(dashed ? Theme.muted : Theme.accent, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 2] : []))
                .frame(width: 14, height: 8)
            Text(text).font(.caption2).foregroundStyle(Theme.muted)
        }
    }

    /// 每個部位相對第一次的比例（放大 3 倍、限制範圍）。沒量的部位用體重變化估一點點。
    private var scales: BodyFigure.Scales {
        func s(_ m: BodyMetric) -> Double {
            if let r = range(m), r.first > 0 {
                return min(1.35, max(0.75, 1 + (r.last / r.first - 1) * 3))
            }
            if let r = range(.weight), r.first > 0 {
                return min(1.15, max(0.9, 1 + (r.last / r.first - 1) * 1.5))
            }
            return 1
        }
        return .init(shoulders: s(.shoulders), chest: s(.chest), arm: s(.arm), waist: s(.waist),
                     hips: s(.hips), thigh: s(.thigh), calf: s(.calf))
    }

    private var figureLabels: [BodyFigure.Callout] {
        let parts: [(BodyMetric, Double, Bool)] = [
            (.shoulders, 84, false), (.chest, 108, true), (.arm, 128, false),
            (.waist, 186, true), (.hips, 222, false), (.thigh, 256, true), (.calf, 346, false),
        ]
        return parts.compactMap { (m, y, right) -> BodyFigure.Callout? in
            guard let r = range(m) else { return nil }
            let d = r.last - r.first
            let text = logs.count > 1 && abs(d) >= 0.1
                ? "\(m.title.prefix(2)) \(d > 0 ? "+" : "")\(fmt(d))"
                : "\(m.title.prefix(2)) \(fmt(r.last))"
            let good: Bool? = abs(d) < 0.1 ? nil : ((d > 0) == m.upIsGood)
            return BodyFigure.Callout(text: text, y: y, right: right, good: good)
        }
    }

    // MARK: 數字

    private var tiles: some View {
        let w = range(.weight)
        let ratio: Double? = {
            guard let l = latest, let sh = BodyMetric.shoulders.value(l) ?? BodyMetric.chest.value(l),
                  let wa = BodyMetric.waist.value(l) else { return nil }
            return sh / wa
        }()
        return HStack(spacing: 8) {
            tile(w.map { fmt($0.last) } ?? "—", unit: "kg", "體重", sub: weightDelta)
            if height > 0, let w {
                let bmi = w.last / pow(height / 100, 2)
                tile(String(format: "%.1f", bmi), unit: nil, "BMI", sub: nil)
            }
            if let ratio {
                tile(String(format: "%.2f", ratio), unit: nil, "肩腰比", sub: "越大越倒三角")
            }
        }
    }

    private var weightDelta: String? {
        guard let r = range(.weight), abs(r.last - r.first) >= 0.1 else { return nil }
        let d = r.last - r.first
        return "比第一次 " + (d > 0 ? "+" : "") + fmt(d)
    }

    private func tile(_ value: String, unit: String?, _ label: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Theme.number(24)).foregroundStyle(Theme.fg)
                if let unit { Text(unit).font(.caption).foregroundStyle(Theme.muted) }
            }
            Text(label).font(.caption).foregroundStyle(Theme.muted)
            if let sub { Text(sub).font(.caption2.weight(.bold)).foregroundStyle(Theme.accentSoft) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themeCard(padding: 12, radius: 16)
    }

    // MARK: 曲線

    private var chartCard: some View {
        let pts = logs.compactMap { log in metric.value(log).map { ProgressPoint(date: log.date, value: $0) } }
        let available = BodyMetric.allCases.filter { range($0) != nil }
        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(available) { m in
                        let on = m == metric
                        Button { metric = m } label: {
                            Text(m.title)
                                .font(.footnote.weight(on ? .bold : .regular))
                                .foregroundStyle(on ? Theme.bg : Theme.accentSoft)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(on ? Theme.fg : .clear, in: Capsule())
                                .overlay(Capsule().stroke(on ? Theme.fg : Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if pts.isEmpty {
                Text("還沒有「\(metric.title)」的紀錄。").font(.footnote).foregroundStyle(Theme.muted)
            } else {
                if let r = range(metric), pts.count > 1 {
                    let d = r.last - r.first
                    let good = (d > 0) == metric.upIsGood
                    Text("比第一次 \(d >= 0 ? "+" : "")\(fmt(d)) \(metric.unit)")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(abs(d) < 0.1 ? Theme.muted : (good ? Theme.green : Theme.hotText))
                }
                Chart(pts) { p in
                    LineMark(x: .value("日期", p.date), y: .value(metric.unit, p.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("日期", p.date), y: .value(metric.unit, p.value))
                        .foregroundStyle(Theme.accent)
                        .symbolSize(30)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Theme.divider)
                        AxisValueLabel().foregroundStyle(Theme.muted)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).foregroundStyle(Theme.muted)
                    }
                }
                .frame(height: 170)
            }
            Text(metric.howTo).font(.caption).foregroundStyle(Theme.muted)
        }
        .themeCard()
        .onAppear {
            if range(metric) == nil, let m = available.first { metric = m }
        }
    }

    // MARK: 紀錄

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("紀錄").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg).padding(.bottom, 8)
            ForEach(logs.reversed()) { log in
                Button { editing = log } label: {
                    HStack {
                        Text(log.date.formatted(.dateTime.year().month(.defaultDigits).day()))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.fg)
                        Spacer()
                        Text(summary(log))
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("刪除", systemImage: "trash", role: .destructive) {
                        context.delete(log)
                        try? context.save()
                    }
                }
            }
        }
        .themeCard()
    }

    private func summary(_ log: BodyLog) -> String {
        BodyMetric.allCases.compactMap { m in m.value(log).map { "\(m.title.prefix(2)) \(fmt($0))" } }
            .prefix(3).joined(separator: " · ")
    }

    private func fmt(_ x: Double) -> String {
        String(format: "%.1f", x).replacingOccurrences(of: ".0", with: "")
    }
}

// MARK: - 輸入

struct BodyEntrySheet: View {
    /// 新增時用上一次的數字當提示
    let previous: BodyLog?
    /// 編輯既有紀錄
    let log: BodyLog?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.height) private var height = 0.0
    @State private var date = Date()
    @State private var values: [BodyMetric: Double] = [:]
    @State private var heightText: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("身高")
                        Spacer()
                        TextField("選填", value: $heightText, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("cm").foregroundStyle(Theme.muted)
                    }
                } footer: {
                    SectionLabel("身高只用來算 BMI。")
                }
                Section {
                    ForEach(BodyMetric.allCases) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(m.title)
                                Spacer()
                                TextField(previous.flatMap { m.value($0) }.map { "上次 \(String(format: "%.1f", $0))" } ?? "選填",
                                          value: Binding<Double?>(get: { values[m] }, set: { values[m] = $0 }), format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 110)
                                Text(m.unit).foregroundStyle(Theme.muted).frame(width: 26, alignment: .leading)
                            }
                            Text(m.howTo).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                } header: {
                    SectionLabel("只填有量的就好")
                } footer: {
                    SectionLabel("體重每週量一次（算增重速度），圍度每 2–4 週量一次；同一個時間、同一個位置量，變化才準。增肌時體重每月增加 0.5–1 kg、腰圍沒有明顯變大，就是長肌肉的好速度。")
                }
            }
            .themeForm()
            .navigationTitle(log == nil ? "量一次" : "編輯紀錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }.disabled(values.values.allSatisfy { $0 <= 0 })
                }
            }
            .onAppear {
                heightText = height > 0 ? height : nil
                if let log {
                    date = log.date
                    for m in BodyMetric.allCases { values[m] = m.value(log) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        if let h = heightText, h > 50 { height = h }
        let target = log ?? BodyLog(date: date)
        target.date = date
        for m in BodyMetric.allCases {
            target[keyPath: m.keyPath] = max(0, values[m] ?? 0)
        }
        if log == nil { context.insert(target) }
        try? context.save()
        StartWeight.noteBodyWeight(target.weight, date: target.date)
        dismiss()
    }
}

// MARK: - 身形圖

/// 正面身形。用 MuscleArt.front 的外形和肌肉，依量到的圍度把各部位拉寬或縮窄；
/// ghost = 在後面用虛線畫第一次（基準）的輪廓。設計座標：x 中線 0，y 0（頭頂）～ 406（腳底）。
struct BodyFigure: View {
    struct Scales {
        var shoulders = 1.0, chest = 1.0, arm = 1.0, waist = 1.0, hips = 1.0, thigh = 1.0, calf = 1.0

        fileprivate var key: String {
            func r(_ v: Double) -> String { String(Int((v * 100).rounded())) }
            return [shoulders, chest, arm, waist, hips, thigh, calf].map(r).joined(separator: ",")
        }
    }

    struct Callout: Identifiable {
        let text: String
        let y: Double
        let right: Bool
        /// true = 往好的方向，false = 反方向，nil = 沒變或只有一次
        let good: Bool?
        var id: String { text }
    }

    let scales: Scales
    let ghost: Bool
    let labels: [Callout]

    var body: some View {
        Canvas { ctx, size in
            // 設計座標高 436（y -6 ～ 430），寬 360（左右留位置給標籤），置中縮放
            let k = min(size.width / 360, size.height / 436)
            ctx.translateBy(x: size.width / 2, y: (size.height - 436 * k) / 2 + 6 * k)
            ctx.scaleBy(x: k, y: k)

            if ghost {
                let base = Self.outline(Scales())
                ctx.stroke(base, with: .color(Theme.muted.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            let cur = Self.outline(scales)
            ctx.fill(cur, with: .linearGradient(
                Gradient(colors: [Theme.accent.opacity(0.55), Theme.accentDim.opacity(0.35)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: 430)))

            // 肌肉分塊：淡淡的亮色＋細分隔線，裁切在身體裡面
            var inner = ctx
            inner.clip(to: cur)
            for (i, sh) in MuscleArt.front.enumerated() where sh.muscle != "body" {
                let p = Self.warped(index: i, scales: scales)
                let tone: Color = sh.muscle == nil ? Theme.bg.opacity(0.12) : Theme.accentSoft.opacity(0.12)
                inner.fill(p, with: .color(tone))
                inner.stroke(p, with: .color(Theme.bg.opacity(0.55)), lineWidth: 0.9)
            }
            ctx.stroke(cur, with: .color(Theme.accent), lineWidth: 1.8)

            for l in labels {
                let col: Color = l.good.map { $0 ? Theme.green : Theme.hotText } ?? Theme.accentSoft
                let x: Double = l.right ? 122 : -122
                var tick = Path()
                tick.move(to: CGPoint(x: l.right ? 50 : -50, y: l.y))
                tick.addLine(to: CGPoint(x: l.right ? 116 : -116, y: l.y))
                ctx.stroke(tick, with: .color(col.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                ctx.draw(Text(l.text).font(.system(size: 10, weight: .bold)).foregroundColor(col),
                         at: CGPoint(x: x, y: l.y), anchor: l.right ? .leading : .trailing)
            }
        }
        .accessibilityLabel("身形圖")
    }

    // MARK: 輪廓與變形

    private static var cache: [String: Path] = [:]
    private static let lock = NSLock()

    private static func cached(_ key: String) -> Path? {
        lock.lock(); defer { lock.unlock() }
        return cache[key]
    }

    private static func store(_ key: String, _ p: Path) {
        lock.lock(); defer { lock.unlock() }
        if cache.count > 600 { cache.removeAll() }
        cache[key] = p
    }

    /// 整個身體的輪廓（頭、軀幹、手臂、腿的聯集），x = 0 是中線。
    static func outline(_ s: Scales) -> Path {
        let key = "outline|" + s.key
        if let p = cached(key) { return p }
        var result: Path?
        for (i, sh) in MuscleArt.front.enumerated() where sh.muscle == "body" {
            let p = warped(index: i, scales: s)
            result = result.map { $0.union(p) } ?? p
        }
        let out = result ?? Path()
        store(key, out)
        return out
    }

    /// 第 index 個形狀依圍度變形後的路徑（快取）。
    fileprivate static func warped(index: Int, scales s: Scales) -> Path {
        let key = "\(index)|" + s.key
        if let p = cached(key) { return p }
        let shape = MuscleArt.front[index]
        let cmds = tokenize(shape.d)
        // 這個形狀在左邊還是右邊（用所有點的 x 平均）
        var sum = 0.0, count = 0.0
        for c in cmds {
            var j = 0
            while j + 1 < c.nums.count { sum += c.nums[j]; count += 1; j += 2 }
        }
        let sg: Double = (count > 0 ? sum / count : 0) < 0 ? -1 : 1

        func pts(_ nums: [Double]) -> [CGPoint] {
            var out: [CGPoint] = []
            var j = 0
            while j + 1 < nums.count {
                let (x, y) = warp(nums[j], nums[j + 1], zone: shape.zone, sg: sg, s: s)
                out.append(CGPoint(x: x, y: y))
                j += 2
            }
            return out
        }

        var path = Path()
        for c in cmds {
            let p = pts(c.nums)
            switch c.cmd {
            case "M", "m":
                for (n, pt) in p.enumerated() {
                    if n == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
            case "L", "l":
                for pt in p { path.addLine(to: pt) }
            case "C", "c":
                var n = 0
                while n + 2 < p.count {
                    path.addCurve(to: p[n + 2], control1: p[n], control2: p[n + 1])
                    n += 3
                }
            case "Q", "q":
                var n = 0
                while n + 1 < p.count {
                    path.addQuadCurve(to: p[n + 1], control: p[n])
                    n += 2
                }
            case "Z", "z":
                path.closeSubpath()
            default:
                break
            }
        }
        store(key, path)
        return path
    }

    /// 把 SVG 路徑字串拆成（指令, 數字們）。
    private static func tokenize(_ d: String) -> [(cmd: Character, nums: [Double])] {
        var out: [(cmd: Character, nums: [Double])] = []
        var cur = ""
        var cmd: Character? = nil
        var nums: [Double] = []
        func flushNum() {
            if !cur.isEmpty {
                if let v = Double(cur) { nums.append(v) }
                cur = ""
            }
        }
        func flushCmd() {
            flushNum()
            if let c = cmd { out.append((cmd: c, nums: nums)) }
            nums = []
        }
        for ch in d {
            if ch.isLetter {
                flushCmd()
                cmd = ch
            } else if ch == " " || ch == "," {
                flushNum()
            } else if ch == "-" {
                flushNum()
                cur.append(ch)
            } else {
                cur.append(ch)
            }
        }
        flushCmd()
        return out
    }

    /// 在錨點之間線性插值（pts 依 y 由小到大）；超出範圍用頭尾的值。
    private static func interp(_ y: Double, _ pts: [(Double, Double)]) -> Double {
        guard let first = pts.first, let last = pts.last else { return 1 }
        if y <= first.0 { return first.1 }
        if y >= last.0 { return last.1 }
        for i in 1..<pts.count where y <= pts[i].0 {
            let (y0, v0) = pts[i - 1]
            let (y1, v1) = pts[i]
            return v0 + (v1 - v0) * (y - y0) / (y1 - y0)
        }
        return last.1
    }

    /// 肢段中心線在高度 y 的 |x|。
    private static func axisX(_ y: Double, _ axis: [CGPoint]) -> Double {
        interp(y, axis.map { (Double($0.y), abs(Double($0.x))) })
    }

    private static func clamp01(_ v: Double) -> Double { min(1, max(0, v)) }

    private static func warp(_ x: Double, _ y: Double, zone: String, sg: Double, s: Scales) -> (Double, Double) {
        switch zone {
        case "core":
            let k = interp(y, [(80, s.shoulders), (110, s.chest), (188, s.waist), (222, s.hips)])
            return (x * k, y)
        case "arm":
            // 手臂中線（MuscleArt.armAxis）跟著肩寬走，手臂本身的粗細跟著上臂圍（前臂只跟一半）
            let c = sg * axisX(y, MuscleArt.armAxis)
            let t = clamp01((y - 160) / 40)
            let k = s.arm + (1 + (s.arm - 1) * 0.5 - s.arm) * t
            return (c * s.shoulders + (x - c) * k, y)
        case "leg":
            let c = sg * axisX(y, MuscleArt.legAxis)
            let t = clamp01((y - 290) / 50)
            let k = s.thigh + (s.calf - s.thigh) * t * t * (3 - 2 * t)
            return (c * s.hips + (x - c) * k, y)
        default:
            return (x, y)
        }
    }
}
