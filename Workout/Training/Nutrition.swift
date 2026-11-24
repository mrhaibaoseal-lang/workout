import SwiftUI

extension Keys {
    /// 每天吃了幾克蛋白質，JSON [yyyy-MM-dd: 克]
    static let proteinLog = "proteinLog"
}

/// 增肌飲食（0.33.0）：不做食物資料庫，只做兩件事——
/// 1. 每天快速記蛋白質（點常見份量），目標＝體重 × 1.6 g（上限看到 2.2 g 就夠了）。
/// 2. 用體重紀錄算每週增重速度：新手增肌每週增加體重的 0.25–0.5% 最好，太快多半是長脂肪、太慢長不了肌肉。
enum Nutrition {
    /// 每公斤體重每天幾克蛋白質
    static let gramsPerKg = 1.6
    static let upperGramsPerKg = 2.2

    struct Portion: Identifiable {
        let name: String
        let grams: Int
        let icon: String
        var id: String { name }
    }

    /// 常見份量（台灣常吃的，取整數）
    static let portions: [Portion] = [
        Portion(name: "一份肉／魚", grams: 25, icon: "fork.knife"),
        Portion(name: "乳清一匙", grams: 22, icon: "takeoutbag.and.cup.and.straw"),
        Portion(name: "雞蛋一顆", grams: 7, icon: "oval.portrait"),
        Portion(name: "牛奶一杯", grams: 8, icon: "cup.and.saucer"),
        Portion(name: "無糖豆漿一杯", grams: 9, icon: "cup.and.saucer.fill"),
        Portion(name: "豆腐半盒", grams: 10, icon: "square.split.2x2"),
        Portion(name: "希臘優格一杯", grams: 12, icon: "takeoutbag.and.cup.and.straw.fill"),
    ]

    static func target(bodyWeight: Double) -> Int {
        Int((bodyWeight * gramsPerKg).rounded())
    }

    // MARK: 熱量估算（0.43.0：問卷填的身高、年齡、性別）

    /// 一週練 3–4 次的活動係數
    static let activityFactor = 1.55

    struct Calories: Equatable {
        /// 一天大約消耗（維持體重）
        let maintenance: Int
        /// 增肌建議吃的量（維持 + 每週增 0.25–0.5% 體重所需的盈餘，取中間值）
        let target: Int
        var surplus: Int { target - maintenance }
    }

    /// Mifflin-St Jeor 基礎代謝率 × 活動係數。要有身高、年齡、體重，而且性別選了男或女才算；
    /// 「不想說」或沒填就回傳 nil，畫面用原本的增重速度建議（不顯示大卡數字）。
    static func calories(bodyWeight: Double, heightCm: Double, age: Int?, sex: Sex?) -> Calories? {
        guard bodyWeight > 0, heightCm > 0, let age, let sex, sex != .undisclosed else { return nil }
        let base = 10 * bodyWeight + 6.25 * heightCm - 5 * Double(age) + (sex == .male ? 5 : -161)
        guard base > 0 else { return nil }
        let maintenance = base * activityFactor
        // 每週增 0.375% 體重，1 kg 約 7700 大卡
        let surplus = bodyWeight * 0.00375 * 7700 / 7
        return Calories(maintenance: Int((maintenance / 10).rounded()) * 10,
                        target: Int(((maintenance + surplus) / 10).rounded()) * 10)
    }

    // MARK: 蛋白質紀錄

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ d: Date) -> String { dayFormat.string(from: d) }

    static func load() -> [String: Int] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.proteinLog),
              let dict = try? JSONDecoder().decode([String: Int].self, from: Data(raw.utf8)) else { return [:] }
        return dict
    }

    static func save(_ dict: [String: Int]) {
        // 只留最近 120 天
        let cutoff = key(Calendar.current.date(byAdding: .day, value: -120, to: .now) ?? .now)
        let kept = dict.filter { $0.key >= cutoff && $0.value > 0 }
        guard let data = try? JSONEncoder().encode(kept), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.proteinLog)
    }

    static func add(_ grams: Int, on date: Date = .now) {
        var d = load()
        d[key(date), default: 0] = max(0, d[key(date), default: 0] + grams)
        save(d)
    }

    /// 最近 n 天（含今天）有記錄的日子的平均；沒記錄的天不算。
    static func average(_ log: [String: Int], days n: Int, now: Date = .now) -> Int? {
        stats(log, days: n, endingOn: now)?.avg
    }

    /// endingOn 那天往前 n 天（含那天）：有記錄的日子的平均、記了幾天。
    /// 沒記錄的天不算進平均，所以要一起看記了幾天（只記一天 150 g 不代表整週都吃夠）。
    static func stats(_ log: [String: Int], days n: Int, endingOn end: Date) -> (avg: Int, logged: Int)? {
        let cal = Calendar.current
        let vals = (0..<n).compactMap { i -> Int? in
            guard let d = cal.date(byAdding: .day, value: -i, to: end) else { return nil }
            return log[key(d)]
        }.filter { $0 > 0 }
        return vals.isEmpty ? nil : (vals.reduce(0, +) / vals.count, vals.count)
    }

    /// 週總結要記滿幾天，才拿平均給建議
    static let minLoggedDays = 4

    // MARK: 增重速度

    enum Pace: Equatable {
        /// 資料不夠（最近 6 週內至少要 2 筆、相隔 10 天以上）
        case unknown
        case losing, slow, good, fast

        var title: String {
            switch self {
            case .unknown: "還算不出來"
            case .losing: "體重在掉"
            case .slow: "太慢"
            case .good: "剛好"
            case .fast: "太快"
            }
        }

        var advice: String {
            switch self {
            case .unknown: "每週同一天早上（上完廁所、吃早餐前）量一次體重，兩週後就算得出增重速度。"
            case .losing: "吃的不夠，肌肉很難長：每天多吃約 300 大卡（例如多一碗飯＋一杯牛奶）。"
            case .slow: "再多吃一點：每天多約 200 大卡（例如一根香蕉＋一杯豆漿）。"
            case .good: "這個速度大部分長的是肌肉，照現在吃就好。"
            case .fast: "長太快多半是脂肪：每天少約 200 大卡，先從含糖飲料、油炸減。"
            }
        }

        var color: Color {
            switch self {
            case .good: Theme.green
            case .unknown: Theme.muted
            default: Theme.hotText
            }
        }
    }

    /// 每週體重變化（kg）：最近 6 週體重的線性回歸斜率。資料不夠回傳 nil。
    static func weeklyChange(_ points: [(date: Date, weight: Double)], now: Date = .now) -> Double? {
        let from = now.addingTimeInterval(-42 * 86400)
        let pts = points.filter { $0.weight > 0 && $0.date >= from && $0.date <= now }
        guard pts.count >= 2, let a = pts.map(\.date).min(), let b = pts.map(\.date).max(),
              b.timeIntervalSince(a) >= 10 * 86400 else { return nil }
        let xs = pts.map { $0.date.timeIntervalSince(a) / (7 * 86400) }
        let ys = pts.map(\.weight)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        var num = 0.0, den = 0.0
        for i in xs.indices {
            num += (xs[i] - mx) * (ys[i] - my)
            den += (xs[i] - mx) * (xs[i] - mx)
        }
        return den > 0 ? num / den : nil
    }

    /// 每週變化占體重的比例 → 太慢／剛好／太快。
    static func pace(weeklyChange c: Double?, bodyWeight: Double) -> Pace {
        guard let c, bodyWeight > 0 else { return .unknown }
        let pct = c / bodyWeight * 100
        if pct < -0.1 { return .losing }
        if pct < 0.2 { return .slow }
        if pct <= 0.5 { return .good }
        return .fast
    }

    /// 好的速度換成 kg（給畫面顯示目標）
    static func goodRange(bodyWeight: Double) -> ClosedRange<Double> {
        (bodyWeight * 0.0025)...(bodyWeight * 0.005)
    }
}

/// 身體頁的「增肌飲食」卡片。
struct NutritionCard: View {
    let weights: [(date: Date, weight: Double)]
    @State private var log: [String: Int] = Nutrition.load()
    @State private var showCustom = false
    @State private var custom = 20

    private var bodyWeight: Double {
        weights.last?.weight ?? (StartWeight.bodyWeight > 0 ? StartWeight.bodyWeight : StartWeight.defaultBodyWeight)
    }

    private var today: Int { log[Nutrition.key(.now)] ?? 0 }
    private var target: Int { Nutrition.target(bodyWeight: bodyWeight) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("增肌飲食").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                if let st = Nutrition.stats(log, days: 7, endingOn: .now) {
                    Text("7 天記了 \(st.logged) 天，平均 \(st.avg) g").font(.caption).foregroundStyle(Theme.muted)
                }
            }
            proteinRow
            portionChips
            Divider().overlay(Theme.divider)
            paceRow
        }
        .themeCard()
        .sheet(isPresented: $showCustom) { customSheet }
        // 從備份還原、或隔天回到這頁時重新讀
        .onAppear { log = Nutrition.load() }
    }

    private var proteinRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(today)").font(Theme.number(28)).foregroundStyle(today >= target ? Theme.green : Theme.fg)
                Text("/ \(target) g 蛋白質").font(.subheadline).foregroundStyle(Theme.muted)
                Spacer()
                if today > 0 {
                    Button("清除") { change(-today) }
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            ProgressView(value: min(1, Double(today) / Double(max(target, 1))))
                .tint(today >= target ? Theme.green : Theme.accent)
            Text(today >= target ? "今天達標了" : "今天還差 \(target - today) g（體重 × \(Progression.format(Nutrition.gramsPerKg)) g）")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
    }

    private var portionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Nutrition.portions) { p in
                    Button { change(p.grams) } label: {
                        VStack(spacing: 2) {
                            Text(p.name).font(.caption.weight(.semibold))
                            Text("+\(p.grams) g").font(.caption2).foregroundStyle(Theme.muted)
                        }
                        .foregroundStyle(Theme.fg)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                Button { showCustom = true } label: {
                    Label("其他", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accentSoft)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.line))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var paceRow: some View {
        let change = Nutrition.weeklyChange(weights)
        let pace = Nutrition.pace(weeklyChange: change, bodyWeight: bodyWeight)
        let good = Nutrition.goodRange(bodyWeight: bodyWeight)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("增重速度").font(.subheadline).foregroundStyle(Theme.fg)
                Text(pace.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(pace.color)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .overlay(Capsule().stroke(pace.color.opacity(0.6)))
                Spacer()
                if let change {
                    Text("每週 \(change >= 0 ? "+" : "")\(String(format: "%.2f", change)) kg")
                        .font(.caption.weight(.semibold)).foregroundStyle(Theme.fg)
                }
            }
            Text("目標每週 +\(String(format: "%.2f", good.lowerBound))～\(String(format: "%.2f", good.upperBound)) kg。" + pace.advice)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if let cal = Nutrition.calories(bodyWeight: bodyWeight, heightCm: UserProfile.heightCm,
                                            age: UserProfile.age(), sex: UserProfile.sex) {
                Text("估計你一天大約消耗 \(cal.maintenance) 大卡，增肌可以吃到 \(cal.target) 大卡左右（多 \(cal.surplus)）。這是用身高、年齡、性別算的粗估，照增重速度微調。")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var customSheet: some View {
        NavigationStack {
            Form {
                Stepper("\(custom) g", value: $custom, in: 1...100)
            }
            .themeForm()
            .navigationTitle("記蛋白質")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { showCustom = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加上") { change(custom); showCustom = false }
                }
            }
        }
        .presentationDetents([.height(220)])
    }

    private func change(_ g: Int) {
        Nutrition.add(g)
        log = Nutrition.load()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
