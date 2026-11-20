import Foundation

extension Keys {
    /// 停滯後按「重新爬」的時間，JSON [exerciseId: TimeInterval]
    static let plateauResets = "plateauResets"
    /// 減量週結束時間（秒）。現在比這個早 = 減量週進行中。
    static let deloadUntil = "deloadUntil"
    /// 上次開始減量週的時間（秒）。
    static let lastDeloadStart = "lastDeloadStart"
}

struct PlateauInfo: Identifiable {
    let exerciseId: String
    /// 最新的幾次訓練都沒超過之前的最佳。
    let sessionsWithoutProgress: Int
    /// 之前的最佳（負重動作：估算 1RM；徒手動作：單組最多次數）。
    let best: Double
    let lastDate: Date
    let suggestion: String

    var id: String { exerciseId }
}

enum Plateau {
    static let minSessions = 4
    static let stallSessions = 3
    static let deloadCooldownDays = 21

    // MARK: Reset store

    private static var defaults: UserDefaults { .standard }

    static func resets() -> [String: TimeInterval] {
        guard let raw = defaults.string(forKey: Keys.plateauResets),
              let data = raw.data(using: .utf8),
              let dict = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else { return [:] }
        return dict
    }

    private static func saveResets(_ dict: [String: TimeInterval]) {
        guard let data = try? JSONEncoder().encode(dict), let raw = String(data: data, encoding: .utf8) else { return }
        defaults.set(raw, forKey: Keys.plateauResets)
    }

    /// 按了「重新爬」：這個時間點以前的訓練不再算，要新練 4 次才會再被判停滯。
    static func markReset(_ exerciseId: String) {
        var dict = resets()
        dict[exerciseId] = Date.now.timeIntervalSince1970
        saveResets(dict)
    }

    // MARK: Detection

    private struct SessionPerf {
        let date: Date
        let value: Double
    }

    /// 每個動作每次訓練的表現，新的在前。sessions 要由新到舊排好。
    private static func perfs(sessions: [WorkoutSession], resets: [String: TimeInterval]) -> [String: [SessionPerf]] {
        var out: [String: [SessionPerf]] = [:]
        for s in sessions {
            let work = s.entries.filter(\.isWork)
            if work.isEmpty { continue }
            let byEx = Dictionary(grouping: work, by: \.exerciseId)
            for (id, sets) in byEx {
                if let r = resets[id], s.date.timeIntervalSince1970 <= r { continue }
                guard let ex = ExerciseLibrary.byId(id) else { continue }
                let value: Double
                if ex.loaded {
                    let valid = sets.filter { $0.weight > 0 && $0.reps > 0 }
                    if valid.isEmpty { continue }
                    let low = valid.filter { $0.reps <= 12 }
                    let pool = low.isEmpty ? valid : low
                    value = pool.map { ExerciseRecords.e1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                } else {
                    value = Double(sets.map(\.reps).max() ?? 0)
                }
                if value <= 0 { continue }
                out[id, default: []].append(SessionPerf(date: s.date, value: value))
            }
        }
        // sessions 本來就新到舊；保險再排一次
        for key in out.keys { out[key]?.sort { $0.date > $1.date } }
        return out
    }

    private static func analyze(id: String, list: [SessionPerf]) -> PlateauInfo? {
        guard list.count >= minSessions, let ex = ExerciseLibrary.byId(id) else { return nil }
        var n = 0
        var k = stallSessions
        while k < list.count {
            let before = list[k...].map(\.value).max() ?? 0
            let recent = list[..<k].map(\.value).max() ?? 0
            if recent <= before + 0.001 { n = k; k += 1 } else { break }
        }
        guard n >= stallSessions else { return nil }
        let best = list.map(\.value).max() ?? 0
        let text: String
        if ex.loaded {
            text = "連續 \(n) 次沒進步：這次先減 10% 重量，用標準動作重新爬上來"
        } else {
            text = "連續 \(n) 次沒進步：這次放慢節奏（下放 3 秒、最低點停 1 秒），用更標準的動作做"
        }
        return PlateauInfo(exerciseId: id, sessionsWithoutProgress: n, best: best,
                           lastDate: list[0].date, suggestion: text)
    }

    /// 單一動作。sessions 要由新到舊排好。
    static func check(exerciseId: String, sessions: [WorkoutSession]) -> PlateauInfo? {
        let all = perfs(sessions: sessions, resets: resets())
        guard let list = all[exerciseId] else { return nil }
        return analyze(id: exerciseId, list: list)
    }

    /// 所有停滯中的動作（停最久的在前）。
    static func stalled(sessions: [WorkoutSession]) -> [PlateauInfo] {
        let all = perfs(sessions: sessions, resets: resets())
        return all.compactMap { analyze(id: $0.key, list: $0.value) }
            .sorted { a, b in
                a.sessionsWithoutProgress != b.sessionsWithoutProgress
                    ? a.sessionsWithoutProgress > b.sessionsWithoutProgress
                    : a.exerciseId < b.exerciseId
            }
    }

    // MARK: Deload

    static var deloadEnd: Date? {
        let t = defaults.double(forKey: Keys.deloadUntil)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 減量週進行中（只讀一個 UserDefaults 值，很便宜）。
    static var deloadActive: Bool {
        let t = defaults.double(forKey: Keys.deloadUntil)
        return t > 0 && Date.now.timeIntervalSince1970 < t
    }

    static func shouldSuggestDeload(sessions: [WorkoutSession]) -> Bool {
        if deloadActive { return false }
        let last = defaults.double(forKey: Keys.lastDeloadStart)
        if last > 0 {
            let days = Date.now.timeIntervalSince1970 - last
            if days < Double(deloadCooldownDays) * 86_400 { return false }
        }
        let all = perfs(sessions: sessions, resets: resets())
        let infos = all.compactMap { analyze(id: $0.key, list: $0.value) }
        guard !infos.isEmpty else { return false }
        let cutoff = Date.now.addingTimeInterval(-14 * 86_400)
        let recentTrained = all.values.filter { ($0.first?.date ?? .distantPast) >= cutoff }.count
        let stalledRecent = infos.filter { $0.lastDate >= cutoff }.count
        if stalledRecent >= 3 { return true }
        return stalledRecent >= 2 && recentTrained > 0
            && Double(stalledRecent) / Double(recentTrained) >= 0.4
    }

    /// 這週改成減量週（到本週結束），並讓目前停滯的動作重新計算。
    /// sessions 用來找出停滯的動作；不傳就只開減量週。
    static func startDeload(sessions: [WorkoutSession] = []) {
        let end = SharedStore.calendar.date(byAdding: .day, value: 7, to: SharedStore.weekStart(.now))
            ?? Date.now.addingTimeInterval(7 * 86_400)
        defaults.set(end.timeIntervalSince1970, forKey: Keys.deloadUntil)
        defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.lastDeloadStart)
        if !sessions.isEmpty {
            var dict = resets()
            let now = Date.now.timeIntervalSince1970
            for info in stalled(sessions: sessions) { dict[info.exerciseId] = now }
            saveResets(dict)
        }
    }

    // MARK: Suggestion tweak

    /// 停滯時改寫建議：負重動作先減 10%，徒手動作放慢節奏。只在進步期套用。
    static func adjust(_ s: Suggestion, item: PlannedExercise, info: PlateauInfo?,
                       ladder: WeightLadder, phase: Phase) -> Suggestion {
        guard let info, phase == .normal else { return s }
        if item.exercise.loaded {
            guard s.weight > 0 else { return s }
            let w = ladder.snap(s.weight * 0.9)
            return Suggestion(weight: w, reps: item.low,
                              note: "連續 \(info.sessionsWithoutProgress) 次沒進步：先減 10% 重量，用標準動作重新爬上來")
        }
        return Suggestion(weight: s.weight, reps: item.low,
                          note: "連續 \(info.sessionsWithoutProgress) 次沒進步：放慢節奏（下放 3 秒、最低點停 1 秒），用更標準的動作做")
    }
}
