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
    @AppStorage(Keys.place) private var placeRaw = TrainingPlace.home.rawValue
    @AppStorage(Keys.limitBarbell) private var limitBarbell = true
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.autoWarmup) private var autoWarmup = true
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
    @State private var showIntervals = false
    @ObservedObject private var commands = AppCommands.shared
    @AppStorage(Keys.lastRankIndex) private var lastRankIndex = -1
    @AppStorage(Keys.lastRankPoints) private var lastRankPoints = -1
    @AppStorage(Keys.lastRankCheck) private var lastRankCheck: Double = 0
    @AppStorage(Keys.lastSettledWeek) private var lastSettledWeek: Double = 0
    @State private var rankChange: RankChange?
    @State private var intake: RankIntake?
    @State private var settlement: WeeklySettlement?
    @State private var goalSheet: GoalSheet?
    // 讀進來讓畫面在請假、買卡、押注、排程紀錄變動時重算
    @AppStorage(Keys.leaves) private var leavesRaw = ""
    @AppStorage(Keys.planLog) private var planLogRaw = ""
    @AppStorage(Keys.shieldBuys) private var shieldBuysRaw = ""
    @AppStorage(Keys.bets) private var betsRaw = ""
    // 換課表、改自訂課表或自訂動作時重算今天的動作
    @AppStorage(Keys.activeProgram) private var activeProgram = ""
    @AppStorage(Keys.customPrograms) private var programsRaw = ""
    @AppStorage(Keys.customExercises) private var customExercisesRaw = ""
    @AppStorage(Keys.customInAutoPick) private var customInAutoPick = false
    @AppStorage(Keys.autoSuperset) private var autoSuperset = false
    @AppStorage(Keys.kits) private var kitsRaw = ""
    // 標記不排的動作、換動作、次數範圍調整後，今天的動作也要跟著重算
    @AppStorage(Keys.avoidExercises) private var avoidRaw = ""
    @AppStorage(Keys.patternShift) private var shiftRaw = ""
    @AppStorage(Keys.repCeiling) private var ceilingRaw = ""
    @AppStorage(Keys.extraSet) private var extraRaw = ""
    @AppStorage(Keys.tempRange) private var tempRaw = ""
    @AppStorage(Keys.muscleSetAdjust) private var adjustRaw = ""
    @AppStorage(Keys.volumeReviews) private var reviewsRaw = ""
    @AppStorage(Keys.weeklySummarySeen) private var summarySeen = 0
    @AppStorage(Keys.builtInProgram) private var builtInRaw = ""
    @AppStorage(Keys.weekMerge) private var weekMergeRaw = ""
    @AppStorage(Keys.weekMergeDismissed) private var weekMergeDismissed: Double = 0
    @State private var weeklyFacts: WeeklyFactsItem?
    // 減量時機、升中階（0.26.0）
    @AppStorage(Keys.deloadOverrides) private var deloadRaw = ""
    @AppStorage(Keys.deloadAskedWeek) private var deloadAskedWeek = 0
    @AppStorage(Keys.trainingLevel) private var levelRaw = ""
    @AppStorage(Keys.graduationSnooze) private var graduationSnooze: Double = 0
    @State private var showGraduation = false
    @AppStorage(Keys.focusMuscles) private var focusRaw = ""
    @AppStorage(Keys.focusAskedBlock) private var focusAskedBlock = -1
    @AppStorage(Keys.specialization) private var specRaw = ""

    private struct RankChange: Identifiable {
        let id = UUID()
        let from: RankStep
        let to: RankStep
    }

    private var week: Int { Stats.week(since: Date(timeIntervalSince1970: startDate)) }
    private var phase: Phase {
        _ = deloadRaw
        return ProgramBuilder.phase(week: week)
    }
    private var day: DayTemplate {
        _ = (activeProgram, programsRaw, customExercisesRaw, customInAutoPick, builtInRaw, weekMergeRaw, weekMergeDismissed, specRaw)
        TrainingHistory.sync(sessions)
        // 選過的那天用 id 重新找：換了課表或改了內容，才會拿到最新的
        if let id = pickedDay?.id, let d = ProgramBuilder.days.first(where: { $0.id == id }) { return d }
        return ProgramBuilder.nextDay(after: sessions)
    }
    private var equipment: Set<Equipment> { ProgramBuilder.equipment(place: placeRaw, homeRaw: equipmentRaw) }
    private var plan: [PlannedExercise] {
        _ = (autoSuperset, kitsRaw, avoidRaw, shiftRaw, ceilingRaw, extraRaw, tempRaw, adjustRaw, deloadRaw, levelRaw, focusRaw, specRaw)
        return ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: length,
                                   limitBarbell: limitBarbell && placeRaw == TrainingPlace.home.rawValue,
                                   gym: placeRaw == TrainingPlace.gym.rawValue)
    }
    private func mergeOffer(_ plans: [DayPlan]) -> WeekFit.Offer? {
        _ = (weekMergeRaw, weekMergeDismissed, activeProgram, programsRaw, builtInRaw)
        return WeekFit.offer(sessions: sessions, plans: plans)
    }

    private var trainedToday: Bool {
        sessions.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }
    private var ctx: GoalContext {
        _ = (leavesRaw, planLogRaw, shieldBuysRaw, betsRaw)
        return .load()
    }
    private var missed: Bool {
        GoalEngine.missedLastPlanned(dates: sessions.map(\.date), ctx: ctx)
    }
    private var onLeave: LeaveReason? { ctx.leave(Calendar.current.startOfDay(for: .now)) }
    private var plans: [DayPlan] {
        _ = refresh
        _ = (classesRaw, commuteSchool, commuteWork, earliestHour, preferredHour, latestHour, weeklyGoal, eventsRaw, tiredHours, leavesRaw)
        return Planner.makePlan(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if missed && !trainedToday {
                        MissedCard(onStart: {
                            active = ActiveWorkout(day: day, length: .minimal)
                        }, onLeave: { goalSheet = .leave })
                    }
                    weeklySummaryCard
                    coachCards
                    SideDetectCard(sessions: sessions)
                    specializationCard
                    let plans = self.plans
                    if pickedDay == nil, onLeave == nil, let offer = mergeOffer(plans) {
                        MergeDayCard(offer: offer, onAccept: {
                            withAnimation { WeekFit.accept(offer) }
                        }, onDismiss: {
                            withAnimation { WeekFit.dismiss() }
                        })
                    }
                    let ctx = self.ctx
                    let dates = sessions.map(\.date)
                    let current = GoalEngine.current(dates: dates, goal: weeklyGoal, ctx: ctx)
                    WeekRingCard(week: week, phase: phase,
                                 done: current.count, goal: current.goal,
                                 plans: plans)
                    heroCard(today: plans.first)
                    RankCard(rank: RankEngine.rank(sessions: sessions, goal: weeklyGoal, ctx: ctx), intake: intake)
                    QuestCard(quests: GoalEngine.quests(week: current.week, facts: GoalEngine.facts(sessions),
                                                        goal: current.goal, ctx: ctx),
                              shields: current.shields,
                              activeBet: ctx.bets.first(where: { $0.week == current.week }),
                              onSheet: { goalSheet = $0 })
                    exerciseList
                    weekVolume
                    toolsRow
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
            .onAppear {
                checkRank()
                PersonalVolume.reviewIfNeeded(sessions: sessions)
            }
            .fullScreenCover(isPresented: $showGraduation) {
                GraduationCelebration { showGraduation = false }
            }
            .sheet(item: $weeklyFacts) { item in
                WeeklySummaryView(facts: item.facts) {
                    summarySeen = max(summarySeen, item.facts.week)
                    weeklyFacts = nil
                }
            }
            // 練完時訓練畫面還蓋著，等它收起來（onDismiss）再播，才看得到動畫
            .onChange(of: sessions.count) { if active == nil { checkRank() } }
            .sheet(item: $goalSheet) { g in
                switch g {
                case .leave: LeaveSheet()
                case .bet: BetSheet().environmentObject(inventory)
                case .shield: ShieldSheet().environmentObject(inventory)
                }
            }
            .fullScreenCover(item: $rankChange) { c in
                RankChangeView(from: c.from, to: c.to)
            }
            .fullScreenCover(item: $settlement, onDismiss: { checkRank() }) { s in
                WeeklySettlementView(settlement: s)
            }
            .fullScreenCover(isPresented: $showIntervals) {
                IntervalScreen()
            }
            // 捷徑「開始今天的訓練」（冷啟動時訂閱當下就會收到）
            .onReceive(commands.$pendingStart) { pending in
                guard pending else { return }
                commands.pendingStart = false
                guard active == nil else { return }
                showIntervals = false
                let planned = plans.first.flatMap { $0.done ? nil : $0.length }
                active = ActiveWorkout(day: day, length: planned ?? length)
            }
            .fullScreenCover(item: $active, onDismiss: { checkRank() }) { a in
                WorkoutView(day: a.day, length: a.length, week: week) {
                    pickedDay = nil
                }
                .environmentObject(inventory)
            }
        }
    }

    /// 牌位相關的動畫依序播：每週結算 → 分數入帳（牌位小卡數字跳動）→ 晉級／掉段畫面。
    /// 第一次只記下目前狀態，不播。
    private func checkRank() {
        guard active == nil, rankChange == nil, settlement == nil else { return }
        GoalEngine.settleBets(sessions: sessions, goal: weeklyGoal, inventory: inventory)
        let events = RankEngine.ledger(sessions: sessions, goal: weeklyGoal)
        let points = RankEngine.total(events)
        let r = Rank(points: points)

        // 1. 每週結算（週一第一次打開）
        let weekly = events.filter(\.isSettlement)
        if let last = weekly.last {
            let stamp = last.date.timeIntervalSince1970
            if lastSettledWeek == 0 || lastRankPoints < 0 {
                lastSettledWeek = stamp
            } else if stamp > lastSettledWeek {
                let fresh = weekly.filter { $0.date.timeIntervalSince1970 > lastSettledWeek }
                lastSettledWeek = stamp
                let before = RankEngine.total(events.filter { $0.date < (fresh.first?.date ?? last.date) })
                settlement = WeeklySettlement(events: Array(fresh.suffix(5)), before: before,
                                              after: RankEngine.total(events.filter { $0.date <= last.date }))
                return
            }
        }

        // 2. 分數入帳
        guard lastRankPoints >= 0, lastRankIndex >= 0 else {
            lastRankPoints = points
            lastRankIndex = r.index
            lastRankCheck = Date().timeIntervalSince1970
            return
        }
        var delay = 0.4
        if points != lastRankPoints {
            let since = Date(timeIntervalSince1970: lastRankCheck)
            let chips = events.filter { $0.date > since && $0.delta != 0 }.suffix(3)
            intake = RankIntake(from: lastRankPoints, to: points,
                                chips: chips.isEmpty ? [RankIntake.Chip(text: "分數變動", delta: points - lastRankPoints)]
                                    : chips.map { RankIntake.Chip(text: $0.reason, delta: $0.delta) })
            lastRankPoints = points
            delay = RankIntake.duration + 0.2
            let id = intake?.id
            DispatchQueue.main.asyncAfter(deadline: .now() + RankIntake.duration + 0.4) {
                if intake?.id == id { intake = nil }
            }
        }
        lastRankCheck = Date().timeIntervalSince1970

        // 3. 牌位變了就跳晉級／掉段畫面（等分數跑完）
        guard r.index != lastRankIndex else { return }
        let from = RankStep(index: lastRankIndex)
        lastRankIndex = r.index
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            rankChange = RankChange(from: from, to: RankStep(r))
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
            Button { goalSheet = .leave } label: {
                Image(systemName: onLeave != nil ? "bed.double.fill" : "bed.double")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(onLeave != nil ? Theme.bg : Theme.accentSoft)
                    .frame(width: 36, height: 30)
                    .background(onLeave != nil ? Theme.accent : Theme.raised, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(onLeave != nil ? "今天請假中" : "請假")
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
                if let leave = onLeave, !trainedToday {
                    Label("今天請假：\(leave.title)", systemImage: leave.icon)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.accentSoft)
                } else if trainedToday {
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
                if let name = ProgramBuilder.customName {
                    Label(name, systemImage: "list.bullet.rectangle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted)
                }
            }

            if day.id.hasPrefix(WeekFit.prefix) && !trainedToday {
                HStack(spacing: 8) {
                    Text("這週天數不夠，課表併成一天")
                        .font(.caption)
                        .foregroundStyle(Theme.accentSoft.opacity(0.8))
                    Spacer()
                    Button("改回分開練") { withAnimation { WeekFit.dismiss() } }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }
            }

            if let reason = today?.reason, !reason.isEmpty, !trainedToday {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(Theme.accentSoft.opacity(0.8))
            }

            HStack(spacing: 6) {
                ForEach(TrainingPlace.allCases) { p in
                    let on = p.rawValue == placeRaw
                    Button { placeRaw = p.rawValue } label: {
                        Label(p.title, systemImage: p.icon)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(on ? Theme.bg : Color(gearHex: "#DCE4F7"))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(on ? Color(gearHex: "#DCE4F7") : .clear, in: Capsule())
                            .overlay(Capsule().stroke(on ? Color(gearHex: "#DCE4F7") : Theme.accentDim, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
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
        let minutes = ProgramBuilder.estimatedMinutes(plan, sessions: sessions, gym: placeRaw == TrainingPlace.gym.rawValue,
                                                      increment: increment, autoWarmup: autoWarmup, week: week, length: length)
        return "約 \(minutes) 分鐘 · \(plan.count) 個動作 · \(sets) 組"
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
            let ladder = WeightLadder.make(item, gym: placeRaw == TrainingPlace.gym.rawValue, step: increment)
            let scheme = SetPlanner.resolve(SchemeStore.scheme(for: item.exercise.id), exercise: item.exercise, phase: phase,
                                            grouped: item.group != nil)
            let s = Progression.suggest(item, last: last, phase: phase, ladder: ladder, scheme: scheme)
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
                                Text("\(r.item.sets) 組 × \(r.item.low)–\(r.item.high) \(r.item.exercise.unit.label)"
                                     + (r.item.intensity?.tag.map { " · \($0)日" } ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                if let g = r.item.group {
                                    let size = rows.filter { $0.item.group == g }.count
                                    let letter = Superset.letters(rows.map(\.item.group))[g] ?? "A"
                                    Label("\(Superset.name(size: size)) \(letter)" + (r.item.kit.map { " · 用\($0)" } ?? "")
                                          + (r.item.sharedKit != nil ? " · 每輪要換重量" : ""),
                                          systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(r.item.sharedKit != nil ? Theme.hotText : Theme.accent)
                                }
                                if let from = r.item.replaced {
                                    Text("代替「\(from)」（器材不夠）")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.accentSoft)
                                }
                                if let from = r.item.upgradedFrom {
                                    Text("「\(from)」到頂了，升級成這個")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Theme.gold)
                                }
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

    // MARK: Weekly volume

    /// 本週預計組數：照目前課表、器材排出一週的完整版，點開才算。
    private var weekVolume: some View {
        _ = (autoSuperset, kitsRaw, activeProgram, programsRaw, customExercisesRaw, customInAutoPick, avoidRaw, shiftRaw, adjustRaw, focusRaw, specRaw)
        return WeeklyVolumeCard(plans: {
            ProgramBuilder.weeklyPlans(equipment: equipment, week: week,
                                       limitBarbell: limitBarbell && placeRaw == TrainingPlace.home.rawValue,
                                       gym: placeRaw == TrainingPlace.gym.rawValue)
        }, personal: CustomPrograms.active == nil)
    }

    // MARK: Weekly summary

    /// 減量時機（提早／延後）和升中階的卡片，一次最多一張；減量優先。
    @ViewBuilder
    private var coachCards: some View {
        let _ = (deloadRaw, deloadAskedWeek, levelRaw, graduationSnooze, focusRaw, focusAskedBlock, specRaw)
        let w = week
        if trainedToday || pickedDay != nil {
            EmptyView()
        } else if let offer = Fatigue.offer(week: w, sessions: sessions) {
            DeloadOfferCard(offer: offer, onAccept: {
                let early: Bool
                switch offer {
                case .early: early = true
                case .postpone: early = false
                }
                withAnimation {
                    if early { Plateau.startDeload(sessions: sessions) }
                    else { _ = BlockClock.postpone(week: w) }
                }
            }, onDecline: {
                withAnimation { BlockClock.markAsked(week: w) }
            })
        } else if let g = Graduation.offer(week: w, sessions: sessions) {
            GraduationCard(offer: g, onAccept: {
                Graduation.setLevel(.intermediate)
                showGraduation = true
            }, onSnooze: {
                withAnimation { Graduation.snooze() }
            })
        } else if let a = Focus.offer(week: w, sessions: sessions) {
            // 落後的部位有手臂或肩膀，而且沒排專項期，才多一個「改試專項期」
            let canSpecialize = !Set(a.weak).isDisjoint(with: Specialization.muscles)
                && Specialization.status(week: w) == .none
            FocusOfferCard(analysis: a, onFocus: {
                withAnimation {
                    Focus.set(Array((a.weak + Focus.muscles).prefix(Focus.maxCount)))
                    Focus.markAsked(week: w)
                }
            }, canSpecialize: canSpecialize, onSpecialize: {
                withAnimation {
                    Specialization.begin(week: w)
                    Focus.markAsked(week: w)
                }
            }, onDismiss: {
                withAnimation { Focus.markAsked(week: w) }
            })
        }
    }

    /// 手臂／肩膀專項期：排好或進行中顯示一行狀態，結束後顯示這段的進步（按「好」收起來）。
    @ViewBuilder
    private var specializationCard: some View {
        let _ = (specRaw, deloadRaw, activeProgram)
        switch Specialization.status(week: week) {
        case .scheduled, .running:
            SpecializationStatusRow(status: Specialization.status(week: week))
        case .ended(let block):
            SpecializationEndCard(report: Specialization.report(block: block, sessions: sessions)) {
                withAnimation { Specialization.markEndSeen() }
            }
        case .none:
            EmptyView()
        }
    }

    /// 上週總結的入口：每週一次，看過（按「好」）就收起來。
    @ViewBuilder
    private var weeklySummaryCard: some View {
        let _ = (reviewsRaw, summarySeen)
        let start = Date(timeIntervalSince1970: startDate)
        if let w = WeeklySummary.pendingWeek(start: start, seen: summarySeen, sessions: sessions) {
            WeeklySummaryCard(week: w, hasReview: PersonalVolume.review(endingWeek: w) != nil) {
                weeklyFacts = WeeklyFactsItem(facts: WeeklySummary.facts(week: w, start: start, sessions: sessions,
                                                                         goal: weeklyGoal))
            }
        }
    }

    // MARK: Tools

    private var toolsRow: some View {
        Button {
            showIntervals = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "timer")
                    .font(.title3)
                    .foregroundStyle(Theme.hotText)
                    .frame(width: 46, height: 46)
                    .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("間歇計時")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.fg)
                    Text("Tabata、EMOM、AMRAP，練完加練用")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Supply box

    private var boxStrip: some View {
        let count = sessions.count
        let waiting = inventory.boxesAvailable(sessionCount: GoalEngine.boxTotal(sessions: sessions, goal: weeklyGoal))
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
    var onLeave: (() -> Void)? = nil

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
            if let onLeave {
                Button(action: onLeave) {
                    Label("今天真的不行，請假", systemImage: "bed.double")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GhostButtonStyle(stroke: Theme.hotLine))
            }
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

/// sheet(item:) 用
struct WeeklyFactsItem: Identifiable {
    let facts: WeeklyFacts
    var id: Int { facts.week }
}
