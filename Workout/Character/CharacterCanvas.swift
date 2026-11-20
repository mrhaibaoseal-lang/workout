import SwiftUI

/// 角色：用關節座標在 Canvas 上即時繪製（移植自 docs/character-design.html 的 drawGear）。
struct CharacterView: View {
    let move: CharacterMove
    let loadout: Loadout
    var animated: Bool = true
    var showStats: Bool = true
    /// 屬性換算的戰力，加在裝備戰力上。
    var bonusPower: Int = 0

    var body: some View {
        TimelineView(.animation(paused: !animated)) { timeline in
            Canvas { context, size in
                let now: Double = animated ? timeline.date.timeIntervalSinceReferenceDate : 0.7
                let t = CGFloat(now)
                let p: CGFloat = animated ? CGFloat(0.5 - 0.5 * cos(2.0 * Double.pi * now / 2.6)) : 0
                CharacterRenderer.draw(&context, size: size, move: move, loadout: loadout,
                                       t: t, p: p, showStats: showStats, bonusPower: bonusPower)
            }
        }
        .aspectRatio(180.0 / 204.0, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: - 畫筆（200 單位座標 -> 畫布）

private struct Pen {
    let k: CGFloat
    let tf: CGAffineTransform

    init(size: CGSize) {
        let vw: CGFloat = 180
        let vh: CGFloat = 204
        let s = min(size.width / vw, size.height / vh)
        let ox = (size.width - vw * s) / 2
        let oy = (size.height - vh * s) / 2
        k = s
        tf = CGAffineTransform(translationX: ox, y: oy).scaledBy(x: s, y: s).translatedBy(x: -20, y: 14)
    }

    func map(_ p: CGPoint) -> CGPoint { p.applying(tf) }

    func fill(_ c: inout GraphicsContext, _ path: Path, _ col: Color) {
        c.fill(path.applying(tf), with: .color(col))
    }

    func stroke(_ c: inout GraphicsContext, _ path: Path, _ col: Color, _ w: CGFloat,
                cap: CGLineCap = .round, join: CGLineJoin = .round, dash: [CGFloat] = []) {
        let style = StrokeStyle(lineWidth: w * k, lineCap: cap, lineJoin: join, dash: dash.map { $0 * k })
        c.stroke(path.applying(tf), with: .color(col), style: style)
    }

    func line(_ c: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ w: CGFloat, _ col: Color,
              cap: CGLineCap = .round) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        stroke(&c, path, col, w, cap: cap)
    }

    func circle(_ c: inout GraphicsContext, _ ctr: CGPoint, _ r: CGFloat,
                fill fillCol: Color? = nil, stroke strokeCol: Color? = nil, sw: CGFloat = 0) {
        let path = Path(ellipseIn: CGRect(x: ctr.x - r, y: ctr.y - r, width: r * 2, height: r * 2))
        if let f = fillCol { fill(&c, path, f) }
        if let s = strokeCol { stroke(&c, path, s, sw) }
    }

    func ellipse(_ c: inout GraphicsContext, _ ctr: CGPoint, _ rx: CGFloat, _ ry: CGFloat,
                 fill fillCol: Color? = nil, stroke strokeCol: Color? = nil, sw: CGFloat = 0) {
        let path = Path(ellipseIn: CGRect(x: ctr.x - rx, y: ctr.y - ry, width: rx * 2, height: ry * 2))
        if let f = fillCol { fill(&c, path, f) }
        if let s = strokeCol { stroke(&c, path, s, sw) }
    }

    func rect(_ c: inout GraphicsContext, _ r: CGRect, _ radius: CGFloat,
              fill fillCol: Color? = nil, stroke strokeCol: Color? = nil, sw: CGFloat = 0) {
        let path = Path(roundedRect: r, cornerRadius: radius)
        if let f = fillCol { fill(&c, path, f) }
        if let s = strokeCol { stroke(&c, path, s, sw, join: .round) }
    }

    /// 在模糊圖層內作畫（std 為 200 單位座標下的標準差）。
    func blur(_ c: inout GraphicsContext, _ std: CGFloat, _ body: (inout GraphicsContext) -> Void) {
        c.drawLayer { (layer: inout GraphicsContext) in
            layer.addFilter(.blur(radius: std * k))
            body(&layer)
        }
    }
}

// MARK: - 小工具

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

private func sub(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }

private func hyp(_ a: CGPoint) -> CGFloat { (a.x * a.x + a.y * a.y).squareRoot() }

private func frac(_ v: CGFloat) -> CGFloat { v.truncatingRemainder(dividingBy: 1) }

private func rot(_ p: CGPoint, _ a: CGFloat) -> CGPoint {
    CGPoint(x: p.x * cos(a) - p.y * sin(a), y: p.x * sin(a) + p.y * cos(a))
}

private func poly(_ pts: [CGPoint], close: Bool = true) -> Path {
    var path = Path()
    guard let first = pts.first else { return path }
    path.move(to: first)
    for q in pts.dropFirst() { path.addLine(to: q) }
    if close { path.closeSubpath() }
    return path
}

/// 與 SVG 的 A（橢圓弧）指令相同的語意，用折線近似。
private func arcTo(_ path: inout Path, from a: CGPoint, to b: CGPoint, rx: CGFloat, ry: CGFloat,
                   large: Bool, sweep: Bool) {
    let x1 = a.x / rx
    let y1 = a.y / ry
    let x2 = b.x / rx
    let y2 = b.y / ry
    let mx = (x1 + x2) / 2
    let my = (y1 + y2) / 2
    let dx = x2 - x1
    let dy = y2 - y1
    let len = max((dx * dx + dy * dy).squareRoot(), 0.000001)
    let h = len / 2
    var dist: CGFloat = 0
    if h < 1 { dist = (1 - h * h).squareRoot() }
    let nx = -dy / len
    let ny = dx / len
    let sign: CGFloat = (sweep != large) ? 1 : -1
    let cx = mx + nx * dist * sign
    let cy = my + ny * dist * sign
    let th1 = atan2(y1 - cy, x1 - cx)
    let th2 = atan2(y2 - cy, x2 - cx)
    var delta = th2 - th1
    let twoPi = CGFloat.pi * 2
    if sweep {
        while delta < 0 { delta += twoPi }
    } else {
        while delta > 0 { delta -= twoPi }
    }
    let steps = 24
    for i in 1...steps {
        let th = th1 + delta * CGFloat(i) / CGFloat(steps)
        path.addLine(to: CGPoint(x: (cx + cos(th)) * rx, y: (cy + sin(th)) * ry))
    }
}

/// 肢體的錐形四邊形（軀幹用）。
private func quadPath(_ a: CGPoint, _ b: CGPoint, _ wa: CGFloat, _ wb: CGFloat) -> Path {
    let d = sub(b, a)
    var l = hyp(d)
    if l == 0 { l = 1 }
    let nx = -d.y / l
    let ny = d.x / l
    return poly([
        pt(a.x + nx * wa, a.y + ny * wa),
        pt(b.x + nx * wb, b.y + ny * wb),
        pt(b.x - nx * wb, b.y - ny * wb),
        pt(a.x - nx * wa, a.y - ny * wa)
    ])
}

private struct DrawShape {
    let isTorso: Bool
    let a: CGPoint
    let b: CGPoint
    let w: CGFloat
    let color: Color
    let far: Bool
    let base: String
}

// MARK: - 繪製

enum CharacterRenderer {
    private static let K = Color(gearHex: "#0A0D12")
    private static let skin = Color(gearHex: "#E9BE9C")
    private static let nearSkin = Color(gearHex: "#E3B48F")
    private static let farSkin = Color(gearHex: "#BF8F6C")
    private static let fg = Color(gearHex: "#E7EBF0")
    private static let lineGrey = Color(gearHex: "#2C3440")

    fileprivate static func draw(_ c: inout GraphicsContext, size: CGSize, move: CharacterMove,
                                 loadout: Loadout, t: CGFloat, p: CGFloat, showStats: Bool,
                                 bonusPower: Int = 0) {
        guard size.width > 1, size.height > 1 else { return }
        let pen = Pen(size: size)
        let P = move.pose(p)
        let O: CGFloat = 6
        let rr = loadout.topRarity
        let bonus = loadout.setBonus
        let rc: Color
        if let b = bonus {
            rc = Color(gearHex: b.series.glow)
        } else if let r = Rarity(rawValue: rr) {
            rc = r.color
        } else {
            rc = lineGrey
        }

        // 覆蓋色
        var cover: [String: String] = [:]
        var stripe: [String: String] = [:]
        var sglow: [String: Bool] = [:]
        for slot in [GearSlot.top, GearSlot.bottom] {
            if let it = loadout.item(slot) {
                for k in it.cover {
                    cover[k] = it.c
                    if let c2 = it.c2 { stripe[k] = c2 }
                    if it.glow { sglow[k] = true }
                }
            }
        }
        let shoe = loadout.item(.feet)
        if let s = shoe { cover["foot"] = s.c }

        // 形狀
        var shapes: [DrawShape] = []
        for seg in BodySegments.all {
            var col: Color
            if let hex = cover[seg.base] {
                col = Color(gearHex: hex)
            } else if seg.base == "neck" {
                col = skin
            } else {
                col = seg.far ? farSkin : nearSkin
            }
            let extraW: CGFloat = (seg.base == "foot" && shoe != nil) ? 3 : 0
            let w = seg.width + extraW
            if seg.isTorso {
                shapes.append(DrawShape(isTorso: true, a: P.hip, b: P.sh, w: w, color: col, far: false, base: seg.base))
            } else {
                shapes.append(DrawShape(isTorso: false, a: P.point(seg.from, far: seg.far),
                                        b: P.point(seg.to, far: seg.far), w: w, color: col,
                                        far: seg.far, base: seg.base))
            }
        }

        let fxItem = loadout.item(.fx)
        let fxSeries: Series? = fxItem.flatMap { GearCatalog.seriesById($0.series) }

        // 地面光暈
        let groundX = P.an.x - 2
        let hasR = rr > 0
        pen.blur(&c, 5) { (l: inout GraphicsContext) in
            pen.ellipse(&l, pt(groundX, 186), 46, 7, fill: hasR ? rc.opacity(0.45) : lineGrey)
        }
        pen.ellipse(&c, pt(groundX, 186), 30, 3.5, fill: hasR ? rc.opacity(0.9) : lineGrey.opacity(0.8))

        // 後層特效
        if let it = fxItem, let se = fxSeries {
            fxLayer(&c, pen, fx: it.form, P: P, col: Color(gearHex: se.c2), col2: Color(gearHex: se.c3), t: t, front: false)
        }

        // 裝備造型（GearArt）
        let gear = gearParts(loadout, kind: move.gearKind)
        let goblet = move.gearKind == .goblet

        // 背部物件（身體後方）
        drawParts(&c, pen, gear, z: .back, P: P, t: t, goblet: goblet)

        // 光暈
        if rr >= 2 {
            let base: CGFloat = (bonus != nil || rr >= 4) ? 0.85 : 0.6
            let pulse: CGFloat = 0.85 + 0.15 * sin(t * 2.86)
            let auraCol = rc.opacity(Double(base * pulse))
            pen.blur(&c, 5) { (l: inout GraphicsContext) in
                silhouette(&l, pen, shapes, head: P.head, extra: O + 12, color: auraCol)
            }
        }

        // 彩色外框與黑色描邊
        silhouette(&c, pen, shapes, head: P.head, extra: O + (rr > 0 ? 5 : 0), color: rr > 0 ? rc : fg)
        silhouette(&c, pen, shapes, head: P.head, extra: O, color: K)

        // 肢體填色（每段畫完接著畫掛在這段上的裝備）
        for sh in shapes {
            defer {
                if let an = anchorFor(sh.base) {
                    let set: Set<GearPart.Anchor> = an == .fore ? [.fore, .fist] : [an]
                    drawParts(&c, pen, gear, z: .limb, P: P, t: t, goblet: goblet, anchors: set,
                              side: sh.far ? .far : .near)
                }
            }
            if !sh.isTorso {
                fillLimb(&c, pen, sh, stripe: stripe, glow: sglow)
            } else {
                pen.fill(&c, quadPath(sh.a, sh.b, 10, 16), sh.color)
                pen.stroke(&c, quadPath(sh.a, sh.b, 10, 16), sh.color, 2)
                pen.circle(&c, sh.b, 15, fill: sh.color)
                pen.circle(&c, sh.a, 10, fill: sh.color)
                if let sc = stripe["torso"] {
                    let col = Color(gearHex: sc)
                    let a = mix(sh.a, sh.b, 0.05)
                    let b = mix(sh.a, sh.b, 1.02)
                    if sglow["torso"] == true {
                        pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                            pen.line(&l, a, b, 6, col)
                        }
                    }
                    pen.line(&c, a, b, 3, col)
                }
                pen.line(&c, mix(sh.a, sh.b, 0.72), mix(sh.a, sh.b, 0.6), 2, Color.black.opacity(0.18))
                pen.line(&c, mix(sh.a, sh.b, 0.18), mix(sh.a, sh.b, 0.42), 2, Color.black.opacity(0.12))
            }
        }

        // 沒穿下身時畫一件內褲（初始角色只有內褲）
        if loadout.item(.bottom) == nil {
            let briefs = Color(gearHex: "#34477A")
            let band = Color(gearHex: "#C9D3E6")
            let farHip = P.point(.hip, far: true)
            pen.line(&c, farHip, mix(farHip, P.point(.kn, far: true), 0.26), 17, briefs)
            pen.circle(&c, P.hip, 11, fill: briefs)
            pen.line(&c, P.hip, mix(P.hip, P.sh, 0.2), 22, briefs)
            pen.line(&c, P.hip, mix(P.hip, P.kn, 0.26), 19, briefs)
            let d = sub(P.sh, P.hip)
            var l = hyp(d)
            if l == 0 { l = 1 }
            let n = pt(-d.y / l * 11, d.x / l * 11)
            let w = mix(P.hip, P.sh, 0.2)
            pen.line(&c, pt(w.x - n.x, w.y - n.y), pt(w.x + n.x, w.y + n.y), 3, band)
        }

        // 高光線
        for sh in shapes where !sh.isTorso && !sh.far && sh.w >= 11 {
            highlight(&c, pen, sh)
        }

        // 肩甲與胸前紋章
        if let tp = loadout.item(.top) {
            drawTopDetails(&c, pen, tp, P: P)
        }

        // 疊在所有肢段上面的裝備（毛領、腰帶、法袍下襬…）
        drawParts(&c, pen, gear, z: .over, P: P, t: t, goblet: goblet)

        // 頭
        drawHead(&c, pen, loadout.item(.head), P: P, t: t)

        // 手舉過頭（肩推）時，手臂要壓在頭上面，跟啞鈴同一層
        // 只重畫近側手臂；上臂從中段開始，避免黑框切過軀幹。遠側手臂留在頭後面。
        if min(P.el.y, P.ha.y) < P.head.y + 13 {
            let arms: [DrawShape] = shapes.compactMap { sh in
                guard !sh.far, sh.base == "upper" || sh.base == "fore" else { return nil }
                let a = sh.base == "upper" ? mix(sh.a, sh.b, 0.55) : sh.a
                return DrawShape(isTorso: false, a: a, b: sh.b, w: sh.w, color: sh.color, far: false, base: sh.base)
            }
            for sh in arms {
                pen.line(&c, sh.a, sh.b, sh.w + O, K)
            }
            for sh in arms {
                fillLimb(&c, pen, sh, stripe: stripe, glow: sglow)
                if sh.w >= 11 { highlight(&c, pen, sh) }
            }
            drawParts(&c, pen, gear, z: .limb, P: P, t: t, goblet: goblet, anchors: [.fore, .fist], side: .near)
        }

        // 啞鈴
        drawParts(&c, pen, gear, z: .grip, P: P, t: t, goblet: goblet)

        // 喝水的水壺：從手往嘴巴的方向
        if move == .drink {
            let mouth = pt(P.head.x + 8, P.head.y + 4)
            let d = sub(mouth, P.ha)
            let l = max(hyp(d), 1)
            let u = pt(d.x / l, d.y / l)
            let a = pt(P.ha.x - u.x * 6, P.ha.y - u.y * 6)
            let b = pt(P.ha.x + u.x * 14, P.ha.y + u.y * 14)
            let cap = pt(b.x + u.x * 5, b.y + u.y * 5)
            pen.line(&c, a, b, 12.5, K)
            pen.line(&c, a, b, 10, Color(gearHex: "#5BC8F5"))
            pen.line(&c, b, cap, 8.5, K)
            pen.line(&c, b, cap, 6, Color(gearHex: "#E9EDF2"))
            let n = pt(-u.y * 2.5, u.x * 2.5)
            pen.line(&c, pt(a.x + u.x * 3 + n.x, a.y + u.y * 3 + n.y), pt(b.x - u.x * 2 + n.x, b.y - u.y * 2 + n.y),
                     2, Color.white.opacity(0.55))
        }

        // 前層特效
        if let it = fxItem, let se = fxSeries {
            fxLayer(&c, pen, fx: it.form, P: P, col: Color(gearHex: se.c2), col2: Color(gearHex: se.c3), t: t, front: true)
        }

        // 文字
        if showStats {
            let k = pen.k
            if rr > 0 {
                let name: String
                if let b = bonus {
                    name = b.series.name + "套裝"
                } else {
                    name = Rarity(rawValue: rr)?.name ?? ""
                }
                let txt = Text(name).font(.system(size: 9 * k, weight: .bold)).tracking(1.5 * k).foregroundColor(rc)
                c.draw(txt, at: pen.map(pt(176, 2)), anchor: .bottomTrailing)
            }
            let pw = Text("戰力 \(loadout.power + bonusPower)").font(.system(size: 11 * k, weight: .bold)).foregroundColor(fg)
            c.draw(pw, at: pen.map(pt(176, 14)), anchor: .bottomTrailing)
        }
    }

    // MARK: 裝備造型

    private enum PartSide { case near, far, both }

    private static func anchorFor(_ base: String) -> GearPart.Anchor? {
        switch base {
        case "torso": return .torso
        case "thigh": return .thigh
        case "shin": return .shin
        case "foot": return .foot
        case "upper": return .upper
        case "fore": return .fore
        default: return nil
        }
    }

    /// 目前穿戴的所有造型；沒有啞鈴裝備時用預設啞鈴，徒手動作不畫啞鈴。
    private static func gearParts(_ loadout: Loadout, kind: GearKind) -> [GearPart] {
        var out: [GearPart] = []
        for slot in GearSlot.allCases {
            if slot == .bell && kind == .bare { continue }
            if let it = loadout.item(slot) {
                out += GearArt.parts(it.id)
            } else if slot == .bell {
                out += GearArt.parts("default.bell")
            }
        }
        return out
    }

    /// 局部座標 → 200 單位座標。y 正向＝前面／上面。
    private static func gearFrame(_ a: GearPart.Anchor, P: Joints, far: Bool, t: CGFloat, goblet: Bool) -> CGAffineTransform {
        func q(_ j: JointName) -> CGPoint { P.point(j, far: far) }
        func unit(_ v: CGPoint) -> CGPoint {
            let l = hyp(v)
            return l == 0 ? pt(1, 0) : pt(v.x / l, v.y / l)
        }
        func make(_ o: CGPoint, _ x: CGPoint, _ y: CGPoint) -> CGAffineTransform {
            CGAffineTransform(a: x.x, b: x.y, c: y.x, d: y.y, tx: o.x, ty: o.y)
        }
        func seg(_ a: JointName, _ b: JointName, ccw: Bool) -> CGAffineTransform {
            let x = unit(sub(q(b), q(a)))
            return make(q(a), x, ccw ? pt(x.y, -x.x) : pt(-x.y, x.x))
        }
        switch a {
        case .torso: return seg(.hip, .sh, ccw: false)
        case .nape:
            let x0 = unit(sub(q(.sh), q(.hip)))
            let ang = sin(t * 2.2) * 3 * .pi / 180
            let x = pt(x0.x * cos(ang) - x0.y * sin(ang), x0.x * sin(ang) + x0.y * cos(ang))
            return make(q(.sh), x, pt(-x.y, x.x))
        case .thigh: return seg(.hip, .kn, ccw: true)
        case .shin: return seg(.kn, .an, ccw: true)
        case .foot: return seg(.an, .to, ccw: true)
        case .upper: return seg(.sh, .el, ccw: true)
        case .fore: return seg(.el, .ha, ccw: true)
        case .fist:
            let x = unit(sub(q(.ha), q(.el)))
            return make(q(.ha), x, pt(x.y, -x.x))
        case .grip:
            return goblet ? make(q(.ha), pt(0, -1), pt(-1, 0)) : make(q(.ha), pt(1, 0), pt(0, -1))
        }
    }

    private static func drawParts(_ c: inout GraphicsContext, _ pen: Pen, _ parts: [GearPart], z: GearPart.Z,
                                  P: Joints, t: CGFloat, goblet: Bool,
                                  anchors: Set<GearPart.Anchor>? = nil, side: PartSide = .both) {
        for part in parts where part.z == z {
            if let a = anchors, !a.contains(part.anchor) { continue }
            // 高腳杯深蹲只抱一顆啞鈴
            let wantFar = part.far && !(part.anchor == .grip && goblet) && side != .near
            if wantFar {
                let tf = gearFrame(part.anchor, P: P, far: true, t: t, goblet: goblet).concatenating(pen.tf)
                c.drawLayer { (l: inout GraphicsContext) in
                    l.addFilter(.colorMultiply(Color(white: 0.72)))
                    part.layers.draw(&l, transform: tf, scale: pen.k)
                }
            }
            if side != .far {
                let tf = gearFrame(part.anchor, P: P, far: false, t: t, goblet: goblet).concatenating(pen.tf)
                part.layers.draw(&c, transform: tf, scale: pen.k)
            }
        }
    }

    // MARK: 肢體

    private static func fillLimb(_ c: inout GraphicsContext, _ pen: Pen, _ sh: DrawShape,
                                 stripe: [String: String], glow: [String: Bool]) {
        pen.line(&c, sh.a, sh.b, sh.w, sh.color)
        if let sc = stripe[sh.base] {
            let col = Color(gearHex: sc)
            let a = mix(sh.a, sh.b, 0.08)
            let b = mix(sh.a, sh.b, 0.92)
            if glow[sh.base] == true {
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.line(&l, a, b, 5, col)
                }
            }
            pen.line(&c, a, b, 2.6, col)
        }
        if sh.far {
            pen.line(&c, sh.a, sh.b, sh.w, Color.black.opacity(0.22))
        }
    }

    private static func highlight(_ c: inout GraphicsContext, _ pen: Pen, _ sh: DrawShape) {
        let d = sub(sh.b, sh.a)
        var l = hyp(d)
        if l == 0 { l = 1 }
        let nx = -d.y / l * sh.w * 0.25
        let ny = d.x / l * sh.w * 0.25
        let sgn: CGFloat = nx < 0 ? 1 : -1
        let a = pt(sh.a.x + nx * sgn, sh.a.y + ny * sgn)
        let b = pt(sh.b.x + nx * sgn, sh.b.y + ny * sgn)
        pen.line(&c, mix(a, b, 0.2), mix(a, b, 0.75), 2.5, Color.white.opacity(0.35))
    }

    // MARK: 輪廓

    private static func silhouette(_ c: inout GraphicsContext, _ pen: Pen, _ shapes: [DrawShape],
                                   head: CGPoint, extra: CGFloat, color: Color) {
        for sh in shapes {
            if !sh.isTorso {
                pen.line(&c, sh.a, sh.b, sh.w + extra, color)
            } else {
                let e = extra / 2
                let q = quadPath(sh.a, sh.b, 10 + e, 16 + e)
                pen.fill(&c, q, color)
                pen.stroke(&c, q, color, 2 + e)
                pen.circle(&c, sh.b, 15 + e, fill: color)
                pen.circle(&c, sh.a, 10 + e, fill: color)
            }
        }
        pen.circle(&c, head, 13 + extra / 2, fill: color)
    }

    // MARK: 上衣細節

    private static func drawTopDetails(_ c: inout GraphicsContext, _ pen: Pen, _ tp: GearItem, P: Joints) {
        let col = Color(gearHex: tp.c)
        let e2 = Color(gearHex: tp.c2 ?? tp.c)
        if tp.pauldron {
            var outer = Path()
            let s1 = pt(P.sh.x - 13, P.sh.y + 4)
            outer.move(to: s1)
            arcTo(&outer, from: s1, to: pt(P.sh.x + 13, P.sh.y + 4), rx: 13, ry: 13, large: false, sweep: true)
            outer.closeSubpath()
            pen.fill(&c, outer, col)
            pen.stroke(&c, outer, K, 3)
            var inner = Path()
            let s2 = pt(P.sh.x - 9, P.sh.y - 2)
            inner.move(to: s2)
            arcTo(&inner, from: s2, to: pt(P.sh.x + 9, P.sh.y - 2), rx: 10, ry: 10, large: false, sweep: true)
            pen.stroke(&c, inner, e2, 2)
        }
        guard let em = tp.emblem else { return }
        let d = sub(P.sh, P.hip)
        var l = hyp(d)
        if l == 0 { l = 1 }
        var nx = -d.y / l
        var ny = d.x / l
        if nx < 0 { nx = -nx; ny = -ny }
        let c0 = mix(P.hip, P.sh, 0.68)
        let ex = c0.x + nx * 8
        let ey = c0.y + ny * 8
        switch em {
        case "core":
            pen.blur(&c, 2.5) { (lc: inout GraphicsContext) in
                pen.circle(&lc, pt(ex, ey), 6, fill: e2)
            }
            pen.circle(&c, pt(ex, ey), 4.5, fill: e2, stroke: K, sw: 1.8)
            pen.circle(&c, pt(ex, ey), 1.8, fill: Color.white)
        case "chevron":
            let path = poly([pt(ex - 4, ey - 3), pt(ex, ey + 1), pt(ex + 4, ey - 3)], close: false)
            pen.stroke(&c, path, e2, 2.6)
        case "star":
            var pts: [CGPoint] = []
            var cur = pt(ex, ey - 6)
            pts.append(cur)
            let rel: [(CGFloat, CGFloat)] = [(1.8, 3.8), (4.2, 0.6), (-3, 2.9), (0.7, 4.2), (-3.7, -2),
                                             (-3.7, 2), (0.7, -4.2), (-3, -2.9), (4.2, -0.6)]
            for (dx, dy) in rel {
                cur = pt(cur.x + dx, cur.y + dy)
                pts.append(cur)
            }
            let path = poly(pts)
            pen.fill(&c, path, e2)
            pen.stroke(&c, path, K, 1.4)
        case "diamond":
            let path = poly([pt(ex, ey - 6), pt(ex + 4, ey), pt(ex, ey + 6), pt(ex - 4, ey)])
            pen.blur(&c, 2.5) { (lc: inout GraphicsContext) in
                pen.fill(&lc, path, e2)
            }
            pen.fill(&c, path, e2)
            pen.stroke(&c, path, K, 1.4)
        case "rune":
            var path = Path()
            path.move(to: pt(ex - 3, ey - 6))
            path.addLine(to: pt(ex - 3, ey + 6))
            path.move(to: pt(ex - 3, ey - 2))
            path.addLine(to: pt(ex + 3, ey - 6))
            path.move(to: pt(ex - 3, ey + 2))
            path.addLine(to: pt(ex + 3, ey + 6))
            pen.blur(&c, 2.5) { (lc: inout GraphicsContext) in
                pen.stroke(&lc, path, e2, 3)
            }
            pen.stroke(&c, path, e2, 1.8)
        default:
            break
        }
    }

    // MARK: 頭

    private static func drawHead(_ c: inout GraphicsContext, _ pen: Pen, _ hd: GearItem?, P: Joints, t: CGFloat) {
        let hx = P.head.x
        let hy = P.head.y
        pen.circle(&c, P.head, 13, fill: skin)
        var chin = Path()
        chin.move(to: pt(hx - 9, hy + 8))
        chin.addQuadCurve(to: pt(hx + 11, hy + 6), control: pt(hx, hy + 15))
        pen.stroke(&c, chin, Color.black.opacity(0.12), 3)

        var ey = hy - 1
        var eyes = true
        if let hd = hd {
            let col = Color(gearHex: hd.c)
            let col2 = Color(gearHex: hd.c2 ?? hd.c)
            switch hd.form {
            case "band":
                let tail1 = pt(hx - 24, hy + 3 + sin(t * 4) * 2)
                let tail2 = pt(hx - 22, hy - 9 + sin(t * 4 + 1) * 2)
                pen.line(&c, pt(hx - 15, hy - 3), tail1, 6, K)
                pen.line(&c, pt(hx - 15, hy - 3), tail1, 3, col2)
                pen.line(&c, pt(hx - 15, hy - 4), tail2, 6, K)
                pen.line(&c, pt(hx - 15, hy - 4), tail2, 3, col2)
                var r = Path()
                r.addRect(CGRect(x: hx - 13, y: hy - 9, width: 26, height: 6))
                pen.fill(&c, r, col)
                pen.stroke(&c, r, K, 2.5, join: .miter)
                pen.circle(&c, P.head, 14.5, stroke: K, sw: 3)
            case "cap":
                ey = hy + 2
                pen.line(&c, pt(hx + 5, hy - 3), pt(hx + 24, hy - 1), 5, K)
                pen.line(&c, pt(hx + 5, hy - 3), pt(hx + 24, hy - 1), 2.5, col)
                var dome = Path()
                let s = pt(hx - 14.5, hy - 2)
                dome.move(to: s)
                arcTo(&dome, from: s, to: pt(hx + 14.5, hy - 2), rx: 14.5, ry: 14.5, large: false, sweep: true)
                dome.closeSubpath()
                pen.fill(&c, dome, col)
                pen.stroke(&c, dome, K, 3)
            case "beanie":
                ey = hy + 2
                var dome = Path()
                let s = pt(hx - 14.5, hy - 1)
                dome.move(to: s)
                arcTo(&dome, from: s, to: pt(hx + 14.5, hy - 1), rx: 14.5, ry: 16, large: false, sweep: true)
                dome.closeSubpath()
                pen.fill(&c, dome, col)
                pen.stroke(&c, dome, K, 3)
                pen.rect(&c, CGRect(x: hx - 15, y: hy - 5, width: 30, height: 6), 2, fill: col2, stroke: K, sw: 2.5)
                pen.circle(&c, pt(hx - 2, hy - 17), 4.5, fill: col2, stroke: K, sw: 2.5)
            case "crown":
                let path = poly([
                    pt(hx - 11, hy - 10), pt(hx - 12, hy - 23), pt(hx - 5, hy - 16), pt(hx, hy - 27),
                    pt(hx + 5, hy - 16), pt(hx + 12, hy - 23), pt(hx + 11, hy - 10)
                ])
                pen.fill(&c, path, col)
                pen.stroke(&c, path, K, 2.5)
                pen.circle(&c, pt(hx, hy - 14), 2.6, fill: Color(gearHex: "#C8302C"), stroke: K, sw: 1.2)
            case "visor":
                eyes = false
                let r = CGRect(x: hx - 3, y: hy - 6, width: 19, height: 7)
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.rect(&l, r, 3.5, fill: col)
                }
                pen.rect(&c, r, 3.5, fill: col, stroke: K, sw: 2.2)
                pen.line(&c, pt(hx - 3, hy - 3), pt(hx - 14, hy - 4), 3, K)
            case "helmet":
                eyes = false
                pen.circle(&c, P.head, 15, fill: col, stroke: K, sw: 3)
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.line(&l, pt(hx - 6, hy - 15), pt(hx + 4, hy - 15), 4, col2)
                }
                pen.line(&c, pt(hx - 8, hy - 15.5), pt(hx + 6, hy - 15.5), 2, K)
                let r = CGRect(x: hx + 1, y: hy - 4, width: 15, height: 6)
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.rect(&l, r, 3, fill: col2)
                }
                pen.rect(&c, r, 3, fill: col2, stroke: K, sw: 2)
                pen.line(&c, pt(hx - 10, hy + 6), pt(hx - 2, hy + 9), 2, K.opacity(0.5))
            case "hood":
                var outer = Path()
                let s = pt(hx + 10, hy - 12)
                outer.move(to: s)
                let e = pt(hx + 8, hy + 14)
                arcTo(&outer, from: s, to: e, rx: 17, ry: 17, large: true, sweep: false)
                let m = pt(hx + 3, hy + 9)
                outer.addLine(to: m)
                arcTo(&outer, from: m, to: pt(hx + 4, hy - 9), rx: 10, ry: 11, large: false, sweep: true)
                outer.closeSubpath()
                pen.fill(&c, outer, col)
                pen.stroke(&c, outer, K, 3)
                var inner = Path()
                inner.move(to: pt(hx + 1, hy + 3))
                inner.addQuadCurve(to: pt(hx + 14, hy + 3), control: pt(hx + 8, hy + 2))
                inner.addLine(to: pt(hx + 12, hy + 10))
                inner.addQuadCurve(to: pt(hx + 2, hy + 9), control: pt(hx + 5, hy + 13))
                inner.closeSubpath()
                pen.fill(&c, inner, col2)
                pen.stroke(&c, inner, K, 2)
            case "circlet":
                var arc = Path()
                arc.move(to: pt(hx - 13, hy - 5))
                arc.addQuadCurve(to: pt(hx + 13, hy - 6), control: pt(hx, hy - 10))
                pen.stroke(&c, arc, K, 5)
                pen.stroke(&c, arc, col, 2.6)
                let gem = poly([pt(hx + 9, hy - 13), pt(hx + 12, hy - 8), pt(hx + 9, hy - 3), pt(hx + 6, hy - 8)])
                pen.fill(&c, gem, col2)
                pen.stroke(&c, gem, K, 1.6)
            case "horns":
                var dome = Path()
                let s = pt(hx - 14.5, hy - 2)
                dome.move(to: s)
                arcTo(&dome, from: s, to: pt(hx + 14.5, hy - 2), rx: 14.5, ry: 14.5, large: false, sweep: true)
                dome.closeSubpath()
                pen.fill(&c, dome, col2)
                pen.stroke(&c, dome, K, 3)
                for sx in [CGFloat(-1), CGFloat(1)] {
                    var horn = Path()
                    horn.move(to: pt(hx + sx * 6, hy - 12))
                    horn.addQuadCurve(to: pt(hx + sx * 17, hy - 32), control: pt(hx + sx * 20, hy - 18))
                    horn.addQuadCurve(to: pt(hx + sx * 1, hy - 14), control: pt(hx + sx * 13, hy - 20))
                    horn.closeSubpath()
                    pen.fill(&c, horn, col)
                    pen.stroke(&c, horn, K, 2.4)
                }
                pen.line(&c, pt(hx - 12, hy - 4), pt(hx + 12, hy - 4), 2, Color(gearHex: "#3DF5A0"))
            case "tiara":
                for i in -1...1 {
                    let fi = CGFloat(i)
                    let bx = hx + fi * 9
                    let lift: CGFloat = (i == 0) ? 6 : 0
                    let by = hy - 20 - lift + sin(t * 2.5 + fi) * 2
                    let gem = poly([pt(bx, by - 6), pt(bx + 3.5, by), pt(bx, by + 6), pt(bx - 3.5, by)])
                    pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                        pen.fill(&l, gem, col)
                    }
                    pen.fill(&c, gem, i == 0 ? col : col2)
                    pen.stroke(&c, gem, K, 1.4)
                }
            case "mask":
                eyes = false
                var m = Path()
                let s = pt(hx - 14, hy + 1)
                m.move(to: s)
                arcTo(&m, from: s, to: pt(hx + 14, hy + 1), rx: 14, ry: 14, large: false, sweep: true)
                m.addLine(to: pt(hx + 14, hy + 4))
                m.addQuadCurve(to: pt(hx - 14, hy + 4), control: pt(hx, hy + 16))
                m.closeSubpath()
                pen.fill(&c, m, col.opacity(0.95))
                pen.stroke(&c, m, K, 2.5)
                let r = CGRect(x: hx + 3, y: hy - 3, width: 9, height: 3)
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.rect(&l, r, 1.5, fill: col2)
                }
                pen.rect(&c, r, 1.5, fill: col2)
            default:
                break
            }
        }
        if eyes {
            var brow = Path()
            brow.move(to: pt(hx + 3, ey - 5))
            brow.addLine(to: pt(hx + 10, ey - 3))
            pen.stroke(&c, brow, K, 2.4)
            pen.rect(&c, CGRect(x: hx + 5, y: ey - 1.6, width: 5, height: 3.2), 1.6, fill: K)
        }
    }

    // MARK: 特效

    private static func fxLayer(_ c: inout GraphicsContext, _ pen: Pen, fx: String, P: Joints,
                                col: Color, col2: Color, t: CGFloat, front: Bool) {
        let cx = P.hip.x + 6
        switch fx {
        case "fire":
            for i in 0..<10 {
                if (i % 2 == 0) != front { continue }
                let fi = CGFloat(i)
                let ph = frac(t * 0.9 + fi / 10)
                let x = cx - 40 + CGFloat((i * 37) % 80) + sin(t * 3 + fi) * 3
                let y = 184 - ph * 120
                let sz = (1 - ph) * 9 + 2
                var path = Path()
                path.move(to: pt(x, y - sz * 1.8))
                path.addQuadCurve(to: pt(x, y + sz * 0.6), control: pt(x + sz, y))
                path.addQuadCurve(to: pt(x, y - sz * 1.8), control: pt(x - sz, y))
                path.closeSubpath()
                pen.fill(&c, path, (i % 3 != 0 ? col : col2).opacity(Double(0.9 - ph * 0.8)))
            }
        case "ice":
            guard front else { return }
            for i in 0..<10 {
                let fi = CGFloat(i)
                let ph = frac(t * 0.25 + fi / 10)
                let x = cx - 50 + CGFloat((i * 41) % 100) + sin(t + fi) * 6
                let y = -6 + ph * 190
                let r = CGFloat(3 + (i % 3))
                let ang = (t * 40 + fi * 20) * CGFloat.pi / 180
                let segs: [(CGPoint, CGPoint)] = [
                    (pt(-r, 0), pt(r, 0)), (pt(0, -r), pt(0, r)),
                    (pt(-r * 0.7, -r * 0.7), pt(r * 0.7, r * 0.7)),
                    (pt(-r * 0.7, r * 0.7), pt(r * 0.7, -r * 0.7))
                ]
                var path = Path()
                for (a, b) in segs {
                    let ra = rot(a, ang)
                    let rb = rot(b, ang)
                    path.move(to: pt(x + ra.x, y + ra.y))
                    path.addLine(to: pt(x + rb.x, y + rb.y))
                }
                pen.stroke(&c, path, col2.opacity(Double(sin(ph * CGFloat.pi))), 1.6)
            }
        case "bolt":
            guard front else { return }
            for i in 0..<3 {
                let fi = CGFloat(i)
                if sin(t * 9 + fi * 2.1) < 0.3 { continue }
                let x = cx - 44 + fi * 42 + sin(t * 5 + fi) * 6
                let y = 40 + CGFloat((i * 47) % 100)
                let path = poly([
                    pt(x, y), pt(x + 6, y + 10), pt(x + 1, y + 12), pt(x + 8, y + 24),
                    pt(x + 4, y + 25), pt(x + 10, y + 36)
                ], close: false)
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.stroke(&l, path, col, 2.4)
                }
                pen.stroke(&c, path, Color.white, 1.2)
            }
        case "gold":
            guard front else { return }
            for i in 0..<9 {
                let fi = CGFloat(i)
                let ph = frac(t * 0.35 + fi / 9)
                let x = cx - 50 + CGFloat((i * 53) % 110) + sin(t + fi) * 4
                let y = 180 - ph * 170
                let o = sin(ph * CGFloat.pi)
                let path = poly([
                    pt(x, y - 4), pt(x + 1.3, y - 1.3), pt(x + 4, y), pt(x + 1.3, y + 1.3),
                    pt(x, y + 4), pt(x - 1.3, y + 1.3), pt(x - 4, y), pt(x - 1.3, y - 1.3)
                ])
                pen.fill(&c, path, col.opacity(Double(o * 0.9)))
            }
        case "rays":
            guard !front else { return }
            let sx = P.sh.x
            let sy = P.sh.y
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * CGFloat.pi * 2 + t * 0.3
                let x2 = sx + cos(a) * 95
                let y2 = sy + sin(a) * 95
                let path = poly([
                    pt(sx, sy),
                    pt(x2 + cos(a + 1.57) * 9, y2 + sin(a + 1.57) * 9),
                    pt(x2 - cos(a + 1.57) * 9, y2 - sin(a + 1.57) * 9)
                ])
                pen.fill(&c, path, col.opacity(0.13))
            }
        case "magic":
            guard !front else { return }
            let x = P.an.x - 2
            let spin = t * 30 * CGFloat.pi / 180
            let xf = CGAffineTransform(translationX: x, y: 186).scaledBy(x: 1, y: 0.28).rotated(by: spin)
            let outer = Path(ellipseIn: CGRect(x: -52, y: -52, width: 104, height: 104)).applying(xf)
            let inner = Path(ellipseIn: CGRect(x: -40, y: -40, width: 80, height: 80)).applying(xf)
            let tri = poly([pt(0, -52), pt(45, 26), pt(-45, 26)]).applying(xf)
            let tri2 = poly([pt(0, 52), pt(-45, -26), pt(45, -26)]).applying(xf)
            pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                pen.stroke(&l, outer, col, 3)
            }
            pen.stroke(&c, outer, col, 2)
            pen.stroke(&c, inner, col, 2, dash: [6, 5])
            pen.stroke(&c, tri, col.opacity(0.8), 1.5)
            pen.stroke(&c, tri2, col.opacity(0.8), 1.5)
            for i in 0..<6 {
                let fi = CGFloat(i)
                let ph = frac(t * 0.5 + fi / 6)
                pen.circle(&c, pt(x - 40 + fi * 16, 186 - ph * 90), 1.8, fill: col.opacity(Double(1 - ph)))
            }
        case "scan":
            guard front else { return }
            let ph = frac(t * 0.45)
            let y = 184 - ph * 190
            let o = Double(sin(ph * CGFloat.pi))
            let ctr = pt(P.hip.x + 10, y)
            pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                pen.ellipse(&l, ctr, 42, 5, stroke: col.opacity(o), sw: 3)
            }
            pen.ellipse(&c, ctr, 42, 5, stroke: col.opacity(o), sw: 1.2)
            for i in 0..<5 {
                let yy = 10 + CGFloat(i) * 36 + (t * 20).truncatingRemainder(dividingBy: 36)
                pen.line(&c, pt(30, yy), pt(36, yy), 1.5, col.opacity(0.5))
            }
        case "rain":
            guard front else { return }
            let rainCol = Color(gearHex: "#9FB3D1").opacity(0.55)
            for i in 0..<22 {
                let fi = CGFloat(i)
                let ph = frac(t * 1.4 + fi / 22)
                let x = 26 + CGFloat((i * 67) % 170) - ph * 14
                let y = -14 + ph * 200
                pen.line(&c, pt(x, y), pt(x - 4, y + 12), 1.4, rainCol)
            }
        case "stars":
            guard front else { return }
            for i in 0..<12 {
                let fi = CGFloat(i)
                let x = 34 + CGFloat((i * 59) % 150)
                let y = -6 + CGFloat((i * 83) % 180)
                let o = 0.5 + 0.5 * sin(t * 3 + fi * 1.7)
                let r = 1.5 + CGFloat(i % 3)
                var path = Path()
                path.move(to: pt(x, y - r * 2))
                path.addQuadCurve(to: pt(x + r * 2, y), control: pt(x, y))
                path.addQuadCurve(to: pt(x, y + r * 2), control: pt(x, y))
                path.addQuadCurve(to: pt(x - r * 2, y), control: pt(x, y))
                path.addQuadCurve(to: pt(x, y - r * 2), control: pt(x, y))
                path.closeSubpath()
                pen.fill(&c, path, (i % 2 != 0 ? col : col2).opacity(Double(o)))
            }
        case "smoke":
            guard !front else { return }
            for i in 0..<8 {
                let fi = CGFloat(i)
                let ph = frac(t * 0.3 + fi / 8)
                let x = cx - 36 + CGFloat((i * 29) % 72) + sin(t * 1.5 + fi) * 8
                let y = 186 - ph * 150
                let fillCol: Color = (i % 2 != 0 ? col : Color.black).opacity(Double((1 - ph) * 0.55))
                pen.blur(&c, 2.5) { (l: inout GraphicsContext) in
                    pen.ellipse(&l, pt(x, y), 8 + ph * 10, 6 + ph * 6, fill: fillCol)
                }
            }
        default:
            break
        }
    }
}
