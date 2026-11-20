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
    var id: String { exerciseId + "\(date.timeIntervalSince1970)" }
}

struct ProgressScreen: View {
    @Query(sort: \SetEntry.date) private var entries: [SetEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @State private var selectedId: String?
    @State private var showHistory = false

    /// Exercises with history, most-trained first.
    private var exerciseIds: [String] {
        var counts: [String: Int] = [:]
        for e in entries { counts[e.exerciseId, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var currentId: String? { selectedId ?? exerciseIds.first }

    /// Same rule as the character milestones: first time doesn't count.
    private var records: [PersonalRecord] {
        let sorted = entries.sorted { a, b in
            a.date != b.date ? a.date < b.date : a.setIndex < b.setIndex
        }
        var best: [String: Double] = [:]
        var out: [PersonalRecord] = []
        for e in sorted where e.weight > 0 {
            guard let ex = ExerciseLibrary.byId(e.exerciseId), ex.loaded else { continue }
            if let prev = best[e.exerciseId] {
                if e.weight > prev {
                    out.append(PersonalRecord(exerciseId: e.exerciseId, date: e.date,
                                              weight: e.weight, reps: e.reps, previous: prev))
                    best[e.exerciseId] = e.weight
                }
            } else {
                best[e.exerciseId] = e.weight
            }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    RankCard(rank: RankEngine.rank(sessions: sessions, goal: weeklyGoal))
                    if entries.isEmpty {
                        ContentUnavailableView("還沒有紀錄", systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("練完第一次後，這裡會出現你的進步曲線。"))
                            .foregroundStyle(Theme.muted)
                            .padding(.top, 40)
                    } else {
                        let records = self.records
                        statTiles(records: records.count)
                        weeklyCard
                        if let id = currentId, let ex = ExerciseLibrary.byId(id) {
                            exerciseCard(ex, records: records)
                        }
                        recordList(records)
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
            Text(ex.loaded ? "估算最大力量（1RM）" : "單組最多\(ex.unit.label)數")
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
                                Text("原本 \(Progression.format(r.previous)) kg")
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
