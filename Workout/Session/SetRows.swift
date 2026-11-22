import SwiftUI
import SwiftData

struct CompactSetRow: View {
    let set: SetDraft
    let tag: String
    let exercise: Exercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(tag)
                    .font(set.kind == .work ? Theme.number(15) : .caption.weight(.heavy))
                    .foregroundStyle(set.kind == .work ? Theme.muted : (set.kind == .warmup ? Theme.accentSoft : Theme.hotText))
                    .frame(width: 24, alignment: .leading)
                Text(label)
                    .font(Theme.number(17))
                    .foregroundStyle(set.done ? Theme.fg : Theme.muted)
                Spacer()
                if let g = set.grade {
                    Text(g.title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(g == .miss ? Theme.muted : Theme.bg)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(g == .miss ? Theme.raised : g.color, in: Capsule())
                }
                ZStack {
                    if set.done {
                        Circle().fill(Theme.accent)
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Theme.bg)
                    } else {
                        Circle().stroke(Theme.line, lineWidth: 2)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(set.kind == .warmup && !set.done ? 0.8 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityHint(set.done ? "點一下取消完成" : "點一下改做這一組")
    }

    private var label: String {
        let reps = "\(set.reps) \(exercise.unit.label)"
        let each = set.oneArm ? " 每邊" : ""
        guard exercise.loaded else { return reps + each }
        return "\(Progression.format(set.weight)) kg × \(set.reps)" + each
    }
}

struct ActiveSetEditor: View {
    @Binding var set: SetDraft
    let tag: String
    let exercise: Exercise
    let ladder: WeightLadder
    /// 上次同一組（幽靈模式）
    var last: LastSet? = nil
    /// 這個動作的次數下限（判定 MISS 用）
    var low: Int = 0
    let onDone: () -> Void
    @State private var holding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(header)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(set.kind == .work ? Theme.fg : (set.kind == .warmup ? Theme.accentSoft : Theme.hotText))
            HStack(spacing: 10) {
                if exercise.loaded {
                    stepperBox(
                        minus: { set.weight = ladder.down(set.weight) },
                        plus: { set.weight = ladder.up(set.weight) },
                        minusLabel: "減少重量", plusLabel: "增加重量"
                    ) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            TextField("0", value: $set.weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .font(Theme.number(22))
                                .foregroundStyle(Theme.fg)
                                .frame(width: 52)
                            Text("kg").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                stepperBox(
                    minus: { set.reps = max(0, set.reps - repStep) },
                    plus: { set.reps = min(300, set.reps + repStep) },
                    minusLabel: "減少次數", plusLabel: "增加次數"
                ) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(set.reps)").font(Theme.number(22)).foregroundStyle(Theme.fg)
                        Text(exercise.unit.label).font(.caption).foregroundStyle(Theme.muted)
                    }
                    .frame(minWidth: 52)
                }
            }
            if exercise.loaded, set.weight > 0 {
                if let l = ladder.loading(set.weight, kit: set.kit) {
                    Label(l.text, systemImage: "circle.grid.2x1.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accentSoft)
                } else if !ladder.isEmpty {
                    Label("你的器材裝不出 \(Progression.format(set.weight)) kg，按 ＋／− 會跳到裝得出來的重量", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.hotText)
                }
            }
            if set.kind == .work, let last {
                ghostRow(last)
            }
            if set.kind == .work {
                rirPicker(set.oneArm ? "\(weak.hand)\(noun)還能再做幾下？" : "還能再做幾下？", value: $set.rir)
                gradePreview
            }
            if set.oneArm {
                otherSide
            }
            if exercise.unit == .seconds {
                Button {
                    holding = true
                } label: {
                    Label("開始計時（倒數 3 秒）", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.accentDim))
            } else {
                TempoBar(exerciseId: exercise.id)
            }
            Button(action: onDone) {
                Text("完成這一組")
            }
            .buttonStyle(HotButtonStyle(height: 52))
        }
        .fullScreenCover(isPresented: $holding) {
            HoldTimerView(name: exercise.name, target: max(set.target, set.reps), onDone: { secs in
                set.reps = secs
                holding = false
            }, onCancel: { holding = false })
        }
        .padding(14)
        .background(Color(gearHex: "#1E2633"), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hot, lineWidth: 2))
    }

    private var repStep: Int { exercise.unit == .seconds ? 5 : 1 }

    /// 幽靈模式：和上次同一組比，輸入時即時更新
    private func ghostRow(_ last: LastSet) -> some View {
        let g = GhostDelta.compare(weight: set.weight, reps: set.reps, last: last, loaded: exercise.loaded,
                                   unit: exercise.unit.label)
        let lastText = exercise.loaded && last.weight > 0
            ? "\(Progression.format(last.weight)) kg × \(last.reps)" : "\(last.reps) \(exercise.unit.label)"
        return HStack(spacing: 6) {
            Image(systemName: "person.fill.questionmark")
                .font(.caption)
                .foregroundStyle(Theme.muted.opacity(0.7))
            Text("上次 \(lastText)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            Label(g.text, systemImage: g.icon)
                .font(.caption.weight(.heavy))
                .foregroundStyle(g.color)
            InfoTip(item: .ghost)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Theme.sunken.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// 填好「還剩幾下」後先預告會拿到什麼
    @ViewBuilder
    private var gradePreview: some View {
        let g = SetGrade.judge(reps: set.reps, rir: set.rir, target: set.target, low: low)
        HStack(spacing: 6) {
            Text("目標 \(set.target) \(exercise.unit.label) · 還剩 1～2 下 = PERFECT")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
            if set.rir >= 0 {
                Text(g.title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(g.color)
            }
            InfoTip(item: .grade)
        }
    }

    /// 先做的那邊（弱邊；沒設定就左邊）
    private var weak: WeakSide { SideBalance.first(for: exercise) }
    private var noun: String { Limb.of(exercise).noun }

    private var header: String {
        switch set.kind {
        case .work: set.oneArm ? "第 \(tag) 組 · 先做\(weak.hand)\(noun)" : "第 \(tag) 組"
        case .weak: "加強組（只做\(weak.hand)\(noun)）"
        default: set.kind.title
        }
    }

    /// 單手組的另一手：預設做到和弱的那手一樣的次數就停；填「還剩幾下」才算得出兩手差多少。
    private var otherSide: some View {
        let reps = set.otherReps < 0 ? set.reps : set.otherReps
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("\(weak.otherHand)\(noun)：做到 \(set.reps) 下就停，不要多做")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.accentSoft)
                InfoTip(item: .sides)
            }
            stepperBox(
                minus: { set.otherReps = max(0, reps - repStep) },
                plus: { set.otherReps = min(300, reps + repStep) },
                minusLabel: "減少\(weak.otherHand)\(noun)次數", plusLabel: "增加\(weak.otherHand)\(noun)次數"
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(reps)").font(Theme.number(20)).foregroundStyle(Theme.fg)
                    Text(exercise.unit.label).font(.caption).foregroundStyle(Theme.muted)
                }
                .frame(minWidth: 52)
            }
            rirPicker("\(weak.otherHand)\(noun)還能再做幾下？", value: $set.otherRir)
        }
        .padding(10)
        .background(Theme.sunken.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 做完還剩幾下力氣：用來自動調整下一組，也用來判定 PERFECT。
    private func rirPicker(_ title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            InfoTip(item: .rir)
            Spacer(minLength: 0)
            ForEach(0..<5, id: \.self) { v in
                let on = value.wrappedValue == v
                Button {
                    value.wrappedValue = on ? -1 : v
                } label: {
                    Text(v == 4 ? "4+" : "\(v)")
                        .font(Theme.number(14))
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                        .frame(width: 36, height: 32)
                        .background(on ? Theme.accent : Theme.sunken, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(v == 4 ? "還剩 4 下以上" : "還剩 \(v) 下")
            }
        }
    }

    private func stepperBox<Content: View>(minus: @escaping () -> Void, plus: @escaping () -> Void,
                                           minusLabel: String, plusLabel: String,
                                           @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 0) {
            stepButton("minus", label: minusLabel, action: minus)
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
            stepButton("plus", label: plusLabel, action: plus)
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
}
