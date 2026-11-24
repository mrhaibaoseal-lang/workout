import SwiftUI
import RealityKit
import Combine
import Metal

// 3D 技術驗證頁（設定 → 3D 測試）。確認 Blender 匯出的 USDZ 能在 RealityKit 即時播放：
// 卡通著色（Toon.metal）、描邊外殼、逐件開關裝備、切換動作、效能和檔案大小。
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
    @Published var outlineCull = 1           // 0 不剔除、1 剔除背面、2 剔除正面
    @Published var showStats = true
    @Published var report: [String] = []

    let arView: ARView
    private var holder = Entity()            // 轉向用
    private var model = Entity()             // 抬高用
    private var info: Hero3DInfo?
    private var clips: [String: Hero3DClip] = [:]
    // iOS 18 起載入的網格是一般 Entity（帶 ModelComponent），不再是 ModelEntity，所以一律用元件操作
    private var meshes: [(entity: Entity, part: String, mat: String)] = []
    private var jointMap: [ObjectIdentifier: [Int?]] = [:]
    private var outlineMats: [CustomMaterial] = []
    private var time: Double = 0
    private var yaw: Float = 0
    private var sub: Cancellable?

    init() {
        arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.environment.background = .color(UIColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1))
        arView.debugOptions = [.showStatistics]
        load()
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

            var all = 0, plain = 0, untagged = 0
            func walk(_ e: Entity, _ parentTag: String?) {
                all += 1
                let tag = e.name.contains("__") ? e.name : parentTag
                if e.components.has(ModelComponent.self) {
                    if !(e is ModelEntity) { plain += 1 }
                    if let tag {
                        let parts = tag.components(separatedBy: "__")
                        meshes.append((e, parts[0], parts.count > 1 ? parts[1] : ""))
                    } else { untagged += 1 }
                }
                for c in e.children { walk(c, tag) }
            }
            walk(root, nil)
            let withJoints = meshes.filter { !Self.jointNames($0.entity).isEmpty }
            log.append("實體 \(all) 個，網格 \(meshes.count) 個（非 ModelEntity \(plain)、沒標名 \(untagged)），有骨架 \(withJoints.count) 個")
            log.append("USD 內建動畫 \(root.availableAnimations.count) 段")
            if let first = withJoints.first {
                log.append("骨頭名稱例：\(Self.jointNames(first.entity).prefix(3).joined(separator: ", "))")
            }
            try applyMaterials(&log)
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

    private func srgb(_ c: [Float]) -> UIColor {
        func f(_ x: Float) -> CGFloat { CGFloat(x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055) }
        return UIColor(red: f(c[0]), green: f(c[1]), blue: f(c[2]), alpha: 1)
    }

    private func applyMaterials(_ log: inout [String]) throws {
        guard let device = MTLCreateSystemDefaultDevice(), let lib = device.makeDefaultLibrary() else {
            log.append("❌ 沒有 Metal 函式庫"); return
        }
        let toon = CustomMaterial.SurfaceShader(named: "toonSurface", in: lib)
        let flat = CustomMaterial.SurfaceShader(named: "flatSurface", in: lib)
        var cache: [String: CustomMaterial] = [:]
        for (e, _, matName) in meshes {
            if let m = cache[matName] { Self.setMaterial(e, m); continue }
            var m: CustomMaterial
            if matName == "ol" {
                m = try CustomMaterial(surfaceShader: flat, lightingModel: .unlit)
                m.baseColor = .init(tint: UIColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1))
                outlineMats.append(m)
            } else if let mi = info?.materials[matName], mi.kind == "toon" {
                m = try CustomMaterial(surfaceShader: toon, lightingModel: .unlit)
                m.baseColor = .init(tint: srgb(mi.color))
                let alt = mi.alt ?? [0, 0, 0]
                m.custom.value = SIMD4(alt[0], alt[1], alt[2], mi.shade ?? 0.55)
                m.roughness = .init(floatLiteral: mi.altShade ?? 0.6)
                m.metallic = .init(floatLiteral: (mi.spec ?? false) ? 1 : 0)
            } else if let mi = info?.materials[matName] {
                m = try CustomMaterial(surfaceShader: flat, lightingModel: .unlit)
                let k = min(mi.strength ?? 1, 2)
                m.baseColor = .init(tint: srgb(mi.color.map { min($0 * k, 1) }))
            } else {
                log.append("⚠️ 材質表沒有 \(matName)"); continue
            }
            cache[matName] = m
            Self.setMaterial(e, m)
        }
        setOutlineCull()
    }

    func setOutlineCull() {
        let cull: MaterialParameterTypes.FaceCulling = [.none, .back, .front][outlineCull]
        for (e, _, mat) in meshes where mat == "ol" {
            guard var m = e.components[ModelComponent.self]?.materials.first as? CustomMaterial else { continue }
            m.faceCulling = cull
            Self.setMaterial(e, m)
        }
    }

    private func mapJoints(_ log: inout [String]) {
        guard let clip = clips.values.first else { log.append("❌ 沒有動作檔"); return }
        let idx = Dictionary(uniqueKeysWithValues: clip.joints.enumerated().map { ($1, $0) })
        let short = Dictionary(clip.joints.enumerated().map { ($1.components(separatedBy: "/").last!, $0) }, uniquingKeysWith: { a, _ in a })
        var matched = 0, total = 0
        for (e, _, _) in meshes {
            let map = Self.jointNames(e).map { n -> Int? in
                idx[n] ?? short[n.components(separatedBy: "/").last ?? n]
            }
            matched += map.compactMap { $0 }.count; total += map.count
            jointMap[ObjectIdentifier(e)] = map
        }
        log.append("骨頭對應 \(matched)/\(total)")
    }

    func applyChoice() {
        let bellOK = move != "pushup"
        for (e, part, _) in meshes {
            let slot = String(part.split(separator: "_").first ?? "")
            let series = part.split(separator: "_").dropFirst().joined(separator: "_")
            e.isEnabled = part == "base" || (choice[slot] == series && (slot != "bell" || bellOK))
        }
        if useUSDAnimation, let root = model.children.first, let anim = root.availableAnimations.first {
            root.playAnimation(anim.repeat())
        } else {
            model.children.first?.stopAllAnimations()
        }
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
        for (e, _, _) in meshes where e.isEnabled {
            guard let map = jointMap[ObjectIdentifier(e)], !map.isEmpty else { continue }
            Self.setJoints(e, pose, map)
        }
        model.position.y = clip.lift(at: t, parts: activeParts)
    }

    private static func setMaterial(_ e: Entity, _ m: any RealityKit.Material) {
        guard var mc = e.components[ModelComponent.self] else { return }
        mc.materials = Array(repeating: m, count: max(mc.materials.count, 1))
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
                    Picker("剔除", selection: $m.outlineCull) {
                        Text("不剔除").tag(0); Text("背面").tag(1); Text("正面").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Toggle("顯示效能數字", isOn: $m.showStats)
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
        .onChange(of: m.showStats) { _, _ in m.toggleStats() }
    }
}
