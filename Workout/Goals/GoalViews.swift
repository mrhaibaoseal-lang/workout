import SwiftUI
import SwiftData

enum GoalSheet: String, Identifiable {
    case leave, bet, shield
    var id: String { rawValue }
}

// MARK: - 週任務卡（今天頁）

struct QuestCard: View {
    let quests: [Quest]
    let shields: Int
    let activeBet: Bet?
    let onSheet: (GoalSheet) -> Void

    private var doneCount: Int { quests.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("本週任務").font(.headline).foregroundStyle(Theme.fg)
                Text("\(doneCount)/\(quests.count)")
                    .font(Theme.number(13, .bold))
                    .foregroundStyle(doneCount == quests.count ? Theme.green : Theme.muted)
                Spacer()
                Button { onSheet(.shield) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: shields > 0 ? "shield.lefthalf.filled" : "shield")
                        Text("\(shields)")
                    }
                    .font(Theme.number(13, .bold))
                    .foregroundStyle(shields > 0 ? Theme.accent : Theme.muted)
                    .padding(.horizontal, 10).frame(minHeight: 30)
                    .background(Theme.raised, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("保護卡 \(shields) 張")
                Button { onSheet(.bet) } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                        Text(activeBet.map { "押 \($0.stake)" } ?? "押注")
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 10).frame(minHeight: 30)
                    .background(Theme.raised, in: Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(quests) { q in row(q) }
            }

            HStack(spacing: 6) {
                ForEach(0..<quests.count, id: \.self) { i in
                    Capsule().fill(i < doneCount ? Theme.gold : Theme.line).frame(height: 4)
                }
                Image(systemName: "shippingbox.fill")
                    .font(.caption)
                    .foregroundStyle(doneCount == quests.count ? Theme.gold : Theme.muted)
                Text(doneCount == quests.count ? "+1 箱已入袋" : "全破 +1 箱")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(doneCount == quests.count ? Theme.gold : Theme.muted)
            }
        }
        .themeCard()
    }

    private func row(_ q: Quest) -> some View {
        let p = q.target > 0 ? min(1, Double(q.current) / Double(q.target)) : 1
        return HStack(spacing: 12) {
            Image(systemName: q.done ? "checkmark" : q.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(q.done ? Theme.bg : Theme.accent)
                .frame(width: 34, height: 34)
                .background(q.done ? Theme.green : Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(q.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(q.done ? Theme.muted : Theme.fg)
                        .strikethrough(q.done, color: Theme.muted)
                    Spacer()
                    Text("\(min(q.current, q.target))/\(q.target)")
                        .font(Theme.number(12, .bold))
                        .foregroundStyle(Theme.muted)
                }
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line)
                        Capsule().fill(q.done ? Theme.green : Theme.accent).frame(width: g.size.width * p)
                    }
                }
                .frame(height: 5)
            }
            Text("+\(GoalEngine.questPoints)")
                .font(Theme.number(13, .bold))
                .foregroundStyle(q.done ? Theme.green : Theme.muted)
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 請假

struct LeaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Keys.leaves) private var leavesRaw = ""
    @State private var yesterday = false
    @State private var reason: LeaveReason = .tired

    private var day: Date {
        let today = Calendar.current.startOfDay(for: .now)
        return yesterday ? Calendar.current.date(byAdding: .day, value: -1, to: today)! : today
    }

    private var leaves: [String: LeaveReason] { GoalStore.leaves(leavesRaw) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("哪一天", selection: $yesterday) {
                        Text("今天").tag(false)
                        Text("昨天").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if let existing = leaves[GoalStore.key(day)] {
                        HStack(spacing: 12) {
                            Image(systemName: existing.icon).font(.title2).foregroundStyle(Theme.accent)
                            Text("\(yesterday ? "昨天" : "今天")已經請假：\(existing.title)")
                                .font(.headline).foregroundStyle(Theme.fg)
                        }
                        .themeCard()
                        Button("取消請假") { GoalStore.setLeave(day, nil); reload() }
                            .buttonStyle(GhostButtonStyle(stroke: Theme.hotLine))
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(LeaveReason.allCases) { r in
                                let on = r == reason
                                Button { reason = r } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: r.icon).font(.title3)
                                        Text(r.title).font(.footnote.weight(.bold))
                                    }
                                    .foregroundStyle(on ? Theme.bg : Theme.fg)
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .background(on ? Theme.accent : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(on ? Theme.accent : Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        Button {
                            GoalStore.setLeave(day, reason)
                            reload()
                            dismiss()
                        } label: {
                            Label("\(yesterday ? "昨天" : "今天")請假", systemImage: "bed.double.fill")
                        }
                        .buttonStyle(HotButtonStyle())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("請假的日子").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                        rule("不算漏練，不會跳「絕不連續兩次」提醒")
                        rule("每請 2 天，那週的週目標少 1 次")
                        rule("一週請假 4 天以上，那週不結算（不加分也不扣分，連續週數不斷）")
                        rule("狀態值不會因為請假下降")
                        rule("行程裡整天的活動自動算請假")
                    }
                    .themeCard()

                    recent
                }
                .padding(16)
            }
            .themeScreen()
            .navigationTitle("請假")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// 寫進 UserDefaults 後讓 @AppStorage 重新讀。
    private func reload() { leavesRaw = UserDefaults.standard.string(forKey: Keys.leaves) ?? "" }

    @ViewBuilder
    private var recent: some View {
        let list = leaves.compactMap { k, r in GoalStore.day(k).map { ($0, r) } }
            .filter { $0.0 > Date().addingTimeInterval(-60 * 86400) }
            .sorted { $0.0 > $1.0 }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("最近 60 天").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                ForEach(list.indices, id: \.self) { i in
                    let item = list[i]
                    HStack {
                        Image(systemName: item.1.icon).foregroundStyle(Theme.accent).frame(width: 24)
                        Text("\(item.0.formatted(.dateTime.month(.defaultDigits).day())) 週\(TimeFmt.weekday(item.0))")
                            .foregroundStyle(Theme.fg)
                        Text(item.1.title).foregroundStyle(Theme.muted)
                        Spacer()
                    }
                    .font(.subheadline)
                }
            }
            .themeCard()
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(Theme.accent)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - 押注

struct BetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventory: InventoryStore
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.bets) private var betsRaw = ""
    @State private var nextWeek = false
    @State private var stake = GoalEngine.betStakes[1]

    private var thisWeek: Date { SharedStore.weekStart(.now) }
    private var week: Date { nextWeek ? SharedStore.calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek)! : thisWeek }
    private var bets: [Bet] { GoalStore.bets(betsRaw) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("押自己會練滿週目標").font(.headline).foregroundStyle(Theme.fg)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                            Text("\(inventory.state.shards)").font(Theme.number(17)).foregroundStyle(Theme.fg)
                        }
                    }

                    Picker("哪一週", selection: $nextWeek) {
                        Text("本週").tag(false)
                        Text("下週").tag(true)
                    }
                    .pickerStyle(.segmented)

                    let allowed = GoalEngine.canBet(week: week)
                    if let b = bets.first(where: { $0.week == week }) {
                        Label("這週已經押了 \(b.stake) 碎片", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.bold)).foregroundStyle(Theme.green)
                            .themeCard()
                    } else if !allowed {
                        Label("本週只能在週一、週二押，可以先押下週", systemImage: "clock")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                            .themeCard()
                    } else {
                        HStack(spacing: 8) {
                            ForEach(GoalEngine.betStakes, id: \.self) { s in
                                let on = s == stake
                                Button { stake = s } label: {
                                    VStack(spacing: 2) {
                                        Text("\(s)").font(Theme.number(22))
                                        Text("贏 +\(s * 2)").font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(on ? Theme.bg : Theme.fg)
                                    .frame(maxWidth: .infinity, minHeight: 64)
                                    .background(on ? Color.cyan : Theme.surface,
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(on ? Color.cyan : Theme.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(inventory.state.shards < s)
                                .opacity(inventory.state.shards < s ? 0.4 : 1)
                            }
                        }
                        Button {
                            guard inventory.state.shards >= stake else { return }
                            inventory.state.shards -= stake
                            GoalStore.saveBets(bets + [Bet(week: week, stake: stake, placedAt: .now)])
                            betsRaw = UserDefaults.standard.string(forKey: Keys.bets) ?? ""
                            dismiss()
                        } label: {
                            Label("押 \(stake) 碎片", systemImage: "diamond.fill")
                        }
                        .buttonStyle(HotButtonStyle())
                        .disabled(inventory.state.shards < stake)
                        .opacity(inventory.state.shards < stake ? 0.4 : 1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("規則").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                        rule("押本週只能在週一、週二；下週隨時可以押，每週押一次")
                        rule("那週練滿週目標（請假後的目標）：拿回 2 倍碎片")
                        rule("沒練滿：押的碎片沒收")
                        rule("那週請假 4 天以上：原數退回")
                        rule("週一打開 App 時結算")
                    }
                    .themeCard()

                    history
                }
                .padding(16)
            }
            .themeScreen()
            .navigationTitle("押注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if !GoalEngine.canBet(week: thisWeek) && !bets.contains(where: { $0.week == thisWeek }) { nextWeek = true }
        }
    }

    @ViewBuilder
    private var history: some View {
        let list = bets.sorted { $0.week > $1.week }.prefix(8)
        if !list.isEmpty {
            let records = GoalEngine.weeks(dates: sessions.map(\.date), goal: weeklyGoal, ctx: .load())
            VStack(alignment: .leading, spacing: 8) {
                Text("押注紀錄").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                ForEach(Array(list)) { b in
                    let r = GoalEngine.result(of: b, records: records)
                    HStack {
                        Text("\(b.week.formatted(.dateTime.month(.defaultDigits).day())) 那週")
                            .foregroundStyle(Theme.fg)
                        Text("押 \(b.stake)").foregroundStyle(Theme.muted)
                        Spacer()
                        switch r {
                        case .pending: Text("進行中").foregroundStyle(Theme.accent)
                        case .won: Text("+\(b.stake * 2)").foregroundStyle(Theme.green)
                        case .lost: Text("−\(b.stake)").foregroundStyle(Theme.hotText)
                        case .refunded: Text("退回").foregroundStyle(Theme.muted)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .themeCard()
        }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(Color.cyan)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

// MARK: - 保護卡

struct ShieldSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var inventory: InventoryStore
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.shieldBuys) private var buysRaw = ""

    var body: some View {
        _ = buysRaw
        let held = GoalEngine.current(dates: sessions.map(\.date), goal: weeklyGoal, ctx: .load()).shields
        let price = GoalEngine.shieldPrice
        let canBuy = held < GoalEngine.shieldCap && inventory.state.shards >= price
        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 18) {
                        ForEach(0..<GoalEngine.shieldCap, id: \.self) { i in
                            ShieldIcon(filled: i < held)
                                .frame(width: 84, height: 96)
                        }
                    }
                    .padding(.top, 8)
                    Text("\(held) / \(GoalEngine.shieldCap) 張")
                        .font(Theme.number(22)).foregroundStyle(Theme.fg)

                    VStack(alignment: .leading, spacing: 6) {
                        rule("一週練滿週目標 → 得到 1 張（最多 2 張）")
                        rule("哪一週沒達標，自動用掉 1 張：連續達標的加碼不歸零、連續週數不中斷，也不扣分")
                        rule("手上沒有卡、或本來就沒有連續紀錄時不會用掉")
                    }
                    .themeCard()

                    Button {
                        guard canBuy else { return }
                        inventory.state.shards -= price
                        GoalStore.addShieldBuy()
                        buysRaw = UserDefaults.standard.string(forKey: Keys.shieldBuys) ?? ""
                    } label: {
                        Label("用 \(price) 碎片買 1 張", systemImage: "diamond.fill")
                    }
                    .buttonStyle(HotButtonStyle())
                    .disabled(!canBuy)
                    .opacity(canBuy ? 1 : 0.4)
                    Text(held >= GoalEngine.shieldCap ? "已經滿了" : "目前有 \(inventory.state.shards) 碎片")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(16)
            }
            .themeScreen()
            .navigationTitle("保護卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(Theme.accent)
            Text(text).font(.caption).foregroundStyle(Theme.muted)
        }
    }
}

/// 保護卡圖示：盾牌＋中間的閃電；沒有的那張是虛線外框。
struct ShieldIcon: View {
    let filled: Bool

    var body: some View {
        Canvas { c, size in
            let w = size.width, h = size.height
            var p = Path()
            p.move(to: CGPoint(x: w / 2, y: 2))
            p.addLine(to: CGPoint(x: w - 4, y: h * 0.16))
            p.addQuadCurve(to: CGPoint(x: w / 2, y: h - 2), control: CGPoint(x: w - 2, y: h * 0.72))
            p.addQuadCurve(to: CGPoint(x: 4, y: h * 0.16), control: CGPoint(x: 2, y: h * 0.72))
            p.closeSubpath()
            if filled {
                c.fill(p, with: .linearGradient(Gradient(colors: [Color(gearHex: "#9DB4FF"), Color(gearHex: "#3D5191")]),
                                                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                c.stroke(p, with: .color(.white.opacity(0.85)), lineWidth: 2.5)
                var b = Path()
                b.move(to: CGPoint(x: w * 0.56, y: h * 0.18))
                b.addLine(to: CGPoint(x: w * 0.34, y: h * 0.54))
                b.addLine(to: CGPoint(x: w * 0.5, y: h * 0.54))
                b.addLine(to: CGPoint(x: w * 0.42, y: h * 0.84))
                b.addLine(to: CGPoint(x: w * 0.68, y: h * 0.44))
                b.addLine(to: CGPoint(x: w * 0.52, y: h * 0.44))
                b.closeSubpath()
                c.fill(b, with: .color(Theme.gold))
            } else {
                c.stroke(p, with: .color(Theme.line), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
        }
        .accessibilityHidden(true)
    }
}
