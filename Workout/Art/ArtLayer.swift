import SwiftUI

/// 一個向量圖層：SVG 路徑字串＋填色＋外框。形狀資料由 scripts/art/*.js 產生，
/// 預覽 HTML 和 App 用的是同一份資料，畫出來一樣。
struct ArtLayer {
    enum Fill {
        case solid(String, Double)
        /// 由上到下的漸層（範圍是這個形狀的外框）
        case linear([String])
        /// 從中心往外的漸層（色碼, 透明度）
        case radial([(String, Double)])
    }

    let d: String
    let fill: Fill
    let stroke: String?
    let width: CGFloat
    /// 大於 0 時整層模糊（發光用），單位同座標。
    let blur: CGFloat
    /// 動畫用（牌位獎章）：部位編號、支點、同部位第幾片、是否為鏡像那一份、是否為輪廓（反光只掃在輪廓裡）。
    /// 意義見 scripts/art/badges.js 的 PART。
    let part: Int
    let pivot: CGPoint
    let index: Int
    let mirrored: Bool
    let clip: Bool

    init(_ d: String, _ fill: Fill, stroke: String? = nil, width: CGFloat = 0, blur: CGFloat = 0,
         part: Int = 0, px: CGFloat = 60, py: CGFloat = 58, i: Int = 0, m: Bool = false, clip: Bool = false) {
        self.d = d
        self.fill = fill
        self.stroke = stroke
        self.width = width
        self.blur = blur
        self.part = part
        self.pivot = CGPoint(x: px, y: py)
        self.index = i
        self.mirrored = m
        self.clip = clip
    }

    /// 形狀的外框（快取）。
    var bounds: CGRect { SVGPathCache.bounds(d) }

    var path: Path { SVGPathCache.path(d) }

    /// transform：局部座標 → 畫布；scale：線寬、模糊半徑要乘的倍率（transform 裡的縮放）。
    /// 漸層方向以局部座標的外框為準，和預覽 SVG 的 objectBoundingBox 一致。
    func draw(_ c: inout GraphicsContext, transform t: CGAffineTransform = .identity,
              scale k: CGFloat = 1, alpha: Double = 1) {
        let local = path
        let p = local.applying(t)
        let r = local.boundingRect
        var shading: GraphicsContext.Shading?
        switch fill {
        case .solid(let hex, let a):
            if a * alpha > 0.001 { shading = .color(Color(gearHex: hex).opacity(a * alpha)) }
        case .linear(let hs):
            let n = max(1, hs.count - 1)
            let stops = hs.enumerated().map {
                Gradient.Stop(color: Color(gearHex: $0.element).opacity(alpha), location: CGFloat($0.offset) / CGFloat(n))
            }
            shading = .linearGradient(Gradient(stops: stops),
                                      startPoint: CGPoint(x: r.midX, y: r.minY).applying(t),
                                      endPoint: CGPoint(x: r.midX, y: r.maxY).applying(t))
        case .radial(let hs):
            let n = max(1, hs.count - 1)
            let stops = hs.enumerated().map {
                Gradient.Stop(color: Color(gearHex: $0.element.0).opacity($0.element.1 * alpha),
                              location: CGFloat($0.offset) / CGFloat(n))
            }
            shading = .radialGradient(Gradient(stops: stops), center: CGPoint(x: r.midX, y: r.midY).applying(t),
                                      startRadius: 0, endRadius: max(r.width, r.height) / 2 * k)
        }
        let strokeCol: Color? = (stroke != nil && width > 0) ? Color(gearHex: stroke!).opacity(alpha) : nil
        let style = StrokeStyle(lineWidth: width * k, lineCap: .round, lineJoin: .round)
        func paint(_ g: inout GraphicsContext) {
            if let sh = shading { g.fill(p, with: sh) }
            if let sc = strokeCol { g.stroke(p, with: .color(sc), style: style) }
        }
        if blur > 0 {
            c.drawLayer { (l: inout GraphicsContext) in
                l.addFilter(.blur(radius: blur * k))
                paint(&l)
            }
        } else {
            paint(&c)
        }
    }
}

extension Array where Element == ArtLayer {
    func draw(_ c: inout GraphicsContext, transform: CGAffineTransform = .identity,
              scale: CGFloat = 1, alpha: Double = 1) {
        for l in self { l.draw(&c, transform: transform, scale: scale, alpha: alpha) }
    }
}

/// 只支援產生器會輸出的指令：絕對座標 M L Q C Z。
enum SVGPathCache {
    private static var cache: [String: Path] = [:]
    private static var boxes: [String: CGRect] = [:]
    private static let lock = NSLock()

    static func bounds(_ d: String) -> CGRect {
        lock.lock()
        if let b = boxes[d] { lock.unlock(); return b }
        lock.unlock()
        let b = path(d).boundingRect
        lock.lock()
        boxes[d] = b
        lock.unlock()
        return b
    }

    static func path(_ d: String) -> Path {
        lock.lock()
        if let p = cache[d] { lock.unlock(); return p }
        lock.unlock()
        let p = parse(d)
        lock.lock()
        cache[d] = p
        lock.unlock()
        return p
    }

    static func parse(_ d: String) -> Path {
        var path = Path()
        var cmd: Character = "M"
        var nums: [CGFloat] = []

        func flush() {
            var i = 0
            func take(_ n: Int) -> [CGFloat]? {
                guard i + n <= nums.count else { return nil }
                defer { i += n }
                return Array(nums[i..<(i + n)])
            }
            switch cmd {
            case "M":
                var first = true
                while let v = take(2) {
                    let p = CGPoint(x: v[0], y: v[1])
                    if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                }
            case "L":
                while let v = take(2) { path.addLine(to: CGPoint(x: v[0], y: v[1])) }
            case "Q":
                while let v = take(4) {
                    path.addQuadCurve(to: CGPoint(x: v[2], y: v[3]), control: CGPoint(x: v[0], y: v[1]))
                }
            case "C":
                while let v = take(6) {
                    path.addCurve(to: CGPoint(x: v[4], y: v[5]), control1: CGPoint(x: v[0], y: v[1]),
                                  control2: CGPoint(x: v[2], y: v[3]))
                }
            case "Z":
                path.closeSubpath()
            default:
                break
            }
            nums.removeAll(keepingCapacity: true)
        }

        var token = ""
        func endToken() {
            if !token.isEmpty, let v = Double(token) { nums.append(CGFloat(v)) }
            token = ""
        }
        for ch in d {
            if "MLQCZ".contains(ch) {
                endToken()
                flush()
                cmd = ch
                if ch == "Z" { flush(); cmd = " " }
            } else if ch == " " || ch == "," {
                endToken()
            } else if ch == "-" && !token.isEmpty && token.last != "e" {
                endToken()
                token.append(ch)
            } else {
                token.append(ch)
            }
        }
        endToken()
        flush()
        return path
    }
}
