import Foundation
import SwiftUI

/// 哪一邊比較弱（設定 →「左右平衡」，手、腳分開設）。
enum WeakSide: String, CaseIterable, Identifiable {
    case none, left, right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "沒有明顯差"
        case .left: "左邊比較弱"
        case .right: "右邊比較弱"
        }
    }

    /// 「左」／「右」（none 當左：沒設定時先做左邊）
    var hand: String { self == .right ? "右" : "左" }
    /// 另一邊
    var otherHand: String { self == .right ? "左" : "右" }
}

/// 手或腳：上半身動作算手，下半身算腳，各自有弱邊設定。
enum Limb: String, CaseIterable, Identifiable {
    case arm, leg

    var id: String { rawValue }
    var noun: String { self == .arm ? "手" : "腳" }
    var key: String { self == .arm ? Keys.weakSide : Keys.weakLeg }
    var snoozeKey: String { self == .arm ? Keys.sideSnoozeArm : Keys.sideSnoozeLeg }

    static func of(_ ex: Exercise) -> Limb { ex.pattern.isLower ? .leg : .arm }
}

/// 左右平衡（0.28.0，自動偵測 0.29.0）：
/// - 本來就一邊一邊做的動作（`perSideIds`：單臂划船、分腿蹲、單腳硬舉⋯）一律兩邊分開記次數和還剩幾下。
/// - 設了弱的那隻手，手臂／肩膀的雙手啞鈴動作也改成單手做（`oneArmIds`）。
/// - 弱的那邊先做（沒設定就先做左邊），另一邊做到一樣的次數就停。
///   `SetEntry.reps`／`rir` 是先做的那邊，`side` 記是哪一邊；`otherReps`／`otherRir` 是另一邊。
/// - 二頭、側平舉、肩推、弓步類，最後多一組只做弱邊的加強組（`SetKind.weak`，不算進步、紀錄、每週組數）。
/// - 兩邊都填「還剩幾下」就算得出差幾下。最近 3 次都差 2 下以上而且同一邊 → 今天頁問要不要設成那一邊弱（`detect`）；
///   設了弱邊後最近 3 次都差 1 下以內 → 進步頁問要不要關加強組。
enum SideBalance {
    static func weak(_ limb: Limb) -> WeakSide {
        WeakSide(rawValue: UserDefaults.standard.string(forKey: limb.key) ?? "") ?? .none
    }

    static func weak(for ex: Exercise) -> WeakSide { weak(Limb.of(ex)) }

    static func set(_ side: WeakSide, for limb: Limb) {
        UserDefaults.standard.set(side.rawValue, forKey: limb.key)
    }

    /// 弱邊加強組（預設開，只有設定了弱邊才有作用）
    static var extraOn: Bool {
        UserDefaults.standard.object(forKey: Keys.weakExtra) as? Bool ?? true
    }

    /// 本來就是一邊一邊做的動作：不管有沒有設定，都兩邊分開記（用來偵測左右差）。
    static let perSideIds: Set<String> = [
        "db_row", "db_lean_lateral", "cable_lateral",
        "db_sl_rdl", "sl_rdl", "db_split_squat", "split_squat", "db_reverse_lunge", "reverse_lunge",
        "sl_glute_bridge", "db_calf_raise", "calf_raise",
        "db_step_up", "db_concentration_curl",
    ]

    /// 設了弱的那隻手，才改成單手做的雙手啞鈴動作（單手用同一個重量）。
    /// 不放啞鈴過頭三頭伸展：那是兩手握一顆，改單手等於重量變兩倍。
    static let oneArmIds: Set<String> = [
        "db_curl", "db_hammer_curl", "db_lateral", "db_shoulder_press", "db_arnold", "db_rear_fly",
        "db_incline_curl", "db_kickback", "db_chest_rear_fly",
    ]

    /// 會多排一組弱邊加強組的動作類型
    static let extraPatterns: Set<MovementPattern> = [.biceps, .lateral, .vPush, .lunge]

    /// 這個動作兩邊分開做、分開記
    static func sided(_ ex: Exercise) -> Bool {
        perSideIds.contains(ex.id) || (oneArmIds.contains(ex.id) && weak(.arm) != .none)
    }

    /// 先做哪一邊：弱邊；沒設定就左邊
    static func first(for ex: Exercise) -> WeakSide {
        let w = weak(for: ex)
        return w == .none ? .left : w
    }

    static func wantsExtra(_ ex: Exercise, phase: Phase, minimal: Bool) -> Bool {
        sided(ex) && weak(for: ex) != .none && extraOn && extraPatterns.contains(ex.pattern)
            && phase != .deload && !minimal
    }

    /// 訓練畫面動作卡的提醒
    static func cardNote(_ ex: Exercise) -> String? {
        let limb = Limb.of(ex)
        let w = weak(limb)
        let n = limb.noun
        if sided(ex) {
            if w == .none {
                return "兩邊分開記：先做左\(n)，右\(n)做到一樣的次數就停；兩邊都填「還能再做幾下」，App 會幫你看左右有沒有差。"
            }
            return "先做\(w.hand)\(n)，再換\(w.otherHand)\(n)；\(w.otherHand)\(n)做到和\(w.hand)\(n)一樣的次數就停。"
        }
        guard w != .none, ex.loaded, ex.pattern.isUpper || ex.pattern.isLower else { return nil }
        if limb == .leg {
            return "兩腳平均出力，身體不要偏向\(w.otherHand)邊；\(w.hand)腳先撐不住就停。"
        }
        return "\(w.hand)手先做不動就停，\(w.otherHand)手不要多做；兩邊舉的高度、速度要一樣。"
    }

    // MARK: - 差幾下

    /// 一組的左右差（下）：右邊能做的 − 左邊能做的，正數 = 左邊比較弱。兩邊都要填「還剩幾下」。
    static func diff(_ e: SetEntry) -> Int? {
        guard e.isWork, e.otherReps >= 0, e.rir >= 0, e.otherRir >= 0 else { return nil }
        let first = e.reps + e.rir
        let other = e.otherReps + e.otherRir
        return e.side == WeakSide.right.rawValue ? first - other : other - first
    }

    struct ExerciseGap: Identifiable {
        let id: String
        let name: String
        let limb: Limb
        /// 每次訓練的平均差（舊到新，正數 = 左邊弱）
        let points: [Double]

        var first: Double { points.first ?? 0 }
        var latest: Double { points.last ?? 0 }
    }

    static func gaps(_ sessions: [WorkoutSession]) -> [ExerciseGap] {
        var byEx: [String: [(Date, Double)]] = [:]
        for s in sessions {
            var perEx: [String: [Int]] = [:]
            for e in s.entries {
                if let d = diff(e) { perEx[e.exerciseId, default: []].append(d) }
            }
            for (id, list) in perEx {
                byEx[id, default: []].append((s.date, Double(list.reduce(0, +)) / Double(list.count)))
            }
        }
        return byEx.compactMap { id, list in
            let ex = ExerciseLibrary.byId(id)
            let pts = list.sorted { $0.0 < $1.0 }.map(\.1)
            return ExerciseGap(id: id, name: ex?.name ?? id, limb: ex.map(Limb.of) ?? .arm, points: pts)
        }
        .sorted { abs($0.latest) > abs($1.latest) }
    }

    /// 某個部位（手／腳）每次訓練的平均差，舊到新
    static func limbPoints(_ sessions: [WorkoutSession], limb: Limb) -> [Double] {
        sessions.sorted { $0.date < $1.date }.compactMap { s in
            let list = s.entries.compactMap { e -> Int? in
                guard let ex = ExerciseLibrary.byId(e.exerciseId), Limb.of(ex) == limb else { return nil }
                return diff(e)
            }
            return list.isEmpty ? nil : Double(list.reduce(0, +)) / Double(list.count)
        }
    }

    /// 偵測：最近 3 次有資料的訓練，每次平均都差 2 下以上、而且都是同一邊弱 → 那一邊。
    static func detect(_ sessions: [WorkoutSession], limb: Limb) -> WeakSide? {
        let pts = limbPoints(sessions, limb: limb).suffix(3)
        guard pts.count == 3 else { return nil }
        if pts.allSatisfy({ $0 >= 2 }) { return .left }
        if pts.allSatisfy({ $0 <= -2 }) { return .right }
        return nil
    }

    /// 偵測到的弱邊和設定不一樣、而且最近 4 週沒按過「先不要」→ 今天頁問
    static func offer(_ sessions: [WorkoutSession]) -> (limb: Limb, side: WeakSide, gap: Double)? {
        for limb in Limb.allCases {
            guard let side = detect(sessions, limb: limb), side != weak(limb), !snoozed(limb) else { continue }
            let pts = limbPoints(sessions, limb: limb).suffix(3)
            return (limb, side, abs(pts.reduce(0, +) / Double(pts.count)))
        }
        return nil
    }

    static func snoozed(_ limb: Limb) -> Bool {
        let t = UserDefaults.standard.double(forKey: limb.snoozeKey)
        return t > 0 && Date().timeIntervalSince1970 - t < 28 * 86400
    }

    static func snooze(_ limb: Limb) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: limb.snoozeKey)
    }

    /// 設了弱邊的部位，最近 3 次都差 1 下以內（沒有設弱邊的部位不看）
    static func balanced(_ sessions: [WorkoutSession]) -> Bool {
        let limbs = Limb.allCases.filter { weak($0) != .none }
        guard !limbs.isEmpty else { return false }
        return limbs.allSatisfy { limb in
            let pts = limbPoints(sessions, limb: limb).suffix(3)
            return pts.count == 3 && pts.allSatisfy { abs($0) <= 1 }
        }
    }

    static func format(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }

    /// 「左手少 2 下」「差不多」
    static func describe(_ v: Double, limb: Limb) -> String {
        if abs(v) < 0.5 { return "差不多" }
        return "\(v > 0 ? "左" : "右")\(limb.noun)少 \(format(abs(v))) 下"
    }
}

/// 今天頁：偵測到某一邊比較弱，問要不要開左右平衡（或改成另一邊）。
struct SideDetectCard: View {
    let sessions: [WorkoutSession]
    @AppStorage(Keys.weakSide) private var armRaw = WeakSide.none.rawValue
    @AppStorage(Keys.weakLeg) private var legRaw = WeakSide.none.rawValue
    @AppStorage(Keys.sideSnoozeArm) private var snoozeArm = 0.0
    @AppStorage(Keys.sideSnoozeLeg) private var snoozeLeg = 0.0

    var body: some View {
        let _ = (armRaw, legRaw, snoozeArm, snoozeLeg)
        if let o = SideBalance.offer(sessions) {
            let current = SideBalance.weak(o.limb)
            let n = o.limb.noun
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "hand.raised.fill").foregroundStyle(Theme.gold)
                    Text(current == .none ? "你的\(o.side.hand)\(n)好像比較弱" : "現在比較弱的好像是\(o.side.hand)\(n)")
                        .font(.headline)
                        .foregroundStyle(Theme.fg)
                    InfoTip(item: .sides)
                }
                Text("最近 3 次兩邊分開做的動作，\(o.side.hand)\(n)平均少 \(SideBalance.format(o.gap)) 下。"
                     + (current == .none
                        ? "開啟左右平衡後，\(o.side.hand)\(n)會先做、另一邊做到一樣的次數就停，\(o.side.hand)\(n)再多一組加強組。"
                        : "設定裡寫的是\(current.hand)\(n)比較弱，要改成\(o.side.hand)\(n)嗎？"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button(current == .none ? "開啟" : "改成\(o.side.hand)\(n)") {
                        withAnimation { SideBalance.set(o.side, for: o.limb) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("先不要") {
                        withAnimation { SideBalance.snooze(o.limb) }
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .themeCard()
        }
    }
}

/// 進步頁「左右平衡」卡：每個兩邊分開做的動作差幾下（第一次 → 最近）。
struct SideBalanceCard: View {
    let sessions: [WorkoutSession]
    @AppStorage(Keys.weakSide) private var armRaw = WeakSide.none.rawValue
    @AppStorage(Keys.weakLeg) private var legRaw = WeakSide.none.rawValue
    @AppStorage(Keys.weakExtra) private var extraOn = true
    @AppStorage(Keys.weakExtraSnooze) private var snooze = 0.0

    var body: some View {
        let arm = WeakSide(rawValue: armRaw) ?? .none
        let leg = WeakSide(rawValue: legRaw) ?? .none
        let gaps = SideBalance.gaps(sessions)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("左右平衡")
                    .font(.headline)
                    .foregroundStyle(Theme.fg)
                InfoTip(item: .sides)
                Spacer()
                Text(settingText(arm: arm, leg: leg))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(arm == .none && leg == .none ? Theme.muted : Theme.hotText)
            }
            if gaps.isEmpty {
                Text("單臂划船、分腿蹲這類一邊一邊做的動作，兩邊都填「還能再做幾下」，這裡就會算出左右差幾下。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(gaps) { row($0) }
                Text("差 1 下以內就算平衡；連續 3 次差 2 下以上，App 會問你要不要開左右平衡。")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if (arm != .none || leg != .none) && extraOn && !snoozed && SideBalance.balanced(sessions) {
                balancedPrompt
            }
        }
        .themeCard()
    }

    private func settingText(arm: WeakSide, leg: WeakSide) -> String {
        var parts: [String] = []
        if arm != .none { parts.append("\(arm.hand)手弱") }
        if leg != .none { parts.append("\(leg.hand)腳弱") }
        return parts.isEmpty ? "還沒設定" : parts.joined(separator: "、")
    }

    private var snoozed: Bool {
        snooze > 0 && Date().timeIntervalSince1970 - snooze < 28 * 86400
    }

    private func row(_ g: SideBalance.ExerciseGap) -> some View {
        HStack {
            Text(g.name)
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            Spacer()
            if g.points.count > 1 {
                Text("\(SideBalance.describe(g.first, limb: g.limb)) →")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Text(SideBalance.describe(g.latest, limb: g.limb))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(abs(g.latest) <= 1 ? Theme.green : Theme.hotText)
        }
    }

    private var balancedPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近 3 次兩邊都差 1 下以內了，弱邊的加強組可以關掉；先做弱邊、兩邊分開記會繼續保留。")
                .font(.subheadline)
                .foregroundStyle(Theme.accentSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("關掉加強組") { extraOn = false }
                    .buttonStyle(.borderedProminent)
                Button("再練一陣子") { snooze = Date().timeIntervalSince1970 }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.bold))
        }
        .padding(10)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
