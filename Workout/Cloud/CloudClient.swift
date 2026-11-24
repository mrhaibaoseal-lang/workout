import Foundation
import Security

/// Worker 網址（部署後填在這裡，例如 "https://workout-sync.你的帳號.workers.dev"）。
/// 空字串 = 雲端功能整個隱藏（問卷最後一頁、設定 → 資料都不會出現）。
enum CloudConfig {
    static let workerURLString = ""

    /// 單筆備份上限（和 Worker 一致）
    static let maxBlobBytes = 5 * 1024 * 1024

    static var workerURL: URL? { url(from: workerURLString) }

    static var isConfigured: Bool { workerURL != nil }

    /// 只收 https（測試用的 localhost 例外）
    static func url(from string: String) -> URL? {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let url = URL(string: t), let scheme = url.scheme?.lowercased(), url.host != nil else { return nil }
        if scheme == "https" || (scheme == "http" && url.host == "localhost") { return url }
        return nil
    }
}

/// 金鑰和 token 存在 Keychain（只在這支手機、第一次解鎖後可讀）。
/// 不放 UserDefaults，所以不會進任何備份檔、log；換手機靠恢復碼。
enum CloudKeychain {
    private static let service = "com.mrhaibaoseal.workout.cloud"
    private static let account = "secrets"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> CloudSecrets? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, data.count == CloudSecrets.size * 2 else { return nil }
        return CloudSecrets(key: Data(data.prefix(CloudSecrets.size)), token: Data(data.suffix(CloudSecrets.size)))
    }

    @discardableResult
    static func save(_ s: CloudSecrets) -> Bool {
        let data = s.key + s.token
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        return SecItemAdd(baseQuery.merging(attrs) { $1 } as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

struct CloudVersionInfo: Decodable, Equatable, Identifiable {
    var version: Int
    /// 伺服器收到的時間（毫秒）
    var createdAt: Double
    var size: Int

    var id: Int { version }
    var date: Date { Date(timeIntervalSince1970: createdAt / 1000) }
}

enum CloudError: LocalizedError {
    case notConfigured, noKeys, unauthorized, notFound, tooLarge, rateLimited
    case server(Int), network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "還沒設定雲端網址"
        case .noKeys: "這支手機上沒有雲端金鑰"
        case .unauthorized: "雲端不認得這組金鑰"
        case .notFound: "雲端找不到這組恢復碼的備份（碼打錯了，或還沒備份過）"
        case .tooLarge: "備份超過 5 MB，雲端收不下"
        case .rateLimited: "傳太頻繁，稍後再試"
        case .server(let code): "雲端出錯（\(code)）"
        case .network(let text): "連不上雲端：\(text)"
        }
    }
}

/// 對 Worker 的三個請求。Authorization: Bearer <token>；內容是加密後的位元組，這裡不碰明文。
struct CloudClient {
    let base: URL
    let bearer: String

    init(base: URL, secrets: CloudSecrets) {
        self.base = base
        self.bearer = secrets.bearer
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private func request(_ path: String, method: String, query: [URLQueryItem] = [], body: Data? = nil) -> URLRequest {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) ?? URLComponents()
        if !query.isEmpty { comps.queryItems = query }
        var req = URLRequest(url: comps.url ?? base)
        req.httpMethod = method
        req.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = body
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func send(_ req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, resp) = try await Self.session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw CloudError.server(0) }
            switch http.statusCode {
            case 200..<300: return (data, http)
            case 401, 403: throw CloudError.unauthorized
            case 404: throw CloudError.notFound
            case 413: throw CloudError.tooLarge
            case 429: throw CloudError.rateLimited
            default: throw CloudError.server(http.statusCode)
            }
        } catch let e as CloudError {
            throw e
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw CloudError.network((error as NSError).localizedDescription)
        }
    }

    @discardableResult
    func put(_ blob: Data) async throws -> CloudVersionInfo {
        let (data, _) = try await send(request("v1/blob", method: "PUT", body: blob))
        return try JSONDecoder().decode(CloudVersionInfo.self, from: data)
    }

    func get(version: Int? = nil) async throws -> Data {
        let query = version.map { [URLQueryItem(name: "version", value: String($0))] } ?? []
        return try await send(request("v1/blob", method: "GET", query: query)).0
    }

    func versions() async throws -> [CloudVersionInfo] {
        struct Reply: Decodable { var versions: [CloudVersionInfo] }
        let (data, _) = try await send(request("v1/blob/versions", method: "GET"))
        return try JSONDecoder().decode(Reply.self, from: data).versions
    }
}
