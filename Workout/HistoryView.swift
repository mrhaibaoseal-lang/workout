import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("還沒有紀錄", systemImage: "list.bullet.rectangle",
                                           description: Text("完成的訓練會出現在這裡。"))
                } else {
                    List {
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
                                    Text("\(s.date.formatted(date: .abbreviated, time: .shortened)) · \(s.durationSeconds / 60) 分鐘 · \(s.entries.count) 組")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(sessions[i]) }
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

    var body: some View {
        List {
            ForEach(groups) { g in
                Section(g.name) {
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
                }
            }
        }
        .navigationTitle(session.dayName)
    }
}
