import Foundation

/// 測試資料的存放：Application Support/RepTest/。
/// 不進 SwiftData、完整備份、雲端備份、SharedStore；影像一律不存。
final class RepTestStore: ObservableObject {
    @Published private(set) var trials: [RepTrial] = []
    let dir: URL

    private var indexURL: URL { dir.appendingPathComponent("trials.json") }

    init(dir: URL? = nil) {
        if let dir {
            self.dir = dir
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.dir = base.appendingPathComponent("RepTest", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.dir, withIntermediateDirectories: true)
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        trials = (try? dec.decode([RepTrial].self, from: data)) ?? []
    }

    private func saveIndex() throws {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(trials).write(to: indexURL, options: .atomic)
    }

    private func framesURL(_ id: String) -> URL {
        dir.appendingPathComponent("frames_\(id).csv")
    }

    func add(_ trial: RepTrial, frames: [RepFrame]) throws {
        let text = RepTestCSV.framesFile(trialId: trial.id, frames: frames)
        try Data(text.utf8).write(to: framesURL(trial.id), options: .atomic)
        trials.append(trial)
        try saveIndex()
    }

    func delete(_ trial: RepTrial) {
        try? FileManager.default.removeItem(at: framesURL(trial.id))
        trials.removeAll { $0.id == trial.id }
        try? saveIndex()
    }

    /// 產生 trials.csv 和 frames.csv（放在暫存資料夾，交給 ShareSheet）
    func exportFiles() throws -> [URL] {
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("reptest_export", isDirectory: true)
        try? FileManager.default.removeItem(at: out)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let sorted = trials.sorted { $0.date < $1.date }

        let trialsURL = out.appendingPathComponent("trials.csv")
        try Data(RepTestCSV.trialsCSV(sorted).utf8).write(to: trialsURL, options: .atomic)

        let texts = sorted.compactMap { try? String(contentsOf: framesURL($0.id), encoding: .utf8) }
        let framesOut = out.appendingPathComponent("frames.csv")
        try Data(RepTestCSV.combineFrames(texts).utf8).write(to: framesOut, options: .atomic)
        return [trialsURL, framesOut]
    }
}
