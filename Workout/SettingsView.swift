import SwiftUI

struct EquipmentPicker: View {
    @Binding var raw: String

    var body: some View {
        ForEach(Equipment.allCases) { eq in
            Toggle(isOn: binding(for: eq)) {
                Label(eq.name, systemImage: eq.icon)
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

struct SettingsView: View {
    @AppStorage(Keys.equipment) private var equipmentRaw = ""
    @AppStorage(Keys.weeklyGoal) private var weeklyGoal = 4
    @AppStorage(Keys.increment) private var increment = 2.5
    @AppStorage(Keys.maxDumbbell) private var maxDumbbell = 20.0
    @AppStorage(Keys.maxBarbell) private var maxBarbell = 40.0
    @AppStorage(Keys.startDate) private var startDate = Date().timeIntervalSince1970
    @State private var confirmRestart = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EquipmentPicker(raw: $equipmentRaw)
                } header: {
                    Text("我的器材")
                } footer: {
                    Text("徒手動作永遠可用。勾選後課表會自動換成適合的動作。")
                }

                Section("目標") {
                    Stepper("每週 \(weeklyGoal) 次", value: $weeklyGoal, in: 2...6)
                    Stepper("每次加重 \(Progression.format(increment)) kg", value: $increment, in: 0.5...5, step: 0.5)
                    Stepper("啞鈴最重（每支）\(Progression.format(maxDumbbell)) kg", value: $maxDumbbell, in: 5...60, step: 2.5)
                    Stepper("槓鈴最重（含槓）\(Progression.format(maxBarbell)) kg", value: $maxBarbell, in: 10...150, step: 5)
                }

                Section {
                    LabeledContent("目前", value: "第 \(Stats.week(since: Date(timeIntervalSince1970: startDate))) 週")
                    Button("從第 1 週重新開始") { confirmRestart = true }
                } header: {
                    Text("週期")
                } footer: {
                    Text("第 1-2 週是適應期，之後每 6 週有一次減量週，減量週後換一批動作。重新開始不會刪除紀錄。")
                }
            }
            .navigationTitle("設定")
            .confirmationDialog("從第 1 週重新開始？", isPresented: $confirmRestart, titleVisibility: .visible) {
                Button("重新開始") { startDate = Date().timeIntervalSince1970 }
            } message: {
                Text("適合停練一段時間後回來，會重新進入兩週適應期。")
            }
        }
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
                        Text("這次不一樣").font(.title.bold())
                        Text("每週 4 次，每次照著做就好。忙的時候選精簡版，20 分鐘也算數。中斷了也不用從頭來，只要接著下一天練。")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                Section("你家裡有什麼器材？") {
                    EquipmentPicker(raw: $equipmentRaw)
                }
                Section {
                    Button {
                        startDate = Date().timeIntervalSince1970
                        onboarded = true
                    } label: {
                        Text("開始第 1 週").font(.headline).frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("練壯")
        }
    }
}
