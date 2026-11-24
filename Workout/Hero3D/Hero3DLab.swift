import SwiftUI
import RealityKit
import Combine
import Metal

// 3D 技術驗證頁（設定 → 3D 測試）。確認 Blender 匯出的 USDZ 能在 RealityKit 即時播放：
// 卡通著色（Toon.metal）、描邊外殼、逐件開關裝備、切換動作、效能和檔案大小。
// 0.38 試做：著色器描邊（同一份網格畫兩次、沿平均法線外撐，取代烘好的 __ol 外殼）、泛光後處理（Hero3DBloom）。
// 檔案由 scripts/blender/build_app.sh 產生：hero3d.usdz（骨架＋全部零件）、hero3d.json（材質表）、hero3d_clip_<動作>.json。

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
    let parts: [String]
    let meshes: [String]
    let materials: [String: Mat]
}

struct Hero3DClip: Decodable {
    let move: String
    let fps: Double
    let joints: [String]
    let frames: [[[Float]]]          // [格][骨頭][tx,ty,tz,qx,qy,qz,qw]
    let low: [String: [Float]]       // 零件 → 每格最低點

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

@MainActor
final class Hero3DModel: ObservableObject {
    struct Slot: Identifiable { let id: String; let name: String }
    static let slots = [Slot(id: "head", name: "頭"), Slot(id: "hands", name: "手"), Slot(id: "feet", name: "腳"),
                        Slot(id: "back", name: "背"), Slot(id: "bell", name: "啞鈴")]
    static let seriesName = ["basic": "基本", "frost": "冰霜", "titan": "鈦甲", "none": "無"]

    @Published var choice: [String: String] = ["head": "basic", "hands": "basic", "feet": "basic", "back": "none", "bell": "basic"]
    @Published var move = "squat"
    @Published var useUSDAnimation = false
    @Published var paused = false
    @Published var outlineCull = 1           // 0 不剔除、1 剔除背面、2 剔除正面（只對烘好的外殼）
    @Published var outlineMode = 2           // 0 無、1 烘好的外殼（__ol）、2 著色器外撐（同一份網格畫兩次）
    @Published var outlineWidth: Float = 10  // 著色器描邊厚度（毫米，模型座標）
    @Published var bloomOn = true
    @Published var bloomStrength: Float = 1.2
    @Published var bloomThreshold: Float = 0.95
    @Published var showStats = true
    @Published var report: [String] = []
    @Published var vertexLine = ""

    let arView: ARView
    private var holder = Entity()            // 轉向用
    private var model = Entity()             // 抬高用
    private var info: Hero3DInfo?
    private var clips: [String: Hero3DClip] = [:]
    // RealityKit 讀 USD 時，綁同一副骨架的網格會合併成「一個」實體，零件變成網格裡的 part。
    // 所以在 part 這層辨認零件（名字 = hero3d.json 的 meshes，例如 head_titan__ol）、套材質、換裝時重組網格。
    private struct Body {
        let entity: Entity
        let contents: MeshResource.Contents                  // 原始內容，換裝時從這裡篩
        let tags: [String: (part: String, mat: String)]      // key = 模型 id + "|" + part id
    }
    private var bodies: [Body] = []
    private var mats: [any RealityKit.Material] = []
    private var matIndex: [String: Int] = [:]
    private var fallbackMat = 0
    private var olShaderMat: CustomMaterial?
    private var outlines: [ObjectIdentifier: Entity] = [:]       // 本體 → 著色器描邊用的複本
    private var smoothCache: [String: MeshResource.Part] = [:]   // 描邊用的 part（法線已平均）
    private let bloom = Hero3DBloom()
    private var jointMap: [ObjectIdentifier: [Int?]] = [:]
    private var time: Double = 0
    private var yaw: Float = 0
    private var sub: Cancellable?

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1))
        arView.debugOptions = [.showStatistics]
        let pass = bloom
        arView.renderCallbacks.prepareWithDevice = { device in pass.prepare(device) }
        load()
        applyBloom()
    }

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
        let pass = bloom
        arView.renderCallbacks.postProcess = bloomOn ? { ctx in pass.run(ctx) } : nil
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
        let order = ["basic", "frost", "titan"]
        return (slot == "back" ? ["none"] : []) + order.filter(have.contains)
    }

    private func load() {
        var log: [String] = []
        let anchor = AnchorEntity(world: .zero)
        arView.scene.addAnchor(anchor)
        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 32
        cam.look(at: [0, 0.85, 0], from: [0, 1.15, 4.4], relativeTo: nil)
        anchor.addChild(cam)
        // 舞台圓台
        let stage = ModelEntity(mesh: .generatePlane(width: 1.6, depth: 1.6, cornerRadius: 0.8),
                                materials: [UnlitMaterial(color: UIColor(red: 0.12, green: 0.14, blue: 0.24, alpha: 1))])
        stage.position.y = -0.001
        anchor.addChild(stage)
        anchor.addChild(holder)
        holder.addChild(model)

        let bundle = Bundle.main
        do {
            guard let infoURL = bundle.url(forResource: "hero3d", withExtension: "json"),
                  let usdURL = bundle.url(forResource: "hero3d", withExtension: "usdz") else {
                report = ["找不到 hero3d.usdz／hero3d.json"]; return
            }
            info = try JSONDecoder().decode(Hero3DInfo.self, from: Data(contentsOf: infoURL))
            for m in ["squat", "pushup"] {
                if let u = bundle.url(forResource: "hero3d_clip_\(m)", withExtension: "json") {
                    clips[m] = try JSONDecoder().decode(Hero3DClip.self, from: Data(contentsOf: u))
                }
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: usdURL.path)[.size] as? Int) ?? 0
            let t0 = CACurrentMediaTime()
            let root = try Entity.load(contentsOf: usdURL)
            log.append(String(format: "載入 %.0f ms，檔案 %.1f MB", (CACurrentMediaTime() - t0) * 1000, Double(size) / 1_048_576))
            model.addChild(root)

            try makeMaterials(&log)
            collectBodies(root, &log)
            log.append("USD 內建動畫 \(root.availableAnimations.count) 段")
            mapJoints(&log)
        } catch {
            log.append("❌ \(error.localizedDescription)")
        }
        report = log
        applyChoice()
        sub = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] ev in
            MainActor.assumeIsolated { self?.tick(ev.deltaTime) }
        }
    }

    private func collectBodies(_ root: Entity, _ log: inout [String]) {
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
        for b in bodies {
            let ol = b.entity.clone(recursive: false)
            ol.name = b.entity.name + "_outline"
            ol.isEnabled = false
            b.entity.parent?.addChild(ol)
            outlines[ObjectIdentifier(b.entity)] = ol
        }
        var vAll = 0, vOl = 0
        for b in bodies {
            for m in b.contents.models {
                for p in m.parts {
                    let n = p.positions.count
                    vAll += n
                    if b.tags[m.id + "|" + p.id]?.mat == "ol" { vOl += n }
                }
            }
        }
        log.append("USDZ 頂點 \(vAll)，其中烘好的描邊外殼 \(vOl)")
        log.append("實體 \(all) 個，有網格 \(bodies.count) 個，part \(partCount) 個，認出零件 \(matched) 個")
        log.append(contentsOf: samples)
    }

    private func srgb(_ c: [Float]) -> UIColor {
        func f(_ x: Float) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
        return UIColor(red: f(c[0]), green: f(c[1]), blue: f(c[2]), alpha: 1)
    }

    private func makeMaterials(_ log: inout [String]) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let lib = device.makeDefaultLibrary() else {
            log.append("❌ 沒有 Metal 函式庫"); return
        }
        let toon = CustomMaterial.SurfaceShader(named: "toonSurface", in: lib)
        let flat = CustomMaterial.SurfaceShader(named: "flatSurface", in: lib)
        var used = Set((info?.meshes ?? []).compactMap { $0.components(separatedBy: "__").dropFirst().first })
        used.insert("ol")
        for name in used.sorted() {
            var m: CustomMaterial
            if name == "ol" {
                m = try CustomMaterial(surfaceShader: flat, lightingModel: .unlit)
                m.baseColor = .init(tint: UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1))
            } else if let mi = info?.materials[name], mi.kind == "toon" {
                m = try CustomMaterial(surfaceShader: toon, lightingModel: .unlit)
                m.baseColor = .init(tint: srgb(mi.color))
                let alt = mi.alt ?? [0, 0, 0]
                m.custom.value = SIMD4(alt[0], alt[1], alt[2], mi.shade ?? 0.55)
                m.roughness = .init(floatLiteral: mi.altShade ?? 0.6)
                m.metallic = .init(floatLiteral: (mi.spec ?? false) ? 1 : 0)
            } else if let mi = info?.materials[name] {
                m = try CustomMaterial(surfaceShader: flat, lightingModel: .unlit)
                let k = min(mi.strength ?? 1, 2)
                m.baseColor = .init(tint: srgb(mi.color.map { min($0 * k, 1) }))
                // 強度 ≥ 2 的算發光（flame、glow、frglow、ring），開泛光時不設亮度上限
                m.custom.value = SIMD4(0, 0, 0, (mi.strength ?? 1) >= 2 ? 1 : 0)
            } else {
                log.append("⚠️ 材質表沒有 \(name)"); continue
            }
            m.specular = .init(floatLiteral: 1)
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
        setOutlineCull()
    }

    func setOutlineCull() {
        guard let i = matIndex["ol"], var m = mats[i] as? CustomMaterial else { return }
        let cull: [MaterialParameterTypes.FaceCulling] = [.none, .back, .front]
        m.faceCulling = cull[outlineCull]
        mats[i] = m
        for b in bodies {
            guard var mc = b.entity.components[ModelComponent.self] else { continue }
            mc.materials = mats
            b.entity.components.set(mc)
        }
    }

    private func mapJoints(_ log: inout [String]) {
        guard let clip = clips.values.first else { log.append("❌ 沒有動作檔"); return }
        let idx = Dictionary(uniqueKeysWithValues: clip.joints.enumerated().map { ($1, $0) })
        let short = Dictionary(clip.joints.enumerated().map { ($1.components(separatedBy: "/").last!, $0) }, uniquingKeysWith: { a, _ in a })
        var matched = 0, total = 0
        for b in bodies {
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
        let active = activeParts
        let shaderOL = outlineMode == 2
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
                    let isOl = t?.mat == "ol"
                    if isOl && outlineMode != 1 { continue }
                    var q = p
                    q.materialIndex = t.flatMap { matIndex[$0.mat] } ?? fallbackMat
                    parts.append(q)
                    if isOl { vLine += p.positions.count } else { vBody += p.positions.count }
                    // 著色器描邊只套卡通材質（眼睛、發光不描）
                    if shaderOL, let t, info?.materials[t.mat]?.kind == "toon" {
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
                if shaderOL, !olModels.isEmpty, let olm = olShaderMat {
                    setMesh(ol, b.contents, olModels, [olm])
                    ol.isEnabled = true
                } else {
                    ol.isEnabled = false
                }
            }
        }
        vertexLine = "畫面上頂點：本體 \(vBody)，描邊 \(vLine)" + (shaderOL ? "（著色器描邊與本體共用頂點資料，USDZ 不用存）" : "")
        if useUSDAnimation, let root = model.children.first, let anim = root.availableAnimations.first {
            root.playAnimation(anim.repeat())
        } else {
            model.children.first?.stopAllAnimations()
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

    /// 描邊用的 part：同位置的頂點法線取平均（硬邊撐開不裂），材質固定第 0 個
    private func outlinePart(_ key: String, _ p: MeshResource.Part) -> MeshResource.Part {
        if let c = smoothCache[key] { return c }
        var q = p
        q.materialIndex = 0
        if let normals = p.normals?.elements {
            let pos = p.positions.elements
            var acc: [SIMD3<Int32>: SIMD3<Float>] = [:]
            func k(_ v: SIMD3<Float>) -> SIMD3<Int32> { SIMD3<Int32>(v * 10000, rounding: .toNearestOrAwayFromZero) }
            for i in pos.indices where i < normals.count { acc[k(pos[i]), default: .zero] += normals[i] }
            let smooth = pos.map { v -> SIMD3<Float> in
                let s = acc[k(v)] ?? .zero
                let l = simd_length(s)
                return l > 1e-6 ? s / l : .zero
            }
            q.normals = MeshBuffer(smooth)
        }
        smoothCache[key] = q
        return q
    }

    private var activeParts: Set<String> {
        var s: Set<String> = ["base"]
        for slot in Self.slots.map(\.id) {
            if let c = choice[slot], c != "none", slot != "bell" || move != "pushup" { s.insert("\(slot)_\(c)") }
        }
        return s
    }

    private func tick(_ dt: TimeInterval) {
        holder.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
        guard !useUSDAnimation, let clip = clips[move] else { return }
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
                Section("裝備") {
                    ForEach(Hero3DModel.slots) { slot in
                        Picker(slot.name, selection: Binding(get: { m.choice[slot.id] ?? "basic" },
                                                             set: { m.choice[slot.id] = $0 })) {
                            ForEach(m.options(for: slot.id), id: \.self) { Text(Hero3DModel.seriesName[$0] ?? $0).tag($0) }
                        }
                    }
                }
                Section("描邊") {
                    Picker("描邊", selection: $m.outlineMode) {
                        Text("無").tag(0); Text("烘好的外殼").tag(1); Text("著色器外撐").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if m.outlineMode == 1 {
                        Picker("剔除", selection: $m.outlineCull) {
                            Text("不剔除").tag(0); Text("背面").tag(1); Text("正面").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    if m.outlineMode == 2 {
                        HStack {
                            Text("厚度 \(m.outlineWidth, specifier: "%.0f") mm").font(.caption.monospacedDigit())
                            Slider(value: $m.outlineWidth, in: 2...30, step: 1)
                        }
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
        .onChange(of: m.move) { _, _ in m.applyChoice() }
        .onChange(of: m.useUSDAnimation) { _, _ in m.applyChoice() }
        .onChange(of: m.outlineCull) { _, _ in m.setOutlineCull() }
        .onChange(of: m.outlineMode) { _, _ in m.applyChoice() }
        .onChange(of: m.outlineWidth) { _, _ in m.applyOutlineWidth() }
        .onChange(of: m.bloomOn) { _, _ in m.applyBloom() }
        .onChange(of: m.bloomStrength) { _, _ in m.applyBloom() }
        .onChange(of: m.bloomThreshold) { _, _ in m.applyBloom() }
        .onChange(of: m.showStats) { _, _ in m.toggleStats() }
    }
}
