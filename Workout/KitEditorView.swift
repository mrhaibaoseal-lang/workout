import SwiftUI

/// 設定 → 我的啞鈴與槓片。改完立刻存，課表的加重建議只會跳到裝得出來的重量。
struct KitEditorView: View {
    @State private var kits: [WeightKit] = WeightKits.load()
    @State private var confirmReset = false

    var body: some View {
        Form {
            ForEach($kits) { $kit in
                Section {
                    TextField("名稱", text: $kit.name)
                    weightRow("一支把手（含鎖頭）", value: $kit.handle)
                    ForEach($kit.plates) { $p in
                        HStack {
                            weightField(value: $p.kg).frame(width: 64)
                            Text("kg 槓片").foregroundStyle(Theme.muted)
                            Spacer()
                            Stepper("\(p.count) 片", value: $p.count, in: 0...40)
                                .fixedSize()
                        }
                    }
                    .onDelete { kit.plates.remove(atOffsets: $0) }
                    Button("新增一種槓片", systemImage: "plus.circle") {
                        kit.plates.append(PlateStack(kg: 1.25, count: 2))
                    }
                    Toggle("兩支把手可以接成槓鈴", isOn: $kit.makesBarbell)
                    if kit.makesBarbell {
                        weightRow("連接桿", value: $kit.connector)
                    }
                    Toggle("槓片可以掛在下拉架", isOn: $kit.onCable)
                    Stepper("拆裝鎖頭：一支 \(Int(kit.lockSeconds)) 秒", value: $kit.lockSeconds, in: 0...60, step: 1)
                    Stepper("拿下或裝上一片：\(Int(kit.plateSeconds)) 秒", value: $kit.plateSeconds, in: 1...20, step: 1)
                    if kit.makesBarbell {
                        Stepper("組成槓鈴：\(Int(kit.assembleSeconds)) 秒", value: $kit.assembleSeconds, in: 10...300, step: 10)
                    }
                    preview(kit)
                } header: {
                    HStack {
                        SectionLabel(kit.name.isEmpty ? "啞鈴組" : kit.name)
                        Spacer()
                        if kits.count > 1 {
                            Button("刪除", role: .destructive) { kits.removeAll { $0.id == kit.id } }
                                .font(.caption)
                        }
                    }
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Button("新增一組啞鈴", systemImage: "plus") {
                    kits.append(WeightKit(name: "新的啞鈴", handle: 2, plates: [PlateStack(kg: 2.5, count: 4)]))
                }
                Button("恢復預設（Tixteel＋舊啞鈴）", role: .destructive) { confirmReset = true }
            } footer: {
                SectionLabel("排在最上面的那組優先用（主要啞鈴放第一個）。兩手各拿一支的動作，槓片要平分給兩支、左右對稱；單手動作（單臂划船、高腳杯深蹲、臀推）可以把整組槓片裝在同一支。舊啞鈴的把手和連接桿重量是估的，用體重計秤一下會更準。換重量的秒數用來拉長休息：要換片的那次休息，會自動延長到「換重量＋至少 30 秒」。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("我的啞鈴與槓片")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: kits) { _, new in WeightKits.save(new) }
        .confirmationDialog("恢復成預設的兩組啞鈴？", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("恢復預設", role: .destructive) { kits = WeightKits.defaults }
        }
    }

    private func weightRow(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            weightField(value: value).frame(width: 64)
            Text("kg").foregroundStyle(Theme.muted)
        }
    }

    private func weightField(value: Binding<Double>) -> some View {
        TextField("0", value: value, format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
    }

    @ViewBuilder
    private func preview(_ kit: WeightKit) -> some View {
        let rows: [(String, WeightKits.Use)] = [("兩手各一支", .pair), ("只拿一支", .single), ("接成槓鈴", .barbell), ("下拉架", .cable)]
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows, id: \.0) { title, use in
                let ws = Array(Set(WeightKits.loadings(kit, use).map(\.weight))).sorted()
                if !ws.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.caption.weight(.bold)).foregroundStyle(Theme.fg)
                        Text(ws.map(Progression.format).joined(separator: "、") + " kg")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
