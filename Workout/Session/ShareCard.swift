import SwiftUI

/// 練完的分享圖卡（0.33.0）：總重量、組數、時間、PR、牌位、角色，不用拍照。
/// 教練講評畫面按「分享」→ 畫成圖片 → 系統分享選單（存相簿、傳 LINE、IG 限動）。
struct ShareCardData {
    let facts: CoachFacts
    let rank: Rank
    let loadout: Loadout
    let date: Date

    /// 總重量（kg）：負重動作的重量 × 次數加總
    var volume: Double {
        facts.items.filter(\.loaded).flatMap(\.sets).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var sets: Int { facts.items.reduce(0) { $0 + $1.sets.count } }

    /// 徒手動作的總次數
    var bodyweightReps: Int {
        facts.items.filter { !$0.loaded && $0.unit == RepUnit.reps.label }.flatMap(\.sets).reduce(0) { $0 + $1.reps }
    }

    static func volumeText(_ v: Double) -> String {
        v >= 10000 ? String(format: "%.1f 噸", v / 1000) : "\(Int(v.rounded())) kg"
    }
}

struct ShareCardView: View {
    let data: ShareCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.date.formatted(.dateTime.year().month(.defaultDigits).day()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                    Text(data.facts.dayName)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Theme.fg)
                    Text("\(data.facts.lengthTitle) · \(data.facts.phaseTitle)")
                        .font(.footnote)
                        .foregroundStyle(Theme.accentSoft)
                }
                Spacer()
                VStack(spacing: 4) {
                    RankBadge(tier: data.rank.tier, division: data.rank.division, size: 64, motion: .still)
                    Text(data.rank.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.gold)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                CharacterView(move: .squat, loadout: data.loadout, animated: false, showStats: false)
                    .frame(width: 130, height: 190)
                VStack(alignment: .leading, spacing: 10) {
                    stat(ShareCardData.volumeText(data.volume), "總重量")
                    HStack(spacing: 16) {
                        stat("\(data.sets)", "正式組")
                        stat("\(data.facts.minutes)", "分鐘")
                    }
                    if data.bodyweightReps > 0 {
                        stat("\(data.bodyweightReps)", "徒手總次數")
                    }
                }
                Spacer(minLength: 0)
            }

            if !data.facts.prNames.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("破個人紀錄", systemImage: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                    ForEach(data.facts.prNames.prefix(4), id: \.self) { n in
                        Text(n).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.fg)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.goldBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 6) {
                grade("PERFECT", data.facts.perfect, Theme.green)
                grade("GOOD", data.facts.good, Theme.accent)
                grade("MISS", data.facts.miss, Theme.hotText)
                Spacer()
                Text("練壯")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(
            ZStack {
                Theme.bg
                Theme.heroGradient
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(Theme.number(26)).foregroundStyle(Theme.fg)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
    }

    private func grade(_ title: String, _ n: Int, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(title).font(.caption2.weight(.heavy)).foregroundStyle(color)
            Text("\(n)").font(.caption2.weight(.bold)).foregroundStyle(Theme.fg)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .overlay(Capsule().stroke(color.opacity(0.5)))
    }
}

/// 預覽圖卡＋分享按鈕（sheet）。
struct ShareCardSheet: View {
    let data: ShareCardData
    @Environment(\.dismiss) private var dismiss
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                ShareCardView(data: data)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let image {
                        ShareLink(item: image, preview: SharePreview("今天的訓練", image: image)) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: render)
    }

    @MainActor
    private func render() {
        let r = ImageRenderer(content: ShareCardView(data: data))
        r.scale = 3
        if let ui = r.uiImage { image = Image(uiImage: ui) }
    }
}
