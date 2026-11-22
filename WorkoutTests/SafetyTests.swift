import XCTest
import SwiftData
@testable import Workout

/// 0.34.0：訓練中存檔、刪除紀錄收回、小工具連續週數、完整備份。
final class SafetyTests: XCTestCase {

    // MARK: 訓練中存檔

    func testSetDraftSnapshotRoundTrip() {
        var s = SetDraft(weight: 12.5, reps: 10, kind: .work, kit: "B", rir: 2, done: true, target: 12,
                         grade: .good, oneArm: true, otherReps: 9, otherRir: 1, eased: true)
        s.reps = 11
        let back = SetDraft(s.snapshot)
        XCTAssertEqual(back.snapshot, s.snapshot)
        XCTAssertEqual(back.kind, .work)
        XCTAssertEqual(back.grade, .good)
        XCTAssertEqual(back.reps, 11)
    }

    private func snap(done: Bool, savedAt: Date) -> WorkoutSnapshot {
        let set = SetDraft(weight: 10, reps: 10, done: done).snapshot
        return WorkoutSnapshot(dayId: "upperA", dayName: "上半身 A", length: "full",
                               startedAt: savedAt.timeIntervalSince1970 - 600, savedAt: savedAt.timeIntervalSince1970,
                               readiness: "3,3,3", sessionNote: "", combo: 0, bestCombo: 0, onTimeRests: 0,
                               scoredRests: 0,
                               exercises: [.init(exerciseId: "pushup", note: "", sets: [set])])
    }

    func testResumeOnlyWhenFreshAndSomethingDone() {
        let now = Date.now
        XCTAssertTrue(WorkoutResume.isFresh(snap(done: true, savedAt: now.addingTimeInterval(-3600)), now: now))
        XCTAssertFalse(WorkoutResume.isFresh(snap(done: false, savedAt: now), now: now))
        XCTAssertFalse(WorkoutResume.isFresh(snap(done: true, savedAt: now.addingTimeInterval(-13 * 3600)), now: now))
    }

    func testSnapshotCodable() throws {
        let s = snap(done: true, savedAt: .now)
        let data = try JSONEncoder().encode(s)
        XCTAssertEqual(try JSONDecoder().decode(WorkoutSnapshot.self, from: data), s)
    }

    // MARK: 刪除紀錄收回

    func testRevertOnlyTheGrantedUpgrade() {
        let current = ["pushup": "pause_pushup", "squat": "slow_squat"]
        XCTAssertEqual(SessionGrants.revertUpgrades(current, granted: ["pushup": "pause_pushup"]),
                       ["squat": "slow_squat"])
        // 之後又改過（不是這次記的）就不動
        XCTAssertEqual(SessionGrants.revertUpgrades(current, granted: ["squat": "other"]), current)
    }

    // MARK: 小工具連續週數

    func testWeekStreakCountsDaysNotSessions() {
        let cal = SharedStore.calendar
        let thisWeek = SharedStore.weekStart(.now)
        let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        let monday = cal.date(byAdding: .hour, value: 9, to: lastWeek)!
        // 上週只有一天、練兩次：不夠 2 天
        let twice = [monday, monday.addingTimeInterval(3600)]
        XCTAssertEqual(SharedStore.weekStreak(twice, now: cal.date(byAdding: .day, value: 1, to: thisWeek)!), 0)
        // 兩天就算
        let twoDays = [monday, cal.date(byAdding: .day, value: 2, to: monday)!]
        XCTAssertEqual(SharedStore.weekStreak(twoDays, now: cal.date(byAdding: .day, value: 1, to: thisWeek)!), 1)
    }

    // MARK: 完整備份

    @MainActor
    func testFullBackupRoundTrip() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetEntry.self, BodyLog.self, IntervalLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let s = WorkoutSession(date: date, dayKey: "upperA", length: .short, durationSeconds: 1200)
        s.note = "好累"
        ctx.insert(s)
        let e = SetEntry(exerciseId: "db_bench", setIndex: 0, weight: 12.5, reps: 10, date: date, rir: 2)
        e.eased = true
        e.side = "left"
        e.session = s
        ctx.insert(e)
        let b = BodyLog(date: date)
        b.weight = 70.5
        ctx.insert(b)
        try ctx.save()

        let data = try FullBackup.encode(FullBackup.make(context: ctx, now: date))
        let f = try FullBackup.decode(data)
        XCTAssertEqual(f.version, FullBackup.version)
        XCTAssertEqual(f.sessions.count, 1)
        XCTAssertEqual(f.sessions[0].note, "好累")
        XCTAssertEqual(f.sessions[0].mode, "short")
        XCTAssertEqual(f.sessions[0].entries.first?.weight, 12.5)
        XCTAssertEqual(f.sessions[0].entries.first?.eased, true)
        XCTAssertEqual(f.sessions[0].entries.first?.side, "left")
        XCTAssertEqual(f.bodies.first?.weight, 70.5)
        XCTAssertEqual(f.sessions[0].date, date)
    }

    func testBackupRejectsGarbageAndNewerVersion() throws {
        XCTAssertThrowsError(try FullBackup.decode(Data("not json".utf8)))
        let f = FullBackup.File(version: FullBackup.version + 1, exportedAt: .now, appVersion: "9.9",
                                sessions: [], bodies: [], intervals: [], defaults: Data())
        XCTAssertThrowsError(try FullBackup.decode(FullBackup.encode(f)))
    }
}
