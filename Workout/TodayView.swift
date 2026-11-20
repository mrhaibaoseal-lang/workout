import SwiftUI
import SwiftData

struct ActiveWorkout: Identifiable {
    let day: DayTemplate
    let length: WorkoutLength
    var id: String { day.id + "-" + length.rawValue }
}

struct TodayView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @EnvironmentObject private var inventory: InventoryStore
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.maxDumbbell) private var maxDumbbell = 20.0
    @AppStorage(Keys.maxBarbell) private var maxBarbell = 40.0
    // Read so the view refreshes when any planner input changes.
    @AppStorage(ClassStore.key) private var classesRaw = ""
    @AppStorage(Keys.commuteSchool) private var commuteSchool = 15
    @AppStorage(Keys.commuteWork) private var commuteWork = 5
    @AppStorage(Keys.earliestHour) private var earliestHour = 12
    @AppStorage(Keys.preferredHour) private var preferredHour = 14
    @AppStorage(Keys.latestHour) private var latestHour = 25
    @AppStorage(EventStore.key) private var eventsRaw = ""
    @AppStorage(Keys.tiredHours) private var tiredHours = 6
    @Environment(\.scenePhase) private var scenePhase
    @State private var refresh = 0
    @State private var lengthChosen = false

    @State private var length: WorkoutLength = .full
    @State private var pickedDay: DayTemplate?
    @State private var active: ActiveWorkout?
    @AppStorage(Keys.lastRankIndex) private var lastRankIndex = -1
    @State private var rankChange: RankChange?

    private struct RankChange: Identifiable {
        let id = UUID()
        let rank: Rank
        let promoted: Bool
    }

    private var week: Int { Stats.week(since: Date(timeIntervalSince1970: startDate)) }
    private var phase: Phase { ProgramBuilder.phase(week: week) }
    private var day: DayTemplate { pickedDay ?? ProgramBuilder.nextDay(after: sessions) }
    private var equipment: Set<Equipment> { Equipment.parse(equipmentRaw) }
    private var plan: [PlannedExercise] {
        ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length)
    }
    private var trainedToday: Bool {
        sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }
    private var missed: Bool {
        Stats.missedLastPlanned(sessions, weekdays: [])
    }
    private var plans: [DayPlan] {
        _ = refresh
        _ = (classesRaw, commuteSchool, commuteWork, earliestHour, preferredHour, latestHour, weeklyGoal, eventsRaw, tiredHours)
        return Planner.makePlan(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if missed && !trainedToday {
                        MissedCard {
                            active = ActiveWorkout(day: day, length: .minimal)
                        }
                    }
                    let plans = self.plans
                    WeekRingCard(week: week, phase: phase,
                                 done: Stats.sessionsThisWeek(sessions), goal: weeklyGoal,
                                 plans: plans)
                    heroCard(today: plans.first)
                    RankCard(rank: RankEngine.rank(sessions: sessions, goal: weeklyGoal))
                    exerciseList
                    boxStrip
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themeScreen()
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard !lengthChosen, let today = plans.first, !today.done else { return }
                length = today.length ?? .minimal
            }
            .onChange(of: length) { lengthChosen = true }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refresh += 1
                    checkRank()
                }
            }
            .onAppear { checkRank() }
            .onChange(of: sessions.count) { checkRank() }
            .sheet(item: $rankChange) { c in
                RankChangeView(rank: c.rank, promoted: c.promoted)
            }
            .fullScreenCover(item: $active) { a in
                WorkoutView(day: a.day, length: a.length, week: week) {
                    pickedDay = nil
                }
                .environmentObject(inventory)
            }
        }
    }

    /// 牌位變了就跳晉級／降級畫面；第一次只記下來不跳。
    private func checkRank() {
        let r = RankEngine.rank(sessions: sessions, goal: weeklyGoal)
        guard lastRankIndex >= 0 else {
            lastRankIndex = r.index
            return
        }
        guard r.index != lastRankIndex else { return }
        let promoted = r.index > lastRankIndex
        lastRankIndex = r.index
        // 等訓練畫面收起來再跳。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            rankChange = RankChange(rank: r, promoted: promoted)
        }
    }

    // MARK: Header

    private var header: some View {
        let now = Date()
        let cal = Calendar.current
        let dateText = "週\(TimeFmt.weekday(now)) \(cal.component(.month, from: now)) 月 \(cal.component(.day, from: now)) 日"
        let streak = Stats.weekStreak(sessions)
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.muted)
                Text("今天練什麼")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(Theme.fg)
            }
            Spacer()
            if streak > 0 {
                Label("連續 \(streak) 週", systemImage: "flame.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.hotText)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.hotBg, in: Capsule())
                    .overlay(Capsule().stroke(Theme.hotLine, lineWidth: 1))
            }
        }
        .padding(.top, 12)
    }

    // MARK: Hero

    private func heroCard(today: DayPlan?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Tag(text: length.title, fg: Theme.bg, bg: Theme.accent)
                if trainedToday {
                    Label("今天練完了", systemImage: "checkmark.seal.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.green)
                } else if let start = today?.start {
                    Text("\(TimeFmt.hm(start)) 開始")
                        .font(Theme.number(14, .bold))
                        .foregroundStyle(Theme.accentSoft)
                } else if today?.done == false {
                    Text("今天沒排，想動也可以")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accentSoft)
                }
                Spacer()
                Menu {
                    ForEach(ProgramBuilder.days) { d in
                        Button(d.name) { pickedDay = d }
                    }
                } label: {
                    Label("換一天", systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accentSoft)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(day.name)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(Theme.fg)
                Text(summaryLine)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accentSoft)
            }

            if let reason = today?.reason, !reason.isEmpty, !trainedToday {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Theme.accentSoft.opacity(0.8))
            }

            HStack(spacing: 6) {
                ForEach(WorkoutLength.allCases) { l in
                    let on = l == length
                    Button { length = l } label: {
                        Text(l.title)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(on ? Theme.bg : Color(gearHex: "#DCE4F7"))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Theme.accent : .clear, in: Capsule())
                            .overlay(Capsule().stroke(on ? Theme.accent : Theme.accentDim, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                active = ActiveWorkout(day: day, length: length)
            } label: {
                Label(length == .minimal ? "做 1 組就好" : "開始訓練", systemImage: "play.fill")
            }
            .buttonStyle(HotButtonStyle())
            .disabled(plan.isEmpty)
            .opacity(plan.isEmpty ? 0.4 : 1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                Theme.heroGradient
                Image(systemName: "dumbbell")
                    .font(.system(size: 120, weight: .ultraLight))
                    .foregroundStyle(Color(gearHex: "#3D5191").opacity(0.6))
                    .rotationEffect(.degrees(-20))
                    .offset(x: 30, y: -10)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(gearHex: "#34446F"), lineWidth: 1))
    }

    private var summaryLine: String {
        let sets = plan.reduce(0) { $0 + $1.sets }
        if length == .minimal { return "\(day.focus) · 做 1 組就算數" }
        return "約 \(ProgramBuilder.estimatedMinutes(plan)) 分鐘 · \(plan.count) 個動作 · \(sets) 組"
    }

    // MARK: Exercises

    private struct Row: Identifiable {
        let index: Int
        let item: PlannedExercise
        let load: String
        let up: Bool
        var id: String { item.id }
    }

    private var rows: [Row] {
        plan.enumerated().map { i, item in
            let last = Progression.lastSets(for: item.exercise.id, in: sessions)
            let cap = Progression.maxWeight(for: item.exercise, dumbbell: maxDumbbell, barbell: maxBarbell)
            let s = Progression.suggest(item, last: last, phase: phase, increment: increment, maxWeight: cap)
            let lastWeight = last.map(\.weight).max() ?? 0
            let load: String
            if !item.exercise.loaded {
                load = "徒手"
            } else if s.weight > 0 {
                load = "\(Progression.format(s.weight)) kg"
            } else {
                load = "自選"
            }
            return Row(index: i + 1, item: item, load: load,
                       up: item.exercise.loaded && lastWeight > 0 && s.weight > lastWeight)
        }
    }

    @ViewBuilder
    private var exerciseList: some View {
        let rows = self.rows
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("今天的動作").font(.headline).foregroundStyle(Theme.fg)
                Spacer()
                let ups = rows.filter(\.up).count
                if ups > 0 {
                    Text("\(ups) 個建議加重").font(.footnote).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)

            if rows.isEmpty {
                Text("目前器材找不到適合的動作，請到「設定」勾選你的器材。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.hotText)
                    .themeCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { r in
                        HStack(spacing: 12) {
                            Text("\(r.index)")
                                .font(Theme.number(15))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 40, height: 40)
                                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.item.exercise.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.fg)
                                Text("\(r.item.sets) 組 × \(r.item.low)–\(r.item.high) \(r.item.exercise.unit.label)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(r.load)
                                    .font(Theme.number(15))
                                    .foregroundStyle(Theme.fg)
                                if r.up { Tag(text: "加重") }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        if r.index < rows.count {
                            Divider().overlay(Theme.divider)
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
        }
    }

    // MARK: Supply box

    private var boxStrip: some View {
        let count = sessions.count
        let waiting = inventory.boxesAvailable(sessionCount: count)
        let next = Milestone.all
            .filter { $0.kind == .sessions && $0.goal > count }
            .min { $0.goal < $1.goal }
        let title = waiting > 0 ? "有 \(waiting) 個補給箱還沒開" : (trainedToday ? "明天練完再拿 1 個補給箱" : "練完拿 1 個補給箱")
        return HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title3)
                .foregroundStyle(Theme.gold)
                .frame(width: 46, height: 46)
                .background(Theme.goldBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.fg)
                if let m = next, let item = m.item {
                    Text("再 \(m.goal - count) 次解鎖「\(item.name)」（\(m.condition)）")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color(gearHex: "#4A3C1E"), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }
}

// MARK: - Cards

struct MissedCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("上次排定的練習沒做到", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Theme.hotText)
            Text("沒關係，但規則是**絕不連續兩次**。以前放棄，都是從漏練一次、再漏一次開始的。今天就算只做 1 組也算數。")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            Button(action: onStart) {
                Text("現在做 1 組")
            }
            .buttonStyle(HotButtonStyle(height: 48))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.hotLine, lineWidth: 1))
    }
}

/// Weekly goal ring plus the next 7 days from the planner.
struct WeekRingCard: View {
    let week: Int
    let phase: Phase
    let done: Int
    let goal: Int
    let plans: [DayPlan]

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Ring(progress: goal > 0 ? Double(done) / Double(goal) : 0,
                     color: done >= goal ? Theme.green : Theme.accent)
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(done)").font(Theme.number(24))
                        Text("/\(goal)").font(Theme.number(14, .bold)).foregroundStyle(Theme.muted)
                    }
                    .foregroundStyle(Theme.fg)
                    Text("本週").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("第 \(week) 週").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                    Text(phase.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                }
                HStack(spacing: 4) {
                    ForEach(plans) { p in
                        DayDot(plan: p)
                    }
                }
            }
        }
        .themeCard()
    }
}

struct DayDot: View {
    let plan: DayPlan

    private var isToday: Bool { Calendar.current.isDateInToday(plan.day) }

    var body: some View {
        VStack(spacing: 4) {
            Text(isToday ? "今" : TimeFmt.weekday(plan.day))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Theme.hotText : Theme.muted)
            box
                .frame(width: 26, height: 26)
            Text(caption)
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var caption: String {
        if plan.done { return "完成" }
        if let s = plan.start { return TimeFmt.hm(s) }
        return " "
    }

    @ViewBuilder
    private var box: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if plan.done {
            shape.fill(Theme.accent)
                .overlay(Image(systemName: "checkmark").font(.caption2.weight(.heavy)).foregroundStyle(Theme.bg))
        } else if plan.length != nil {
            if isToday {
                shape.fill(Theme.hotBg).overlay(shape.stroke(Theme.hot, lineWidth: 2))
                    .overlay(Text(plan.length == .full ? "60" : "20")
                        .font(Theme.number(10)).foregroundStyle(Theme.hotText))
            } else {
                shape.stroke(Theme.accentDim, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .overlay(Text(plan.length == .full ? "60" : "20")
                        .font(Theme.number(10)).foregroundStyle(Theme.accentSoft))
            }
        } else {
            shape.fill(Color(gearHex: "#1F2732"))
        }
    }
}
