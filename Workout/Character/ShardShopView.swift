import SwiftUI
import UIKit

struct ShardShopView: View {
    @EnvironmentObject private var store: InventoryStore
    @State private var pending: GearItem?
    @State private var showConfirm = false

    private func unowned(_ r: Rarity) -> [GearItem] {
        GearCatalog.items.filter { $0.rarity == r && !$0.isGold && !store.isOwned($0) }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "diamond.fill").foregroundStyle(.cyan)
                    Text("\(store.state.shards) 碎片").monospacedDigit()
                }
                Text("兌換所需：普通 20 ・ 稀有 50 ・ 史詩 120 ・ 傳說 300。黃金系列不能兌換。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Rarity.allCases.reversed(), id: \.rawValue) { r in
                let list = unowned(r)
                if !list.isEmpty {
                    Section {
                        ForEach(list) { item in
                            row(item)
                        }
                    } header: {
                        Text("\(r.name) ・ \(r.exchangeCost) 碎片")
                            .foregroundStyle(r.color)
                    }
                }
            }
        }
        .navigationTitle("碎片兌換")
        .navigationBarTitleDisplayMode(.inline)
        .alert("確認兌換", isPresented: $showConfirm, presenting: pending) { item in
            Button("兌換（\(item.rarity.exchangeCost) 碎片）") {
                if store.exchange(item) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("用 \(item.rarity.exchangeCost) 碎片兌換「\(item.name)」？")
        }
    }

    private func row(_ item: GearItem) -> some View {
        let can = store.canExchange(item)
        let seriesName = GearCatalog.seriesById(item.series)?.name ?? ""
        return HStack {
            Circle().fill(item.rarity.color).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                Text("\(seriesName) ・ \(item.slot.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("\(item.rarity.exchangeCost)") {
                pending = item
                showConfirm = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(!can)
        }
    }
}
