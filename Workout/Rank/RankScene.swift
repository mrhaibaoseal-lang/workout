import SwiftUI

/// 晉級／升段／掉段的全螢幕動畫。所有東西都是經過時間 t 的函式，點一下畫面就跳到結尾。
/// 公式和 scripts/art/badge-anim.js 的 scene() 一致，可以先在預覽 HTML 看效果。
enum RankScene {
    private typealias M = FXMath

    enum Kind { case division, tier, down }

    struct Timing {
        let boom: Double
        let impact: Double
        let title: Double
        let end: Double
    }

    static func kind(_ from: RankStep, _ to: RankStep) -> Kind {
        if to.index < from.index { return .down }
        return to.tier == from.tier ? .division : .tier
    }

    static func timing(_ k: Kind) -> Timing {
        switch k {
        case .division: Timing(boom: 1.4, impact: 1.4, title: 1.6, end: 2.8)
        case .tier: Timing(boom: 2.0, impact: 3.4, title: 3.5, end: 4.8)
        case .down: Timing(boom: 1.9, impact: 1.9, title: 2.3, end: 3.4)
        }
    }

    /// 版面：獎章中心與大小（文字也依這個排）。
    static func layout(_ size: CGSize) -> (center: CGPoint, side: Double) {
        (CGPoint(x: size.width / 2, y: size.height * 0.4), min(size.width * 0.62, 260))
    }

    static func draw(_ c: inout GraphicsContext, size: CGSize, from: RankStep, to: RankStep, t: Double) {
        let kind = kind(from, to), S = timing(kind)
        let W = size.width, H = size.height
        let (center, sz) = layout(size)
        let cx = center.x, cy = center.y, k = sz / 120
        let light = to.tier.light, mid = to.tier.mid, dark = to.tier.dark
        let master = kind == .tier && to.tier == .master, champ = kind == .tier && to.tier == .champion
        let big = max(W, H)

        // 背景
        let after = M.seg(t, S.boom, S.boom + 0.6)
        let bgCol = kind == .down ? Color(gearHex: "#3A4250") : dark
        FX.glow(&c, center: center, radius: big * 0.8, color: bgCol, alpha: kind == .down ? 0.35 : 0.25 + 0.45 * after)
        if champ {
            c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)),
                   with: .linearGradient(Gradient(colors: [Color(gearHex: "#FF4A1F").opacity(0.45 * after), .clear]),
                                         startPoint: CGPoint(x: 0, y: H), endPoint: CGPoint(x: 0, y: H * 0.3)))
        }
        if kind != .down {
            let pa = kind == .division ? 0.6 * after : after
            // 光柱
            c.fill(Path(CGRect(x: cx - sz * 0.45, y: 0, width: sz * 0.9, height: H)),
                   with: .linearGradient(Gradient(colors: [light.opacity(0), light.opacity(0.28 * pa), light.opacity(0)]),
                                         startPoint: CGPoint(x: cx - sz * 0.45, y: 0), endPoint: CGPoint(x: cx + sz * 0.45, y: 0)))
            FX.rays(&c, center: center, radius: big, count: master || champ ? 18 : 14, angle: t * 0.2, color: light, alpha: 0.22 * pa)
            if master {
                FX.vortex(&c, center: center, t: t, count: 60, radius: big * 0.6, color: Color(gearHex: "#D9A6FF"),
                          alpha: 0.4 + 0.6 * M.seg(t, 0.4, S.boom))
            }
            if champ { FX.embers(&c, size: size, t: t, count: 50, alpha: 0.3 + 0.7 * M.seg(t, 0.5, S.boom)) }
            if t < S.boom {
                FX.converge(&c, center: center, t: t, radius: sz * 1.2, color: light, count: 40, alpha: M.seg(t, 0.4, S.boom))
            }
        } else {
            FX.dust(&c, size: size, t: t, count: 30, alpha: M.seg(t, 0.6, 1.4))
        }
        // 背後光暈
        let glow = kind == .down ? 0.2
            : 0.2 + 0.5 * M.seg(t, 0.4, S.boom) * (t < S.boom ? 1 : 0) + 0.45 * after
        FX.glow(&c, center: center, radius: sz * 0.75, color: kind == .down ? Color(gearHex: "#9AA5B1") : light, alpha: glow)

        // 獎章
        var shake = 0.0, punch = 1.0, gray = 0.0
        var fx = BadgeFX()
        var step = from
        var hide = false
        if kind == .down {
            if t < S.boom {
                fx.assemble = M.seg(t, 0, 0.5)
                fx.drop = M.seg(t, 0.7, S.boom)
                shake = 1.5 * max(0, 1 - abs(t - 1.1) * 1.4)
                gray = M.seg(t, 0.7, S.boom) * 0.85
            } else {
                // 掉段：新獎章安靜地淡入，不飛入、不灑彩帶
                step = to
                fx.alpha = M.seg(t, S.boom, S.boom + 0.5)
                fx.idle = true
                fx.t = t - S.boom
                fx.particles = 0.5 * M.seg(t, S.boom + 0.6, S.boom + 1.2)
                punch = 0.9 + 0.1 * M.easeOutCubic(M.seg(t, S.boom, S.boom + 0.6))
                gray = 0.6 * (1 - M.seg(t, 2.2, 2.9))
                if let a = from.division, let b = to.division, from.tier == to.tier {
                    fx.numFlip = (a, b, M.seg(t, 2.0, 2.4))
                }
            }
        } else if t < S.boom {
            let ch = M.seg(t, 0.4, S.boom)
            fx.assemble = M.seg(t, 0, 0.45)
            fx.flash = 0.85 * pow(ch, 3)
            shake = (kind == .division ? 2 : 3.5) * ch * ch
        } else {
            step = to
            if kind == .tier {
                let e = M.seg(t, S.boom, S.boom + 0.9)
                if e < 1 {
                    var g = c
                    g.translateBy(x: cx - 60 * k, y: cy - 58 * k)
                    g.scaleBy(x: k, y: k)
                    var old = BadgeFX()
                    old.explode = e
                    old.flash = 0.9 * (1 - e)
                    BadgeRenderer.draw(&g, tier: from.tier.rawValue, division: from.division, fx: old)
                }
                fx.assemble = M.seg(t, S.boom + 0.2, S.impact)
                fx.crownDrop = master || champ ? 260 : 110
                hide = fx.assemble <= 0
            } else {
                fx.assemble = M.seg(t, S.boom, S.boom + 0.9)
                fx.keepCore = true
                fx.flash = 0.9 * (1 - M.seg(t, S.boom, S.boom + 0.3))
                if let a = from.division, let b = to.division { fx.numFlip = (a, b, M.seg(t, S.boom + 0.1, S.boom + 0.5)) }
            }
            let ti = max(0, t - S.impact)
            if t >= S.impact { punch = 1 + 0.18 * exp(-ti * 6) * cos(ti * 18) }
            fx.idle = t >= S.impact
            fx.t = ti
            fx.particles = M.seg(t, S.impact, S.impact + 0.6)
            fx.sheen = -1
        }
        if !hide {
            let fxBadge = fx
            let sx = shake * sin(t * 61), sy = shake * cos(t * 47)
            c.drawLayer { (g: inout GraphicsContext) in
                if gray > 0 {
                    g.addFilter(.saturation(1 - gray))
                    g.addFilter(.brightness(-0.12 * gray))
                }
                g.translateBy(x: cx + sx * k, y: cy + sy * k)
                g.scaleBy(x: k * punch, y: k * punch)
                g.translateBy(x: -60, y: -58)
                BadgeRenderer.draw(&g, tier: step.tier.rawValue, division: step.division, fx: fxBadge)
            }
        }

        // 衝擊波、白光、彩帶
        if kind != .down {
            FX.ring(&c, center: center, progress: M.seg(t, S.boom, S.boom + 0.7), maxRadius: big * 0.9, color: .white)
            if kind == .tier {
                FX.ring(&c, center: center, progress: M.seg(t, S.impact, S.impact + 0.8), maxRadius: big * 0.7, color: light)
            }
            let fl = kind == .division ? 0.6 : 1.0
            let a = fl * (1 - M.seg(t, S.boom, S.boom + 0.5)) * (t >= S.boom ? 1 : 0)
            if a > 0 { c.fill(Path(CGRect(x: 0, y: 0, width: W, height: H)), with: .color(.white.opacity(a))) }
            FX.confetti(&c, center: center, tau: t - S.impact - 0.05, count: kind == .division ? 45 : 90,
                        colors: [light, mid, Color(gearHex: "#FFD54A"), .white, Theme.accent], height: H)
        }
    }

    /// 觸覺節奏：蓄力越來越密、爆開重擊、落地成功。
    static func haptics(_ kind: Kind) -> [(Double, HapticScript.Kind)] {
        let S = timing(kind)
        switch kind {
        case .down:
            return [(0.75, .light), (1.0, .light), (1.3, .medium), (S.boom, .warning)]
        case .division, .tier:
            var list: [(Double, HapticScript.Kind)] = []
            var x = 0.45, gap = 0.28
            while x < S.boom - 0.05 {
                list.append((x, .light))
                x += gap
                gap = max(0.07, gap * 0.82)
            }
            list.append((S.boom, .heavy))
            if kind == .tier {
                list.append((S.boom + 0.15, .rigid))
                list.append((S.impact, .heavy))
            }
            list.append((S.impact + 0.12, .success))
            return list
        }
    }
}

/// 晉級／降級時跳出來的畫面。
struct RankChangeView: View {
    let from: RankStep
    let to: RankStep
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var skip: Double = 0
    @State private var haptics = HapticScript()

    private var kind: RankScene.Kind { RankScene.kind(from, to) }
    private var S: RankScene.Timing { RankScene.timing(kind) }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSince(start) + skip
                ZStack {
                    Canvas { c, size in
                        RankScene.draw(&c, size: size, from: from, to: to, t: t)
                    }
                    texts(t: t, size: geo.size)
                }
            }
        }
        .background(Theme.bg)
        .ignoresSafeArea()
        .overlay(alignment: .bottom) { okButton }
        .contentShape(Rectangle())
        .onTapGesture { jumpToEnd() }
        .onAppear {
            start = Date()
            if reduceMotion {
                skip = S.end
            } else {
                haptics.play(RankScene.haptics(kind))
            }
        }
        .onDisappear { haptics.cancel() }
        .statusBarHidden()
    }

    private var title: String {
        switch kind {
        case .down: "掉段了"
        case .division: "升段！"
        case .tier: to.tier == .master ? "大師降臨！" : to.tier == .champion ? "登上王者！" : "晉級！"
        }
    }

    @ViewBuilder
    private func texts(t: Double, size: CGSize) -> some View {
        let lay = RankScene.layout(size)
        let center = lay.center, sz = lay.side
        let tp = FXMath.seg(t, S.title, S.title + 0.35)
        let np = FXMath.seg(t, S.title + 0.3, S.title + 0.7)
        let sp = FXMath.seg(t, S.title + 0.6, S.title + 1)
        let down = kind == .down
        Text(title)
            .font(.system(size: 40, weight: .black))
            .foregroundStyle(down ? Theme.muted : to.tier.light)
            .shadow(color: down ? .clear : to.tier.mid.opacity(0.9), radius: 14)
            .scaleEffect(down ? 1 : 1 + 1.5 * (1 - FXMath.easeOutBack(tp)))
            .opacity(tp)
            .position(x: center.x, y: center.y - sz * 0.72)
        Text(to.title)
            .font(.system(size: 26, weight: .heavy))
            .foregroundStyle(Theme.fg)
            .opacity(np)
            .position(x: center.x, y: center.y + sz * 0.62 + 20 * (1 - FXMath.easeOutCubic(np)))
        Text(down ? "沒關係，這週多練一次就拿回來。" : "繼續保持，下一段在等你。")
            .font(.callout)
            .foregroundStyle(Theme.muted)
            .opacity(sp)
            .position(x: center.x, y: center.y + sz * 0.62 + 46)
    }

    private var okButton: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSince(start) + skip
            let a = FXMath.seg(t, S.title + 0.9, S.title + 1.2)
            Button("好") { dismiss() }
                .buttonStyle(HotButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .opacity(a)
                .offset(y: 30 * (1 - FXMath.easeOutCubic(a)))
                .allowsHitTesting(a > 0.5)
        }
    }

    private func jumpToEnd() {
        let now = Date().timeIntervalSince(start) + skip
        guard now < S.end else { return }
        skip += S.end - now
        haptics.cancel()
    }
}
