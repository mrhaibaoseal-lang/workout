import SwiftUI
import UIKit
import SwiftData

/// 角色頁：舞台 → 補給箱 → 裝備格 → 黃金里程碑圓環。盡量用圖形，文字只留短標籤。
struct CharacterScreen: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @EnvironmentObject private var store: InventoryStore
    @State private var move: CharacterMove = .squat
    @State private var showBox = false
    @State private var focused: String?

    private var stats: MilestoneStats { MilestoneStats.compute(sessions: sessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    stage
                    boxCard
                    gearGrid
                    milestoneCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themeScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBox) {
                BoxOpenView(sessionCount: sessions.count)
                    .environmentObject(store)
            }
        }
    }

    // MARK: 標題

    private var header: some View {
        HStack {
            Text("角色")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.fg)
            Spacer()
            NavigationLink {
                ShardShopView().toolbar(.visible, for: .navigationBar)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                    Text("\(store.state.shards)").font(Theme.number(17))
                        .foregroundStyle(Theme.fg)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Theme.surface, in: Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("碎片 \(store.state.shards)，兌換裝備")
        }
        .padding(.top, 12)
    }

    // MARK: 舞台

    private var stage: some View {
        let loadout = store.state.loadout
        let glow = loadout.setBonus.map { Color(gearHex: $0.series.glow) } ?? Theme.accent
        return VStack(spacing: 8) {
            CharacterView(move: move, loadout: loadout)
                .frame(height: 320)
            HStack(spacing: 10) {
                ForEach(CharacterMove.basic) { m in
                    let on = m == move
                    Button {
                        withAnimation(.snappy) { move = m }
                    } label: {
                        Text(m.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(on ? Theme.bg : Theme.fg)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(on ? glow : Theme.raised.opacity(0.7), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            setMeter(loadout)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(
                colors: [glow.opacity(0.28), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                center: .top, startRadius: 10, endRadius: 420),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }

    /// 8 格表示同系列件數；滿 4 格亮起＝套裝效果。
    private func setMeter(_ loadout: Loadout) -> some View {
        var counts: [String: Int] = [:]
        for slot in GearSlot.allCases {
            if let it = loadout.item(slot), it.series != "basic" { counts[it.series, default: 0] += 1 }
        }
        let best = counts.max { $0.value < $1.value }
        let series = best.flatMap { GearCatalog.seriesById($0.key) }
        let n = best?.value ?? 0
        let color = series.map { Color(gearHex: $0.glow) } ?? Theme.muted
        return HStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(i < n ? color : Theme.line)
                    .frame(height: 5)
                    .overlay(alignment: .trailing) {
                        if i == 3 { Rectangle().fill(Theme.fg.opacity(0.5)).frame(width: 1.5, height: 11) }
                    }
            }
            Image(systemName: n >= 4 ? "bolt.fill" : "bolt")
                .font(.caption.weight(.bold))
                .foregroundStyle(n >= 4 ? color : Theme.muted)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(n >= 4 ? "\(series?.name ?? "")套裝 \(n) 件，戰力加成" : "同系列穿滿 4 件有套裝加成，目前 \(n) 件")
    }

    // MARK: 補給箱

    private var boxCard: some View {
        let n = store.boxesAvailable(sessionCount: sessions.count)
        return Button {
            if n > 0 { showBox = true }
        } label: {
            HStack(spacing: 16) {
                SupplyBox(active: n > 0)
                    .frame(width: 72, height: 64)
                    .overlay(alignment: .topTrailing) {
                        if n > 0 {
                            Text("\(n)")
                                .font(Theme.number(14))
                                .foregroundStyle(Theme.onHot)
                                .frame(minWidth: 24, minHeight: 24)
                                .background(Theme.hot, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(n > 0 ? "開箱" : "補給箱")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(n > 0 ? Theme.gold : Theme.muted)
                    HStack(spacing: 4) {
                        Image(systemName: "figure.strengthtraining.traditional")
                        Image(systemName: "arrow.right")
                        Image(systemName: "shippingbox.fill")
                        Text("+1")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
                }
                Spacer()
                if n > 0 {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(n > 0 ? Theme.goldBg : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(n > 0 ? Theme.gold.opacity(0.6) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(n == 0)
        .accessibilityLabel(n > 0 ? "開補給箱，還有 \(n) 箱" : "沒有補給箱，每練完一次得一箱")
    }

    // MARK: 裝備

    private var gearGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(GearSlot.allCases) { slot in
                NavigationLink {
                    GearPickerView(slot: slot).toolbar(.visible, for: .navigationBar)
                } label: {
                    gearTile(slot)
                }
                .buttonStyle(.plain)
            }
        }
        .themeCard(padding: 12)
    }

    private func gearTile(_ slot: GearSlot) -> some View {
        let it = store.state.loadout.item(slot)
        let color = it?.rarity.color ?? Theme.muted
        return VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(it == nil ? AnyShapeStyle(Theme.sunken)
                          : AnyShapeStyle(LinearGradient(colors: [color.opacity(0.45), color.opacity(0.12)],
                                                         startPoint: .top, endPoint: .bottom)))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(it == nil ? Theme.line : color,
                                  style: StrokeStyle(lineWidth: it == nil ? 1 : 1.5, dash: it == nil ? [4, 3] : []))
                Image(systemName: slot.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(it == nil ? Theme.muted : Theme.fg)
                if it?.isGold == true {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(5)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            Text(slot.short)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slot.name)：\(it?.name ?? slot.emptyName)")
    }

    // MARK: 黃金里程碑

    private var milestoneCard: some View {
        let s = stats
        let current = Milestone.all.first { $0.id == focused }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.circle.fill").foregroundStyle(Theme.gold)
                Text("黃金裝備").font(.headline.weight(.heavy)).foregroundStyle(Theme.fg)
                Spacer()
                Text("\(Milestone.all.filter { store.isClaimed($0) }.count)/\(Milestone.all.count)")
                    .font(Theme.number(15, .bold))
                    .foregroundStyle(Theme.muted)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 12) {
                ForEach(Milestone.all) { m in
                    milestoneRing(m, s)
                }
            }
            if let m = current {
                milestoneDetail(m, s)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .themeCard()
    }

    private func milestoneRing(_ m: Milestone, _ s: MilestoneStats) -> some View {
        let claimed = store.isClaimed(m)
        let met = m.isMet(s)
        let on = focused == m.id
        return Button {
            withAnimation(.snappy) { focused = on ? nil : m.id }
        } label: {
            ZStack {
                Ring(progress: claimed ? 1 : m.progress(s),
                     color: claimed ? Theme.gold : met ? Theme.hot : Theme.accentDim, lineWidth: 5)
                Circle()
                    .fill(claimed ? Theme.goldBg : Theme.sunken)
                    .padding(8)
                Image(systemName: m.item?.slot.icon ?? "star.fill")
                    .font(.headline)
                    .foregroundStyle(claimed ? Theme.gold : met ? Theme.hotText : Theme.muted)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(alignment: .topTrailing) {
                if claimed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.bg, Theme.green)
                        .font(.subheadline)
                } else if met {
                    Circle().fill(Theme.hot).frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Theme.surface, lineWidth: 2))
                }
            }
            .scaleEffect(on ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(m.title)，\(m.condition)，\(claimed ? "已領取" : met ? "可以領取" : m.progressText(s))")
    }

    private func milestoneDetail(_ m: Milestone, _ s: MilestoneStats) -> some View {
        let claimed = store.isClaimed(m)
        let met = m.isMet(s)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(m.item?.name ?? m.title).font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                HStack(spacing: 6) {
                    Image(systemName: m.kind.icon)
                    Text(claimed ? "已取得" : m.progressText(s))
                        .font(Theme.number(13, .bold))
                }
                .font(.caption)
                .foregroundStyle(Theme.muted)
            }
            Spacer()
            if !claimed && met {
                Button("領取") {
                    _ = store.claim(m, stats: s)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                .buttonStyle(HotButtonStyle(height: 40))
                .frame(width: 96)
            }
        }
        .padding(12)
        .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 畫出來的補給箱：箱身＋箱蓋＋十字綁帶，有箱可開時發光、輕輕上下浮動。
struct SupplyBox: View {
    let active: Bool
    @State private var float = false

    var body: some View {
        let body1 = active ? Theme.gold : Theme.raised
        let body2 = active ? Color(gearHex: "#B9862A") : Theme.sunken
        let strap = active ? Theme.hot : Theme.line
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                if active {
                    Ellipse().fill(Theme.gold.opacity(0.35)).blur(radius: 12)
                        .frame(width: w * 0.9, height: h * 0.5)
                        .offset(y: h * 0.3)
                }
                // 箱身
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [body1, body2], startPoint: .top, endPoint: .bottom))
                    .frame(width: w * 0.86, height: h * 0.62)
                    .offset(y: h * 0.17)
                // 箱蓋
                RoundedRectangle(cornerRadius: 5)
                    .fill(body1)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(body2, lineWidth: 1.5))
                    .frame(width: w * 0.96, height: h * 0.24)
                    .offset(y: -h * 0.2)
                // 綁帶
                Rectangle().fill(strap).frame(width: w * 0.14, height: h * 0.86).offset(y: h * 0.05)
                Rectangle().fill(strap.opacity(0.8)).frame(width: w * 0.86, height: h * 0.1).offset(y: h * 0.2)
                if active {
                    Image(systemName: "sparkle")
                        .font(.system(size: w * 0.18, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: w * 0.36, y: -h * 0.4)
                }
            }
            .frame(width: w, height: h)
        }
        .offset(y: active && float ? -3 : 0)
        .onAppear {
            guard active else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { float = true }
        }
        .accessibilityHidden(true)
    }
}

extension GearSlot {
    var icon: String {
        switch self {
        case .head: return "crown.fill"
        case .top: return "tshirt.fill"
        case .bottom: return "figure.walk"
        case .feet: return "shoeprints.fill"
        case .hands: return "hand.raised.fill"
        case .back: return "shield.fill"
        case .bell: return "dumbbell.fill"
        case .fx: return "sparkles"
        }
    }

    /// 格子下方的兩字標籤。
    var short: String {
        switch self {
        case .bell: return "啞鈴"
        default: return name
        }
    }
}

extension Milestone.Kind {
    var icon: String {
        switch self {
        case .sessions: return "figure.strengthtraining.traditional"
        case .streak: return "flame.fill"
        case .records: return "trophy.fill"
        }
    }
}

// MARK: - 選裝備

struct GearPickerView: View {
    let slot: GearSlot
    @EnvironmentObject private var store: InventoryStore

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    private var items: [GearItem] { GearCatalog.items(for: slot) }

    private func preview(_ item: GearItem?) -> Loadout {
        var l = store.state.loadout
        if let it = item {
            l[slot] = it.id
        } else {
            l.slots.removeValue(forKey: slot.rawValue)
        }
        return l
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                noneCell
                ForEach(items) { item in
                    itemCell(item)
                }
            }
            .padding()
        }
        .themeScreen()
        .navigationTitle(slot.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noneCell: some View {
        let selected = store.state.loadout.item(slot) == nil
        return Button {
            store.unequip(slot)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.sunken)
                    CharacterView(move: .squat, loadout: preview(nil), animated: false, showStats: false)
                        .padding(4)
                }
                .frame(height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1))
                Text(slot.emptyName).font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private func itemCell(_ item: GearItem) -> some View {
        let owned = store.isOwned(item)
        let equipped = store.isEquipped(item)
        return Button {
            if owned { store.equip(item) }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Theme.sunken)
                    CharacterView(move: .squat, loadout: preview(item), animated: false, showStats: false)
                        .padding(4)
                        .opacity(owned ? 1 : 0.35)
                    if !owned {
                        Image(systemName: item.isGold ? "star.circle.fill" : "lock.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                .frame(height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(equipped ? item.rarity.color : Theme.line, lineWidth: equipped ? 2 : 1))
                HStack(spacing: 4) {
                    Circle().fill(item.rarity.color).frame(width: 7, height: 7)
                    Text(item.name).font(.caption).lineLimit(1).foregroundStyle(Theme.fg)
                }
            }
            .opacity(owned ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!owned)
    }
}
