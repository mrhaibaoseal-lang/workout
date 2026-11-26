import SwiftUI
import RealityKit
import Combine
import Metal

// 3D 技術驗證頁（設定 → 3D 測試）。確認 Blender 匯出的 USDZ 能在 RealityKit 即時播放：
// 卡通著色（Toon.metal）、描邊外殼、逐件開關裝備、切換動作、效能和檔案大小。
// 0.38 試做：著色器描邊（同一份網格畫兩次、沿平均法線外撐；0.39.0 起 USDZ 不再烘外殼）、泛光後處理（Hero3DBloom）。
// 0.44.0 上衣／下身換裝：身體只有一份網格（base__body），換裝＝換貼圖（hero3d_top_<系列>.png、hero3d_bottom_<系列>.png，Toon.metal 的 outfitSurface）；
// 長褲、短褲、鈦甲緊身衣是另外的網格（bottom_long／bottom_short／top_suit），各系列一張貼圖；胸章、腿甲這類小零件是 top_<系列>／bottom_<系列>。
// 檔案由 scripts/blender/build_app.sh 產生：hero3d.usdz（骨架、身體、衣服網格、基本款）、hero3d_<系列>.usdz（該系列的零件，選到才載入，0.52.0）、
// hero3d.json（材質表、換裝表、系列檔對照）、hero3d_clip_<動作>.json、換裝貼圖。
// 0.56.0 動作示範：Hero3DDemoView 讓動作庫／動作說明播 3D（穿使用者目前的裝備）。動作檔 scripts/blender/build_moves.sh 一次匯出全部（約 95 個）；
// 椅子、單槓、滑輪、機器這些器材存成 hero3d_prop_<動作>.json＋.bin（頂點、法線、索引＋會動的零件每格變換），App 自己組網格（不走 USD）。

struct Hero3DInfo: Decodable {
    struct Mat: Decodable {
        let kind: String
        let color: [Float]
        let shade: Float?
        let spec: Bool?
        let strength: Float?
        let alt: [Float]?
        let altShade: Float?
    }
    /// 換裝：outfits["top"|"bottom"][系列]
    struct Outfit: Decodable {
        let body: String          // 身體貼圖（不含副檔名）
        let mesh: String?         // 衣服網格：suit／long／short
        let cloth: String?        // 衣服網格的貼圖
        let part: String?         // 剛性小零件（top_frost…）
    }
    let parts: [String]
    let meshes: [String]
    let materials: [String: Mat]
    let outfits: [String: [String: Outfit]]?
    /// 系列 → 該系列零件的 USDZ 檔名（不含副檔名）；沒寫的系列在主檔裡
    let files: [String: String]?
}

struct Hero3DClip: Decodable {
    let move: String
    let fps: Double
    let joints: [String]
    let frames: [[[Float]]]          // [格][骨頭][tx,ty,tz,qx,qy,qz,qw]
    let low: [String: [Float]]       // 零件 → 每格最低點
    let bell: Bool?                  // 這個動作手上拿不拿啞鈴（沒寫＝舊檔，照拿）
    let leanBack: Bool?              // 背靠椅子：背部裝備（披風、背包）要藏起來

    func pose(at t: Double) -> [Transform] {
        let n = frames.count
        let x = (t * fps).truncatingRemainder(dividingBy: Double(n))
        let i0 = Int(x) % n, i1 = (i0 + 1) % n, a = Float(x - Double(Int(x)))
        return (0..<joints.count).map { j in
            let p = frames[i0][j], q = frames[i1][j]
            let t0 = SIMD3(p[0], p[1], p[2]), t1 = SIMD3(q[0], q[1], q[2])
            let r0 = simd_quatf(ix: p[3], iy: p[4], iz: p[5], r: p[6])
            let r1 = simd_quatf(ix: q[3], iy: q[4], iz: q[5], r: q[6])
            return Transform(scale: .one, rotation: simd_slerp(r0, r1, a), translation: t0 + (t1 - t0) * a)
        }
    }

    /// 整個角色要抬高多少（有東西沉到地板下才抬），照 moves3d.py 的接地修正
    func lift(at t: Double, parts: Set<String>) -> Float {
        let i = Int(t * fps) % frames.count
        let lo = parts.compactMap { low[$0]?[i] }.min() ?? 0
        return lo < -0.004 ? -lo - 0.002 : 0
    }
}

/// 器材檔（hero3d_prop_<動作>.json；頂點資料在同名 .bin）
struct Hero3DPropInfo: Decodable {
    struct Group: Decodable {
        let name: String
        let mat: String
        let outline: Bool
        let nv: Int
        let ni: Int
        let pos: Int                 // .bin 裡的位元組位置：頂點 Float32×3×nv、法線 Float32×3×nv、索引 UInt32×ni
        let anim: [[Float]]?         // 會動的零件：每格 [tx,ty,tz,qx,qy,qz,qw,sx,sy,sz]；沒有＝靜止
    }
    let groups: [Group]
    let materials: [String: Hero3DInfo.Mat]
}

@MainActor
final class Hero3DModel: ObservableObject {
    struct Slot: Identifiable { let id: String; let name: String }
    static let slots = [Slot(id: "head", name: "頭"), Slot(id: "hands", name: "手"), Slot(id: "feet", name: "腳"),
                        Slot(id: "back", name: "背"), Slot(id: "bell", name: "啞鈴")]
    static let seriesName = ["basic": "基本", "frost": "冰霜", "titan": "鈦甲", "pig": "小豬", "night": "暗夜", "dawn": "曙光",
                             "rune": "符文", "astral": "星界", "street": "街頭", "neon": "霓虹", "lava": "熔岩", "gold": "黃金",
                             "shadow": "暗影", "none": "無"]
    static let seriesOrder = ["basic", "street", "frost", "titan", "pig", "neon", "lava", "night", "dawn", "rune", "astral", "gold", "shadow"]
    static let clothPart = ["suit": "top_suit", "long": "bottom_long", "short": "bottom_short"]

    @Published var choice: [String: String] = ["head": "basic", "hands": "basic", "feet": "basic", "back": "none", "bell": "basic"]
    @Published var outfit: [String: String] = ["top": "basic", "bottom": "basic"]   // 上衣、下身（可混搭）
    @Published var move = "squat"
    @Published var useUSDAnimation = false
    @Published var paused = false
    @Published var outlineWidth: Float = 10  // 著色器描邊厚度（毫米，模型座標）
    @Published var bloomOn = false           // 預設關：泛光出問題時不擋描邊測試
    @Published var bloomStrength: Float = 1.2
    @Published var bloomThreshold: Float = 0.95
    @Published var showStats = true
    @Published var report: [String] = []
    @Published var vertexLine = ""

    let arView: ARView
    private var holder = Entity()            // 轉向用
    private var model = Entity()             // 抬高用
    private var propRoot = Entity()          // 器材（跟著轉向，不跟著抬高）
    private var propEntities: [(entity: Entity, outline: Entity?, anim: [[Float]])] = []
    private var propMats: [String: CustomMaterial] = [:]
    private var shownMove = ""
    private var metalLib: MTLLibrary?
    private let demo: Bool
    private var info: Hero3DInfo?
    private var roots: [Entity] = []          // 主檔＋已載入的系列檔
    private var loadedFiles: Set<String> = []
    private var clips: [String: Hero3DClip] = [:]
    // RealityKit 讀 USD 時，綁同一副骨架的網格會合併成「一個」實體，零件變成網格裡的 part。
    // 所以在 part 這層辨認零件（名字 = hero3d.json 的 meshes，例如 head_titan__ti）、套材質、換裝時重組網格。
    private struct Body {
        let entity: Entity
        let contents: MeshResource.Contents                  // 原始內容，換裝時從這裡篩
        let tags: [String: (part: String, mat: String)]      // key = 模型 id + "|" + part id
    }
    private var bodies: [Body] = []
    private var mats: [any RealityKit.Material] = []
    private var matIndex: [String: Int] = [:]
    private var fallbackMat = 0
    private var texCache: [String: TextureResource] = [:]
    private var olShaderMat: CustomMaterial?
    private var outlines: [ObjectIdentifier: Entity] = [:]       // 本體 → 著色器描邊用的複本
    private var smoothCache: [String: MeshResource.Part] = [:]   // 描邊用的 part（法線已平均）
    private let bloom = Hero3DBloom()
    private var jointMap: [ObjectIdentifier: [Int?]] = [:]
    private var time: Double = 0
    private var yaw: Float = 0
    private var sub: Cancellable?

    /// demo＝動作示範用（0.56.0）：斜前方鏡頭、不顯示效能數字、不用泛光、動作檔和器材依需要才讀
    init(demo: Bool = false, move: String = "squat") {
        self.demo = demo
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        self.move = move
        showStats = !demo
        arView.environment.background = .color(demo ? UIColor(red: 0.078, green: 0.098, blue: 0.125, alpha: 1) : UIColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1))
        arView.debugOptions = demo ? [] : [.showStatistics]
        load()
        applyBloom()
    }
    private var bloomInstalled = false

    /// 泛光開關：一般材質亮度上限（specular_scale）＋後處理
    func applyBloom() {
        bloom.strength = bloomStrength
        bloom.threshold = bloomThreshold
        let cap: Float = bloomOn ? min(0.88, bloomThreshold - 0.05) : 1
        for i in mats.indices {
            guard var m = mats[i] as? CustomMaterial else { continue }
            m.specular = .init(floatLiteral: cap)
            mats[i] = m
        }
        for b in bodies {
            guard var mc = b.entity.components[ModelComponent.self] else { continue }
            mc.materials = mats
            b.entity.components.set(mc)
        }
        bloom.enabled = bloomOn
        if bloomOn && !bloomInstalled {
            bloomInstalled = true
            Hero3DBloom.install(bloom, on: arView)
        }
    }

    func applyOutlineWidth() {
        guard var m = olShaderMat else { return }
        m.custom.value = SIMD4(outlineWidth / 1000, 0, 0, 0)
        olShaderMat = m
        for ol in outlines.values {
            guard var mc = ol.components[ModelComponent.self] else { continue }
            mc.materials = [m]
            ol.components.set(mc)
        }
    }

    func options(for slot: String) -> [String] {
        let have = (info?.parts ?? []).filter { $0.hasPrefix(slot + "_") }.map { String($0.dropFirst(slot.count + 1)) }
        return (slot == "back" ? ["none"] : []) + Self.seriesOrder.filter(have.contains)
    }

    func outfitOptions(_ slot: String) -> [String] {
        let have = Set(info?.outfits?[slot]?.keys.map { $0 } ?? [])
        return Self.seriesOrder.filter(have.contains) + have.subtracting(Self.seriesOrder).sorted()
    }

    /// 動作檔：第一次用到才讀（95 個動作，不要一開始全讀）
    @discardableResult
    private func clip(_ name: String) -> Hero3DClip? {
        if let c = clips[name] { return c }
        guard let u = Bundle.main.url(forResource: "hero3d_clip_\(name)", withExtension: "json"),
              let c = try? JSONDecoder().decode(Hero3DClip.self, from: Data(contentsOf: u)) else { return nil }
        clips[name] = c
        return c
    }

    private func texture(_ name: String) -> TextureResource? {
        if let t = texCache[name] { return t }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png") else {
            report.append("❌ 找不到 \(name).png"); return nil
        }
        do {
            // raw：不做 sRGB 轉換（右半是遮罩），顏色由著色器自己轉；不要 mipmap（左右兩半會在小圖混在一起）
            let t = try TextureResource.load(contentsOf: url, withName: name,
                                             options: TextureResource.CreateOptions(semantic: .raw, mipmapsMode: .none))
            texCache[name] = t
            return t
        } catch {
            report.append("❌ 貼圖 \(name)：\(error.localizedDescription)"); return nil
        }
    }

    /// 換上衣／下身：身體材質的兩個貼圖欄（上衣＝custom、下身＝base color），衣服網格換成該系列的貼圖
    func applyOutfit() {
        guard let o = info?.outfits else { return }
        let top = o["top"]?[outfit["top"] ?? "basic"], bottom = o["bottom"]?[outfit["bottom"] ?? "basic"]
        if let i = matIndex["body"], var m = mats[i] as? CustomMaterial {
            if let n = top?.body, let t = texture(n) { m.custom.texture = .init(t) }
            if let n = bottom?.body, let t = texture(n) { m.baseColor.texture = .init(t) }
            mats[i] = m
        }
        for e in [top, bottom].compactMap({ $0 }) {
            guard let kind = e.mesh, let n = e.cloth, let i = matIndex["cloth_" + kind],
                  var m = mats[i] as? CustomMaterial, let t = texture(n) else { continue }
            m.custom.texture = .init(t)
            m.baseColor.texture = .init(t)
            mats[i] = m
        }
        for b in bodies {
            guard var mc = b.entity.components[ModelComponent.self] else { continue }
            mc.materials = mats
            b.entity.components.set(mc)
        }
    }

    private func load() {
        var log: [String] = []
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        let cam = PerspectiveCamera()
        if demo {
            // 斜前方看（跟 Blender 審查圖同一個方向），器材（滑輪架 2 m 高）也放得下
            cam.camera.fieldOfViewInDegrees = 34
            cam.look(at: [0, 0.95, 0], from: [3.4, 1.6, 3.7], relativeTo: nil)
        } else {
            cam.camera.fieldOfViewInDegrees = 32
            cam.look(at: [0, 0.85, 0], from: [0, 1.15, 4.4], relativeTo: nil)
        }
        anchor.addChild(cam)
        // 舞台圓台
        let stage = ModelEntity(mesh: .generatePlane(width: 1.6, depth: 1.6, cornerRadius: 0.8),
                                materials: [UnlitMaterial(color: UIColor(red: 0.12, green: 0.14, blue: 0.24, alpha: 1))])
        stage.position.y = -0.001
        anchor.addChild(stage)
        anchor.addChild(holder)
        holder.addChild(model)
        holder.addChild(propRoot)

        let bundle = Bundle.main
        do {
            guard let infoURL = bundle.url(forResource: "hero3d", withExtension: "json"),
                  let usdURL = bundle.url(forResource: "hero3d", withExtension: "usdz") else {
                report = ["找不到 hero3d.usdz／hero3d.json"]; return
            }
            info = try JSONDecoder().decode(Hero3DInfo.self, from: Data(contentsOf: infoURL))
            for m in (demo ? ["squat", move] : ["squat", "pushup"]) { _ = clip(m) }
            try makeMaterials(&log)
            let root = try loadRoot(usdURL, "主檔", &log)
            log.append("USD 內建動畫 \(root.availableAnimations.count) 段")
        } catch {
            log.append("❌ \(error.localizedDescription)")
        }
        report = log
        applyOutfit()
        applyChoice()
        sub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
            MainActor.assumeIsolated { self?.tick(ev.deltaTime) }
        }
    }

    /// 載入一個 USDZ 檔、辨認零件、對應骨頭（主檔和系列檔共用）
    @discardableResult
    private func loadRoot(_ url: URL, _ label: String, _ log: inout [String]) throws -> Entity {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        let t0 = CACurrentMediaTime()
        let root = try Entity.load(contentsOf: url)
        log.append(String(format: "載入\(label) %.0f ms，檔案 %.1f MB", (CACurrentMediaTime() - t0) * 1000, Double(size) / 1_048_576))
        model.addChild(root)
        roots.append(root)
        loadedFiles.insert(url.deletingPathExtension().lastPathComponent)
        let first = bodies.count
        collectBodies(root, &log)
        mapJoints(bodies[first...], &log)
        return root
    }

    /// 目前選到的系列（頭、手、腳、背、啞鈴、上衣、下身）有分檔的，還沒載入就載入
    private func ensureSeriesLoaded() {
        guard let files = info?.files else { return }
        let want = Set(choice.values).union(outfit.values)
        var log: [String] = []
        for s in want.sorted() {
            guard let f = files[s], !loadedFiles.contains(f) else { continue }
            guard let url = Bundle.main.url(forResource: f, withExtension: "usdz") else {
                log.append("❌ 找不到 \(f).usdz"); loadedFiles.insert(f); continue
            }
            do { try loadRoot(url, Self.seriesName[s] ?? s, &log) } catch {
                log.append("❌ \(f)：\(error.localizedDescription)"); loadedFiles.insert(f)
            }
        }
        report.append(contentsOf: log)
    }

    private func collectBodies(_ root: Entity, _ log: inout [String]) {
        let first = bodies.count
        let names = (info?.meshes ?? []).sorted { $0.count > $1.count }   // 長的先比，避免 skin 吃掉 skintank
        func match(_ s: String) -> String? { names.first { s.contains($0) } }
        var all = 0, partCount = 0, matched = 0
        var samples: [String] = []
        func walk(_ e: Entity, _ parent: String) {
            all += 1
            let chain = parent + "/" + e.name
            if let mc = e.components[ModelComponent.self] {
                let c = mc.mesh.contents
                var tags: [String: (part: String, mat: String)] = [:]
                for m in c.models {
                    let inst = c.instances.filter { $0.model == m.id }.map(\.id).joined(separator: "|")
                    for p in m.parts {
                        partCount += 1
                        if samples.count < 3 { samples.append("model=\(m.id) part=\(p.id) inst=\(inst)") }
                        guard let t = match(p.id) ?? match(m.id) ?? match(inst) ?? match(chain) else { continue }
                        let sp = t.components(separatedBy: "__")
                        tags[m.id + "|" + p.id] = (sp[0], sp.count > 1 ? sp[1] : "")
                        matched += 1
                    }
                }
                bodies.append(Body(entity: e, contents: c, tags: tags))
            }
            for ch in e.children { walk(ch, chain) }
        }
        walk(root, "")
        // 著色器描邊：每個本體做一個不遞迴的複本（帶同一副骨架），網格在 applyChoice 裡從本體的 part 組
        for b in bodies[first...] {
            let ol = b.entity.clone(recursive: false)
            ol.name = b.entity.name + "_outline"
            ol.isEnabled = false
            b.entity.parent?.addChild(ol)
            outlines[ObjectIdentifier(b.entity)] = ol
        }
        let vAll = bodies[first...].reduce(0) { $0 + $1.contents.models.reduce(0) { $0 + $1.parts.reduce(0) { $0 + $1.positions.count } } }
        log.append("USDZ 頂點 \(vAll)")
        log.append("實體 \(all) 個，有網格 \(bodies.count) 個，part \(partCount) 個，認出零件 \(matched) 個")
        log.append(contentsOf: samples)
    }

    private func srgb(_ c: [Float]) -> UIColor {
        func f(_ x: Float) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
        return UIColor(red: f(c[0]), green: f(c[1]), blue: f(c[2]), alpha: 1)
    }

    /// 一個材質（卡通／純色／換裝）。身體、零件、器材共用
    private func makeMaterial(_ mi: Hero3DInfo.Mat, _ lib: MTLLibrary) throws -> CustomMaterial? {
        var m: CustomMaterial
        switch mi.kind {
        case "outfit":
            // 身體、衣服網格：貼圖在 applyOutfit 放；沒蓋住的地方是皮膚（tint）
            m = try CustomMaterial(surfaceShader: .init(named: "outfitSurface", in: lib), lightingModel: .unlit)
            m.baseColor = .init(tint: srgb(mi.color))
            m.custom.value = SIMD4(0, 0, 0, mi.shade ?? 0.55)
        case "toon":
            m = try CustomMaterial(surfaceShader: .init(named: "toonSurface", in: lib), lightingModel: .unlit)
            m.baseColor = .init(tint: srgb(mi.color))
            let alt = mi.alt ?? [0, 0, 0]
            m.custom.value = SIMD4(alt[0], alt[1], alt[2], mi.shade ?? 0.55)
            m.roughness = .init(floatLiteral: mi.altShade ?? 0.6)
            m.metallic = .init(floatLiteral: (mi.spec ?? false) ? 1 : 0)
        default:
            m = try CustomMaterial(surfaceShader: .init(named: "flatSurface", in: lib), lightingModel: .unlit)
            let k = min(mi.strength ?? 1, 2)
            m.baseColor = .init(tint: srgb(mi.color.map { min($0 * k, 1) }))
            // 強度 ≥ 2 的算發光（flame、glow、frglow、ring），開泛光時不設亮度上限
            m.custom.value = SIMD4(0, 0, 0, (mi.strength ?? 1) >= 2 ? 1 : 0)
        }
        m.specular = .init(floatLiteral: 1)
        return m
    }

    private func makeMaterials(_ log: inout [String]) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let lib = device.makeDefaultLibrary() else {
            log.append("❌ 沒有 Metal 函式庫"); return
        }
        metalLib = lib
        let flat = CustomMaterial.SurfaceShader(named: "flatSurface", in: lib)
        let used = Set((info?.meshes ?? []).compactMap { $0.components(separatedBy: "__").dropFirst().first })
        for name in used.sorted() {
            guard let mi = info?.materials[name] else { log.append("⚠️ 材質表沒有 \(name)"); continue }
            guard let m = try makeMaterial(mi, lib) else { continue }
            matIndex[name] = mats.count
            mats.append(m)
        }
        var ol = try CustomMaterial(surfaceShader: flat,
                                    geometryModifier: CustomMaterial.GeometryModifier(named: "outlineGeom", in: lib),
                                    lightingModel: .unlit)
        ol.baseColor = .init(tint: UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1))
        ol.specular = .init(floatLiteral: 1)
        ol.faceCulling = .front
        ol.custom.value = SIMD4(outlineWidth / 1000, 0, 0, 0)
        olShaderMat = ol
        fallbackMat = mats.count            // 認不出的 part 用灰色，方便看出來
        mats.append(UnlitMaterial(color: .gray))
    }

    private func mapJoints(_ list: ArraySlice<Body>, _ log: inout [String]) {
        guard let clip = clips["squat"] ?? clips.values.first else { log.append("❌ 沒有動作檔"); return }
        let idx = Dictionary(uniqueKeysWithValues: clip.joints.enumerated().map { ($1, $0) })
        let short = Dictionary(clip.joints.enumerated().map { ($1.components(separatedBy: "/").last!, $0) }, uniquingKeysWith: { a, _ in a })
        var matched = 0, total = 0
        for b in list {
            let map = Self.jointNames(b.entity).map { n -> Int? in
                idx[n] ?? short[n.components(separatedBy: "/").last ?? n]
            }
            matched += map.compactMap { $0 }.count; total += map.count
            jointMap[ObjectIdentifier(b.entity)] = map
        }
        log.append("骨頭對應 \(matched)/\(total)")
    }

    /// 依目前選的裝備，從原始內容篩出要顯示的 part，重組網格並指定材質
    func applyChoice() {
        clip(move)
        if shownMove != move { shownMove = move; time = 0; loadProps() }
        ensureSeriesLoaded()
        let active = activeParts
        var vBody = 0, vLine = 0
        for b in bodies {
            var models: [MeshResource.Model] = []
            var olModels: [MeshResource.Model] = []
            for m in b.contents.models {
                var parts: [MeshResource.Part] = []
                var olParts: [MeshResource.Part] = []
                for p in m.parts {
                    let key = m.id + "|" + p.id
                    let t = b.tags[key]
                    if let t, !active.contains(t.part) { continue }
                    var q = p
                    q.materialIndex = t.flatMap { matIndex[$0.mat] } ?? fallbackMat
                    parts.append(q)
                    vBody += p.positions.count
                    // 著色器描邊套全部零件（眼睛也要有黑框，0.38.1 只描卡通材質時眼睛少一圈）
                    if t != nil {
                        let op = outlinePart(key, p)
                        olParts.append(op)
                        vLine += op.positions.count
                    }
                }
                if !parts.isEmpty { var mm = m; mm.parts = MeshPartCollection(parts); models.append(mm) }
                if !olParts.isEmpty { var mm = m; mm.parts = MeshPartCollection(olParts); olModels.append(mm) }
            }
            setMesh(b.entity, b.contents, models, mats)
            if let ol = outlines[ObjectIdentifier(b.entity)] {
                if !olModels.isEmpty, let olm = olShaderMat {
                    setMesh(ol, b.contents, olModels, [olm])
                    ol.isEnabled = true
                } else {
                    ol.isEnabled = false
                }
            }
        }
        vertexLine = "畫面上頂點：本體 \(vBody)，描邊 \(vLine)（與本體共用頂點資料，USDZ 不用存）"
        // 每個檔各帶一份同樣的動畫，一起從頭播才會同步
        for root in roots {
            if useUSDAnimation, let anim = root.availableAnimations.first {
                root.playAnimation(anim.repeat())
            } else {
                root.stopAllAnimations()
            }
        }
    }

    private func setMesh(_ e: Entity, _ base: MeshResource.Contents, _ models: [MeshResource.Model], _ materials: [any RealityKit.Material]) {
        var c = base
        let keep = Set(models.map(\.id))
        c.models = MeshModelCollection(models)
        c.instances = MeshInstanceCollection(base.instances.filter { keep.contains($0.model) })
        do {
            let mesh = try MeshResource.generate(from: c)
            var mc = e.components[ModelComponent.self] ?? ModelComponent(mesh: mesh, materials: materials)
            mc.mesh = mesh
            mc.materials = materials
            e.components.set(mc)
        } catch {
            report.append("❌ 重組網格失敗：\(error.localizedDescription)")
        }
    }

    /// 同位置的頂點法線取平均（硬邊撐開不裂）。描邊用
    private static func smoothNormals(_ pos: [SIMD3<Float>], _ normals: [SIMD3<Float>]) -> [SIMD3<Float>] {
        var acc: [SIMD3<Int32>: SIMD3<Float>] = [:]
        func k(_ v: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(v * 10000, rounding: .toNearestOrAwayFromZero) }
        for i in pos.indices where i < normals.count { acc[k(pos[i]), default: .zero] += normals[i] }
        return pos.map { v -> SIMD3<Float> in
            let s = acc[k(v)] ?? .zero
            let l = simd_length(s)
            return l > 1e-6 ? s / l : .zero
        }
    }

    /// 描邊用的 part：同位置的頂點法線取平均（硬邊撐開不裂），材質固定第 0 個
    private func outlinePart(_ key: String, _ p: MeshResource.Part) -> MeshResource.Part {
        if let c = smoothCache[key] { return c }
        var q = p
        q.materialIndex = 0
        if let normals = p.normals?.elements {
            q.normals = MeshBuffer(Self.smoothNormals(p.positions.elements, normals))
        }
        smoothCache[key] = q
        return q
    }

    // MARK: 器材（0.56.0）：hero3d_prop_<動作>.json＋.bin，自己組網格；會動的零件每格設變換

    private func propMaterial(_ name: String, _ info: Hero3DPropInfo) -> (any RealityKit.Material) {
        if let m = propMats[name] { return m }
        guard let lib = metalLib, let mi = info.materials[name], let m = try? makeMaterial(mi, lib) else {
            return UnlitMaterial(color: .gray)
        }
        propMats[name] = m
        return m
    }

    private func loadProps() {
        propRoot.children.removeAll()
        propEntities = []
        guard let ju = Bundle.main.url(forResource: "hero3d_prop_\(move)", withExtension: "json"),
              let bu = Bundle.main.url(forResource: "hero3d_prop_\(move)", withExtension: "bin") else { return }
        do {
            let pi = try JSONDecoder().decode(Hero3DPropInfo.self, from: Data(contentsOf: ju))
            let bin = try Data(contentsOf: bu)
            for g in pi.groups {
                let (pos, nor, idx) = Self.readGroup(bin, g)
                guard pos.count == g.nv, !idx.isEmpty else { report.append("⚠️ 器材 \(g.name) 資料長度不對"); continue }
                var d = MeshDescriptor(name: g.name)
                d.positions = MeshBuffers.Positions(pos)
                d.normals = MeshBuffers.Normals(nor)
                d.primitives = .triangles(idx)
                let e = ModelEntity(mesh: try MeshResource.generate(from: [d]), materials: [propMaterial(g.mat, pi)])
                e.name = g.name
                var ol: Entity?
                if g.outline, let olm = olShaderMat {
                    var od = d
                    od.normals = MeshBuffers.Normals(Self.smoothNormals(pos, nor))
                    let o = ModelEntity(mesh: try MeshResource.generate(from: [od]), materials: [olm])
                    o.name = g.name + "_outline"
                    e.addChild(o)       // 描邊跟著本體動
                    ol = o
                }
                propRoot.addChild(e)
                propEntities.append((e, ol, g.anim ?? []))
            }
        } catch {
            report.append("❌ 器材 \(move)：\(error.localizedDescription)")
        }
    }

    private static func readGroup(_ bin: Data, _ g: Hero3DPropInfo.Group) -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) {
        let n = g.nv
        guard g.pos >= 0, g.pos + n * 24 + g.ni * 4 <= bin.count else { return ([], [], []) }
        return bin.withUnsafeBytes { raw -> ([SIMD3<Float>], [SIMD3<Float>], [UInt32]) in
            func f(_ o: Int) -> Float { raw.loadUnaligned(fromByteOffset: o, as: Float.self) }
            let pos = (0..<n).map { SIMD3<Float>(f(g.pos + $0 * 12), f(g.pos + $0 * 12 + 4), f(g.pos + $0 * 12 + 8)) }
            let o2 = g.pos + n * 12
            let nor = (0..<n).map { SIMD3<Float>(f(o2 + $0 * 12), f(o2 + $0 * 12 + 4), f(o2 + $0 * 12 + 8)) }
            let o3 = g.pos + n * 24
            let idx = (0..<g.ni).map { raw.loadUnaligned(fromByteOffset: o3 + $0 * 4, as: UInt32.self) }
            return (pos, nor, idx)
        }
    }

    /// 會動的器材第 x 格（x 可以是小數）的變換：位移、縮放線性內插，旋轉球面內插
    private static func propTransform(_ fr: [[Float]], _ x: Double) -> Transform {
        let n = fr.count
        let i0 = Int(x) % n, i1 = (i0 + 1) % n, a = Float(x - Double(Int(x)))
        let p = fr[i0], q = fr[i1]
        func v(_ r: [Float], _ o: Int) -> SIMD3<Float> { SIMD3(r[o], r[o + 1], r[o + 2]) }
        let r0 = simd_quatf(ix: p[3], iy: p[4], iz: p[5], r: p[6]), r1 = simd_quatf(ix: q[3], iy: q[4], iz: q[5], r: q[6])
        return Transform(scale: v(p, 7) + (v(q, 7) - v(p, 7)) * a, rotation: simd_slerp(r0, r1, a),
                         translation: v(p, 0) + (v(q, 0) - v(p, 0)) * a)
    }

    // MARK: 動作示範（0.56.0）：依使用者的裝備穿上

    /// 角色頁的裝備（`Loadout`）→ 3D 零件選擇；3D 沒有的系列用基本款
    func apply(loadout: Loadout) {
        for slot in Self.slots.map(\.id) {
            let fallback = slot == "back" ? "none" : "basic"
            let s = GearSlot(rawValue: slot).flatMap { loadout.item($0)?.series } ?? fallback
            choice[slot] = options(for: slot).contains(s) ? s : fallback
        }
        for slot in ["top", "bottom"] {
            let s = GearSlot(rawValue: slot).flatMap { loadout.item($0)?.series } ?? "basic"
            outfit[slot] = outfitOptions(slot).contains(s) ? s : "basic"
        }
        applyOutfit()
        applyChoice()
    }

    private var activeParts: Set<String> {
        var s: Set<String> = ["base"]
        let cl = clips[move]
        let bell = cl?.bell ?? (move != "pushup")       // 舊動作檔沒有這個欄位
        let leanBack = cl?.leanBack ?? false
        for slot in Self.slots.map(\.id) {
            if slot == "bell" && !bell { continue }
            if slot == "back" && leanBack { continue }   // 背靠椅子：披風、背包會穿進椅背
            if let c = choice[slot], c != "none" { s.insert("\(slot)_\(c)") }
        }
        for slot in ["top", "bottom"] {
            guard let e = info?.outfits?[slot]?[outfit[slot] ?? "basic"] else { continue }
            if let p = e.part { s.insert(p) }
            if let k = e.mesh, let p = Self.clothPart[k] { s.insert(p) }
        }
        return s
    }

    private func tick(_ dt: TimeInterval) {
        holder.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        if useUSDAnimation {
            // USD 動畫只帶動本體；描邊複本是後加的，動畫碰不到，每格照抄本體的骨頭（最多晚一格）
            for b in bodies {
                if let ol = outlines[ObjectIdentifier(b.entity)], ol.isEnabled { Self.copyJoints(from: b.entity, to: ol) }
            }
            return
        }
        guard let clip = clips[move] else { return }
        let reduce = UIAccessibility.isReduceMotionEnabled
        if !paused && !reduce { time += dt }
        // 減少動態效果：停在動作最深的那一格
        let t = reduce ? Double(clip.frames.count / 2) / clip.fps : time
        let pose = clip.pose(at: t)
        for b in bodies {
            guard let map = jointMap[ObjectIdentifier(b.entity)], !map.isEmpty else { continue }
            Self.setJoints(b.entity, pose, map)
            if let ol = outlines[ObjectIdentifier(b.entity)], ol.isEnabled { Self.setJoints(ol, pose, map) }
        }
        if bloomOn, !bloom.formatNote.isEmpty, !report.contains(where: { $0.hasPrefix("泛光") }) {
            report.append("泛光 " + bloom.formatNote)
        }
        model.position.y = clip.lift(at: t, parts: activeParts)
        for pe in propEntities where !pe.anim.isEmpty { pe.entity.transform = Self.propTransform(pe.anim, t * clip.fps) }
    }

    private static func jointNames(_ e: Entity) -> [String] {
        if let me = e as? ModelEntity, !me.jointNames.isEmpty { return me.jointNames }
        if #available(iOS 18.0, *), let p = e.components[SkeletalPosesComponent.self]?.poses.default {
            return p.jointNames
        }
        return []
    }

    private static func setJoints(_ e: Entity, _ pose: [Transform], _ map: [Int?]) {
        if let me = e as? ModelEntity, !me.jointNames.isEmpty {
            var jt = me.jointTransforms
            for (i, k) in map.enumerated() where k != nil && i < jt.count { jt[i] = pose[k!] }
            me.jointTransforms = jt
            return
        }
        if #available(iOS 18.0, *), var c = e.components[SkeletalPosesComponent.self], var p = c.poses.default {
            let n = p.jointTransforms.count
            for (i, k) in map.enumerated() where k != nil && i < n { p.jointTransforms[i] = pose[k!] }
            c.poses.default = p
            e.components.set(c)
        }
    }

    private static func copyJoints(from src: Entity, to dst: Entity) {
        if let s = src as? ModelEntity, let d = dst as? ModelEntity, !s.jointNames.isEmpty {
            d.jointTransforms = s.jointTransforms
            return
        }
        if #available(iOS 18.0, *), let c = src.components[SkeletalPosesComponent.self] {
            dst.components.set(c)
        }
    }

    func rotate(by dx: CGFloat) { yaw += Float(dx) * 0.01 }
    func toggleStats() { arView.debugOptions = showStats ? [.showStatistics] : [] }
}

private struct Hero3DViewport: UIViewRepresentable {
    let model: Hero3DModel
    func makeUIView(context: Context) -> ARView { model.arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}

struct Hero3DLabView: View {
    @StateObject private var m = Hero3DModel()
    @State private var lastDrag: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Hero3DViewport(model: m)
                .frame(height: 420)
                .gesture(DragGesture()
                    .onChanged { g in m.rotate(by: g.translation.width - lastDrag); lastDrag = g.translation.width }
                    .onEnded { _ in lastDrag = 0 })
            Form {
                Section("動作") {
                    Picker("動作", selection: $m.move) {
                        Text("深蹲").tag("squat"); Text("伏地挺身").tag("pushup")
                    }
                    .pickerStyle(.segmented)
                    Toggle("暫停", isOn: $m.paused)
                    Toggle("改用 USD 內建動畫（只有深蹲）", isOn: $m.useUSDAnimation)
                }
                Section("上衣／下身（可混搭）") {
                    ForEach(["top", "bottom"], id: \.self) { slot in
                        Picker(slot == "top" ? "上衣" : "下身", selection: Binding(get: { m.outfit[slot] ?? "basic" },
                                                         set: { m.outfit[slot] = $0 })) {
                            ForEach(m.outfitOptions(slot), id: \.self) { Text(Hero3DModel.seriesName[$0] ?? $0).tag($0) }
                        }
                    }
                }
                Section("裝備") {
                    ForEach(Hero3DModel.slots) { slot in
                        Picker(slot.name, selection: Binding(get: { m.choice[slot.id] ?? "basic" },
                                                             set: { m.choice[slot.id] = $0 })) {
                            ForEach(m.options(for: slot.id), id: \.self) { Text(Hero3DModel.seriesName[$0] ?? $0).tag($0) }
                        }
                    }
                }
                Section("描邊") {
                    HStack {
                        Text("描邊 \(m.outlineWidth, specifier: "%.0f") mm").font(.caption.monospacedDigit())
                        Slider(value: $m.outlineWidth, in: 2...30, step: 1)
                    }
                    Text(m.vertexLine).font(.caption.monospaced())
                    Toggle("顯示效能數字", isOn: $m.showStats)
                }
                Section("泛光") {
                    Toggle("泛光", isOn: $m.bloomOn)
                    if m.bloomOn {
                        HStack {
                            Text("強度 \(m.bloomStrength, specifier: "%.1f")").font(.caption.monospacedDigit())
                            Slider(value: $m.bloomStrength, in: 0...3, step: 0.1)
                        }
                        HStack {
                            Text("門檻 \(m.bloomThreshold, specifier: "%.2f")").font(.caption.monospacedDigit())
                            Slider(value: $m.bloomThreshold, in: 0.7...1, step: 0.01)
                        }
                    }
                }
                Section("診斷（截圖給 Claude）") {
                    ForEach(m.report, id: \.self) { Text($0).font(.caption.monospaced()) }
                }
            }
        }
        .navigationTitle("3D 測試")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: m.choice) { _, _ in m.applyChoice() }
        .onChange(of: m.outfit) { _, _ in m.applyOutfit(); m.applyChoice() }
        .onChange(of: m.move) { _, _ in m.applyChoice() }
        .onChange(of: m.useUSDAnimation) { _, _ in m.applyChoice() }
        .onChange(of: m.outlineWidth) { _, _ in m.applyOutlineWidth() }
        .onChange(of: m.bloomOn) { _, _ in m.applyBloom() }
        .onChange(of: m.bloomStrength) { _, _ in m.applyBloom() }
        .onChange(of: m.bloomThreshold) { _, _ in m.applyBloom() }
        .onChange(of: m.showStats) { _, _ in m.toggleStats() }
    }
}

/// 動作示範用的 3D 畫面（0.56.0）：穿使用者目前的裝備播一個動作，手指左右拖曳轉視角。
/// 只在有 `hero3d_clip_<動作>.json` 時使用（`Hero3DMoves`）。
struct Hero3DDemoView: View {
    let move: String
    let loadout: Loadout
    @StateObject private var m: Hero3DModel
    @State private var lastDrag: CGFloat = 0

    init(move: String, loadout: Loadout) {
        self.move = move
        self.loadout = loadout
        _m = StateObject(wrappedValue: Hero3DModel(demo: true, move: move))
    }

    var body: some View {
        Hero3DViewport(model: m)
            .gesture(DragGesture()
                .onChanged { g in m.rotate(by: g.translation.width - lastDrag); lastDrag = g.translation.width }
                .onEnded { _ in lastDrag = 0 })
            .onAppear { m.apply(loadout: loadout) }
            .onChange(of: move) { _, new in m.move = new; m.applyChoice() }
            .onChange(of: loadout) { _, l in m.apply(loadout: l) }
            .accessibilityHidden(true)
    }
}
