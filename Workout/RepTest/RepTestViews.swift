import SwiftUI
import AVFoundation
import UIKit

// MARK: - 首頁：紀錄清單

/// 設定 → 資料 → 實驗功能 → 數次數測試
struct RepTestHomeView: View {
    @StateObject private var store = RepTestStore()
    @State private var showSession = false
    @State private var shareItems: RepShareItems?
    @State private var errorText: String?

    private var sortedTrials: [RepTrial] {
        store.trials.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Button {
                    showSession = true
                } label: {
                    Label("新增一組", systemImage: "video.badge.plus")
                }
                .frame(minHeight: 44)
                Button {
                    exportAll()
                } label: {
                    Label("匯出全部", systemImage: "square.and.arrow.up")
                }
                .frame(minHeight: 44)
                .disabled(store.trials.isEmpty)
            } footer: {
                SectionLabel("只記錄關節座標，不數次數、不存影像。匯出 trials.csv 和 frames.csv 給 Claude 分析。")
            }
            .listRowBackground(Theme.surface)

            Section {
                if store.trials.isEmpty {
                    Text("還沒有紀錄").foregroundStyle(Theme.muted)
                } else {
                    ForEach(sortedTrials) { t in
                        TrialRow(trial: t)
                    }
                    .onDelete { offsets in
                        let list = sortedTrials
                        for i in offsets { store.delete(list[i]) }
                    }
                }
            } header: {
                SectionLabel("已存的紀錄（左滑刪除）")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("數次數測試")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showSession) {
            RepTestSessionView(store: store)
        }
        .sheet(item: $shareItems) { s in
            ShareSheet(items: s.urls)
        }
        .alert("匯出失敗", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
    }

    private func exportAll() {
        do {
            shareItems = RepShareItems(urls: try store.exportFiles())
        } catch {
            errorText = error.localizedDescription
        }
    }
}

private struct RepShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

private struct TrialRow: View {
    let trial: RepTrial

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_TW")
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(RepTestExercise.find(trial.exerciseId).name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.fg)
                Spacer()
                Text("\(trial.actualReps) 下")
                    .font(Theme.number(18))
                    .foregroundStyle(Theme.accent)
            }
            Text("\(Self.dateFmt.string(from: trial.date))　\(trial.frames) 格　平均 \(String(format: "%.1f", trial.avgFps)) fps"
                 + (trial.partialReps > 0 ? "　半程 \(trial.partialReps)" : ""))
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            if !trial.note.isEmpty {
                Text(trial.note).font(.footnote).foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 測試流程

private struct RepRecording {
    var frames: [RepFrame]
    var dropped: Int
    var duration: Double { frames.last?.t ?? 0 }
}

struct RepTestSessionView: View {
    @ObservedObject var store: RepTestStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = RepCaptureEngine()

    private enum Phase { case setup, countdown, recording, answer }

    @State private var phase: Phase = .setup
    @State private var exerciseId = RepTestExercise.all[0].id
    @State private var angle: RepAngle = RepTestExercise.all[0].defaultAngle
    @State private var useFront = true
    @State private var showCamera = false
    @State private var count = 5
    @State private var recordStart = Date()
    @State private var elapsed: Double = 0
    @State private var recording: RepRecording?
    @State private var countdownTask: Task<Void, Never>?

    @State private var reps = 10
    @State private var partial = 0
    @State private var weightText = ""
    @State private var note = ""
    @State private var saveError: String?

    private var exercise: RepTestExercise { RepTestExercise.find(exerciseId) }
    private var missing: [RepJoint] { exercise.missingJoints(in: engine.joints) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if engine.authorization == .denied || engine.authorization == .restricted {
                deniedView
            } else if phase == .answer {
                answerForm
            } else {
                stage
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { engine.start(front: useFront) }
        .onDisappear {
            countdownTask?.cancel()
            engine.stopSession()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: useFront) { _, v in engine.setCamera(front: v) }
        .onChange(of: exerciseId) { _, _ in angle = exercise.defaultAngle }
        .onChange(of: phase) { _, p in
            UIApplication.shared.isIdleTimerDisabled = (p == .countdown || p == .recording)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            if phase == .recording { elapsed = Date().timeIntervalSince(recordStart) }
        }
        .onAppear { engine.onAutoStop = { stopRecording() } }
    }

    // MARK: 相機舞台

    private var stage: some View {
        ZStack {
            VStack(spacing: 8) {
                banner
                cameraArea
                if phase == .setup { controls }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, phase == .setup ? 8 : 24)

            if phase != .setup {
                // 整個畫面都可以點來停止（倒數中點＝取消）
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tapStage() }
            }
        }
    }

    private var banner: some View {
        let ok = missing.isEmpty
        return HStack(spacing: 8) {
            if phase == .setup {
                Button("取消") { dismiss() }
                    .foregroundStyle(Theme.muted)
                    .frame(minHeight: 44)
            }
            Spacer(minLength: 0)
            Group {
                if phase == .recording {
                    Text("記錄中　點畫面停止")
                } else if phase == .countdown {
                    Text("準備中　點畫面取消")
                } else if let err = engine.cameraError {
                    Text(err)
                } else if ok {
                    Text("已入鏡")
                } else {
                    Text("缺：" + missing.map(\.zh).joined(separator: "、"))
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background((phase == .setup || phase == .countdown) ? (ok ? Theme.green.opacity(0.85) : Color.red.opacity(0.85))
                        : Theme.hot.opacity(0.9),
                        in: Capsule())
            Spacer(minLength: 0)
            if phase == .setup { Color.clear.frame(width: 44, height: 44) }
        }
    }

    private var cameraArea: some View {
        ZStack {
            Color(white: 0.04)
            if showCamera {
                RepCameraPreview(session: engine.session)
            }
            RepSkeletonView(joints: engine.joints, mirror: useFront,
                            required: exercise.allRequiredJoints)
            overlayText
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var overlayText: some View {
        if phase == .countdown {
            Text("\(count)")
                .font(Theme.number(160))
                .foregroundStyle(.white)
                .shadow(radius: 8)
        } else if phase == .recording {
            VStack {
                Text(String(format: "%.1f", elapsed))
                    .font(Theme.number(72))
                    .foregroundStyle(.white)
                    .shadow(radius: 8)
                Text("上限 \(Int(RepCaptureEngine.maxDuration)) 秒")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("動作").foregroundStyle(Theme.muted)
                Spacer()
                Picker("動作", selection: $exerciseId) {
                    ForEach(RepTestExercise.all) { ex in
                        Text(ex.name).tag(ex.id)
                    }
                }
                .pickerStyle(.menu)
            }
            Text(exercise.placement)
                .font(.footnote)
                .foregroundStyle(Theme.accentSoft)
            Picker("拍攝方向", selection: $angle) {
                ForEach(RepAngle.allCases, id: \.self) { a in Text(a.title).tag(a) }
            }
            .pickerStyle(.segmented)
            Picker("鏡頭", selection: $useFront) {
                Text("前鏡頭").tag(true)
                Text("後鏡頭").tag(false)
            }
            .pickerStyle(.segmented)
            Toggle("疊上相機畫面（只顯示，不存）", isOn: $showCamera)
                .font(.subheadline)
            Button {
                startCountdown()
            } label: {
                Text("開始")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.hot)
            .foregroundStyle(Theme.onHot)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 權限被拒

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash").font(.system(size: 48)).foregroundStyle(Theme.muted)
            Text("沒有相機權限").font(.title3.weight(.bold)).foregroundStyle(Theme.fg)
            Text("數次數測試需要用相機即時辨識關節位置，影像不會存下來，也不會上傳。請到系統設定打開相機權限。")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Button("打開設定") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            Button("返回") { dismiss() }.foregroundStyle(Theme.muted)
        }
        .padding(24)
    }

    // MARK: 流程

    private func startCountdown() {
        countdownTask?.cancel()
        phase = .countdown
        countdownTask = Task { @MainActor in
            let light = UIImpactFeedbackGenerator(style: .light)
            let heavy = UIImpactFeedbackGenerator(style: .heavy)
            for n in stride(from: 5, through: 1, by: -1) {
                count = n
                light.impactOccurred()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            heavy.impactOccurred()
            engine.startRecording()
            recordStart = Date()
            elapsed = 0
            phase = .recording
        }
    }

    private func tapStage() {
        switch phase {
        case .countdown:
            countdownTask?.cancel()
            phase = .setup
        case .recording:
            stopRecording()
        default:
            break
        }
    }

    private func stopRecording() {
        guard phase == .recording else { return }
        phase = .answer
        engine.stopRecording { frames, dropped in
            recording = RepRecording(frames: frames, dropped: dropped)
            engine.stopSession()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    // MARK: 填答案

    private var answerForm: some View {
        let rec = recording
        let duration = rec?.duration ?? 0
        let frameCount = rec?.frames.count ?? 0
        let fps = duration > 0 ? Double(frameCount) / duration : 0
        return Form {
            Section {
                LabeledContent("動作", value: exercise.name)
                LabeledContent("長度", value: String(format: "%.1f 秒", duration))
                LabeledContent("格數", value: "\(frameCount)（丟掉 \(rec?.dropped ?? 0)）")
                LabeledContent("平均", value: String(format: "%.1f fps", fps))
            }
            .listRowBackground(Theme.surface)

            Section {
                Stepper("實際完整次數：\(reps)", value: $reps, in: 0...200)
                    .frame(minHeight: 44)
                Stepper("半程次數：\(partial)", value: $partial, in: 0...200)
                    .frame(minHeight: 44)
                TextField("重量 kg（選填）", text: $weightText)
                    .keyboardType(.decimalPad)
                    .frame(minHeight: 44)
                TextField("備註（選填，例如「含拿放」）", text: $note)
                    .frame(minHeight: 44)
            } header: {
                SectionLabel("實際做了幾下？")
            }
            .listRowBackground(Theme.surface)

            Section {
                Button {
                    save()
                } label: {
                    Text("存").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
                }
                .tint(Theme.hot)
                Button(role: .destructive) {
                    dismiss()
                } label: {
                    Text("不存").frame(maxWidth: .infinity, minHeight: 44)
                }
                if let saveError {
                    Text(saveError).font(.footnote).foregroundStyle(.red)
                }
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
    }

    private func save() {
        guard let rec = recording else { dismiss(); return }
        let duration = rec.duration
        let weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        let trial = RepTrial(
            id: UUID().uuidString,
            date: Date(),
            exerciseId: exerciseId,
            view: angle.rawValue,
            camera: useFront ? "front" : "back",
            actualReps: reps,
            partialReps: partial,
            weightKg: weight,
            note: note,
            durationS: duration,
            frames: rec.frames.count,
            droppedFrames: rec.dropped,
            avgFps: duration > 0 ? Double(rec.frames.count) / duration : 0,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
        do {
            try store.add(trial, frames: rec.frames)
            dismiss()
        } catch {
            saveError = "存檔失敗：\(error.localizedDescription)"
        }
    }
}

// MARK: - 相機預覽與火柴人

/// 只顯示、不存。前鏡頭預覽預設是鏡像（像照鏡子），火柴人畫的時候也跟著翻，所以兩者對得上。
struct RepCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

struct RepSkeletonView: View {
    let joints: [RepJointSample?]
    let mirror: Bool
    let required: Set<RepJoint>

    private static let bones: [(RepJoint, RepJoint)] = [
        (.nose, .neck), (.leftEye, .nose), (.rightEye, .nose), (.leftEar, .leftEye), (.rightEar, .rightEye),
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        Canvas { ctx, size in
            func point(_ j: RepJoint) -> CGPoint? {
                guard j.rawValue < joints.count, let s = joints[j.rawValue] else { return nil }
                let x = mirror ? 1 - CGFloat(s.x) : CGFloat(s.x)
                return CGPoint(x: x * size.width, y: (1 - CGFloat(s.y)) * size.height)
            }
            func ok(_ j: RepJoint) -> Bool {
                guard j.rawValue < joints.count, let s = joints[j.rawValue] else { return false }
                return s.c >= RepTestExercise.minConfidence
            }
            for (a, b) in Self.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                let strong = ok(a) && ok(b)
                ctx.stroke(path, with: .color(Theme.accent.opacity(strong ? 1 : 0.3)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            for j in RepJoint.allCases {
                guard let p = point(j) else { continue }
                let color: Color
                if required.contains(j) {
                    color = ok(j) ? Theme.green : .red
                } else {
                    color = Theme.accentSoft.opacity(ok(j) ? 1 : 0.3)
                }
                let r: CGFloat = required.contains(j) ? 6 : 4
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(color))
            }
        }
    }
}
