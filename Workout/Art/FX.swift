import SwiftUI
import UIKit

// 全螢幕特效：旋轉光芒、衝擊波、彩帶、聚氣光點、火星、漩渦、灰塵。
// 晉級畫面、開箱、破紀錄、完成訓練共用；全部只靠時間算出來（同一個 t 永遠畫出同一格）。
// 公式和 scripts/art/badge-anim.js 的同名函式一致。
enum FX {
    private typealias M = FXMath

    /// 從中心放射的光芒，ang 是目前角度（弧度）。
    static func rays(_ c: inout GraphicsContext, center: CGPoint, radius R: Double, count n: Int,
                     angle ang: Double, color: Color, alpha a: Double) {
        guard a > 0.01 else { return }
        let shading = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [color.opacity(a), color.opacity(0)]), center: center, startRadius: 0, endRadius: R)
        var p = Path()
        for i in 0..<n {
            let a0 = ang + Double(i) * M.tau / Double(n), h = M.tau / Double(n) * 0.28
            p.move(to: center)
            p.addLine(to: CGPoint(x: center.x + R * cos(a0 - h), y: center.y + R * sin(a0 - h)))
            p.addLine(to: CGPoint(x: center.x + R * cos(a0 + h), y: center.y + R * sin(a0 + h)))
            p.closeSubpath()
        }
        c.fill(p, with: shading)
    }

    /// 衝擊波圓環，q = 0…1。
    static func ring(_ c: inout GraphicsContext, center: CGPoint, progress q: Double, maxRadius: Double,
                     color: Color, width: Double = 16) {
        guard q > 0 && q < 1 else { return }
        let r = M.easeOutCubic(q) * maxRadius
        c.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                 with: .color(color.opacity(1 - q)), lineWidth: width * (1 - q) + 1)
    }

    /// 彩帶從 center 噴出後飄落，tau = 噴出後經過的秒數。
    static func confetti(_ c: inout GraphicsContext, center: CGPoint, tau: Double, count n: Int,
                         colors: [Color], height H: Double, power: Double = 1) {
        guard tau > 0 else { return }
        for j in 0..<n {
            let r1 = M.rnd(j, 31), r2 = M.rnd(j, 32), r3 = M.rnd(j, 33), r4 = M.rnd(j, 34), r5 = M.rnd(j, 35)
            let vx = (r1 - 0.5) * 900 * power, vy = -(350 + r2 * 650) * power
            let k = (1 - exp(-2.5 * tau)) / 2.5
            let x = center.x + vx * k + sin(tau * 3 + r3 * 6) * 18 * tau
            let y = center.y + vy * k + 300 * tau * tau / (1 + tau)
            if y > H + 20 { continue }
            let a = M.clamp(3.2 - tau)
            var g = c
            g.translateBy(x: x, y: y)
            g.rotate(by: .radians(r3 * M.tau + tau * (r4 - 0.5) * 16))
            g.scaleBy(x: abs(cos(tau * (5 + r5 * 6))) + 0.15, y: 1)
            let col = colors[j % colors.count].opacity(a)
            if j % 3 == 0 {
                g.fill(Path(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8)), with: .color(col))
            } else {
                g.fill(Path(CGRect(x: -4, y: -7, width: 8, height: 14)), with: .color(col))
            }
        }
    }

    /// 蓄力：光點從四周往中心收。
    static func converge(_ c: inout GraphicsContext, center: CGPoint, t: Double, radius R: Double,
                         color: Color, count n: Int, alpha a: Double) {
        guard a > 0.01 else { return }
        for j in 0..<n {
            let an = M.rnd(j, 41) * M.tau, u = M.fract(t / 0.7 + M.rnd(j, 42))
            let r = R * (1 - M.easeInCubic(u)) + 10, r2 = r + 26 * (1 - u) + 6
            var p = Path()
            p.move(to: CGPoint(x: center.x + r * cos(an), y: center.y + r * sin(an)))
            p.addLine(to: CGPoint(x: center.x + r2 * cos(an), y: center.y + r2 * sin(an)))
            c.stroke(p, with: .color(color.opacity(u * a)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    /// 從畫面底部往上飄的火星。
    static func embers(_ c: inout GraphicsContext, size: CGSize, t: Double, count n: Int, alpha a: Double) {
        guard a > 0.01 else { return }
        let hot = Color(gearHex: "#FFE08A"), red = Color(gearHex: "#FF3A1A")
        for j in 0..<n {
            let per = 2 + M.rnd(j, 52) * 2, u = M.fract(t / per + M.rnd(j, 53))
            let x = M.rnd(j, 51) * size.width + sin(t * 2 + Double(j)) * 20
            let y = size.height + 10 - u * size.height * 1.1
            BadgeRenderer.dot(&c, x, y, 1.5 + M.rnd(j, 54) * 2.5, M.mix(hot, red, u), sin(.pi * u) * a)
        }
    }

    /// 往中心捲進去的漩渦光點。
    static func vortex(_ c: inout GraphicsContext, center: CGPoint, t: Double, count n: Int, radius R: Double,
                       color: Color, alpha a: Double) {
        guard a > 0.01 else { return }
        for j in 0..<n {
            let u = M.fract(t / 2.6 + M.rnd(j, 61)), an = M.rnd(j, 62) * M.tau + u * M.tau * 1.2 + t * 0.3
            let r = R * (1 - u)
            BadgeRenderer.dot(&c, center.x + r * cos(an), center.y + r * sin(an) * 0.8, 1.2 + 2 * (1 - u), color,
                              sin(.pi * u) * a)
        }
    }

    /// 慢慢落下的灰塵（掉段）。
    static func dust(_ c: inout GraphicsContext, size: CGSize, t: Double, count n: Int, alpha a: Double) {
        guard a > 0.01 else { return }
        let gray = Color(gearHex: "#8A94A3")
        for j in 0..<n {
            let u = M.fract(t / (3 + M.rnd(j, 72) * 2) + M.rnd(j, 73))
            BadgeRenderer.dot(&c, M.rnd(j, 71) * size.width, -10 + u * (size.height + 20), 1 + M.rnd(j, 74) * 1.5,
                              gray, sin(.pi * u) * a * 0.6)
        }
    }

    /// 往外噴的光點（破紀錄、開箱）。
    static func sparkBurst(_ c: inout GraphicsContext, center: CGPoint, tau: Double, count n: Int, speed: Double,
                           colors: [Color]) {
        guard tau > 0 && tau < 1.6 else { return }
        for j in 0..<n {
            let an = M.rnd(j, 81) * M.tau, v = speed * (0.5 + M.rnd(j, 82))
            let d = v * (1 - exp(-3 * tau)) / 3
            let x = center.x + d * cos(an), y = center.y + d * sin(an) + 40 * tau * tau
            BadgeRenderer.dot(&c, x, y, 2 + M.rnd(j, 83) * 2.5, colors[j % colors.count], M.clamp(1.4 - tau))
        }
    }

    /// 柔和的圓形光暈。
    static func glow(_ c: inout GraphicsContext, center: CGPoint, radius r: Double, color: Color, alpha a: Double) {
        guard a > 0.01 else { return }
        c.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [color.opacity(a), color.opacity(0)]),
                                     center: center, startRadius: 0, endRadius: r))
    }
}

/// 觸覺回饋排程：照時間點觸發，畫面消失就停止。
@MainActor
final class HapticScript {
    private var items: [DispatchWorkItem] = []

    enum Kind { case light, medium, heavy, rigid, success, warning }

    func play(_ list: [(Double, Kind)]) {
        cancel()
        for (t, k) in list {
            let w = DispatchWorkItem {
                switch k {
                case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
                case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                case .heavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                case .rigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
                case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            }
            items.append(w)
            DispatchQueue.main.asyncAfter(deadline: .now() + t, execute: w)
        }
    }

    func cancel() {
        items.forEach { $0.cancel() }
        items.removeAll()
    }
}
