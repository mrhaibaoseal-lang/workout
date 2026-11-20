import SwiftUI
import SwiftData

/// 分數入帳動畫：練完回到今天頁時，牌位小卡的分數從舊值跑到新值，旁邊冒出加分標籤。
struct RankIntake: Identifiable {
    struct Chip {
        let text: String
        let delta: Int
    }

    let id = UUID()
    let from: Int
    let to: Int
    let chips: [Chip]
    let start = Date()
    /// 跨過小段的那一刻（秒），沒跨過是 nil
    let crossing: Double?

    static let duration = 2.4

    init(from: Int, to: Int, chips: [Chip]) {
        self.from = from
        self.to = to
        self.chips = chips
        var cross: Double?
        let first = Rank(points: from).index
        var t = 0.35
        while t <= 1.95 {
            if Rank(points: Self.points(from, to, t)).index != first { cross = t; break }
            t += 0.02
        }
        crossing = cross
    }

    static func points(_ from: Int, _ to: Int, _ t: Double) -> Int {
        let u = FXMath.smooth(FXMath.seg(t, 0.35, 1.9))
        return Int((Double(from) + Double(to - from) * u).rounded())
    }
}

/// 小卡：獎章＋目前牌位＋到下一段的進度。點了看詳情。
struct RankCard: View {
    let rank: Rank
    var intake: RankIntake? = nil

    var body: some View {
        NavigationLink {
            RankDetailView()
        } label: {
            if let intake {
                TimelineView(.animation) { ctx in
                    content(t: ctx.date.timeIntervalSince(intake.start), intake: intake)
                }
            } else {
                content(t: nil, intake: nil)
            }
        }
        .buttonStyle(.plain)
    }

    private func content(t: Double?, intake: RankIntake?) -> some View {
        let shown = t.flatMap { tt in intake.map { RankIntake.points($0.from, $0.to, tt) } } ?? rank.points
        let r = Rank(points: shown)
        let tt = t ?? 99
        let counting = t != nil && tt > 0.35 && tt < 1.9
        let pop: Double = {
            guard let c = intake?.crossing, tt >= c else { return 1 }
            return 1 + 0.35 * exp(-(tt - c) * 7) * cos((tt - c) * 16)
        }()
        let glow = t == nil ? 0 : sin(.pi * FXMath.seg(tt, 0, RankIntake.duration)) * 0.9
        let up = (intake?.to ?? 0) >= (intake?.from ?? 0)
        return HStack(spacing: 14) {
            RankBadge(tier: r.tier, division: r.division, size: 58, motion: .shine)
                .id(r.index)
                .scaleEffect(pop)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("牌位").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text("\(shown) 分")
                        .font(Theme.number(13, .bold))
                        .foregroundStyle(counting ? (up ? Theme.gold : Theme.hotText) : Theme.muted)
                        .scaleEffect(counting ? 1.25 : 1, anchor: .trailing)
                }
                Text(r.title)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(r.tier.light)
                RankBar(rank: r)
                Text(nextText(r)).font(.caption).foregroundStyle(Theme.muted)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [r.tier.dark.opacity(0.35 + 0.3 * glow), Theme.surface],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(r.tier.dark.opacity(0.7), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(r.tier.light.opacity(glow), lineWidth: 2)
            .shadow(color: r.tier.light.opacity(glow * 0.8), radius: 10))
        .overlay(alignment: .topTrailing) {
            if let intake, let t {
                chips(intake, t: t)
            }
        }
    }

    /// 加分標籤：一個個彈出來，往上飄走。
    private func chips(_ intake: RankIntake, t: Double) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            ForEach(Array(intake.chips.enumerated()), id: \.offset) { i, c in
                let a0 = 0.1 + Double(i) * 0.18
                let inP = FXMath.seg(t, a0, a0 + 0.3)
                let outP = FXMath.seg(t, 1.7 + Double(i) * 0.1, 2.3 + Double(i) * 0.1)
                Text("\(c.delta >= 0 ? "+" : "−")\(abs(c.delta)) \(c.text)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(c.delta >= 0 ? Theme.bg : .white)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(c.delta >= 0 ? Theme.gold : Theme.hot, in: Capsule())
                    .shadow(color: (c.delta >= 0 ? Theme.gold : Theme.hot).opacity(0.6), radius: 8)
                    .scaleEffect(0.4 + 0.6 * FXMath.easeOutBack(inP))
                    .opacity(inP * (1 - outP))
                    .offset(y: -28 * FXMath.easeInCubic(outP))
            }
        }
        .padding(.top, -10)
        .padding(.trailing, 10)
        .allowsHitTesting(false)
    }

    private func nextText(_ r: Rank) -> String {
        if let n = r.toNext, let t = r.nextTitle { return "再 \(n) 分升到 \(t)" }
        return "已經是最高牌位"
    }
}

/// 進度條：有一道光一直掃過；快升段（90% 以上）時整條發光脈動。
struct RankBar: View {
    let rank: Rank
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            let w = max(8, g.size.width * rank.fraction)
            let near = rank.fraction >= 0.9 && rank.toNext != nil
            if reduceMotion {
                bar(w: w, shimmer: nil, pulse: near ? 0.6 : 0)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    bar(w: w, shimmer: FXMath.fract(t / (near ? 1.4 : 2.6)),
                        pulse: near ? 0.45 + 0.45 * sin(t * 5) : 0)
                }
            }
        }
        .frame(height: 8)
    }

    private func bar(w: CGFloat, shimmer: Double?, pulse: Double) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.line)
            Capsule().fill(LinearGradient(colors: [rank.tier.dark, rank.tier.light],
                                          startPoint: .leading, endPoint: .trailing))
                .frame(width: w)
                .overlay(alignment: .leading) {
                    if let u = shimmer {
                        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.6), .white.opacity(0)],
                                       startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                            .offset(x: -28 + (w + 28) * CGFloat(u))
                    }
                }
                .clipShape(Capsule())
                .shadow(color: rank.tier.light.opacity(pulse), radius: 6)
        }
    }
}

struct RankDetailView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @State private var ladderShown = false
    @State private var preview: RankTier?

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
        .sheet(item: $preview) { t in
            RankPreviewSheet(tier: t, points: rank.points)
        }
    }

    private var rank: Rank { RankEngine.rank(sessions: sessions, goal: weeklyGoal) }

    private func hero(_ rank: Rank) -> some View {
        VStack(spacing: 10) {
            RankBadge(tier: rank.tier, division: rank.division, size: 140, motion: .live)
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
            HStack {
                sectionTitle("牌位")
                Spacer()
                Text("點一下看動畫").font(.caption).foregroundStyle(Theme.muted)
            }
            ForEach(RankTier.allCases.reversed()) { t in
                let reached = t.rawValue <= rank.tier.rawValue
                Button { preview = t } label: {
                HStack(spacing: 12) {
                    RankBadge(tier: t, size: 44, motion: reached ? .shine : .still)
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
                    } else if !reached {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // 由下往上（鐵牌先）依序滑進來
                .opacity(ladderShown ? 1 : 0)
                .offset(x: ladderShown ? 0 : 50)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(Double(t.rawValue) * 0.07), value: ladderShown)
            }
        }
        .themeCard()
        .onAppear { ladderShown = true }
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

/// 牌位預覽：大獎章播完整待機動畫，可以切換 III／II／I；還沒到的牌位當作解鎖預告。
struct RankPreviewSheet: View {
    let tier: RankTier
    let points: Int
    @State private var division = 1

    var body: some View {
        let reached = points >= tier.floor
        VStack(spacing: 14) {
            Capsule().fill(Theme.line).frame(width: 40, height: 5).padding(.top, 8)
            Text(reached ? "已達成" : "解鎖預告")
                .font(.caption.weight(.heavy)).tracking(2)
                .foregroundStyle(reached ? tier.light : Theme.muted)
            RankBadge(tier: tier, division: tier.hasDivisions ? division : nil, size: 170, motion: .live)
                .id(division)
                .padding(.vertical, 6)
            Text(tier.hasDivisions ? "\(tier.name) \(["I", "II", "III"][division - 1])" : tier.name)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(tier.light)
            if tier.hasDivisions {
                Picker("小段", selection: $division) {
                    Text("III").tag(3)
                    Text("II").tag(2)
                    Text("I").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
            }
            Text(reached ? "\(tier.floor) 分起" : "還差 \(tier.floor - points) 分（\(tier.floor) 分起）")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(colors: [tier.dark.opacity(0.7), Theme.bg], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }
}
