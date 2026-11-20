import SwiftUI
import SwiftData

/// 行程：日期膠囊＋當天的上課、打工、活動和排好的訓練時間軸。
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
        let clock: String
        let icon: String
        let color: Color
        let kind: String
        let title: String
        let detail: String
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
            list.append(Item(start: at(c.startMin), clock: TimeFmt.hm(c.startMin), icon: "graduationcap.fill",
                             color: Theme.accent, kind: "上課", title: c.name,
                             detail: c.timeText + (c.room.isEmpty ? "" : " · \(c.room)")))
        }
        for s in ShiftReader.load().shifts where s.start >= day && s.start < next {
            list.append(Item(start: s.start, clock: TimeFmt.hm(s.start), icon: "briefcase.fill",
                             color: Theme.gold, kind: "打工", title: s.name,
                             detail: "\(TimeFmt.hm(s.start))–\(TimeFmt.hm(s.end))"))
        }
        for e in EventStore.all(from: day, to: next) {
            list.append(Item(start: e.allDay ? day : e.start,
                             clock: e.allDay ? "整天" : TimeFmt.hm(e.start),
                             icon: e.category.icon,
                             color: e.fromPhone ? Theme.muted : Theme.accentSoft,
                             kind: e.fromPhone ? "行事曆" : "活動",
                             title: e.displayTitle,
                             detail: e.allDay ? "" : e.timeText,
                             event: e.fromPhone ? nil : e))
        }
        let plans = Planner.makePlan(sessions: sessions, horizon: 14)
        if let p = plans.first(where: { $0.day == day }) {
            if p.done {
                list.append(Item(start: next, clock: "全天", icon: "checkmark.seal.fill", color: Theme.green,
                                 kind: "訓練", title: "已完成訓練", detail: ""))
            } else if let length = p.length, let start = p.start {
                list.append(Item(start: start, clock: TimeFmt.hm(start), icon: "figure.strengthtraining.traditional",
                                 color: Theme.hot, kind: "訓練", title: "建議訓練：\(length.title)", detail: "\(TimeFmt.hm(start)) 開始"))
            } else {
                list.append(Item(start: next, clock: "全天", icon: "moon.zzz.fill", color: Theme.muted,
                                 kind: "休息", title: "休息", detail: p.reason))
            }
        }
        return list.sorted { $0.start < $1.start }
    }

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: today)! }
    }

    var body: some View {
        let list = items
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    dayStrip
                    dayCard(list)
                    linksCard
                    Text("新增活動後，訓練會自動避開並重新排。點活動可以修改，長按活動可以刪除。")
                        .font(.footnote)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themeScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editing) { e in
                EventEditView(event: e, isNew: !EventStore.decode(eventsRaw).contains { $0.id == e.id },
                              onSave: save, onDelete: delete)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh += 1 }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("行程")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.fg)
            Spacer()
            Button {
                editing = newEvent()
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.onHot)
                    .frame(width: 44, height: 44)
                    .background(Theme.hot, in: Circle())
            }
            .accessibilityLabel("新增活動")
        }
        .padding(.top, 12)
    }

    private var dayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { d in
                    let on = Calendar.current.isDate(d, inSameDayAs: selected)
                    let isToday = Calendar.current.isDateInToday(d)
                    Button {
                        selected = d
                    } label: {
                        VStack(spacing: 4) {
                            Text(isToday ? "今天" : d.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.caption.weight(.bold))
                            Text(d.formatted(.dateTime.day()))
                                .font(Theme.number(20))
                        }
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                        .frame(width: 54, height: 66)
                        .background(on ? Theme.accent : Theme.surface,
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(on ? Theme.accent : Theme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(d.formatted(.dateTime.month().day().weekday(.wide)))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func dayCard(_ list: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selected.formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.fg)
                Spacer()
                DatePicker("選其他日期", selection: $selected, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(minHeight: 44)
            }
            if list.isEmpty {
                Text("這天沒有安排")
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Theme.divider) }
                        row(item).padding(.vertical, 10)
                    }
                }
            }
        }
        .themeCard()
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        if let e = item.event {
            Button {
                editing = e
            } label: {
                rowContent(item, tappable: true)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("刪除", role: .destructive) { delete(e) }
            }
        } else {
            rowContent(item, tappable: false)
        }
    }

    private func rowContent(_ item: Item, tappable: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(item.clock)
                .font(Theme.number(15))
                .foregroundStyle(Theme.fg)
                .frame(width: 48, alignment: .leading)
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon)
                            .font(.caption)
                            .foregroundStyle(item.color)
                        Tag(text: item.kind, fg: item.color, bg: item.color.opacity(0.16))
                    }
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.fg)
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Capsule().fill(item.color).frame(width: 4)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ClassScheduleView()
            } label: {
                linkRow(icon: "graduationcap", title: "課表")
            }
            .buttonStyle(.plain)
            Divider().overlay(Theme.divider)
            NavigationLink {
                ShiftListView()
            } label: {
                linkRow(icon: "briefcase", title: "班表檢查")
            }
            .buttonStyle(.plain)
        }
        .themeCard(padding: 4)
    }

    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.fg)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
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
                                    .frame(minHeight: 44)
                                    .background(event.category == c ? Theme.accent.opacity(0.18) : Theme.raised,
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(event.category == c ? Theme.accent : Color.clear, lineWidth: 1.5))
                                    .foregroundStyle(event.category == c ? Theme.accent : Theme.fg)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    SectionLabel("類型")
                } footer: {
                    SectionLabel(event.category.effect)
                }
                .listRowBackground(Theme.surface)

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
                .listRowBackground(Theme.surface)

                if !isNew {
                    Section {
                        Button("刪除這個活動", role: .destructive) {
                            onDelete(event)
                            dismiss()
                        }
                        .frame(minHeight: 44)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themeForm()
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
                        .foregroundStyle(Theme.fg)
                }
                .listRowBackground(Theme.surface)
            } else {
                Section {
                    if let u = info.updatedAt {
                        LabeledContent("最後同步", value: u.formatted(date: .abbreviated, time: .shortened))
                    }
                    Toggle("顯示過去的班", isOn: $showPast)
                        .frame(minHeight: 44)
                } footer: {
                    SectionLabel("這裡是練壯讀到的資料，跟打工薪水帳對一下。不對的話，在打工薪水帳改好、打開一次，再回來看。")
                }
                .listRowBackground(Theme.surface)
                let cutoff = Calendar.current.startOfDay(for: .now)
                let shown = info.shifts.filter { showPast || $0.end > cutoff }
                if shown.isEmpty {
                    Text("沒有班")
                        .foregroundStyle(Theme.muted)
                        .listRowBackground(Theme.surface)
                }
                ForEach(shown, id: \.start) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.start.formatted(.dateTime.month().day()) + "（\(TimeFmt.weekday(s.start))）")
                                .font(.headline)
                                .foregroundStyle(Theme.fg)
                            Text(s.name).font(.caption).foregroundStyle(Theme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(TimeFmt.hm(s.start))–\(TimeFmt.hm(s.end))")
                                .font(Theme.number(16, .bold))
                                .foregroundStyle(Theme.fg)
                            Text(String(format: "%.1f 小時", s.end.timeIntervalSince(s.start) / 3600))
                                .font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                    .frame(minHeight: 44)
                    .listRowBackground(Theme.surface)
                }
            }
        }
        .themeForm()
        .navigationTitle("班表檢查")
        .refreshable { info = ShiftReader.load() }
        .onAppear { info = ShiftReader.load() }
    }
}
