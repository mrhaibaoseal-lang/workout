import SwiftUI
import UIKit
import SwiftData

struct CharacterScreen: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @EnvironmentObject private var store: InventoryStore
    @State private var move: CharacterMove = .squat
    @State private var showBox = false

    private var stats: MilestoneStats { MilestoneStats.compute(sessions: sessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stageCard
                    boxSection
                    equipmentSection
                    milestoneSection
                    shardSection
                }
                .padding()
            }
            .navigationTitle("角色")
            .sheet(isPresented: $showBox) {
                BoxOpenView(sessionCount: sessions.count)
                    .environmentObject(store)
            }
        }
    }

    // MARK: 舞台

    private var stageCard: some View {
        let loadout = store.state.loadout
        return VStack(spacing: 10) {
            CharacterView(move: move, loadout: loadout)
                .frame(height: 300)
            if let b = loadout.setBonus {
                Text("\(b.series.name)套裝 \(b.count)/8 ・ 光環換成系列色、戰力 ×1.2")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(gearHex: b.series.glow))
            } else {
                Text("同系列裝備穿滿 4 件，光環換成系列色、戰力 ×1.2")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            Picker("動作", selection: $move) {
                ForEach(CharacterMove.basic) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .environment(\.colorScheme, .dark)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RadialGradient(
                colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                center: .top, startRadius: 10, endRadius: 420),
            in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: 補給箱

    @ViewBuilder
    private var boxSection: some View {
        let n = store.boxesAvailable(sessionCount: sessions.count)
        if n > 0 {
            Button {
                showBox = true
            } label: {
                Label("開補給箱（\(n)）", systemImage: "shippingbox.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Text("每完成一次訓練，就會獲得一個補給箱。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 裝備

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("裝備").font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(GearSlot.allCases) { slot in
                    NavigationLink {
                        GearPickerView(slot: slot)
                    } label: {
                        equipRow(slot)
                    }
                    .buttonStyle(.plain)
                    if slot != GearSlot.allCases.last {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func equipRow(_ slot: GearSlot) -> some View {
        let it = store.state.loadout.item(slot)
        return HStack(spacing: 10) {
            Text(slot.name)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            if let it = it {
                Circle().fill(it.rarity.color).frame(width: 9, height: 9)
                Text(it.name)
            } else {
                Text(slot.emptyName).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: 實力裝備

    private var milestoneSection: some View {
        let s = stats
        return VStack(alignment: .leading, spacing: 8) {
            Text("實力裝備").font(.title3.bold())
            Text("黃金系列只能靠實力取得，補給箱不會掉。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Milestone.all) { m in
                    milestoneRow(m, s)
                    if m.id != Milestone.all.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func milestoneRow(_ m: Milestone, _ s: MilestoneStats) -> some View {
        let claimed = store.isClaimed(m)
        let met = m.isMet(s)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(m.title).font(.subheadline.weight(.semibold))
                Text("\(m.condition) ・ \(m.progressText(s))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: m.progress(s))
                    .tint(Color(gearHex: "#E0A21B"))
            }
            if claimed {
                Label("已領取", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            } else if met {
                Button("領取") {
                    store.claim(m, stats: s)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(gearHex: "#E0A21B"))
            } else {
                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }

    // MARK: 碎片

    private var shardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("碎片").font(.title3.bold())
            NavigationLink {
                ShardShopView()
            } label: {
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                    Text("\(store.state.shards) 碎片").monospacedDigit()
                    Spacer()
                    Text("兌換").foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("抽到已擁有的裝備會變成碎片，可兌換還沒有的裝備。")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                    RoundedRectangle(cornerRadius: 12).fill(Color(gearHex: "#141920"))
                    CharacterView(move: .squat, loadout: preview(nil), animated: false, showStats: false)
                        .padding(4)
                }
                .frame(height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
                Text(slot.emptyName).font(.caption)
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
                    RoundedRectangle(cornerRadius: 12).fill(Color(gearHex: "#141920"))
                    CharacterView(move: .squat, loadout: preview(item), animated: false, showStats: false)
                        .padding(4)
                        .opacity(owned ? 1 : 0.35)
                    if !owned {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }
                .frame(height: 130)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(equipped ? item.rarity.color : Color.clear, lineWidth: 2))
                HStack(spacing: 4) {
                    Circle().fill(item.rarity.color).frame(width: 7, height: 7)
                    Text(item.name).font(.caption).lineLimit(1)
                }
                if !owned {
                    Text(item.isGold ? "實力裝備" : "未擁有")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(owned ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!owned)
    }
}
