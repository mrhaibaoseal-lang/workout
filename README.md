# 練壯（Workout）

在家用現有器材練壯的 iPhone App（SwiftUI + SwiftData，iOS 17 以上）。

## 功能

- **每週 4 天課表**：上半身 A / 下半身 A / 上半身 B / 下半身 B，依序輪流。中斷了不用重來，只要接著練下一天。
- **三種長度**：完整版（約 60 分鐘）、精簡版（約 20 分鐘，只做最重要的 3 個動作）、只做 1 組（最懶的日子，做完會問要不要再多做一點）。
- **自動排程**：讀課表（可從截圖辨識）和「打工薪水帳」的班表，扣掉上課、打工、通勤，自動排出每週哪幾天練、練完整或精簡、幾點開始。
- **練習提醒**：照排出來的時間提醒；當天已經練過就不會提醒。
- **絕不連續兩次**：上次排定的練習日沒練，首頁會跳出提醒，一鍵開始「只做 1 組」。
- **主畫面／鎖定畫面小工具**：顯示本週練了幾次、連續幾週、下次練什麼。
- **依器材自動挑動作**：在設定勾選器材，課表會換成你做得到的動作。
- **自動加重建議**：上次全部組都做到次數上限就建議加重，沒做到就建議多做 1 下。
- **週期安排**：第 1-2 週是適應期（練輕一點），每 6 週有一次減量週，之後換一批動作。
- **進步曲線**：每個動作的估算最大力量或次數走勢，加上每週訓練次數。
- **休息計時器**：每打勾一組就開始倒數。
- **選手模式**：把訓練包裝成原創 MMA 選手的生涯。練完就是一場勝利（完整版 KO、精簡版降伏、只做 1 組判定），累積經驗值、等級、戰績、獎金。另有週任務、6 週訓練營與對手、裝備升級、隨機配色掉落、徽章、連續週數保護卡、押注、影子對手、總重量里程碑。
- **懲罰（都能挽回）**：超過 3 天沒練排名每天下滑、狀態下降；連續兩次漏練記棄權敗；訓練營沒達標輸掉比賽；冠軍太久沒練腰帶被剝奪。請假和整天活動不罰。完整規則見 [`docs/遊戲化設計.md`](docs/遊戲化設計.md)。
- 資料只存在手機上，不需要帳號。

## 雲端編譯與安裝

每次 push 都會觸發 GitHub Actions（`.github/workflows/build.yml`）：

1. 在 macOS 機器上用 XcodeGen 從 `project.yml` 產生專案，編出**未簽名**的 `Workout.ipa`。
2. build 號自動使用 Actions 的執行編號，每次都會遞增，Feather 才會顯示「有更新」。
3. 透過 [`mrhaibaoseal-lang/feather-source`](https://github.com/mrhaibaoseal-lang/feather-source) 的 action 發佈成 GitHub Release，私人 Feather 來源會自動收錄。

安裝：在 Feather 重新整理私人來源 → 下載「練壯」→ 用 FlareStore 憑證簽名安裝。

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
  Reminders.swift           練習提醒通知
  Schedule/                 課表、班表讀取、自動排程、課表截圖辨識
  ProgressScreen.swift      進步圖表
  HistoryView.swift         訓練紀錄（從「進步」或「選手」右上角打開）
  Career/                   選手模式：規則引擎、選手頁、比賽結果畫面
  SettingsView.swift        設定、第一次開啟引導
Shared/SharedStore.swift    App 與小工具共用的資料（App Group）
WorkoutWidget/              主畫面小工具
```
