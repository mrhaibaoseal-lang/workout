import SwiftUI
import SwiftData
import Charts

struct ProgressPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct ProgressScreen: View {
    @Query(sort: \SetEntry.date) private var entries: [SetEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedId: String?
    @State private var showHistory = false

    /// Exercises with history, most-trained first.
    private var exerciseIds: [String] {
        var counts: [String: Int] = [:]
        for e in entries { counts[e.exerciseId, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var currentId: String? { selectedId ?? exerciseIds.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if entries.isEmpty {
                        ContentUnavailableView("還沒有紀錄", systemImage: "chart.line.uptrend.xyaxis",
                                               description: Text("練完第一次後，這裡會出現你的進步曲線。"))
                    } else {
                        summaryCard
                        if let id = currentId, let ex = ExerciseLibrary.byId(id) {
                            exerciseCard(ex)
                        }
                        weeklyCard
                    }
                }
                .padding()
            }
            .navigationTitle("進步")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Label("紀錄", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }

    private var summaryCard: some View {
        let totalSets = entries.count
        let minutes = sessions.reduce(0) { $0 + $1.durationSeconds } / 60
        return HStack {
            stat("\(sessions.count)", "總次數")
            stat("\(totalSets)", "總組數")
            stat("\(minutes)", "總分鐘")
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

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

    private func exerciseCard(_ ex: Exercise) -> some View {
        let pts = points(for: ex)
        let unit = ex.loaded ? "kg" : ex.unit.label
        return VStack(alignment: .leading, spacing: 12) {
            Menu {
                ForEach(exerciseIds, id: \.self) { id in
                    Button(ExerciseLibrary.byId(id)?.name ?? id) { selectedId = id }
                }
            } label: {
                HStack {
                    Text(ex.name).font(.title3.bold())
                    Image(systemName: "chevron.down")
                }
            }

            Text(ex.loaded ? "估算最大力量（1RM）" : "單組最多\(ex.unit.label)數")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let first = pts.first, let last = pts.last, pts.count > 1, first.value > 0 {
                let pct = (last.value - first.value) / first.value * 100
                Text(pct >= 0
                     ? "比第一次強了 \(Int(pct.rounded()))% 💪"
                     : "比第一次少 \(Int((-pct).rounded()))%，沒關係，繼續練")
                    .font(.headline)
                    .foregroundStyle(pct >= 0 ? .green : .orange)
            }

            Chart(pts) { p in
                LineMark(x: .value("日期", p.date), y: .value(unit, p.value))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("日期", p.date), y: .value(unit, p.value))
            }
            .frame(height: 200)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weeklyCard: some View {
        let cal = Stats.calendar
        let thisWeek = Stats.weekStart(.now)
        let weeks: [ProgressPoint] = (0..<8).reversed().map { offset in
            let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeek)!
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start)!
            let n = sessions.filter { $0.date >= start && $0.date < end }.count
            return ProgressPoint(date: start, value: Double(n))
        }
        return VStack(alignment: .leading, spacing: 12) {
            Text("最近 8 週訓練次數").font(.title3.bold())
            Chart(weeks) { w in
                BarMark(x: .value("週", w.date, unit: .weekOfYear), y: .value("次數", w.value))
            }
            .frame(height: 160)
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}
