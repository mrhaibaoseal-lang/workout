import SwiftUI
import PhotosUI

struct WeekdayItem: Hashable {
    let value: Int
    let label: String
}

/// Monday-first weekday order with labels.
let weekdayOrder: [WeekdayItem] = [
    WeekdayItem(value: 2, label: "週一"), WeekdayItem(value: 3, label: "週二"),
    WeekdayItem(value: 4, label: "週三"), WeekdayItem(value: 5, label: "週四"),
    WeekdayItem(value: 6, label: "週五"), WeekdayItem(value: 7, label: "週六"),
    WeekdayItem(value: 1, label: "週日"),
]

struct ClassScheduleView: View {
    @AppStorage(ClassStore.key) private var raw = ""
    @State private var editing: ClassBlock?
    @State private var photo: PhotosPickerItem?
    @State private var imported: [ClassBlock]?
    @State private var ocrError: String?
    @State private var working = false

    private var blocks: [ClassBlock] { ClassStore.decode(raw) }

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $photo, matching: .images) {
                    Label(working ? "辨識中…" : "從課表截圖匯入", systemImage: "text.viewfinder")
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                }
                .disabled(working)
            } footer: {
                SectionLabel("每學期換課表時用。辨識完會先讓你確認，再取代目前的課表。")
            }
            .listRowBackground(Theme.surface)

            ForEach(weekdayOrder, id: \.value) { day in
                let items = blocks.filter { $0.weekday == day.value }.sorted { $0.startMin < $1.startMin }
                if !items.isEmpty {
                    Section {
                        ForEach(items) { b in
                            Button { editing = b } label: { ClassRow(block: b) }
                                .foregroundStyle(Theme.fg)
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { items[$0].id }
                            save(blocks.filter { !ids.contains($0.id) })
                        }
                    } header: {
                        SectionLabel(day.label)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .themeForm()
        .navigationTitle("課表")
        .toolbar {
            Button {
                editing = ClassBlock(weekday: 2, startMin: 610, endMin: 720, name: "")
            } label: { Image(systemName: "plus") }
                .accessibilityLabel("新增課程")
        }
        .sheet(item: $editing) { b in
            ClassEditView(block: b) { updated in
                var all = blocks.filter { $0.id != updated.id }
                all.append(updated)
                save(all)
            }
        }
        .sheet(isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } })) {
            ImportReviewView(blocks: imported ?? []) { confirmed in
                save(confirmed)
                imported = nil
            }
        }
        .alert("辨識失敗", isPresented: Binding(get: { ocrError != nil }, set: { if !$0 { ocrError = nil } })) {
            Button("好") {}
        } message: { Text(ocrError ?? "") }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await runOCR(item) }
        }
    }

    private func save(_ list: [ClassBlock]) {
        raw = ClassStore.encode(list)
    }

    private func runOCR(_ item: PhotosPickerItem) async {
        working = true
        defer { working = false; photo = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                ocrError = "讀不到這張圖片。"
                return
            }
            let lines = try await TimetableOCR.recognize(image)
            let parsed = TimetableOCR.parse(lines)
            if parsed.isEmpty {
                ocrError = "找不到「週一、週二…」或「08:10」這類時間，請確認截圖是整張週課表。"
            } else {
                imported = parsed
            }
        } catch {
            ocrError = error.localizedDescription
        }
    }
}

struct ClassRow: View {
    let block: ClassBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.name.isEmpty ? "（未命名）" : block.name)
                .font(.headline)
                .foregroundStyle(Theme.fg)
            Text(block.timeText + (block.room.isEmpty ? "" : " · \(block.room)"))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
        .frame(minHeight: 44, alignment: .leading)
    }
}

struct ImportReviewView: View {
    @State var blocks: [ClassBlock]
    let onConfirm: ([ClassBlock]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editing: ClassBlock?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("辨識到 \(blocks.count) 堂課。點一下可以修改，左滑可以刪除。確認沒問題再按「取代課表」。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.fg)
                }
                .listRowBackground(Theme.surface)
                ForEach(weekdayOrder, id: \.value) { day in
                    let items = blocks.filter { $0.weekday == day.value }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { b in
                                Button { editing = b } label: { ClassRow(block: b) }
                                    .foregroundStyle(Theme.fg)
                            }
                            .onDelete { offsets in
                                let ids = offsets.map { items[$0].id }
                                blocks.removeAll { ids.contains($0.id) }
                            }
                        } header: {
                            SectionLabel(day.label)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
            }
            .themeForm()
            .navigationTitle("確認課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("取代課表") { onConfirm(blocks) }.bold()
                }
            }
            .sheet(item: $editing) { b in
                ClassEditView(block: b) { updated in
                    if let i = blocks.firstIndex(where: { $0.id == updated.id }) { blocks[i] = updated }
                }
            }
        }
    }
}

struct ClassEditView: View {
    @State var block: ClassBlock
    let onSave: (ClassBlock) -> Void
    @Environment(\.dismiss) private var dismiss

    private func timeBinding(_ keyPath: WritableKeyPath<ClassBlock, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(block[keyPath: keyPath] * 60)) },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                block[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("課名", text: $block.name)
                    TextField("教室（可留空）", text: $block.room)
                    Picker("星期", selection: $block.weekday) {
                        ForEach(weekdayOrder, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    DatePicker("開始", selection: timeBinding(\.startMin), displayedComponents: .hourAndMinute)
                    DatePicker("結束", selection: timeBinding(\.endMin), displayedComponents: .hourAndMinute)
                }
                .listRowBackground(Theme.surface)
            }
            .themeForm()
            .navigationTitle(block.name.isEmpty ? "新增課程" : block.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        onSave(block)
                        dismiss()
                    }
                    .disabled(block.name.isEmpty || block.endMin <= block.startMin)
                }
            }
        }
    }
}
