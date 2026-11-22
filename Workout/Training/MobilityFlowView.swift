import SwiftUI

/// 熱身／伸展跟做：角色示範＋倒數＋下一個。關掉或做完都呼叫 onClose（completed＝有做完）。
struct MobilityFlowView: View {
    @StateObject private var run: MobilityRun
    let onClose: (_ completed: Bool) -> Void
    /// 做完的按鈕文字（熱身做完是「開始訓練」）
    var doneLabel = "完成"

    @EnvironmentObject private var inventory: InventoryStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(kind: MobilityKind, steps: [MobilityStep], doneLabel: String = "完成",
         onClose: @escaping (_ completed: Bool) -> Void) {
        _run = StateObject(wrappedValue: MobilityRun(kind: kind, steps: steps))
        self.doneLabel = doneLabel
        self.onClose = onClose
    }

    private var color: Color {
        if run.finished { return Theme.green }
        switch run.phase.kind {
        case .prep, .switchSide: return Theme.gold
        case .work: return run.kind == .warmup ? Theme.hot : Theme.accent
        }
    }

    private var phaseLabel: String {
        switch run.phase.kind {
        case .prep: return run.phase.step == 0 ? "準備" : "下一個"
        case .switchSide: return "換邊"
        case .work:
            switch run.phase.side {
            case 1: return "第一邊"
            case 2: return "第二邊"
            default: return run.kind == .warmup ? "動起來" : "放鬆呼吸"
            }
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            stepBar
            if run.finished {
                Spacer(minLength: 0)
                finishedView
                Spacer(minLength: 0)
            } else {
                stage
                info
                Spacer(minLength: 0)
                countdown
                Spacer(minLength: 0)
            }
            controls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RadialGradient(colors: [color.opacity(0.18), Theme.bg], center: .top, startRadius: 20, endRadius: 520)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: run.index)
        )
        .preferredColorScheme(.dark)
        .onAppear {
            guard !started else { return }
            started = true
            run.start()
        }
        .onDisappear { run.cleanup() }
        .onReceive(timer) { _ in run.tick() }
        .onChange(of: scenePhase) { _, p in
            if p == .active { run.resync() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                run.cleanup()
                onClose(run.finished)
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 40, height: 40)
                    .background(Theme.surface, in: Circle())
            }
            .accessibilityLabel("關閉")
            VStack(alignment: .leading, spacing: 2) {
                Text(run.kind.title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.fg)
                Text(run.finished ? "完成" : "第 \(run.phase.step + 1) / \(run.steps.count) 個")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if !run.finished {
                Text("剩 " + TimeText.mmss(Int(run.timeLeft.rounded(.up))))
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    /// 每個動作一格，做過的填滿、正在做的依進度填
    private var stepBar: some View {
        HStack(spacing: 4) {
            ForEach(run.steps.indices, id: \.self) { i in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(color)
                            .frame(width: geo.size.width * fill(i))
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func fill(_ i: Int) -> Double {
        if run.finished || i < run.phase.step { return 1 }
        if i > run.phase.step { return 0 }
        let mine = run.phases.indices.filter { run.phases[$0].step == i && run.phases[$0].kind != .prep }
        guard let first = mine.first, let last = mine.last else { return 0 }
        if run.index < first { return 0 }
        let done = mine.filter { $0 < run.index }.reduce(0.0) { $0 + run.phases[$1].seconds }
        let all = mine.reduce(0.0) { $0 + run.phases[$1].seconds }
        let cur = run.index <= last ? run.phase.seconds - run.phaseLeft : 0
        return min(1, (done + cur) / max(all, 1))
    }

    private var stage: some View {
        CharacterView(move: run.step.move, loadout: inventory.state.loadout,
                      animated: !reduceMotion && !run.isPaused, showStats: false)
            .id(run.step.move)
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .background(
                RadialGradient(
                    colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                    center: .top, startRadius: 10, endRadius: 300),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                if run.phase.kind != .work {
                    Text(phaseLabel)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.onHot)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.gold, in: Capsule())
                        .padding(12)
                }
            }
            .transition(.opacity)
    }

    private var info: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text(run.step.name)
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.fg)
                if run.step.perSide {
                    Text("左右各 \(run.step.seconds) 秒")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.surface, in: Capsule())
                }
            }
            Text(run.step.cue)
                .font(.subheadline)
                .foregroundStyle(Theme.accentSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var countdown: some View {
        HStack(spacing: 18) {
            ZStack {
                Ring(progress: run.phaseProgress, color: color, lineWidth: 10)
                Text("\(Int(run.phaseLeft.rounded(.up)))")
                    .font(Theme.number(44))
                    .foregroundStyle(Theme.fg)
                    .contentTransition(.numericText())
            }
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text(run.isPaused ? "暫停中" : phaseLabel)
                    .font(.title2.weight(.black))
                    .foregroundStyle(color)
                if let n = run.nextStep {
                    Text("下一個：\(n.name)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("最後一個")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var finishedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.green)
            Text(run.kind == .warmup ? "熱身完成！" : "伸展完成！")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Theme.fg)
            Text(run.kind == .warmup ? "身體熱起來了，第一個動作記得先做熱身組。" : "今天辛苦了，記得補充蛋白質和水。")
                .font(.subheadline)
                .foregroundStyle(Theme.accentSoft)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if run.finished {
            Button(doneLabel) { onClose(true) }
                .buttonStyle(HotButtonStyle())
        } else {
            HStack(spacing: 12) {
                Button { run.back() } label: {
                    Image(systemName: "backward.end.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityLabel("重做這個動作")
                Button { run.togglePause() } label: {
                    Label(run.isPaused ? "繼續" : "暫停", systemImage: run.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
                Button { run.skip() } label: {
                    Image(systemName: "forward.end.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityLabel("跳過這個動作")
            }
        }
    }
}
