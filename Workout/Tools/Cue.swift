import AVFoundation
import UIKit
import UserNotifications

/// 計時工具（間歇、等長、節拍器）的提示音＋震動。
/// 聲音用 .playback + .mixWithOthers：靜音開關打開也聽得到，而且不會把音樂停掉。
@MainActor
enum Cue {
    enum Tone: CaseIterable {
        /// 很輕的滴答（節拍器每秒、倒數前的小提醒）
        case tick
        /// 倒數 3、2、1
        case count
        /// 開始做（高音、長一點）
        case go
        /// 休息／放下（低音）
        case rest
        /// 全部結束（三個音往上）
        case done
    }

    private static var players: [Tone: AVAudioPlayer] = [:]
    private static var sessionReady = false

    static func play(_ tone: Tone, haptic: Bool = true) {
        prepareSession()
        if let p = player(tone) {
            p.currentTime = 0
            p.play()
        }
        if haptic { buzz(tone) }
    }

    private static func buzz(_ tone: Tone) {
        switch tone {
        case .tick: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .count: UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .go: UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
        case .rest: UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .done: UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private static func prepareSession() {
        guard !sessionReady else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        sessionReady = true
    }

    private static func player(_ tone: Tone) -> AVAudioPlayer? {
        if let p = players[tone] { return p }
        let notes: [(Double, Double)]
        var volume: Double = 0.5
        switch tone {
        case .tick: notes = [(1600, 0.035)]; volume = 0.25
        case .count: notes = [(1175, 0.11)]
        case .go: notes = [(1568, 0.38)]; volume = 0.6
        case .rest: notes = [(587, 0.28)]
        case .done: notes = [(1047, 0.14), (1319, 0.14), (1568, 0.4)]; volume = 0.6
        }
        guard let p = try? AVAudioPlayer(data: wav(notes, volume: volume)) else { return nil }
        p.prepareToPlay()
        players[tone] = p
        return p
    }

    /// 產生 16-bit 單聲道 WAV：每個音是正弦波，頭尾淡入淡出避免爆音。
    private static func wav(_ notes: [(Double, Double)], volume: Double) -> Data {
        let rate = 44_100.0
        var samples: [Int16] = []
        for (freq, seconds) in notes {
            let count = Int(seconds * rate)
            let fade = min(Int(0.006 * rate), count / 2)
            for i in 0..<count {
                var env = 1.0
                if i < fade { env = Double(i) / Double(fade) }
                if i > count - fade { env = Double(count - i) / Double(fade) }
                // 後半段慢慢變小，聽起來像「嗶」而不是「嗡」
                env *= 1 - 0.5 * Double(i) / Double(count)
                let v = sin(2 * .pi * freq * Double(i) / rate) * env * volume
                samples.append(Int16(max(-1, min(1, v)) * Double(Int16.max)))
            }
        }
        var d = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let bytes = samples.count * 2
        d.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + bytes))
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
        put(UInt32(rate)); put(UInt32(rate * 2)); put(UInt16(2)); put(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); put(UInt32(bytes))
        for s in samples { put(s) }
        return d
    }
}

/// 計時工具切到背景時的本機通知（App 在前景時系統不顯示，所以不會重複響）。
enum ToolAlerts {
    static func schedule(id: String, at date: Date, title: String, body: String = "") {
        let wait = date.timeIntervalSinceNow
        guard wait > 0.5 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(prefix: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
