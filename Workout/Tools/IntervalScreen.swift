import SwiftUI
import SwiftData

/// 間歇計時：選類型 → 設定 → 跑。做完記到歷史（IntervalLog）。
struct IntervalScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \IntervalLog.date, order: .reverse) private var logs: [IntervalLog]
    @State private var kind: IntervalKind = .tabata
    @State private var setup = IntervalSetup.load(.tabata)
    @State private var run: IntervalRun?

    var body: some View {
        NavigationStack {
            Group {
                if let run {
                    IntervalRunView(run: run, onClose: { finish(run) })
                } else {
                    setupForm
                }
            }
            .background(Theme.bg.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        // 被別的畫面蓋掉（例如捷徑開始訓練）也要收掉通知和螢幕常亮
        .onDisappear { run?.cleanup() }
    }

    // MARK: Setup

    private var setupForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("間歇計時")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Theme.fg)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                            .frame(width: 40, height: 40)
                            .background(Theme.raised, in: Circle())
                    }
                    .accessibilityLabel("關閉")
                }
                Text("練完加練用。會記到歷史，但不算牌位分數、週任務和連續天數。")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)

                Picker("類型", selection: $kind) {
                    ForEach(IntervalKind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { _, k in setup = IntervalSetup.load(k) }

                VStack(alignment: .leading, spacing: 14) {
                    Text(kind.explain)
                        .font(.subheadline)
                        .foregroundStyle(Theme.accentSoft)
                    settings
                    Divider().overlay(Theme.divider)
                    HStack {
                        Text("總共").foregroundStyle(Theme.muted)
                        Spacer()
                        Text(TimeText.mmss(setup.totalSeconds))
                            .font(Theme.number(22))
                            .foregroundStyle(Theme.fg)
                    }
                }
                .padding(16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))

                Button {
                    setup.save()
                    RestAlerts.requestAuthorization()
                    let r = IntervalRun(setup: setup)
                    r.start()
                    run = r
                } label: {
                    Label("開始（先倒數 \(Int(IntervalSetup.prepSeconds)) 秒）", systemImage: "play.fill")
                }
                .buttonStyle(HotButtonStyle())

                if !logs.isEmpty {
                    Text("最近")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                    ForEach(logs.prefix(3)) { IntervalLogRow(log: $0) }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var settings: some View {
        switch kind {
        case .tabata:
            stepper("回合", value: $setup.rounds, range: 4...16, step: 1, unit: "回合")
        case .emom:
            stepper("每輪", value: $setup.work, range: 30...180, step: 15, unit: "秒")
            stepper("幾輪", value: $setup.rounds, range: 2...40, step: 1, unit: "輪")
        case .amrap:
            stepper("限時", value: Binding(get: { setup.work / 60 }, set: { setup.work = $0 * 60 }),
                    range: 3...40, step: 1, unit: "分鐘")
        case .custom:
            stepper("做", value: $setup.work, range: 5...300, step: 5, unit: "秒")
            stepper("休", value: $setup.rest, range: 0...300, step: 5, unit: "秒")
            stepper("回合", value: $setup.rounds, range: 1...40, step: 1, unit: "回合")
        }
    }

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.fg)
            Spacer()
            Button { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } label: {
                Image(systemName: "minus").frame(width: 40, height: 40)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("減少\(title)")
            Text("\(value.wrappedValue) \(unit)")
                .font(Theme.number(18))
                .foregroundStyle(Theme.fg)
                .frame(minWidth: 86)
            Button { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } label: {
                Image(systemName: "plus").frame(width: 40, height: 40)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("增加\(title)")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.fg)
    }

    // MARK: Save

    /// 有真的開始做（過了準備倒數）才記錄。
    private func finish(_ r: IntervalRun) {
        let early = !r.finished
        r.cleanup()
        if r.activeSeconds >= 10 {
            context.insert(IntervalLog(date: .now, kind: r.setup.kind, detail: r.setup.detail,
                                       durationSeconds: r.activeSeconds, rounds: r.roundsDone, stoppedEarly: early))
        }
        run = nil
        dismiss()
    }
}

/// 跑起來的畫面：大圓環倒數這一段，做的時候橘色、休息藍色。
struct IntervalRunView: View {
    @ObservedObject var run: IntervalRun
    let onClose: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmStop = false
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var color: Color {
        if run.finished { return Theme.green }
        switch run.phase.kind {
        case .prep: return Theme.gold
        case .work: return Theme.hot
        case .rest: return Theme.accent
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text(run.setup.kind.title + " · " + run.setup.detail)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("剩 " + TimeText.mmss(Int((run.total - run.elapsed).rounded(.up))))
                    .font(Theme.number(15))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if run.finished {
                finishedView
            } else {
                ZStack {
                    Ring(progress: run.phaseProgress, color: color, lineWidth: 16)
                    VStack(spacing: 6) {
                        Text(run.phase.label)
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(color)
                        Text("\(Int(run.phaseLeft.rounded(.up)))")
                            .font(Theme.number(96))
                            .foregroundStyle(Theme.fg)
                            .contentTransition(.numericText())
                        if run.phase.round > 0, run.setup.kind != .amrap {
                            Text("第 \(run.phase.round) / \(run.workRounds) 回合")
                                .font(.headline)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .frame(width: 290, height: 290)
                if run.setup.kind == .amrap {
                    amrapButton
                } else if let n = run.next {
                    Text("接下來：\(n.label) \(Int(n.seconds)) 秒")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            controls
        }
        .padding(20)
        .background(
            RadialGradient(colors: [color.opacity(0.22), Theme.bg], center: .center, startRadius: 20, endRadius: 420)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: run.index)
        )
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(timer) { _ in run.tick() }
        .onChange(of: scenePhase) { _, p in
            if p == .active { run.resync() }
        }
        .confirmationDialog("提早結束？", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("結束並記錄", role: .destructive) { onClose() }
            Button("繼續", role: .cancel) {}
        } message: {
            Text("做了 10 秒以上會記到歷史，標成「提早結束」。")
        }
    }

    private var amrapButton: some View {
        Button {
            run.amrapRounds += 1
            Cue.play(.count)
        } label: {
            VStack(spacing: 2) {
                Text("+1 輪").font(.title2.weight(.black))
                Text("已做 \(run.amrapRounds) 輪").font(.subheadline.weight(.bold))
            }
        }
        .buttonStyle(HotButtonStyle(height: 76))
        .disabled(run.phase.kind == .prep)
        .opacity(run.phase.kind == .prep ? 0.5 : 1)
    }

    private var finishedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.green)
            Text("完成！")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(Theme.fg)
            Text(run.setup.kind == .amrap ? "做了 \(run.amrapRounds) 輪" : "\(run.roundsDone) 回合 · \(TimeText.mmss(run.activeSeconds))")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accentSoft)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if run.finished {
            Button("記錄並關閉", action: onClose)
                .buttonStyle(HotButtonStyle())
        } else {
            HStack(spacing: 12) {
                Button {
                    run.togglePause()
                } label: {
                    Label(run.isPaused ? "繼續" : "暫停", systemImage: run.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle())
                Button(role: .destructive) {
                    confirmStop = true
                } label: {
                    Label("結束", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.hotLine))
            }
        }
    }
}

struct IntervalLogRow: View {
    let log: IntervalLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(log.title).font(.headline).foregroundStyle(Theme.fg)
                Text(log.detail).font(.caption).foregroundStyle(Theme.muted)
                if log.stoppedEarly {
                    Text("提早結束").font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .background(Theme.raised, in: Capsule())
                        .foregroundStyle(Theme.muted)
                }
            }
            Text("\(log.date.formatted(date: .abbreviated, time: .shortened)) · \(TimeText.mmss(log.durationSeconds)) · \(log.kind == IntervalKind.amrap.rawValue ? "\(log.rounds) 輪" : "\(log.rounds) 回合")")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum TimeText {
    static func mmss(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
