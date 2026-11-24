import SwiftUI
import SwiftData

/// 恢復碼的顯示：一行三組，等寬字體，好抄。
struct RecoveryCodeBlock: View {
    let secrets: CloudSecrets

    var body: some View {
        let groups = RecoveryCode.groups(secrets)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(stride(from: 0, to: groups.count, by: 3)), id: \.self) { i in
                Text(groups[i..<min(i + 3, groups.count)].joined(separator: "  "))
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.fg)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.disabled)
        .accessibilityLabel("恢復碼，共 \(groups.count) 組")
    }
}

/// 第一次開啟雲端：顯示恢復碼，請使用者抄下來，輸入其中兩組確認抄對了才開啟。
struct CloudSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var secrets = CloudSecrets.generate()
    @State private var firstGroup = ""
    @State private var lastGroup = ""
    @State private var error: String?

    private var groups: [String] { RecoveryCode.groups(secrets) }

    private var confirmed: Bool {
        guard let first = groups.first, let last = groups.last else { return false }
        return RecoveryCode.normalize(firstGroup) == first && RecoveryCode.normalize(lastGroup) == last
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("這組恢復碼是唯一能打開你雲端備份的鑰匙。伺服器沒有它，App 作者也沒有，弄丟了就再也解不開。請用紙筆抄下來（或存在密碼管理員），不要拍照存在相簿、也不要傳給別人。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .listRowBackground(Theme.surface)

                Section {
                    RecoveryCodeBlock(secrets: secrets)
                        .padding(.vertical, 6)
                } header: {
                    SectionLabel("你的恢復碼")
                } footer: {
                    SectionLabel("英文字母不分大小寫；沒有 I、L、O、U（會當成 1 和 0）。每組 6 個字，共 \(groups.count) 組。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    TextField("第 1 組", text: $firstGroup)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("第 \(groups.count) 組（最後一組）", text: $lastGroup)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    SectionLabel("確認你抄對了")
                } footer: {
                    SectionLabel("照你抄的紙，輸入第 1 組和最後一組。對了才能開啟。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button("我抄好了，開啟加密雲端備份") { enable() }
                        .buttonStyle(HotButtonStyle())
                        .disabled(!confirmed)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.hotText)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .themeForm()
            .navigationTitle("加密雲端備份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .interactiveDismissDisabled()
        .preferredColorScheme(.dark)
    }

    private func enable() {
        if CloudSync.shared.enable(with: secrets) {
            dismiss()
        } else {
            error = "金鑰存不進這支手機的 Keychain，請稍後再試。"
        }
    }
}

/// 設定 → 資料 →「查看恢復碼」：先驗證 Face ID／密碼。
struct RecoveryCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var secrets: CloudSecrets?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                if let secrets {
                    Section {
                        RecoveryCodeBlock(secrets: secrets)
                            .padding(.vertical, 6)
                    } header: {
                        SectionLabel("恢復碼")
                    } footer: {
                        SectionLabel("換手機時輸入這組碼就能拿回備份。不要拍照、不要傳給別人。")
                    }
                    .listRowBackground(Theme.surface)
                } else {
                    Section {
                        Text(failed ? "沒有通過驗證，或這支手機上沒有金鑰。" : "需要先驗證是你本人…")
                            .foregroundStyle(Theme.muted)
                        if failed {
                            Button("再試一次") { Task { await unlock() } }
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themeForm()
            .navigationTitle("恢復碼")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .task { await unlock() }
        // 切到背景就蓋回去，不留在畫面上
        .onDisappear { secrets = nil }
    }

    private func unlock() async {
        failed = false
        guard await CloudAuth.authenticate(reason: "查看雲端備份的恢復碼"), let s = CloudKeychain.load() else {
            failed = true
            return
        }
        secrets = s
    }
}

/// 換手機：輸入恢復碼 → 下載 → 解密 → 先顯示內容 → 確認後還原（沿用 `FullBackup.restore`）。
struct CloudRestoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var inventory: InventoryStore

    @State private var codeText = ""
    @State private var secrets: CloudSecrets?
    @State private var versions: [CloudVersionInfo] = []
    @State private var busy = false
    @State private var error: String?
    @State private var pending: FullBackup.File?
    @State private var done = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("貼上或輸入恢復碼", text: $codeText, axis: .vertical)
                        .lineLimit(3...8)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    SectionLabel("恢復碼")
                } footer: {
                    SectionLabel("空格、橫線不用管，大小寫都可以。")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button {
                        Task { await lookup() }
                    } label: {
                        if busy { ProgressView() } else { Text("找雲端的備份") }
                    }
                    .frame(minHeight: 44)
                    .disabled(busy || codeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.hotText)
                    }
                }
                .listRowBackground(Theme.surface)

                if !versions.isEmpty {
                    Section {
                        ForEach(versions) { v in
                            Button {
                                Task { await load(v) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(v.date.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(Theme.fg)
                                        Text(v == versions.first ? "最新" : "較早的版本")
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    Text("\(max(1, v.size / 1024)) KB").font(.caption).foregroundStyle(Theme.muted)
                                }
                                .frame(minHeight: 44)
                            }
                            .disabled(busy)
                        }
                    } header: {
                        SectionLabel("選一個版本")
                    } footer: {
                        SectionLabel("通常選最新的。最新的有問題才選較早的。")
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .themeForm()
            .navigationTitle("從雲端還原")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
            .confirmationDialog("用雲端備份取代目前的資料？",
                                isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button("取代並還原", role: .destructive) { restore() }
                Button("取消", role: .cancel) { pending = nil }
            } message: {
                if let f = pending {
                    Text("備份裡有 \(f.sessions.count) 次訓練、\(f.bodies.count) 筆身體數據（\(f.exportedAt.formatted(date: .abbreviated, time: .shortened)) 存的）。目前 App 裡的紀錄和設定會全部被取代，沒辦法復原。")
                }
            }
            .alert("還原好了", isPresented: $done) {
                Button("好") { dismiss() }
            } message: {
                Text("建議把 App 完全關掉再打開一次，讓所有畫面重新讀取。之後會繼續用同一組恢復碼做雲端備份。")
            }
        }
        .interactiveDismissDisabled(busy)
        .preferredColorScheme(.dark)
    }

    private func lookup() async {
        error = nil
        guard let s = RecoveryCode.decode(codeText) else {
            error = "恢復碼不對：少了字、或抄錯了。再對一次紙上的碼。"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let list = try await CloudSync.versions(secrets: s)
            guard !list.isEmpty else { throw CloudError.notFound }
            secrets = s
            versions = list.sorted { $0.version > $1.version }
        } catch {
            versions = []
            self.error = error.localizedDescription
        }
    }

    private func load(_ v: CloudVersionInfo) async {
        guard let s = secrets else { return }
        error = nil
        busy = true
        defer { busy = false }
        do {
            pending = try await CloudSync.download(secrets: s, version: v.version)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore() {
        guard let f = pending, let s = secrets else { return }
        pending = nil
        do {
            try FullBackup.restore(f, context: context)
            inventory.reload()
            CloudSync.shared.resume(with: s)
            done = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// 設定 → 資料 裡的「加密雲端備份」區塊。還沒設定 Worker 網址時整段不顯示。
struct CloudSettingsSection: View {
    @ObservedObject private var sync = CloudSync.shared
    @AppStorage(Keys.cloudEnabled) private var enabled = false
    @State private var sheet: Sheet?

    private enum Sheet: Identifiable {
        case setup, code, restore
        var id: Int { hashValue }
    }

    var body: some View {
        if CloudConfig.isConfigured {
            Section {
                Toggle(isOn: Binding(get: { enabled }, set: { setEnabled($0) })) {
                    Label("加密雲端備份", systemImage: "icloud.and.arrow.up")
                }
                .frame(minHeight: 44)
                .sheet(item: $sheet) { which in
                    switch which {
                    case .setup: CloudSetupView()
                    case .code: RecoveryCodeSheet()
                    case .restore: CloudRestoreView()
                    }
                }
                if enabled {
                    Text(sync.statusText)
                        .font(.footnote)
                        .foregroundStyle(sync.lastError == nil ? Theme.muted : Theme.hotText)
                    Button {
                        sync.uploadNow()
                    } label: {
                        Label("立即同步", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .frame(minHeight: 44)
                    .disabled(sync.status == .syncing)
                }
                Button {
                    sheet = .code
                } label: {
                    Label("查看恢復碼", systemImage: "key.fill")
                }
                .frame(minHeight: 44)
                .disabled(!enabled && CloudKeychain.load() == nil)
                Button {
                    sheet = .restore
                } label: {
                    Label("從雲端還原（換手機）", systemImage: "icloud.and.arrow.down")
                }
                .frame(minHeight: 44)
            } header: {
                SectionLabel("加密雲端備份")
            } footer: {
                SectionLabel("預設關閉。開了以後，每次練完、離開 App 時，紀錄和設定會先在手機上加密再傳到雲端，伺服器看不到內容，只留最近 5 個版本。換手機時輸入恢復碼就能拿回來；恢復碼弄丟就解不開。")
            }
            .listRowBackground(Theme.surface)
        }
    }

    private func setEnabled(_ on: Bool) {
        if !on {
            sync.disable()
            enabled = false
        } else if CloudKeychain.load() != nil {
            // 以前開過，金鑰還在：直接再開，恢復碼不變
            CloudSync.setEnabled(true)
            sync.scheduleUpload()
        } else {
            sheet = .setup
        }
    }
}
