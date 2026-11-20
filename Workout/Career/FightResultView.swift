import SwiftUI

struct FightResult {
    let report: FightReport
    let length: WorkoutLength
    let before: Attributes
    let after: Attributes
}

/// 練完之後的「比賽結果」畫面。固定暗色擂台風格。
struct FightResultView: View {
    let result: FightResult
    let onDone: () -> Void

    @State private var appear = false

    private var r: FightReport { result.report }
    private let gold = Color(hex: 0xE6C14A)
    private let panel = Color(white: 0.11)

    var body: some View {
        ZStack {
            Color(white: 0.04).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("第 \(r.fightNumber) 場 · 比賽結果")
                            .font(.caption.bold()).tracking(3)
                            .foregroundStyle(.gray)
                        Text("勝利")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(gold)
                            .scaleEffect(appear ? 1 : 0.5)
                            .opacity(appear ? 1 : 0)
                        Text("\(r.method.title) · \(result.length.title)")
                            .font(.title3.bold())
                        Text("戰績 \(r.recordAfter)").foregroundStyle(.gray)
                    }
                    .padding(.top, 24)

                    Image(systemName: "figure.boxing")
                        .font(.system(size: 80, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .offset(y: appear ? 0 : 20)
                        .opacity(appear ? 1 : 0)

                    if r.levelAfter > r.levelBefore {
                        banner("升級！Lv.\(r.levelBefore) → Lv.\(r.levelAfter)", symbol: "arrow.up.circle.fill", color: gold)
                    }
                    if r.tierAfter > r.tierBefore {
                        banner("升上「\(r.tierAfter.title)」", symbol: "chart.bar.fill", color: gold)
                    }

                    xpPanel

                    if !r.prs.isEmpty {
                        panelView(title: "新紀錄", symbol: "arrow.up.right", color: .green) {
                            ForEach(r.prs, id: \.self) { name in
                                Text(name).font(.subheadline)
                            }
                            Text("今晚最佳表現 +\(50 * r.prs.count) 獎金").font(.caption).foregroundStyle(.gray)
                        }
                    }

                    if let drop = r.drop {
                        panelView(title: "掉落", symbol: "gift.fill", color: drop.item.rarity.color) {
                            HStack(spacing: 12) {
                                Circle().fill(drop.item.color).frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(drop.item.rarity.color, lineWidth: 2))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(drop.item.slot.title)・\(drop.item.name)").font(.subheadline.bold())
                                    Text(drop.duplicate
                                         ? "\(drop.item.rarity.title)・已經有了，換成 \(drop.item.rarity.duplicatePurse) 獎金"
                                         : "\(drop.item.rarity.title)・到選手頁換上")
                                        .font(.caption).foregroundStyle(.gray)
                                }
                            }
                        }
                    }

                    if !r.quests.isEmpty || !r.milestones.isEmpty {
                        panelView(title: "完成", symbol: "checkmark.seal.fill", color: .green) {
                            ForEach(r.quests, id: \.self) { q in
                                Label("週任務：\(q)", systemImage: "checklist").font(.subheadline)
                            }
                            ForEach(r.milestones, id: \.self) { m in
                                Label(m, systemImage: "flag.fill").font(.subheadline)
                            }
                        }
                    }

                    if !r.badges.isEmpty {
                        panelView(title: "新徽章", symbol: "rosette", color: gold) {
                            ForEach(r.badges, id: \.self) { b in
                                Text(b).font(.subheadline.bold())
                            }
                        }
                    }

                    attributesPanel

                    Button(action: onDone) {
                        Text("完成")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal)
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .sensoryFeedback(.success, trigger: appear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appear = true }
        }
    }

    private var xpPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("經驗值").font(.subheadline.bold())
                Spacer()
                Text("+\(r.xp) XP").font(.rounded(.title3)).foregroundStyle(gold).monospacedDigit()
            }
            ForEach(Array(r.lines.enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(line.0)
                    Spacer()
                    Text("+\(line.1)").monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            if r.multiplier > 1 {
                HStack {
                    Text("連續週數倍率")
                    Spacer()
                    Text("×\(String(format: "%.2f", r.multiplier))").monospacedDigit()
                }
                .font(.caption).foregroundStyle(.orange)
            }
            Divider().overlay(Color.white.opacity(0.1))
            HStack {
                Label("+\(r.purse) 獎金", systemImage: "dollarsign.circle.fill")
                Spacer()
                Label("+\(r.points) 排名積分", systemImage: "chart.bar.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(gold)
        }
        .padding()
        .background(panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private var attributesPanel: some View {
        let b = result.before
        let a = result.after
        let rows: [(String, Int, Int)] = [
            ("力量", b.power, a.power), ("下盤", b.legs, a.legs),
            ("耐力", b.stamina, a.stamina), ("韌性", b.grit, a.grit),
        ]
        return VStack(alignment: .leading, spacing: 8) {
            Text("屬性").font(.subheadline.bold())
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(row.0).font(.subheadline).frame(width: 44, alignment: .leading)
                    ProgressView(value: Double(row.2), total: 99).tint(.white)
                    Text("\(row.2)").font(.rounded(.subheadline)).monospacedDigit().frame(width: 28, alignment: .trailing)
                    Text(row.2 > row.1 ? "+\(row.2 - row.1)" : "")
                        .font(.caption.bold()).foregroundStyle(.green).frame(width: 30, alignment: .leading)
                }
            }
        }
        .padding()
        .background(panel, in: RoundedRectangle(cornerRadius: 14))
    }

    private func banner(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }

    private func panelView<Content: View>(title: String, symbol: String, color: Color,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption.bold()).foregroundStyle(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(panel, in: RoundedRectangle(cornerRadius: 14))
    }
}
