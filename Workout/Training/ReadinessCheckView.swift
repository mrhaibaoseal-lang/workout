import SwiftUI

/// 開始訓練前的 3 題（睡眠、痠痛、精神），一定要回答才會排今天的課表。
struct ReadinessCheckView: View {
    let onDone: (Readiness) -> Void
    let onQuit: () -> Void

    @State private var answers: [Int?] = [nil, nil, nil]

    private var result: Readiness? {
        guard let s = answers[0], let so = answers[1], let e = answers[2] else { return nil }
        return Readiness(sleep: s, soreness: so, energy: e)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onQuit) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Theme.fg)
                        .frame(width: 44, height: 44)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel("不練了")
                Spacer()
                Text("開始前先看狀態").font(.headline.weight(.heavy)).foregroundStyle(Theme.fg)
                Spacer()
                InfoTip(item: .readiness).frame(width: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(Readiness.questions) { q in
                        question(q)
                    }
                    verdict
                }
                .padding(16)
            }

            Button {
                if let r = result {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDone(r)
                }
            } label: {
                Text(result == nil ? "三題都選好才能開始" : "開始訓練")
            }
            .buttonStyle(HotButtonStyle(height: 56))
            .disabled(result == nil)
            .opacity(result == nil ? 0.5 : 1)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func question(_ q: Readiness.Question) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(q.title, systemImage: q.icon)
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Theme.fg)
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { v in
                    let on = answers[q.id] == v
                    Button {
                        answers[q.id] = v
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(v)").font(Theme.number(20))
                            Text(q.labels[v - 1]).font(.system(size: 11, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(on ? color(v) : Theme.sunken, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(v) 分，\(q.labels[v - 1])")
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func color(_ v: Int) -> Color {
        switch v {
        case 1, 2: Theme.hot
        case 3: Theme.accent
        default: Theme.green
        }
    }

    /// 選完之後告訴你今天會怎麼調整
    @ViewBuilder
    private var verdict: some View {
        if let r = result {
            Label(r.banner ?? "狀態普通（\(r.total)/15）：照原本的課表練。", systemImage: "list.bullet.clipboard.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(r.level == .high ? Theme.green : (r.level == .normal ? Theme.fg : Theme.accentSoft))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
