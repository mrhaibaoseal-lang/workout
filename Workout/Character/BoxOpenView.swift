import SwiftUI
import UIKit

struct BoxOpenView: View {
    let sessionCount: Int
    @EnvironmentObject private var store: InventoryStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase {
        case closed, opening, revealed
    }

    @State private var phase: Phase = .closed
    @State private var result: BoxResult?
    @State private var shake = false
    @State private var burst = false
    @State private var equipped = false

    private var shakeAnimation: Animation {
        if phase == .opening {
            return Animation.easeInOut(duration: 0.07).repeatForever(autoreverses: true)
        }
        return Animation.default
    }

    private var remaining: Int { store.boxesAvailable(sessionCount: sessionCount) }

    var body: some View {
        ZStack {
            Color(gearHex: "#0C0F14").ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                switch phase {
                case .closed, .opening:
                    boxView
                case .revealed:
                    if let r = result {
                        revealView(r)
                    }
                }
                Spacer(minLength: 0)
                buttons
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: 箱子

    private var boxView: some View {
        VStack(spacing: 18) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 130))
                .foregroundStyle(
                    LinearGradient(colors: [Color(gearHex: "#F2B630"), Color(gearHex: "#C8841A")],
                                   startPoint: .top, endPoint: .bottom))
                .rotationEffect(.degrees(shake ? 7 : -7))
                .scaleEffect(phase == .opening ? 1.12 : 1)
                .animation(shakeAnimation, value: shake)
                .onTapGesture { openTapped() }
            Text(phase == .closed ? "點一下開箱" : "開箱中…")
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.7))
            Text("還有 \(remaining) 箱")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private func openTapped() {
        guard phase == .closed else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        phase = .opening
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            reveal()
        }
    }

    private func reveal() {
        shake = false
        guard let r = store.openBox(sessionCount: sessionCount) else {
            phase = .closed
            return
        }
        result = r
        equipped = false
        burst = false
        if r.item.rarity.rawValue >= 3 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            phase = .revealed
        }
        withAnimation(.easeOut(duration: 0.9)) {
            burst = true
        }
    }

    // MARK: 結果

    private func revealView(_ r: BoxResult) -> some View {
        let col = r.item.rarity.color
        var preview = store.state.loadout
        preview[r.item.slot] = r.item.id
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [col.opacity(0.85), col.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 170))
                    .frame(width: 340, height: 340)
                    .scaleEffect(burst ? 1 : 0.1)
                    .opacity(burst ? 0.85 : 0)
                CharacterView(move: .squat, loadout: preview, animated: true, showStats: false)
                    .frame(height: 230)
            }
            .frame(height: 260)
            Text(r.item.rarity.name)
                .font(.footnote.weight(.bold))
                .tracking(2)
                .foregroundStyle(col)
            Text(r.item.name)
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(r.item.slot.name)
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.6))
            if r.isNew {
                Text("新裝備！")
                    .font(.headline)
                    .foregroundStyle(col)
            } else {
                Text("已擁有 → +\(r.shards) 碎片")
                    .font(.headline)
                    .foregroundStyle(.cyan)
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: 按鈕

    @ViewBuilder
    private var buttons: some View {
        if phase == .revealed, let r = result {
            VStack(spacing: 10) {
                if r.isNew {
                    Button {
                        store.equip(r.item)
                        equipped = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(equipped ? "已裝備" : "立刻裝備")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(equipped)
                }
                if remaining > 0 {
                    Button {
                        phase = .closed
                        result = nil
                        burst = false
                    } label: {
                        Text("再開一箱（還有 \(remaining) 箱）")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                Button {
                    dismiss()
                } label: {
                    Text("完成").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        } else {
            Button("關閉") { dismiss() }
                .foregroundStyle(Color.white.opacity(0.6))
                .opacity(phase == .opening ? 0 : 1)
        }
    }
}
