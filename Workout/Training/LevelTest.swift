import SwiftUI

extension Keys {
    /// 程度評估的結果，JSON LevelTest.Result
    static let levelTest = "levelTest"
}

/// 程度評估（0.33.0）：第一次使用或在設定裡重新評估，用 3 個簡單測試推起始重量，
/// 取代「體重 × 0.5」的推估（`StartWeight.noviceEstimate`）。每一項都可以跳過。
/// - 伏地挺身最多幾下：伏地挺身大約推起體重的 64%，換算成臥推的推估最大力量。
/// - 高腳杯深蹲做 10 下（還剩 2 下左右）用幾公斤。
/// - 單手啞鈴划船做 10 下（還剩 2 下左右）用幾公斤。
/// 換算成各動作的 e1RM 後，當作「做過的動作」給 `StartWeight.estimate` 參考；真的練過的動作一律優先。
enum LevelTest {
    struct Result: Codable, Equatable {
        var pushups: Int?
        var gobletKg: Double?
        var rowKg: Double?
        var date: Double
    }

    /// 伏地挺身撐起的體重比例
    static let pushupLoad = 0.64
    /// 測試的次數和還剩幾下
    static let testReps = 10
    static let testRIR = 2

    static var current: Result? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.levelTest),
              let r = try? JSONDecoder().decode(Result.self, from: Data(raw.utf8)) else { return nil }
        return r
    }

    static func save(_ r: Result) {
        guard let data = try? JSONEncoder().encode(r), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.levelTest)
    }

    /// 測試結果換算成各參考動作的 e1RM。
    static func lifts(_ r: Result, bodyWeight: Double) -> [String: Double] {
        var out: [String: Double] = [:]
        if let n = r.pushups, n > 0 {
            out["bb_bench"] = Comeback.e1rm(weight: bodyWeight * pushupLoad, reps: n, rir: 0)
        }
        if let w = r.gobletKg, w > 0 {
            out["goblet_squat"] = Comeback.e1rm(weight: w, reps: testReps, rir: testRIR)
        }
        if let w = r.rowKg, w > 0 {
            out["db_row"] = Comeback.e1rm(weight: w, reps: testReps, rir: testRIR)
        }
        return out
    }

    /// 給 `StartWeight` 用：評估換算的參考（日期 = 評估那天，比真的練過的舊）。
    static var referenceLifts: [String: TrainingHistory.Lift] {
        guard let r = current else { return [:] }
        let bw = StartWeight.bodyWeight > 0 ? StartWeight.bodyWeight : StartWeight.defaultBodyWeight
        let date = Date(timeIntervalSince1970: r.date)
        return lifts(r, bodyWeight: bw).mapValues { TrainingHistory.Lift(e1rm: $0, date: date) }
    }

    /// 換算成「槓鈴臥推 = 1」的基準力量（各項平均），完全沒有相關動作時用來推。
    static func benchEquivalent(_ r: Result, bodyWeight: Double) -> Double? {
        let l = lifts(r, bodyWeight: bodyWeight)
        let vals = l.compactMap { id, e1 in StartWeight.strength[id].map { e1 / $0 } }
        return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
    }

    static var summary: String {
        guard let r = current else { return "還沒做" }
        var parts: [String] = []
        if let n = r.pushups { parts.append("伏地挺身 \(n) 下") }
        if let w = r.gobletKg { parts.append("深蹲 \(Progression.format(w)) kg") }
        if let w = r.rowKg { parts.append("划船 \(Progression.format(w)) kg") }
        return parts.isEmpty ? "都跳過了" : parts.joined(separator: " · ")
    }
}

/// 程度評估畫面（第一次使用、設定 → 訓練）。
struct LevelTestView: View {
    var onDone: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var doPushups = true
    @State private var pushups = 10
    @State private var doGoblet = true
    @State private var goblet = 8.0
    @State private var doRow = true
    @State private var row = 8.0

    var body: some View {
        Form {
            Section {
                Text("做 3 個簡單測試，App 會用結果推算每個動作第一次的重量。做不到或沒器材就關掉那一項。測完休息幾分鐘再做下一項。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .listRowBackground(Theme.surface)

            item(on: $doPushups, title: "伏地挺身最多幾下",
                 detail: "身體一直線，胸口貼近地面再推起，做到做不動為止。") {
                Stepper("\(pushups) 下", value: $pushups, in: 1...80)
            }
            item(on: $doGoblet, title: "高腳杯深蹲 10 下用幾公斤",
                 detail: "雙手捧一個啞鈴在胸前，挑一個做完 10 下大概還能再做 2 下的重量。") {
                Stepper("\(Progression.format(goblet)) kg", value: $goblet, in: 1...60, step: 0.5)
            }
            item(on: $doRow, title: "單手啞鈴划船 10 下用幾公斤",
                 detail: "一手一膝撐在椅子上，挑一個做完 10 下大概還能再做 2 下的重量（填一支的重量）。") {
                Stepper("\(Progression.format(row)) kg", value: $row, in: 1...60, step: 0.5)
            }

            Section {
                Button("存起來") {
                    LevelTest.save(LevelTest.Result(pushups: doPushups ? pushups : nil,
                                                    gobletKg: doGoblet ? goblet : nil,
                                                    rowKg: doRow ? row : nil,
                                                    date: Date().timeIntervalSince1970))
                    finish()
                }
                .buttonStyle(HotButtonStyle())
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            } footer: {
                Text("只影響「第一次做」的動作；練過的動作照你實際的紀錄加重。")
            }
            .listRowBackground(Color.clear)
        }
        .themeForm()
        .navigationTitle("程度評估")
        .onAppear(perform: load)
    }

    private func item<C: View>(on: Binding<Bool>, title: String, detail: String,
                               @ViewBuilder control: () -> C) -> some View {
        Section {
            Toggle(title, isOn: on)
            if on.wrappedValue {
                control()
            }
        } footer: {
            Text(detail)
        }
        .listRowBackground(Theme.surface)
    }

    private func load() {
        guard let r = LevelTest.current else { return }
        doPushups = r.pushups != nil; pushups = r.pushups ?? pushups
        doGoblet = r.gobletKg != nil; goblet = r.gobletKg ?? goblet
        doRow = r.rowKg != nil; row = r.rowKg ?? row
    }

    private func finish() {
        if let onDone { onDone() } else { dismiss() }
    }
}
