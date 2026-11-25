import AVFoundation
import CoreMotion
import Vision

/// 相機擷取 + Vision 2D 人體姿勢辨識 + 手機重力向量。
/// 影像處理完就丟掉，不寫檔、不快取。座標是直式畫面、Vision 正規化座標（原點在左下），
/// 前鏡頭不做左右鏡像（存原始結果）。
final class RepCaptureEngine: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    /// 單組上限（秒）
    static let maxDuration: Double = 180

    let session = AVCaptureSession()

    @Published private(set) var joints: [RepJointSample?] = Array(repeating: nil, count: RepJoint.allCases.count)
    @Published private(set) var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var cameraError: String?

    /// 記錄到上限、自動停止時通知（主執行緒）
    var onAutoStop: (() -> Void)?

    private let sessionQueue = DispatchQueue(label: "reptest.session")
    private let videoQueue = DispatchQueue(label: "reptest.video")
    private let motionQueue = OperationQueue()
    private let output = AVCaptureVideoDataOutput()
    private let motion = CMMotionManager()

    private let gravityLock = NSLock()
    private var gravity: (x: Double, y: Double, z: Double)?

    private var position: AVCaptureDevice.Position = .front

    // 只在 videoQueue 上讀寫
    private var recording = false
    private var startPTS: CMTime?
    private var frames: [RepFrame] = []
    private var dropped = 0

    // MARK: 啟動與停止

    func start(front: Bool) {
        position = front ? .front : .back
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        authorization = status
        switch status {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async {
                    self.authorization = ok ? .authorized : .denied
                    if ok { self.run() }
                }
            }
        default:
            break
        }
    }

    func setCamera(front: Bool) {
        position = front ? .front : .back
        guard authorization == .authorized else { return }
        sessionQueue.async { self.configure() }
    }

    func stopSession() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
        motion.stopDeviceMotionUpdates()
    }

    private func run() {
        startMotion()
        sessionQueue.async {
            self.configure()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] m, _ in
            guard let self, let g = m?.gravity else { return }
            self.gravityLock.lock()
            self.gravity = (g.x, g.y, g.z)
            self.gravityLock.unlock()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720
        for input in session.inputs { session.removeInput(input) }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            DispatchQueue.main.async { self.cameraError = "找不到可用的相機" }
            return
        }
        session.addInput(input)

        if !session.outputs.contains(output) {
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoQueue)
            if session.canAddOutput(output) { session.addOutput(output) }
        }
        session.commitConfiguration()

        // 直式、不鏡像；Vision 以 .up 處理
        if let conn = output.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = false
        }

        // 30 fps
        if (try? device.lockForConfiguration()) != nil {
            let d = CMTime(value: 1, timescale: 30)
            device.activeVideoMinFrameDuration = d
            device.activeVideoMaxFrameDuration = d
            device.unlockForConfiguration()
        }
        DispatchQueue.main.async { self.cameraError = nil }
    }

    // MARK: 記錄

    func startRecording() {
        videoQueue.async {
            self.frames = []
            self.dropped = 0
            self.startPTS = nil
            self.recording = true
        }
    }

    /// 停止記錄並取回資料（主執行緒回呼）
    func stopRecording(_ completion: @escaping (_ frames: [RepFrame], _ dropped: Int) -> Void) {
        videoQueue.async {
            self.recording = false
            let f = self.frames
            let d = self.dropped
            self.frames = []
            DispatchQueue.main.async { completion(f, d) }
        }
    }

    // MARK: 取樣回呼（videoQueue）

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let samples = detect(in: pixels)

        if recording {
            if startPTS == nil { startPTS = pts }
            let t = CMTimeGetSeconds(CMTimeSubtract(pts, startPTS ?? pts))
            gravityLock.lock()
            let g = gravity
            gravityLock.unlock()
            frames.append(RepFrame(t: t, gx: g?.x, gy: g?.y, gz: g?.z, joints: samples))
            if t >= Self.maxDuration {
                recording = false
                DispatchQueue.main.async { self.onAutoStop?() }
            }
        }
        DispatchQueue.main.async { self.joints = samples }
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if recording { dropped += 1 }
    }

    private func detect(in pixels: CVPixelBuffer) -> [RepJointSample?] {
        var result = [RepJointSample?](repeating: nil, count: RepJoint.allCases.count)
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil, let observations = request.results else { return result }

        // 畫面裡有多個人時，取信心總和最高的一個
        var best: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]?
        var bestScore: Float = 0
        for obs in observations {
            guard let pts = try? obs.recognizedPoints(.all) else { continue }
            let score = pts.values.reduce(Float(0)) { $0 + $1.confidence }
            if score > bestScore { bestScore = score; best = pts }
        }
        guard let best else { return result }
        for j in RepJoint.allCases {
            if let p = best[Self.visionName(j)], p.confidence > 0 {
                result[j.rawValue] = RepJointSample(x: Float(p.location.x), y: Float(p.location.y), c: p.confidence)
            }
        }
        return result
    }

    private static func visionName(_ j: RepJoint) -> VNHumanBodyPoseObservation.JointName {
        switch j {
        case .nose: return .nose
        case .leftEye: return .leftEye
        case .rightEye: return .rightEye
        case .leftEar: return .leftEar
        case .rightEar: return .rightEar
        case .neck: return .neck
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftWrist: return .leftWrist
        case .rightWrist: return .rightWrist
        case .root: return .root
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }
}
