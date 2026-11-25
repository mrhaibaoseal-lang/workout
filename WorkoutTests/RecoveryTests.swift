import XCTest
import SwiftData
@testable import Workout

/// 0.51.0：各部位恢復時間、今天自動挑最恢復的那天。
final class RecoveryTests: XCTestCase {

    func testTypicalSessionRecoversAtMuscleHours() {
        for m in Muscle.allCases {
            XCTAssertEqual(MuscleStats.hoursUntilRecovered(m, fatigue: 6), m.recoveryHours, accuracy: 0.01)
        }
        XCTAssertEqual(MuscleStats.hoursUntilRecovered(.quads, fatigue: 1), 0)
    }

    func testLegsRecoverSlowerThanChest() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let now = Date.now
        let then = now.addingTimeInterval(-50 * 3600)
        let s = WorkoutSession(date: then, dayKey: "upperA", length: .full, durationSeconds: 3600)
        ctx.insert(s)
        for (i, id) in (Array(repeating: "db_bench", count: 6) + Array(repeating: "bb_squat", count: 6)).enumerated() {
            let e = SetEntry(exerciseId: id, setIndex: i, weight: 20, reps: 10, date: then, rir: 2)
            e.session = s
            ctx.insert(e)
        }
        let rec = MuscleStats.recovery([s], now: now)
        XCTAssertGreaterThanOrEqual(rec[.chest] ?? 0, MuscleStats.recoveredLevel)
        XCTAssertLessThan(rec[.quads] ?? 1, MuscleStats.recoveredLevel)
        XCTAssertEqual(rec[.calves] ?? 0, 1, accuracy: 0.0001)
    }
}
