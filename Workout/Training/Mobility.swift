import Foundation
import UIKit

/// 練前動態熱身、練後伸展：依今天的動作挑內容（設計見 docs/training-system.md「熱身與伸展跟做」）。
enum MobilityKind {
    case warmup, cooldown

    var title: String { self == .warmup ? "動態熱身" : "練後伸展" }
    /// 兩個動作之間（含第一個之前）準備的秒數：伸展要趴下、躺下，給久一點
    var gap: Double { self == .warmup ? 4 : 6 }
}

struct MobilityStep: Equatable {
    let move: CharacterMove
    let name: String
    let cue: String
    let seconds: Int
    /// 左右各做一次（中間有換邊的時間）
    var perSide: Bool = false

    var totalSeconds: Int { perSide ? seconds * 2 : seconds }
}

enum Mobility {
    // MARK: 熱身

    private static let armCircle = MobilityStep(move: .armCircle, name: "手臂繞圈", cue: "向前繞一半時間、再向後繞，圈從小慢慢變大", seconds: 30)
    private static let armSwing = MobilityStep(move: .armSwing, name: "手臂前後開合", cue: "手臂往前抱、往後打開，胸口拉開", seconds: 30)
    private static let wallSlide = MobilityStep(move: .wallSlide, name: "頭上推舉伸展", cue: "手肘從身側往上推直再收回，肩膀往下沉、不要聳肩", seconds: 30)
    private static let hipHinge = MobilityStep(move: .hipHinge, name: "徒手早安式", cue: "手抱胸、膝微彎，屁股往後推到大腿後側有拉的感覺", seconds: 30)
    private static let bwSquat = MobilityStep(move: .bwSquat, name: "徒手深蹲", cue: "慢慢蹲、站起來，手往前伸幫忙平衡", seconds: 30)
    private static let lungeStep = MobilityStep(move: .lungeStep, name: "左右交替後跨弓步", cue: "往後跨一大步、後膝往地板靠近，左右交替", seconds: 40)
    private static let legSwing = MobilityStep(move: .legSwing, name: "前後擺腿", cue: "扶著牆或下拉架，腿放鬆前後擺，幅度慢慢加大", seconds: 20, perSide: true)
    private static let bwBridge = MobilityStep(move: .bwBridge, name: "臀橋", cue: "夾臀把髖頂起，停一秒再放下", seconds: 30)
    private static let pushup = MobilityStep(move: .pushup, name: "慢速伏地挺身", cue: "慢慢做 5～8 下就好，不用做到累（可以跪著）", seconds: 30)

    /// 依今天的動作模式排熱身，大約 3～5 分鐘。上半身、下半身都沒有（空的）就兩邊都做。
    static func warmup(patterns: [MovementPattern]) -> [MobilityStep] {
        var upper = patterns.contains { $0.isUpper }
        var lower = patterns.contains { $0.isLower }
        if !upper && !lower { upper = true; lower = true }
        var out = [armCircle]
        if upper { out += [armSwing, wallSlide] }
        out += [hipHinge, bwSquat]
        if lower { out += [lungeStep, legSwing, bwBridge] }
        if upper { out.append(pushup) }
        return out
    }

    // MARK: 伸展

    private enum Area: CaseIterable {
        case chest, shoulder, triceps, quads, calves, hipFlexor, hamstrings, glutes, core, back
    }

    private static func step(_ a: Area) -> MobilityStep {
        switch a {
        case .chest: return MobilityStep(move: .chestStretch, name: "胸肌伸展", cue: "雙手在背後交握，手臂往後下方伸、挺胸，肩膀放鬆", seconds: 30)
        case .shoulder: return MobilityStep(move: .crossBody, name: "手臂橫拉", cue: "手臂伸直橫過胸前，另一手勾住手肘往身體拉", seconds: 30, perSide: true)
        case .triceps: return MobilityStep(move: .tricepsStretch, name: "三頭伸展", cue: "手肘朝上、手掌摸背，另一手輕壓手肘", seconds: 30, perSide: true)
        case .quads: return MobilityStep(move: .quadStretch, name: "站姿大腿前側伸展", cue: "一手扶牆，另一手抓腳踝把腳跟拉向屁股，膝蓋朝下", seconds: 30, perSide: true)
        case .calves: return MobilityStep(move: .calfStretch, name: "推牆小腿伸展", cue: "後腳伸直、腳跟踩地，身體往牆靠", seconds: 30, perSide: true)
        case .hipFlexor: return MobilityStep(move: .hipFlexor, name: "跪姿髖屈肌伸展", cue: "後膝跪地（墊毛巾），夾臀把髖往前推", seconds: 30, perSide: true)
        case .hamstrings: return MobilityStep(move: .seatedFold, name: "坐姿體前彎", cue: "坐地上腿伸直，背打直往前趴，摸到小腿或腳尖都可以", seconds: 40)
        case .glutes: return MobilityStep(move: .kneeHug, name: "仰躺抱膝", cue: "躺著把雙膝抱向胸口，下背貼地，慢慢呼吸", seconds: 30)
        case .core: return MobilityStep(move: .cobra, name: "人面獅身式", cue: "趴著用前臂撐起上身，髖貼地，肩膀往下沉、放鬆呼吸", seconds: 30)
        case .back: return MobilityStep(move: .childPose, name: "嬰兒式", cue: "跪坐在腳跟上，手往前伸遠，額頭靠地，慢慢呼吸", seconds: 40)
        }
    }

    private static func areas(of p: MovementPattern) -> [Area] {
        switch p {
        case .hPush, .incline: return [.chest, .triceps]
        case .vPush: return [.shoulder, .triceps]
        case .lateral, .rear: return [.shoulder]
        case .hPull, .vPull: return [.back]
        case .biceps: return [.chest]
        case .triceps: return [.triceps]
        case .squat: return [.quads, .glutes, .hipFlexor]
        case .lunge: return [.quads, .hipFlexor, .glutes]
        case .quadIso: return [.quads]
        case .hinge: return [.hamstrings, .glutes]
        case .hamCurl: return [.hamstrings]
        case .glute: return [.glutes, .hipFlexor]
        case .calf: return [.calves]
        case .core: return [.core]
        }
    }

    /// 最多幾個伸展（左右各做的算一個），大約 4～5 分鐘
    static let maxStretches = 6

    /// 今天練最多的部位優先；順序是站著的先、趴下躺下的後，最後用嬰兒式收。
    static func cooldown(patterns: [MovementPattern]) -> [MobilityStep] {
        var score: [Area: Int] = [:]
        for p in patterns {
            for (i, a) in areas(of: p).enumerated() {
                score[a, default: 0] += 3 - min(i, 2)
            }
        }
        if score.isEmpty {
            score = [.chest: 1, .quads: 1, .hamstrings: 1, .back: 1]
        }
        let order = Area.allCases
        let picked = score.keys
            .sorted { (score[$0]!, -order.firstIndex(of: $0)!) > (score[$1]!, -order.firstIndex(of: $1)!) }
            .prefix(maxStretches)
        return order.filter { picked.contains($0) }.map(step)
    }
}

// MARK: - 跟做的計時

/// 跟做流程的一段：準備（換下一個動作）、做、換邊。
struct MobilityPhase: Equatable {
    enum Kind { case prep, work, switchSide }
    let kind: Kind
    let step: Int
    /// 0：不分邊；1、2：第一邊、第二邊
    let side: Int
    let seconds: Double

    /// 換邊的秒數
    static let switchSeconds = 5.0
}

/// 用實際時間算（開始時間＋暫停累計＋跳段），切到背景回來也不會跑掉。
@MainActor
final class MobilityRun: ObservableObject {
    let kind: MobilityKind
    let steps: [MobilityStep]
    let phases: [MobilityPhase]
    private let starts: [Double]
    private var startedAt = Date()
    private var pausedTotal: Double = 0
    /// 跳到下一個／上一個動作時的時間位移
    private var shift: Double = 0
    @Published private(set) var pausedAt: Date?
    @Published private(set) var now = Date()
    @Published private(set) var finished = false
    private var lastPhase = -1
    private var lastCountdown = -1

    init(kind: MobilityKind, steps: [MobilityStep]) {
        self.kind = kind
        self.steps = steps
        phases = MobilityRun.makePhases(kind: kind, steps: steps)
        var t = 0.0
        var s: [Double] = []
        for p in phases { s.append(t); t += p.seconds }
        starts = s
    }

    nonisolated static func makePhases(kind: MobilityKind, steps: [MobilityStep]) -> [MobilityPhase] {
        var out: [MobilityPhase] = []
        for (i, s) in steps.enumerated() {
            out.append(.init(kind: .prep, step: i, side: 0, seconds: kind.gap))
            if s.perSide {
                out.append(.init(kind: .work, step: i, side: 1, seconds: Double(s.seconds)))
                out.append(.init(kind: .switchSide, step: i, side: 2, seconds: MobilityPhase.switchSeconds))
                out.append(.init(kind: .work, step: i, side: 2, seconds: Double(s.seconds)))
            } else {
                out.append(.init(kind: .work, step: i, side: 0, seconds: Double(s.seconds)))
            }
        }
        return out
    }

    var total: Double { (starts.last ?? 0) + (phases.last?.seconds ?? 0) }
    var elapsed: Double {
        let end = pausedAt ?? now
        return min(total, max(0, end.timeIntervalSince(startedAt) - pausedTotal + shift))
    }
    var isPaused: Bool { pausedAt != nil }
    var index: Int { starts.lastIndex { $0 <= elapsed } ?? 0 }
    var phase: MobilityPhase { phases[index] }
    var step: MobilityStep { steps[phase.step] }
    var phaseLeft: Double { max(0, starts[index] + phases[index].seconds - elapsed) }
    var phaseProgress: Double { 1 - phaseLeft / max(phases[index].seconds, 0.001) }
    var nextStep: MobilityStep? { phase.step + 1 < steps.count ? steps[phase.step + 1] : nil }
    var timeLeft: Double { total - elapsed }

    func start() {
        startedAt = Date()
        now = startedAt
        UIApplication.shared.isIdleTimerDisabled = true
        Cue.play(.rest)
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
            if lastPhase >= 0 {
                Cue.play(phases[i].kind == .work ? .go : .rest)
            }
            lastPhase = i
            lastCountdown = -1
        }
        let left = Int(phaseLeft.rounded(.up))
        if left <= 3, left >= 1, left != lastCountdown, phases[i].seconds >= 4 {
            lastCountdown = left
            Cue.play(.count)
        }
    }

    func togglePause() {
        if let p = pausedAt {
            pausedTotal += Date().timeIntervalSince(p)
            pausedAt = nil
            now = Date()
        } else {
            pausedAt = Date()
        }
    }

    /// 跳到下一個動作的準備；最後一個就直接完成。
    func skip() {
        let next = phase.step + 1
        guard let target = phases.firstIndex(where: { $0.step == next }) else {
            jump(to: total)
            finish()
            return
        }
        jump(to: starts[target])
    }

    /// 回到這個動作的開頭；剛開始（3 秒內）就回上一個動作。
    func back() {
        let first = phases.firstIndex { $0.step == phase.step } ?? 0
        if elapsed - starts[first] < 3, phase.step > 0,
           let prev = phases.firstIndex(where: { $0.step == phase.step - 1 }) {
            jump(to: starts[prev])
        } else {
            jump(to: starts[first])
        }
    }

    private func jump(to t: Double) {
        shift += t - elapsed
        lastPhase = index
        lastCountdown = -1
        Cue.play(.tick)
    }

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
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
