import SwiftUI
import SwiftData

struct ActiveWorkout: Identifiable {
    let day: DayTemplate
    let length: WorkoutLength
    /// 接著練上次沒按完成的訓練（`WorkoutResume`）
    var resume: WorkoutSnapshot? = nil
    /// 從「開始訓練」按鈕進來的才用 zoom 轉場（其他入口沒有對應的起點）
    var zoom: Bool = false
    var id: String { day.id + "-" + length.rawValue }
}

struct TodayView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyLog.date) private var bodyLogs: [BodyLog]
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
    @State private var entrance = TodayEntrance()
    @Namespace private var zoomNS
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lengthChosen = false

    @State private var length: WorkoutLength = .preferred
    @State private var pickedDay: DayTemplate?
    @State private var active: ActiveWorkout?
    @State private var showIntervals = false
    @State private var showPlanCheck = false
    @ObservedObject private var commands = AppCommands.shared
    @AppStorage(Keys.lastRankIndex) private var lastRankIndex = -1
    @AppStorage(Keys.lastRankPoints) private var lastRankPoints = -1
    @AppStorage(Keys.lastRankCheck) private var lastRankCheck: Double = 0
    @AppStorage(Keys.rankRules) private var rankRules = 1
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

    /// 停練暫停寫進去時重畫（`TrainingHistory.refresh` 會在畫面算完後才寫）
    @AppStorage(Keys.trainingPauses) private var pausesRaw = ""
    private var week: Int {
        _ = pausesRaw
        return Stats.week(since: Date(timeIntervalSince1970: startDate))
    }
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
    /// 上次沒按完成的訓練（`WorkoutResume`）
    @State private var resumable: WorkoutSnapshot?
    /// 接著練要用的那一天：照 id 找（併成全身日的那天也找得到）
    private func resumeDay(_ r: WorkoutSnapshot) -> DayTemplate? {
        if let d = ProgramBuilder.days.first(where: { $0.id == r.dayId }) { return d }
        return day.id == r.dayId ? day : nil
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
                    header.todayEntrance(entrance)
                    // 0. 上次練到一半（App 被關掉）：接著練
                    if let r = resumable, active == nil {
                        ResumeCard(snap: r, canResume: resumeDay(r) != nil, onResume: {
                            if let d = resumeDay(r), let len = WorkoutLength(rawValue: r.length) {
                                active = ActiveWorkout(day: d, length: len, resume: r)
                            }
                        }, onDiscard: {
                            WorkoutResume.clear()
                            withAnimation { resumable = nil }
                        })
                        .todayEntrance(entrance)
                    }
                    // 1. 會改變今天要做什麼的：漏練、併成全身日
                    if missed && !trainedToday {
                        MissedCard(onStart: {
                            active = ActiveWorkout(day: day, length: .minimal)
                        }, onLeave: { goalSheet = .leave })
                        .todayEntrance(entrance)
                    }
                    let plans = self.plans
                    if pickedDay == nil, onLeave == nil, let offer = mergeOffer(plans) {
                        MergeDayCard(offer: offer, onAccept: {
                            withAnimation { WeekFit.accept(offer) }
                        }, onDismiss: {
                            withAnimation { WeekFit.dismiss() }
                        })
                        .todayEntrance(entrance)
                    }
                    // 2. 今天的訓練：開始按鈕和動作清單放最上面
                    let plan = self.plan
                    heroCard(today: plans.first, plan: plan).todayEntrance(entrance)
                    if !trainedToday, onLeave == nil, length != .minimal, !plan.isEmpty {
                        PlanCheckRow(findings: planFindings(plan)) { showPlanCheck = true }
                            .todayEntrance(entrance)
                    }
                    exerciseList(plan).todayEntrance(entrance)
                    // 3. 教練的提醒（每週、每個區塊才出現一次）
                    weeklySummaryCard.todayEntrance(entrance)
                    coachCards.todayEntrance(entrance)
                    SideDetectCard(sessions: sessions).todayEntrance(entrance)
                    specializationCard.todayEntrance(entrance)
                    // 4. 本週進度、牌位、任務
                    let ctx = self.ctx
                    let dates = sessions.map(\.date)
                    let current = GoalEngine.current(dates: dates, goal: weeklyGoal, ctx: ctx)
                    SectionHeader(title: "本週").todayEntrance(entrance)
                    WeekRingCard(week: week, phase: phase,
                                 done: current.count, goal: current.goal,
                                 plans: plans)
                        .todayEntrance(entrance)
                    QuestCard(quests: GoalEngine.quests(week: current.week, facts: GoalEngine.facts(sessions),
                                                        goal: current.goal, ctx: ctx),
                              shields: current.shields,
                              activeBet: ctx.bets.first(where: { $0.week == current.week }),
                              onSheet: { goalSheet = $0 })
                        .todayEntrance(entrance)
                    let rank = RankEngine.rank(sessions: sessions, goal: weeklyGoal, ctx: ctx)
                    RankCard(rank: rank, intake: intake,
                             gate: RankEngine.nextGate(sessions: sessions, goal: weeklyGoal, rank: rank, ctx: ctx))
                        .todayEntrance(entrance)
                    // 5. 其他
                    SectionHeader(title: "更多").todayEntrance(entrance)
                    weekVolume.todayEntrance(entrance)
                    HStack(spacing: 10) {
                        toolsTile
                        boxTile
                    }
                    .todayEntrance(entrance)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themeScreen()
            .toolbar(.hidden, for: .navigationBar)
            // 進場動畫只排前 1.6 秒；之後才出現的卡直接顯示，不重播
            .task {
                try? await Task.sleep(for: .seconds(1.6))
                entrance.playing = false
            }
            .onAppear {
                guard !lengthChosen, let today = plans.first, !today.done else { return }
                length = today.length ?? .minimal
            }
            .onChange(of: length) { lengthChosen = true }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    refresh += 1
                    checkRank()
                    resumable = WorkoutResume.load()
                }
            }
            .onAppear {
                checkRank()
                PersonalVolume.reviewIfNeeded(sessions: sessions)
                resumable = WorkoutResume.load()
            }
            .fullScreenCover(isPresented: $showGraduation) {
                GraduationCelebration { showGraduation = false }
            }
            .sheet(isPresented: $showPlanCheck) {
                let plan = self.plan
                PlanCheckSheet(findings: planFindings(plan), plan: plan)
                    .presentationDetents([.medium, .large])
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
            .fullScreenCover(item: $active, onDismiss: {
                checkRank()
                resumable = WorkoutResume.load()
            }) { a in
                WorkoutView(day: a.day, length: a.length, week: week, resume: a.resume) {
                    pickedDay = nil
                }
                .environmentObject(inventory)
                .todayZoomDestination(enabled: a.zoom && !reduceMotion, id: "start", in: zoomNS)
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

        // 牌位規則改版（門檻、扣分、晉級條件）：分數會整個重算，不要因此播掉段動畫，直接記下新狀態
        if rankRules != RankEngine.rulesVersion {
            rankRules = RankEngine.rulesVersion
            if lastRankPoints >= 0 {
                lastRankPoints = points
                lastRankIndex = r.index
                lastRankCheck = Date().timeIntervalSince1970
            }
        }

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

    private func heroCard(today: DayPlan?, plan: [PlannedExercise]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                placeMenu
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
                Text(summaryLine(plan))
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

            if let note = fatigueNote {
                Label(note, systemImage: "bed.double")
                    .font(.caption)
                    .foregroundStyle(Theme.gold)
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
                        Text(lengthLabel(l))
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
                active = ActiveWorkout(day: day, length: length, zoom: true)
            } label: {
                Label(length == .minimal ? "做 1 組就好" : "開始訓練", systemImage: "play.fill")
            }
            .buttonStyle(StartButtonStyle(glow: !plan.isEmpty))
            .todayZoomSource(id: "start", in: zoomNS)
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

    /// 在家／健身房：不常換，做成小選單放在卡片左上角
    private var placeMenu: some View {
        let place = TrainingPlace(rawValue: placeRaw) ?? .home
        return Menu {
            Picker("地點", selection: $placeRaw) {
                ForEach(TrainingPlace.allCases) { p in
                    Label(p.title, systemImage: p.icon).tag(p.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: place.icon)
                Text(place.title)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(Theme.bg)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color(gearHex: "#DCE4F7"), in: Capsule())
        }
        .accessibilityLabel("訓練地點：\(place.title)")
    }

    /// 排課第二意見（`PlanCheck`）：純計算，跟著課表變動重算；AI 說明只在打開畫面時才產生。
    private func planFindings(_ plan: [PlannedExercise]) -> [PlanFinding] {
        guard length != .minimal else { return [] }
        let minutes = ProgramBuilder.estimatedMinutes(plan, sessions: sessions, gym: placeRaw == TrainingPlace.gym.rawValue,
                                                      increment: increment, autoWarmup: autoWarmup, week: week, length: length)
        return PlanCheck.run(plan: plan, day: day, length: length, phase: phase, sessions: sessions,
                             minutes: minutes, equipment: equipment)
    }

    private func summaryLine(_ plan: [PlannedExercise]) -> String {
        let sets = plan.reduce(0) { $0 + $1.sets }
        if length == .minimal { return "\(day.focus) · 做 1 組就算數" }
        let minutes = ProgramBuilder.estimatedMinutes(plan, sessions: sessions, gym: placeRaw == TrainingPlace.gym.rawValue,
                                                      increment: increment, autoWarmup: autoWarmup, week: week, length: length)
        return "\(sets) 組 · \(plan.count) 個動作 · 約 \(minutes) 分鐘"
    }

    /// 長度按鈕：完整／精簡顯示今天實際排到的正式組數（0.51.0 起取代「60 分」「20 分」）。
    private func lengthLabel(_ l: WorkoutLength) -> String {
        if l == .minimal { return l.title }
        let p = l == length ? plan : ProgramBuilder.plan(day: day, equipment: equipment, week: week, length: l,
                                                         limitBarbell: limitBarbell && placeRaw == TrainingPlace.home.rawValue,
                                                         gym: placeRaw == TrainingPlace.gym.rawValue)
        return "\(l.title) \(p.reduce(0) { $0 + $1.sets }) 組"
    }

    /// 自動排到的這天，主要肌肉平均還沒恢復（< 0.6）時提醒；自己選的天、今天練過就不提。
    private var fatigueNote: String? {
        guard !trainedToday, pickedDay == nil, length != .minimal else { return nil }
        let load = MuscleStats.fatigue(sessions)
        let rec = MuscleStats.recovery(sessions)
        guard let score = MuscleStats.readiness(day, recovery: rec), score < 0.6 else { return nil }
        let slow = MuscleStats.primaryMuscles(day)
            .map { ($0, MuscleStats.hoursUntilRecovered($0, fatigue: load[$0] ?? 0)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
        guard let worst = slow.first else { return nil }
        let names = slow.prefix(2).map(\.0.name).joined(separator: "、")
        return "\(names)還在恢復（約 \(Int(worst.1.rounded(.up))) 小時），可以改精簡、只做 1 組，或今天休息。"
    }

    // MARK: Exercises

    private struct Row: Identifiable {
        let index: Int
        let item: PlannedExercise
        let load: String
        let up: Bool
        var id: String { item.id }
    }

    private func rows(_ plan: [PlannedExercise]) -> [Row] {
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
    private func exerciseList(_ plan: [PlannedExercise]) -> some View {
        let rows = self.rows(plan)
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
                var facts = WeeklySummary.facts(week: w, start: start, sessions: sessions, goal: weeklyGoal)
                // 用被總結的那一週算，不是今天（週總結可能過幾天才打開）
                let weekEnd = PersonalVolume.weekStart(w + 1, start: start)
                let lastDay = Stats.calendar.date(byAdding: .day, value: -1, to: weekEnd) ?? weekEnd
                let weights = bodyLogs.filter { $0.weight > 0 && $0.date < weekEnd }.map { (date: $0.date, weight: $0.weight) }
                let bw = weights.last?.weight ?? StartWeight.bodyWeight
                facts.weeklyGain = Nutrition.weeklyChange(weights, now: weekEnd)
                facts.pace = Nutrition.pace(weeklyChange: facts.weeklyGain, bodyWeight: bw)
                if bw > 0, let st = Nutrition.stats(Nutrition.load(), days: 7, endingOn: lastDay) {
                    facts.protein = (st.avg, Nutrition.target(bodyWeight: bw), st.logged)
                }
                weeklyFacts = WeeklyFactsItem(facts: facts)
            }
        }
    }

    // MARK: Tools & supply box

    private var toolsTile: some View {
        Button { showIntervals = true } label: {
            TileButton(icon: "timer", title: "間歇計時", subtitle: "Tabata、EMOM、AMRAP，練完加練用",
                       tint: Theme.hotText, tintBg: Theme.hotBg)
        }
        .buttonStyle(.plain)
    }

    private var boxTile: some View {
        let count = sessions.count
        let waiting = inventory.boxesAvailable(sessionCount: GoalEngine.boxTotal(sessions: sessions, goal: weeklyGoal))
        let next = Milestone.all
            .filter { $0.kind == .sessions && $0.goal > count }
            .min { $0.goal < $1.goal }
        let title = waiting > 0 ? "\(waiting) 個補給箱" : "補給箱"
        var subtitle = waiting > 0 ? "到「角色」打開" : (trainedToday ? "明天練完再拿 1 個" : "練完拿 1 個")
        if waiting == 0, let m = next, let item = m.item {
            subtitle = "再 \(m.goal - count) 次解鎖「\(item.name)」"
        }
        return TileButton(icon: "shippingbox.fill", title: title, subtitle: subtitle,
                          tint: Theme.gold, tintBg: Theme.goldBg, dashed: true)
    }
}

// MARK: - Cards

/// 上次的訓練沒按「完成」就被關掉（`WorkoutResume`）。
struct ResumeCard: View {
    let snap: WorkoutSnapshot
    /// 課表改過、找不到那一天就不能接著練，只能放棄
    let canResume: Bool
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("上次的訓練還沒結束", systemImage: "arrow.uturn.backward.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.accentSoft)
            Text("\(snap.dayName) · 已經做完 \(snap.doneSets) 組 · \(Date(timeIntervalSince1970: snap.savedAt).formatted(date: .omitted, time: .shortened)) 存的")
                .font(.subheadline)
                .foregroundStyle(Theme.fg)
            if canResume {
                Button(action: onResume) { Text("接著練") }
                    .buttonStyle(HotButtonStyle(height: 48))
            } else {
                Text("課表改過了，找不到那一天，沒辦法接著練。")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Button(action: onDiscard) {
                Label("放棄這次（不儲存）", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

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
    /// 卡片露出在螢幕上之後，已完成的格子才依序點亮（在螢幕外時不播）
    @State private var visible = false
    @State private var reveal = false

    var body: some View {
        let doneIDs = plans.filter(\.done).map(\.id)
        return HStack(spacing: 16) {
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
                        DayDot(plan: p, reveal: reveal, visible: visible,
                               order: doneIDs.firstIndex(of: p.id) ?? 0)
                    }
                }
            }
        }
        .themeCard()
        .trackVisibility($visible)
        .onChange(of: visible) { _, v in if v { reveal = true } }
    }
}

struct DayDot: View {
    let plan: DayPlan
    /// 這一週的卡片第一次露出來了：完成的格子開始依序點亮
    var reveal = true
    /// 卡片現在看得到（今天剛完成的爆光要等看得到才播）
    var visible = true
    /// 在本週已完成的格子裡排第幾個（決定點亮的先後）
    var order = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lit: Bool
    @State private var pop = false
    @State private var bursting = false

    init(plan: DayPlan, reveal: Bool = true, visible: Bool = true, order: Int = 0) {
        self.plan = plan
        self.reveal = reveal
        self.visible = visible
        self.order = order
        // 卡片已經亮過了（例如資料更新後重建的格子）就直接是亮的
        _lit = State(initialValue: reveal)
    }

    private var isToday: Bool { Calendar.current.isDateInToday(plan.day) }

    /// 完成的格子要等點亮才顯示成完成
    private var showDone: Bool { plan.done && lit }

    var body: some View {
        VStack(spacing: 4) {
            Text(isToday ? "今" : TimeFmt.weekday(plan.day))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Theme.hotText : Theme.muted)
            box
                .frame(width: 26, height: 26)
                .scaleEffect(pop ? 1.22 : 1)
                .overlay { if bursting { DayBurstFX() } }
            Text(caption)
                .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .onAppear { if reveal { lightUp() } }
        .onChange(of: reveal) { _, r in if r { lightUp() } }
        .onChange(of: visible) { _, v in if v { burstIfNeeded() } }
        .onChange(of: plan.done) { _, done in
            if done { lightUp() } else { lit = reveal }
        }
    }

    /// 依順序點亮；減少動態效果時直接顯示結果
    private func lightUp() {
        if lit {
            burstIfNeeded()
            return
        }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { lit = true }
            burstIfNeeded(afterLight: true)
            return
        }
        let delay = 0.15 + Double(order) * 0.12
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { lit = true; pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pop = false }
            }
            burstIfNeeded(afterLight: true)
        }
    }

    /// 今天剛完成的那一格：小爆光（縮放加光暈），每天只播一次
    private func burstIfNeeded(afterLight: Bool = false) {
        guard isToday, plan.done, lit, visible || afterLight, !DayBurstMemo.played else { return }
        DayBurstMemo.markPlayed()
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        bursting = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { pop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { bursting = false }
    }

    private var caption: String {
        if plan.done { return "完成" }
        if let s = plan.start { return TimeFmt.hm(s) }
        return " "
    }

    @ViewBuilder
    private var box: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if showDone {
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
