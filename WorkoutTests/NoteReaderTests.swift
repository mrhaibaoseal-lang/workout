import XCTest
@testable import Workout

/// 看懂備註（0.37.0）：規則版、驗證、下次調整、存放。
final class NoteReaderTests: XCTestCase {
    private let bench = NoteInput.Item(id: "db_bench", name: "啞鈴臥推", loaded: true, limb: .arm)
    private let squat = NoteInput.Item(id: "goblet_squat", name: "高腳杯深蹲", loaded: true, limb: .leg)
    private let pushup = NoteInput.Item(id: "pushup", name: "伏地挺身", loaded: false, limb: .arm)

    private func read(_ notes: [String: String] = [:], session: String = "", items: [NoteInput.Item]? = nil,
                      weak: @escaping (Limb) -> WeakSide = { _ in .none }) -> [NoteFinding] {
        NoteReader.rules(NoteInput(items: items ?? [bench, squat, pushup], notes: notes, sessionNote: session),
                         currentWeak: weak)
    }

    private func kinds(_ f: [NoteFinding]) -> [NoteKind] { f.map(\.kind) }

    // MARK: 否定

    func testNegatedPhrasesAreIgnored() {
        for text in ["不痛", "沒痛", "沒有痛", "不會痛", "今天不重", "不輕", "不會太重", "一點都不會不舒服"] {
            XCTAssertEqual(read(["db_bench": text]), [], "「\(text)」不該列出任何一筆")
        }
    }

    func testSorenessIsNotPain() {
        for text in ["肌肉痠痛", "手臂有點酸痛", "昨天練的肩膀還在痠痛"] {
            XCTAssertEqual(read(["db_bench": text]), [], "「\(text)」是練完的痠，不是會痛")
        }
        // 痠痛之外真的有痛，還是要抓到
        XCTAssertEqual(read(["db_bench": "肩膀痠痛，手肘刺痛"]),
                       [NoteFinding(kind: .pain, exerciseId: "db_bench", joint: .elbow)])
    }

    func testNegationOnlyRemovesItsOwnPhrase() {
        // 「肩膀不痛」是否定，後面的「太輕」還是要抓到
        let f = read(["db_bench": "肩膀不痛，但是太輕"])
        XCTAssertEqual(kinds(f), [.tooLight])
    }

    // MARK: 四種情況

    func testPainWithJoint() {
        let f = read(["db_bench": "左肩有點刺痛"])
        XCTAssertEqual(f, [NoteFinding(kind: .pain, exerciseId: "db_bench", joint: .shoulder)])
    }

    func testPainWithoutJointIsNil() {
        let f = read(["db_bench": "做完不舒服"])
        XCTAssertEqual(f, [NoteFinding(kind: .pain, exerciseId: "db_bench", joint: nil)])
    }

    func testPainPicksJointNearestToPainWord() {
        let f = read(["goblet_squat": "肩膀還好，膝蓋卡卡的"])
        XCTAssertEqual(f.first?.joint, .knee)
    }

    func testTooLightAndTooHeavy() {
        XCTAssertEqual(kinds(read(["db_bench": "太輕了"])), [.tooLight])
        XCTAssertEqual(kinds(read(["db_bench": "最後一組撐不住"])), [.tooHeavy])
    }

    func testTooLightOrHeavyNeverForBodyweight() {
        XCTAssertEqual(read(["pushup": "太輕了"]), [])
        XCTAssertEqual(read(["pushup": "太重"]), [])
    }

    func testSideWeakWithLimbWord() {
        let f = read(["db_bench": "左手先抖"])
        XCTAssertEqual(f, [NoteFinding(kind: .sideWeak, exerciseId: "db_bench", limb: .arm, side: .left)])
    }

    func testGearUsesFirst20Characters() {
        let text = "椅子會晃，要換一張穩一點的，不然每次做到最後一組都會怕"
        let f = read(["db_bench": text])
        XCTAssertEqual(kinds(f), [.gear])
        XCTAssertEqual(f.first?.summary, String(text.prefix(20)))
    }

    // MARK: 一句話多種情況

    func testSeveralKindsInOneNote() {
        let f = read(["db_bench": "左肩有點痛，重量太輕"])
        XCTAssertEqual(kinds(f), [.pain, .tooLight])
        XCTAssertEqual(f.first?.joint, .shoulder)
    }

    func testPainAndGearAndSideInOneNote() {
        let f = read(["db_bench": "椅子會晃，右手比較弱，手肘痛"])
        XCTAssertEqual(Set(kinds(f)), [.pain, .sideWeak, .gear])
    }

    // MARK: 太輕和太重

    func testTooLightAndTooHeavyTogetherListsNeither() {
        XCTAssertEqual(read(["db_bench": "前面太輕，後面太重"]), [])
    }

    func testConflictAcrossExerciseNoteAndSessionNote() {
        let f = read(["db_bench": "太輕"], session: "啞鈴臥推最後撐不住")
        XCTAssertEqual(f, [], "兩個備註一個太輕一個太重，也是都不列")
    }

    func testConflictOnlyAffectsThatExercise() {
        let f = read(["db_bench": "前面太輕，後面太重", "goblet_squat": "太輕"])
        XCTAssertEqual(f, [NoteFinding(kind: .tooLight, exerciseId: "goblet_squat")])
    }

    // MARK: 左右差

    func testSideWeakLimbInferredFromExerciseWhenNotWritten() {
        let arm = read(["db_bench": "右邊比較弱"])
        XCTAssertEqual(arm, [NoteFinding(kind: .sideWeak, exerciseId: "db_bench", limb: .arm, side: .right)])
        let leg = read(["goblet_squat": "左邊先沒力"])
        XCTAssertEqual(leg, [NoteFinding(kind: .sideWeak, exerciseId: "goblet_squat", limb: .leg, side: .left)])
    }

    func testLimbWordBeatsExerciseGuess() {
        // 深蹲的備註但寫「左手」→ 看字面
        let f = read(["goblet_squat": "左手抱著先抖"])
        XCTAssertEqual(f.first?.limb, .arm)
    }

    func testSessionNoteWithoutExerciseNeedsLimbWord() {
        let withLimb = read(session: "今天左手先抖")
        XCTAssertEqual(withLimb, [NoteFinding(kind: .sideWeak, exerciseId: nil, limb: .arm, side: .left)])
        XCTAssertEqual(read(session: "今天左邊先抖"), [], "沒寫部位、整次備註也沒有動作可推")
    }

    func testSessionNoteNamingExerciseGivesLimbAndExercise() {
        let f = read(session: "高腳杯深蹲右邊先沒力")
        XCTAssertEqual(f, [NoteFinding(kind: .sideWeak, exerciseId: "goblet_squat", limb: .leg, side: .right)])
    }

    func testAlreadyWeakOnThatSideIsNotListed() {
        XCTAssertEqual(read(["db_bench": "左手先抖"], weak: { $0 == .arm ? .left : .none }), [])
        // 設的是另一邊就還是要列
        XCTAssertEqual(kinds(read(["db_bench": "左手先抖"], weak: { $0 == .arm ? .right : .none })), [.sideWeak])
        // 腳設成同一邊不影響手
        XCTAssertEqual(kinds(read(["db_bench": "左手先抖"], weak: { $0 == .leg ? .left : .none })), [.sideWeak])
    }

    func testBothSidesTogetherAreNotCountedAsASide() {
        XCTAssertEqual(read(["db_bench": "左右兩邊都很穩，不會抖"]), [])
        XCTAssertEqual(read(["db_bench": "左右差不多"]), [])
    }

    func testBothSidesWeakIsAmbiguous() {
        XCTAssertEqual(read(["db_bench": "左手先抖，右手也很弱"]), [])
    }

    func testSideWeakWindowIsSixCharacters() {
        XCTAssertEqual(kinds(read(["db_bench": "右手今天感覺弱"])), [.sideWeak], "「弱」在右後面第 6 個字")
        XCTAssertEqual(read(["db_bench": "右手今天感覺好像真的有點弱"]), [], "超過 6 個字就不算")
    }

    func testCantDoItOnOneSideIsSideWeakNotTooHeavy() {
        let f = read(["db_bench": "左手做不動"])
        XCTAssertEqual(kinds(f), [.sideWeak])
    }

    // MARK: 整次備註

    func testSessionNoteOnlyCountsExerciseItNames() {
        let f = read(session: "今天啞鈴臥推左肩痛，體力普通")
        XCTAssertEqual(f, [NoteFinding(kind: .pain, exerciseId: "db_bench", joint: .shoulder)])
        // 沒提到動作名字：痛、太重都不能綁到動作
        XCTAssertEqual(read(session: "今天肩膀痛，整體太重"), [])
    }

    func testSameExerciseSameKindKeepsOne() {
        let f = read(["db_bench": "肩膀痛"], session: "啞鈴臥推的時候手肘也痛")
        XCTAssertEqual(f.filter { $0.kind == .pain }.count, 1)
    }

    func testNotesForExercisesNotDoneAreIgnored() {
        XCTAssertEqual(read(["unknown_ex": "肩膀痛"]), [])
    }

    func testResultsFollowTrainingOrder() {
        let f = read(["goblet_squat": "膝蓋痛", "db_bench": "太輕"])
        XCTAssertEqual(f.map(\.exerciseId), ["db_bench", "goblet_squat"])
    }

    // MARK: AI 回傳的驗證

    func testConvertDropsInvalidFindingsOnly() {
        let input = NoteInput(items: [bench, squat], notes: ["db_bench": "x"], sessionNote: "")
        let raws: [NoteReader.Raw] = [
            .init(kind: "pain", exerciseId: "db_bench", joint: "shoulder"),
            .init(kind: "pain", exerciseId: "not_today", joint: "knee"),                 // 不在今天清單
            .init(kind: "pain", exerciseId: "db_bench", joint: "neck"),                  // 沒有這個關節
            .init(kind: "banana", exerciseId: "db_bench"),                               // 沒有這個 kind
            .init(kind: "gear", exerciseId: "db_bench", summary: "椅子会晃"),             // 簡體字
            .init(kind: "gear", exerciseId: "db_bench", summary: "椅子會晃得很厲害握把也有點鬆掉要重新鎖緊才行"), // 超過 20 字
            .init(kind: "gear", exerciseId: "goblet_squat", summary: "椅子會晃"),
            .init(kind: "sideWeak", limb: "arm", side: "left"),
            .init(kind: "sideWeak", limb: "arm", side: "none"),                          // 不是左右
            .init(kind: "tooLight", exerciseId: ""),                                    // 沒有動作
        ]
        let f = NoteReader.convert(raws, input: input)
        XCTAssertEqual(f, [
            NoteFinding(kind: .pain, exerciseId: "db_bench", joint: .shoulder),
            NoteFinding(kind: .gear, exerciseId: "goblet_squat", summary: "椅子會晃"),
            NoteFinding(kind: .sideWeak, exerciseId: nil, limb: .arm, side: .left),
        ])
    }

    func testFinalizeAppliesSameRulesToAIResults() {
        let input = NoteInput(items: [bench, pushup], notes: [:], sessionNote: "")
        let list = [
            NoteFinding(kind: .tooLight, exerciseId: "db_bench"),
            NoteFinding(kind: .tooHeavy, exerciseId: "db_bench"),   // 衝突，兩個都不列
            NoteFinding(kind: .tooLight, exerciseId: "pushup"),     // 徒手
            NoteFinding(kind: .sideWeak, limb: .arm, side: .left),  // 已經設成左邊弱
            NoteFinding(kind: .pain, exerciseId: "db_bench"),
            NoteFinding(kind: .pain, exerciseId: "db_bench"),       // 重複
        ]
        let f = NoteReader.finalize(list, input: input, currentWeak: { $0 == .arm ? .left : .none })
        XCTAssertEqual(f, [NoteFinding(kind: .pain, exerciseId: "db_bench")])
    }

    // MARK: 下次調整

    private func sets(_ weights: [Double]) -> [SetDraft] {
        weights.map { SetDraft(weight: $0, reps: 10) }
    }

    private func ladder() -> WeightLadder {
        WeightLadder(loadings: [10, 12.5, 15, 17.5, 20].map { Loading(weight: $0, kit: "Tixteel", plates: [], use: .pair) },
                     step: 2.5)
    }

    private let base = Suggestion(weight: 17.5, reps: 10, note: "維持 17.5 kg")

    func testEaseSetsEasedAndSnapsToLadder() {
        var s = sets([17.5, 17.5])
        let out = NoteNudges.apply(.ease, to: &s, suggestion: base, ladder: ladder(), loaded: true)
        XCTAssertEqual(s.map(\.weight), [12.5, 12.5], "17.5 × 0.8 = 14，階梯上不超過的是 12.5")
        XCTAssertTrue(s.allSatisfy(\.eased))
        XCTAssertEqual(out.weight, 12.5)
        XCTAssertTrue(out.note.hasPrefix("上次備註說會痛：先減輕約兩成。"))
        XCTAssertTrue(out.note.hasSuffix("維持 17.5 kg"))
    }

    func testUpAndDownMoveOneStepAndDoNotMarkEased() {
        var up = sets([15, 15])
        let a = NoteNudges.apply(.up, to: &up, suggestion: Suggestion(weight: 15, reps: 10, note: "x"),
                                 ladder: ladder(), loaded: true)
        XCTAssertEqual(up.map(\.weight), [17.5, 17.5])
        XCTAssertFalse(up.contains(where: \.eased))
        XCTAssertTrue(a.note.hasPrefix("上次備註說太輕：多加一級。"))

        var down = sets([15])
        let b = NoteNudges.apply(.down, to: &down, suggestion: Suggestion(weight: 15, reps: 10, note: "x"),
                                 ladder: ladder(), loaded: true)
        XCTAssertEqual(down.map(\.weight), [12.5])
        XCTAssertTrue(b.note.hasPrefix("上次備註說太重：少一級。"))
    }

    func testUpAtHeaviestKeepsWeightAndSaysSo() {
        var s = sets([20, 20])
        let out = NoteNudges.apply(.up, to: &s, suggestion: Suggestion(weight: 20, reps: 10, note: "x"),
                                   ladder: ladder(), loaded: true)
        XCTAssertEqual(s.map(\.weight), [20, 20])
        XCTAssertTrue(out.note.hasPrefix("上次備註說太輕，但已經是器材最重了。"))
    }

    func testWarmupSetsAreNotTouched() {
        var s = [SetDraft(weight: 10, reps: 10, kind: .warmup), SetDraft(weight: 17.5, reps: 10)]
        _ = NoteNudges.apply(.down, to: &s, suggestion: base, ladder: ladder(), loaded: true)
        XCTAssertEqual(s.map(\.weight), [10, 15])
    }

    func testBodyweightOrZeroWeightIsNotNudged() {
        var s = sets([0, 0])
        let out = NoteNudges.apply(.up, to: &s, suggestion: Suggestion(weight: 0, reps: 10, note: "x"),
                                   ladder: ladder(), loaded: true)
        XCTAssertEqual(out.note, "x")
        var s2 = sets([15])
        let out2 = NoteNudges.apply(.down, to: &s2, suggestion: Suggestion(weight: 0, reps: 10, note: "y"),
                                    ladder: ladder(), loaded: false)
        XCTAssertEqual(s2.map(\.weight), [15])
        XCTAssertEqual(out2.note, "y")
    }

    // MARK: 存放

    func testNudgeExpiresAfter21Days() {
        let id = "test_nudge_\(UUID().uuidString)"
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        defer { NoteStore.clearNudge(id) }
        NoteStore.setNudge(.up, for: id, now: t0)
        XCTAssertEqual(NoteStore.nudge(for: id, now: t0.addingTimeInterval(20 * 86400)), .up)
        XCTAssertNil(NoteStore.nudge(for: id, now: t0.addingTimeInterval(22 * 86400)))
    }

    func testNewNudgeReplacesOldOne() {
        let id = "test_nudge_\(UUID().uuidString)"
        defer { NoteStore.clearNudge(id) }
        NoteStore.setNudge(.up, for: id)
        NoteStore.setNudge(.ease, for: id)
        XCTAssertEqual(NoteStore.nudge(for: id), .ease)
        NoteStore.clearNudge(id)
        XCTAssertNil(NoteStore.nudge(for: id))
    }

    func testReminderStaysUntilCleared() {
        let id = "test_reminder_\(UUID().uuidString)"
        defer { NoteStore.clearReminder(id) }
        NoteStore.setReminder("椅子調第 3 格", for: id, now: Date(timeIntervalSince1970: 1))
        XCTAssertEqual(NoteStore.reminder(for: id), "椅子調第 3 格")
        NoteStore.clearReminder(id)
        XCTAssertNil(NoteStore.reminder(for: id))
    }

    func testKeysHaveWorkoutPrefix() {
        XCTAssertEqual(Keys.noteNudges, "workout.noteNudges")
        XCTAssertEqual(Keys.noteReminders, "workout.noteReminders")
    }
}
