import XCTest
@testable import Workout

/// 內建「上半身為主 4 天」（0.55.0）：頻率、B 日不練胸、單日同部位組數、腿只維持、舊紀錄找得回。
final class UpperProgramTests: XCTestCase {

    private var days: [DayTemplate] { ProgramBuilder.upperDays }

    private func day(_ id: String) -> DayTemplate { days.first { $0.id == id }! }

    /// 完整版進步期每格的正式組數（主項 +1）
    private func sets(_ d: DayTemplate) -> [Int] {
        d.slots.map { ProgramBuilder.slotSets($0, day: d, phase: .normal, length: .full, extra: false) }
    }

    /// 一天每個部位的組數：主要出力 1 組、次要出力算半組
    private func muscleSets(_ d: DayTemplate, sets counts: [Int]? = nil) -> [Muscle: Double] {
        let counts = counts ?? sets(d)
        return VolumePlan.weekly(slots: zip(d.slots, counts).map { (pattern: $0.pattern, sets: $1) })
    }

    /// 這週有幾天主要練到這個部位
    private func frequency(_ m: Muscle) -> Int {
        days.filter { d in d.slots.contains { VolumePlan.primaryMuscles($0.pattern).contains(m) } }.count
    }

    func testFourDaysInSuggestedOrder() {
        XCTAssertEqual(days.map(\.id), ["u4A", "u4B", "u4L", "u4C"])
        XCTAssertEqual(BuiltInProgram.upper4.goal, 4)
        XCTAssertEqual(BuiltInProgram.upper4.days.map(\.id), days.map(\.id))
    }

    func testWeeklyFrequency() {
        XCTAssertEqual(frequency(.chest), 2)
        XCTAssertEqual(frequency(.lats), 3)
        XCTAssertEqual(frequency(.quads), 1)
        XCTAssertEqual(frequency(.glutes), 1)
        XCTAssertEqual(frequency(.hamstrings), 1)
        XCTAssertEqual(frequency(.abs), 2)
        XCTAssertEqual(frequency(.sideDelt), 3)
        XCTAssertEqual(frequency(.biceps), 3)
    }

    func testDayBHasNoChest() {
        let b = day("u4B")
        XCTAssertFalse(b.slots.contains { VolumePlan.primaryMuscles($0.pattern).contains(.chest) })
        XCTAssertNil(muscleSets(b)[.chest])
    }

    func testDailyMuscleSetsAtMostTen() {
        for d in days {
            for (m, v) in muscleSets(d) {
                XCTAssertLessThanOrEqual(v, 10, "\(d.id) \(m): \(v)")
            }
        }
    }

    func testUpperDaysTotalSets() {
        for id in ["u4A", "u4B", "u4C"] {
            let total = sets(day(id)).reduce(0, +)
            XCTAssertTrue((20...24).contains(total), "\(id): \(total)")
        }
    }

    func testWeeklyUpperVolumeInRange() {
        let weekly = VolumePlan.weekly(slots: days.flatMap { d in
            zip(d.slots, sets(d)).map { (pattern: $0.pattern, sets: $1) }
        })
        for m in [Muscle.chest, .lats, .sideDelt, .biceps, .triceps] {
            XCTAssertTrue((10...16).contains(weekly[m] ?? 0), "\(m): \(weekly[m] ?? 0)")
        }
    }

    /// 腿只求維持：平衡不把腿補到 10 組；不帶 maintain（舊課表的算法）才會補小腿。
    func testBalanceKeepsLegsAtMaintenance() {
        let inputs = days.map { d in
            VolumePlan.DayInput(patterns: d.slots.map(\.pattern), sets: sets(d), lost: [])
        }
        let before = inputs.map(\.sets)
        let maintained = VolumePlan.balance(days: inputs, phase: .normal,
                                            personal: [.quads: 2, .calves: 2],
                                            maintain: BuiltInProgram.upper4.maintained)
        let legDay = days.firstIndex { $0.id == "u4L" }!
        XCTAssertEqual(maintained[legDay], before[legDay], "腿日的腿不加組")
        for (i, d) in days.enumerated() {
            for (m, v) in muscleSets(d, sets: maintained[i]) {
                XCTAssertLessThanOrEqual(v, 10, "平衡後 \(d.id) \(m): \(v)")
            }
        }
        let plain = VolumePlan.balance(days: inputs, phase: .normal)
        XCTAssertGreaterThan(plain[legDay].reduce(0, +), before[legDay].reduce(0, +), "一般目標會補腿")
    }

    func testMaintainedOnlyForUpper4() {
        XCTAssertEqual(BuiltInProgram.upper4.maintained, VolumePlan.legMuscles)
        XCTAssertTrue(BuiltInProgram.split4.maintained.isEmpty)
        XCTAssertTrue(BuiltInProgram.fullBody3.maintained.isEmpty)
        XCTAssertEqual(VolumePlan.range(for: .quads, maintain: VolumePlan.legMuscles)?.lowerBound, VolumePlan.maintainLow)
        XCTAssertEqual(VolumePlan.range(for: .quads, maintain: []), VolumePlan.range(for: .quads))
        XCTAssertEqual(VolumePlan.range(for: .chest, maintain: VolumePlan.legMuscles), VolumePlan.range(for: .chest))
    }

    func testOldRecordsFindNewDays() {
        for d in days {
            XCTAssertEqual(ProgramBuilder.template(id: d.id)?.name, d.name)
        }
        let all = (ProgramBuilder.splitDays + ProgramBuilder.fullBodyDays + ProgramBuilder.upperDays).map(\.id)
        XCTAssertEqual(all.count, Set(all).count, "三份內建課表的 day id 不重複")
        let merged = WeekFit.merged([day("u4A"), day("u4B")])
        XCTAssertNotNil(ProgramBuilder.template(id: merged.id))
        let patterns = merged.slots.map(\.pattern)
        XCTAssertEqual(patterns.count, Set(patterns).count)
    }

    func testHalvesForGoals() {
        XCTAssertTrue(day("u4A").halves == (true, false))
        XCTAssertTrue(day("u4C").halves.upper)
        XCTAssertFalse(day("u4C").halves.lower)
        XCTAssertTrue(day("u4L").halves == (true, true))
    }

    /// 同一個動作類型在兩天出現，後面那天用下一順位的動作。
    func testLaterDayUsesSecondChoice() {
        let eq = Set(Equipment.allCases)
        func pick(_ id: String, _ p: MovementPattern) -> String? {
            ProgramBuilder.rawPlan(day: day(id), equipment: eq, week: 3, length: .full, limitBarbell: false)
                .items.first { $0.exercise.pattern == p }?.exercise.id
        }
        XCTAssertNotNil(pick("u4A", .hPush))
        XCTAssertNotEqual(pick("u4A", .hPush), pick("u4C", .hPush))
        XCTAssertNotEqual(pick("u4A", .hPull), pick("u4C", .hPull))
        XCTAssertNotEqual(pick("u4B", .vPull), pick("u4C", .vPull))
    }

    func testIntensityAndSpecialization() {
        XCTAssertEqual(Graduation.intensity(dayId: "u4A"), .heavy)
        XCTAssertEqual(Graduation.intensity(dayId: "u4C"), .light)
        for id in ["u4A", "u4L", "u4C"] {
            XCTAssertFalse(Specialization.extraSlots(dayId: id).isEmpty, id)
        }
        // 專項期加動作不加胸、背、腿
        let extra = ["u4A", "u4B", "u4L", "u4C"].flatMap { Specialization.extraSlots(dayId: $0) }
        XCTAssertTrue(extra.allSatisfy { $0.pattern.region == nil })
    }
}
