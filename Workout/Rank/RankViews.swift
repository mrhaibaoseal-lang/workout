import SwiftUI
import SwiftData

/// 小卡：獎章＋目前牌位＋到下一段的進度。點了看詳情。
struct RankCard: View {
    let rank: Rank

    var body: some View {
        NavigationLink {
            RankDetailView()
        } label: {
            HStack(spacing: 14) {
                RankBadge(tier: rank.tier, division: rank.division, size: 58)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("牌位").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                        Spacer()
                        Text("\(rank.points) 分").font(Theme.number(13, .bold)).foregroundStyle(Theme.muted)
                    }
                    Text(rank.title)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(rank.tier.light)
                    RankBar(rank: rank)
                    Text(nextText).font(.caption).foregroundStyle(Theme.muted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [rank.tier.dark.opacity(0.35), Theme.surface],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(rank.tier.dark.opacity(0.7), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var nextText: String {
        if let n = rank.toNext, let t = rank.nextTitle { return "再 \(n) 分升到 \(t)" }
        return "已經是最高牌位"
    }
}

struct RankBar: View {
    let rank: Rank

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(LinearGradient(colors: [rank.tier.dark, rank.tier.light],
                                              startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, g.size.width * rank.fraction))
            }
        }
        .frame(height: 8)
    }
}

struct RankDetailView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4

    var body: some View {
        let events = RankEngine.ledger(sessions: sessions, goal: weeklyGoal)
        let rank = Rank(points: RankEngine.total(events))
        ScrollView {
            VStack(spacing: 12) {
                hero(rank)
                rules
                ladder(rank)
                history(events)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .themeScreen()
        .navigationTitle("牌位")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func hero(_ rank: Rank) -> some View {
        VStack(spacing: 10) {
            RankBadge(tier: rank.tier, division: rank.division, size: 140)
            Text(rank.title).font(.system(size: 30, weight: .black)).foregroundStyle(rank.tier.light)
            Text("\(rank.points) 分").font(Theme.number(17, .bold)).foregroundStyle(Theme.muted)
            RankBar(rank: rank).padding(.horizontal, 30)
            if let n = rank.toNext, let t = rank.nextTitle {
                Text("再 \(n) 分升到 \(t)").font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RadialGradient(colors: [rank.tier.dark.opacity(0.45), Theme.surface],
                           center: .top, startRadius: 0, endRadius: 300),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("怎麼拿分")
            rule("完成完整 60 分", "+\(RankEngine.fullPoints)")
            rule("完成精簡 20 分", "+\(RankEngine.shortPoints)")
            rule("只做 1 組", "+\(RankEngine.minimalPoints)")
            rule("破個人紀錄（每個動作）", "+\(RankEngine.prPoints)，單次最多 +\(RankEngine.prCap)")
            rule("一週練滿 \(weeklyGoal) 次", "+\(RankEngine.goalBonus)")
            rule("連續達標加碼", "每週再 +\(RankEngine.streakStep)，最多 +\(RankEngine.streakMax)")
            rule("這週只練 1 次", "−\(RankEngine.lightWeekPenalty)", bad: true)
            rule("整週沒練", "−\(RankEngine.emptyWeekPenalty)", bad: true)
            Text("每週一結算上一週。分數由訓練紀錄即時算出，刪紀錄或改每週目標都會重算。")
                .font(.caption).foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    private func ladder(_ rank: Rank) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("牌位")
            ForEach(RankTier.allCases.reversed()) { t in
                let reached = t.rawValue <= rank.tier.rawValue
                HStack(spacing: 12) {
                    RankBadge(tier: t, size: 44)
                        .saturation(reached ? 1 : 0.15)
                        .opacity(reached ? 1 : 0.6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.name).font(.headline).foregroundStyle(reached ? t.light : Theme.muted)
                        Text(t == .champion ? "\(t.floor) 分以上"
                             : t.hasDivisions ? "\(t.floor) 分起 · III → II → I 每段 \(t.divisionSize) 分"
                             : "\(t.floor) 分起")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if t == rank.tier {
                        Tag(text: "目前", fg: Theme.bg, bg: t.light)
                    }
                }
            }
        }
        .themeCard()
    }

    private func history(_ events: [RankEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("最近的分數變化")
            if events.isEmpty {
                Text("練完第一次就開始累積分數").foregroundStyle(Theme.muted)
            }
            ForEach(events.suffix(30).reversed()) { e in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.reason).foregroundStyle(Theme.fg)
                        Text(e.date.formatted(.dateTime.month().day()))
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text(e.delta >= 0 ? "+\(e.delta)" : "\(e.delta)")
                        .font(Theme.number(17, .bold))
                        .foregroundStyle(e.delta >= 0 ? Theme.green : Theme.hotText)
                }
                .padding(.vertical, 2)
            }
        }
        .themeCard()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline.weight(.heavy)).foregroundStyle(Theme.fg)
    }

    private func rule(_ title: String, _ value: String, bad: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(Theme.fg)
            Spacer()
            Text(value).font(.subheadline.weight(.bold))
                .foregroundStyle(bad ? Theme.hotText : Theme.green)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// 晉級／降級時跳出來的畫面。
struct RankChangeView: View {
    let rank: Rank
    let promoted: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(promoted ? "晉級！" : "掉段了")
                .font(.system(size: 40, weight: .black))
                .foregroundStyle(promoted ? rank.tier.light : Theme.muted)
            RankBadge(tier: rank.tier, division: rank.division, size: 190)
                .scaleEffect(appear ? 1 : 0.3)
                .rotationEffect(.degrees(appear ? 0 : -25))
                .opacity(appear ? 1 : 0)
            Text(rank.title).font(.title.weight(.heavy)).foregroundStyle(Theme.fg)
            Text(promoted ? "繼續保持，下一段在等你。" : "沒關係，這週多練一次就拿回來。")
                .foregroundStyle(Theme.muted)
            Spacer()
            Button("好") { dismiss() }
                .buttonStyle(HotButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Theme.bg
                RadialGradient(colors: [rank.tier.dark.opacity(promoted ? 0.6 : 0.25), .clear],
                               center: .center, startRadius: 10, endRadius: 420)
            }
            .ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { appear = true }
            if promoted { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }
}
