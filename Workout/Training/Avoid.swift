import SwiftUI

extension Keys {
    /// 不排的動作（會痛、不喜歡），JSON [exerciseId: AvoidEntry]
    static let avoidExercises = "avoidExercises"
    /// 「這個動作會痛」的紀錄，JSON [PainRecord]（先只存，之後的功能會用）
    static let painLog = "painLog"
    /// 換動作的位移，JSON ["dayId|pattern": Int]：排課選動作時，順位往後加這個數字
    static let patternShift = "patternShift"
    /// 0.23.0 升級遷移做過了（複合動作不再輪替，要先把使用者正在練的動作固定住）
    static let pinnedV023 = "pinnedV023"
}

/// 一個「key 是字串、值是 Codable」的小字典，存在 UserDefaults 的 JSON 字串裡。
/// 排課會頻繁讀取，字串沒變就用快取，不用每次解 JSON。
final class KeyedStore<Value: Codable> {
    let key: String
    private var cacheRaw: String?
    private var cache: [String: Value] = [:]

    init(key: String) { self.key = key }

    func load() -> [String: Value] {
        let raw = UserDefaults.standard.string(forKey: key) ?? ""
        if raw == cacheRaw { return cache }
        cacheRaw = raw
        cache = (try? JSONDecoder().decode([String: Value].self, from: Data(raw.utf8))) ?? [:]
        return cache
    }

    func save(_ dict: [String: Value]) {
        guard let data = try? JSONEncoder().encode(dict), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: key)
    }

    subscript(id: String) -> Value? {
        get { load()[id] }
        set {
            var d = load()
            d[id] = newValue
            save(d)
        }
    }
}

enum AvoidReason: String, Codable {
    case pain, dislike

    var title: String {
        switch self {
        case .pain: "會痛"
        case .dislike: "不喜歡"
        }
    }
}

struct AvoidEntry: Codable, Equatable {
    var reason: String
    /// 標記的時間（秒）
    var date: Double

    var kind: AvoidReason { AvoidReason(rawValue: reason) ?? .dislike }
}

struct AvoidItem: Identifiable {
    let id: String
    let entry: AvoidEntry
}

struct PainRecord: Codable, Equatable {
    var exerciseId: String
    var date: Double
}

enum Avoid {
    static let store = KeyedStore<AvoidEntry>(key: Keys.avoidExercises)

    static func isAvoided(_ id: String) -> Bool {
        store.load()[id] != nil
    }

    static func mark(_ id: String, reason: AvoidReason) {
        store[id] = AvoidEntry(reason: reason.rawValue, date: Date.now.timeIntervalSince1970)
    }

    static func unmark(_ id: String) {
        store[id] = nil
    }

    /// 全部不排的動作，最近標記的在前。
    static func entries() -> [AvoidItem] {
        store.load().map { AvoidItem(id: $0.key, entry: $0.value) }.sorted { $0.entry.date > $1.entry.date }
    }

    // MARK: 痛的紀錄

    static func painLog() -> [PainRecord] {
        guard let raw = UserDefaults.standard.string(forKey: Keys.painLog),
              let list = try? JSONDecoder().decode([PainRecord].self, from: Data(raw.utf8)) else { return [] }
        return list
    }

    static func logPain(_ exerciseId: String) {
        var list = painLog()
        list.append(PainRecord(exerciseId: exerciseId, date: Date.now.timeIntervalSince1970))
        guard let data = try? JSONEncoder().encode(list), let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: Keys.painLog)
    }
}

/// 設定 → 不排的動作：看標記了哪些，可以取消。
struct AvoidListView: View {
    @AppStorage(Keys.avoidExercises) private var raw = ""

    private var items: [AvoidItem] {
        _ = raw
        return Avoid.entries()
    }

    var body: some View {
        Form {
            Section {
                if items.isEmpty {
                    Text("還沒有標記任何動作").foregroundStyle(Theme.muted)
                }
                ForEach(items) { item in
                    row(item.id, item.entry)
                }
            } header: {
                SectionLabel("不排的動作")
            } footer: {
                SectionLabel("在訓練畫面動作卡右上角的選單，選「會痛」或「不喜歡」並換掉，就會記在這裡，之後自動排課不會再排它，會改排同類型的其他動作。取消標記後，下次排課又會考慮它。")
            }
            .listRowBackground(Theme.surface)
        }
        .themeForm()
        .navigationTitle("不排的動作")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ id: String, _ entry: AvoidEntry) -> some View {
        let name = ExerciseLibrary.byId(id)?.name ?? id
        let date = Date(timeIntervalSince1970: entry.date).formatted(.dateTime.year().month(.defaultDigits).day())
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text("\(entry.kind.title) · \(date)").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("取消標記") { Avoid.unmark(id) }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderless)
        }
    }
}
