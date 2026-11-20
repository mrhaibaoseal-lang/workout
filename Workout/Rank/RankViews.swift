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
                RankBadge(tier: rank.tier, division: rank.division, size: 56)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(rank.title).font(.title3.bold())
                        Spacer()
                        Text("\(rank.points) 分").font(.subheadline).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    RankBar(rank: rank)
                    Text(nextText).font(.caption).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding()
            .background(
                LinearGradient(colors: [rank.tier.light.opacity(0.25), rank.tier.dark.opacity(0.12)],
                               startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 16)
            )
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
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(rank.tier.gradient)
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
        List {
            Section {
                VStack(spacing: 10) {
                    RankBadge(tier: rank.tier, division: rank.division, size: 140)
                    Text(rank.title).font(.title.bold())
                    Text("\(rank.points) 分").font(.headline).monospacedDigit().foregroundStyle(.secondary)
                    RankBar(rank: rank).padding(.horizontal, 30)
                    if let n = rank.toNext, let t = rank.nextTitle {
                        Text("再 \(n) 分升到 \(t)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("怎麼拿分") {
                rule("完成完整 60 分", "+\(RankEngine.fullPoints)")
                rule("完成精簡 20 分", "+\(RankEngine.shortPoints)")
                rule("只做 1 組", "+\(RankEngine.minimalPoints)")
                rule("破個人紀錄（每個動作）", "+\(RankEngine.prPoints)，每次最多 +\(RankEngine.prCap)")
                rule("達成每週 \(weeklyGoal) 次", "+\(RankEngine.goalBonus)")
                rule("連續達標加碼", "每週 +\(RankEngine.streakStep)，最多 +\(RankEngine.streakMax)")
                rule("這週只練 1 次", "−\(RankEngine.lightWeekPenalty)", bad: true)
                rule("整週沒練", "−\(RankEngine.emptyWeekPenalty)", bad: true)
            }

            Section("牌位") {
                ForEach(RankTier.allCases.reversed()) { t in
                    HStack(spacing: 12) {
                        RankBadge(tier: t, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.name).font(.headline)
                            Text(t == .champion ? "\(t.floor) 分以上"
                                 : t.hasDivisions ? "\(t.floor) 分起 · 每段 \(t.divisionSize) 分"
                                 : "\(t.floor) 分起")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if t == rank.tier {
                            Text("目前").font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(t.light.opacity(0.4), in: Capsule())
                        }
                    }
                    .opacity(t.rawValue > rank.tier.rawValue ? 0.55 : 1)
                }
            }

            Section("最近的分數變化") {
                if events.isEmpty {
                    Text("練完第一次就開始累積分數").foregroundStyle(.secondary)
                }
                ForEach(events.suffix(30).reversed()) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.reason)
                            Text(e.date.formatted(.dateTime.month().day()))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(e.delta >= 0 ? "+\(e.delta)" : "\(e.delta)")
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(e.delta >= 0 ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("牌位")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rule(_ title: String, _ value: String, bad: Bool = false) -> some View {
        LabeledContent(title) {
            Text(value).foregroundStyle(bad ? .red : .green).monospacedDigit()
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
        VStack(spacing: 20) {
            Spacer()
            Text(promoted ? "晉級！" : "掉段了")
                .font(.largeTitle.bold())
                .foregroundStyle(promoted ? rank.tier.dark : Color.secondary)
            RankBadge(tier: rank.tier, division: rank.division, size: 180)
                .scaleEffect(appear ? 1 : 0.3)
                .rotationEffect(.degrees(appear ? 0 : -25))
                .opacity(appear ? 1 : 0)
            Text(rank.title).font(.title.bold())
            Text(promoted ? "繼續保持，下一段在等你。" : "沒關係，這週多練一次就拿回來。")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("好").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(rank.tier.dark)
        }
        .padding(24)
        .background(
            RadialGradient(colors: [rank.tier.light.opacity(promoted ? 0.45 : 0.15), .clear],
                           center: .center, startRadius: 10, endRadius: 400)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55).delay(0.15)) { appear = true }
            if promoted { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }
}
