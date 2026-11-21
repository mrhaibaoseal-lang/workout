import SwiftUI
import UIKit

/// 動作節奏，例如 3-1-1 = 慢慢放 3 秒、停 1 秒、用力 1 秒。
struct Tempo: Equatable, Hashable {
    var down: Int
    var hold: Int
    var up: Int

    static let standard = Tempo(down: 3, hold: 1, up: 1)
    static let presets: [Tempo] = [
        .init(down: 2, hold: 0, up: 1), .init(down: 3, hold: 0, up: 1), .standard,
        .init(down: 4, hold: 1, up: 1), .init(down: 2, hold: 1, up: 2), .init(down: 4, hold: 0, up: 2),
    ]

    var text: String { "\(down)-\(hold)-\(up)" }
    var cycle: Double { Double(down + hold + up) }

    init(down: Int, hold: Int, up: Int) {
        self.down = down
        self.hold = hold
        self.up = up
    }

    init?(text: String) {
        let p = text.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, p[0] > 0, p[2] > 0 else { return nil }
        self.init(down: p[0], hold: p[1], up: p[2])
    }

    /// 每個動作上次用的節奏，JSON [exerciseId: "3-1-1"]
    static func load(_ exerciseId: String) -> Tempo {
        all()[exerciseId].flatMap { Tempo(text: $0) } ?? .standard
    }

    static func save(_ t: Tempo, for exerciseId: String) {
        var a = all()
        a[exerciseId] = t.text
        if let data = try? JSONEncoder().encode(a) {
            UserDefaults.standard.set(String(decoding: data, as: UTF8.self), forKey: Keys.tempos)
        }
    }

    private static func all() -> [String: String] {
        (try? JSONDecoder().decode([String: String].self,
                                   from: Data((UserDefaults.standard.string(forKey: Keys.tempos) ?? "").utf8))) ?? [:]
    }
}

enum TempoPhase {
    case ready, down, hold, up

    var title: String {
        switch self {
        case .ready: "準備"
        case .down: "慢慢放"
        case .hold: "停住"
        case .up: "用力"
        }
    }

    var color: Color {
        switch self {
        case .ready: Theme.gold
        case .down: Theme.accent
        case .hold: Theme.accentSoft
        case .up: Theme.hot
        }
    }
}

/// 節拍器：先倒數 3 秒，接著照節奏一直循環，每做完「用力」算一下。
@MainActor
final class MetronomeRun: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var phase: TempoPhase = .ready
    @Published private(set) var phaseLeft = 0
    @Published private(set) var reps = 0
    private var tempo = Tempo.standard
    private var startedAt = Date()
    private var timer: Timer?
    private var lastMark = ""
    private static let lead = 3.0

    func start(_ t: Tempo) {
        tempo = t
        startedAt = Date()
        reps = 0
        lastMark = ""
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        timer?.invalidate()
        let tm = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(tm, forMode: .common)
        timer = tm
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if running { UIApplication.shared.isIdleTimerDisabled = false }
        running = false
        phase = .ready
    }

    private func tick() {
        let t = Date().timeIntervalSince(startedAt)
        if t < Self.lead {
            phase = .ready
            phaseLeft = Int((Self.lead - t).rounded(.up))
            mark("r\(phaseLeft)") { Cue.play(.count) }
            return
        }
        let x = t - Self.lead
        let n = Int(x / tempo.cycle)
        let c = x - Double(n) * tempo.cycle
        reps = n
        let d = Double(tempo.down), h = Double(tempo.hold)
        let p: TempoPhase
        let into: Double
        let len: Double
        if c < d {
            p = .down; into = c; len = d
        } else if c < d + h {
            p = .hold; into = c - d; len = h
        } else {
            p = .up; into = c - d - h; len = Double(tempo.up)
        }
        phase = p
        phaseLeft = max(1, Int((len - into).rounded(.up)))
        let sec = Int(into)
        mark("\(n)-\(p)-\(sec)") {
            if sec == 0 {
                switch p {
                case .down: Cue.play(.rest)
                case .hold: Cue.play(.tick)
                case .up: Cue.play(.go)
                case .ready: break
                }
            } else {
                // 慢慢放／停住的每一秒輕輕滴一下，跟著數
                Cue.play(.tick)
            }
        }
    }

    private func mark(_ m: String, _ action: () -> Void) {
        guard m != lastMark else { return }
        lastMark = m
        action()
    }
}

/// 放在「這一組」裡的節拍器列：預設關，按 ▶︎ 才開始。
struct TempoBar: View {
    let exerciseId: String
    @StateObject private var run = MetronomeRun()
    @State private var tempo = Tempo.standard
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "metronome.fill")
                    .foregroundStyle(Theme.accentSoft)
                Text("節奏")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Menu {
                    Picker("節奏", selection: Binding(get: { tempo }, set: { pick($0) })) {
                        ForEach(Tempo.presets, id: \.self) { t in
                            Text("\(t.text)（放 \(t.down)、停 \(t.hold)、起 \(t.up) 秒）").tag(t)
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(tempo.text).font(Theme.number(15))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.sunken, in: Capsule())
                }
                .accessibilityLabel("節奏 \(tempo.text)，點一下更改")
                Spacer(minLength: 0)
                if run.running {
                    Text("第 \(run.reps + (run.phase == .ready ? 0 : 1)) 下")
                        .font(Theme.number(14))
                        .foregroundStyle(Theme.fg)
                }
                Button {
                    if run.running { run.stop() } else { run.start(tempo) }
                } label: {
                    Image(systemName: run.running ? "stop.fill" : "play.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(run.running ? Theme.fg : Theme.bg)
                        .frame(width: 40, height: 32)
                        .background(run.running ? Theme.raised : Theme.accent,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(run.running ? "停止節拍器" : "開始節拍器")
            }
            if run.running {
                HStack {
                    Text(run.phase.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(run.phase.color)
                    Spacer()
                    Text("\(run.phaseLeft)")
                        .font(Theme.number(26))
                        .foregroundStyle(run.phase.color)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(run.phase.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .onAppear {
            guard !loaded else { return }
            tempo = Tempo.load(exerciseId)
            loaded = true
        }
        .onDisappear { run.stop() }
    }

    private func pick(_ t: Tempo) {
        tempo = t
        Tempo.save(t, for: exerciseId)
        if run.running { run.start(t) }
    }
}
