import SwiftUI

/// 人體肌肉圖（正面／背面）。每塊肌肉用 fill 決定顏色；點一下可以選取。
struct MuscleMapView: View {
    enum Side { case front, back }

    let side: Side
    let fill: (Muscle) -> Color
    var selected: Muscle? = nil
    var onTap: ((Muscle) -> Void)? = nil
    /// 第一次進到畫面時，各肌群從底色依序填到目標顏色（預設不播，其他畫面不受影響）。
    var animateIn: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var introStart: Date?
    @State private var introDone = false

    private static let introDuration = 0.6
    private static let introStagger = 0.04
    private var introActive: Bool { animateIn && !reduceMotion && !introDone }

    private static let boxX: Double = -118
    private static let boxY: Double = -6
    private static let boxW: Double = 236
    private static let boxH: Double = 436

    /// 身體底色（和沒練到的肌肉同色調，肌肉之間只留細線，像解剖線稿）
    static let base = Color(gearHex: "#353F4E")
    /// 沒有資料的肌肉
    static let idle = Color(gearHex: "#3B4759")
    private static let seam = Color(gearHex: "#141A22")

    private static let silhouettes: [Side: Path] = {
        func union(_ list: [MuscleArt.Shape]) -> Path {
            list.filter { $0.muscle == "body" }.map { SVGPathCache.path($0.d) }
                .reduce(Path()) { $0.union($1) }
        }
        return [.front: union(MuscleArt.front), .back: union(MuscleArt.back)]
    }()

    private var shapes: [MuscleArt.Shape] { side == .front ? MuscleArt.front : MuscleArt.back }

    /// 設計座標 → 畫布的縮放與位移（等比置中）。
    private static func fit(_ size: CGSize) -> (k: Double, ox: Double, oy: Double) {
        let k = min(Double(size.width) / boxW, Double(size.height) / boxH)
        let ox = Double(size.width) / 2 - (boxX + boxW / 2) * k
        let oy = (Double(size.height) - boxH * k) / 2 - boxY * k
        return (k, ox, oy)
    }

    var body: some View {
        GeometryReader { geo in
            if introActive {
                TimelineView(.animation) { tl in
                    mapCanvas(geo.size, elapsed: introStart.map { tl.date.timeIntervalSince($0) } ?? 0)
                }
            } else {
                mapCanvas(geo.size, elapsed: nil)
            }
        }
        .accessibilityLabel(side == .front ? "正面肌肉圖" : "背面肌肉圖")
        .onFirstVisible { startIntro() }
    }

    private func mapCanvas(_ size: CGSize, elapsed: Double?) -> some View {
        Canvas { ctx, size in
            let f = Self.fit(size)
            ctx.translateBy(x: f.ox, y: f.oy)
            ctx.scaleBy(x: f.k, y: f.k)
            draw(&ctx, elapsed: elapsed)
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture().onEnded { value in
                handleTap(value.location, size: size)
            }
        )
    }

    private func startIntro() {
        guard introActive, introStart == nil else { return }
        introStart = .now
        let total = Self.introDuration + Self.introStagger * Double(Muscle.allCases.count) + 0.1
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(total))
            introDone = true
        }
    }

    private func draw(_ ctx: inout GraphicsContext, elapsed: Double?) {
        let list = shapes
        let body = Self.silhouettes[side] ?? Path()
        // 外框 → 身體底色 → 裁切在身體裡面畫肌肉（貼邊的肌肉和外框齊平）
        ctx.stroke(body, with: .color(Self.seam), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
        ctx.fill(body, with: .color(Self.base))
        var inner = ctx
        inner.clip(to: body)
        for s in list where s.muscle == nil {
            let p = SVGPathCache.path(s.d)
            inner.fill(p, with: .color(Color(gearHex: "#323C4A")))
            inner.stroke(p, with: .color(Self.seam), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        }
        for s in list {
            guard let id = s.muscle, let m = Muscle(rawValue: id) else { continue }
            let p = SVGPathCache.path(s.d)
            if let elapsed {
                // 先鋪底色，再依序疊上目標顏色（不同肌群錯開起跑，ease-out）
                let idx = Double(Muscle.allCases.firstIndex(of: m) ?? 0)
                let t = min(1, max(0, (elapsed - idx * Self.introStagger) / Self.introDuration))
                let eased = 1 - pow(1 - t, 3)
                inner.fill(p, with: .color(Self.idle))
                if eased > 0 { inner.fill(p, with: .color(fill(m).opacity(eased))) }
            } else {
                inner.fill(p, with: .color(fill(m)))
            }
            inner.stroke(p, with: .color(Self.seam), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        }
        if let sel = selected {
            for s in list where s.muscle == sel.rawValue {
                inner.stroke(SVGPathCache.path(s.d), with: .color(Theme.fg),
                             style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
            }
        }
    }

    private func handleTap(_ loc: CGPoint, size: CGSize) {
        guard let onTap else { return }
        let f = Self.fit(size)
        let pt = CGPoint(x: (Double(loc.x) - f.ox) / f.k, y: (Double(loc.y) - f.oy) / f.k)
        for s in shapes.reversed() {
            guard let id = s.muscle, let m = Muscle(rawValue: id) else { continue }
            if SVGPathCache.path(s.d).contains(pt) {
                onTap(m)
                return
            }
        }
    }
}

private func setsText(_ v: Double) -> String {
    v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
}

// MARK: - 每週組數

struct MuscleVolumeCard: View {
    let sessions: [WorkoutSession]

    @State private var week = 0
    @State private var selected: Muscle?

    private var sets: [Muscle: Double] {
        let date = week == 0 ? Date.now : (Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now)
        return MuscleStats.weeklySets(sessions, weekOf: date)
    }

    private func color(_ m: Muscle, _ data: [Muscle: Double]) -> Color {
        let st = MuscleStats.status(data[m] ?? 0)
        return st == .none ? MuscleMapView.idle : st.color
    }

    var body: some View {
        let data = sets
        return VStack(alignment: .leading, spacing: 12) {
            Text("每個部位這週練了幾組")
                .font(.headline)
                .foregroundStyle(Theme.fg)

            Picker("週", selection: $week) {
                Text("這週").tag(0)
                Text("上週").tag(1)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                MuscleMapView(side: .front, fill: { color($0, data) }, selected: selected, onTap: toggle, animateIn: true)
                    .frame(height: 260)
                MuscleMapView(side: .back, fill: { color($0, data) }, selected: selected, onTap: toggle, animateIn: true)
                    .frame(height: 260)
            }

            legend

            VStack(spacing: 2) {
                ForEach(Muscle.ordered) { m in
                    row(m, data[m] ?? 0)
                }
            }

            Text("增肌建議每個部位一週 10–20 組；次要出力的肌肉算半組。")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    private func toggle(_ m: Muscle) {
        selected = (selected == m) ? nil : m
    }

    private var legend: some View {
        let items: [(MuscleStatus, String)] = [
            (.none, "還沒練"), (.low, "太少"), (.building, "快達標"), (.good, "剛好"), (.high, "偏多"),
        ]
        return HStack(spacing: 10) {
            ForEach(items, id: \.1) { item in
                HStack(spacing: 4) {
                    Circle()
                        .fill(item.0 == .none ? MuscleMapView.idle : item.0.color)
                        .frame(width: 8, height: 8)
                    Text(item.1).font(.caption2).foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private func row(_ m: Muscle, _ v: Double) -> some View {
        let st = MuscleStats.status(v)
        let isSel = selected == m
        return Button {
            toggle(m)
        } label: {
            HStack(spacing: 10) {
                Text(m.name)
                    .font(.subheadline)
                    .foregroundStyle(isSel ? Theme.fg : Theme.accentSoft)
                    .frame(width: 70, alignment: .leading)
                GeometryReader { g in
                    let w = g.size.width
                    let lo = CGFloat(MuscleStats.target.lowerBound / 20) * w
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(Theme.sunken)
                        Rectangle()
                            .fill(Theme.green.opacity(0.18))
                            .frame(width: w - lo, height: g.size.height)
                            .offset(x: lo)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(st == .none ? Color.clear : st.color)
                            .frame(width: w * CGFloat(min(1, v / 20)))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(height: 8)
                Text("\(setsText(v)) 組")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .frame(width: 52, alignment: .trailing)
                Text(st.label)
                    .font(.caption2)
                    .foregroundStyle(st == .none ? Theme.muted : st.color)
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .background(isSel ? Theme.raised : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 疲勞地圖

struct FatigueMapCard: View {
    let sessions: [WorkoutSession]

    private static let red = Color(gearHex: "#E5484D")

    private func color(_ r: Double) -> Color {
        if r >= 0.8 { return Theme.green }
        if r >= 0.6 { return Theme.gold }
        if r >= 0.4 { return Theme.hot }
        return Self.red
    }

    var body: some View {
        let rec = MuscleStats.recovery(sessions)
        let tired = Muscle.allCases
            .filter { (rec[$0] ?? 1) < 0.6 }
            .sorted { (rec[$0] ?? 1) < (rec[$1] ?? 1) }
        let day = MuscleStats.suggestedDay(recovery: rec)
        let fillFn: (Muscle) -> Color = { color(rec[$0] ?? 1) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("疲勞地圖")
                .font(.headline)
                .foregroundStyle(Theme.fg)

            HStack(spacing: 8) {
                MuscleMapView(side: .front, fill: fillFn).frame(height: 260)
                MuscleMapView(side: .back, fill: fillFn).frame(height: 260)
            }

            HStack(spacing: 10) {
                dot(Theme.green, "已恢復")
                dot(Theme.gold, "還好")
                dot(Theme.hot, "有點累")
                dot(Self.red, "很累")
            }

            if tired.isEmpty {
                Text("全身都恢復得差不多了。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentSoft)
            } else {
                Text("還在累：" + tired.map { $0.name }.joined(separator: "、"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentSoft)
            }
            if let day {
                Text("今天適合練：\(day.name)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.green)
            }

            Text("依最近 4 天練的組數估算，練完約 2–3 天恢復。")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    private func dot(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(text).font(.caption2).foregroundStyle(Theme.muted)
        }
    }
}
