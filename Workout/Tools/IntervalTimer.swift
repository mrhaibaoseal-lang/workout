import Foundation
import SwiftData
import SwiftUI
import UIKit

/// 間歇計時的紀錄。記到歷史，但不算牌位分數、週任務、連續天數
/// （所以和 WorkoutSession 分開存）。
@Model
final class IntervalLog {
    var date: Date
    /// IntervalKind.rawValue
    var kind: String
    /// 例如「20 秒做／10 秒休 × 8」
    var detail: String
    /// 實際花的時間（不含準備倒數、不含暫停）
    var durationSeconds: Int
    /// 做完幾回合（AMRAP 是按了幾次 +1）
    var rounds: Int
    /// 沒做完就結束
    var stoppedEarly: Bool = false

    init(date: Date = .now, kind: IntervalKind, detail: String, durationSeconds: Int, rounds: Int, stoppedEarly: Bool) {
        self.date = date
        self.kind = kind.rawValue
        self.detail = detail
        self.durationSeconds = durationSeconds
        self.rounds = rounds
        self.stoppedEarly = stoppedEarly
    }

    var title: String { IntervalKind(rawValue: kind)?.title ?? kind }
}

enum IntervalKind: String, CaseIterable, Identifiable, Codable {
    case tabata, emom, amrap, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tabata: "Tabata"
        case .emom: "EMOM"
        case .amrap: "AMRAP"
        case .custom: "自訂"
        }
    }

    var explain: String {
        switch self {
        case .tabata: "做 20 秒、休 10 秒，重複 8 回合，一共 4 分鐘。每一回合都全力衝。"
        case .emom: "每分鐘一開始就做指定的次數，做完剩下的秒數就是休息，下一分鐘再來。"
        case .amrap: "限時內盡量多做幾輪。每做完一輪按一下「+1 輪」。"
        case .custom: "自己決定做幾秒、休幾秒、幾回合。"
        }
    }
}

enum PhaseKind { case prep, work, rest }

struct IntervalPhase {
    let kind: PhaseKind
    let label: String
    let seconds: Double
    /// 第幾回合（準備是 0）
    let round: Int
}

/// 間歇的設定。work／rest／rounds 依類型解讀：
/// EMOM 的 work = 每輪幾秒（預設 60）；AMRAP 的 work = 總秒數、rounds 不用。
struct IntervalSetup: Codable, Equatable {
    var kind: IntervalKind
    var work: Int
    var rest: Int
    var rounds: Int

    static let prepSeconds = 10.0

    static func preset(_ kind: IntervalKind) -> IntervalSetup {
        switch kind {
        case .tabata: .init(kind: .tabata, work: 20, rest: 10, rounds: 8)
        case .emom: .init(kind: .emom, work: 60, rest: 0, rounds: 10)
        case .amrap: .init(kind: .amrap, work: 600, rest: 0, rounds: 1)
        case .custom: .init(kind: .custom, work: 40, rest: 20, rounds: 6)
        }
    }

    var phases: [IntervalPhase] {
        var p = [IntervalPhase(kind: .prep, label: "準備", seconds: Self.prepSeconds, round: 0)]
        switch kind {
        case .tabata, .custom:
            for r in 1...max(1, rounds) {
                p.append(.init(kind: .work, label: "做！", seconds: Double(work), round: r))
                if rest > 0 && r < rounds {
                    p.append(.init(kind: .rest, label: "休息", seconds: Double(rest), round: r))
                }
            }
        case .emom:
            for r in 1...max(1, rounds) {
                p.append(.init(kind: .work, label: "第 \(r) 輪", seconds: Double(work), round: r))
            }
        case .amrap:
            p.append(.init(kind: .work, label: "盡量多做", seconds: Double(work), round: 1))
        }
        return p
    }

    /// 不含準備倒數
    var totalSeconds: Int { Int(phases.dropFirst().reduce(0) { $0 + $1.seconds }) }

    var detail: String {
        switch kind {
        case .tabata, .custom: rest > 0 ? "\(work) 秒做／\(rest) 秒休 × \(rounds)" : "\(work) 秒 × \(rounds)"
        case .emom: work == 60 ? "每分鐘一輪 × \(rounds)" : "每 \(work) 秒一輪 × \(rounds)"
        case .amrap: "限時 \(work / 60) 分鐘"
        }
    }

    // 記住上次用的設定（每種類型各一份）
    static func load(_ kind: IntervalKind) -> IntervalSetup {
        let all = (try? JSONDecoder().decode([String: IntervalSetup].self,
                                             from: Data((UserDefaults.standard.string(forKey: Keys.intervalSetups) ?? "").utf8))) ?? [:]
        return all[kind.rawValue] ?? preset(kind)
    }

    func save() {
        let d = UserDefaults.standard
        var all = (try? JSONDecoder().decode([String: IntervalSetup].self,
                                             from: Data((d.string(forKey: Keys.intervalSetups) ?? "").utf8))) ?? [:]
        all[kind.rawValue] = self
        if let data = try? JSONEncoder().encode(all) {
            d.set(String(decoding: data, as: UTF8.self), forKey: Keys.intervalSetups)
        }
    }
}

/// 進行中的間歇。用實際時間算（開始時間 + 暫停累計），切到背景回來也不會跑掉；
/// 背景時靠預先排好的通知提醒換階段。
@MainActor
final class IntervalRun: ObservableObject {
    let setup: IntervalSetup
    let phases: [IntervalPhase]
    private let starts: [Double]
    private var startedAt = Date()
    private var pausedTotal: Double = 0
    @Published private(set) var pausedAt: Date?
    @Published private(set) var now = Date()
    @Published var amrapRounds = 0
    @Published private(set) var finished = false
    private var lastPhase = -1
    private var lastCountdown = -1
    static let alertPrefix = "interval-"

    init(setup: IntervalSetup) {
        self.setup = setup
        phases = setup.phases
        var t = 0.0
        var s: [Double] = []
        for p in phases { s.append(t); t += p.seconds }
        starts = s
    }

    var total: Double { (starts.last ?? 0) + (phases.last?.seconds ?? 0) }
    var elapsed: Double {
        let end = pausedAt ?? now
        return max(0, end.timeIntervalSince(startedAt) - pausedTotal)
    }
    var isPaused: Bool { pausedAt != nil }

    /// 目前在第幾段
    var index: Int {
        let e = elapsed
        return starts.lastIndex { $0 <= e } ?? 0
    }
    var phase: IntervalPhase { phases[index] }
    var phaseLeft: Double { max(0, starts[index] + phases[index].seconds - elapsed) }
    var phaseProgress: Double { 1 - phaseLeft / max(phases[index].seconds, 0.001) }
    var next: IntervalPhase? { index + 1 < phases.count ? phases[index + 1] : nil }
    var workRounds: Int { phases.filter { $0.kind == .work }.count }

    /// 做完的回合（工作段結束才算）
    var roundsDone: Int {
        if setup.kind == .amrap { return amrapRounds }
        let e = elapsed
        return phases.indices.filter { phases[$0].kind == .work && starts[$0] + phases[$0].seconds <= e }.count
    }

    /// 真正在動的時間（扣掉準備）
    var activeSeconds: Int { Int(max(0, min(elapsed, total) - IntervalSetup.prepSeconds)) }

    func start() {
        startedAt = Date()
        now = startedAt
        UIApplication.shared.isIdleTimerDisabled = true
        Cue.play(.count)
        scheduleAlerts()
    }

    func tick() {
        guard !finished, pausedAt == nil else { return }
        now = Date()
        if elapsed >= total {
            finish()
            return
        }
        let i = index
        if i != lastPhase {
            if lastPhase >= 0 || i > 0 {
                Cue.play(phases[i].kind == .work ? .go : .rest)
            }
            lastPhase = i
            lastCountdown = -1
        }
        // 每段最後 3 秒倒數（AMRAP、EMOM 也一樣）
        let left = Int(phaseLeft.rounded(.up))
        if left <= 3, left >= 1, left != lastCountdown, phases[i].seconds >= 5 {
            lastCountdown = left
            Cue.play(.count)
        }
    }

    func togglePause() {
        if let p = pausedAt {
            pausedTotal += Date().timeIntervalSince(p)
            pausedAt = nil
            now = Date()
            scheduleAlerts()
        } else {
            pausedAt = Date()
            ToolAlerts.cancel(prefix: Self.alertPrefix)
        }
    }

    /// 回到前景：把錯過的階段直接跳過，不補播一堆聲音。
    func resync() {
        now = Date()
        lastPhase = index
        lastCountdown = Int(phaseLeft.rounded(.up))
    }

    func finish() {
        guard !finished else { return }
        now = Date()
        finished = true
        Cue.play(.done)
        cleanup()
    }

    func cleanup() {
        ToolAlerts.cancel(prefix: Self.alertPrefix)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// 每段開始排一則通知（系統最多 64 則，留空間給其他提醒）
    private func scheduleAlerts() {
        ToolAlerts.cancel(prefix: Self.alertPrefix)
        let base = Date().addingTimeInterval(-elapsed)
        var count = 0
        for (i, p) in phases.enumerated() where i > 0 && starts[i] > elapsed {
            guard count < 50 else { break }
            let title: String
            switch p.kind {
            case .work: title = setup.kind == .emom ? "\(p.label)開始" : "開始！第 \(p.round)／\(workRounds) 回合"
            case .rest: title = "休息 \(Int(p.seconds)) 秒"
            case .prep: continue
            }
            ToolAlerts.schedule(id: Self.alertPrefix + "\(i)", at: base.addingTimeInterval(starts[i]), title: title)
            count += 1
        }
        ToolAlerts.schedule(id: Self.alertPrefix + "end", at: base.addingTimeInterval(total),
                            title: "\(setup.kind.title) 完成！", body: "回到練壯看結果。")
    }
}
