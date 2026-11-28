import SwiftUI
import RealityKit
import Combine
import Metal

// 正式畫面用的 3D 角色（2026-11-26 起）。測試頁 Hero3DLab.swift 留著做實驗；這裡只放正式要的：
// 卡通著色、著色器描邊、依背包換裝、播動作片段、減少動態效果時停格。沒有泛光（使用者決定不用）。
//
// 用法：`CharacterStage(move:loadout:…)`。App 裡有這個動作的 3D 片段（hero3d_clip_<動作>.json）就畫 3D，
// 沒有就退回 2D 的 CharacterView，所以片段匯出一個、畫面就多一個 3D，不用等全部做完。
// 資料格式（Hero3DInfo、Hero3DClip）沿用 Hero3DLab.swift，由 scripts/blender/build_app.sh 產生，這裡只讀不改。

// MARK: - 動作的 3D 設定

enum Hero3DMoves {
    /// 2D 動作名稱和 3D 片段名稱不同的（其他一律同名）
    static let alias: [CharacterMove: String] = [.latPulldown: "pulldown"]

    static func key(for move: CharacterMove) -> String { alias[move] ?? move.rawValue }

    // 以下照 scripts/blender/moves/*.py 的 MOVE_META（2026-11-26 讀出，95 個動作）。新增動作時要一起補。
    /// bell：手上拿啞鈴，才顯示「啞鈴造型」部位
    static let bell: Set<String> = [
        "arnoldPress", "benchPress", "bridge", "calf", "chestRearFly", "chestRow", "concentrationCurl", "curl", "dbFly",
        "declineCrunch", "farmerWalk", "floorPress", "inclineCurl", "inclineFly", "inclinePress", "kickback", "lateral",
        "leanLateral", "lunge", "press", "pullover", "rdl", "rearFly", "reverseLunge", "row", "sideLyingLateral",
        "skullCrusher", "slRdl", "splitSquat", "squat", "stepUp", "suitcaseCarry", "triceps",
    ]
    /// lean_back：背靠椅背／躺著，隱藏背部裝備（披風、背包、尾巴）
    static let leanBack: Set<String> = [
        "benchPress", "bridge", "bwBridge", "cableCrunch", "closePulldown", "dbFly", "deadBug", "declineCrunch",
        "floorPress", "hipThrust", "inclineCurl", "inclineFly", "inclinePress", "kneeHug", "oneArmPulldown",
        "overheadCableExt", "pulldown", "pullover", "reverseCrunch", "sideLyingLateral", "skullCrusher", "wallSlide",
    ]
    /// Blender 已做好的全部動作（預覽頁列表用）
    static let all: [String] = [
        "armCircle", "armSwing", "arnoldPress", "assistedPullup", "benchDip", "benchPress", "birdDog", "breathe",
        "bridge", "bwBridge", "bwSquat", "cableCrunch", "cableLateral", "calf", "calfSingle", "calfStretch",
        "chestRearFly", "chestRow", "chestStretch", "childPose", "chinup", "closePulldown", "cobra",
        "concentrationCurl", "crossBody", "curl", "dbFly", "deadBug", "declineCrunch", "declinePushup", "drink",
        "elevatedBenchDip", "elevatedPike", "facePull", "farmerWalk", "floorPress", "hangingKnee", "highChop",
        "hipFlexor", "hipHinge", "hipThrust", "inclineCurl", "inclineFly", "inclinePress", "kbSwing", "kickback",
        "kneeHug", "lateral", "leanLateral", "legCurl", "legExtension", "legPress", "legSwing", "lunge", "lungeStep",
        "machineChestPress", "machineLegCurl", "machineRearDelt", "machineShoulderPress", "oneArmPulldown",
        "overheadCableExt", "pikePushup", "plank", "press", "proneYTW", "pulldown", "pullover", "pullup", "pushup",
        "quadStretch", "rdl", "ready", "rearFly", "reverseCrunch", "reverseLunge", "reverseNordic", "row",
        "seatedCableRow", "seatedFold", "sideLyingLateral", "sidePlank", "sissySquat", "skullCrusher", "slRdl",
        "slTowelLegCurl", "splitSquat", "squat", "stepUp", "straightArmPulldown", "suitcaseCarry", "towelLegCurl",
        "triceps", "tricepsPushdown", "tricepsStretch", "wallSlide",
    ]
}

// MARK: - 背包 → 3D 零件

/// 每個部位穿哪個系列的 3D 零件。背包沒穿、或該系列沒有這個部位的 3D 零件時，用基本款（背部用「無」）：
/// 眼睛在 head_*、手掌在 hands_* 裡，空著會沒有眼睛和手；赤膊、赤腳、內褲還沒有 3D 版。
/// 特效（fx）還沒有 3D 版，先不顯示。
struct Hero3DLook: Equatable {
    var head = "basic", hands = "basic", feet = "basic", bell = "basic"
    var back: String?
    var top = "basic", bottom = "basic"

    init() {}

    init(loadout: Loadout, info: Hero3DInfo?) {
        let parts = Set(info?.parts ?? [])
        func rigid(_ slot: GearSlot) -> String? {
            guard let s = loadout.item(slot)?.series, parts.contains("\(slot.rawValue)_\(s)") else { return nil }
            return s
        }
        func outfit(_ slot: GearSlot) -> String {
            guard let s = loadout.item(slot)?.series, info?.outfits?[slot.rawValue]?[s] != nil else { return "basic" }
            return s
        }
        head = rigid(.head) ?? "basic"
        hands = rigid(.hands) ?? "basic"
        feet = rigid(.feet) ?? "basic"
        bell = rigid(.bell) ?? "basic"
        back = rigid(.back)
        top = outfit(.top)
        bottom = outfit(.bottom)
    }

    var series: Set<String> { Set([head, hands, feet, bell, top, bottom] + [back].compactMap { $0 }) }

    /// 某部位實際顯示的系列（預覽頁用）；nil＝不顯示
    func shown(_ slot: GearSlot) -> String? {
        switch slot {
        case .head: return head
        case .hands: return hands
        case .feet: return feet
        case .bell: return bell
        case .back: return back
        case .top: return top
        case .bottom: return bottom
        case .fx: return nil
        }
    }
}

// MARK: - 器材（椅子、單槓、滑輪架、機器）

/// 器材檔（hero3d_prop_<動作>.json；頂點資料在同名 .bin），由 scripts/blender/build_moves.sh 產生
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

/// 讀好的器材資料（還沒變成 RealityKit 網格；單元測試直接用這個檢查載入路徑）
struct Hero3DPropData {
    struct Group {
        let name: String
        let mat: String
        let matInfo: Hero3DInfo.Mat?
        let outline: Bool
        let pos: [SIMD3<Float>]
        let nor: [SIMD3<Float>]
        let idx: [UInt32]
        let anim: [[Float]]?
    }
    let groups: [Group]

    static func urls(_ key: String, bundle: Bundle = .main) -> (json: URL, bin: URL)? {
        guard let j = bundle.url(forResource: "hero3d_prop_\(key)", withExtension: "json"),
              let b = bundle.url(forResource: "hero3d_prop_\(key)", withExtension: "bin") else { return nil }
        return (j, b)
    }

    /// 沒有器材檔＝nil；資料長度不對的零件跳過
    static func load(_ key: String, bundle: Bundle = .main) -> Hero3DPropData? {
        guard let u = urls(key, bundle: bundle),
              let pi = try? JSONDecoder().decode(Hero3DPropInfo.self, from: Data(contentsOf: u.json)),
              let bin = try? Data(contentsOf: u.bin) else { return nil }
        let groups = pi.groups.compactMap { g -> Group? in
            let (pos, nor, idx) = readGroup(bin, g)
            guard pos.count == g.nv, !idx.isEmpty else { return nil }
            return Group(name: g.name, mat: g.mat, matInfo: pi.materials[g.mat], outline: g.outline,
                         pos: pos, nor: nor, idx: idx, anim: g.anim)
        }
        return Hero3DPropData(groups: groups)
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
    static func transform(_ fr: [[Float]], _ x: Double) -> Transform {
        let n = fr.count
        let i0 = Int(x) % n, i1 = (i0 + 1) % n, a = Float(x - Double(Int(x)))
        let p = fr[i0], q = fr[i1]
        func v(_ r: [Float], _ o: Int) -> SIMD3<Float> { SIMD3(r[o], r[o + 1], r[o + 2]) }
        let r0 = simd_quatf(ix: p[3], iy: p[4], iz: p[5], r: p[6]), r1 = simd_quatf(ix: q[3], iy: q[4], iz: q[5], r: q[6])
        return Transform(scale: v(p, 7) + (v(q, 7) - v(p, 7)) * a, rotation: simd_slerp(r0, r1, a),
                         translation: v(p, 0) + (v(q, 0) - v(p, 0)) * a)
    }

    /// 同位置的頂點法線取平均（硬邊撐開不裂）。描邊用
    static func smoothNormals(_ pos: [SIMD3<Float>], _ normals: [SIMD3<Float>]) -> [SIMD3<Float>] {
        var acc: [SIMD3<Int32>: SIMD3<Float>] = [:]
        func k(_ v: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(v * 10000, rounding: .toNearestOrAwayFromZero) }
        for i in pos.indices where i < normals.count { acc[k(pos[i]), default: .zero] += normals[i] }
        return pos.map { v -> SIMD3<Float> in
            let s = acc[k(v)] ?? .zero
            let l = simd_length(s)
            return l > 1e-6 ? s / l : .zero
        }
    }
}

/// 組好的器材範本：每個畫面 clone `root` 一份（網格、材質共用）
struct Hero3DProp {
    let root: Entity
    /// 和 root.children 同順序；空陣列＝靜止的零件
    let anims: [[[Float]]]
    /// 第 0 格的範圍（角色座標，未轉向），鏡頭取景用
    let lo: SIMD3<Float>
    let hi: SIMD3<Float>
}

// MARK: - 共用資源（所有角色畫面共用：材質表、模型範本、片段、貼圖、描邊法線、器材）

@MainActor
final class Hero3DAssets {
    static let shared = Hero3DAssets()

    let info: Hero3DInfo?
    private(set) var materials: [any RealityKit.Material] = []
    private(set) var matIndex: [String: Int] = [:]
    private(set) var fallbackMat = 0
    private(set) var outlineMat: CustomMaterial?
    /// 描邊厚度（毫米，模型座標），和測試頁預設一樣
    static let outlineWidth: Float = 10

    private var clips: [String: Hero3DClip] = [:]
    private var templates: [String: Entity] = [:]
    private var failed: Set<String> = []
    private var textures: [String: TextureResource] = [:]
    private var props: [String: Hero3DProp] = [:]
    private var metalLib: MTLLibrary?
    /// 描邊用的 part（同位置頂點的法線取平均），key＝檔名|model|part
    var smoothParts: [String: MeshResource.Part] = [:]

    private init() {
        info = Bundle.main.url(forResource: "hero3d", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(Hero3DInfo.self, from: $0) }
        if info != nil { makeMaterials() }
    }

    /// 這個動作能不能畫 3D（模型、材質、片段都在）
    func hasClip(_ key: String) -> Bool {
        guard info != nil, !materials.isEmpty, !failed.contains("clip_" + key) else { return false }
        return Bundle.main.url(forResource: "hero3d_clip_\(key)", withExtension: "json") != nil
    }

    func clip(_ key: String) -> Hero3DClip? {
        if let c = clips[key] { return c }
        guard !failed.contains("clip_" + key),
              let u = Bundle.main.url(forResource: "hero3d_clip_\(key)", withExtension: "json"),
              let c = try? JSONDecoder().decode(Hero3DClip.self, from: Data(contentsOf: u)) else {
            failed.insert("clip_" + key); return nil
        }
        clips[key] = c
        return c
    }

    /// 模型檔只讀一次，之後每個畫面各 clone 一份（網格資源共用）
    func template(_ file: String) -> Entity? {
        if let t = templates[file] { return t }
        guard !failed.contains(file), let u = Bundle.main.url(forResource: file, withExtension: "usdz"),
              let e = try? Entity.load(contentsOf: u) else {
            failed.insert(file); return nil
        }
        templates[file] = e
        return e
    }

    /// 系列 → 零件所在的模型檔；沒分檔的在主檔
    func file(for series: String) -> String { info?.files?[series] ?? "hero3d" }

    func texture(_ name: String) -> TextureResource? {
        if let t = textures[name] { return t }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let t = try? TextureResource.load(contentsOf: url, withName: name,
                                                options: TextureResource.CreateOptions(semantic: .raw, mipmapsMode: .none))
        else { return nil }
        textures[name] = t
        return t
    }

    /// 器材：同一個動作只讀檔、組網格一次，之後每個畫面 clone（和 Hero3DLab 0.56.0 的 loadProps 同一套組法）
    func prop(_ key: String) -> Hero3DProp? {
        if let p = props[key] { return p }
        guard !failed.contains("prop_" + key), let lib = metalLib, let data = Hero3DPropData.load(key) else {
            failed.insert("prop_" + key); return nil
        }
        let root = Entity()
        root.name = "prop_" + key
        var anims: [[[Float]]] = []
        var mats: [String: any RealityKit.Material] = [:]
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude), hi = -lo
        for g in data.groups {
            var d = MeshDescriptor(name: g.name)
            d.positions = MeshBuffers.Positions(g.pos)
            d.normals = MeshBuffers.Normals(g.nor)
            d.primitives = .triangles(g.idx)
            guard let mesh = try? MeshResource.generate(from: [d]) else { continue }
            let mat: any RealityKit.Material
            if let m = mats[g.mat] {
                mat = m
            } else {
                mat = g.matInfo.flatMap { try? Self.makeMaterial($0, lib) } ?? UnlitMaterial(color: .gray)
                mats[g.mat] = mat
            }
            let e = ModelEntity(mesh: mesh, materials: [mat])
            e.name = g.name
            if g.outline, let olm = outlineMat {
                var od = d
                od.normals = MeshBuffers.Normals(Hero3DPropData.smoothNormals(g.pos, g.nor))
                if let om = try? MeshResource.generate(from: [od]) {
                    let o = ModelEntity(mesh: om, materials: [olm])
                    o.name = g.name + "_outline"
                    e.addChild(o)       // 描邊跟著本體動
                }
            }
            root.addChild(e)
            anims.append(g.anim ?? [])
            let m = g.anim.flatMap { $0.first }.map { Hero3DPropData.transform([$0], 0).matrix } ?? matrix_identity_float4x4
            for p in g.pos {
                let w = m * SIMD4<Float>(p, 1)
                let v = SIMD3<Float>(w.x, w.y, w.z)
                lo = pointwiseMin(lo, v)
                hi = pointwiseMax(hi, v)
            }
        }
        guard !anims.isEmpty else { failed.insert("prop_" + key); return nil }
        let p = Hero3DProp(root: root, anims: anims, lo: lo, hi: hi)
        props[key] = p
        return p
    }

    private static func srgb(_ c: [Float]) -> UIColor {
        func f(_ x: Float) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
        return UIColor(red: f(c[0]), green: f(c[1]), blue: f(c[2]), alpha: 1)
    }

    /// 一個材質（卡通／純色／換裝），身體、零件、器材共用；和 Hero3DLab 的 makeMaterial 相同（不含泛光的亮度上限）
    private static func makeMaterial(_ mi: Hero3DInfo.Mat, _ lib: MTLLibrary) throws -> CustomMaterial {
        var m: CustomMaterial
        if mi.kind == "outfit" {
            m = try CustomMaterial(surfaceShader: .init(named: "outfitSurface", in: lib), lightingModel: .unlit)
            m.baseColor = .init(tint: srgb(mi.color))
            m.custom.value = SIMD4(0, 0, 0, mi.shade ?? 0.55)
        } else if mi.kind == "toon" {
            m = try CustomMaterial(surfaceShader: .init(named: "toonSurface", in: lib), lightingModel: .unlit)
            m.baseColor = .init(tint: srgb(mi.color))
            let alt = mi.alt ?? [0, 0, 0]
            m.custom.value = SIMD4(alt[0], alt[1], alt[2], mi.shade ?? 0.55)
            m.roughness = .init(floatLiteral: mi.altShade ?? 0.6)
            m.metallic = .init(floatLiteral: (mi.spec ?? false) ? 1 : 0)
        } else {
            m = try CustomMaterial(surfaceShader: .init(named: "flatSurface", in: lib), lightingModel: .unlit)
            let k = min(mi.strength ?? 1, 2)
            m.baseColor = .init(tint: srgb(mi.color.map { min($0 * k, 1) }))
            m.custom.value = SIMD4(0, 0, 0, (mi.strength ?? 1) >= 2 ? 1 : 0)
        }
        m.specular = .init(floatLiteral: 1)
        return m
    }

    private func makeMaterials() {
        guard let device = MTLCreateSystemDefaultDevice(), let lib = device.makeDefaultLibrary() else { return }
        metalLib = lib
        do {
            let flat = CustomMaterial.SurfaceShader(named: "flatSurface", in: lib)
            var list: [any RealityKit.Material] = []
            var index: [String: Int] = [:]
            let used = Set((info?.meshes ?? []).compactMap { $0.components(separatedBy: "__").dropFirst().first })
            for name in used.sorted() {
                guard let mi = info?.materials[name] else { continue }
                index[name] = list.count
                list.append(try Self.makeMaterial(mi, lib))
            }
            var ol = try CustomMaterial(surfaceShader: flat,
                                        geometryModifier: CustomMaterial.GeometryModifier(named: "outlineGeom", in: lib),
                                        lightingModel: .unlit)
            ol.baseColor = .init(tint: UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1))
            ol.specular = .init(floatLiteral: 1)
            ol.faceCulling = .front
            ol.custom.value = SIMD4(Self.outlineWidth / 1000, 0, 0, 0)
            fallbackMat = list.count
            list.append(UnlitMaterial(color: .gray))
            materials = list
            matIndex = index
            outlineMat = ol
        } catch {
            materials = []      // 材質做不出來就整個退回 2D
        }
    }
}

// MARK: - 單一角色畫面

@MainActor
final class Hero3DStageModel {
    let arView: ARView
    private let holder = Entity()            // 轉向用
    private let model = Entity()             // 抬高用（接地修正）
    private let propRoot = Entity()          // 器材：跟著轉向，不跟著抬高（和 Hero3DLab 0.56.0 示範頁相同）
    private var propParts: [(entity: Entity, anim: [[Float]])] = []
    private let cam = PerspectiveCamera()
    private var spin: Float = 0
    private struct Body {
        let entity: Entity
        let file: String
        let contents: MeshResource.Contents
        let tags: [String: (part: String, mat: String)]   // key = model id + "|" + part id
    }
    private var bodies: [Body] = []
    private var outlines: [ObjectIdentifier: Entity] = [:]
    private var jointMap: [ObjectIdentifier: [Int?]] = [:]
    private var mappedJoints: [String] = []
    private var loadedFiles: Set<String> = []
    private var mats: [any RealityKit.Material]
    private var clip: Hero3DClip?
    private var moveKey = ""
    private var look: Hero3DLook?
    private var active: Set<String> = []
    private var animated = true
    private var posed = false
    private var time: Double = 0
    private var sub: Cancellable?
    private var assets: Hero3DAssets { .shared }

    /// 斜側面：看得到身體前後的動作，也看得到正面的裝備
    static let yaw: Float = -0.5
    static let fov: Float = 30
    /// CharacterStage 的畫面比例（寬／高），鏡頭取景用
    static let aspect: Float = 180 / 204

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear
        arView.isOpaque = false
        mats = Hero3DAssets.shared.materials
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        cam.camera.fieldOfViewInDegrees = Self.fov
        anchor.addChild(cam)
        anchor.addChild(holder)
        holder.addChild(model)
        holder.addChild(propRoot)
        holder.orientation = simd_quatf(angle: Self.yaw, axis: [0, 1, 0])
        frameCamera(nil)
        sub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
            MainActor.assumeIsolated { self?.tick(ev.deltaTime) }
        }
    }

    func stop() {
        sub?.cancel()
        sub = nil
    }

    /// spin：使用者拖曳加上的轉向（弧度），疊在預設的斜側面上
    func update(move key: String, look newLook: Hero3DLook, animated: Bool, spin newSpin: Float = 0) {
        if animated != self.animated { self.animated = animated; posed = false }
        if newSpin != spin {
            spin = newSpin
            holder.orientation = simd_quatf(angle: Self.yaw + spin, axis: [0, 1, 0])
        }
        var changed = false
        if key != moveKey, let c = assets.clip(key) {
            moveKey = key
            clip = c
            time = 0
            changed = true
            if c.joints != mappedJoints { mapJoints(bodies[...]) }
            loadProps(key)
        }
        if newLook != look {
            if newLook.top != look?.top || newLook.bottom != look?.bottom { applyOutfit(newLook) }
            look = newLook
            changed = true
        }
        if changed { rebuild() }
    }

    // MARK: 器材

    /// 換動作時換器材（沒有器材檔的動作就清空）。範本在 Hero3DAssets 共用，這裡 clone 一份
    private func loadProps(_ key: String) {
        propRoot.children.removeAll()
        propParts = []
        let p = assets.prop(key)
        if let p {
            let root = p.root.clone(recursive: true)
            propRoot.addChild(root)
            propParts = zip(root.children, p.anims).compactMap { e, a -> (entity: Entity, anim: [[Float]])? in
                a.isEmpty ? nil : (entity: e, anim: a)
            }
        }
        frameCamera(p)
        posed = false
    }

    /// 預設鏡頭（角色站著剛好）；器材超出畫面（滑輪架、單槓比人高）時往後拉、取景中心跟著移
    private func frameCamera(_ p: Hero3DProp?) {
        let defaultCenter: Float = 0.8, defaultDist: Float = 4.6
        // 預設鏡頭看得到的範圍（約 -0.43～2.03 m 高、水平半寬 1.09 m），留點邊
        let baseTop: Float = 2.0, baseBottom: Float = -0.4, baseRadius: Float = 0.9
        var top = baseTop, bottom = baseBottom, radius = baseRadius
        if let p {
            top = max(top, p.hi.y + 0.08)
            bottom = min(bottom, p.lo.y - 0.05)
            // 可以轉向：取水平面上離中心最遠的角
            for x in [p.lo.x, p.hi.x] { for z in [p.lo.z, p.hi.z] { radius = max(radius, (x * x + z * z).squareRoot()) } }
        }
        guard top > baseTop || bottom < baseBottom || radius > baseRadius else {
            cam.look(at: [0, defaultCenter, 0], from: [0, defaultCenter + 0.4, defaultDist], relativeTo: nil)
            return
        }
        let tanHalf = tanf(Self.fov / 2 * .pi / 180)
        let half = max((top - bottom) / 2, radius / Self.aspect) * 1.05
        // 靠近鏡頭的器材透視會放大，多退半個半徑
        let dist = half / tanHalf + radius * 0.5
        let center = max(defaultCenter, (top + bottom) / 2)
        cam.look(at: [0, center, 0], from: [0, center + 0.4 * dist / defaultDist, dist], relativeTo: nil)
    }

    // MARK: 載入

    private func ensureLoaded() {
        guard let look else { return }
        for f in ["hero3d"] + look.series.sorted().map(assets.file(for:)) where !loadedFiles.contains(f) {
            loadedFiles.insert(f)
            guard let t = assets.template(f) else { continue }
            let root = t.clone(recursive: true)
            model.addChild(root)
            let first = bodies.count
            collectBodies(root, file: f)
            mapJoints(bodies[first...])
        }
    }

    /// 和 Hero3DLab 的 collectBodies 相同：RealityKit 把同一副骨架的網格合成一個實體，零件在 part 這層辨認
    private func collectBodies(_ root: Entity, file: String) {
        let first = bodies.count
        let names = (assets.info?.meshes ?? []).sorted { $0.count > $1.count }
        func match(_ s: String) -> String? { names.first { s.contains($0) } }
        func walk(_ e: Entity, _ parent: String) {
            let chain = parent + "/" + e.name
            if let mc = e.components[ModelComponent.self] {
                let c = mc.mesh.contents
                var tags: [String: (part: String, mat: String)] = [:]
                for m in c.models {
                    let inst = c.instances.filter { $0.model == m.id }.map(\.id).joined(separator: "|")
                    for p in m.parts {
                        guard let t = match(p.id) ?? match(m.id) ?? match(inst) ?? match(chain) else { continue }
                        let sp = t.components(separatedBy: "__")
                        tags[m.id + "|" + p.id] = (sp[0], sp.count > 1 ? sp[1] : "")
                    }
                }
                bodies.append(Body(entity: e, file: file, contents: c, tags: tags))
            }
            for ch in e.children { walk(ch, chain) }
        }
        walk(root, "")
        for b in bodies[first...] {
            let ol = b.entity.clone(recursive: false)
            ol.name = b.entity.name + "_outline"
            ol.isEnabled = false
            b.entity.parent?.addChild(ol)
            outlines[ObjectIdentifier(b.entity)] = ol
        }
    }

    private func mapJoints(_ list: ArraySlice<Body>) {
        guard let clip else { return }
        mappedJoints = clip.joints
        let idx = Dictionary(clip.joints.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let short = Dictionary(clip.joints.enumerated().map { ($1.components(separatedBy: "/").last!, $0) },
                               uniquingKeysWith: { a, _ in a })
        for b in list {
            jointMap[ObjectIdentifier(b.entity)] = Self.jointNames(b.entity).map { n -> Int? in
                idx[n] ?? short[n.components(separatedBy: "/").last ?? n]
            }
        }
        posed = false
    }

    // MARK: 換裝

    private func applyOutfit(_ look: Hero3DLook) {
        guard let o = assets.info?.outfits else { return }
        let top = o["top"]?[look.top], bottom = o["bottom"]?[look.bottom]
        if let i = assets.matIndex["body"], var m = mats[i] as? CustomMaterial {
            if let n = top?.body, let t = assets.texture(n) { m.custom.texture = .init(t) }
            if let n = bottom?.body, let t = assets.texture(n) { m.baseColor.texture = .init(t) }
            mats[i] = m
        }
        for e in [top, bottom].compactMap({ $0 }) {
            guard let kind = e.mesh, let n = e.cloth, let i = assets.matIndex["cloth_" + kind],
                  var m = mats[i] as? CustomMaterial, let t = assets.texture(n) else { continue }
            m.custom.texture = .init(t)
            m.baseColor.texture = .init(t)
            mats[i] = m
        }
    }

    private func activeParts(_ look: Hero3DLook) -> Set<String> {
        var s: Set<String> = ["base", "head_" + look.head, "hands_" + look.hands, "feet_" + look.feet]
        if Hero3DMoves.bell.contains(moveKey) { s.insert("bell_" + look.bell) }
        if let b = look.back, !Hero3DMoves.leanBack.contains(moveKey) { s.insert("back_" + b) }
        for (slot, series) in [("top", look.top), ("bottom", look.bottom)] {
            guard let e = assets.info?.outfits?[slot]?[series] else { continue }
            if let p = e.part { s.insert(p) }
            if let k = e.mesh, let p = Hero3DModel.clothPart[k] { s.insert(p) }
        }
        return s
    }

    /// 依穿著和動作，從原始內容篩出要顯示的 part，重組網格（和 Hero3DLab 的 applyChoice 相同）
    private func rebuild() {
        guard let look, clip != nil else { return }
        ensureLoaded()
        active = activeParts(look)
        guard let olMat = assets.outlineMat else { return }
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
                    q.materialIndex = t.flatMap { assets.matIndex[$0.mat] } ?? assets.fallbackMat
                    parts.append(q)
                    if t != nil { olParts.append(outlinePart(b.file + "|" + key, p)) }
                }
                if !parts.isEmpty { var mm = m; mm.parts = MeshPartCollection(parts); models.append(mm) }
                if !olParts.isEmpty { var mm = m; mm.parts = MeshPartCollection(olParts); olModels.append(mm) }
            }
            b.entity.isEnabled = !models.isEmpty
            if !models.isEmpty { Self.setMesh(b.entity, b.contents, models, mats) }
            if let ol = outlines[ObjectIdentifier(b.entity)] {
                if !olModels.isEmpty {
                    Self.setMesh(ol, b.contents, olModels, [olMat])
                    ol.isEnabled = true
                } else {
                    ol.isEnabled = false
                }
            }
        }
        posed = false
    }

    private func outlinePart(_ key: String, _ p: MeshResource.Part) -> MeshResource.Part {
        if let c = assets.smoothParts[key] { return c }
        var q = p
        q.materialIndex = 0
        if let normals = p.normals?.elements {
            q.normals = MeshBuffer(Hero3DPropData.smoothNormals(p.positions.elements, normals))
        }
        assets.smoothParts[key] = q
        return q
    }

    // MARK: 播放

    private func tick(_ dt: TimeInterval) {
        guard let clip else { return }
        if !animated && posed { return }
        if animated { time += dt }
        // 不播放（減少動態效果、靜態畫面）：停在動作最深的那一格
        let t = animated ? time : Double(clip.frames.count / 2) / clip.fps
        let pose = clip.pose(at: t)
        for b in bodies where b.entity.isEnabled {
            guard let map = jointMap[ObjectIdentifier(b.entity)], !map.isEmpty else { continue }
            Self.setJoints(b.entity, pose, map)
            if let ol = outlines[ObjectIdentifier(b.entity)], ol.isEnabled { Self.setJoints(ol, pose, map) }
        }
        model.position.y = clip.lift(at: t, parts: active)
        // 器材和角色同一個時間點（停格時也停在同一格）
        for pp in propParts { pp.entity.transform = Hero3DPropData.transform(pp.anim, t * clip.fps) }
        posed = true
    }

    // MARK: 工具（和 Hero3DLab 相同；那邊是 private）

    private static func setMesh(_ e: Entity, _ base: MeshResource.Contents, _ models: [MeshResource.Model],
                                _ materials: [any RealityKit.Material]) {
        var c = base
        let keep = Set(models.map(\.id))
        c.models = MeshModelCollection(models)
        c.instances = MeshInstanceCollection(base.instances.filter { keep.contains($0.model) })
        guard let mesh = try? MeshResource.generate(from: c) else { return }
        var mc = e.components[ModelComponent.self] ?? ModelComponent(mesh: mesh, materials: materials)
        mc.mesh = mesh
        mc.materials = materials
        e.components.set(mc)
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
}

// MARK: - SwiftUI

struct Hero3DCharacterView: UIViewRepresentable {
    let move: String
    let look: Hero3DLook
    var animated = true
    /// 拖曳加上的轉向（弧度）
    var spin: Float = 0

    func makeCoordinator() -> Hero3DStageModel { Hero3DStageModel() }
    func makeUIView(context: Context) -> ARView { context.coordinator.arView }
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(move: move, look: look, animated: animated, spin: spin)
    }
    static func dismantleUIView(_ uiView: ARView, coordinator: Hero3DStageModel) { coordinator.stop() }
}

/// 可以左右拖曳轉視角的 3D 角色（動作介紹頁用；其他畫面不開，免得和捲動搶手勢）
private struct Hero3DRotatableView: View {
    let move: String
    let look: Hero3DLook
    let animated: Bool
    @State private var spin: Float = 0
    @State private var lastDrag: CGFloat = 0

    init(move: String, look: Hero3DLook, animated: Bool) {
        self.move = move
        self.look = look
        self.animated = animated
    }

    var body: some View {
        Hero3DCharacterView(move: move, look: look, animated: animated, spin: spin)
            .contentShape(Rectangle())
            .gesture(DragGesture()
                .onChanged { g in
                    spin += Float(g.translation.width - lastDrag) * 0.01
                    lastDrag = g.translation.width
                }
                .onEnded { _ in lastDrag = 0 })
    }
}

/// 角色畫面的統一入口：有 3D 片段就畫 3D，沒有就退回 2D。
/// showStats：右上角的稀有度／套裝名稱和戰力，位置、字級、顏色照 2D（CharacterRenderer 的「文字」段落），3D 版用疊字。
struct CharacterStage: View {
    let move: CharacterMove
    /// 指定 3D 片段（Blender 新做、2D 沒有的動作，例如 sidePlank）；nil＝照 move
    var key3D: String?
    let loadout: Loadout
    var animated = true
    var showStats = true
    var bonusPower = 0
    /// 手指左右拖曳轉視角（動作介紹頁）；預設關
    var rotatable = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let assets = Hero3DAssets.shared
        let key = key3D ?? Hero3DMoves.key(for: move)
        if assets.hasClip(key) {
            let look = Hero3DLook(loadout: loadout, info: assets.info)
            Group {
                if rotatable {
                    Hero3DRotatableView(move: key, look: look, animated: animated && !reduceMotion)
                } else {
                    Hero3DCharacterView(move: key, look: look, animated: animated && !reduceMotion)
                }
            }
                .aspectRatio(180.0 / 204.0, contentMode: .fit)
                .overlay {
                    if showStats { stats }
                }
                .accessibilityHidden(true)
        } else {
            CharacterView(move: move, loadout: loadout, animated: animated, showStats: showStats, bonusPower: bonusPower)
        }
    }

    /// 2D 的座標系是 180×204，字的右下角在 (156, 16)、(156, 28)；k＝畫面對 2D 座標的縮放
    private var stats: some View {
        GeometryReader { geo in
            let k = min(geo.size.width / 180, geo.size.height / 204)
            let bonus = loadout.setBonus
            let rarity = Rarity(rawValue: loadout.topRarity)
            let rc: Color = bonus.map { Color(gearHex: $0.series.glow) } ?? rarity?.color ?? Color(gearHex: "#2C3440")
            VStack(alignment: .trailing, spacing: 0) {
                if loadout.topRarity > 0 {
                    Text(bonus.map { $0.series.name + "套裝" } ?? rarity?.name ?? "")
                        .font(.system(size: 9 * k, weight: .bold))
                        .tracking(1.5 * k)
                        .foregroundColor(rc)
                }
                Text("戰力 \(loadout.power + bonusPower)")
                    .font(.system(size: 11 * k, weight: .bold))
                    .foregroundColor(Color(gearHex: "#E7EBF0"))
            }
            .padding(.top, 4 * k)
            .padding(.trailing, 24 * k)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
    }
}

// MARK: - 預覽頁（設定 → 3D 角色預覽）

struct Hero3DStagePreview: View {
    @EnvironmentObject private var inventory: InventoryStore
    @State private var key = "squat"
    @State private var animated = true

    var body: some View {
        let assets = Hero3DAssets.shared
        let have = Hero3DMoves.all.filter(assets.hasClip)
        let look = Hero3DLook(loadout: inventory.state.loadout, info: assets.info)
        Form {
            Section {
                Group {
                    if assets.hasClip(key) {
                        Hero3DCharacterView(move: key, look: look, animated: animated)
                    } else {
                        Text("「\(key)」還沒有 3D 片段\n（正式畫面會退回 2D）")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .listRowInsets(EdgeInsets())
                .listRowBackground(RadialGradient(
                    colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                    center: .top, startRadius: 10, endRadius: 320))
            }
            Section("動作") {
                Picker("動作", selection: $key) {
                    ForEach(Hero3DMoves.all, id: \.self) { k in
                        Text(assets.hasClip(k) ? "\(k)（3D）" : k).tag(k)
                    }
                }
                Toggle("播放", isOn: $animated)
                Text("App 裡有 3D 片段的動作：\(have.count)／\(Hero3DMoves.all.count)")
                    .font(.caption)
            }
            Section("目前背包 → 3D（換裝到角色頁）") {
                ForEach(GearSlot.allCases) { slot in
                    HStack {
                        Text(slot.name)
                        Spacer()
                        Text(describe(slot, look)).foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }
        }
        .navigationTitle("3D 角色預覽")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func describe(_ slot: GearSlot, _ look: Hero3DLook) -> String {
        let worn = inventory.state.loadout.item(slot)
        if slot == .fx { return worn == nil ? "無" : "\(worn!.name)（還沒有 3D）" }
        guard let s = look.shown(slot) else { return "無" }
        let name = GearCatalog.seriesById(s)?.name ?? s
        if worn == nil { return "沒穿 → 用\(name)" }
        if worn?.series != s { return "\(worn!.name) → 沒有 3D，用\(name)" }
        return name
    }
}
