import CoreGraphics

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

    /// 遠側肢體的位移。
    static let farOffset = CGPoint(x: -6, y: -1)

    func point(_ j: JointName, far: Bool) -> CGPoint {
        let p = self[j]
        if far { return CGPoint(x: p.x + Joints.farOffset.x, y: p.y + Joints.farOffset.y) }
        return p
    }

    static func lerp(_ a: Joints, _ b: Joints, _ t: CGFloat) -> Joints {
        func l(_ p: CGPoint, _ q: CGPoint) -> CGPoint {
            CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
        }
        return Joints(head: l(a.head, b.head), sh: l(a.sh, b.sh), el: l(a.el, b.el), ha: l(a.ha, b.ha),
                      hip: l(a.hip, b.hip), kn: l(a.kn, b.kn), an: l(a.an, b.an), to: l(a.to, b.to))
    }
}

enum GearKind {
    case goblet   // 抱在胸前的單顆啞鈴
    case db       // 雙手各一顆
}

enum CharacterMove: String, CaseIterable, Identifiable {
    case squat, press, rdl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .squat: return "深蹲"
        case .press: return "肩推"
        case .rdl: return "硬舉"
        }
    }

    var gearKind: GearKind {
        switch self {
        case .squat: return .goblet
        case .press, .rdl: return .db
        }
    }

    var muscles: [String] {
        switch self {
        case .squat: return ["thigh", "glute"]
        case .press: return ["upper", "delt"]
        case .rdl: return ["thigh", "glute"]
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
        }
    }

    var end: Joints {
        switch self {
        case .squat: return CharacterMove.j([114, 76, 106, 98, 124, 122, 124, 100, 92, 144, 130, 152, 108, 182, 124, 184])
        case .press: return CharacterMove.j([110, 38, 106, 60, 108, 32, 110, 8, 104, 110, 107, 146, 106, 182, 122, 184])
        case .rdl: return CharacterMove.j([156, 88, 136, 98, 134, 126, 132, 150, 90, 118, 112, 148, 108, 182, 124, 184])
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
