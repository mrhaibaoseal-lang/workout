import XCTest
import SwiftData
@testable import Workout

/// 區塊時鐘、每週組數平衡、併成全身日、停練回來、停練暫停週數、徒手升級、程度評估（0.33.0 補的測試）。
final class BlockAndVolumeTests: XCTestCase {

    private var cal: Calendar { Stats.calendar }

    private func day(_ base: Date, _ n: Int) -> Date {
        cal.date(byAdding: .day, value: n, to: cal.startOfDay(for: base))!
    }

    // MARK: BlockClock

    func testBlockClockDefaultSixWeeks() {
        let a = BlockClock.locate(week: 1, overrides: [:])
        XCTAssertEqual(a, BlockClock.Location(block: 0, start: 1, deload: 6, planned: 6))
        XCTAssertEqual(BlockClock.locate(week: 6, overrides: [:]).block, 0)
        let b = BlockClock.locate(week: 7, overrides: [:])
        XCTAssertEqual(b.block, 1)
        XCTAssertEqual(b.start, 7)
        XCTAssertEqual(b.deload, 12)
        XCTAssertEqual(b.weekInBlock(9), 3)
    }

    func testBlockClockEarlyDeloadNeedsThreeNormalWeeks() {
        // 第一個區塊前兩週是適應期：最早第 6 週才能減量
        XCTAssertEqual(BlockClock.locate(week: 1, overrides: [0: 4]).deload, 6)
        // 第二個區塊從第 7 週開始，最早第 10 週
        let loc = BlockClock.locate(week: 8, overrides: [1: 8])
        XCTAssertEqual(loc.deload, 10)
        XCTAssertEqual(BlockClock.locate(week: 11, overrides: [1: 10]).start, 11)
    }

    func testBlockClockPostponeIsCapped() {
        XCTAssertEqual(BlockClock.locate(week: 1, overrides: [0: 8]).deload, 8)
        XCTAssertEqual(BlockClock.locate(week: 9, overrides: [0: 8]).start, 9)
        // 最長 8 週
        XCTAssertEqual(BlockClock.locate(week: 1, overrides: [0: 99]).deload, 8)
    }

    // MARK: VolumePlan.balance

    func testBalanceRefillsSkippedSlotOnSameMuscle() {
        let day = VolumePlan.DayInput(patterns: [.hPush, .triceps], sets: [3, 2], lost: [(pattern: .incline, sets: 3)])
        let out = VolumePlan.balance(days: [day], phase: .rampUp)
        // 胸只有臥推一個動作：補到 4 組上限，剩下的不硬塞給三頭
        XCTAssertEqual(out, [[4, 2]])
    }

    func testBalanceAddsOnlyInNormalPhase() {
        let day = VolumePlan.DayInput(patterns: [.biceps], sets: [2], lost: [])
        XCTAssertEqual(VolumePlan.balance(days: [day], phase: .deload), [[2]])
        XCTAssertEqual(VolumePlan.balance(days: [day], phase: .rampUp), [[2]])
        let normal = VolumePlan.balance(days: [day], phase: .normal)
        XCTAssertGreaterThan(normal[0][0], 2)
        XCTAssertLessThanOrEqual(normal[0][0], VolumePlan.maxSetsPerExercise)
    }

    func testBalanceNeverExceedsLimits() {
        let days = ProgramBuilder.splitDays.map { d in
            VolumePlan.DayInput(patterns: d.slots.map(\.pattern), sets: d.slots.map(\.sets), lost: [])
        }
        let out = VolumePlan.balance(days: days, phase: .normal)
        for (d, sets) in out.enumerated() {
            XCTAssertTrue(sets.allSatisfy { $0 <= VolumePlan.maxSetsPerExercise }, "day \(d)")
            XCTAssertLessThanOrEqual(sets.reduce(0, +) - days[d].sets.reduce(0, +), VolumePlan.maxExtraPerDay)
        }
    }

    func testLowerBodyWeeklySetsStayInRangeAfterLungeCut() {
        let slots = ProgramBuilder.splitDays.flatMap(\.slots).map { (pattern: $0.pattern, sets: $0.sets) }
        let weekly = VolumePlan.weekly(slots: slots)
        for m in [Muscle.quads, .glutes, .hamstrings] {
            XCTAssertTrue((10...16).contains(weekly[m] ?? 0), "\(m): \(weekly[m] ?? 0)")
        }
        // 下半身 A 的弓步只當輔助
        let lunge = ProgramBuilder.splitDays.first { $0.id == "lowerA" }!.slots.first { $0.pattern == .lunge }!
        XCTAssertFalse(lunge.essential)
        XCTAssertEqual(lunge.sets, 2)
    }

    // MARK: WeekFit

    func testMergedDayIsCompactAndCoversBothDays() {
        let upper = ProgramBuilder.splitDays.first { $0.id == "upperA" }!
        let lower = ProgramBuilder.splitDays.first { $0.id == "lowerA" }!
        let m = WeekFit.merged([upper, lower])
        XCTAssertEqual(m.id, "merge:upperA+lowerA")
        XCTAssertEqual(WeekFit.parts(m.id), ["upperA", "lowerA"])
        XCTAssertLessThanOrEqual(m.slots.count, WeekFit.maxSlots)
        let patterns = m.slots.map(\.pattern)
        XCTAssertEqual(patterns.count, Set(patterns).count, "同一個動作類型不重複")
        XCTAssertTrue(patterns.contains(.hPush))
        XCTAssertTrue(patterns.contains(.squat))
        XCTAssertTrue(m.slots.allSatisfy { $0.sets >= 2 })
        XCTAssertEqual(Set(m.slots.compactMap(\.source)), ["upperA", "lowerA"])
    }

    func testPartsOfNormalDay() {
        XCTAssertEqual(WeekFit.parts("upperB"), ["upperB"])
    }

    // MARK: Comeback

    private func session(_ ctx: ModelContext, _ date: Date, _ id: String, _ w: Double) -> WorkoutSession {
        let s = WorkoutSession(date: date, dayKey: "upperA", length: .full, durationSeconds: 3600)
        s.phase = Phase.normal.rawValue
        ctx.insert(s)
        let e = SetEntry(exerciseId: id, setIndex: 0, weight: w, reps: 10, date: date, rir: 2)
        e.session = s
        ctx.insert(e)
        return s
    }

    func testComebackDetectsLayoffNotYetReturned() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let now = Date.now
        let old = session(ctx, day(now, -15), "db_bench", 12.5)
        try ctx.save()
        let s = try XCTUnwrap(Comeback.detect([old], now: now))
        XCTAssertEqual(s.gapDays, 15)
        XCTAssertNil(s.returned)
        XCTAssertEqual(s.level, 1)
        XCTAssertEqual(s.cut, 0.1, accuracy: 0.001)
        XCTAssertEqual(s.before["db_bench"], 12.5)
    }

    func testComebackAfterReturnAndLongGap() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let now = Date.now
        let back = session(ctx, day(now, -2), "db_row", 10)
        let old = session(ctx, day(now, -30), "db_bench", 12.5)
        try ctx.save()
        let s = try XCTUnwrap(Comeback.detect([back, old], now: now))
        XCTAssertEqual(s.gapDays, 28)
        XCTAssertEqual(s.level, 2)
        XCTAssertNotNil(s.returned)
        XCTAssertTrue(s.doneAfter.contains("db_row"))
        XCTAssertFalse(s.doneAfter.contains("db_bench"))
    }

    func testNoComebackForNormalGaps() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let now = Date.now
        let a = session(ctx, day(now, -1), "db_bench", 12.5)
        let b = session(ctx, day(now, -4), "db_bench", 12.5)
        try ctx.save()
        XCTAssertNil(Comeback.detect([a, b], now: now))
    }

    // MARK: TrainingPause

    func testPauseStartsAfterTwoWeeks() {
        let last = day(.now, -60)
        XCTAssertNil(TrainingPause.pause(lastBefore: last, until: day(last, 13), ongoing: true))
        // 還沒回來：蓋到這一週結尾
        let p14 = TrainingPause.pause(lastBefore: last, until: day(last, 14), ongoing: true)
        XCTAssertEqual(p14?.days, 7)
        XCTAssertEqual(p14?.from, day(last, 14).timeIntervalSince1970)
        XCTAssertEqual(TrainingPause.pause(lastBefore: last, until: day(last, 21), ongoing: true)?.days, 14)
        // 回來了：進位到 7 的倍數
        XCTAssertNil(TrainingPause.pause(lastBefore: last, until: day(last, 14), ongoing: false))
        XCTAssertEqual(TrainingPause.pause(lastBefore: last, until: day(last, 15), ongoing: false)?.days, 7)
        XCTAssertEqual(TrainingPause.pause(lastBefore: last, until: day(last, 21), ongoing: false)?.days, 7)
        XCTAssertEqual(TrainingPause.pause(lastBefore: last, until: day(last, 30), ongoing: false)?.days, 21)
    }

    /// 停練中每天重算暫停（像 `TrainingPause.record` 那樣），週數不能往回跳、滿 14 天後要停住；回來後連續往前走。
    func testWeekNeverGoesBackDuringOngoingLayoff() {
        let start = day(.now, -200)
        for lastOffset in [20, 23, 26] {
            let last = day(start, lastOffset)
            for returnGap in [14, 15, 19, 21, 30, 44] {
                var prev = 0
                for g in 0...(returnGap + 30) {
                    let date = day(last, g)
                    let p = g < returnGap
                        ? TrainingPause.pause(lastBefore: last, until: date, ongoing: true)
                        : TrainingPause.pause(lastBefore: last, until: day(last, returnGap), ongoing: false)
                    let w = TrainingPause.week(since: start, at: date, pauses: p.map { [$0] } ?? [])
                    XCTAssertGreaterThanOrEqual(w, prev, "last \(lastOffset) return \(returnGap) gap \(g)")
                    XCTAssertLessThanOrEqual(w - prev, prev == 0 ? w : 1)
                    if g >= 14 && g < returnGap {
                        let frozen = TrainingPause.week(since: start, at: day(last, 14), pauses: [])
                        XCTAssertEqual(w, frozen, "停練中週數要停住：gap \(g)")
                    }
                    prev = w
                }
            }
        }
    }

    func testWeekFreezesDuringPause() {
        let start = day(.now, -100)
        let pauses = [TrainingPause.Pause(from: day(start, 14).timeIntervalSince1970, days: 14)]
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 13), pauses: pauses), 2)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 14), pauses: pauses), 3)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 27), pauses: pauses), 3)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 34), pauses: pauses), 3)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 35), pauses: pauses), 4)
        // 沒有暫停就是原本的算法
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 35), pauses: []), 6)
    }

    func testWeekStartSkipsPause() {
        let start = day(.now, -100)
        let pauses = [TrainingPause.Pause(from: day(start, 14).timeIntervalSince1970, days: 14)]
        XCTAssertEqual(TrainingPause.weekStart(2, start: start, pauses: pauses), day(start, 7))
        XCTAssertEqual(TrainingPause.weekStart(3, start: start, pauses: pauses), day(start, 14))
        XCTAssertEqual(TrainingPause.weekStart(4, start: start, pauses: pauses), day(start, 35))
        // 週數和週開始互相對得上
        for n in 1...8 {
            let d = TrainingPause.weekStart(n, start: start, pauses: pauses)
            XCTAssertEqual(TrainingPause.week(since: start, at: d, pauses: pauses), n)
        }
    }

    func testPauseMidWeekKeepsAlignment() {
        let start = day(.now, -100)
        // 停練前最後一次在第 2 週的第 3 天，暫停從那之後 7 天開始
        let pauses = [TrainingPause.Pause(from: day(start, 17).timeIntervalSince1970, days: 7)]
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 16), pauses: pauses), 3)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 27), pauses: pauses), 3)
        XCTAssertEqual(TrainingPause.week(since: start, at: day(start, 28), pauses: pauses), 4)
        XCTAssertEqual(TrainingPause.weekStart(4, start: start, pauses: pauses), day(start, 28))
    }

    // MARK: Upgrade（徒手）

    private func ex(_ id: String) -> Exercise { ExerciseLibrary.byId(id)! }

    func testBodyweightUpgradeChains() {
        let ups = ["pushup": "pause_pushup", "pause_pushup": "archer_pushup"]
        XCTAssertEqual(Upgrade.replacement(for: ex("pushup"), equipment: [], used: [], upgrades: ups)?.id, "archer_pushup")
        XCTAssertEqual(Upgrade.replacement(for: ex("pushup"), equipment: [], used: ["archer_pushup"], upgrades: ups)?.id, "pause_pushup")
        XCTAssertNil(Upgrade.replacement(for: ex("pushup"), equipment: [], used: [], upgrades: [:]))
        // 升級後的動作要椅子、沒有椅子就不換
        XCTAssertNil(Upgrade.replacement(for: ex("pike_pushup"), equipment: [], used: [],
                                         upgrades: ["pike_pushup": "elevated_pike"]))
    }

    func testBodyweightNeedsTwoSessionsInARow() {
        let empty = WeightLadder(loadings: [], step: 1)
        let hit: [(weight: Double, reps: Int)] = [(0, 12), (0, 12)]
        let miss: [(weight: Double, reps: Int)] = [(0, 12), (0, 10)]
        XCTAssertTrue(Upgrade.ready(ex("pushup"), high: 12, work: hit, previous: hit, ladder: empty))
        XCTAssertFalse(Upgrade.ready(ex("pushup"), high: 12, work: hit, previous: miss, ladder: empty))
        XCTAssertFalse(Upgrade.ready(ex("pushup"), high: 12, work: hit, previous: [], ladder: empty))
        XCTAssertFalse(Upgrade.ready(ex("pushup"), high: 12, work: miss, previous: hit, ladder: empty))
    }

    func testUpgradeTargetChecksEquipmentAndHistory() {
        // 屈體伏地挺身 → 腳抬高要椅子：沒有椅子就沒有目標，建議文字也不會答應
        XCTAssertNil(Upgrade.target(for: ex("pike_pushup"), equipment: [], upgrades: [:]))
        XCTAssertEqual(Upgrade.target(for: ex("pike_pushup"), equipment: [.bench], upgrades: [:])?.id, "elevated_pike")
        // 已經升級過就不再升
        XCTAssertNil(Upgrade.target(for: ex("pushup"), equipment: [], upgrades: ["pushup": "pause_pushup"]))
        XCTAssertEqual(Upgrade.target(for: ex("pause_pushup"), equipment: [], upgrades: ["pushup": "pause_pushup"])?.id,
                       "archer_pushup")
    }

    func testBodyweightQualifiesOnRepsOnly() {
        let empty = WeightLadder(loadings: [], step: 1)
        XCTAssertTrue(Upgrade.qualifies(ex("pushup"), high: 12, work: [(0, 12), (0, 13), (0, 12)], ladder: empty))
        XCTAssertFalse(Upgrade.qualifies(ex("pushup"), high: 12, work: [(0, 12), (0, 11)], ladder: empty))
        XCTAssertFalse(Upgrade.qualifies(ex("plank"), high: 60, work: [(0, 60)], ladder: empty))
        // 負重動作沒有器材階梯不算到頂
        XCTAssertFalse(Upgrade.qualifies(ex("goblet_squat"), high: 12, work: [(10, 12)], ladder: empty))
    }

    func testEveryBodyweightUpgradeIsHarderSamePattern() {
        for (from, to) in Upgrade.paths {
            guard let a = ExerciseLibrary.byId(from), let b = ExerciseLibrary.byId(to) else {
                XCTFail("\(from) → \(to) 不在動作庫"); continue
            }
            XCTAssertEqual(a.pattern, b.pattern, "\(from) → \(to)")
            XCTAssertEqual(a.loaded, b.loaded, "\(from) → \(to)")
        }
        // 每條路線都走得完、不會繞圈
        for start in Upgrade.paths.keys {
            var seen: Set<String> = [start]
            var id = start
            while let next = Upgrade.paths[id] {
                XCTAssertFalse(seen.contains(next), "\(start) 繞圈")
                if seen.contains(next) { break }
                seen.insert(next)
                id = next
            }
        }
    }

    // MARK: LevelTest

    func testLevelTestLifts() {
        let r = LevelTest.Result(pushups: 20, gobletKg: 10, rowKg: nil, date: 0)
        let l = LevelTest.lifts(r, bodyWeight: 70)
        // 次數超過 15 下的當 15 下算（Epley 高次數會高估）
        XCTAssertEqual(l["bb_bench"] ?? 0, 70 * 0.64 * (1 + 15.0 / 30), accuracy: 0.01)
        XCTAssertEqual(l["goblet_squat"] ?? 0, 10 * (1 + 12.0 / 30), accuracy: 0.01)
        XCTAssertNil(l["db_row"])
        let eq = LevelTest.benchEquivalent(LevelTest.Result(pushups: 20, gobletKg: nil, rowKg: nil, date: 0), bodyWeight: 70)
        XCTAssertEqual(eq ?? 0, l["bb_bench"] ?? -1, accuracy: 0.01)
        XCTAssertNil(LevelTest.benchEquivalent(LevelTest.Result(pushups: nil, gobletKg: nil, rowKg: nil, date: 0), bodyWeight: 70))
    }

    func testLevelTestPushupsCapAndOwnBodyWeight() {
        // 80 下不能推成好幾倍體重
        let many = LevelTest.lifts(LevelTest.Result(pushups: 80, gobletKg: nil, rowKg: nil, date: 0), bodyWeight: 60)
        XCTAssertLessThanOrEqual(many["bb_bench"] ?? 0, 60 * 0.64 * 1.5 + 0.01)
        // 測試時有填體重，就用那個體重，不用目前記的
        let own = LevelTest.Result(pushups: 10, gobletKg: nil, rowKg: nil, date: 0, bodyWeight: 45)
        XCTAssertEqual(LevelTest.lifts(own, bodyWeight: 60)["bb_bench"] ?? 0, 45 * 0.64 * (1 + 10.0 / 30), accuracy: 0.01)
    }

    func testLevelTestReferencesExist() {
        let r = LevelTest.Result(pushups: 10, gobletKg: 8, rowKg: 8, date: 0)
        for id in LevelTest.lifts(r, bodyWeight: 60).keys {
            XCTAssertNotNil(ExerciseLibrary.byId(id), id)
            XCTAssertNotNil(StartWeight.strength[id], id)
        }
    }

    // MARK: Nutrition

    func testWeeklyGainSlope() {
        let now = Date.now
        let pts: [(date: Date, weight: Double)] = (0..<5).map { i in
            (date: now.addingTimeInterval(-Double(28 - i * 7) * 86400), weight: 70 + Double(i) * 0.3)
        }
        XCTAssertEqual(Nutrition.weeklyChange(pts, now: now) ?? 0, 0.3, accuracy: 0.001)
        // 只有一筆或相隔太近算不出來
        XCTAssertNil(Nutrition.weeklyChange(Array(pts.suffix(1)), now: now))
        XCTAssertNil(Nutrition.weeklyChange([(now.addingTimeInterval(-3 * 86400), 70), (now, 70.5)], now: now))
    }

    func testPaceBands() {
        XCTAssertEqual(Nutrition.pace(weeklyChange: nil, bodyWeight: 70), .unknown)
        XCTAssertEqual(Nutrition.pace(weeklyChange: -0.2, bodyWeight: 70), .losing)
        XCTAssertEqual(Nutrition.pace(weeklyChange: 0.05, bodyWeight: 70), .slow)
        XCTAssertEqual(Nutrition.pace(weeklyChange: 0.25, bodyWeight: 70), .good)
        XCTAssertEqual(Nutrition.pace(weeklyChange: 0.6, bodyWeight: 70), .fast)
        XCTAssertEqual(Nutrition.target(bodyWeight: 70), 112)
    }

    func testProteinAverageSkipsEmptyDays() {
        let now = Date.now
        let cal = Calendar.current
        let log = [Nutrition.key(now): 100, Nutrition.key(cal.date(byAdding: .day, value: -2, to: now)!): 140,
                   Nutrition.key(cal.date(byAdding: .day, value: -9, to: now)!): 10]
        XCTAssertEqual(Nutrition.average(log, days: 7, now: now), 120)
        XCTAssertNil(Nutrition.average([:], days: 7, now: now))
    }

    // MARK: 動作自己指定部位

    func testExerciseOwnMusclesOverridePattern() {
        func dict(_ l: [(Muscle, Double)]) -> [Muscle: Double] { Dictionary(uniqueKeysWithValues: l) }
        // 有指定：用指定的，不是動作類型的
        let ytw = ExerciseLibrary.byId("prone_ytw")!
        XCTAssertEqual(dict(ytw.trainedMuscles), [.rearDelt: 1, .traps: 1])
        XCTAssertNil(dict(ytw.trainedMuscles)[.lats])
        let hammer = ExerciseLibrary.byId("db_hammer_curl")!
        XCTAssertEqual(dict(hammer.trainedMuscles), [.biceps: 1, .forearms: 1])
        for id in ["db_split_squat", "split_squat", "pause_split_squat", "db_step_up"] {
            XCTAssertEqual(dict(ExerciseLibrary.byId(id)!.trainedMuscles), [.quads: 1, .glutes: 1], id)
        }
        // 沒指定：回傳動作類型的部位
        let bench = ExerciseLibrary.byId("db_bench")!
        XCTAssertNil(bench.muscles)
        XCTAssertEqual(dict(bench.trainedMuscles), dict(bench.pattern.muscles))
        // 新動作：部位正確、同動作類型的排課（VolumePlan）不受影響
        XCTAssertEqual(dict(ExerciseLibrary.byId("side_plank")!.trainedMuscles), [.obliques: 1])
        XCTAssertEqual(dict(ExerciseLibrary.byId("sissy_squat")!.trainedMuscles), [.quads: 1])
        XCTAssertEqual(dict(ExerciseLibrary.byId("cable_high_chop")!.trainedMuscles), [.obliques: 1, .abs: 0.5])
    }

    func testNewExercisesInLibrary() {
        let ids = ["sissy_squat", "reverse_nordic", "cable_high_chop", "side_plank", "farmer_walk",
                   "cable_one_arm_pulldown", "db_side_lying_lateral", "db_fly"]
        for id in ids { XCTAssertNotNil(ExerciseLibrary.byId(id), id) }
        let all = ExerciseLibrary.builtIn.map(\.id)
        XCTAssertEqual(all.count, Set(all).count, "動作 id 不重複")
        // 滑輪動作只用高位（.cable），不用器械
        XCTAssertEqual(ExerciseLibrary.byId("cable_high_chop")!.requires, [.cable])
        XCTAssertEqual(ExerciseLibrary.byId("cable_one_arm_pulldown")!.requires, [.cable])
        // 單側動作接上左右平衡
        for id in ["cable_one_arm_pulldown", "cable_high_chop", "side_plank"] {
            XCTAssertTrue(SideBalance.sided(ExerciseLibrary.byId(id)!), id)
        }
        // 腿伸展：健身房機器版還是第一個，在家有徒手版
        let gym = ExerciseLibrary.candidates(for: .quadIso, equipment: Equipment.gym).map(\.id)
        XCTAssertEqual(gym.first, "leg_extension")
        let home = ExerciseLibrary.candidates(for: .quadIso, equipment: []).map(\.id)
        XCTAssertEqual(home, ["sissy_squat", "reverse_nordic"])
    }

    // MARK: DemoVideos

    func testDemoVideoIdsValidAndExercisesExist() {
        for (id, v) in DemoVideos.byExercise {
            XCTAssertNotNil(ExerciseLibrary.byId(id), id)
            XCTAssertTrue(DemoVideos.isValidId(v.id), "\(id): \(v.id)")
        }
        for (id, base) in DemoVideos.sameAs {
            XCTAssertNotNil(ExerciseLibrary.byId(id), id)
            XCTAssertNotNil(DemoVideos.byExercise[base], base)
        }
        XCTAssertFalse(DemoVideos.isValidId("abc\"><x"))
        XCTAssertFalse(DemoVideos.isValidId("abcdefghij中"))
        XCTAssertFalse(DemoVideos.isValidId("abcdefghij１"))
        let url = DemoVideos.searchURL(for: ExerciseLibrary.byId("db_kickback")!)
        XCTAssertEqual(url.host, "www.youtube.com")
    }
}
