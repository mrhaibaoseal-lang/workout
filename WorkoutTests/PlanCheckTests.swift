import XCTest
@testable import Workout

/// 排課檢查（0.40.0）：每條規則的門檻、排序與數量上限。
final class PlanCheckTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func ex(_ id: String) -> Exercise {
        guard let e = ExerciseLibrary.byId(id) else { fatalError("missing \(id)") }
        return e
    }

    private func item(_ id: String, sets: Int = 3, essential: Bool = true) -> PlannedExercise {
        PlannedExercise(exercise: ex(id), sets: sets, low: 8, high: 12, restSeconds: 90, essential: essential)
    }

    private var upperA: DayTemplate {
        ProgramBuilder.splitDays.first { $0.id == "upperA" }!
    }

    private let home: Set<Equipment> = [.dumbbell, .bench]

    private func run(_ plan: [PlannedExercise], length: WorkoutLength = .full, phase: Phase = .normal,
                     minutes: Int = 40, equipment: Set<Equipment>? = nil,
                     feedback: [MuscleFeedback] = [], painLog: [PainRecord] = []) -> [PlanFinding] {
        PlanCheck.run(plan: plan, day: upperA, length: length, phase: phase, sessions: [], minutes: minutes,
                      equipment: equipment ?? home, now: now, feedback: feedback, painLog: painLog, marked: [:])
    }

    private func finding(_ list: [PlanFinding], _ c: PlanFinding.Category) -> PlanFinding? {
        list.first { $0.category == c }
    }

    func testNoProblemsReturnsEmpty() {
        XCTAssertEqual(run([item("db_bench"), item("db_row")]), [])
    }

    func testTimeOverLimit() {
        let plan = [item("db_bench")]
        // 完整版目標 60 分，75 分以內不提醒
        XCTAssertNil(finding(run(plan, minutes: 75), .time))
        let f = finding(run(plan, minutes: 80), .time)
        XCTAssertEqual(f?.level, .warn)
        XCTAssertTrue(f?.detail.contains("80") ?? false)
        // 精簡版目標 20 分：26 分就超過
        XCTAssertNotNil(finding(run(plan, length: .short, minutes: 26), .time))
        // 只做 1 組不檢查
        XCTAssertEqual(run(plan, length: .minimal, minutes: 200), [])
    }

    func testDailyMuscleSetsOverTen() {
        // 胸：4 + 4 + 3 = 11 組
        let many = [item("db_bench", sets: 4), item("db_floor_press", sets: 4), item("db_incline_press", sets: 3)]
        let f = finding(run(many), .volume)
        XCTAssertEqual(f?.level, .tip)
        XCTAssertTrue(f?.detail.contains("11") ?? false)
        // 剛好 10 組不算
        let ten = [item("db_bench", sets: 4), item("db_floor_press", sets: 3), item("db_incline_press", sets: 3)]
        XCTAssertNil(finding(run(ten), .volume))
    }

    func testRepeatedPattern() {
        let f = finding(run([item("db_bench"), item("db_floor_press")]), .pattern)
        XCTAssertEqual(f?.level, .tip)
        XCTAssertNil(finding(run([item("db_bench"), item("db_row")]), .pattern))
    }

    func testEquipmentMismatch() {
        let f = finding(run([item("bb_bench"), item("db_row")]), .equipment)
        XCTAssertEqual(f?.level, .warn)
        XCTAssertNil(finding(run([item("db_bench")]), .equipment))
    }

    func testDeloadSetsNotReduced() {
        // 上半身 A 的水平推：完整版正常 4 組，減量週應該是 2 組
        XCTAssertNotNil(finding(run([item("db_bench", sets: 4)], phase: .deload), .deload))
        XCTAssertNil(finding(run([item("db_bench", sets: 2)], phase: .deload), .deload))
        // 不是減量週不檢查
        XCTAssertNil(finding(run([item("db_bench", sets: 4)], phase: .normal), .deload))
    }

    func testRecoveryConflictFromSoreFeedback() {
        let sore = MuscleFeedback(muscle: Muscle.chest.rawValue, date: now.addingTimeInterval(-24 * 3600).timeIntervalSince1970,
                                  recovery: Recovery.sore.rawValue, joint: false)
        let f = finding(run([item("db_bench")], feedback: [sore]), .recovery)
        XCTAssertEqual(f?.level, .warn)
        // 超過胸的恢復時間（60 小時）的回報不算
        let old = MuscleFeedback(muscle: Muscle.chest.rawValue, date: now.addingTimeInterval(-72 * 3600).timeIntervalSince1970,
                                 recovery: Recovery.sore.rawValue, joint: false)
        XCTAssertNil(finding(run([item("db_bench")], feedback: [old]), .recovery))
        // 不是重點動作不算
        XCTAssertNil(finding(run([item("db_bench", essential: false)], feedback: [sore]), .recovery))
    }

    func testPainfulExerciseStillPlanned() {
        let pain = PainRecord(exerciseId: "db_bench", date: now.addingTimeInterval(-2 * 86400).timeIntervalSince1970)
        let f = finding(run([item("db_bench")], painLog: [pain]), .joint)
        XCTAssertEqual(f?.level, .warn)
        // 超過 14 天就不算
        let old = PainRecord(exerciseId: "db_bench", date: now.addingTimeInterval(-20 * 86400).timeIntervalSince1970)
        XCTAssertNil(finding(run([item("db_bench")], painLog: [old]), .joint))
    }

    func testOrderingAndLimits() {
        var all: [PlanFinding] = []
        for i in 0..<4 { all.append(PlanFinding(level: .tip, category: .pattern, title: "t\(i)", detail: "d")) }
        for i in 0..<4 { all.append(PlanFinding(level: .tip, category: .volume, title: "v\(i)", detail: "d")) }
        for i in 0..<4 { all.append(PlanFinding(level: .tip, category: .week, title: "w\(i)", detail: "d")) }
        all.append(PlanFinding(level: .warn, category: .time, title: "time", detail: "d"))
        let out = PlanCheck.finalize(all)
        XCTAssertEqual(out.count, 5)
        XCTAssertEqual(out.first?.level, .warn)
        for c in [PlanFinding.Category.pattern, .volume, .week] {
            XCTAssertLessThanOrEqual(out.filter { $0.category == c }.count, 2)
        }
        // 注意都排在建議前面
        let firstTip = out.firstIndex { $0.level == .tip } ?? out.count
        XCTAssertFalse(out[firstTip...].contains { $0.level == .warn })
    }
}
