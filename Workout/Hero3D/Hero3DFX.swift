import RealityKit
import UIKit
import Metal

// 3D 角色的裝備特效（fx 部位）：火焰、符文法陣、金光。
// 做法見 docs/3d-system.md「特效（fx 部位）」：固定數量的面片／小網格，每格用時間 t 的公式算位置、大小、透明度，
// 不用 RealityKit 粒子 → 同一個 t 一定是同一張圖（定格截圖、減少動態效果用 Kind.stillTime）。
//
// 公式、數量、顏色、貼圖畫法照抄 scripts/fx/fx-preview.html 的 makeFire／makeMagic／makeGold、h()、frac()、GOLDEN、glyph()；
// 改一邊要改另一邊。three.js 和 RealityKit 都是 y 朝上、單位公尺，座標直接照用。
// 掛在 Hero3DStageModel 的 fxRoot（holder 底下：跟著轉向，不跟著抬高）。

@MainActor
final class Hero3DFX {
    enum Kind: String, CaseIterable {
        case fire, magic, gold

        /// 定格截圖、減少動態效果、低電量模式用的時間點（和 fx-preview.html 的 DEFS[].still 相同）
        var stillTime: Double {
            switch self {
            case .fire: return 1.37
            case .magic: return 0.9
            case .gold: return 2.15
            }
        }
    }

    let kind: Kind
    let root = Entity()
    private var step: (Double) -> Void = { _ in }
    /// iOS 17 沒有 BillboardComponent：這些面片每格自己轉成世界座標的正面（鏡頭在 +z 方向，近似面向鏡頭）
    private var manualFacing: [Entity] = []

    init(kind: Kind) {
        self.kind = kind
        root.name = "fx_" + kind.rawValue
        switch kind {
        case .fire: step = makeFire()
        case .magic: step = makeMagic()
        case .gold: step = makeGold()
        }
    }

    /// 照公式擺好時間點 t（秒）的樣子。只看 t、不看前一格，任意 t 可以重複呼叫（定格截圖用）
    func update(t: Double) {
        step(t)
        for e in manualFacing { e.setOrientation(simd_quatf(ix: 0, iy: 0, iz: 0, r: 1), relativeTo: nil) }
    }

    // MARK: - 共用小工具（照抄 HTML）

    private static func frac(_ x: Double) -> Double { x - floor(x) }
    /// 固定雜湊：每顆的「個性」
    private static func h(_ i: Double) -> Double { frac(sin(i * 12.9898) * 43758.5453) }
    /// 黃金角：讓 N 顆平均散開
    private static let GOLDEN = 2.39996

    private static let quad = MeshResource.generatePlane(width: 1, height: 1)          // 面片：XY 平面、面向 +z
    private static let groundQuad = MeshResource.generatePlane(width: 1, depth: 1)     // 地面件：XZ 平面、面向 +y

    private static func spriteMaterial(_ tex: TextureResource?) -> UnlitMaterial {
        var m = UnlitMaterial()
        // 貼圖的透明度要在 tint alpha < 1 時才會用上（RealityKit 的老問題），所以用 0.999
        m.color = .init(tint: UIColor(white: 1, alpha: 0.999), texture: tex.map { MaterialParameters.Texture($0) })
        m.blending = .transparent(opacity: .init(floatLiteral: 1))
        if #available(iOS 18.0, *) { m.writesDepth = false }
        return m
    }

    private static func setOpacity(_ e: Entity, _ o: Double) {
        e.components.set(OpacityComponent(opacity: Float(min(1, max(0, o)))))
    }

    /// three.js 的 Sprite：面向鏡頭的面片。anchorY＝錨點離底邊的比例（Sprite.center.y）。
    /// 回傳的 pivot 負責位置、大小、透明度；面片本身是 pivot 的第一個子實體（要在畫面上旋轉時轉它）。
    private func sprite(_ tex: TextureResource?, anchorY: Float = 0.5) -> Entity {
        let pivot = Entity()
        let plane = ModelEntity(mesh: Self.quad, materials: [Self.spriteMaterial(tex)])
        plane.position.y = 0.5 - anchorY
        pivot.addChild(plane)
        if #available(iOS 18.0, *) {
            pivot.components.set(BillboardComponent())
        } else {
            manualFacing.append(pivot)
        }
        Self.setOpacity(pivot, 1)
        root.addChild(pivot)
        return pivot
    }

    /// 平躺的地面件（HTML 的 groundPlane）
    private func ground(_ size: Float, _ tex: TextureResource?, y: Float = 0.01) -> ModelEntity {
        let e = ModelEntity(mesh: Self.groundQuad, materials: [Self.spriteMaterial(tex)])
        e.scale = [size, 1, size]
        e.position.y = y
        Self.setOpacity(e, 1)
        root.addChild(e)
        return e
    }

    private static func xyz(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Float> { [Float(x), Float(y), Float(z)] }
    private static func spinY(_ a: Double) -> simd_quatf { simd_quatf(angle: Float(a), axis: [0, 1, 0]) }

    // MARK: - 1. 火焰（熔岩・史詩）：面片 18＋8＋2＝28

    private func makeFire() -> (Double) -> Void {
        let texA = Tex.flame(outer: "#FF5A1F", core: "#FFC23D"), texB = Tex.flame(outer: "#FFC23D", core: "#FFF6D8")
        let flames = (0..<18).map { i in sprite(i % 3 != 0 ? texA : texB, anchorY: 0.1) }
        let sparkTex = Tex.spark()
        let sparks = (0..<8).map { _ in sprite(sparkTex) }
        let floorE = ground(1.5, Tex.glow(255, 110, 30))
        let back = sprite(Tex.glow(255, 120, 40, 0.6))
        back.position = [0, 0.85, -0.45]
        back.scale = [1.9, 2.1, 1]
        let h = Self.h, frac = Self.frac, G = Self.GOLDEN

        return { t in
            for (i, s) in flames.enumerated() {
                let d = Double(i)
                let ph = frac(t * 0.8 + h(d))
                let a = d * G, r = (0.22 + 0.22 * h(d + 7)) * (1 + 0.5 * ph)
                s.position = Self.xyz(cos(a) * r + sin(t * 3 + d) * 0.05 * ph, ph * (0.85 + 0.55 * h(d + 3)), sin(a) * r)
                let sz = 0.12 + 0.4 * pow(1 - ph, 0.8)
                s.scale = [Float(sz * 0.62), Float(sz), 1]
                Self.setOpacity(s, min(1, ph / 0.08) * (1 - ph * 0.85))
            }
            for (i, s) in sparks.enumerated() {
                let d = Double(i)
                let ph = frac(t * 0.45 + h(d + 40)), a = d * G + 1, r = 0.3 + 0.25 * h(d + 41)
                s.position = Self.xyz(cos(a) * r + sin(t * 2 + d) * 0.08, 0.1 + ph * 1.9, sin(a) * r)
                s.scale = [0.045, 0.045, 0.045]
                Self.setOpacity(s, sin(.pi * ph) * (0.6 + 0.4 * sin(t * 20 + d)))
            }
            Self.setOpacity(floorE, 0.55 + 0.15 * sin(t * 5) + 0.06 * sin(t * 13))
            Self.setOpacity(back, 0.28 + 0.06 * sin(t * 4))
        }
    }

    // MARK: - 2. 符文法陣（符文戰神・傳說）：地面件 4＋光點 14＋符文 4＝22

    private func makeMagic() -> (Double) -> Void {
        let glow = ground(1.9, Tex.glow(61, 245, 160, 0.5), y: 0.006)
        let discO = ground(1.6, Tex.magicOuter(), y: 0.012)
        let discI = ground(1.0, Tex.magicInner(), y: 0.016)
        let pulse = ground(1, Tex.magicRing(), y: 0.02)
        let moteTex = Tex.glow(160, 255, 210, 1)
        let motes = (0..<14).map { _ in sprite(moteTex) }
        let runes = (0..<4).map { k in sprite(Tex.rune(k)) }
        let h = Self.h, frac = Self.frac

        return { t in
            discO.orientation = Self.spinY(t * 0.35)
            discI.orientation = Self.spinY(-t * 0.6)
            let pp = frac(t / 2)                                   // 每 2 秒一道擴散光環
            let ps = Float(0.5 + pp * 1.3)
            pulse.scale = [ps, 1, ps]
            Self.setOpacity(pulse, (1 - pp) * 0.8)
            Self.setOpacity(glow, 0.7 + 0.2 * sin(t * 3))
            for (i, s) in motes.enumerated() {
                let d = Double(i)
                let ph = frac(t * 0.45 + h(d + 60)), a = d / 14 * .pi * 2 + t * 0.35
                s.position = Self.xyz(cos(a) * 0.72, 0.05 + ph * 1.6, sin(a) * 0.72)
                let sc = Float(0.07 + 0.04 * h(d))
                s.scale = [sc, sc, sc]
                Self.setOpacity(s, sin(.pi * ph))
            }
            for (i, s) in runes.enumerated() {
                let d = Double(i)
                let ph = frac(t * 0.25 + d / 4), a = d * .pi / 2 + t * 0.35
                s.position = Self.xyz(cos(a) * 0.56, 0.1 + ph * 1.2, sin(a) * 0.56)
                s.scale = [0.16, 0.16, 0.16]
                Self.setOpacity(s, sin(.pi * ph))
            }
        }
    }

    // MARK: - 3. 金光（黃金・傳說）：金幣 12（小網格）＋閃光 8＋地面件 2＝22

    private func makeGold() -> (Double) -> Void {
        let coinProto = Coin.make()
        let coins: [Entity] = (0..<12).map { _ in
            let c = coinProto?.clone(recursive: true) ?? Entity()
            Self.setOpacity(c, 1)
            root.addChild(c)
            return c
        }
        let starTex = Tex.star()
        let stars = (0..<8).map { _ in sprite(starTex) }
        let glow = ground(1.7, Tex.glow(255, 200, 61, 0.55), y: 0.006)
        let ring = ground(1.35, Tex.goldRing(), y: 0.014)
        let h = Self.h, frac = Self.frac, G = Self.GOLDEN

        return { t in
            for (i, c) in coins.enumerated() {
                let d = Double(i)
                let ph = frac(t * 0.5 + h(d + 80)), a = d * G + 0.5, r = 0.46 + 0.3 * h(d + 81)
                c.position = Self.xyz(cos(a) * r, 2.35 - 2.3 * pow(ph, 1.6), sin(a) * r)   // 越落越快
                // three.js 的 rotation.set(x, y, 0)（XYZ 順序）＝ Rx · Ry：翻面
                c.orientation = simd_quatf(angle: Float(t * 5 + d * 1.3), axis: [1, 0, 0])
                    * simd_quatf(angle: Float(d * 0.9), axis: [0, 1, 0])
                Self.setOpacity(c, min(1, ph / 0.08, (1 - ph) / 0.1))
            }
            for (i, s) in stars.enumerated() {
                let d = Double(i)
                let a = d * G + 2, r = 0.42 + 0.22 * h(d + 90)
                s.position = Self.xyz(cos(a) * r, 0.3 + 1.55 * h(d + 91), sin(a) * r)
                let o = pow(max(0, sin(t * 2.4 + d * 1.9)), 4)
                let sc = Float(0.03 + 0.2 * o)
                s.scale = [sc, sc, sc]
                Self.setOpacity(s, o)
                // SpriteMaterial.rotation：在畫面上轉（轉面片本身，pivot 負責面向鏡頭）
                s.children.first?.orientation = simd_quatf(angle: Float(t * 0.6), axis: [0, 0, 1])
            }
            ring.orientation = Self.spinY(t * 0.25)
            Self.setOpacity(glow, 0.75 + 0.15 * sin(t * 2.5))
        }
    }
}

// MARK: - 金幣（立體小網格，卡通著色＋描邊）

@MainActor
private enum Coin {
    static let radius: Float = 0.075, thickness: Float = 0.016, segments = 28
    private static var proto: Entity?
    private static var tried = false
    private static let lib: MTLLibrary? = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

    /// 金幣範本（只做一次；每顆 clone，網格和材質共用）。做不出來＝nil（不顯示金幣）
    static func make() -> Entity? {
        if tried { return proto }
        tried = true
        guard let lib, let face = Tex.coinFace() else { return nil }
        // HTML：CylinderGeometry(0.075, 0.075, 0.016, 28) 再 rotateX(π/2) → 軸朝 z，圓面朝 ±z。
        // 自己組網格（generateCylinder 要 iOS 18，圓面的 UV 也要自己定，星形才會在正中間）
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = []
        var sideIdx: [UInt32] = [], capIdx: [UInt32] = []
        let r = radius, hz = thickness / 2, n = segments
        func ang(_ j: Int) -> Float { Float(j) / Float(n) * 2 * .pi }
        // 側面：每個角度上下兩點，法線朝外
        for j in 0...n {
            let c = cos(ang(j)), s = sin(ang(j))
            pos += [[r * c, r * s, -hz], [r * c, r * s, hz]]
            nor += [[c, s, 0], [c, s, 0]]
            uv += [[0, 0], [0, 0]]
        }
        for j in 0..<n {
            let b0 = UInt32(j * 2), t0 = b0 + 1, b1 = b0 + 2, t1 = b0 + 3
            sideIdx += [b0, b1, t1, b0, t1, t0]         // 從外面看逆時針
        }
        // 圓面（+z、-z）：中心點＋一圈
        for (z, nz) in [(hz, Float(1)), (-hz, Float(-1))] {
            let center = UInt32(pos.count)
            pos.append([0, 0, z]); nor.append([0, 0, nz]); uv.append([0.5, 0.5])
            for j in 0...n {
                let c = cos(ang(j)), s = sin(ang(j))
                pos.append([r * c, r * s, z]); nor.append([0, 0, nz])
                uv.append([0.5 + c * 0.5, 0.5 - s * 0.5])
            }
            for j in 0..<n {
                let a = center + 1 + UInt32(j), b = a + 1
                capIdx += nz > 0 ? [center, a, b] : [center, b, a]
            }
        }
        var side = MeshDescriptor(name: "coin_side")
        side.positions = MeshBuffers.Positions(pos)
        side.normals = MeshBuffers.Normals(nor)
        side.textureCoordinates = MeshBuffers.TextureCoordinates(uv)
        side.primitives = .triangles(sideIdx)
        side.materials = .allFaces(0)
        var caps = side
        caps.name = "coin_caps"
        caps.primitives = .triangles(capIdx)
        caps.materials = .allFaces(1)
        guard let mesh = try? MeshResource.generate(from: [side, caps]),
              var sideMat = try? CustomMaterial(surfaceShader: .init(named: "toonSurface", in: lib), lightingModel: .unlit),
              var capMat = try? CustomMaterial(surfaceShader: .init(named: "toonTexSurface", in: lib), lightingModel: .unlit)
        else { return nil }
        // 和角色同一套卡通著色（Toon.metal）；暗面倍率 0.55 和角色預設相同
        sideMat.baseColor = .init(tint: Tex.ui("#C98E1A"))
        sideMat.custom.value = SIMD4(0, 0, 0, 0.55)
        sideMat.specular = .init(floatLiteral: 1)
        capMat.baseColor = .init(tint: .white, texture: .init(face))
        capMat.custom.value = SIMD4(0, 0, 0, 0.55)
        capMat.specular = .init(floatLiteral: 1)
        let coin = Entity()
        coin.name = "coin"
        coin.addChild(ModelEntity(mesh: mesh, materials: [sideMat, capMat]))
        // 描邊：和角色相同（outlineGeom 沿平滑法線往外撐、剔除正面），顏色照 HTML 的 0x4a2c00
        if var ol = Hero3DAssets.shared.outlineMat {
            ol.baseColor = .init(tint: Tex.ui("#4A2C00"))
            var od = MeshDescriptor(name: "coin_outline")
            od.positions = MeshBuffers.Positions(pos)
            od.normals = MeshBuffers.Normals(Hero3DPropData.smoothNormals(pos, nor))
            od.primitives = .triangles(sideIdx + capIdx)
            if let om = try? MeshResource.generate(from: [od]) {
                coin.addChild(ModelEntity(mesh: om, materials: [ol]))
            }
        }
        proto = coin
        return coin
    }
}

// MARK: - 貼圖（Core Graphics 照 HTML 的 canvas 步驟畫，每張只畫一次）

@MainActor
private enum Tex {
    private static var cache: [String: TextureResource] = [:]
    private static var failed: Set<String> = []

    static func ui(_ hex: String) -> UIColor {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                       blue: CGFloat(v & 255) / 255, alpha: 1)
    }
    private static func cg(_ hex: String) -> CGColor {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return rgba(CGFloat((v >> 16) & 255), CGFloat((v >> 8) & 255), CGFloat(v & 255), 1)
    }
    private static func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat) -> CGColor {
        CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    /// canvasTex：座標和 canvas 一樣（原點左上、y 朝下）。畫完轉成非預乘的 RGBA，邊緣半透明處才不會發黑
    private static func paint(_ name: String, _ w: Int, _ hh: Int, _ draw: (CGContext) -> Void) -> TextureResource? {
        if let t = cache[name] { return t }
        if failed.contains(name) { return nil }
        guard let cs = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: hh, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            failed.insert(name); return nil
        }
        ctx.translateBy(x: 0, y: CGFloat(hh))
        ctx.scaleBy(x: 1, y: -1)
        draw(ctx)
        guard let data = ctx.data else { failed.insert(name); return nil }
        let n = w * hh * 4
        let src = data.bindMemory(to: UInt8.self, capacity: n)
        var px = [UInt8](repeating: 0, count: n)
        for i in stride(from: 0, to: n, by: 4) {
            let a = Int(src[i + 3])
            px[i + 3] = UInt8(a)
            guard a > 0 else { continue }
            for c in 0..<3 { px[i + c] = UInt8(min(255, (Int(src[i + c]) * 255 + a / 2) / a)) }
        }
        var tex: TextureResource?
        if let provider = CGDataProvider(data: Data(px) as CFData),
           let img = CGImage(width: w, height: hh, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                             bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                             decode: nil, shouldInterpolate: true, intent: .defaultIntent) {
            if #available(iOS 18.0, *) {
                tex = try? TextureResource(image: img, withName: "fx_" + name, options: .init(semantic: .color))
            } else {
                tex = try? TextureResource.generate(from: img, withName: "fx_" + name, options: .init(semantic: .color))
            }
        }
        if let tex { cache[name] = tex } else { failed.insert(name) }
        return tex
    }

    private static func circle(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
        g.beginPath()
        g.addArc(center: CGPoint(x: x, y: y), radius: r, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    }

    /// canvas 的 lineTo：路徑還沒有點時等於 moveTo
    private static func poly(_ g: CGContext, _ pts: [CGPoint]) {
        g.beginPath()
        guard let f = pts.first else { return }
        g.move(to: f)
        for p in pts.dropFirst() { g.addLine(to: p) }
        g.closePath()
    }

    /// 符文：從 3×3 格點挑線段，固定種子 → 每個字形不同、原創（HTML 的 glyph）
    private static func glyph(_ g: CGContext, _ seed: Double, _ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ ang: CGFloat) {
        func P(_ k: Int) -> CGPoint { CGPoint(x: CGFloat(k % 3 - 1) * size / 2, y: CGFloat(k / 3 - 1) * size / 2) }
        func h(_ i: Double) -> Double { let x = sin(i * 12.9898) * 43758.5453; return x - floor(x) }
        g.saveGState()
        g.translateBy(x: cx, y: cy)
        g.rotate(by: ang)
        g.beginPath()
        g.move(to: P(1)); g.addLine(to: P(7))                             // 每個符文都有中間一豎
        for k in 0..<3 {
            let a = Int(floor(h(seed * 7 + Double(k)) * 9)), b = Int(floor(h(seed * 13 + Double(k) + 5) * 9))
            if a != b { g.move(to: P(a)); g.addLine(to: P(b)) }
        }
        g.strokePath()
        g.restoreGState()
    }

    static func glow(_ r: CGFloat, _ gr: CGFloat, _ b: CGFloat, _ a: CGFloat = 0.85) -> TextureResource? {
        paint("glow_\(Int(r))_\(Int(gr))_\(Int(b))_\(a)", 128, 128) { g in
            let colors = [rgba(r, gr, b, a), rgba(r, gr, b, a * 0.45), rgba(r, gr, b, 0)] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors,
                                        locations: [0, 0.45, 1]) else { return }
            g.drawRadialGradient(grad, startCenter: CGPoint(x: 64, y: 64), startRadius: 0,
                                 endCenter: CGPoint(x: 64, y: 64), endRadius: 64, options: [])
        }
    }

    // 火焰
    static func flame(outer: String, core: String) -> TextureResource? {
        paint("flame_\(outer)_\(core)", 64, 128) { g in
            let w: CGFloat = 64, hh: CGFloat = 128
            let p = CGMutablePath()
            p.move(to: CGPoint(x: w / 2, y: 4))
            p.addCurve(to: CGPoint(x: w / 2, y: hh - 4), control1: CGPoint(x: w * 0.98, y: hh * 0.5),
                       control2: CGPoint(x: w * 0.92, y: hh * 0.97))
            p.addCurve(to: CGPoint(x: w / 2, y: 4), control1: CGPoint(x: w * 0.08, y: hh * 0.97),
                       control2: CGPoint(x: w * 0.02, y: hh * 0.5))
            g.addPath(p); g.setFillColor(cg(outer)); g.fillPath()
            g.addPath(p); g.setLineWidth(4); g.setStrokeColor(rgba(110, 22, 0, 0.95)); g.strokePath()
            g.saveGState()
            g.translateBy(x: w / 2, y: hh - 6); g.scaleBy(x: 0.55, y: 0.58); g.translateBy(x: -w / 2, y: -(hh - 6))
            g.addPath(p); g.setFillColor(cg(core)); g.fillPath()
            g.restoreGState()
        }
    }

    static func spark() -> TextureResource? {
        paint("spark", 32, 32) { g in
            g.setFillColor(cg("#FFE08A"))
            g.translateBy(x: 16, y: 16); g.rotate(by: .pi / 4)
            g.fill(CGRect(x: -8, y: -8, width: 16, height: 16))
        }
    }

    // 符文法陣
    private static let G = "#3DF5A0", AU = "#E3C47E"

    static func magicOuter() -> TextureResource? {
        paint("magic_outer", 512, 512) { g in
            g.translateBy(x: 256, y: 256); g.setLineCap(.round)
            g.setShadow(offset: .zero, blur: 14, color: cg(G))
            g.setStrokeColor(cg(G)); g.setLineWidth(7); circle(g, 0, 0, 238); g.strokePath()
            g.setLineWidth(3); circle(g, 0, 0, 196); g.strokePath()
            g.setAlpha(0.85); g.setLineWidth(3.5)
            for off in [0, CGFloat.pi] {
                poly(g, (0..<3).map { k -> CGPoint in
                    let a = off - .pi / 2 + CGFloat(k) * .pi * 2 / 3
                    return CGPoint(x: cos(a) * 196, y: sin(a) * 196)
                })
                g.strokePath()
            }
            g.setAlpha(1); g.setStrokeColor(cg(AU)); g.setShadow(offset: .zero, blur: 14, color: cg(AU)); g.setLineWidth(3.5)
            for k in 0..<12 {
                let a = CGFloat(k) / 12 * .pi * 2
                glyph(g, Double(k + 1), cos(a) * 217, sin(a) * 217, 22, a + .pi / 2)
            }
        }
    }

    static func magicInner() -> TextureResource? {
        paint("magic_inner", 256, 256) { g in
            g.translateBy(x: 128, y: 128); g.setStrokeColor(cg(G)); g.setShadow(offset: .zero, blur: 10, color: cg(G))
            g.setLineWidth(4)
            g.setLineDash(phase: 0, lengths: [14, 10]); circle(g, 0, 0, 118); g.strokePath(); g.setLineDash(phase: 0, lengths: [])
            g.setLineWidth(3); circle(g, 0, 0, 70); g.strokePath()
            g.rotate(by: .pi / 4); g.stroke(CGRect(x: -46, y: -46, width: 92, height: 92))
            g.setFillColor(cg(G))
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * .pi * 2
                circle(g, cos(a) * 94, sin(a) * 94, 6); g.fillPath()
            }
        }
    }

    static func magicRing() -> TextureResource? {
        paint("magic_ring", 256, 256) { g in
            g.setStrokeColor(cg(G)); g.setShadow(offset: .zero, blur: 12, color: cg(G)); g.setLineWidth(8)
            circle(g, 128, 128, 112); g.strokePath()
        }
    }

    static func rune(_ k: Int) -> TextureResource? {
        paint("rune_\(k)", 64, 64) { g in
            g.setStrokeColor(cg(AU)); g.setShadow(offset: .zero, blur: 8, color: cg(G))
            g.setLineWidth(5); g.setLineCap(.round)
            glyph(g, Double(k + 20), 32, 32, 36, 0)
        }
    }

    // 金光
    static func coinFace() -> TextureResource? {
        paint("coin_face", 128, 128) { g in
            g.setFillColor(cg("#F2B630")); g.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            g.setStrokeColor(cg("#B57A10")); g.setLineWidth(10); circle(g, 64, 64, 56); g.strokePath()
            let star = (0..<10).map { k -> CGPoint in                       // 凸起的五角星
                let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5, r: CGFloat = k % 2 == 1 ? 16 : 36
                return CGPoint(x: 64 + cos(a) * r, y: 64 + sin(a) * r)
            }
            g.setFillColor(cg("#FFE58A")); poly(g, star); g.fillPath()
            g.setStrokeColor(cg("#B57A10")); g.setLineWidth(4); poly(g, star); g.strokePath()
        }
    }

    static func star() -> TextureResource? {
        paint("gold_star", 64, 64) { g in
            g.translateBy(x: 32, y: 32); g.setFillColor(cg("#FFF1B8")); g.setShadow(offset: .zero, blur: 10, color: cg("#FFC83D"))
            poly(g, (0..<8).map { k -> CGPoint in
                let a = CGFloat(k) * .pi / 4, r: CGFloat = k % 2 == 1 ? 5 : 28
                return CGPoint(x: cos(a) * r, y: sin(a) * r)
            })
            g.fillPath()
        }
    }

    static func goldRing() -> TextureResource? {
        paint("gold_ring", 256, 256) { g in
            g.translateBy(x: 128, y: 128); g.setStrokeColor(cg("#FFC83D")); g.setShadow(offset: .zero, blur: 10, color: cg("#FFC83D"))
            g.setLineWidth(5); circle(g, 0, 0, 116); g.strokePath()
            g.setFillColor(cg("#FFF1B8"))
            for k in 0..<8 {
                g.saveGState()
                g.rotate(by: CGFloat(k) * .pi / 4); g.translateBy(x: 0, y: -116); g.rotate(by: .pi / 4)
                g.fill(CGRect(x: -9, y: -9, width: 18, height: 18))
                g.restoreGState()
            }
        }
    }
}
