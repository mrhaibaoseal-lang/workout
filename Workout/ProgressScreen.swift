import SwiftUI
import SwiftData
import Charts

struct ProgressPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// A set that beat the heaviest weight ever used for that exercise.
struct PersonalRecord: Identifiable {
    let exerciseId: String
    let date: Date
    let weight: Double
    let reps: Int
    let previous: Double
    /// 次數紀錄（同重量做更多下）：以前用這個重量最多幾下；重量紀錄是 nil
    var previousReps: Int? = nil
    var id: String { exerciseId + "\(date.timeIntervalSince1970)" }
}

struct ProgressScreen: View {
    @Query(sort: \SetEntry.date) private var allEntries: [SetEntry]
    /// 只看正式組（熱身組、Drop set 不算進步）
    private var entries: [SetEntry] { allEntries.filter(\.isWork) }
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @State private var selectedId: String?
    @State private var showHistory = false
    @Query(sort: \BodyLog.date, order: .reverse) private var bodyLogs: [BodyLog]
    private var latestBody: BodyLog? { bodyLogs.first }

    /// Exercises with history, most-trained first.
    private var exerciseIds: [String] {
        var counts: [String: Int] = [:]
        for e in entries { counts[e.exerciseId, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var currentId: String? { selectedId ?? exerciseIds.first }

    /// 和牌位、訓練中同一套規則（`PRRule`）：重量紀錄或最高重量的次數紀錄，第一次做不算，每次訓練每個動作最多 1 個。
    private var records: [PersonalRecord] {
        let work = entries.filter { $0.isWork && $0.weight > 0 && $0.reps > 0 }
        // 同一次訓練的組存檔時間相同
        let groups = Dictionary(grouping: work) { "\($0.exerciseId)|\($0.date.timeIntervalSince1970)" }
            .values.sorted { ($0.first?.date ?? .distantPast) < ($1.first?.date ?? .distantPast) }
        var best: [String: PRBest] = [:]
        var out: [PersonalRecord] = []
        for sets in groups {
            guard let first = sets.first, let ex = ExerciseLibrary.byId(first.exerciseId), ex.loaded else { continue }
            let id = first.exerciseId
            let before = best[id]
            var hit: (SetEntry, PRKind)? = nil
            var b = before
            for e in sets.sorted(by: { $0.setIndex < $1.setIndex }) {
                if before != nil, let k = PRRule.check(weight: e.weight, reps: e.reps, best: b) { hit = (e, k) }
                b = PRRule.merge(b, weight: e.weight, reps: e.reps)
            }
            best[id] = b
            if let h = hit, let before {
                let e = h.0
                switch h.1 {
                case .weight(let old):
                    out.append(PersonalRecord(exerciseId: id, date: e.date, weight: e.weight, reps: e.reps, previous: old))
                case .reps:
                    out.append(PersonalRecord(exerciseId: id, date: e.date, weight: e.weight, reps: e.reps,
                                              previous: before.weight, previousReps: before.reps))
                }
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    NavigationLink { BodyScreen() } label: { bodyLink }
                        .buttonStyle(.plain)
                    if entries.isEmpty {
                        ContentUnavailableView("還沒有紀錄", systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("練完第一次後，這裡會出現你的進步曲線。"))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 40)
                    } else {
                        let records = self.records
                        statTiles(records: records.count)
                        // 力量：每個動作的曲線、紀錄
                        SectionHeader(title: "力量")
                        if let id = currentId, let ex = ExerciseLibrary.byId(id) {
                            exerciseCard(ex, records: records)
                        }
                        NavigationLink { RecordsScreen() } label: { RecordsLinkCard() }
                            .buttonStyle(.plain)
                        recordList(records)
                        ShadowRivalCard(sessions: sessions)
                        // 部位：組數、疲勞、左右
                        SectionHeader(title: "部位")
                        MuscleVolumeCard(sessions: sessions)
                        FatigueMapCard(sessions: sessions)
                        SideBalanceCard(sessions: sessions)
                        // 訓練量
                        SectionHeader(title: "訓練量")
                        weeklyCard
                        TonnageCard(sessions: sessions)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .themeScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }

    private var bodyLink: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.arms.open")
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("身體數據").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text(latestBody.map { "上次量 \($0.date.formatted(.dateTime.month(.defaultDigits).day()))" + ($0.weight > 0 ? " · \(Progression.format($0.weight)) kg" : "") }
                     ?? "體重、圍度，用身形圖看變化（不用拍照）")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .themeCard(padding: 14, radius: 20)
    }

    private var header: some View {
        HStack {
            Text("進步")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(Theme.fg)
            Spacer()
            Button { showHistory = true } label: {
                Label("訓練紀錄", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.top, 12)
    }

    private func statTiles(records: Int) -> some View {
        HStack(spacing: 8) {
            tile("\(sessions.count)", unit: nil, "累積訓練", color: Theme.fg)
            tile("\(Stats.weekStreak(sessions))", unit: "週", "連續達標", color: Theme.fg)
            tile("\(records)", unit: nil, "破個人紀錄", color: Theme.hotText)
        }
    }

    private func tile(_ value: String, unit: String?, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Theme.number(28)).foregroundStyle(color)
                if let unit { Text(unit).font(.footnote).foregroundStyle(Theme.muted) }
            }
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .themeCard(padding: 12, radius: 16)
    }

    // MARK: Weekly

    private var weeklyCard: some View {
        let cal = Stats.calendar
        let thisWeek = Stats.weekStart(.now)
        let weeks: [ProgressPoint] = (0..<8).reversed().map { offset in
            let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeek)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let n = sessions.filter { $0.date >= start && $0.date < end }.count
            return ProgressPoint(date: start, value: Double(n))
        }
        let goal = Double(weeklyGoal)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("每週訓練次數").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Spacer()
                Text("最近 8 週 · 目標 \(weeklyGoal) 次").font(.caption).foregroundStyle(Theme.muted)
            }
            Chart {
                ForEach(weeks) { w in
                    let isNow = w.date == thisWeek
                    BarMark(x: .value("週", w.date, unit: .weekOfYear), y: .value("次數", w.value), width: .ratio(0.6))
                        .foregroundStyle(isNow ? Color(gearHex: "#3D5191") : (w.value >= goal ? Theme.accent : Theme.accentDim))
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            Text("\(Int(w.value))").font(Theme.number(11, .bold)).foregroundStyle(Theme.accentSoft)
                        }
                }
                RuleMark(y: .value("目標", goal))
                    .foregroundStyle(Theme.accentDim)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: weeks.map(\.date)) { v in
                    AxisValueLabel {
                        if let d = v.as(Date.self) {
                            Text(d == thisWeek ? "本週" : "\(cal.component(.month, from: d))/\(cal.component(.day, from: d))")
                                .font(.caption2)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(goal + 1, (weeks.map(\.value).max() ?? 0) + 1))
            .frame(height: 160)
        }
        .themeCard()
    }

    // MARK: Per exercise

    private func points(for ex: Exercise) -> [ProgressPoint] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: entries.filter { $0.exerciseId == ex.id }) {
            cal.startOfDay(for: $0.date)
        }
        return grouped.map { day, sets in
            let value: Double = ex.loaded
                ? sets.map { $0.weight * (1 + Double($0.reps) / 30) }.max() ?? 0  // 估算 1RM
                : Double(sets.map(\.reps).max() ?? 0)
            return ProgressPoint(date: day, value: value)
        }
        .sorted { $0.date < $1.date }
    }

    private func exerciseCard(_ ex: Exercise, records: [PersonalRecord]) -> some View {
        let pts = points(for: ex)
        let unit = ex.loaded ? "kg" : ex.unit.label
        let cal = Calendar.current
        let prDays = Set(records.filter { $0.exerciseId == ex.id }.map { cal.startOfDay(for: $0.date) })
        return VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(exerciseIds, id: \.self) { id in
                        let on = id == ex.id
                        Button { selectedId = id } label: {
                            Text(ExerciseLibrary.byId(id)?.name ?? id)
                                .font(.footnote.weight(on ? .bold : .regular))
                                .foregroundStyle(on ? Theme.bg : Theme.accentSoft)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(on ? Theme.fg : .clear, in: Capsule())
                                .overlay(Capsule().stroke(on ? Theme.fg : Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let last = pts.last {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(ex.loaded ? String(format: "%.1f", last.value) : "\(Int(last.value))")
                            .font(Theme.number(34))
                            .foregroundStyle(Theme.fg)
                        Text(unit).font(.subheadline).foregroundStyle(Theme.muted)
                    }
                    if let first = pts.first, pts.count > 1 {
                        let diff = last.value - first.value
                        Text(diff >= 0 ? "比第一次 +\(Progression.format(Progression.roundHalf(diff))) \(unit)"
                                       : "比第一次 \(Progression.format(Progression.roundHalf(diff))) \(unit)")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(diff >= 0 ? Theme.green : Theme.hotText)
                    }
                }
            }
            Text(ex.loaded ? "推估最大力量" : "單組最多\(ex.unit.label)數")
                .font(.caption)
                .foregroundStyle(Theme.muted)

            Chart(pts) { p in
                AreaMark(x: .value("日期", p.date), y: .value(unit, p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent.opacity(0.12))
                LineMark(x: .value("日期", p.date), y: .value(unit, p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                if prDays.contains(p.date) {
                    PointMark(x: .value("日期", p.date), y: .value(unit, p.value))
                        .foregroundStyle(Theme.hot)
                        .symbolSize(70)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Theme.divider)
                    AxisValueLabel().foregroundStyle(Theme.muted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day()).foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 170)

            if !prDays.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(Theme.hot).frame(width: 9, height: 9)
                    Text("橘點 = 那天破了個人紀錄").font(.caption).foregroundStyle(Theme.muted)
                }
            }
        }
        .themeCard()
    }

    // MARK: Records

    @ViewBuilder
    private func recordList(_ records: [PersonalRecord]) -> some View {
        let recent = Array(records.reversed().prefix(5))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("最近破的紀錄")
                    .font(.headline)
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { i, r in
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(Theme.hotText)
                                .frame(width: 40, height: 40)
                                .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ExerciseLibrary.byId(r.exerciseId)?.name ?? r.exerciseId)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.fg)
                                Text(r.date.formatted(.dateTime.month(.defaultDigits).day()))
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(Progression.format(r.weight)) kg × \(r.reps)")
                                    .font(Theme.number(16))
                                    .foregroundStyle(Theme.fg)
                                Text(r.previousReps.map { "原本 \($0) 下" } ?? "原本 \(Progression.format(r.previous)) kg")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        if i < recent.count - 1 {
                            Divider().overlay(Theme.divider)
                        }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
        }
    }
}
