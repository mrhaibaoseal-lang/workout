import Foundation
import CryptoKit
import Security

/// 雲端備份的金鑰：256-bit 加密金鑰 + 256-bit 存取 token。
/// 金鑰只在手機上（Keychain）和使用者抄下來的恢復碼裡；伺服器只看得到 token 的雜湊，看不到金鑰、也看不到明文。
struct CloudSecrets: Equatable {
    var key: Data
    var token: Data

    static let size = 32

    static func generate() -> CloudSecrets {
        CloudSecrets(key: randomBytes(size), token: randomBytes(size))
    }

    private static func randomBytes(_ n: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: n)
        let status = SecRandomCopyBytes(kSecRandomDefault, n, &bytes)
        precondition(status == errSecSuccess, "系統亂數失敗")
        return Data(bytes)
    }

    var symmetricKey: SymmetricKey { SymmetricKey(data: key) }

    /// 送給 Worker 的 Bearer token（base64url，43 字元）
    var bearer: String {
        token.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// 壓縮（zlib）→ AES-256-GCM 加密。
/// 檔案格式：1 byte 格式版本 + AES.GCM combined（12 bytes nonce + 密文 + 16 bytes tag）。
/// 版本號也放進 AES.GCM 的附加驗證資料，改了就解不開。
enum CloudCrypto {
    static let formatVersion: UInt8 = 1

    enum CryptoError: LocalizedError {
        case compress, decompress, badData, wrongKey, newerFormat

        var errorDescription: String? {
            switch self {
            case .compress: "壓縮失敗"
            case .decompress: "解壓縮失敗，資料可能壞掉了"
            case .badData: "雲端的資料格式不對"
            case .wrongKey: "解不開：恢復碼不對，或這份資料不是用這組金鑰加密的"
            case .newerFormat: "這份備份是新版 App 存的，請先更新 App"
            }
        }
    }

    static func seal(_ plain: Data, key: SymmetricKey) throws -> Data {
        guard let packed = try? (plain as NSData).compressed(using: .zlib) as Data else { throw CryptoError.compress }
        let box = try AES.GCM.seal(packed, using: key, authenticating: Data([formatVersion]))
        guard let combined = box.combined else { throw CryptoError.badData }
        return Data([formatVersion]) + combined
    }

    static func open(_ blob: Data, key: SymmetricKey) throws -> Data {
        // 1 byte 版本 + 12 nonce + 16 tag = 至少 29 bytes
        guard blob.count > 29, let version = blob.first else { throw CryptoError.badData }
        guard version <= formatVersion else { throw CryptoError.newerFormat }
        let packed: Data
        do {
            let box = try AES.GCM.SealedBox(combined: Data(blob.dropFirst()))
            packed = try AES.GCM.open(box, using: key, authenticating: Data([version]))
        } catch {
            throw CryptoError.wrongKey
        }
        guard let plain = try? (packed as NSData).decompressed(using: .zlib) as Data else { throw CryptoError.decompress }
        return plain
    }
}

/// 恢復碼：把金鑰和 token 編成好抄的文字（Crockford Base32，沒有 I、L、O、U，每 6 個字一組）。
/// 內容 = 版本 1 byte + 金鑰 32 + token 32 + 檢查碼 2（SHA-256 前 2 bytes，抄錯會被發現）= 67 bytes → 108 個字。
enum RecoveryCode {
    private static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    static let version: UInt8 = 1
    static let groupSize = 6

    static func encode(_ s: CloudSecrets) -> String {
        var payload = Data([version]) + s.key + s.token
        payload += Data(SHA256.hash(data: payload).prefix(2))
        var out: [Character] = []
        var buffer = 0, bits = 0
        for byte in payload {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                out.append(alphabet[(buffer >> (bits - 5)) & 31])
                bits -= 5
            }
            buffer &= (1 << bits) - 1
        }
        if bits > 0 { out.append(alphabet[(buffer << (5 - bits)) & 31]) }
        return stride(from: 0, to: out.count, by: groupSize).map {
            String(out[$0..<min($0 + groupSize, out.count)])
        }.joined(separator: "-")
    }

    /// 一組一組的字（畫面上分行顯示用）
    static func groups(_ s: CloudSecrets) -> [String] {
        encode(s).split(separator: "-").map(String.init)
    }

    /// 輸入的文字 → 去掉空白、橫線，小寫轉大寫，O → 0、I／L → 1。不是合法的字回傳 nil。
    static func normalize(_ text: String) -> String? {
        var out = ""
        for ch in text.uppercased() {
            if ch == " " || ch == "-" || ch == "\n" || ch == "\t" || ch == "\r" { continue }
            let c: Character = ch == "O" ? "0" : (ch == "I" || ch == "L" ? "1" : ch)
            guard alphabet.contains(c) else { return nil }
            out.append(c)
        }
        return out
    }

    static func decode(_ text: String) -> CloudSecrets? {
        guard let clean = normalize(text) else { return nil }
        var bytes: [UInt8] = []
        var buffer = 0, bits = 0
        for ch in clean {
            guard let v = alphabet.firstIndex(of: ch) else { return nil }
            buffer = (buffer << 5) | v
            bits += 5
            if bits >= 8 {
                bytes.append(UInt8((buffer >> (bits - 8)) & 255))
                bits -= 8
                buffer &= (1 << bits) - 1
            }
        }
        let n = 1 + CloudSecrets.size * 2 + 2
        guard bytes.count >= n else { return nil }
        let payload = Data(bytes[0..<n])
        let body = payload.prefix(n - 2)
        guard payload[0] == version,
              Data(SHA256.hash(data: body).prefix(2)) == payload.suffix(2) else { return nil }
        return CloudSecrets(key: Data(body[1...CloudSecrets.size]),
                            token: Data(body[(1 + CloudSecrets.size)...]))
    }
}
