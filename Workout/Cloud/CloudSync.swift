import SwiftUI
import SwiftData
import CryptoKit
import LocalAuthentication

extension Keys {
    /// 加密雲端備份開著（預設關）
    static let cloudEnabled = "cloudEnabled"
    /// 上次成功同步的時間（秒）、上次失敗的原因、上次上傳的內容雜湊：只是這支手機的狀態，不放進備份
    static let cloudLastSync = "cloudLastSync"
    static let cloudLastError = "cloudLastError"
    static let cloudLastHash = "cloudLastHash"
}

/// 端對端加密雲端備份（0.43.0）。
/// 內容 = `FullBackup` 的 JSON → zlib 壓縮 → AES-256-GCM 加密 → PUT 到 Cloudflare Worker。
/// 練完按「完成」之後、App 切到背景時各排一次，2 秒內的合併成一次；失敗就默默等下次。
/// 只有一個使用者：最後上傳的為準，伺服器多留最近 5 個版本。
@MainActor
final class CloudSync: ObservableObject {
    static let shared = CloudSync()

    enum Status: Equatable {
        case idle, syncing
    }

    @Published private(set) var status: Status = .idle
    /// 設定頁顯示用：改了就刷新
    @Published private(set) var lastSync: Date?
    @Published private(set) var lastError: String?

    /// RootView 啟動時給（匯出紀錄要用 SwiftData 的 context）
    var context: ModelContext?

    private var pending: Task<Void, Never>?
    private var uploading = false
    private var again = false
    private var background: UIBackgroundTaskIdentifier = .invalid

    private init() {
        loadStatus()
    }

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: Keys.cloudEnabled)
    }

    nonisolated static func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Keys.cloudEnabled)
    }

    private func loadStatus() {
        let d = UserDefaults.standard
        let t = d.double(forKey: Keys.cloudLastSync)
        lastSync = t > 0 ? Date(timeIntervalSince1970: t) : nil
        let e = d.string(forKey: Keys.cloudLastError) ?? ""
        lastError = e.isEmpty ? nil : e
    }

    /// 「上次同步：…」一行字
    var statusText: String {
        if status == .syncing { return "同步中…" }
        if let lastError { return "失敗：\(lastError)" }
        if let lastSync { return "上次同步：" + lastSync.formatted(date: .abbreviated, time: .shortened) }
        return "還沒同步過"
    }

    // MARK: 上傳

    /// 排一次上傳：2 秒內再呼叫會合併成一次。沒開、沒設定網址、沒有金鑰就什麼都不做。
    func scheduleUpload() {
        guard Self.isEnabled, CloudConfig.isConfigured, CloudKeychain.load() != nil else { return }
        if uploading { again = true; return }
        pending?.cancel()
        if background == .invalid {
            // 剛切到背景時系統只給幾秒，借一個背景工作讓它做完
            background = UIApplication.shared.beginBackgroundTask(withName: "cloud-sync") { [weak self] in
                self?.endBackground()
            }
        }
        pending = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.upload(force: false)
        }
    }

    private func endBackground() {
        guard background != .invalid else { return }
        UIApplication.shared.endBackgroundTask(background)
        background = .invalid
    }

    /// 設定頁「立即同步」：不管有沒有變更都傳。
    func uploadNow() {
        pending?.cancel()
        Task { await upload(force: true) }
    }

    private func upload(force: Bool) async {
        guard Self.isEnabled, let base = CloudConfig.workerURL, let secrets = CloudKeychain.load(),
              let context else { endBackground(); return }
        // 已經有一次在傳：等它傳完再補一次（它結束時會處理背景工作）
        if uploading { again = true; return }
        uploading = true
        status = .syncing
        defer {
            uploading = false
            status = .idle
            endBackground()
            if again { again = false; scheduleUpload() }
        }
        do {
            let file = try FullBackup.make(context: context)
            let hash = Self.contentHash(file)
            if !force, hash == UserDefaults.standard.string(forKey: Keys.cloudLastHash) {
                // 和上次傳的一樣：不用再傳，但還是算同步成功（確認過了）
                record(success: true, error: nil, hash: nil)
                return
            }
            let blob = try CloudCrypto.seal(FullBackup.encode(file), key: secrets.symmetricKey)
            guard blob.count <= CloudConfig.maxBlobBytes else { throw CloudError.tooLarge }
            try await CloudClient(base: base, secrets: secrets).put(blob)
            record(success: true, error: nil, hash: hash)
        } catch is CancellationError {
            // 被新的一次取代，不算失敗
        } catch {
            record(success: false, error: error.localizedDescription, hash: nil)
        }
    }

    private func record(success: Bool, error: String?, hash: String?) {
        let d = UserDefaults.standard
        if success {
            d.set(Date.now.timeIntervalSince1970, forKey: Keys.cloudLastSync)
            d.removeObject(forKey: Keys.cloudLastError)
            if let hash { d.set(hash, forKey: Keys.cloudLastHash) }
        } else {
            d.set(error ?? "不明原因", forKey: Keys.cloudLastError)
        }
        loadStatus()
    }

    /// 內容有沒有變：匯出時間不算；設定轉成排序過的文字再算（binary plist 的順序每次可能不一樣）。
    nonisolated static func contentHash(_ file: FullBackup.File) -> String {
        var probe = file
        probe.exportedAt = Date(timeIntervalSince1970: 0)
        probe.defaults = Data()
        var bytes = (try? FullBackup.encode(probe)) ?? Data()
        let prefs = (try? PropertyListSerialization.propertyList(from: file.defaults, format: nil)) as? [String: Any] ?? [:]
        let text = prefs.keys.sorted().map { "\($0)=\(String(describing: prefs[$0]))" }.joined(separator: "\n")
        bytes.append(Data(text.utf8))
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: 開關

    /// 開啟：金鑰存進 Keychain、打開開關、排一次上傳。
    func enable(with secrets: CloudSecrets) -> Bool {
        guard CloudKeychain.save(secrets) else { return false }
        Self.setEnabled(true)
        UserDefaults.standard.removeObject(forKey: Keys.cloudLastHash)
        scheduleUpload()
        return true
    }

    func disable() {
        pending?.cancel()
        Self.setEnabled(false)
    }

    /// 換手機還原後：用恢復碼的金鑰繼續同步（FullBackup.restore 會把設定整組換掉，所以要在還原之後才呼叫）。
    func resume(with secrets: CloudSecrets) {
        CloudKeychain.save(secrets)
        Self.setEnabled(true)
        loadStatus()
    }

    // MARK: 下載

    static func versions(secrets: CloudSecrets) async throws -> [CloudVersionInfo] {
        guard let base = CloudConfig.workerURL else { throw CloudError.notConfigured }
        return try await CloudClient(base: base, secrets: secrets).versions()
    }

    /// 下載指定版本（nil = 最新）→ 解密 → 解成備份內容。還沒動任何本機資料。
    static func download(secrets: CloudSecrets, version: Int?) async throws -> FullBackup.File {
        guard let base = CloudConfig.workerURL else { throw CloudError.notConfigured }
        let blob = try await CloudClient(base: base, secrets: secrets).get(version: version)
        let plain = try CloudCrypto.open(blob, key: secrets.symmetricKey)
        return try FullBackup.decode(plain)
    }
}

/// 看恢復碼之前先驗證本人（Face ID／密碼）。
enum CloudAuth {
    /// 這支手機沒設密碼時，沒有東西可驗證，直接放行（沒設密碼的手機本來就沒有保護）。
    static func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else { return true }
        return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
