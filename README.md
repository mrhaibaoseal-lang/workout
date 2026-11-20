# 練壯（Workout）

在家用現有器材練壯的 iPhone App（SwiftUI + SwiftData，iOS 17 以上）。

## 功能

- **每週 4 天課表**：上半身 A / 下半身 A / 上半身 B / 下半身 B，依序輪流。中斷了不用重來，只要接著練下一天。
- **忙碌精簡版**：一鍵切換，只做每天最重要的 3 個動作（約 20 分鐘）。
- **依器材自動挑動作**：在設定勾選器材，課表會換成你做得到的動作。
- **自動加重建議**：上次全部組都做到次數上限就建議加重，沒做到就建議多做 1 下。
- **週期安排**：第 1-2 週是適應期（練輕一點），每 6 週有一次減量週，之後換一批動作。
- **進步曲線**：每個動作的估算最大力量或次數走勢，加上每週訓練次數。
- **休息計時器**：每打勾一組就開始倒數。
- 資料只存在手機上，不需要帳號。

## 雲端編譯

每次 push 都會觸發 GitHub Actions（`.github/workflows/build.yml`）：
在 macOS 機器上用 XcodeGen 從 `project.yml` 產生專案，編出**未簽名**的 `Workout.ipa`。

下載方式：GitHub 的 repo → **Actions** → 點最新一次成功的執行紀錄 → 最下面 **Artifacts** 的 `Workout-ipa`（下載下來是 zip，解開就是 `.ipa`）。

## 安裝到 iPhone

未簽名的 IPA 要先簽名才能裝。最簡單的方式：

1. 電腦（Windows 或 Mac）安裝 [Sideloadly](https://sideloadly.io/)。
2. iPhone 用線接電腦，把 `Workout.ipa` 拖進 Sideloadly，輸入你的 Apple ID，按 Start。
3. iPhone：**設定 → 一般 → VPN 與裝置管理**，信任你的 Apple ID。
4. iPhone：**設定 → 隱私權與安全性 → 開發者模式**，打開（第一次需要重開機）。

用免費 Apple ID 簽名，App 每 **7 天**要重新簽一次（資料不會消失）。
付費 Apple Developer（每年 US$99）可以改成 TestFlight 安裝，簽名一年有效。

## 專案結構

```
project.yml                 XcodeGen 專案設定
Workout/
  WorkoutApp.swift          App 進入點、分頁
  Models.swift              SwiftData 資料模型、器材
  ExerciseLibrary.swift     動作庫
  Program.swift             課表、週期、加重建議、統計
  TodayView.swift           今天練什麼
  WorkoutView.swift         訓練中畫面（記錄、休息計時）
  ProgressScreen.swift      進步圖表
  HistoryView.swift         訓練紀錄
  SettingsView.swift        設定、第一次開啟引導
```
