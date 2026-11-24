import SwiftUI

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
