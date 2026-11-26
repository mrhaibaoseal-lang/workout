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

// MARK: - 共用資源（所有角色畫面共用：材質表、模型範本、片段、貼圖、描邊法線）

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

    private static func srgb(_ c: [Float]) -> UIColor {
        func f(_ x: Float) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
        return UIColor(red: f(c[0]), green: f(c[1]), blue: f(c[2]), alpha: 1)
    }

    /// 和 Hero3DLab 的 makeMaterials 相同（不含泛光的亮度上限）
    private func makeMaterials() {
        guard let device = MTLCreateSystemDefaultDevice(), let lib = device.makeDefaultLibrary() else { return }
        do {
            let toon = CustomMaterial.SurfaceShader(named: "toonSurface", in: lib)
            let flat = CustomMaterial.SurfaceShader(named: "flatSurface", in: lib)
            let outfitShader = CustomMaterial.SurfaceShader(named: "outfitSurface", in: lib)
            var list: [any RealityKit.Material] = []
            var index: [String: Int] = [:]
            let used = Set((info?.meshes ?? []).compactMap { $0.components(separatedBy: "__").dropFirst().first })
            for name in used.sorted() {
                guard let mi = info?.materials[name] else { continue }
                var m: CustomMaterial
                if mi.kind == "outfit" {
                    m = try CustomMaterial(surfaceShader: outfitShader, lightingModel: .unlit)
                    m.baseColor = .init(tint: Self.srgb(mi.color))
                    m.custom.value = SIMD4(0, 0, 0, mi.shade ?? 0.55)
                } else if mi.kind == "toon" {
                    m = try CustomMaterial(surfaceShader: toon, lightingModel: .unlit)
                    m.baseColor = .init(tint: Self.srgb(mi.color))
                    let alt = mi.alt ?? [0, 0, 0]
                    m.custom.value = SIMD4(alt[0], alt[1], alt[2], mi.shade ?? 0.55)
                    m.roughness = .init(floatLiteral: mi.altShade ?? 0.6)
                    m.metallic = .init(floatLiteral: (mi.spec ?? false) ? 1 : 0)
                } else {
                    m = try CustomMaterial(surfaceShader: flat, lightingModel: .unlit)
                    let k = min(mi.strength ?? 1, 2)
                    m.baseColor = .init(tint: Self.srgb(mi.color.map { min($0 * k, 1) }))
                    m.custom.value = SIMD4(0, 0, 0, (mi.strength ?? 1) >= 2 ? 1 : 0)
                }
                m.specular = .init(floatLiteral: 1)
                index[name] = list.count
                list.append(m)
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
    private let holder = Entity()
    private let model = Entity()
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

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(.clear)
        arView.backgroundColor = .clear
        arView.isOpaque = false
        mats = Hero3DAssets.shared.materials
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 30
        cam.look(at: [0, 0.8, 0], from: [0, 1.2, 4.6], relativeTo: nil)
        anchor.addChild(cam)
        anchor.addChild(holder)
        holder.addChild(model)
        holder.orientation = simd_quatf(angle: Self.yaw, axis: [0, 1, 0])
        sub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
            MainActor.assumeIsolated { self?.tick(ev.deltaTime) }
        }
    }

    func stop() {
        sub?.cancel()
        sub = nil
    }

    func update(move key: String, look newLook: Hero3DLook, animated: Bool) {
        if animated != self.animated { self.animated = animated; posed = false }
        var changed = false
        if key != moveKey, let c = assets.clip(key) {
            moveKey = key
            clip = c
            time = 0
            changed = true
            if c.joints != mappedJoints { mapJoints(bodies[...]) }
        }
        if newLook != look {
            if newLook.top != look?.top || newLook.bottom != look?.bottom { applyOutfit(newLook) }
            look = newLook
            changed = true
        }
        if changed { rebuild() }
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
            let pos = p.positions.elements
            var acc: [SIMD3<Int32>: SIMD3<Float>] = [:]
            func k(_ v: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(v * 10000, rounding: .toNearestOrAwayFromZero) }
            for i in pos.indices where i < normals.count { acc[k(pos[i]), default: .zero] += normals[i] }
            q.normals = MeshBuffer(pos.map { v -> SIMD3<Float> in
                let s = acc[k(v)] ?? .zero
                let l = simd_length(s)
                return l > 1e-6 ? s / l : .zero
            })
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

    func makeCoordinator() -> Hero3DStageModel { Hero3DStageModel() }
    func makeUIView(context: Context) -> ARView { context.coordinator.arView }
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.update(move: move, look: look, animated: animated)
    }
    static func dismantleUIView(_ uiView: ARView, coordinator: Hero3DStageModel) { coordinator.stop() }
}

/// 角色畫面的統一入口：有 3D 片段就畫 3D，沒有就退回 2D。
/// showStats（角色頁的戰力數字）目前只有 2D 版會畫，所以要顯示數字時先用 2D。
struct CharacterStage: View {
    let move: CharacterMove
    /// 指定 3D 片段（Blender 新做、2D 沒有的動作，例如 sidePlank）；nil＝照 move
    var key3D: String?
    let loadout: Loadout
    var animated = true
    var showStats = true
    var bonusPower = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let assets = Hero3DAssets.shared
        let key = key3D ?? Hero3DMoves.key(for: move)
        if !showStats, assets.hasClip(key) {
            Hero3DCharacterView(move: key, look: Hero3DLook(loadout: loadout, info: assets.info),
                                animated: animated && !reduceMotion)
                .aspectRatio(180.0 / 204.0, contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            CharacterView(move: move, loadout: loadout, animated: animated, showStats: showStats, bonusPower: bonusPower)
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
