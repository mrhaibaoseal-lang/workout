# 給 Claude 的固定說明

## 使用者偏好
- 一律用**繁體中文**回覆。技術說明要精準，以同儕程度溝通。
- iOS App 一律做**原生 App**（SwiftUI），不要網頁版或 PWA。

## 編譯與安裝（不要建議其他方式）
- 電腦是 **Windows**，沒有 Mac，本機無法編譯 iOS。
- iOS 一律用 **GitHub Actions macOS runner** 打包**未簽名 IPA**。不用 EAS Build，也不上 App Store / TestFlight。不要建議 Sideloadly、AltStore 或付費開發者帳號。
- 安裝方式：使用者在手機上用 **Feather** 簽名，憑證是 **FlareStore** 的。
- 發佈方式：workflow 最後呼叫 `mrhaibaoseal-lang/feather-source@main` 的 action，把 IPA 發佈成 Release，私人 Feather 來源（Cloudflare Worker）會自動收錄。repo 必須是 public。
- Feather 靠版本號判斷「有更新」：build 號用 `${{ github.run_number }}`，每次都會遞增。

## FlareStore 憑證能力
完整清單見共用說明：https://github.com/mrhaibaoseal-lang/feather-source/blob/main/CLAUDE.md

- App Groups 只有 `group.81c139ae9a27a7f8.1` ～ `.5` 這 5 個固定 ID。本專案的 entitlements 寫 `.1`，
  `Shared/SharedStore.swift` 執行時逐一測試，取第一個可用的；存資料的 key 都加 `workout.` 前綴。
- 不支援 CloudKit（沒有 iCloud 同步）。
