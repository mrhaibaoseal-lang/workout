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
    @State private var openAt = Date()
    @State private var revealAt = Date()
    @State private var equipAt: Date?

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
            TimelineView(.animation) { ctx in
                Canvas { g, size in effects(&g, size: size, now: ctx.date) }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
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
        openAt = Date()
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
        revealAt = Date()
        equipAt = nil
        if r.item.rarity.rawValue >= 3 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
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

    // MARK: 特效

    /// 開箱特效：開箱中光點往箱子收、光暈變大；開出來時白光＋衝擊波＋稀有度顏色的光芒，史詩以上灑彩帶。
    private func effects(_ g: inout GraphicsContext, size: CGSize, now: Date) {
        let c = CGPoint(x: size.width / 2, y: size.height * 0.42)
        let big = max(size.width, size.height)
        let gold = Color(gearHex: "#F2B630")
        switch phase {
        case .closed:
            let t = now.timeIntervalSinceReferenceDate
            FX.glow(&g, center: c, radius: 170, color: gold, alpha: 0.18 + 0.08 * sin(t * 2.5))
        case .opening:
            let t = now.timeIntervalSince(openAt)
            FX.glow(&g, center: c, radius: 150 + 120 * FXMath.seg(t, 0, 0.9), color: gold, alpha: 0.25 + 0.5 * FXMath.seg(t, 0, 0.9))
            FX.converge(&g, center: c, t: t, radius: 260, color: gold, count: 36, alpha: FXMath.seg(t, 0, 0.3))
        case .revealed:
            guard let r = result else { return }
            let t = now.timeIntervalSince(revealAt)
            let col = r.item.rarity.color
            let rare = Double(r.item.rarity.rawValue)
            FX.rays(&g, center: c, radius: big, count: 8 + Int(rare) * 3, angle: t * 0.2, color: col,
                    alpha: (0.08 + 0.05 * rare) * FXMath.seg(t, 0, 0.5))
            FX.ring(&g, center: c, progress: FXMath.seg(t, 0, 0.7), maxRadius: big * 0.8, color: col)
            FX.sparkBurst(&g, center: c, tau: t, count: 12 + Int(rare) * 8, speed: 380 + rare * 60, colors: [col, .white, gold])
            if r.item.rarity.rawValue >= 3 {
                FX.confetti(&g, center: c, tau: t - 0.1, count: r.item.rarity == .legendary ? 100 : 60,
                            colors: [col, gold, .white, Theme.accent], height: size.height)
            }
            if r.item.rarity == .legendary {
                FX.embers(&g, size: size, t: t, count: 30, alpha: FXMath.seg(t, 0.3, 1))
            }
            let flash = (0.35 + 0.15 * rare) * (1 - FXMath.seg(t, 0, 0.45))
            if flash > 0 { g.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(flash))) }
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
                CharacterStage(move: .squat, loadout: preview, animated: true, showStats: false)
                    .frame(height: 230)
                    .overlay {
                        if let at = equipAt {
                            EquipFlash(start: at, color: col).frame(width: 260, height: 260).id(at)
                        }
                    }
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
                        equipAt = Date()
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
