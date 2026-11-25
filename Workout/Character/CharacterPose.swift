import CoreGraphics
import Foundation

/// 關節名稱（側面、面向右；200 單位座標，y 向下，地面約 y=184）。
enum JointName {
    case head, sh, el, ha, hip, kn, an, to
}

struct Joints {
    var head: CGPoint
    var sh: CGPoint
    var el: CGPoint
    var ha: CGPoint
    var hip: CGPoint
    var kn: CGPoint
    var an: CGPoint
    var to: CGPoint

    subscript(_ j: JointName) -> CGPoint {
        switch j {
        case .head: return head
        case .sh: return sh
        case .el: return el
        case .ha: return ha
        case .hip: return hip
        case .kn: return kn
        case .an: return an
        case .to: return to
        }
    }

    /// 遠側的手腳另外擺（弓步、單腳站、伸展）。沒有就跟近側一樣，只往後錯開一點。
    var farLimb: FarLimb? = nil

    /// 遠側肢體的位移。
    static let farOffset = CGPoint(x: -6, y: -1)

    func point(_ j: JointName, far: Bool) -> CGPoint {
        if far, let f = farLimb {
            switch j {
            case .el: return f.el
            case .ha: return f.ha
            case .kn: return f.kn
            case .an: return f.an
            case .to: return f.to
            default: break
            }
        }
        let p = self[j]
        if far { return CGPoint(x: p.x + Joints.farOffset.x, y: p.y + Joints.farOffset.y) }
        return p
    }

    /// 遠側手腳實際的位置（有沒有另外擺都一樣算）
    var resolvedFar: FarLimb {
        farLimb ?? FarLimb(el: point(.el, far: true), ha: point(.ha, far: true), kn: point(.kn, far: true),
                           an: point(.an, far: true), to: point(.to, far: true))
    }

    static func lerp(_ a: Joints, _ b: Joints, _ t: CGFloat) -> Joints {
        func l(_ p: CGPoint, _ q: CGPoint) -> CGPoint {
            CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
        }
        var out = Joints(head: l(a.head, b.head), sh: l(a.sh, b.sh), el: l(a.el, b.el), ha: l(a.ha, b.ha),
                         hip: l(a.hip, b.hip), kn: l(a.kn, b.kn), an: l(a.an, b.an), to: l(a.to, b.to))
        if a.farLimb != nil || b.farLimb != nil {
            let fa = a.resolvedFar, fb = b.resolvedFar
            out.farLimb = FarLimb(el: l(fa.el, fb.el), ha: l(fa.ha, fb.ha), kn: l(fa.kn, fb.kn),
                                  an: l(fa.an, fb.an), to: l(fa.to, fb.to))
        }
        return out
    }

    /// 產生的動作資料用：head, sh, el, ha, hip, kn, an, to 各兩個數字；far 是遠側 el, ha, kn, an, to。
    static func j(_ v: [CGFloat], far f: [CGFloat]? = nil) -> Joints {
        func p(_ a: [CGFloat], _ i: Int) -> CGPoint { CGPoint(x: a[i * 2], y: a[i * 2 + 1]) }
        var out = Joints(head: p(v, 0), sh: p(v, 1), el: p(v, 2), ha: p(v, 3),
                         hip: p(v, 4), kn: p(v, 5), an: p(v, 6), to: p(v, 7))
        if let f {
            out.farLimb = FarLimb(el: p(f, 0), ha: p(f, 1), kn: p(f, 2), an: p(f, 3), to: p(f, 4))
        }
        return out
    }
}

struct FarLimb {
    var el: CGPoint
    var ha: CGPoint
    var kn: CGPoint
    var an: CGPoint
    var to: CGPoint
}

/// 道具的一塊（`MoveProp` 在 MoveFrames.swift，由 scripts/art/moves.js 產生）
struct PropShape {
    enum Kind { case pad, leg, frame }
    let kind: Kind
    let rect: CGRect

    init(_ kind: Kind, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
        self.kind = kind
        rect = CGRect(x: x, y: y, width: w, height: h)
    }
}

/// 滑輪動作手上拿的握把
enum CableGrip {
    /// 直槓（下拉、彎舉）
    case bar
    /// 三頭繩（下壓、面拉、捲腹）
    case rope
    /// D 型把手（划船、側平舉）
    case handle
}

/// 由 scripts/art/moves.js 產生的動作（`MoveFrames.swift`）
struct MoveSpec {
    let title: String
    let gear: GearKind
    /// true：照影格順序繞圈（手臂繞圈）；false：來回
    let loop: Bool
    /// 一個來回（或一圈）幾秒
    let period: Double
    let prop: MoveProp?
    /// 滑輪動作的握把；有滑輪但沒寫就是直槓
    var grip: CableGrip? = nil
    /// 仰躺、頭在右邊的動作：身體是側面圖左右翻過來的，臉和腳掌要翻面
    var mirror: Bool = false
    let frames: [Joints]
}

enum GearKind {
    case goblet   // 抱在胸前的單顆啞鈴
    case db       // 雙手各一顆
    case bare     // 徒手（伏地挺身、棒式）
}

enum CharacterMove: String, CaseIterable, Identifiable {
    case squat, press, rdl
    case pushup, row, pulldown, lunge, bridge, calf, curl, triceps, lateral, rearFly, plank
    /// 休息頁用：彎腰扶膝喘氣、喝水、最後 3 秒的準備姿勢
    case breathe, drink, ready
    // 以下由 scripts/art/moves.js 產生資料（MoveFrames.swift）
    // 練前動態熱身
    case armCircle, hipHinge, bwSquat, lungeStep, armSwing, wallSlide, legSwing, bwBridge
    // 練後伸展
    case chestStretch, crossBody, tricepsStretch, childPose, quadStretch, seatedFold, kneeHug, calfStretch, hipFlexor, cobra
    // 比依動作模式套用更貼近的訓練示範
    case splitSquat, reverseLunge, stepUp, hipThrust, benchPress, floorPress, skullCrusher, pullover, kickback
    case pikePushup, reverseCrunch, deadBug, slRdl, legCurl
    // 滑輪（下拉架）
    case latPulldown, straightArmPulldown, tricepsPushdown, overheadCableExt, facePull, cableCrunch
    case seatedCableRow, cableCurl, cableLateral

    var id: String { rawValue }

    /// 角色頁用的原始三個動作。
    static let basic: [CharacterMove] = [.squat, .press, .rdl]

    /// 依動作模式挑示範動作。
    static func forPattern(_ p: MovementPattern) -> CharacterMove {
        switch p {
        case .hPush, .incline: return .pushup
        case .vPush: return .press
        case .hPull: return .row
        case .vPull: return .pulldown
        case .squat: return .squat
        case .hinge: return .rdl
        case .lunge: return .lunge
        case .hamCurl: return .bridge
        case .quadIso: return .squat
        case .glute: return .bridge
        case .calf: return .calf
        case .biceps: return .curl
        case .triceps: return .triceps
        case .lateral: return .lateral
        case .rear: return .rearFly
        case .core: return .plank
        }
    }

    /// 有專屬示範的動作
    static let byExercise: [String: CharacterMove] = [
        "db_split_squat": .splitSquat, "split_squat": .splitSquat,
        "db_reverse_lunge": .reverseLunge, "reverse_lunge": .reverseLunge,
        "db_step_up": .stepUp,
        "bb_hip_thrust": .hipThrust, "db_hip_thrust": .hipThrust,
        "db_glute_bridge": .bridge, "sl_glute_bridge": .bwBridge,
        "bb_bench": .benchPress, "db_bench": .benchPress, "db_neutral_press": .benchPress,
        "bb_floor_press": .floorPress, "db_floor_press": .floorPress,
        "db_skull": .skullCrusher, "db_pullover": .pullover,
        "db_kickback": .kickback, "pike_pushup": .pikePushup,
        "reverse_crunch": .reverseCrunch, "dead_bug": .deadBug,
        "db_sl_rdl": .slRdl, "sl_rdl": .slRdl,
        "db_leg_curl": .legCurl, "squat": .bwSquat,
        "cable_pulldown": .latPulldown, "cable_close_pulldown": .latPulldown, "cable_one_arm_pulldown": .latPulldown, "band_pulldown": .latPulldown,
        "cable_straight_arm": .straightArmPulldown, "cable_pushdown": .tricepsPushdown, "band_pushdown": .tricepsPushdown,
        "cable_overhead_ext": .overheadCableExt, "cable_face_pull": .facePull, "cable_crunch": .cableCrunch, "cable_high_chop": .cableCrunch,
        "cable_row": .seatedCableRow, "cable_curl": .cableCurl, "cable_lateral": .cableLateral,
    ]

    static func forExercise(_ e: Exercise) -> CharacterMove {
        byExercise[e.id] ?? forPattern(e.pattern)
    }

    var spec: MoveSpec? { CharacterMove.generated[rawValue] }

    /// 動作的影格（舊動作是起點、終點兩格）
    var frames: [Joints] { spec?.frames ?? [start, end] }
    var period: Double { spec?.period ?? 2.6 }
    var prop: MoveProp? { spec?.prop }
    /// 臉朝上（仰躺、頭在右）：頭和腳上的裝備要翻面
    var mirrored: Bool { self == .bridge || spec?.mirror == true }

    /// phase：0～1 是一個週期。來回的動作 0→1→0（餘弦緩動），繞圈的動作依序走完每一格。
    func pose(phase: Double) -> Joints {
        let f = frames
        guard f.count > 1 else { return f.first ?? start }
        let ph = phase - floor(phase)
        if spec?.loop == true {
            let x = ph * Double(f.count)
            let i = Int(x) % f.count
            let t = x - floor(x)
            let s = t * t * (3 - 2 * t)
            return Joints.lerp(f[i], f[(i + 1) % f.count], CGFloat(s))
        }
        let p = 0.5 - 0.5 * cos(2 * Double.pi * ph)
        let x = p * Double(f.count - 1)
        let i = min(Int(x), f.count - 2)
        return Joints.lerp(f[i], f[i + 1], CGFloat(x - Double(i)))
    }

    var title: String {
        switch self {
        case .squat: return "深蹲"
        case .press: return "肩推"
        case .rdl: return "硬舉"
        case .pushup: return "伏地挺身"
        case .row: return "划船"
        case .pulldown: return "下拉"
        case .lunge: return "弓步"
        case .bridge: return "臀橋"
        case .calf: return "提踵"
        case .curl: return "彎舉"
        case .triceps: return "三頭伸展"
        case .lateral: return "側平舉"
        case .rearFly: return "反向飛鳥"
        case .plank: return "棒式"
        case .breathe: return "喘氣"
        case .drink: return "喝水"
        case .ready: return "準備"
        default: return spec?.title ?? rawValue
        }
    }

    var gearKind: GearKind {
        switch self {
        case .squat: return .goblet
        case .pushup, .plank, .breathe, .drink, .ready: return .bare
        case .press, .rdl, .row, .pulldown, .lunge, .bridge, .calf, .curl, .triceps, .lateral, .rearFly: return .db
        default: return spec?.gear ?? .db
        }
    }

    var muscles: [String] {
        switch self {
        case .squat: return ["thigh", "glute"]
        case .press: return ["upper", "delt"]
        case .rdl: return ["thigh", "glute"]
        case .pushup: return ["upper", "torso"]
        case .row: return ["upper", "torso"]
        case .pulldown: return ["upper", "torso"]
        case .lunge: return ["thigh", "glute"]
        case .bridge: return ["glute", "thigh"]
        case .calf: return ["shin"]
        case .curl: return ["upper", "fore"]
        case .triceps: return ["upper"]
        case .lateral: return ["upper", "delt"]
        case .rearFly: return ["upper", "delt"]
        case .plank: return ["torso"]
        case .breathe, .drink: return ["torso"]
        case .ready: return ["upper"]
        default: return []
        }
    }

    private static func j(_ v: [CGFloat]) -> Joints {
        // 順序：head, sh, el, ha, hip, kn, an, to，每個兩個數字
        Joints(head: CGPoint(x: v[0], y: v[1]), sh: CGPoint(x: v[2], y: v[3]),
               el: CGPoint(x: v[4], y: v[5]), ha: CGPoint(x: v[6], y: v[7]),
               hip: CGPoint(x: v[8], y: v[9]), kn: CGPoint(x: v[10], y: v[11]),
               an: CGPoint(x: v[12], y: v[13]), to: CGPoint(x: v[14], y: v[15]))
    }

    var start: Joints {
        switch self {
        case .squat: return CharacterMove.j([110, 38, 106, 60, 116, 86, 122, 64, 104, 110, 110, 146, 108, 182, 124, 184])
        case .press: return CharacterMove.j([110, 38, 106, 60, 118, 84, 118, 60, 104, 110, 107, 146, 106, 182, 122, 184])
        case .rdl: return CharacterMove.j([110, 38, 106, 60, 108, 88, 110, 112, 104, 110, 108, 146, 108, 182, 124, 184])
        // 伏地挺身：撐起（手伸直）
        case .pushup: return CharacterMove.j([150, 118, 130, 128, 131, 156, 132, 184, 94, 144, 62, 159, 28, 174, 30, 184])
        // 划船：俯身、手垂下
        case .row: return CharacterMove.j([164, 86, 146, 94, 148, 122, 148, 146, 98, 116, 108, 150, 108, 182, 124, 184])
        // 下拉：手在頭上伸直
        case .pulldown: return CharacterMove.j([110, 38, 106, 60, 107, 30, 110, 6, 104, 110, 107, 146, 106, 182, 122, 184])
        // 弓步：站直（重心在前腳）
        case .lunge: return CharacterMove.j([134, 38, 130, 60, 132, 88, 134, 112, 128, 110, 130, 146, 132, 182, 148, 184])
        // 臀橋：躺著、髖在地上
        case .bridge: return CharacterMove.j([152, 174, 132, 172, 106, 176, 82, 178, 82, 172, 64, 140, 54, 180, 38, 184])
        // 提踵：腳跟著地
        case .calf: return CharacterMove.j([110, 38, 106, 60, 108, 88, 110, 112, 104, 110, 107, 146, 106, 182, 122, 184])
        // 彎舉：手垂下
        case .curl: return CharacterMove.j([110, 38, 106, 60, 108, 88, 110, 114, 104, 110, 107, 146, 106, 182, 122, 184])
        // 三頭伸展：肘朝上、前臂折在頭後
        case .triceps: return CharacterMove.j([110, 38, 106, 60, 108, 30, 96, 48, 104, 110, 107, 146, 106, 182, 122, 184])
        // 側平舉：手垂下
        case .lateral: return CharacterMove.j([110, 38, 106, 60, 108, 88, 110, 112, 104, 110, 107, 146, 106, 182, 122, 184])
        // 反向飛鳥：俯身、手垂下
        case .rearFly: return CharacterMove.j([164, 86, 146, 94, 148, 122, 148, 146, 98, 116, 108, 150, 108, 182, 124, 184])
        // 棒式：前臂撐地
        case .plank: return CharacterMove.j([160, 146, 140, 150, 138, 180, 160, 182, 92, 162, 56, 170, 22, 178, 24, 184])
        // 喘氣：彎腰、雙手扶膝，吐氣
        case .breathe: return CharacterMove.j([151, 79, 133, 91.5, 129, 119, 120, 140, 92, 120, 116, 148, 106, 182, 122, 184])
        // 喝水：水壺在胸前
        case .drink: return CharacterMove.j([110, 38, 106, 60, 110, 88, 122, 70, 104, 110, 107, 146, 106, 182, 122, 184])
        // 準備：微蹲、雙拳舉在下巴前
        case .ready: return CharacterMove.j([112, 42, 108, 64, 114, 90, 126, 68, 104, 112, 112, 146, 106, 182, 122, 184])
        default: return spec?.frames.first ?? CharacterMove.squat.start
        }
    }

    var end: Joints {
        switch self {
        case .squat: return CharacterMove.j([114, 76, 106, 98, 124, 122, 124, 100, 92, 144, 130, 152, 108, 182, 124, 184])
        case .press: return CharacterMove.j([110, 38, 106, 60, 108, 32, 110, 8, 104, 110, 107, 146, 106, 182, 122, 184])
        case .rdl: return CharacterMove.j([156, 88, 136, 98, 134, 126, 132, 150, 90, 118, 112, 148, 108, 182, 124, 184])
        // 伏地挺身：下放（胸靠近地面）
        case .pushup: return CharacterMove.j([152, 160, 134, 164, 110, 172, 132, 184, 98, 168, 62, 172, 28, 174, 30, 184])
        // 划船：肘拉向身後
        case .row: return CharacterMove.j([164, 86, 146, 94, 126, 108, 144, 124, 98, 116, 108, 150, 108, 182, 124, 184])
        // 下拉：肘拉下到胸前
        case .pulldown: return CharacterMove.j([110, 38, 106, 60, 94, 86, 116, 72, 104, 110, 107, 146, 106, 182, 122, 184])
        // 弓步：下沉、前膝彎
        case .lunge: return CharacterMove.j([110, 68, 104, 90, 106, 118, 108, 142, 100, 140, 136, 148, 132, 182, 148, 184])
        // 臀橋：髖頂起
        case .bridge: return CharacterMove.j([152, 168, 132, 164, 108, 172, 86, 176, 88, 132, 54, 146, 54, 180, 38, 184])
        // 提踵：腳跟抬起
        case .calf: return CharacterMove.j([118, 26, 114, 48, 116, 76, 118, 100, 112, 98, 114, 134, 118, 170, 124, 184])
        // 彎舉：前臂捲到肩前
        case .curl: return CharacterMove.j([110, 38, 106, 60, 110, 88, 120, 62, 104, 110, 107, 146, 106, 182, 122, 184])
        // 三頭伸展：手臂向上伸直
        case .triceps: return CharacterMove.j([110, 38, 106, 60, 108, 30, 110, 6, 104, 110, 107, 146, 106, 182, 122, 184])
        // 側平舉：手舉到與肩同高
        case .lateral: return CharacterMove.j([110, 38, 106, 60, 134, 62, 160, 60, 104, 110, 107, 146, 106, 182, 122, 184])
        // 反向飛鳥：手臂向後上方打開
        case .rearFly: return CharacterMove.j([164, 86, 146, 94, 124, 104, 100, 112, 98, 116, 108, 150, 108, 182, 124, 184])
        // 棒式：髖微微抬起
        case .plank: return CharacterMove.j([160, 146, 140, 150, 138, 180, 160, 182, 92, 156, 56, 168, 22, 178, 24, 184])
        // 喘氣：吸氣，肩膀和頭抬起一點
        case .breathe: return CharacterMove.j([151, 74, 133, 86.5, 129, 115, 120, 140, 92, 120, 116, 148, 106, 182, 122, 184])
        // 喝水：水壺舉到嘴邊
        case .drink: return CharacterMove.j([108, 37, 106, 60, 124, 80, 121, 54, 104, 110, 107, 146, 106, 182, 122, 184])
        // 準備：往下彈一下
        case .ready: return CharacterMove.j([112, 45, 108, 67, 114, 93, 126, 71, 104, 115, 113, 148, 106, 182, 122, 184])
        default: return spec?.frames.last ?? CharacterMove.squat.end
        }
    }

    func pose(_ t: CGFloat) -> Joints {
        Joints.lerp(start, end, t)
    }
}

/// 身體每一段：名稱、基底名稱、起點、終點、粗細、是否遠側。
struct BodySegment {
    let name: String
    let base: String
    let from: JointName
    let to: JointName
    let width: CGFloat
    let far: Bool

    var isTorso: Bool { name == "torso" }
}

enum BodySegments {
    static let all: [BodySegment] = [
        BodySegment(name: "farUpper", base: "upper", from: .sh, to: .el, width: 12, far: true),
        BodySegment(name: "farFore", base: "fore", from: .el, to: .ha, width: 10, far: true),
        BodySegment(name: "farThigh", base: "thigh", from: .hip, to: .kn, width: 16, far: true),
        BodySegment(name: "farShin", base: "shin", from: .kn, to: .an, width: 12, far: true),
        BodySegment(name: "farFoot", base: "foot", from: .an, to: .to, width: 8, far: true),
        BodySegment(name: "torso", base: "torso", from: .hip, to: .sh, width: 24, far: false),
        BodySegment(name: "neck", base: "neck", from: .sh, to: .head, width: 9, far: false),
        BodySegment(name: "thigh", base: "thigh", from: .hip, to: .kn, width: 18, far: false),
        BodySegment(name: "shin", base: "shin", from: .kn, to: .an, width: 13, far: false),
        BodySegment(name: "foot", base: "foot", from: .an, to: .to, width: 9, far: false),
        BodySegment(name: "upper", base: "upper", from: .sh, to: .el, width: 13, far: false),
        BodySegment(name: "fore", base: "fore", from: .el, to: .ha, width: 11, far: false)
    ]
}
