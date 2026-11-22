import XCTest
@testable import Workout

/// 「會痛…」選關節、同關節提醒（0.32.0）。
final class PainJointTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func record(_ id: String, daysAgo: Double, joint: Joint?) -> PainRecord {
        PainRecord(exerciseId: id, date: now.timeIntervalSince1970 - daysAgo * 86400, joint: joint?.rawValue)
    }

    func testOldRecordWithoutJointStillDecodes() throws {
        let raw = #"[{"exerciseId":"db_bench","date":1}]"#
        let list = try JSONDecoder().decode([PainRecord].self, from: Data(raw.utf8))
        XCTAssertEqual(list.first?.joint, nil)
    }

    func testChosenJointOverridesPatternGuess() {
        // 臥推（推類，推測是肩膀），但使用者說是手肘痛
        let pain = Joint.recentPain(now: now, log: [record("db_bench", daysAgo: 1, joint: .elbow)], marked: [:])
        XCTAssertEqual(pain[.elbow], "啞鈴臥推")
        XCTAssertNil(pain[.shoulder])
    }

    func testRecordWithoutJointFallsBackToPattern() {
        let pain = Joint.recentPain(now: now, log: [record("db_bench", daysAgo: 1, joint: nil)], marked: [:])
        XCTAssertEqual(pain[.shoulder], "啞鈴臥推")
    }

    func testOldRecordsAreIgnored() {
        let pain = Joint.recentPain(now: now, log: [record("db_bench", daysAgo: 20, joint: .elbow)], marked: [:])
        XCTAssertTrue(pain.isEmpty)
    }

    func testMarkedEntryWithLogIsNotGuessedAgain() {
        let log = [record("db_bench", daysAgo: 1, joint: .elbow)]
        let marked = ["db_bench": AvoidEntry(reason: AvoidReason.pain.rawValue, date: now.timeIntervalSince1970 - 86400)]
        let pain = Joint.recentPain(now: now, log: log, marked: marked)
        XCTAssertNil(pain[.shoulder], "已經有選關節的紀錄，不要再用推測的肩膀")
    }

    func testCautionUsesAnyInvolvedJoint() {
        let squat = ExerciseLibrary.byId("goblet_squat")!
        // 髖部痛：深蹲也會用到髖部
        XCTAssertNotNil(Joint.caution(for: squat, pain: [.hip: "臀推"]))
        XCTAssertNil(Joint.caution(for: squat, pain: [.elbow: "臥推"]))
        // 痛的就是這個動作本身，不重複提醒
        XCTAssertNil(Joint.caution(for: squat, pain: [.knee: squat.name]))
    }

    func testMenuListsEveryJointOnceWithLikelyFirst() {
        let order = Joint.menuOrder(for: .squat)
        XCTAssertEqual(order.first, .knee)
        XCTAssertEqual(Set(order), Set(Joint.allCases))
        XCTAssertEqual(order.count, Joint.allCases.count)
    }
}
