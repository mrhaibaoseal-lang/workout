import XCTest
import CryptoKit
@testable import Workout

/// 第一次的問卷、加密雲端備份（0.43.0）。
final class OnboardingCloudTests: XCTestCase {
    // MARK: 恢復碼

    func testRecoveryCodeRoundTrip() throws {
        let secrets = CloudSecrets.generate()
        let text = RecoveryCode.encode(secrets)
        XCTAssertEqual(RecoveryCode.groups(secrets).count, 18)
        XCTAssertEqual(RecoveryCode.decode(text), secrets)
    }

    func testRecoveryCodeIgnoresCaseSpacesAndLookalikes() throws {
        let secrets = CloudSecrets.generate()
        let text = RecoveryCode.encode(secrets)
        // 小寫、換成空白、O／I／L 會被當成 0／1
        let sloppy = text.lowercased().replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "l")
        XCTAssertEqual(RecoveryCode.decode(sloppy), secrets)
    }

    func testRecoveryCodeDetectsTypo() throws {
        let secrets = CloudSecrets.generate()
        var chars = Array(RecoveryCode.encode(secrets))
        let i = chars.firstIndex { $0 != "-" } ?? 0
        chars[i] = chars[i] == "A" ? "B" : "A"
        XCTAssertNil(RecoveryCode.decode(String(chars)))
        XCTAssertNil(RecoveryCode.decode("太短了"))
        XCTAssertNil(RecoveryCode.decode(""))
    }

    func testBearerIsBase64URLOf43Chars() {
        let b = CloudSecrets.generate().bearer
        XCTAssertEqual(b.count, 43)
        XCTAssertNil(b.rangeOfCharacter(from: CharacterSet(charactersIn: "+/=")))
    }

    // MARK: 加密

    func testSealOpenRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plain = Data(String(repeating: "練壯 workout 備份 ", count: 500).utf8)
        let blob = try CloudCrypto.seal(plain, key: key)
        XCTAssertLessThan(blob.count, plain.count, "重複的文字壓縮後要變小")
        XCTAssertEqual(try CloudCrypto.open(blob, key: key), plain)
    }

    func testWrongKeyOrTamperedBlobFails() throws {
        let key = SymmetricKey(size: .bits256)
        let blob = try CloudCrypto.seal(Data("secret".utf8), key: key)
        XCTAssertThrowsError(try CloudCrypto.open(blob, key: SymmetricKey(size: .bits256)))
        var bad = blob
        bad[bad.count - 1] ^= 0xFF
        XCTAssertThrowsError(try CloudCrypto.open(bad, key: key))
        XCTAssertThrowsError(try CloudCrypto.open(Data([1, 2, 3]), key: key))
    }

    func testSameDataSealsDifferentlyEachTime() throws {
        let key = SymmetricKey(size: .bits256)
        let plain = Data("same".utf8)
        XCTAssertNotEqual(try CloudCrypto.seal(plain, key: key), try CloudCrypto.seal(plain, key: key))
    }

    // MARK: 程度評估：左右手

    func testOldLevelTestResultStillDecodes() throws {
        let raw = #"{"pushups":12,"gobletKg":10,"rowKg":8,"date":1,"bodyWeight":60}"#
        let r = try JSONDecoder().decode(LevelTest.Result.self, from: Data(raw.utf8))
        XCTAssertNil(r.rowLeftReps)
        XCTAssertNil(r.rowRightReps)
        XCTAssertNil(LevelTest.measuredWeakArm(r))
        // 舊資料沒記次數：照 10 下算
        let lifts = LevelTest.lifts(r, bodyWeight: 60)
        XCTAssertEqual(lifts["db_row"], Comeback.e1rm(weight: 8, reps: LevelTest.testReps, rir: LevelTest.testRIR))
    }

    func testRowGapOfTwoPicksWeakerArm() {
        var r = LevelTest.Result(pushups: nil, gobletKg: nil, rowKg: 10, date: 1)
        r.rowLeftReps = 8; r.rowRightReps = 11
        XCTAssertEqual(LevelTest.measuredWeakArm(r), .left)
        r.rowLeftReps = 12; r.rowRightReps = 10
        XCTAssertEqual(LevelTest.measuredWeakArm(r), .right)
        r.rowLeftReps = 10; r.rowRightReps = 11
        XCTAssertNil(LevelTest.measuredWeakArm(r), "只差 1 下不算")
    }

    func testRowStrengthUsesWeakerArm() {
        var r = LevelTest.Result(pushups: nil, gobletKg: nil, rowKg: 10, date: 1)
        r.rowLeftReps = 8; r.rowRightReps = 11
        XCTAssertEqual(LevelTest.lifts(r, bodyWeight: 60)["db_row"],
                       Comeback.e1rm(weight: 10, reps: 8, rir: LevelTest.testRIR))
    }

    func testLevelTestResultRoundTripKeepsRowReps() throws {
        var r = LevelTest.Result(pushups: 5, gobletKg: nil, rowKg: 9, date: 2)
        r.rowLeftReps = 7; r.rowRightReps = 9
        let back = try JSONDecoder().decode(LevelTest.Result.self, from: JSONEncoder().encode(r))
        XCTAssertEqual(back, r)
    }

    // MARK: 熱量

    func testCaloriesNeedSexAgeAndHeight() throws {
        // 男、70 kg、175 cm、25 歲：BMR 1673.75 × 1.55 ≈ 2594
        let c = try XCTUnwrap(Nutrition.calories(bodyWeight: 70, heightCm: 175, age: 25, sex: .male))
        XCTAssertEqual(c.maintenance, 2590)
        XCTAssertGreaterThan(c.target, c.maintenance)
        XCTAssertLessThan(c.surplus, 500)
        let f = try XCTUnwrap(Nutrition.calories(bodyWeight: 55, heightCm: 160, age: 25, sex: .female))
        XCTAssertLessThan(f.maintenance, c.maintenance)
        XCTAssertNil(Nutrition.calories(bodyWeight: 70, heightCm: 175, age: 25, sex: .undisclosed))
        XCTAssertNil(Nutrition.calories(bodyWeight: 70, heightCm: 175, age: nil, sex: .male))
        XCTAssertNil(Nutrition.calories(bodyWeight: 70, heightCm: 0, age: 25, sex: .male))
        XCTAssertNil(Nutrition.calories(bodyWeight: 70, heightCm: 175, age: 25, sex: nil))
    }

    func testAgeFromBirthYear() {
        let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027
        let year = Calendar.current.component(.year, from: now)
        XCTAssertEqual(UserProfile.age(birthYear: year - 30, now: now), 30)
        XCTAssertNil(UserProfile.age(birthYear: 0, now: now))
        XCTAssertNil(UserProfile.age(birthYear: year - 5, now: now))
    }

    // MARK: 問卷寫入規則

    func testWeekdaySuggestionMatchesDays() {
        for n in 2...6 {
            XCTAssertEqual(OnboardingFlow.suggestedWeekdays(days: n).count, n)
        }
    }

    func testDaysChooseProgram() {
        XCTAssertEqual(OnboardingFlow.program(forDays: 2), .fullBody3)
        XCTAssertEqual(OnboardingFlow.program(forDays: 3), .fullBody3)
        XCTAssertEqual(OnboardingFlow.program(forDays: 4), .split4)
        XCTAssertEqual(OnboardingFlow.program(forDays: 6), .split4)
    }

    func testOnlyOverTwoYearsStartsIntermediate() {
        XCTAssertTrue(TrainingExperience.overTwo.startsIntermediate)
        XCTAssertFalse(TrainingExperience.halfToTwo.startsIntermediate)
        XCTAssertFalse(TrainingExperience.none.startsIntermediate)
    }

    func testShortSessionsOnlyUnder30() {
        XCTAssertTrue(OnboardingFlow.SessionMinutes.under30.isShort)
        XCTAssertFalse(OnboardingFlow.SessionMinutes.between.isShort)
        XCTAssertFalse(OnboardingFlow.SessionMinutes.over60.isShort)
    }

    func testPainMarksLeaveOneUsableExercisePerPattern() {
        for joints in [Set([Joint.shoulder]), Set([Joint.knee, Joint.lowerBack]), Set(Joint.allCases)] {
            for equipment in [Set<Equipment>(), Set([Equipment.dumbbell, .bench]), Equipment.gym] {
                let marked = Set(OnboardingFlow.painExerciseIds(joints: joints, equipment: equipment))
                for pattern in MovementPattern.allCases {
                    guard let primary = Joint.of(pattern), joints.contains(primary) else { continue }
                    let all = ExerciseLibrary.builtIn.filter { $0.pattern == pattern }
                    let usable = all.filter { $0.requires.isSubset(of: equipment) }
                    guard !usable.isEmpty else { continue }
                    XCTAssertTrue(usable.contains { !marked.contains($0.id) },
                                  "\(pattern) 的動作不能全部被標掉")
                }
            }
        }
    }

    func testPainMarksOnlyTouchSelectedJoints() {
        let marked = OnboardingFlow.painExerciseIds(joints: [.knee], equipment: Equipment.gym)
        for id in marked {
            let ex = ExerciseLibrary.byId(id)
            XCTAssertEqual(ex.flatMap { Joint.of($0.pattern) }, .knee, "\(id) 的主要關節不是膝蓋")
        }
        XCTAssertTrue(OnboardingFlow.painExerciseIds(joints: [], equipment: Equipment.gym).isEmpty)
    }
}
