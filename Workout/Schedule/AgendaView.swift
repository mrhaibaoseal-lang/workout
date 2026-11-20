import SwiftUI
import SwiftData

/// 行程：月曆＋當天的上課、打工、活動和排好的訓練。
struct AgendaView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(EventStore.key) private var eventsRaw = ""
    @AppStorage(ClassStore.key) private var classesRaw = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var editing: LifeEvent?
    @State private var refresh = 0

    private struct Item: Identifiable {
        let id = UUID()
        let start: Date
        let icon: String
        let color: Color
        let title: String
        let time: String
        var event: LifeEvent?
    }

    private var items: [Item] {
        _ = (refresh, eventsRaw, classesRaw)
        let cal = Calendar.current
        let day = cal.startOfDay(for: selected)
        let next = cal.date(byAdding: .day, value: 1, to: day)!
        func at(_ m: Int) -> Date { day.addingTimeInterval(TimeInterval(m * 60)) }
        var list: [Item] = []

        let weekday = cal.component(.weekday, from: day)
        for c in ClassStore.decode(classesRaw) where c.weekday == weekday {
            list.append(Item(start: at(c.startMin), icon: "graduationcap.fill", color: .blue,
                             title: c.name, time: c.timeText + (c.room.isEmpty ? "" : " · \(c.room)")))
        }
        for s in ShiftReader.load().shifts where s.start >= day && s.start < next {
            list.append(Item(start: s.start, icon: "briefcase.fill", color: .orange,
                             title: "打工：\(s.name)", time: "\(TimeFmt.hm(s.start))–\(TimeFmt.hm(s.end))"))
        }
        for e in EventStore.all(from: day, to: next) {
            list.append(Item(start: e.allDay ? day : e.start, icon: e.category.icon,
                             color: e.fromPhone ? .gray : .pink,
                             title: e.displayTitle + (e.fromPhone ? "（行事曆）" : ""),
                             time: e.timeText, event: e.fromPhone ? nil : e))
        }
        let plans = Planner.makePlan(sessions: sessions, horizon: 14)
        if let p = plans.first(where: { $0.day == day }) {
            if p.done {
                list.append(Item(start: next, icon: "checkmark.seal.fill", color: .green, title: "已完成訓練", time: ""))
            } else if let length = p.length, let start = p.start {
                list.append(Item(start: start, icon: "figure.strengthtraining.traditional", color: .green,
                                 title: "建議訓練：\(length.title)", time: "\(TimeFmt.hm(start)) 開始"))
            } else {
                list.append(Item(start: next, icon: "moon.zzz.fill", color: .secondary,
                                 title: "休息", time: p.reason))
            }
        }
        return list.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("日期", selection: $selected, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                Section {
                    if items.isEmpty {
                        Text("這天沒有安排").foregroundStyle(.secondary)
                    }
                    ForEach(items) { item in
                        Button {
                            if let e = item.event { editing = e }
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.icon)
                                    .foregroundStyle(item.color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.body)
                                    if !item.time.isEmpty {
                                        Text(item.time).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .swipeActions {
                            if let e = item.event {
                                Button("刪除", role: .destructive) { delete(e) }
                            }
                        }
                    }
                } header: {
                    Text(selected.formatted(.dateTime.month().day().weekday(.wide)))
                } footer: {
                    Text("新增活動後，訓練會自動避開並重新排。點活動可以修改，左滑可以刪除。")
                }
            }
            .navigationTitle("行程")
            .toolbar {
                Button {
                    editing = newEvent()
                } label: { Image(systemName: "plus") }
            }
            .sheet(item: $editing) { e in
                EventEditView(event: e, isNew: !EventStore.decode(eventsRaw).contains { $0.id == e.id },
                              onSave: save, onDelete: delete)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh += 1 }
            }
        }
    }

    private func newEvent() -> LifeEvent {
        let cal = Calendar.current
        let base = cal.startOfDay(for: selected)
        let start = base.addingTimeInterval(19 * 3600)
        return LifeEvent(title: "", category: .meal, start: start, end: start.addingTimeInterval(2 * 3600))
    }

    private func save(_ e: LifeEvent) {
        var list = EventStore.decode(eventsRaw).filter { $0.id != e.id }
        list.append(e)
        eventsRaw = EventStore.encode(list)
    }

    private func delete(_ e: LifeEvent) {
        eventsRaw = EventStore.encode(EventStore.decode(eventsRaw).filter { $0.id != e.id })
    }
}

struct EventEditView: View {
    @State var event: LifeEvent
    let isNew: Bool
    let onSave: (LifeEvent) -> Void
    let onDelete: (LifeEvent) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(EventCategory.allCases) { c in
                            Button {
                                event.category = c
                            } label: {
                                Label(c.title, systemImage: c.icon)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(event.category == c ? Color.accentColor : Color.secondary.opacity(0.15),
                                                in: RoundedRectangle(cornerRadius: 10))
                                    .foregroundStyle(event.category == c ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("類型")
                } footer: {
                    Text(event.category.effect)
                }

                Section {
                    TextField("名稱（可留空，例如：和阿明吃火鍋）", text: $event.title)
                    Toggle("整天", isOn: $event.allDay)
                    DatePicker("開始", selection: $event.start,
                               displayedComponents: event.allDay ? .date : [.date, .hourAndMinute])
                    if !event.allDay {
                        DatePicker("結束", selection: $event.end, in: event.start...,
                                   displayedComponents: [.date, .hourAndMinute])
                    }
                }

                if !isNew {
                    Section {
                        Button("刪除這個活動", role: .destructive) {
                            onDelete(event)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "新增活動" : "編輯活動")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: event.start) { old, new in
                // Keep the same duration when the start moves.
                let duration = max(1800, event.end.timeIntervalSince(old))
                event.end = new.addingTimeInterval(duration)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        var e = event
                        if e.allDay {
                            let cal = Calendar.current
                            e.start = cal.startOfDay(for: e.start)
                            e.end = cal.date(byAdding: .day, value: 1, to: e.start)!
                        }
                        onSave(e)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

/// 讓使用者校對練壯讀到的班表。
struct ShiftListView: View {
    @State private var info = ShiftReader.load()
    @State private var showPast = false

    var body: some View {
        List {
            if !info.found {
                Section {
                    Text("讀不到打工薪水帳的班表。請在 Feather 更新「打工薪水帳」到 3.0.7 以上，打開一次後再回來。")
                }
            } else {
                Section {
                    if let u = info.updatedAt {
                        LabeledContent("最後同步", value: u.formatted(date: .abbreviated, time: .shortened))
                    }
                    Toggle("顯示過去的班", isOn: $showPast)
                } footer: {
                    Text("這裡是練壯讀到的資料，跟打工薪水帳對一下。不對的話，在打工薪水帳改好、打開一次，再回來看。")
                }
                let cutoff = Calendar.current.startOfDay(for: .now)
                let shown = info.shifts.filter { showPast || $0.end > cutoff }
                if shown.isEmpty {
                    Text("沒有班").foregroundStyle(.secondary)
                }
                ForEach(shown, id: \.start) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.start.formatted(.dateTime.month().day()) + "（\(TimeFmt.weekday(s.start))）")
                                .font(.headline)
                            Text(s.name).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(TimeFmt.hm(s.start))–\(TimeFmt.hm(s.end))").monospacedDigit()
                            Text(String(format: "%.1f 小時", s.end.timeIntervalSince(s.start) / 3600))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("班表檢查")
        .refreshable { info = ShiftReader.load() }
        .onAppear { info = ShiftReader.load() }
    }
}
