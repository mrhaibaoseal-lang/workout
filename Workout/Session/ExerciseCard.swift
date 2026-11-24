import SwiftUI
import SwiftData

// MARK: - Exercise card

/// 卡片上的超級組標示
struct GroupBadge {
    let title: String
    let detail: String
    let note: String?
}

struct ExerciseCard: View {
    @Binding var draft: ExerciseDraft
    let number: Int
    let total: Int
    let activeSetId: UUID?
    let increment: Double
    var swapOptions: [Exercise] = []
    let onFocus: (UUID) -> Void
    let onComplete: (UUID) -> Void
    var onScheme: (SetScheme) -> Void = { _ in }
    var onToggleWarmup: () -> Void = {}
    var onSwap: (Exercise) -> Void = { _ in }
    var group: GroupBadge? = nil
    /// 還沒做任何一組、而且有同類型的其他動作可以換
    var canReplace = false
    var onEasePain: (Joint?) -> Void = { _ in }
    var onAvoid: (AvoidReason, Joint?) -> Void = { _, _ in }
    var onLogPain: (Joint?) -> Void = { _ in }
    @State private var showPain = false
    /// 「會痛…」選的關節；nil＝說不上來
    @State private var painJoint: Joint?
    /// 備註框：有上次的備註或已經寫了才一直開著，不然按「加備註」才出現
    @State private var noteOpen = false
    /// 「看影片」示範（`DemoVideoSheet`）
    @State private var showVideo = false

    private var ex: Exercise { draft.item.exercise }
    private var finished: Bool { draft.sets.allSatisfy(\.done) }
    private var hasActive: Bool { draft.sets.contains { $0.id == activeSetId } }
    @EnvironmentObject private var inventory: InventoryStore

    private var demoStage: some View {
        CharacterView(move: CharacterMove.forExercise(ex), loadout: inventory.state.loadout,
                      animated: true, showStats: false)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RadialGradient(
                    colors: [Color(gearHex: "#26303D"), Color(gearHex: "#141920"), Color(gearHex: "#0C0F14")],
                    center: .top, startRadius: 10, endRadius: 260),
                in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .bottomTrailing) {
                Button { showVideo = true } label: {
                    Label(DemoVideos.video(for: ex) != nil ? "看影片" : "找影片", systemImage: "play.rectangle.fill")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(.black.opacity(0.55), in: Capsule())
                        .foregroundStyle(Theme.fg)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .sheet(isPresented: $showVideo) { DemoVideoSheet(exercise: ex).environmentObject(inventory) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let group {
                groupHeader(group)
            }
            if hasActive {
                demoStage
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("動作 \(number) / \(total)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(hasActive ? Theme.hotText : Theme.muted)
                    Text(ex.name)
                        .font(.system(size: hasActive ? 24 : 18, weight: .black))
                        .foregroundStyle(Theme.fg)
                    Text(target)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.accent)
                } else {
                    optionsMenu
                }
            }

            if hasActive {
                if draft.scheme != .straight {
                    // 排法只顯示短名稱，完整說明放在 ⓘ 裡
                    HStack(spacing: 2) {
                        Label("排法：\(draft.scheme.title)", systemImage: "chart.bar.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accentSoft)
                        InfoTip(item: draft.scheme == .dropset ? .dropset : .pyramid)
                    }
                }
                suggestionLine
                if let side = SideBalance.cardNote(ex) {
                    Label(side, systemImage: "hand.raised.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.gold)
                }
                Text(ex.tip)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
                noteEditor
            } else if !draft.note.isEmpty {
                Label(draft.note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(Theme.accentSoft)
            }

            VStack(spacing: 8) {
                ForEach($draft.sets) { $set in
                    let tag = label(for: set)
                    if set.id == activeSetId {
                        ActiveSetEditor(set: $set, tag: tag, exercise: ex, ladder: draft.ladder,
                                        last: draft.lastFor(set), low: draft.item.low) {
                            onComplete(set.id)
                        }
                    } else {
                        CompactSetRow(set: set, tag: tag, exercise: ex) {
                            if set.done { onComplete(set.id) } else { onFocus(set.id) }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(hasActive ? Theme.accentDim : Theme.line, lineWidth: 1))
        .opacity(finished && !hasActive ? 0.7 : 1)
    }

    private func groupHeader(_ g: GroupBadge) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Label(g.title, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                InfoTip(item: .superset)
            }
            Text(g.detail)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            if let n = g.note {
                Text(n)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(n.contains("每輪要換") ? Theme.hotText : Theme.accentSoft)
            }
        }
    }

    private var target: String {
        let work = draft.sets.filter { $0.kind == .work }.count
        var base = "目標 \(work) 組 × \(draft.item.low)–\(draft.item.high) \(ex.unit.label)"
        if draft.scheme != .straight { base += " · " + draft.scheme.short }
        return draft.lastText.isEmpty ? base : base + " · " + draft.lastText
    }

    /// 正式組顯示第幾組，熱身組、遞減組顯示「熱」「降」。
    private func label(for set: SetDraft) -> String {
        if let b = set.kind.badge { return b }
        guard let i = draft.sets.firstIndex(where: { $0.id == set.id }) else { return "" }
        return "\(draft.sets[...i].filter { $0.kind == .work }.count)"
    }

    /// 動作備註：上次寫的放上面，這次的可以改（例如「椅子調第 3 格」）
    @ViewBuilder
    private var noteEditor: some View {
        if draft.lastNote == nil && draft.note.isEmpty && !noteOpen {
            Button { noteOpen = true } label: {
                Label("加備註", systemImage: "square.and.pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
            .buttonStyle(.plain)
        } else {
            noteField
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lastNote = draft.lastNote {
                Label("上次備註：\(lastNote)", systemImage: "note.text")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.gold)
            }
            TextField(draft.lastNote == nil ? "動作備註（例如：椅子調第 3 格）" : "這次的備註", text: $draft.note, axis: .vertical)
                .lineLimit(1...3)
                .font(.caption)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.sunken, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// 加重建議。重量跳太大時旁邊有 ⓘ 說明。
    private var suggestionLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 2) {
                Text(draft.suggestion.note)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(draft.suggestion.note.contains("加重") ? Theme.hotText : Theme.accentSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let tip = draft.suggestion.tip {
                    InfoTip(item: tip)
                }
            }
            if let caution = draft.caution {
                Label(caution, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.hotText)
            }
        }
    }

    private var optionsMenu: some View {
        Menu {
            if !draft.locked { adjustItems }
            painItems
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(Theme.accentSoft)
                .frame(width: 40, height: 40)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityLabel("組數排法、熱身與換動作")
        .confirmationDialog(painJoint.map { "\($0.title)會痛？" } ?? "這個動作會痛？", isPresented: $showPain, titleVisibility: .visible) {
            painChoices
        } message: {
            Text(painMessage)
        }
    }

    /// 組數排法、熱身、換動作（器材被佔用）：開始做正式組之前才能改。
    @ViewBuilder
    private var adjustItems: some View {
        if ex.loaded {
            Picker("組數排法", selection: Binding(get: { draft.chosen }, set: { onScheme($0) })) {
                ForEach(SetScheme.allCases) { s in
                    Text(s == .auto ? "自動（\(draft.chosen == .auto ? draft.scheme.short : "依課表")）" : s.title).tag(s)
                }
            }
            Button(draft.hasWarmups ? "移除熱身組" : "加熱身組", systemImage: "flame") { onToggleWarmup() }
        }
        if !swapOptions.isEmpty {
            Menu("換動作（器材被佔用）") {
                ForEach(swapOptions) { e in
                    Button(e.name) { onSwap(e) }
                }
            }
        }
    }

    @ViewBuilder
    private var painItems: some View {
        Menu("會痛…", systemImage: "bandage") {
            Section("哪裡痛？") {
                ForEach(Joint.menuOrder(for: ex.pattern)) { j in
                    Button(j.title) { painJoint = j; showPain = true }
                }
                Button("說不上來") { painJoint = nil; showPain = true }
            }
        }
        if canReplace {
            Button("不喜歡，換掉", systemImage: "hand.thumbsdown") { onAvoid(.dislike, nil) }
        }
    }

    @ViewBuilder
    private var painChoices: some View {
        if ex.loaded {
            Button("這次減輕 20% 試試") { onEasePain(painJoint) }
        }
        if canReplace {
            Button("換掉並記住，之後不排", role: .destructive) { onAvoid(.pain, painJoint) }
        }
        Button("只記下來") { onLogPain(painJoint) }
        Button("取消", role: .cancel) {}
    }

    private var painMessage: String {
        var text = "肌肉痠是正常的；關節或尖銳的痛，請先停下來。"
        if !canReplace { text += "已經做了幾組，只能減輕剩下組的重量。" }
        if !ex.loaded { text += "這個動作沒有重量可以減輕。" }
        return text
    }
}
