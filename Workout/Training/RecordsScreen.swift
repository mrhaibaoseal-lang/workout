import SwiftUI
import SwiftData
import Charts

private func recordDateText(_ d: Date) -> String {
    d.formatted(.dateTime.year().month(.defaultDigits).day())
}

private func shortDateText(_ d: Date) -> String {
    d.formatted(.dateTime.month(.defaultDigits).day())
}

private func exerciseName(_ id: String) -> String {
    ExerciseLibrary.byId(id)?.name ?? id
}

// MARK: - Screen

struct RecordsScreen: View {
    @Query(sort: \SetEntry.date) private var allEntries: [SetEntry]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    /// 按按鈕後讓畫面重算（資料存在 UserDefaults，SwiftUI 不會自己知道）。
    @State private var refresh = 0

    private func stalledList() -> [PlateauInfo] {
        _ = refresh
        return Plateau.stalled(sessions: sessions)
    }

    var body: some View {
        let book = RecordBook.all(entries: allEntries)
        let stalled = stalledList()
        let events = RecordBook.allEvents(book)
        let cutoff = Date.now.addingTimeInterval(-30 * 86_400)
        let recentCount = events.filter { $0.date >= cutoff }.count
        let rows = book.values
            .filter { !$0.history.isEmpty }
            .sorted { ($0.lastDate ?? .distantPast) > ($1.lastDate ?? .distantPast) }
        let deloadEnd = Plateau.currentDeloadEnd
        // 0.26.0：停滯建議減量併進疲勞判斷（`Fatigue`）
        let suggestDeload: Bool = {
            guard deloadEnd == nil, case .early = Fatigue.offer(week: Plateau.currentWeek, sessions: sessions) else { return false }
            return true
        }()

        return ScrollView {
            VStack(spacing: 12) {
                if rows.isEmpty {
                    ContentUnavailableView("還沒有紀錄", systemImage: "trophy",
                                           description: Text("練完幾次後，這裡會列出你每個動作的個人紀錄。"))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 40)
                } else {
                    HStack(spacing: 8) {
                        summaryTile(events.count, "破紀錄總次數", color: Theme.hotText)
                        summaryTile(recentCount, "最近 30 天", color: Theme.fg)
                        summaryTile(stalled.count, "停滯中的動作", color: stalled.isEmpty ? Theme.fg : Theme.gold)
                    }

                    if let end = deloadEnd {
                        deloadActiveCard(end)
                    } else if suggestDeload {
                        deloadSuggestCard
                    }

                    if !stalled.isEmpty {
                        stalledSection(stalled)
                    }

                    exerciseList(rows)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .themeScreen()
        .navigationTitle("個人紀錄")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func summaryTile(_ value: Int, _ label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            CountUpText(value).font(Theme.number(28)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .themeCard(padding: 12, radius: 16)
    }

    private func deloadActiveCard(_ end: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(Theme.green)
                .frame(width: 40, height: 40)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("減量週進行中，到 \(shortDateText(end.addingTimeInterval(-1)))")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text("這週組數和重量都會減輕，讓身體恢復。")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .themeCard(padding: 14, radius: 20)
    }

    private var deloadSuggestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.heart.fill").foregroundStyle(Theme.gold)
                Text("建議這週改成減量週")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
            }
            Text("好幾個動作卡住、疲勞在累積。這週減量休息，下週換一批動作再重新衝。")
                .font(.caption).foregroundStyle(Theme.muted)
            Button {
                Plateau.startDeload(sessions: sessions)
                refresh += 1
            } label: {
                Text("這週改成減量週")
            }
            .buttonStyle(HotButtonStyle(height: 46))
        }
        .themeCard(padding: 14, radius: 20)
    }

    private func stalledSection(_ list: [PlateauInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("停滯中")
                .font(.headline).foregroundStyle(Theme.fg)
                .padding(.horizontal, 4).padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, info in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(exerciseName(info.exerciseId))
                                .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                            Spacer()
                            Tag(text: "\(info.sessionsWithoutProgress) 次沒進步", fg: Theme.gold, bg: Theme.goldBg)
                        }
                        Text(info.suggestion)
                            .font(.caption).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            Plateau.markReset(info.exerciseId)
                            refresh += 1
                        } label: {
                            Text("這次減量重新爬")
                        }
                        .buttonStyle(GhostButtonStyle())
                        swapButton(info.exerciseId)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if i < list.count - 1 { Divider().overlay(Theme.divider) }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    /// 停滯的動作如果是課表自動挑的、而且還有別的候選，可以直接換一個動作（新動作從頭記，這個動作的停滯也歸零）。
    @ViewBuilder
    private func swapButton(_ exerciseId: String) -> some View {
        if !ProgramBuilder.shiftKeys(exerciseId: exerciseId).isEmpty {
            HStack(spacing: 2) {
                Button {
                    ProgramBuilder.shiftExercise(exerciseId)
                    Plateau.markReset(exerciseId)
                    refresh += 1
                } label: {
                    Text("換一個動作")
                }
                .buttonStyle(GhostButtonStyle())
                InfoTip(item: .fixedCompound)
            }
        }
    }

    private func exerciseList(_ rows: [ExerciseRecords]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("每個動作的紀錄")
                .font(.headline).foregroundStyle(Theme.fg)
                .padding(.horizontal, 4).padding(.top, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.exerciseId) { i, r in
                    NavigationLink {
                        ExerciseRecordsView(exerciseId: r.exerciseId)
                    } label: {
                        exerciseRow(r)
                    }
                    .buttonStyle(.plain)
                    if i < rows.count - 1 { Divider().overlay(Theme.divider) }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    private func exerciseRow(_ r: ExerciseRecords) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(r.exercise.name)
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text(r.lastRecordDate.map { "最近破紀錄 \(shortDateText($0))" } ?? "還沒破過紀錄")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if r.exercise.loaded {
                    if let m = r.maxWeight {
                        CountUpText(m.weight) { "最重 \(Progression.format($0)) kg" }
                            .font(Theme.number(14)).foregroundStyle(Theme.fg)
                    }
                    if let e = r.bestE1RM {
                        Text("最大力量 \(Progression.format(Progression.roundHalf(e.value))) kg")
                            .font(.caption).foregroundStyle(Theme.muted)
                    }
                } else if let m = r.maxReps {
                    CountUpText(Double(m.reps)) { "最多 \(Int($0.rounded())) \(r.exercise.unit.label)" }
                        .font(Theme.number(14)).foregroundStyle(Theme.fg)
                }
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - One exercise

struct ExerciseRecordsView: View {
    let exerciseId: String
    @Query(sort: \SetEntry.date) private var allEntries: [SetEntry]

    private struct TileItem: Identifiable {
        let title: String
        let number: Double
        let text: (Double) -> String
        let sub: String
        var id: String { title }
    }

    var body: some View {
        let rec = RecordBook.records(for: exerciseId, entries: allEntries)
        return ScrollView {
            VStack(spacing: 12) {
                if let rec, !rec.history.isEmpty {
                    hero(rec)
                    tiles(rec)
                    if rec.exercise.loaded { rangeTable(rec) }
                    timelineList(rec)
                } else {
                    ContentUnavailableView("還沒有紀錄", systemImage: "trophy",
                                           description: Text("這個動作練過之後，紀錄會出現在這裡。"))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .themeScreen()
        .navigationTitle(exerciseName(exerciseId))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: Hero + chart

    private func hero(_ rec: ExerciseRecords) -> some View {
        let ex = rec.exercise
        let unit = ex.loaded ? "kg" : ex.unit.label
        let pts = rec.history
        let cal = Calendar.current
        let prDays = Set(rec.timeline.map { cal.startOfDay(for: $0.date) })
        let big: Double = ex.loaded ? (rec.bestE1RM?.value ?? 0) : Double(rec.maxReps?.reps ?? 0)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                CountUpText(big) { ex.loaded ? String(format: "%.1f", $0) : "\(Int($0))" }
                    .font(Theme.number(40)).foregroundStyle(Theme.fg)
                Text(unit).font(.subheadline).foregroundStyle(Theme.muted)
            }
            Text(ex.loaded ? "推估最大力量" : "單組最多\(ex.unit.label)數")
                .font(.caption).foregroundStyle(Theme.muted)

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
            .chartOverlay { proxy in
                if let last = pts.last {
                    ChartLastPointMarker(proxy: proxy, x: last.date, y: last.value,
                                         color: prDays.contains(last.date) ? Theme.hot : Theme.accent)
                }
            }
            .chartDrawIn()
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

    // MARK: Tiles

    private func tileItems(_ rec: ExerciseRecords) -> [TileItem] {
        if rec.exercise.loaded {
            var items: [TileItem] = []
            if let m = rec.maxWeight {
                items.append(TileItem(title: "最大重量", number: m.weight, text: { "\(Progression.format($0)) kg" },
                                      sub: "× \(m.reps) · \(shortDateText(m.date))"))
            }
            if let e = rec.bestE1RM {
                items.append(TileItem(title: "推估最大力量", number: Progression.roundHalf(e.value), text: { "\(Progression.format($0)) kg" },
                                      sub: "\(Progression.format(e.weight)) × \(e.reps) · \(shortDateText(e.date))"))
            }
            if let v = rec.bestSetVolume {
                items.append(TileItem(title: "單組最大量", number: v.value.rounded(), text: { "\(Progression.format($0)) kg" },
                                      sub: shortDateText(v.date)))
            }
            if let v = rec.bestSessionVolume {
                items.append(TileItem(title: "單次訓練最大量", number: v.value.rounded(), text: { "\(Progression.format($0)) kg" },
                                      sub: shortDateText(v.date)))
            }
            return items
        }
        var items: [TileItem] = []
        if let m = rec.maxReps {
            items.append(TileItem(title: "單組最多", number: Double(m.reps),
                                  text: { "\(Int($0.rounded())) \(rec.exercise.unit.label)" },
                                  sub: shortDateText(m.date)))
        }
        items.append(TileItem(title: "累積組數", number: Double(rec.setCount), text: { "\(Int($0.rounded()))" }, sub: "正式組"))
        return items
    }

    private func tiles(_ rec: ExerciseRecords) -> some View {
        let items = tileItems(rec)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items) { t in
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.title).font(.caption).foregroundStyle(Theme.muted)
                    CountUpText(t.number, format: t.text).font(Theme.number(22)).foregroundStyle(Theme.fg)
                        .minimumScaleFactor(0.7).lineLimit(1)
                    Text(t.sub).font(.caption2).foregroundStyle(Theme.muted)
                }
                .themeCard(padding: 12, radius: 16)
            }
        }
    }

    // MARK: Rep ranges

    private func rangeTable(_ rec: ExerciseRecords) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("各次數區間的最佳")
                .font(.headline).foregroundStyle(Theme.fg)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(RepRange.allCases.enumerated()), id: \.element.id) { i, range in
                    HStack {
                        Text(range.title)
                            .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                            .frame(width: 84, alignment: .leading)
                        Spacer()
                        if let m = rec.repRangeBests[range] {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("\(Progression.format(m.weight)) kg × \(m.reps)")
                                    .font(Theme.number(15)).foregroundStyle(Theme.fg)
                                Text(recordDateText(m.date))
                                    .font(.caption2).foregroundStyle(Theme.muted)
                            }
                        } else {
                            Text("—").foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if i < RepRange.allCases.count - 1 { Divider().overlay(Theme.divider) }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
        }
    }

    // MARK: Timeline

    @ViewBuilder
    private func timelineList(_ rec: ExerciseRecords) -> some View {
        let events = Array(rec.timeline.reversed())
        VStack(alignment: .leading, spacing: 8) {
            Text("破紀錄時間軸")
                .font(.headline).foregroundStyle(Theme.fg)
                .padding(.horizontal, 4)
            if events.isEmpty {
                Text("還沒破過紀錄。第一次做不算，下次超越它就會出現在這裡。")
                    .font(.caption).foregroundStyle(Theme.muted)
                    .themeCard(padding: 14, radius: 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { i, ev in
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(Theme.hotText)
                                .frame(width: 36, height: 36)
                                .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.kindLabel)
                                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                                Text(recordDateText(ev.date))
                                    .font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(ev.newText)
                                    .font(Theme.number(15)).foregroundStyle(Theme.fg)
                                Text("原本 \(ev.oldText)")
                                    .font(.caption2).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if i < events.count - 1 { Divider().overlay(Theme.divider) }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.line, lineWidth: 1))
            }
        }
    }
}

// MARK: - Link card

/// 放在進步頁的入口卡片。外面自己包 NavigationLink { RecordsScreen() }。
struct RecordsLinkCard: View {
    @Query(sort: \SetEntry.date) private var allEntries: [SetEntry]

    private var subtitle: String {
        let book = RecordBook.all(entries: allEntries)
        let events = RecordBook.allEvents(book)
        if let e = events.first {
            return "最近破紀錄：\(exerciseName(e.exerciseId)) \(shortDateText(e.date))"
        }
        return book.isEmpty ? "每個動作的最大重量、推估最大力量、破紀錄時間軸" : "還沒破過紀錄，下次超越自己就會出現"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title3)
                .foregroundStyle(Theme.hotText)
                .frame(width: 40, height: 40)
                .background(Theme.hotBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("個人紀錄").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fg)
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
        }
        .themeCard(padding: 14, radius: 20)
    }
}
