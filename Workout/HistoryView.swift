import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \IntervalLog.date, order: .reverse) private var intervals: [IntervalLog]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty && intervals.isEmpty {
                    ContentUnavailableView("還沒有紀錄", systemImage: "list.bullet.rectangle",
                                           description: Text("完成的訓練會出現在這裡。"))
                } else {
                    List {
                        Section {
                        ForEach(sessions) { s in
                            NavigationLink {
                                SessionDetailView(session: s)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(s.dayName).font(.headline)
                                        if let tag = s.length.tag {
                                            Text(tag).font(.caption)
                                                .padding(.horizontal, 6)
                                                .background(.orange.opacity(0.2), in: Capsule())
                                        }
                                    }
                                    Text("\(s.date.formatted(date: .abbreviated, time: .shortened)) · \(s.durationSeconds / 60) 分鐘 · \(s.entries.filter(\.isWork).count) 組")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !s.note.isEmpty {
                                        Label(s.note, systemImage: "note.text")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(sessions[i]) }
                        }
                        }
                        if !intervals.isEmpty {
                            Section("間歇計時（不算牌位）") {
                                ForEach(intervals) { IntervalLogRow(log: $0) }
                                    .onDelete { offsets in
                                        for i in offsets { context.delete(intervals[i]) }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("紀錄")
        }
    }
}

struct SessionDetailView: View {
    let session: WorkoutSession

    struct ExerciseGroup: Identifiable {
        let id: String
        let name: String
        let sets: [SetEntry]
    }

    private var groups: [ExerciseGroup] {
        var order: [String] = []
        var map: [String: [SetEntry]] = [:]
        for e in session.entries.sorted(by: { $0.setIndex < $1.setIndex }) {
            if map[e.exerciseId] == nil { order.append(e.exerciseId) }
            map[e.exerciseId, default: []].append(e)
        }
        return order.map { ExerciseGroup(id: $0, name: ExerciseLibrary.byId($0)?.name ?? $0, sets: map[$0] ?? []) }
    }

    private var notes: [String: String] { ExerciseNotes.decode(session.exerciseNotes) }

    var body: some View {
        List {
            if let r = Readiness.decode(session.readiness) {
                Section("訓練前狀態") {
                    HStack {
                        Text("睡眠 \(r.sleep) · 痠痛 \(r.soreness) · 精神 \(r.energy)")
                        Spacer()
                        Text("\(r.total)/15").bold()
                    }
                    .monospacedDigit()
                }
            }
            if !session.note.isEmpty {
                Section("備註") {
                    Text(session.note)
                }
            }
            ForEach(groups) { g in
                Section {
                    if let n = notes[g.id] {
                        Label(n, systemImage: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(g.sets) { e in
                        let ex = ExerciseLibrary.byId(e.exerciseId)
                        HStack {
                            Text("第 \(e.setIndex + 1) 組")
                            Spacer()
                            if ex?.loaded == true {
                                Text("\(Progression.format(e.weight)) kg × ")
                            }
                            Text("\(e.reps) \(ex?.unit.label ?? "下")")
                        }
                        .monospacedDigit()
                    }
                } header: {
                    Text(g.name)
                }
            }
        }
        .navigationTitle(session.dayName)
    }
}
