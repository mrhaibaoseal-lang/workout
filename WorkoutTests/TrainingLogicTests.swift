import XCTest
import SwiftData
@testable import Workout

/// 排課、加重、破紀錄這些純邏輯的測試（0.30.0 起每次打包前在模擬器跑）。
final class TrainingLogicTests: XCTestCase {

    private func ex(_ id: String) -> Exercise {
        guard let e = ExerciseLibrary.byId(id) else { fatalError("missing \(id)") }
        return e
    }

    private func item(_ id: String, sets: Int = 3, low: Int = 8, high: Int = 12) -> PlannedExercise {
        PlannedExercise(exercise: ex(id), sets: sets, low: low, high: high, restSeconds: 90, essential: true)
    }

    private func entry(_ id: String, _ i: Int, _ w: Double, _ r: Int, rir: Int = -1, eased: Bool = false) -> SetEntry {
        let e = SetEntry(exerciseId: id, setIndex: i, weight: w, reps: r, date: .now, rir: rir)
        e.eased = eased
        return e
    }

    // MARK: 動作庫資料

    func testExerciseIdsUnique() {
        let ids = ExerciseLibrary.builtIn.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testReferencedIdsExist() {
        let all = Set(ExerciseLibrary.builtIn.map(\.id))
        for id in StartWeight.strength.keys { XCTAssertTrue(all.contains(id), "strength: \(id)") }
        for id in SideBalance.perSideIds.union(SideBalance.oneArmIds) { XCTAssertTrue(all.contains(id), "side: \(id)") }
        for id in WeightKits.singleDumbbell { XCTAssertTrue(all.contains(id), "single: \(id)") }
        for id in ExerciseLibrary.notMain { XCTAssertTrue(all.contains(id), "notMain: \(id)") }
    }

    func testEveryLoadedBuiltInHasStrength() {
        let missing = ExerciseLibrary.builtIn.filter { $0.loaded && StartWeight.strength[$0.id] == nil }.map(\.id)
        // 輔助引體向上機是「減輕的重量」，不推估
        XCTAssertEqual(missing, ["assisted_pullup"])
    }

    func testUpgradePathsStayInPattern() {
        for (from, to) in Upgrade.paths {
            XCTAssertEqual(ex(from).pattern, ex(to).pattern, "\(from) → \(to)")
            // 負重升負重、徒手升徒手（0.33.0 起徒手也有路線）
            XCTAssertEqual(ex(from).loaded, ex(to).loaded, "\(from) → \(to)")
        }
    }

    // MARK: 破紀錄

    func testFirstTimeIsNotPR() {
        XCTAssertFalse(PRRule.session(sets: [(weight: 10, reps: 10)], best: nil).pr)
    }

    func testWeightPR() {
        let best = PRBest(weight: 10, reps: 12)
        XCTAssertEqual(PRRule.check(weight: 12.5, reps: 6, best: best), .weight(old: 10))
        XCTAssertNil(PRRule.check(weight: 7.5, reps: 20, best: best))
    }

    func testRepPRAtTopWeight() {
        let best = PRBest(weight: 19.5, reps: 12)
        XCTAssertEqual(PRRule.check(weight: 19.5, reps: 13, best: best), .reps(old: 12))
        XCTAssertNil(PRRule.check(weight: 19.5, reps: 12, best: best))
        let r = PRRule.session(sets: [(weight: 19.5, reps: 13), (weight: 19.5, reps: 14)], best: best)
        XCTAssertTrue(r.pr)
        XCTAssertEqual(r.best, PRBest(weight: 19.5, reps: 14))
    }

    // MARK: 組數

    func testOnlyMainSlotGetsExtraSet() {
        let day = ProgramBuilder.splitDays[0]
        let sets = day.slots.map { ProgramBuilder.slotSets($0, day: day, phase: .normal, length: .full, extra: false) }
        XCTAssertEqual(sets[0], day.slots[0].sets + 1)
        XCTAssertEqual(sets[1], day.slots[1].sets)
    }

    func testDeloadHalvesSets() {
        let day = ProgramBuilder.splitDays[0]
        let main = ProgramBuilder.slotSets(day.slots[0], day: day, phase: .deload, length: .full, extra: false)
        XCTAssertEqual(main, 2)   // 4 → 2
        let iso = ProgramBuilder.slotSets(day.slots[5], day: day, phase: .deload, length: .full, extra: false)
        XCTAssertEqual(iso, 1)    // 2 → 1
    }

    // MARK: 加重建議

    func testAllHitAddsWeight() {
        let last = (0..<3).map { entry("db_bench", $0, 10, 12, rir: 1) }
        let s = Progression.suggest(item("db_bench"), last: last, phase: .normal,
                                    ladder: WeightLadder(loadings: [], step: 1), scheme: .straight)
        XCTAssertGreaterThan(s.weight, 10)
    }

    func testGrindingHoldsWeight() {
        let last = (0..<3).map { entry("db_bench", $0, 10, 12, rir: 0) }
        let s = Progression.suggest(item("db_bench"), last: last, phase: .normal,
                                    ladder: WeightLadder(loadings: [], step: 1), scheme: .straight)
        XCTAssertEqual(s.weight, 10)
    }

    func testMissedKeepsWeight() {
        let last = [entry("db_bench", 0, 10, 12), entry("db_bench", 1, 10, 10)]
        let s = Progression.suggest(item("db_bench"), last: last, phase: .normal,
                                    ladder: WeightLadder(loadings: [], step: 1), scheme: .straight)
        XCTAssertEqual(s.weight, 10)
        XCTAssertEqual(s.reps, 12)
    }

    func testDeloadIsNotBaseline() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let normal = WorkoutSession(date: .now.addingTimeInterval(-8 * 86400), dayKey: "upperA", length: .full, durationSeconds: 3600)
        normal.phase = Phase.normal.rawValue
        let deload = WorkoutSession(date: .now.addingTimeInterval(-1 * 86400), dayKey: "upperA", length: .full, durationSeconds: 1800)
        deload.phase = Phase.deload.rawValue
        ctx.insert(normal)
        ctx.insert(deload)
        for i in 0..<3 {
            let a = entry("db_bench", i, 12.5, 10); a.session = normal; ctx.insert(a)
        }
        let b = entry("db_bench", 0, 11, 8); b.session = deload; ctx.insert(b)
        try ctx.save()
        let last = Progression.lastSets(for: "db_bench", in: [deload, normal])
        XCTAssertEqual(last.map(\.weight).max(), 12.5)
    }

    func testEasedSetsAreNotBaseline() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let normal = WorkoutSession(date: .now.addingTimeInterval(-8 * 86400), dayKey: "upperA", length: .full, durationSeconds: 3600)
        normal.phase = Phase.normal.rawValue
        let eased = WorkoutSession(date: .now.addingTimeInterval(-1 * 86400), dayKey: "upperA", length: .full, durationSeconds: 3600)
        eased.phase = Phase.normal.rawValue
        ctx.insert(normal)
        ctx.insert(eased)
        let a = entry("db_bench", 0, 12.5, 10); a.session = normal; ctx.insert(a)
        let b = entry("db_bench", 0, 10, 10, eased: true); b.session = eased; ctx.insert(b)
        try ctx.save()
        XCTAssertEqual(Progression.lastSets(for: "db_bench", in: [eased, normal]).first?.weight, 12.5)
    }

    // MARK: 還剩幾下

    func testRIRHint() {
        XCTAssertNotNil(RIRCheck.hint(prevReps: 12, prevRir: 3, prevWeight: 10, curReps: 8, curWeight: 10))
        XCTAssertNil(RIRCheck.hint(prevReps: 12, prevRir: 1, prevWeight: 10, curReps: 8, curWeight: 10))
        XCTAssertNil(RIRCheck.hint(prevReps: 12, prevRir: 3, prevWeight: 10, curReps: 11, curWeight: 10))
    }

    // MARK: 主項不排單腳

    func testMainHingeAvoidsSingleLeg() {
        let slot = Slot(pattern: .hinge, sets: 3, low: 6, high: 10, essential: true)
        let top = ProgramBuilder.topChoices(slot: slot, equipment: [.dumbbell, .bench, .barbell], limitBarbell: true)
        XCTAssertFalse(top.contains { ExerciseLibrary.notMain.contains($0.id) })
    }
}
