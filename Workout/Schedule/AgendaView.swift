import SwiftUI
import SwiftData

/// 行程：上面是一整週（左右滑或按箭頭換週，每天標出訓練與行程），
/// 下面是選中那天：先看訓練，再看時間軸，空檔一眼就看得到。
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
            case .lesson: Theme.accent
            case .work: Theme.gold
            case .event: Theme.accentSoft
            case .phone: Theme.muted
            }
        }

        var label: String {
            switch self {
            case .lesson: "上課"
            case .work: "打工"
            case .event: "活動"
            case .phone: "行事曆"
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
                list.append(Item(kind: .work, start: s.start, end: s.end, allDay: false, icon: "briefcase.fill",
                                 title: s.name, detail: String(format: "%.1f 小時", hours)))
            }
            for e in events where e.end > day && e.start < next {
                list.append(Item(kind: e.fromPhone ? .phone : .event, start: e.allDay ? day : e.start, end: e.end,
                                 allDay: e.allDay, icon: e.category.icon, title: e.displayTitle,
                                 detail: e.fromPhone ? "" : e.category.title,
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
            ScrollView {
                VStack(spacing: 12) {
                    header
                    weekCard(snap)
                    dayContent(snap)
                    linksCard
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
            .sheet(isPresented: $showMonth) {
                NavigationStack {
                    DatePicker("日期", selection: $selected, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .padding()
                        .navigationTitle("跳到日期")
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

    // MARK: - 標題

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Button { showMonth = true } label: {
                    HStack(spacing: 4) {
                        Text(selected.formatted(.dateTime.year().month(.wide)))
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.muted)
                }
                .accessibilityLabel("跳到其他日期")
                Text("行程")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Theme.fg)
            }
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

    // MARK: - 週曆

    private func weekCard(_ snap: Snapshot) -> some View {
        let cal = Calendar.current
        let thisWeek = SharedStore.weekStart(.now) == snap.days.first
        return VStack(spacing: 10) {
            HStack {
                Button { shiftWeek(-1) } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 32)
                }
                .accessibilityLabel("上一週")
                Spacer()
                Text(weekTitle(snap.days))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.fg)
                Spacer()
                Button { shiftWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 32)
                }
                .accessibilityLabel("下一週")
            }
            .foregroundStyle(Theme.accent)

            HStack(spacing: 4) {
                ForEach(snap.days, id: \.self) { day in
                    dayCell(day, snap: snap, isSelected: day == selected, isToday: cal.isDateInToday(day))
                        .onTapGesture { withAnimation(.snappy) { selected = day } }
                }
            }

            HStack(spacing: 10) {
                legend(Theme.hot, "訓練")
                legend(Kind.lesson.color, "上課")
                legend(Kind.work.color, "打工")
                legend(Kind.event.color, "活動")
                Spacer()
                if !thisWeek || !cal.isDateInToday(selected) {
                    Button("回到今天") {
                        withAnimation(.snappy) { selected = cal.startOfDay(for: .now) }
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                }
            }
            .font(.caption2)
            .foregroundStyle(Theme.muted)
        }
        .themeCard(padding: 12)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                if v.translation.width < -50 { shiftWeek(1) }
                if v.translation.width > 50 { shiftWeek(-1) }
            }
        )
    }

    private func weekTitle(_ days: [Date]) -> String {
        guard let f = days.first, let l = days.last else { return "" }
        let cal = Calendar.current
        let a = "\(cal.component(.month, from: f))/\(cal.component(.day, from: f))"
        let b = "\(cal.component(.month, from: l))/\(cal.component(.day, from: l))"
        return SharedStore.weekStart(.now) == f ? "本週 · \(a) – \(b)" : "\(a) – \(b)"
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
        }
    }

    private func dayCell(_ day: Date, snap: Snapshot, isSelected: Bool, isToday: Bool) -> some View {
        let kinds = Set(snap.items(on: day).map(\.kind))
        let past = day < Calendar.current.startOfDay(for: .now)
        return VStack(spacing: 5) {
            Text(isToday ? "今天" : TimeFmt.weekday(day))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isSelected ? Theme.bg.opacity(0.8) : Theme.muted)
            Text("\(Calendar.current.component(.day, from: day))")
                .font(Theme.number(18))
                .foregroundStyle(isSelected ? Theme.bg : past ? Theme.muted : Theme.fg)
            trainingMark(snap.training(on: day), selected: isSelected)
                .frame(height: 16)
            HStack(spacing: 2) {
                ForEach([Kind.lesson, .work, .event], id: \.self) { k in
                    if kinds.contains(k) || (k == .event && kinds.contains(.phone)) {
                        Circle().fill(isSelected ? Theme.bg : k.color).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent)
            } else if isToday {
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.month().day().weekday(.wide)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func trainingMark(_ t: Training, selected: Bool) -> some View {
        switch t {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(selected ? Theme.bg : Theme.green)
        case .planned(let length, _, _):
            Text(length == .full ? "60" : "20")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .foregroundStyle(selected ? Theme.accent : Theme.onHot)
                .background(selected ? Theme.bg : Theme.hot, in: Capsule())
        default:
            Color.clear
        }
    }

    private func shiftWeek(_ n: Int) {
        withAnimation(.snappy) {
            selected = Calendar.current.date(byAdding: .day, value: 7 * n, to: selected)!
        }
    }

    // MARK: - 當天

    @ViewBuilder
    private func dayContent(_ snap: Snapshot) -> some View {
        let items = snap.items(on: selected)
        let allDay = items.filter(\.allDay)
        let timed = items.filter { !$0.allDay }

        trainingCard(snap.training(on: selected))

        VStack(alignment: .leading, spacing: 10) {
            Text(selected.formatted(.dateTime.month().day().weekday(.wide)))
                .font(.headline.weight(.heavy))
                .foregroundStyle(Theme.fg)

            ForEach(allDay) { item in
                Button { if let e = item.event { editing = e } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                        Text(item.title).font(.subheadline.weight(.bold))
                        Spacer()
                        Text("整天").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(item.kind.color)
                    .padding(12)
                    .background(item.kind.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(item.event == nil)
            }

            if timed.isEmpty && allDay.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "sun.max")
                    Text("這天沒有課、班或活動")
                }
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timed.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { gap(from: timed[i - 1].end, to: item.start) }
                        row(item)
                    }
                }
            }

            Text("訓練會自動避開課、班和活動。點自己加的活動可以修改，長按可以刪除。")
                .font(.caption)
                .foregroundStyle(Theme.muted)
        }
        .themeCard()
    }

    @ViewBuilder
    private func trainingCard(_ t: Training) -> some View {
        switch t {
        case .done(let list):
            banner(color: Theme.green, icon: "checkmark.seal.fill", caption: "已完成訓練",
                   title: list.map(\.dayName).joined(separator: "、"),
                   trailing: list.first.map { TimeFmt.hm($0.date) },
                   note: list.map(\.length.title).joined(separator: "、"))
        case .planned(let length, let start, let reason):
            banner(color: Theme.hot, icon: "figure.strengthtraining.traditional", caption: "建議訓練",
                   title: length.title, trailing: TimeFmt.hm(start), note: reason)
        case .rest(let reason):
            banner(color: Theme.muted, icon: "moon.zzz.fill", caption: "休息日",
                   title: "不排訓練", trailing: nil, note: reason)
        case .none:
            EmptyView()
        }
    }

    private func banner(color: Color, icon: String, caption: String, title: String,
                        trailing: String?, note: String?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(caption).font(.caption.weight(.bold)).foregroundStyle(color)
                Text(title).font(.title3.weight(.heavy)).foregroundStyle(Theme.fg)
                if let note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(Theme.muted).lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing).font(Theme.number(24)).foregroundStyle(Theme.fg)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.45), lineWidth: 1))
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        let content = HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(TimeFmt.hm(item.start)).font(Theme.number(15, .bold)).foregroundStyle(Theme.fg)
                Text(TimeFmt.hm(item.end)).font(Theme.number(12, .medium)).foregroundStyle(Theme.muted)
            }
            .frame(width: 46, alignment: .trailing)

            HStack(spacing: 10) {
                Capsule().fill(item.kind.color).frame(width: 4)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: item.icon).font(.caption)
                        Text(item.kind.label).font(.caption2.weight(.bold))
                        if !item.detail.isEmpty {
                            Text("· " + item.detail).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                    .foregroundStyle(item.kind.color)
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.fg)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if item.event != nil {
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(item.kind.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())

        if let e = item.event {
            Button { editing = e } label: { content }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("編輯", systemImage: "pencil") { editing = e }
                    Button("刪除", systemImage: "trash", role: .destructive) { delete(e) }
                }
        } else {
            content
        }
    }

    /// 兩個行程之間空超過 1 小時就標出來。
    @ViewBuilder
    private func gap(from: Date, to: Date) -> some View {
        let minutes = Int(to.timeIntervalSince(from) / 60)
        if minutes >= 60 {
            HStack(spacing: 10) {
                Color.clear.frame(width: 46, height: 1)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text("空檔 " + (minutes % 60 == 0 ? "\(minutes / 60) 小時" : "\(minutes / 60) 小時 \(minutes % 60) 分"))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.muted)
                .padding(.leading, 6)
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - 連結

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
