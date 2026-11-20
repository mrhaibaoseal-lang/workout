import SwiftUI
import SwiftData

/// 行程：上面一排週曆（點日期、左右滑換週），下面是當天的訓練卡＋時間軸。
struct AgendaView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(EventStore.key) private var eventsRaw = ""
    @AppStorage(ClassStore.key) private var classesRaw = ""
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var editing: LifeEvent?
    @State private var showMonth = false
    @State private var refresh = 0

    fileprivate enum Kind {
        case lesson, work, event, phone

        var color: Color {
            switch self {
            case .lesson: .blue
            case .work: .orange
            case .event: .pink
            case .phone: .gray
            }
        }
    }

    fileprivate struct Item: Identifiable {
        let id = UUID()
        let kind: Kind
        let start: Date
        let end: Date
        let allDay: Bool
        let icon: String
        let title: String
        let detail: String
        var event: LifeEvent?
    }

    fileprivate enum Training {
        case done([WorkoutSession])
        case planned(WorkoutLength, Date, String)
        case rest(String)
        case none
    }

    /// 一次算好這週要用的資料，避免每個格子各自重讀。
    private struct Snapshot {
        let weekStart: Date
        let days: [Date]
        let classes: [ClassBlock]
        let shifts: [WorkShift]
        let events: [LifeEvent]
        let plans: [DayPlan]
        let sessions: [WorkoutSession]

        func items(on day: Date) -> [Item] {
            let cal = Calendar.current
            let next = cal.date(byAdding: .day, value: 1, to: day)!
            func at(_ m: Int) -> Date { day.addingTimeInterval(TimeInterval(m * 60)) }
            var list: [Item] = []
            let weekday = cal.component(.weekday, from: day)
            for c in classes where c.weekday == weekday {
                list.append(Item(kind: .lesson, start: at(c.startMin), end: at(c.endMin), allDay: false,
                                 icon: "graduationcap.fill", title: c.name, detail: c.room))
            }
            for s in shifts where s.start >= day && s.start < next {
                let hours = s.end.timeIntervalSince(s.start) / 3600
                list.append(Item(kind: .work, start: s.start, end: s.end, allDay: false,
                                 icon: "briefcase.fill", title: "打工", detail: s.name + String(format: " · %.1f 小時", hours)))
            }
            for e in events where e.end > day && e.start < next {
                list.append(Item(kind: e.fromPhone ? .phone : .event, start: e.allDay ? day : e.start, end: e.end,
                                 allDay: e.allDay, icon: e.category.icon, title: e.displayTitle,
                                 detail: e.fromPhone ? "iPhone 行事曆" : e.category.title,
                                 event: e.fromPhone ? nil : e))
            }
            return list.sorted { $0.start < $1.start }
        }

        func training(on day: Date) -> Training {
            let cal = Calendar.current
            let done = sessions.filter { cal.isDate($0.date, inSameDayAs: day) }
            if !done.isEmpty { return .done(done) }
            guard let p = plans.first(where: { $0.day == day }) else { return .none }
            if let length = p.length, let start = p.start { return .planned(length, start, p.reason) }
            return .rest(p.reason)
        }
    }

    private var snapshot: Snapshot {
        _ = (refresh, eventsRaw, classesRaw, weeklyGoal)
        let cal = Calendar.current
        let start = SharedStore.weekStart(selected)
        let end = cal.date(byAdding: .day, value: 7, to: start)!
        return Snapshot(
            weekStart: start,
            days: (0..<7).map { cal.date(byAdding: .day, value: $0, to: start)! },
            classes: ClassStore.decode(classesRaw),
            shifts: ShiftReader.load().shifts,
            events: EventStore.all(from: start, to: end),
            plans: Planner.makePlan(sessions: sessions, horizon: 21),
            sessions: Array(sessions.prefix(200))
        )
    }

    var body: some View {
        let snap = snapshot
        NavigationStack {
            VStack(spacing: 0) {
                weekHeader(snap)
                Divider()
                ScrollView {
                    dayContent(snap)
                        .padding()
                }
                .id(selected)
            }
            .navigationTitle(monthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showMonth = true } label: { Image(systemName: "calendar") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = newEvent() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { e in
                EventEditView(event: e, isNew: !EventStore.decode(eventsRaw).contains { $0.id == e.id },
                              onSave: save, onDelete: delete)
            }
            .sheet(isPresented: $showMonth) {
                NavigationStack {
                    DatePicker("日期", selection: $selected, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()
                        .navigationTitle("選日期")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { Button("完成") { showMonth = false }.bold() }
                }
                .presentationDetents([.medium])
            }
            .onChange(of: selected) { _, new in
                let day = Calendar.current.startOfDay(for: new)
                if day != new { selected = day }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh += 1 }
            }
        }
    }

    private var monthTitle: String {
        selected.formatted(.dateTime.year().month(.wide))
    }

    // MARK: - 週曆

    private func weekHeader(_ snap: Snapshot) -> some View {
        let cal = Calendar.current
        return VStack(spacing: 8) {
            HStack(spacing: 4) {
                Button { shiftWeek(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 28, height: 44)
                }
                ForEach(snap.days, id: \.self) { day in
                    dayCell(day, snap: snap, isSelected: day == selected, isToday: cal.isDateInToday(day))
                        .onTapGesture { withAnimation(.snappy) { selected = day } }
                }
                Button { shiftWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 28, height: 44)
                }
            }
            HStack(spacing: 12) {
                legend(.green, "訓練")
                legend(Kind.lesson.color, "上課")
                legend(Kind.work.color, "打工")
                legend(Kind.event.color, "活動")
                Spacer()
                if !cal.isDateInToday(selected) {
                    Button("回到今天") {
                        withAnimation(.snappy) { selected = cal.startOfDay(for: .now) }
                    }
                    .font(.caption.bold())
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                if v.translation.width < -50 { shiftWeek(1) }
                if v.translation.width > 50 { shiftWeek(-1) }
            }
        )
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }

    private func dayCell(_ day: Date, snap: Snapshot, isSelected: Bool, isToday: Bool) -> some View {
        let kinds = Set(snap.items(on: day).map(\.kind))
        let training = snap.training(on: day)
        return VStack(spacing: 4) {
            Text(TimeFmt.weekday(day))
                .font(.caption2.bold())
                .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : isToday ? Color.accentColor : Color.primary)
            trainingMark(training, selected: isSelected)
                .frame(height: 14)
            HStack(spacing: 2) {
                ForEach([Kind.lesson, .work, .event], id: \.self) { k in
                    if kinds.contains(k) || (k == .event && kinds.contains(.phone)) {
                        Circle().fill(isSelected ? .white : k.color).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor)
            } else if isToday {
                RoundedRectangle(cornerRadius: 12).stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func trainingMark(_ t: Training, selected: Bool) -> some View {
        switch t {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(selected ? .white : .green)
        case .planned(let length, _, _):
            Text(length == .full ? "60" : "20")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 4)
                .background(selected ? Color.white.opacity(0.25) : Color.green.opacity(0.18), in: Capsule())
                .foregroundStyle(selected ? .white : .green)
        default:
            Color.clear
        }
    }

    private func shiftWeek(_ n: Int) {
        withAnimation(.snappy) {
            selected = Calendar.current.date(byAdding: .day, value: 7 * n, to: selected)!
        }
    }

    // MARK: - 當天內容

    @ViewBuilder
    private func dayContent(_ snap: Snapshot) -> some View {
        let items = snap.items(on: selected)
        let allDay = items.filter(\.allDay)
        let timed = items.filter { !$0.allDay }
        VStack(alignment: .leading, spacing: 16) {
            Text(selected.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.title2.bold())

            trainingCard(snap.training(on: selected))

            ForEach(allDay) { item in
                Button { if let e = item.event { editing = e } } label: {
                    Label(item.title + " · 整天", systemImage: item.icon)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(item.kind.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(item.kind.color)
                }
                .buttonStyle(.plain)
            }

            if timed.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "sun.max").font(.title2)
                    Text("這天沒有課、班或活動")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timed.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { gap(from: timed[i - 1].end, to: item.start) }
                        row(item)
                    }
                }
            }

            Button { editing = newEvent() } label: {
                Label("新增活動", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)

            Text("訓練會自動避開課、班和活動。點自己加的活動可以修改。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func trainingCard(_ t: Training) -> some View {
        switch t {
        case .done(let list):
            card(color: .green, icon: "checkmark.seal.fill", caption: "已完成訓練",
                 title: list.map { "\($0.dayName)（\($0.length.title)）" }.joined(separator: "、"),
                 trailing: list.first.map { TimeFmt.hm($0.date) }, note: nil)
        case .planned(let length, let start, let reason):
            card(color: .green, icon: "figure.strengthtraining.traditional", caption: "建議訓練",
                 title: length.title, trailing: "\(TimeFmt.hm(start)) 開始", note: reason)
        case .rest(let reason):
            card(color: .secondary, icon: "moon.zzz.fill", caption: "休息日",
                 title: "不排訓練", trailing: nil, note: reason)
        case .none:
            EmptyView()
        }
    }

    private func card(color: Color, icon: String, caption: String, title: String,
                      trailing: String?, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(caption, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title3.bold())
                Spacer()
                if let trailing {
                    Text(trailing).font(.title3.bold()).monospacedDigit()
                }
            }
            if let note, !note.isEmpty {
                Text(note).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFmt.hm(item.start)).font(.subheadline.bold())
                Text(TimeFmt.hm(item.end)).font(.caption).foregroundStyle(.secondary)
            }
            .monospacedDigit()
            .frame(width: 46, alignment: .trailing)

            Button { if let e = item.event { editing = e } } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(item.kind.color).frame(width: 4)
                    Image(systemName: item.icon).foregroundStyle(item.kind.color).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.body.weight(.medium)).lineLimit(2)
                        if !item.detail.isEmpty {
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if item.event != nil {
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(item.kind.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(item.event == nil)
            .contextMenu {
                if let e = item.event {
                    Button("編輯", systemImage: "pencil") { editing = e }
                    Button("刪除", systemImage: "trash", role: .destructive) { delete(e) }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// 兩個行程之間空超過 1 小時就標出來，一眼看出哪裡有空。
    @ViewBuilder
    private func gap(from: Date, to: Date) -> some View {
        let minutes = Int(to.timeIntervalSince(from) / 60)
        if minutes >= 60 {
            HStack(spacing: 8) {
                Color.clear.frame(width: 46)
                Image(systemName: "ellipsis").foregroundStyle(.tertiary)
                Text("空檔 " + (minutes % 60 == 0 ? "\(minutes / 60) 小時" : "\(minutes / 60) 小時 \(minutes % 60) 分"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 存取

    private func newEvent() -> LifeEvent {
        let base = Calendar.current.startOfDay(for: selected)
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
