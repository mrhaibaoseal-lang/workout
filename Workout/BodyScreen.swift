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
                .frame(height: 320)
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
            (.shoulders, 70, false), (.chest, 98, true), (.arm, 112, false),
            (.waist, 146, true), (.hips, 178, false), (.thigh, 212, true), (.calf, 272, false),
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
                    SectionLabel("每 2–4 週量一次，同一個時間、同一個位置量，變化才準。增肌時體重每月增加 0.5–1 kg、腰圍沒有明顯變大，就是長肌肉的好速度。")
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
        dismiss()
    }
}

// MARK: - 身形圖

/// 正面身形剪影。各部位寬度依量到的圍度縮放；ghost = 在後面用虛線畫第一次的輪廓。
struct BodyFigure: View {
    struct Scales {
        var shoulders = 1.0, chest = 1.0, arm = 1.0, waist = 1.0, hips = 1.0, thigh = 1.0, calf = 1.0
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
            // 設計座標 200 × 320，置中縮放
            let k = min(size.width / 260, size.height / 320)
            ctx.translateBy(x: size.width / 2, y: (size.height - 320 * k) / 2)
            ctx.scaleBy(x: k, y: k)

            if ghost {
                let base = Self.outline(Scales())
                ctx.stroke(base, with: .color(Theme.muted.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            let cur = Self.outline(scales)
            ctx.fill(cur, with: .linearGradient(
                Gradient(colors: [Theme.accent.opacity(0.55), Theme.accentDim.opacity(0.35)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: 320)))
            ctx.stroke(cur, with: .color(Theme.accent), lineWidth: 1.8)
            // 肌肉分線：胸線、腹線，讓剪影比較像人
            var lines = Path()
            let cw = 40 * scales.chest
            lines.move(to: CGPoint(x: -cw * 0.75, y: 100)); lines.addQuadCurve(to: CGPoint(x: 0, y: 104), control: CGPoint(x: -cw * 0.4, y: 112))
            lines.addQuadCurve(to: CGPoint(x: cw * 0.75, y: 100), control: CGPoint(x: cw * 0.4, y: 112))
            lines.move(to: CGPoint(x: 0, y: 106)); lines.addLine(to: CGPoint(x: 0, y: 160))
            ctx.stroke(lines, with: .color(Theme.accentSoft.opacity(0.35)), lineWidth: 1.2)

            for l in labels {
                let col: Color = l.good.map { $0 ? Theme.green : Theme.hotText } ?? Theme.accentSoft
                let x: Double = l.right ? 78 : -78
                var tick = Path()
                tick.move(to: CGPoint(x: l.right ? 46 : -46, y: l.y))
                tick.addLine(to: CGPoint(x: l.right ? 72 : -72, y: l.y))
                ctx.stroke(tick, with: .color(col.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                ctx.draw(Text(l.text).font(.system(size: 10, weight: .bold)).foregroundColor(col),
                         at: CGPoint(x: x, y: l.y), anchor: l.right ? .leading : .trailing)
            }
        }
        .accessibilityLabel("身形圖")
    }

    /// 整個身體的輪廓（頭、軀幹、手臂、腿），x = 0 是中線。
    static func outline(_ s: Scales) -> Path {
        var parts: [Path] = []
        var p = Path()
        // 頭、脖子
        p.addEllipse(in: CGRect(x: -15, y: 8, width: 30, height: 36))
        p.addRoundedRect(in: CGRect(x: -8, y: 40, width: 16, height: 18), cornerSize: CGSize(width: 4, height: 4))

        let sh = 46 * s.shoulders, ch = 40 * s.chest, wa = 29 * s.waist, hi = 36 * s.hips
        // 軀幹（左右對稱）
        var torso = Path()
        torso.move(to: CGPoint(x: -9, y: 56))
        torso.addQuadCurve(to: CGPoint(x: -sh, y: 70), control: CGPoint(x: -sh * 0.6, y: 56))
        torso.addQuadCurve(to: CGPoint(x: -ch, y: 108), control: CGPoint(x: -ch - 4, y: 86))
        torso.addQuadCurve(to: CGPoint(x: -wa, y: 148), control: CGPoint(x: -wa - 2, y: 128))
        torso.addQuadCurve(to: CGPoint(x: -hi, y: 182), control: CGPoint(x: -hi, y: 160))
        torso.addLine(to: CGPoint(x: hi, y: 182))
        torso.addQuadCurve(to: CGPoint(x: wa, y: 148), control: CGPoint(x: hi, y: 160))
        torso.addQuadCurve(to: CGPoint(x: ch, y: 108), control: CGPoint(x: wa + 2, y: 128))
        torso.addQuadCurve(to: CGPoint(x: sh, y: 70), control: CGPoint(x: ch + 4, y: 86))
        torso.addQuadCurve(to: CGPoint(x: 9, y: 56), control: CGPoint(x: sh * 0.6, y: 56))
        torso.closeSubpath()
        parts.append(torso)

        // 手臂：上臂粗細跟著上臂圍
        let aw = 10 * s.arm
        for side in [-1.0, 1.0] {
            var arm = Path()
            let top = CGPoint(x: side * (sh - 2), y: 72)
            arm.move(to: CGPoint(x: top.x - side * aw * 0.4, y: top.y))
            arm.addQuadCurve(to: CGPoint(x: side * (sh + aw + 2), y: 104), control: CGPoint(x: side * (sh + aw * 1.4), y: 80))
            arm.addQuadCurve(to: CGPoint(x: side * (sh + 8), y: 142), control: CGPoint(x: side * (sh + aw + 1), y: 128))
            arm.addQuadCurve(to: CGPoint(x: side * (sh + 10), y: 190), control: CGPoint(x: side * (sh + 13), y: 166))
            arm.addQuadCurve(to: CGPoint(x: side * (sh + 1), y: 190), control: CGPoint(x: side * (sh + 5.5), y: 197))
            arm.addQuadCurve(to: CGPoint(x: side * (sh - 2), y: 142), control: CGPoint(x: side * (sh - 2), y: 166))
            arm.addQuadCurve(to: CGPoint(x: side * (sh - aw * 0.5 - 2), y: 100), control: CGPoint(x: side * (sh - aw * 0.6 - 3), y: 122))
            arm.closeSubpath()
            parts.append(arm)
        }

        // 腿：大腿、小腿粗細跟著圍度
        let tw = 16 * s.thigh, cw = 10 * s.calf
        for side in [-1.0, 1.0] {
            let cx = side * hi * 0.5
            var leg = Path()
            leg.move(to: CGPoint(x: cx - tw, y: 180))
            leg.addLine(to: CGPoint(x: cx + tw, y: 180))
            leg.addQuadCurve(to: CGPoint(x: cx + 8, y: 250), control: CGPoint(x: cx + tw + 1, y: 220))
            leg.addQuadCurve(to: CGPoint(x: cx + 5, y: 308), control: CGPoint(x: cx + cw + 2, y: 272))
            leg.addLine(to: CGPoint(x: cx + 7, y: 316))
            leg.addLine(to: CGPoint(x: cx - 7, y: 316))
            leg.addLine(to: CGPoint(x: cx - 5, y: 308))
            leg.addQuadCurve(to: CGPoint(x: cx - 8, y: 250), control: CGPoint(x: cx - cw - 2, y: 272))
            leg.addQuadCurve(to: CGPoint(x: cx - tw, y: 180), control: CGPoint(x: cx - tw - 1, y: 220))
            leg.closeSubpath()
            parts.append(leg)
        }
        // 各部位疊在一起的地方用聯集，外框才是一條乾淨的線
        return parts.reduce(p) { $0.union($1) }
    }
}
