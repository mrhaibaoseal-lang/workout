import Foundation
import SwiftUI

/// 哪一手比較弱（設定 →「左右平衡」）。
enum WeakSide: String, CaseIterable, Identifiable {
    case none, left, right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "沒有明顯差"
        case .left: "左手比較弱"
        case .right: "右手比較弱"
        }
    }

    /// 「左」／「右」
    var hand: String { self == .right ? "右" : "左" }
    /// 另一手
    var otherHand: String { self == .right ? "左" : "右" }
}

/// 左右平衡（0.28.0）：
/// - 手臂、肩膀、划船的啞鈴動作改成單手做，弱的那手先做，強的那手做到一樣的次數就停（`oneArmIds`）。
/// - 次數、加重都看弱的那手（`SetEntry.reps` 存弱邊；`otherReps` 存另一手）。
/// - 二頭、側平舉、肩推最後多一組只做弱邊的加強組（`SetKind.weak`，不算進步、紀錄、每週組數）。
/// - 兩手都填「還剩幾下」，就能算出差幾下：(另一手次數 + 剩幾下) − (弱邊次數 + 剩幾下)。
/// - 最近 3 次每個動作都差 1 下以內，就建議關掉加強組（用問的）。
enum SideBalance {
    static var weak: WeakSide {
        WeakSide(rawValue: UserDefaults.standard.string(forKey: Keys.weakSide) ?? "") ?? .none
    }

    /// 弱邊加強組（預設開，只有設定了弱邊才有作用）
    static var extraOn: Bool {
        UserDefaults.standard.object(forKey: Keys.weakExtra) as? Bool ?? true
    }

    /// 可以改成單手、而且單手用同一個重量的動作。
    /// 不放啞鈴過頭三頭伸展：那是兩手握一顆，改單手等於重量變兩倍。
    static let oneArmIds: Set<String> = [
        "db_curl", "db_hammer_curl", "db_lateral", "db_lean_lateral",
        "db_shoulder_press", "db_arnold", "db_row", "db_rear_fly",
    ]

    /// 會多排一組弱邊加強組的動作類型（使用者說彎舉、肩推最明顯；側平舉練肩膀側邊）
    static let extraPatterns: Set<MovementPattern> = [.biceps, .lateral, .vPush]

    static func oneArm(_ ex: Exercise) -> Bool {
        weak != .none && oneArmIds.contains(ex.id)
    }

    static func wantsExtra(_ ex: Exercise, phase: Phase, minimal: Bool) -> Bool {
        oneArm(ex) && extraOn && extraPatterns.contains(ex.pattern) && phase != .deload && !minimal
    }

    /// 訓練畫面動作卡的提醒（沒設定弱邊、或不是上半身有負重的動作就沒有）
    static func cardNote(_ ex: Exercise) -> String? {
        let w = weak
        guard w != .none, ex.loaded, ex.pattern.isUpper else { return nil }
        if oneArm(ex) {
            return "單手做：先做\(w.hand)手，再換\(w.otherHand)手；\(w.otherHand)手做到和\(w.hand)手一樣的次數就停。空著的手扶椅背或柱子。"
        }
        return "\(w.hand)手先做不動就停，\(w.otherHand)手不要多做；兩邊舉的高度、速度要一樣。"
    }

    // MARK: - 差幾下

    /// 一組的左右差（下）；兩手都要填「還剩幾下」才算得出來。正數 = 弱邊比較少。
    static func gap(_ e: SetEntry) -> Int? {
        guard e.isWork, e.otherReps >= 0, e.rir >= 0, e.otherRir >= 0 else { return nil }
        return (e.otherReps + e.otherRir) - (e.reps + e.rir)
    }

    struct ExerciseGap: Identifiable {
        let id: String
        let name: String
        /// 每次訓練的平均差（舊到新）
        let points: [Double]

        var first: Double { points.first ?? 0 }
        var latest: Double { points.last ?? 0 }
    }

    static func gaps(_ sessions: [WorkoutSession]) -> [ExerciseGap] {
        var byEx: [String: [(Date, Double)]] = [:]
        for s in sessions {
            var perEx: [String: [Int]] = [:]
            for e in s.entries {
                if let g = gap(e) { perEx[e.exerciseId, default: []].append(g) }
            }
            for (id, list) in perEx {
                byEx[id, default: []].append((s.date, Double(list.reduce(0, +)) / Double(list.count)))
            }
        }
        return byEx.compactMap { id, list in
            let pts = list.sorted { $0.0 < $1.0 }.map(\.1)
            return ExerciseGap(id: id, name: ExerciseLibrary.byId(id)?.name ?? id, points: pts)
        }
        .sorted { $0.latest > $1.latest }
    }

    /// 有資料的動作，最近 3 次都差 1 下以內
    static func balanced(_ gaps: [ExerciseGap]) -> Bool {
        let enough = gaps.filter { $0.points.count >= 3 }
        guard !enough.isEmpty, enough.count == gaps.count else { return false }
        return enough.allSatisfy { $0.points.suffix(3).allSatisfy { $0 <= 1 } }
    }

    static func format(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
    }
}

/// 進步頁「左右平衡」卡：每個單手動作差幾下（第一次 → 最近）。
struct SideBalanceCard: View {
    let sessions: [WorkoutSession]
    @AppStorage(Keys.weakSide) private var weakRaw = WeakSide.none.rawValue
    @AppStorage(Keys.weakExtra) private var extraOn = true
    @AppStorage(Keys.weakExtraSnooze) private var snooze = 0.0

    var body: some View {
        let weak = WeakSide(rawValue: weakRaw) ?? .none
        let gaps = SideBalance.gaps(sessions)
        if weak != .none || !gaps.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Text("左右平衡")
                        .font(.headline)
                        .foregroundStyle(Theme.fg)
                    InfoTip(item: .sides)
                    Spacer()
                    if weak != .none {
                        Text(weak.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.hotText)
                    }
                }
                if gaps.isEmpty {
                    Text("單手動作做完，兩手都填「還能再做幾下」，這裡就會算出兩手差幾下。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                } else {
                    ForEach(gaps) { g in row(g, weak: weak) }
                    Text("差 1 下以內就算平衡。")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                if weak != .none && extraOn && SideBalance.balanced(gaps) && !snoozed {
                    balancedPrompt(weak)
                }
            }
            .themeCard()
        }
    }

    private var snoozed: Bool {
        snooze > 0 && Date().timeIntervalSince1970 - snooze < 28 * 86400
    }

    private func row(_ g: SideBalance.ExerciseGap, weak: WeakSide) -> some View {
        let ok = g.latest <= 1
        return HStack {
            Text(g.name)
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            Spacer()
            if g.points.count > 1 {
                Text("差 \(SideBalance.format(g.first)) 下 →")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Text("差 \(SideBalance.format(max(0, g.latest))) 下")
                .font(Theme.number(15))
                .foregroundStyle(ok ? Theme.green : Theme.hotText)
        }
    }

    private func balancedPrompt(_ weak: WeakSide) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近 3 次兩手都差 1 下以內了，\(weak.hand)手的加強組可以關掉；單手做法會繼續保留。")
                .font(.subheadline)
                .foregroundStyle(Theme.accentSoft)
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
