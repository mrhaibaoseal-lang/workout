import XCTest
@testable import Workout

/// 數次數測試頁：trials.csv／frames.csv 的輸出格式。
final class RepTestCSVTests: XCTestCase {

    private func trial(note: String = "", weight: Double? = nil) -> RepTrial {
        RepTrial(id: "T1", date: Date(timeIntervalSince1970: 1_700_000_000), exerciseId: "db_curl",
                 view: "side", camera: "front", actualReps: 10, partialReps: 2, weightKg: weight, note: note,
                 durationS: 31.234, frames: 900, droppedFrames: 3, avgFps: 29.96, appVersion: "0.45.0")
    }

    func testFramesHeaderHas62Columns() {
        let cols = RepTestCSV.frameColumns
        XCTAssertEqual(cols.count, 5 + 19 * 3)
        XCTAssertEqual(Array(cols.prefix(5)), ["trial_id", "t", "gx", "gy", "gz"])
        XCTAssertEqual(Array(cols[5..<8]), ["nose_x", "nose_y", "nose_c"])
        XCTAssertEqual(Array(cols.suffix(3)), ["rightAnkle_x", "rightAnkle_y", "rightAnkle_c"])
        XCTAssertEqual(RepTestCSV.framesHeader.split(separator: ",").count, cols.count)
    }

    func testFrameWithNoPersonKeepsEveryColumnEmpty() {
        let frame = RepFrame(t: 1.5, gx: nil, gy: nil, gz: nil,
                             joints: Array(repeating: nil, count: RepJoint.allCases.count))
        let line = RepTestCSV.frameLine(trialId: "T1", frame: frame)
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
        XCTAssertEqual(fields.count, RepTestCSV.frameColumns.count)
        XCTAssertEqual(fields[0], "T1")
        XCTAssertEqual(fields[1], "1.5000")
        XCTAssertTrue(fields[2...].allSatisfy { $0.isEmpty })
    }

    func testFrameWithSomeJoints() {
        var joints = [RepJointSample?](repeating: nil, count: RepJoint.allCases.count)
        joints[RepJoint.leftWrist.rawValue] = RepJointSample(x: 0.12345, y: 0.5, c: 0.9)
        let frame = RepFrame(t: 0, gx: 0.01, gy: -0.98, gz: -0.2, joints: joints)
        let fields = RepTestCSV.frameLine(trialId: "T1", frame: frame)
            .split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(fields.count, RepTestCSV.frameColumns.count)
        XCTAssertEqual(Array(fields[2...4]), ["0.0100", "-0.9800", "-0.2000"])
        let i = 5 + RepJoint.leftWrist.rawValue * 3
        XCTAssertEqual(Array(fields[i..<i + 3]), ["0.1235", "0.5000", "0.9000"])
        XCTAssertEqual(fields[5], "")   // nose 沒偵測到
    }

    func testTrialsCSVHeaderAndEscaping() {
        let csv = RepTestCSV.trialsCSV([trial(note: "含拿放, \"重\"\n第二行", weight: 12.5)])
        let lines = csv.components(separatedBy: "\n")
        XCTAssertEqual(lines[0], "trial_id,date,exercise_id,view,camera,actual_reps,partial_reps,weight_kg,note,duration_s,frames,dropped_frames,avg_fps,app_version")
        XCTAssertTrue(csv.contains("\"含拿放, \"\"重\"\"\n第二行\""))
        XCTAssertTrue(csv.contains(",12.50,"))
        XCTAssertTrue(csv.contains(",31.23,900,3,30.0,0.45.0"))
    }

    func testEmptyWeightLeavesFieldBlank() {
        let csv = RepTestCSV.trialsCSV([trial(weight: nil)])
        XCTAssertTrue(csv.contains(",10,2,,,31.23,"))
    }

    func testCombineFramesKeepsSingleHeader() {
        let f = RepFrame(t: 0, gx: nil, gy: nil, gz: nil,
                         joints: Array(repeating: nil, count: RepJoint.allCases.count))
        let a = RepTestCSV.framesFile(trialId: "A", frames: [f, f])
        let b = RepTestCSV.framesFile(trialId: "B", frames: [f])
        let lines = RepTestCSV.combineFrames([a, b]).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 1 + 3)
        XCTAssertEqual(lines.filter { $0 == RepTestCSV.framesHeader }.count, 1)
        XCTAssertTrue(lines[3].hasPrefix("B,"))
    }

    func testMissingJointsPicksBestSide() {
        let ex = RepTestExercise.find("db_curl")
        var joints = [RepJointSample?](repeating: nil, count: RepJoint.allCases.count)
        XCTAssertEqual(ex.missingJoints(in: joints).count, 3)
        for j in [RepJoint.rightShoulder, .rightElbow, .rightWrist] {
            joints[j.rawValue] = RepJointSample(x: 0.5, y: 0.5, c: 0.8)
        }
        XCTAssertTrue(ex.missingJoints(in: joints).isEmpty)
        joints[RepJoint.rightWrist.rawValue] = RepJointSample(x: 0.5, y: 0.5, c: 0.1)
        XCTAssertEqual(ex.missingJoints(in: joints), [.rightWrist])
    }
}
