import Foundation

/// 數次數測試：Vision 的 19 個身體關節（順序固定，CSV 欄位照這個順序）。
enum RepJoint: Int, CaseIterable {
    case nose, leftEye, rightEye, leftEar, rightEar, neck
    case leftShoulder, rightShoulder, leftElbow, rightElbow, leftWrist, rightWrist
    case root, leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle

    /// CSV 欄位用的英文名稱（就是 case 名稱）
    var csvName: String { String(describing: self) }

    var zh: String {
        switch self {
        case .nose: return "鼻子"
        case .leftEye: return "左眼"
        case .rightEye: return "右眼"
        case .leftEar: return "左耳"
        case .rightEar: return "右耳"
        case .neck: return "脖子"
        case .leftShoulder: return "左肩"
        case .rightShoulder: return "右肩"
        case .leftElbow: return "左肘"
        case .rightElbow: return "右肘"
        case .leftWrist: return "左腕"
        case .rightWrist: return "右腕"
        case .root: return "骨盆中心"
        case .leftHip: return "左髖"
        case .rightHip: return "右髖"
        case .leftKnee: return "左膝"
        case .rightKnee: return "右膝"
        case .leftAnkle: return "左踝"
        case .rightAnkle: return "右踝"
        }
    }
}

/// 一個關節在一格裡的位置：Vision 正規化座標（0～1，原點在左下）和信心值。
struct RepJointSample: Equatable {
    var x: Float
    var y: Float
    var c: Float
}

/// 記錄中的一格。沒偵測到人時 joints 全是 nil；沒有重力資料時 gx／gy／gz 是 nil。
struct RepFrame {
    var t: Double
    var gx: Double?
    var gy: Double?
    var gz: Double?
    var joints: [RepJointSample?]
}

/// 鏡頭方向：拍側面或正面（要記在資料裡，分析時才知道座標怎麼解讀）
enum RepAngle: String, CaseIterable, Codable {
    case side, front

    var title: String { self == .side ? "側面" : "正面" }
}

/// 一組測試的資料（存在 trials.json）。
struct RepTrial: Codable, Identifiable, Equatable {
    var id: String
    var date: Date
    var exerciseId: String
    /// "side" 或 "front"
    var view: String
    /// "front" 或 "back"（前／後鏡頭；前鏡頭的座標沒有做左右鏡像）
    var camera: String
    var actualReps: Int
    var partialReps: Int
    var weightKg: Double?
    var note: String
    var durationS: Double
    var frames: Int
    var droppedFrames: Int
    var avgFps: Double
    var appVersion: String
}

/// 可以測的 5 個動作、建議擺法、需要入鏡的關節。
struct RepTestExercise: Identifiable {
    let id: String
    let defaultAngle: RepAngle
    let placement: String
    /// 任一組完整即可（例如左邊或右邊）
    let requirements: [[RepJoint]]

    var name: String { ExerciseLibrary.byId(id)?.name ?? id }

    static let all: [RepTestExercise] = [
        RepTestExercise(id: "db_curl", defaultAngle: .side,
                        placement: "手機直立放在腰的高度，離身體約 2 公尺，拍側面",
                        requirements: [[.leftShoulder, .leftElbow, .leftWrist],
                                       [.rightShoulder, .rightElbow, .rightWrist]]),
        RepTestExercise(id: "db_shoulder_press", defaultAngle: .front,
                        placement: "手機直立放在胸口高度，離身體約 2.5 公尺",
                        requirements: [[.leftShoulder, .leftElbow, .leftWrist,
                                        .rightShoulder, .rightElbow, .rightWrist]]),
        RepTestExercise(id: "goblet_squat", defaultAngle: .side,
                        placement: "手機直立放在膝蓋到腰的高度，離身體約 2.5 公尺，拍側面",
                        requirements: [[.leftShoulder, .leftHip, .leftKnee, .leftAnkle],
                                       [.rightShoulder, .rightHip, .rightKnee, .rightAnkle]]),
        RepTestExercise(id: "pushup", defaultAngle: .side,
                        placement: "手機直立放在地上，離身體約 2 公尺，拍側面",
                        requirements: [[.leftShoulder, .leftElbow, .leftWrist, .leftHip, .leftAnkle],
                                       [.rightShoulder, .rightElbow, .rightWrist, .rightHip, .rightAnkle]]),
        RepTestExercise(id: "db_hip_thrust", defaultAngle: .side,
                        placement: "手機直立放在椅子高度，離身體約 2 公尺，拍側面",
                        requirements: [[.leftShoulder, .leftHip, .leftKnee],
                                       [.rightShoulder, .rightHip, .rightKnee]]),
    ]

    static func find(_ id: String) -> RepTestExercise {
        all.first { $0.id == id } ?? all[0]
    }

    /// 入鏡的信心門檻
    static let minConfidence: Float = 0.3

    /// 還缺哪些關節（空陣列＝已入鏡）。多組需求時回報缺最少的那一組。
    func missingJoints(in joints: [RepJointSample?]) -> [RepJoint] {
        var best: [RepJoint]?
        for group in requirements {
            let missing = group.filter { j in
                guard j.rawValue < joints.count, let s = joints[j.rawValue] else { return true }
                return s.c < Self.minConfidence
            }
            if missing.isEmpty { return [] }
            if best == nil || missing.count < best!.count { best = missing }
        }
        return best ?? []
    }

    /// 這個動作用到的所有關節（畫面上標示用）
    var allRequiredJoints: Set<RepJoint> { Set(requirements.flatMap { $0 }) }
}

/// trials.csv 與 frames.csv 的輸出（純函式，方便測試）。
enum RepTestCSV {
    static let trialColumns = ["trial_id", "date", "exercise_id", "view", "camera", "actual_reps", "partial_reps",
                               "weight_kg", "note", "duration_s", "frames", "dropped_frames", "avg_fps", "app_version"]

    static var frameColumns: [String] {
        ["trial_id", "t", "gx", "gy", "gz"]
            + RepJoint.allCases.flatMap { ["\($0.csvName)_x", "\($0.csvName)_y", "\($0.csvName)_c"] }
    }

    static func row(_ fields: [String]) -> String {
        fields.map(CSVExport.escape).joined(separator: ",")
    }

    static func decimal(_ v: Double, digits: Int = 4) -> String {
        String(format: "%.\(digits)f", v)
    }

    private static func dateString(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }

    private static func weightString(_ w: Double?) -> String {
        guard let w else { return "" }
        return w == w.rounded() ? String(Int(w)) : decimal(w, digits: 2)
    }

    static func trialsCSV(_ trials: [RepTrial]) -> String {
        var lines = [row(trialColumns)]
        for t in trials {
            lines.append(row([
                t.id, dateString(t.date), t.exerciseId, t.view, t.camera,
                "\(t.actualReps)", "\(t.partialReps)", weightString(t.weightKg), t.note,
                decimal(t.durationS, digits: 2), "\(t.frames)", "\(t.droppedFrames)",
                decimal(t.avgFps, digits: 1), t.appVersion,
            ]))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static var framesHeader: String { row(frameColumns) }

    /// 一格一列：沒偵測到的關節三欄留空；整格沒人也會有一列。
    static func frameLine(trialId: String, frame: RepFrame) -> String {
        var fields = [trialId, decimal(frame.t),
                      frame.gx.map { decimal($0) } ?? "",
                      frame.gy.map { decimal($0) } ?? "",
                      frame.gz.map { decimal($0) } ?? ""]
        for j in RepJoint.allCases {
            if j.rawValue < frame.joints.count, let s = frame.joints[j.rawValue] {
                fields.append(decimal(Double(s.x)))
                fields.append(decimal(Double(s.y)))
                fields.append(decimal(Double(s.c)))
            } else {
                fields.append(contentsOf: ["", "", ""])
            }
        }
        return row(fields)
    }

    /// 單組的 frames 檔內容（含標頭）
    static func framesFile(trialId: String, frames: [RepFrame]) -> String {
        ([framesHeader] + frames.map { frameLine(trialId: trialId, frame: $0) }).joined(separator: "\n") + "\n"
    }

    /// 把多組的 frames 檔合成一個（只留一個標頭）
    static func combineFrames(_ fileTexts: [String]) -> String {
        var out = framesHeader + "\n"
        for text in fileTexts {
            var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            if lines.first == framesHeader { lines.removeFirst() }
            for l in lines { out += l + "\n" }
        }
        return out
    }
}
