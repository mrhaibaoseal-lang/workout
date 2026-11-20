import SwiftUI
import UIKit

// 牌位獎章的動畫：待機動作、粒子、反光、轉場（組裝／炸開／掉落）。
// 公式和預覽用的 scripts/art/badge-anim.js 一一對應；改一邊要改另一邊。
// 動作與粒子的參數表由 scripts/art/badges.js 產生在 RankBadgeArt.swift。

/// 一個部位的一種動作。kind 對照 badges.js 的 KIND。
struct BadgeOp {
    let part: Int
    let kind: Int
    let a: Double
    let p: Double
    let st: Double

    init(_ part: Int, _ kind: Int, _ a: Double, _ p: Double, _ st: Double) {
        self.part = part
        self.kind = kind
        self.a = a
        self.p = p
        self.st = st
    }
}

/// 一組粒子。k 對照 badges.js 的 PK。
struct BadgeParticles {
    let k: Int
    let n: Int
    let c: Color
    let c2: Color
    let s: Double
    let p: Double
    let r: Double
    let h: Double
    let y: Double

    init(_ k: Int, _ n: Int, _ c: String, _ c2: String, _ s: Double, _ p: Double, _ r: Double, _ h: Double, _ y: Double) {
        self.k = k
        self.n = n
        self.c = Color(gearHex: c)
        self.c2 = Color(gearHex: c2)
        self.s = s
        self.p = p
        self.r = r
        self.h = h
        self.y = y
    }
}

// MARK: - 共用數學

enum FXMath {
    static let tau = Double.pi * 2

    static func clamp(_ x: Double, _ a: Double = 0, _ b: Double = 1) -> Double { max(a, min(b, x)) }
    static func fract(_ x: Double) -> Double { x - x.rounded(.down) }
    /// 固定亂數：同樣的 (i, salt) 永遠得到同一個 0…1 的值，所以整個動畫可以只靠時間算出來。
    static func rnd(_ i: Int, _ salt: Double = 0) -> Double {
        fract(sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453)
    }
    static func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeInCubic(_ x: Double) -> Double { x * x * x }
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
    static func easeOutBounce(_ x0: Double) -> Double {
        let n = 7.5625, d = 2.75
        var x = x0
        if x < 1 / d { return n * x * x }
        if x < 2 / d { x -= 1.5 / d; return n * x * x + 0.75 }
        if x < 2.5 / d { x -= 2.25 / d; return n * x * x + 0.9375 }
        x -= 2.625 / d
        return n * x * x + 0.984375
    }
    static func smooth(_ x0: Double) -> Double { let x = clamp(x0); return x * x * (3 - 2 * x) }
    /// t 在 a…b 之間的進度（0…1）。
    static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
    /// 用力的節奏：快速衝到 1、停一下、慢慢放掉。
    static func env(_ t: Double, _ p: Double) -> Double {
        let u = (t.truncatingRemainder(dividingBy: p) + p).truncatingRemainder(dividingBy: p)
        if u < 0.12 { return easeOutCubic(u / 0.12) }
        if u < 0.32 { return 1 }
        if u < 0.8 { return 1 - smooth((u - 0.32) / 0.48) }
        return 0
    }
    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let x = UIColor(a), y = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        x.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        y.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(clamp(t))
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k), blue: Double(b1 + (b2 - b1) * k))
    }
}

// MARK: - 轉場與待機的參數

/// 畫一枚獎章時的動畫狀態。全部都是數字，所以同一個時間點永遠畫出同一個樣子。
struct BadgeFX {
    /// 待機動畫的時間（秒）
    var t: Double = 0
    /// 要不要套用待機動作
    var idle = false
    /// 粒子透明度 0…1
    var particles: Double = 0
    /// 反光：nil 不畫、-1 依週期自動掃、0…1 指定位置
    var sheen: Double? = nil
    /// 組裝進度 0…1（1 = 完整）
    var assemble: Double = 1
    /// 組裝時底座和手臂已經在了（升小段只飛入配件）
    var keepCore = false
    /// 炸開進度 0…1
    var explode: Double = 0
    /// 掉段時配件掉落 0…1
    var drop: Double = 0
    /// 整枚變白 0…1
    var flash: Double = 0
    /// 整體透明度
    var alpha: Double = 1
    /// 皇冠從多高落下
    var crownDrop: Double = 110
    /// 小段數字翻牌：(舊, 新, 進度)
    var numFlip: (from: Int, to: Int, p: Double)? = nil

    static let still = BadgeFX()
}

// MARK: - 繪製

enum BadgeRenderer {
    private typealias M = FXMath

    /// 部位分組：轉場時誰先出現。0 底座、1 手臂與核心、2 配件、3 光暈星光、4 皇冠
    private static func group(_ part: Int) -> Int {
        switch part {
        case 0: 0
        case 10, 11, 13: 1
        case 1, 12, 14: 3
        case 8: 4
        default: 2
        }
    }
    private static let window: [(Double, Double)] = [(0, 0.35), (0.25, 0.6), (0.35, 0.8), (0.6, 0.95), (0.7, 1)]

    /// 待機動作：繞支點的變形與透明度。
    private static func motion(_ l: ArtLayer, _ ops: [BadgeOp], _ t: Double) -> (CGAffineTransform, Double) {
        guard l.part != 0, !ops.isEmpty else { return (.identity, 1) }
        var tx = 0.0, ty = 0.0, rot = 0.0, sx = 1.0, sy = 1.0, alpha = 1.0
        let sg: Double = l.mirrored ? -1 : 1
        let i = Double(l.index)
        let toRad = Double.pi / 180
        for o in ops where o.part == l.part {
            let ph = t + i * o.st
            let w = sin(M.tau * ph / o.p)
            switch o.kind {
            case 0: rot += o.a * t * toRad
            case 1: rot += sg * o.a * w * toRad
            case 2: sx *= 1 + o.a * w; sy *= 1 + o.a * w
            case 3: ty += o.a * (0.5 + 0.5 * w)
            case 4:
                let v = 0.5 + 0.5 * w, s = 0.4 + 0.8 * v * v
                sx *= s; sy *= s; alpha *= 0.3 + 0.7 * v
            case 5:
                let s = 1 + o.a * M.env(ph, o.p)
                sx *= s; sy *= s
            case 6:
                sy *= 1 + o.a * (0.6 * sin(t * 11 + i * o.st * 3) + 0.4 * sin(t * 17.3 + i * 2.1))
                rot += 0.05 * sin(t * 9 + i)
            case 7: alpha *= 0.15 + 0.85 * M.env(ph, o.p)
            case 8: rot += sg * o.a * M.env(ph, o.p) * toRad
            case 9: tx += sg * o.a * M.env(ph, o.p) * sin(t * 70)
            case 10: alpha *= 1 - o.a + o.a * (0.5 + 0.5 * w)
            case 11:
                let dx = Double(l.pivot.x) - 60, dy = Double(l.pivot.y) - 58
                let n = max(0.0001, hypot(dx, dy)), v = o.a * (0.5 + 0.5 * w)
                tx += dx / n * v; ty += dy / n * v
            default: break
            }
        }
        let px = l.pivot.x, py = l.pivot.y
        let m = CGAffineTransform(translationX: tx, y: ty)
            .translatedBy(x: px, y: py)
            .rotated(by: rot)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -px, y: -py)
        return (m, alpha)
    }

    /// 轉場中的位移（組裝、炸開、掉落），繞圖層中心。
    private static func transit(_ l: ArtLayer, _ j: Int, _ fx: BadgeFX) -> (CGAffineTransform, Double) {
        var tx = 0.0, ty = 0.0, rot = 0.0, s = 1.0, alpha = fx.alpha
        let g = group(l.part)
        let b = l.bounds
        var cx = Double(b.midX), cy = Double(b.midY)
        var dx = cx - 60, dy = cy - 58
        var n = hypot(dx, dy)
        if n < 6 {
            let a = M.rnd(j, 3) * M.tau
            dx = cos(a); dy = sin(a); n = 1
        }
        dx /= n; dy /= n
        if fx.assemble < 1 && !(fx.keepCore && g <= 1) {
            let (w0, w1) = window[g]
            let st = g == 2 ? Double(j % 7) / 7 * 0.12 : 0
            let lp = M.seg(fx.assemble, w0 + st, min(1, w1 + st))
            switch g {
            case 0:
                s *= max(0, M.easeOutBack(lp)); alpha *= M.clamp(lp * 3); cx = 60; cy = 58
            case 1:
                s *= 1 + 1.2 * (1 - M.easeOutCubic(lp)); alpha *= M.clamp(lp * 2)
            case 4:
                ty += -fx.crownDrop * (1 - M.easeOutBounce(lp)); alpha *= M.clamp(lp * 4)
            default:
                let e = M.easeOutBack(lp), d = 90 + M.rnd(j, 5) * 40
                tx += dx * d * (1 - e); ty += dy * d * (1 - e)
                rot += (M.rnd(j, 7) - 0.5) * 2.1 * (1 - e); alpha *= M.clamp(lp * 2)
            }
        }
        if fx.explode > 0 {
            let e = fx.explode, d = 150 * M.easeOutCubic(e) * (0.6 + 0.8 * M.rnd(j, 11))
            tx += dx * d; ty += dy * d + 80 * e * e
            rot += (M.rnd(j, 13) - 0.5) * 9.4 * e; s *= 1 - 0.3 * e; alpha *= 1 - pow(e, 1.5)
        }
        if fx.drop > 0 && g >= 2 {
            let lp = M.clamp(fx.drop * 1.6 - M.rnd(j, 17) * 0.6)
            ty += 140 * lp * lp; rot += (M.rnd(j, 19) - 0.5) * 1.05 * lp; alpha *= 1 - lp
        }
        let m = CGAffineTransform(translationX: tx, y: ty)
            .translatedBy(x: cx, y: cy)
            .rotated(by: rot)
            .scaledBy(x: s, y: s)
            .translatedBy(x: -cx, y: -cy)
        return (m, alpha)
    }

    /// 整枚變白：剪影（光暈、半透明層不算，免得變成白色圓盤）。
    private static func paintWhite(_ l: ArtLayer, _ c: inout GraphicsContext, _ w: Double) {
        guard w > 0.001 else { return }
        let p = l.path
        switch l.fill {
        case .radial: return
        case .linear: c.fill(p, with: .color(.white.opacity(min(1, w))))
        case .solid(_, let a): if a >= 0.3 { c.fill(p, with: .color(.white.opacity(min(1, w)))) }
        }
        if l.stroke != nil && l.width > 0 {
            c.stroke(p, with: .color(.white.opacity(min(1, w))),
                     style: StrokeStyle(lineWidth: l.width, lineCap: .round, lineJoin: .round))
        }
    }

    /// 在 120×120 座標系畫一枚獎章（呼叫前先把 context 縮放好）。
    static func draw(_ c: inout GraphicsContext, tier: Int, division: Int?, fx: BadgeFX) {
        let looks = RankBadgeArt.tiers[tier]
        let lv = division.map { 3 - $0 } ?? (looks.count - 1)
        let layers = looks[max(0, min(looks.count - 1, lv))]
        let ops = fx.idle ? RankBadgeArt.motion[tier] : []
        let t = fx.t
        if fx.particles > 0 { particles(&c, RankBadgeArt.particles[tier], t, front: false, fade: fx.particles) }
        var clipPath = Path()
        for (j, l) in layers.enumerated() {
            let (mm, ma) = motion(l, ops, t)
            let (tm, ta) = transit(l, j, fx)
            let a = ta * ma
            if a <= 0.001 && fx.flash <= 0 { continue }
            let m = mm.concatenating(tm)
            var g = c
            g.concatenate(m)
            l.draw(&g, alpha: a)
            paintWhite(l, &g, fx.flash * ta)
            if l.clip { clipPath.addPath(l.path, transform: m) }
        }
        // 反光掃過：只畫在獎章輪廓裡
        if let sh = fx.sheen, !clipPath.isEmpty {
            let (per, str) = RankBadgeArt.sheen[tier]
            let u = sh < 0 ? t.truncatingRemainder(dividingBy: per) / (per * 0.45) : sh
            if u >= 0 && u <= 1 {
                c.drawLayer { (l: inout GraphicsContext) in
                    l.clip(to: clipPath)
                    l.translateBy(x: -30 + 180 * u, y: 58)
                    l.rotate(by: .radians(0.35))
                    l.blendMode = .plusLighter
                    l.fill(Path(CGRect(x: -14, y: -90, width: 28, height: 180)),
                           with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(str), .white.opacity(0)]),
                                                 startPoint: CGPoint(x: -14, y: 0), endPoint: CGPoint(x: 14, y: 0)))
                }
            }
        }
        if fx.particles > 0 { particles(&c, RankBadgeArt.particles[tier], t, front: true, fade: fx.particles) }
        // 緞帶＋羅馬數字（畫在粒子上面，小段永遠看得清楚）
        if let d = division {
            let fake = ArtLayer("M38 96 L82 112", .solid("#FFFFFF", 0), part: 10)
            let (tm, ta) = transit(fake, 99, fx)
            var g = c
            g.concatenate(tm)
            for l in RankBadgeArt.ribbons[tier] {
                l.draw(&g, alpha: ta)
                paintWhite(l, &g, fx.flash * ta)
            }
            var n = d, sy = 1.0, wh = 0.0
            if let nf = fx.numFlip, nf.p < 1 {
                let p = M.clamp(nf.p)
                if p < 0.5 { n = nf.from; sy = 1 - p * 2 } else { n = nf.to; sy = p * 2 - 1 }
                wh = 1 - abs(p - 0.5) * 2
            }
            g.translateBy(x: 60, y: 104)
            g.scaleBy(x: 1, y: max(0.01, sy))
            g.translateBy(x: -60, y: -104)
            for l in RankBadgeArt.numerals[max(0, min(3, n))] {
                l.draw(&g, alpha: ta)
                paintWhite(l, &g, max(wh, fx.flash) * ta)
            }
        }
    }

    // MARK: 粒子

    static func dot(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ col: Color, _ a: Double) {
        guard a > 0.01 else { return }
        var g = c
        g.blendMode = .plusLighter
        let r0 = max(0.1, r)
        g.fill(Path(ellipseIn: CGRect(x: x - r0, y: y - r0, width: r0 * 2, height: r0 * 2)), with: .color(col.opacity(a)))
        let r1 = r * 2.4
        g.fill(Path(ellipseIn: CGRect(x: x - r1, y: y - r1, width: r1 * 2, height: r1 * 2)), with: .color(col.opacity(a * 0.25)))
    }

    static func star4(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ col: Color, _ a: Double) {
        guard a > 0.01 else { return }
        var p = Path()
        for k in 0..<8 {
            let rr = k % 2 == 1 ? r * 0.22 : r, an = Double(k) * .pi / 4 - .pi / 2
            let pt = CGPoint(x: x + rr * cos(an), y: y + rr * sin(an))
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        c.fill(p, with: .color(col.opacity(a)))
    }

    // MARK: 進階粒子（金牌以上越來越多）

    private static func star4r(_ c: inout GraphicsContext, _ x: Double, _ y: Double, _ r: Double, _ rot: Double,
                               _ col: Color, _ a: Double) {
        var g = c
        g.translateBy(x: x, y: y)
        g.rotate(by: .radians(rot))
        star4(&g, 0, 0, r, col, a)
    }

    /// 斜軌道橢圓上的點：r、h 半軸，tilt 傾斜（弧度）
    private static func orbitPt(_ r: Double, _ h: Double, _ tilt: Double, _ a: Double) -> CGPoint {
        let ex = r * cos(a), ey = h * sin(a)
        return CGPoint(x: 60 + ex * cos(tilt) - ey * sin(tilt), y: 58 + ex * sin(tilt) + ey * cos(tilt))
    }

    private static func line(_ pts: [CGPoint]) -> Path {
        var p = Path()
        for (k, pt) in pts.enumerated() {
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    /// kind 8 以上：噴發、彗星、符文環、擴散波、閃電、鏡頭光芒、火舌、光柱。
    private static func fancy(_ c0: inout GraphicsContext, _ q: BadgeParticles, _ si: Double, _ t: Double,
                              front: Bool, fade: Double) {
        var c = c0
        c.blendMode = .plusLighter
        let round = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
        func stroke(_ p: Path, _ col: Color, _ w: Double) {
            var st = round
            st.lineWidth = w
            c.stroke(p, with: .color(col), style: st)
        }
        switch q.k {
        case 8: // burst：每次用力，從獎章邊緣往外噴出光條
            guard front else { return }
            let u = (t.truncatingRemainder(dividingBy: q.p) + q.p).truncatingRemainder(dividingBy: q.p)
            guard u <= 0.9 else { return }
            let e = M.easeOutCubic(min(1, u / 0.6)), a = (1 - u / 0.9) * fade
            for j in 0..<q.n {
                let an = M.rnd(j, si + 81) * M.tau, d = 28 + (q.r - 28) * (0.4 + 0.6 * M.rnd(j, si + 82)) * e
                let x = 60 + d * cos(an), y = 56 + d * sin(an) + 10 * u * u
                let len = 3 + 7 * (1 - u)
                stroke(line([CGPoint(x: x, y: y), CGPoint(x: x - len * cos(an), y: y - len * sin(an))]),
                       M.mix(q.c, q.c2, u / 0.9).opacity(a), q.s)
                dot(&c, x, y, q.s * 0.45, .white, a)
            }
        case 9: // comet：斜軌道上的彗星，拖一條漸淡的尾巴
            for j in 0..<q.n {
                let tilt = Double(j) / Double(q.n) * .pi + 0.35, an = M.tau * (t / q.p + Double(j) * 0.37)
                for k in stride(from: 15, through: 0, by: -1) {
                    let a = an - Double(k) * 0.06
                    guard (sin(a) > 0) == front else { continue }
                    let pt = orbitPt(q.r, q.h, tilt, a), f = 1 - Double(k) / 16
                    dot(&c, pt.x, pt.y, q.s * (0.2 + 0.5 * f), k == 0 ? .white : M.mix(q.c, q.c2, Double(k) / 16), pow(f, 1.5) * fade)
                }
            }
        case 10: // halo：旋轉的符文環，後半圈較暗
            let tilt = q.y * .pi / 180, off = M.tau * t / q.p, seg = M.tau / Double(q.n)
            if !front {
                stroke(line((0...48).map { orbitPt(q.r, q.h, tilt, Double($0) / 48 * M.tau) }), q.c.opacity(0.12 * fade), q.s * 0.6)
            }
            for i in 0..<q.n {
                let a0 = off + Double(i) * seg, mid = a0 + seg * 0.3
                guard (sin(mid) > 0) == front else { continue }
                let len = i % 3 == 0 ? 0.75 : 0.4
                stroke(line((0...4).map { orbitPt(q.r, q.h, tilt, a0 + seg * len * Double($0) / 4) }),
                       q.c.opacity(fade * (front ? 0.95 : 0.45)), q.s)
                if i % 3 == 0 {
                    let pt = orbitPt(q.r, q.h, tilt, a0 + seg * 0.9)
                    dot(&c, pt.x, pt.y, q.s * 0.9, q.c, fade * (front ? 1 : 0.5))
                }
            }
        case 11: // pulse：用力時從中心擴散的光環
            guard !front else { return }
            for j in 0..<q.n {
                let u = ((t.truncatingRemainder(dividingBy: q.p) + q.p).truncatingRemainder(dividingBy: q.p) - Double(j) * 0.18) / 1.1
                guard u > 0 && u < 1 else { continue }
                let r = q.r * M.easeOutCubic(u)
                stroke(Path(ellipseIn: CGRect(x: 60 - r, y: 58 - r, width: r * 2, height: r * 2)),
                       q.c.opacity((1 - u) * (1 - u) * fade * 0.9), q.s * (1 - u) + 0.3)
            }
        case 12: // arc：繞著獎章跳的閃電，每 0.07 秒換一次形狀
            guard front else { return }
            for j in 0..<q.n {
                let w = M.fract(t / q.p + M.rnd(j, si + 91))
                guard w <= 0.3 else { continue }
                let a = (1 - w / 0.3) * fade, seed = Int((t / 0.07).rounded(.down)) + j * 131
                let a0 = M.rnd(seed, si + 92) * M.tau
                let span = (0.7 + 0.9 * M.rnd(seed, si + 93)) * (M.rnd(seed, si + 94) > 0.5 ? 1 : -1)
                let pts = (0...7).map { k -> CGPoint in
                    let an = a0 + span * Double(k) / 7
                    let rr = q.r * (k == 0 || k == 7 ? 1 : 0.82 + 0.36 * M.rnd(seed * 8 + k, si + 95))
                    return CGPoint(x: 60 + rr * cos(an), y: 58 + rr * sin(an))
                }
                let p = line(pts)
                stroke(p, q.c.opacity(a * 0.35), 3.2)
                stroke(p, .white.opacity(a), q.s)
            }
        case 13: // flare：鏡頭光芒，慢慢轉、一明一暗
            guard front else { return }
            for j in 0..<q.n {
                let x = j > 0 ? 60 + q.r : 60 - q.r, y = j > 0 ? 58 + q.h * 0.9 : 58 - q.h
                let pl = 0.65 + 0.35 * sin(M.tau * t / q.p + Double(j) * 2), sz = q.s * pl
                dot(&c, x, y, sz * 0.22, q.c, 0.7 * fade)
                star4r(&c, x, y, sz, t * 0.4 + Double(j), q.c, 0.9 * fade * pl)
                star4r(&c, x, y, sz * 0.5, t * 0.4 + Double(j) + .pi / 4, q.c, 0.7 * fade * pl)
            }
        case 14: // flame：往上竄的火舌
            guard front else { return }
            for j in 0..<q.n {
                let r1 = M.rnd(j, si + 1), r2 = M.rnd(j, si + 2), r3 = M.rnd(j, si + 3)
                let u = M.fract(t / (q.p * (0.7 + 0.6 * r3)) + r1)
                let x = 60 + (r2 - 0.5) * q.r + sin(u * 5 + r3 * 6) * 4, y = q.y - u * q.h, s2 = q.s * (1 - u * 0.7)
                var p = Path()
                p.move(to: CGPoint(x: x, y: y - 2.2 * s2))
                p.addQuadCurve(to: CGPoint(x: x, y: y + s2), control: CGPoint(x: x + s2, y: y - 0.4 * s2))
                p.addQuadCurve(to: CGPoint(x: x, y: y - 2.2 * s2), control: CGPoint(x: x - s2, y: y - 0.4 * s2))
                c.fill(p, with: .color(M.mix(q.c, q.c2, u).opacity(sin(.pi * u) * fade * 0.85)))
            }
        case 15: // beam：背後一道道光柱，輪流亮起
            guard !front else { return }
            for j in 0..<q.n {
                let r1 = M.rnd(j, si + 1), r2 = M.rnd(j, si + 2), r3 = M.rnd(j, si + 3)
                let x = 60 + (r1 - 0.5) * q.r, w = q.s * (0.6 + 0.6 * r2)
                let a = pow(0.5 + 0.5 * sin(M.tau * (t / q.p + r3)), 2) * 0.35 * fade
                let top = 58 - q.h / 2
                c.fill(Path(CGRect(x: x - w / 2, y: top, width: w, height: q.h)),
                       with: .linearGradient(Gradient(colors: [q.c.opacity(0), q.c.opacity(a), q.c.opacity(0)]),
                                             startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x, y: top + q.h)))
            }
        default: break
        }
    }

    static func particles(_ c: inout GraphicsContext, _ specs: [BadgeParticles], _ t: Double, front: Bool, fade: Double) {
        for (si, q) in specs.enumerated() {
            let salt = Double(si * 10)
            if q.k >= 8 {
                fancy(&c, q, salt, t, front: front, fade: fade)
                continue
            }
            for j in 0..<q.n {
                let r1 = M.rnd(j, salt + 1), r2 = M.rnd(j, salt + 2), r3 = M.rnd(j, salt + 3)
                switch q.k {
                case 0, 4, 6: // mote / fall / ember
                    guard front else { continue }
                    let u = M.fract(t / (q.p * (0.7 + 0.6 * r3)) + r1)
                    let x = 60 + (r2 - 0.5) * q.r + sin(u * 6 + r3 * 6) * 5
                    let y = q.k == 4 ? -5 + u * q.h : q.y - u * q.h
                    let a = sin(.pi * u) * fade
                    if q.k == 6 {
                        dot(&c, x, y, q.s * (1 - u * 0.6), M.mix(q.c, q.c2, u), a * (0.6 + 0.4 * sin(t * 20 + Double(j))))
                    } else {
                        dot(&c, x, y, q.s, q.c, a)
                    }
                case 1, 7: // orbit / crystal
                    let an = M.tau * (t / q.p + Double(j) / Double(q.n))
                    guard (sin(an) > 0) == front else { continue }
                    let x = 60 + q.r * cos(an), y = 58 + q.h * sin(an) - 6 * cos(an)
                    let a = (0.45 + 0.55 * (0.5 + 0.5 * sin(an))) * fade
                    if q.k == 1 {
                        dot(&c, x, y, q.s, q.c, a)
                    } else {
                        var g = c
                        g.translateBy(x: x, y: y)
                        g.rotate(by: .radians(t * 2 + Double(j)))
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: -q.s))
                        p.addLine(to: CGPoint(x: q.s * 0.6, y: 0))
                        p.addLine(to: CGPoint(x: 0, y: q.s))
                        p.addLine(to: CGPoint(x: -q.s * 0.6, y: 0))
                        p.closeSubpath()
                        g.fill(p, with: .color(q.c.opacity(a)))
                    }
                case 2: // glint
                    guard front else { continue }
                    let v = t / q.p + r1, cyc = Int(v.rounded(.down)), u = M.fract(v)
                    let an = M.rnd(cyc * 7 + j, Double(si) + 21) * M.tau
                    let rr = q.r * (0.55 + 0.45 * M.rnd(cyc * 7 + j, Double(si) + 22))
                    let s = pow(sin(.pi * M.clamp(u * 2.2)), 2)
                    if s > 0.01 { star4(&c, 60 + rr * cos(an), 58 + rr * sin(an), q.s * s, q.c, s * fade) }
                case 3: // spark
                    guard front else { continue }
                    let u = M.fract(t / q.p + r1)
                    guard u <= 0.55 else { continue }
                    let tt = u * q.p, vx = (r2 - 0.5) * 70, vy = -(30 + r3 * 45)
                    let x = 60 + (r2 - 0.5) * q.r + vx * tt, y = q.y + vy * tt + 70 * tt * tt
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x - vx * 0.05, y: y - (vy + 140 * tt) * 0.05))
                    c.stroke(p, with: .color(M.mix(q.c, q.c2, u / 0.55).opacity((1 - u / 0.55) * fade)),
                             style: StrokeStyle(lineWidth: q.s, lineCap: .round))
                case 5: // spiral
                    guard front else { continue }
                    let u = M.fract(t / q.p + r1), an = r2 * M.tau + u * M.tau * 1.5
                    let rr = q.r * (1 - u * 0.6)
                    dot(&c, 60 + rr * cos(an), q.y - u * q.h, q.s, q.c, sin(.pi * u) * fade * (0.5 + 0.5 * sin(an)))
                default: break
                }
            }
        }
    }
}
