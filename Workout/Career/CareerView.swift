import SwiftUI
import SwiftData

/// 「選手」分頁：等級、排名、訓練營、裝備、徽章、押注、請假。
struct CareerView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(CareerStore.planLogKey) private var planLogRaw = ""
    @AppStorage(CareerStore.leaveKey) private var leaveRaw = ""
    @AppStorage(CareerStore.betKey) private var betRaw = ""
    @AppStorage(CareerStore.cardBuyKey) private var cardRaw = ""
    @AppStorage(CareerStore.equippedKey) private var equippedRaw = ""
    @AppStorage(CareerStore.nameKey) private var name = ""
    @AppStorage(CareerStore.nicknameKey) private var nickname = ""
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4

    @State private var editingName = false
    @State private var draftName = ""
    @State private var draftNick = ""
    @State private var showLeave = false
    @State private var showHistory = false

    private func career(_ inputs: [FightInput]) -> CareerState {
        _ = (planLogRaw, leaveRaw, betRaw, cardRaw, equippedRaw, weeklyGoal)
        return CareerEngine.run(CareerInputs.load(inputs))
    }

    var body: some View {
        let inputs = sessions.map(FightInput.init)
        let state = career(inputs)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header(state)
                    ladder(state)
                    campCard(state)
                    QuestCard(quests: state.quests)
                    streakCard(state)
                    betCard(state)
                    attributesCard(Attributes.compute(inputs, streak: state.displayStreak))
                    gearCard(state)
                    wardrobeCard(state)
                    shadowCard(ShadowStats.compare(inputs))
                    milestoneCard(state)
                    badgeCard(state)
                    leaveCard
                    eventsCard(state)
                    NavigationLink {
                        CareerRulesView()
                    } label: {
                        Label("規則說明", systemImage: "book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("選手")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHistory = true } label: {
                        Label("比賽紀錄", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showLeave) { LeaveSheet() }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .alert("選手名稱", isPresented: $editingName) {
                TextField("綽號（例如：鐵臂）", text: $draftNick)
                TextField("名字", text: $draftName)
                Button("取消", role: .cancel) {}
                Button("儲存") {
                    nickname = draftNick.trimmingCharacters(in: .whitespaces)
                    name = draftName.trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }

    // MARK: Header

    private func header(_ s: CareerState) -> some View {
        VStack(spacing: 12) {
            FighterAvatar(owned: s.owned, size: 120)
            Button {
                draftName = name
                draftNick = nickname
                editingName = true
            } label: {
                VStack(spacing: 2) {
                    if !nickname.isEmpty {
                        Text("「\(nickname)」").font(.subheadline.bold()).foregroundStyle(CareerColors.gold)
                    }
                    HStack(spacing: 6) {
                        Text(name.isEmpty ? "無名選手" : name).font(.rounded(.title))
                        Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Chip(text: s.rankText, symbol: s.champion ? "crown.fill" : "chart.bar.fill", color: CareerColors.gold)
                Chip(text: "狀態 \(s.conditionTitle) \(s.condition)", symbol: "heart.fill",
                     color: CareerColors.condition(s.condition))
            }

            HStack(spacing: 0) {
                stat("Lv.\(s.level)", "等級")
                stat(s.record, "戰績")
                stat("\(s.points)", "排名積分")
                stat("\(s.purse)", "獎金")
            }
            XPBar(xp: s.xp)

            Text("KO \(s.ko) · 降伏 \(s.sub) · 判定 \(s.dec) · 大賽 \(s.campWins) 勝 \(s.campLosses) 敗 · 棄權 \(s.forfeits)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("選手外型之後再設計，現在先用暫時的圖示。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.rounded(.title3)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Ladder

    private func ladder(_ s: CareerState) -> some View {
        let tiers: [Tier] = [.amateur, .regional, .prospect, .ranked, .contender, .champion]
        return VStack(alignment: .leading, spacing: 10) {
            Text("職業生涯").font(.headline)
            HStack(spacing: 4) {
                ForEach(tiers, id: \.self) { t in
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(t <= s.tier ? CareerColors.fight : Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        Text(t.title)
                            .font(.system(size: 10, weight: t == s.tier ? .bold : .regular))
                            .foregroundStyle(t == s.tier ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(ladderHint(s)).font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func ladderHint(_ s: CareerState) -> String {
        switch s.tier {
        case .champion: return "你是冠軍。每個訓練營都要衛冕，超過 14 天沒練腰帶會被剝奪。"
        case .contender: return "積分已達頭銜挑戰資格，這個訓練營的比賽就是頭銜戰。"
        default:
            let next = Tier(rawValue: s.tier.rawValue + 1) ?? .contender
            return "再 \(max(0, next.minPoints - s.points)) 積分升上「\(next.title)」。超過 3 天沒練，每天 −2 積分。"
        }
    }

    // MARK: Camp

    private func campCard(_ s: CareerState) -> some View {
        let c = s.camp
        let daysLeft = max(0, SharedStore.calendar.dateComponents([.day], from: SharedStore.calendar.startOfDay(for: .now), to: c.end).day ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("第 \(c.index + 1) 個訓練營").font(.headline)
                Spacer()
                Text("\(c.fightKind) · 剩 \(daysLeft) 天").font(.subheadline.bold()).foregroundStyle(CareerColors.fight)
            }
            HStack(spacing: 12) {
                Image(systemName: "person.fill.questionmark")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("對手「\(c.opponent.nick)」\(c.opponent.name)").font(.subheadline.bold())
                    Text("訓練營結束前練滿 \(c.requirement) 場就贏").font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { m in
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(m <= c.milestones ? CareerColors.gold : Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        Text("\(m * 25)%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Text("目前 \(c.sessions) / \(c.requirement) 場。每到 25% 拿 150 XP、100 獎金。沒達標會輸掉比賽、記一敗。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Streak & cards

    private func streakCard(_ s: CareerState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("連續 \(s.displayStreak) 週", systemImage: "flame.fill")
                    .font(.headline).foregroundStyle(.orange)
                Spacer()
                Text("最長 \(max(s.bestStreak, s.displayStreak)) 週").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("XP 倍率 ×\(String(format: "%.2f", 1 + 0.05 * Double(min(s.streak, 10))))（每連續 1 週 +0.05，最多 ×1.5）")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                HStack(spacing: 4) {
                    ForEach(0..<2, id: \.self) { i in
                        Image(systemName: i < s.cards ? "shield.fill" : "shield")
                            .foregroundStyle(i < s.cards ? Color.blue : Color.secondary)
                    }
                }
                Text("保護卡 \(s.cards) / 2").font(.subheadline)
                Spacer()
                Button("用 300 獎金買") { CareerStore.buyCard() }
                    .buttonStyle(.bordered)
                    .disabled(s.purse < 300 || s.cards >= 2)
            }
            Text("一週練不到 2 次時自動用掉一張，連續週數不會斷。每週練滿 \(weeklyGoal) 次送一張。")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Bets

    private func betCard(_ s: CareerState) -> some View {
        let cal = SharedStore.calendar
        let thisWeek = SharedStore.weekStart(.now)
        let nextWeek = cal.date(byAdding: .day, value: 7, to: thisWeek)!
        let dayIndex = cal.dateComponents([.day], from: thisWeek, to: cal.startOfDay(for: .now)).day ?? 0
        let bets = CareerStore.bets()
        let pending = bets.filter { $0.weekStart >= thisWeek }.reduce(0) { $0 + $1.stake }
        return VStack(alignment: .leading, spacing: 12) {
            Text("押注").font(.headline)
            Text("押自己會練滿 \(weeklyGoal) 次。成功拿回押金再多贏一樣多，失敗押金沒收。")
                .font(.footnote).foregroundStyle(.secondary)
            betRow("這週", week: thisWeek, open: dayIndex < 2, bets: bets, free: s.purse - pending)
            Divider()
            betRow("下週", week: nextWeek, open: true, bets: bets, free: s.purse - pending)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func betRow(_ label: String, week: Date, open: Bool, bets: [Bet], free: Int) -> some View {
        HStack {
            Text(label).font(.subheadline.bold())
            Spacer()
            if let bet = bets.first(where: { $0.weekStart == week }) {
                Text("已押 \(bet.stake)").font(.subheadline).foregroundStyle(CareerColors.gold)
                if open {
                    Button("取消") { CareerStore.cancelBet(weekStart: week) }
                        .font(.subheadline)
                }
            } else if open {
                Menu {
                    ForEach([100, 300, 500], id: \.self) { stake in
                        Button("押 \(stake) 獎金") { CareerStore.placeBet(weekStart: week, stake: stake) }
                            .disabled(free < stake)
                    }
                } label: {
                    Text("押注").font(.subheadline.bold())
                }
                .disabled(free < 100)
            } else {
                Text("只能在週一、週二押").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Attributes

    private func attributesCard(_ a: Attributes) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("屬性").font(.headline)
            attrRow("力量", "上半身成長", a.power)
            attrRow("下盤", "下半身成長", a.legs)
            attrRow("耐力", "最近 28 天組數", a.stamina)
            attrRow("韌性", "連續週數", a.grit)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func attrRow(_ title: String, _ sub: String, _ value: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.bold())
                Text(sub).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 82, alignment: .leading)
            ProgressView(value: Double(value), total: 99).tint(CareerColors.fight)
            Text("\(value)").font(.rounded(.headline)).monospacedDigit().frame(width: 30, alignment: .trailing)
        }
    }

    // MARK: Gear

    private func gearCard(_ s: CareerState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("裝備").font(.headline)
            ForEach(GearKind.allCases) { g in
                let lv = s.gearLevel(g)
                HStack(spacing: 12) {
                    Image(systemName: g.symbol)
                        .font(.title3)
                        .foregroundStyle(lv > 0 ? CareerColors.gold : Color.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.title).font(.subheadline.bold())
                        Text(g.rule).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lv > 0 ? "Lv.\(lv)" : "未解鎖").font(.rounded(.subheadline)).monospacedDigit()
                        Text(s.gearNext(g)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Wardrobe

    private func wardrobeCard(_ s: CareerState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("配色收藏").font(.headline)
                Spacer()
                Text("\(s.owned.count) / \(Cosmetics.all.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            Text("每場勝利有機率掉落：KO 35%、降伏 25%、判定 20%。重複的會換成獎金。")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(GearSlot.allCases) { slot in
                let current = Cosmetics.equipped(slot, owned: s.owned)
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(slot.title)：\(current.name)").font(.subheadline.bold())
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Cosmetics.all.filter { $0.slot == slot }) { item in
                                swatch(item, owned: s.owned.contains(item.id), selected: item.id == current.id)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func swatch(_ item: Cosmetic, owned: Bool, selected: Bool) -> some View {
        Button {
            if owned { CareerStore.equip(item) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(owned ? item.color : Color.secondary.opacity(0.15))
                    if !owned {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(selected ? Color.primary : item.rarity.color.opacity(0.6),
                                               lineWidth: selected ? 3 : 1.5))
                Text(owned ? item.name : item.rarity.title)
                    .font(.caption2)
                    .foregroundStyle(owned ? Color.primary : item.rarity.color)
            }
            .frame(width: 52)
        }
        .buttonStyle(.plain)
    }

    // MARK: Shadow

    private func shadowCard(_ c: (now: ShadowStats, before: ShadowStats)) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("影子對手：上個月的你").font(.headline)
            Text("最近 28 天 vs 前 28 天").font(.caption).foregroundStyle(.secondary)
            shadowRow("訓練次數", Double(c.now.sessions), Double(c.before.sessions), unit: "次")
            shadowRow("完成組數", Double(c.now.sets), Double(c.before.sets), unit: "組")
            shadowRow("總重量", c.now.tonnage, c.before.tonnage, unit: "kg")
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func shadowRow(_ title: String, _ now: Double, _ before: Double, unit: String) -> some View {
        let win = now >= before
        return HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text("\(Int(now).formatted()) vs \(Int(before).formatted()) \(unit)")
                .font(.subheadline).monospacedDigit()
            Image(systemName: win ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(win ? Color.green : Color.red)
        }
    }

    // MARK: Milestones

    private func milestoneCard(_ s: CareerState) -> some View {
        let next = Badges.tonnage.first { s.tonnage < $0.kg }
        let reached = Badges.tonnage.last { s.tonnage >= $0.kg }
        return VStack(alignment: .leading, spacing: 8) {
            Text("累積總重量").font(.headline)
            Text("\(Int(s.tonnage).formatted()) kg").font(.rounded(.title))
            if let r = reached {
                Text("你已經舉起\(r.name)的重量。").font(.subheadline)
            }
            if let n = next {
                ProgressView(value: s.tonnage, total: n.kg).tint(CareerColors.gold)
                Text("下一個：\(n.name)（\(Int(n.kg).formatted()) kg）").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Badges

    private func badgeCard(_ s: CareerState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("徽章").font(.headline)
                Spacer()
                Text("\(s.badges.count) / \(Badges.all.count)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 12) {
                ForEach(Badges.all) { b in
                    let got = s.badges[b.id] != nil
                    VStack(spacing: 4) {
                        Image(systemName: b.symbol)
                            .font(.title2)
                            .foregroundStyle(got ? CareerColors.gold : Color.secondary.opacity(0.4))
                            .frame(width: 48, height: 48)
                            .background((got ? CareerColors.gold : Color.secondary).opacity(0.12), in: Circle())
                        Text(b.name).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                        Text(b.detail).font(.system(size: 9)).foregroundStyle(.secondary)
                            .lineLimit(2).multilineTextAlignment(.center)
                    }
                    .opacity(got ? 1 : 0.6)
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Leave

    private var leaveCard: some View {
        let recent = CareerStore.leaves().suffix(5).reversed()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("請假").font(.headline)
                Spacer()
                Button("今天／昨天請假") { showLeave = true }
                    .buttonStyle(.bordered)
            }
            Text("生病、受傷、考試這類真的不能練的日子，請假就不算漏練。有整天活動的日子會自動算請假。")
                .font(.footnote).foregroundStyle(.secondary)
            ForEach(Array(recent)) { l in
                HStack {
                    Text(l.day.formatted(.dateTime.month().day().weekday()))
                    Text(l.reason.title).foregroundStyle(.secondary)
                    Spacer()
                    Button("取消") { CareerStore.removeLeave(l.day) }.font(.caption)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Events

    private func eventsCard(_ s: CareerState) -> some View {
        let list = Array(s.events.suffix(15).reversed())
        return VStack(alignment: .leading, spacing: 10) {
            Text("生涯紀事").font(.headline)
            if list.isEmpty {
                Text("練完第一場，這裡會開始記錄你的生涯。").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(list) { e in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(color(e.mood))
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(e.title).font(.subheadline.bold())
                            Spacer()
                            Text(e.date.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
                        }
                        if !e.detail.isEmpty {
                            Text(e.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func color(_ mood: CareerEvent.Mood) -> Color {
        switch mood {
        case .good: .green
        case .bad: .red
        case .neutral: .blue
        }
    }
}

struct CareerRulesView: View {
    private let sections: [(String, [String])] = [
        ("一場比賽", [
            "每次練完都是一場勝利：完整版 KO 勝、精簡版降伏勝、只做 1 組判定勝。",
            "經驗值：每組 +10；KO +100、降伏 +60、判定 +40；接住漏練 +50；每破一個紀錄 +50。",
            "連續週數讓經驗值加倍：每週 +5%，最多 ×1.5。",
        ]),
        ("排名（會掉）", [
            "勝場加積分：KO +10、降伏 +7、判定 +4。",
            "超過 3 天沒練，第 4 天起每天 −2 積分。請假日不算。",
            "業餘 0 → 地區賽 100 → 職業新秀 250 → 排名選手 500 → 頭銜挑戰者 900 → 冠軍。",
        ]),
        ("敗場", [
            "排定的訓練沒練：黃牌警告。",
            "連續兩次排定的訓練都沒練、中間也沒練：記一場棄權敗、−15 積分。",
            "訓練營結束時沒達標：輸掉比賽、記一敗、−20 積分。",
        ]),
        ("訓練營", [
            "每 6 週一個訓練營，第 6 週的減量週就是賽前調整週。",
            "目標場數 = 每週目標 × 6 × 70%（請假每 2 天少 1 場）。",
            "每到 25% 拿 150 XP、100 獎金；達標贏下比賽 +40 積分、+300 XP、+500 獎金。",
            "積分 900 以上時，比賽就是頭銜戰；當上冠軍後每個訓練營都是衛冕戰。",
        ]),
        ("冠軍腰帶", [
            "衛冕失敗，或超過 14 天沒練，腰帶被剝奪，積分降到 850。",
        ]),
        ("連續週數與保護卡", [
            "一週練 2 次以上，連續 +1。",
            "沒練到 2 次時，有保護卡就自動用掉一張保住連續；沒有就歸零（最長紀錄保留）。",
            "一週練滿每週目標送一張保護卡，最多 2 張；也可以用 300 獎金買。",
        ]),
        ("押注", [
            "押這週（週一、週二）或下週會練滿每週目標：100／300／500 獎金。",
            "成功拿回押金再多贏一樣多，失敗押金沒收。",
        ]),
        ("不會發生的事", [
            "不會扣等級、不會扣經驗值、不會沒收裝備或配色。",
            "請假、整天活動、排程沒排的日子都不會被罰。",
        ]),
    ]

    var body: some View {
        List {
            ForEach(sections, id: \.0) { section in
                Section(section.0) {
                    ForEach(section.1, id: \.self) { line in
                        Text(line).font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("規則說明")
    }
}
