import SwiftUI
import SwiftData

/// Muted section header / footer text for dark Forms.
struct SectionLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).foregroundStyle(Theme.muted)
    }
}

extension View {
    /// Dark stage styling for Form / List screens.
    func themeForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .tint(Theme.accent)
    }
}

struct EquipmentPicker: View {
    @Binding var raw: String

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Equipment.homeChoices) { eq in
                let on = binding(for: eq)
                Button {
                    on.wrappedValue.toggle()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: eq.icon)
                            .font(.title2)
                            .foregroundStyle(on.wrappedValue ? Theme.accent : Theme.muted)
                            .frame(height: 28)
                        Text(eq.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.fg)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .padding(.horizontal, 8)
                    .background(on.wrappedValue ? Theme.accent.opacity(0.15) : Theme.surface,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(on.wrappedValue ? Theme.accent : Theme.line, lineWidth: on.wrappedValue ? 2 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on.wrappedValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.accent)
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(eq.name)
                .accessibilityAddTraits(on.wrappedValue ? .isSelected : [])
            }
        }
    }

    private func binding(for eq: Equipment) -> Binding<Bool> {
        Binding(
            get: { Equipment.parse(raw).contains(eq) },
            set: { on in
                var set = Equipment.parse(raw)
                if on { set.insert(eq) } else { set.remove(eq) }
                raw = Equipment.encode(set)
            }
        )
    }
}

struct OnboardingView: View {
    @AppStorage(Keys.onboarded) private var onboarded = false
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("這次不一樣")
                            .font(.title.bold())
                            .foregroundStyle(Theme.fg)
                        Text("每週 4 次，每次照著做就好。忙的時候選精簡版，20 分鐘也算數。中斷了也不用從頭來，只要接著下一天練。")
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Theme.surface)
                Section {
                    EquipmentPicker(raw: $equipmentRaw)
                        .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                } header: {
                    SectionLabel("你家裡有什麼器材？")
                }
                .listRowBackground(Color.clear)
                Section {
                    NavigationLink {
                        LevelTestView(onDone: start)
                    } label: {
                        Label("先做程度評估（約 10 分鐘）", systemImage: "gauge.with.dots.needle.50percent")
                    }
                    .frame(minHeight: 44)
                } footer: {
                    Text("伏地挺身、深蹲、划船各測一次，第一次的重量會推得比較準。之後也可以在設定裡做。")
                }
                .listRowBackground(Theme.surface)
                Section {
                    Button {
                        start()
                    } label: {
                        Text("開始第 1 週")
                    }
                    .buttonStyle(HotButtonStyle())
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }
                .listRowBackground(Color.clear)
            }
            .themeForm()
            .navigationTitle("練壯")
        }
    }

    private func start() {
        startDate = Date().timeIntervalSince1970
        onboarded = true
    }
}

struct WeekdayPicker: View {
    @Binding var raw: String

    /// Monday-first display order, as Calendar weekday numbers (1 = Sunday).
    private let order: [(Int, String)] = [(2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")]

    var body: some View {
        let selected = Keys.parseWeekdays(raw)
        HStack(spacing: 6) {
            ForEach(order.indices, id: \.self) { i in
                let (day, label) = order[i]
                let on = selected.contains(day)
                Button {
                    var s = selected
                    if on { s.remove(day) } else { s.insert(day) }
                    raw = s.sorted().map(String.init).joined(separator: ",")
                } label: {
                    Text(label)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(on ? Theme.accent : Theme.raised,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .foregroundStyle(on ? Theme.bg : Theme.fg)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
