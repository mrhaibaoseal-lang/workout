import XCTest
@testable import Workout

/// 熱身／伸展挑選、跟做計時分段、動作示範資料（0.31.0）。
final class MobilityTests: XCTestCase {

    func testWarmupUpperDaySkipsLegOnlyMoves() {
        let steps = Mobility.warmup(patterns: [.hPush, .vPush, .triceps])
        let moves = steps.map(\.move)
        XCTAssertTrue(moves.contains(.armSwing))
        XCTAssertTrue(moves.contains(.pushup))
        XCTAssertFalse(moves.contains(.legSwing))
        XCTAssertFalse(moves.contains(.bwBridge))
    }

    func testWarmupLowerDaySkipsUpperOnlyMoves() {
        let moves = Mobility.warmup(patterns: [.squat, .hinge, .calf]).map(\.move)
        XCTAssertTrue(moves.contains(.legSwing))
        XCTAssertFalse(moves.contains(.pushup))
        XCTAssertFalse(moves.contains(.wallSlide))
    }

    func testWarmupLengthIsReasonable() {
        let all = Mobility.warmup(patterns: [.hPush, .squat])
        let seconds = all.reduce(0) { $0 + $1.totalSeconds }
        XCTAssertGreaterThanOrEqual(seconds, 150)
        XCTAssertLessThanOrEqual(seconds, 360)
        XCTAssertEqual(Mobility.warmup(patterns: []).count, all.count, "沒動作時上下半身都熱")
    }

    func testCooldownMatchesTrainedAreasAndIsCapped() {
        let legs = Mobility.cooldown(patterns: [.squat, .hinge, .lunge, .calf]).map(\.move)
        XCTAssertTrue(legs.contains(.quadStretch))
        XCTAssertTrue(legs.contains(.seatedFold))
        XCTAssertFalse(legs.contains(.chestStretch))

        let everything = Mobility.cooldown(patterns: MovementPattern.allCases)
        XCTAssertLessThanOrEqual(everything.count, Mobility.maxStretches)
        XCTAssertFalse(Mobility.cooldown(patterns: []).isEmpty)
    }

    func testCooldownStandingBeforeFloor() {
        let moves = Mobility.cooldown(patterns: [.hPush, .hPull, .squat]).map(\.move)
        if let chest = moves.firstIndex(of: .chestStretch), let child = moves.firstIndex(of: .childPose) {
            XCTAssertLessThan(chest, child)
        } else {
            XCTFail("胸、背都有練，應該有胸肌伸展和嬰兒式")
        }
    }

    func testPhasesSplitPerSideSteps() {
        let steps = [
            MobilityStep(move: .crossBody, name: "a", cue: "", seconds: 30, perSide: true),
            MobilityStep(move: .childPose, name: "b", cue: "", seconds: 40),
        ]
        let p = MobilityRun.makePhases(kind: .cooldown, steps: steps)
        XCTAssertEqual(p.map(\.kind), [.prep, .work, .switchSide, .work, .prep, .work])
        XCTAssertEqual(p.filter { $0.kind == .work }.map(\.side), [1, 2, 0])
        let total = p.reduce(0) { $0 + $1.seconds }
        XCTAssertEqual(total, 30 + 30 + 40 + MobilityPhase.switchSeconds + 2 * MobilityKind.cooldown.gap)
    }

    func testEveryNewMoveHasFrames() {
        let generated: [CharacterMove] = [
            .armCircle, .hipHinge, .bwSquat, .lungeStep, .armSwing, .wallSlide, .legSwing, .bwBridge,
            .chestStretch, .crossBody, .tricepsStretch, .childPose, .quadStretch, .seatedFold, .kneeHug,
            .calfStretch, .hipFlexor, .cobra, .splitSquat, .reverseLunge, .stepUp, .hipThrust, .benchPress,
            .floorPress, .skullCrusher, .pullover, .kickback, .pikePushup, .reverseCrunch, .deadBug, .slRdl, .legCurl,
            .latPulldown, .straightArmPulldown, .tricepsPushdown, .overheadCableExt, .facePull, .cableCrunch,
            .seatedCableRow, .cableLateral,
        ]
        for m in generated {
            XCTAssertNotNil(m.spec, "\(m) 沒有產生的資料")
            XCTAssertGreaterThanOrEqual(m.frames.count, 2)
        }
    }

    func testExerciseSpecificDemos() {
        XCTAssertEqual(CharacterMove.forExercise(ExerciseLibrary.byId("db_split_squat")!), .splitSquat)
        XCTAssertEqual(CharacterMove.forExercise(ExerciseLibrary.byId("db_hip_thrust")!), .hipThrust)
        // 沒有專屬示範的照動作模式
        XCTAssertEqual(CharacterMove.forExercise(ExerciseLibrary.byId("goblet_squat")!), .squat)
        // 用滑輪的內建動作都有畫出滑輪架
        for e in ExerciseLibrary.builtIn where e.id.hasPrefix("cable_") {
            XCTAssertNotNil(CharacterMove.forExercise(e).prop?.pulley, "\(e.id) 沒有滑輪")
        }
        for id in CharacterMove.byExercise.keys {
            XCTAssertNotNil(ExerciseLibrary.byId(id), "\(id) 不在動作庫")
        }
    }

    func testPosePhaseEndsAndFarLimbInterpolation() {
        let m = CharacterMove.lungeStep
        let a = m.pose(phase: 0)
        let mid = m.pose(phase: 0.5)
        XCTAssertEqual(a.an.x, m.frames[0].an.x, accuracy: 0.01)
        XCTAssertEqual(mid.an.x, m.frames[1].an.x, accuracy: 0.01)
        // 後腳往後跨：遠側腳踝在中間時明顯比起點更後面
        XCTAssertLessThan(mid.point(.an, far: true).x, a.point(.an, far: true).x - 20)
        // 繞圈動作回到起點
        let c0 = CharacterMove.armCircle.pose(phase: 0)
        let c1 = CharacterMove.armCircle.pose(phase: 1)
        XCTAssertEqual(c0.ha.x, c1.ha.x, accuracy: 0.01)
        XCTAssertEqual(c0.ha.y, c1.ha.y, accuracy: 0.01)
    }
}
