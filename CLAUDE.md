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
- **每次推送有功能或介面變更，都要升 `project.yml` 的 `MARKETING_VERSION`**（使用者靠它辨認版本）：新功能／改版升次版本（0.5.0 → 0.6.0），小修正升修訂號（0.5.0 → 0.5.1）。回報時寫成「0.5.0（build 號）」。
- **推不推 main 由 Claude 自己判斷，不用問**（使用者已授權）。新的 session 是從 main 開始的，
  沒合進 main 的改動，下一次做新功能時就讀不到（之前發生過好幾個分支的工作都沒進 main）。
  - **要推**：改動已完成，而且①這個版本在 GitHub Actions 編譯成功，或②只改文件／說明（`[skip ci]`）。
    使用者說「好」「就用這個」「正式」之類的定案話，也算完成。
  - **先不推**：還在試做、等使用者看預覽決定；編譯失敗或還沒編完；使用者明說先不要。
  - 推的方法：先 `git fetch origin main`，確認能快轉（main 是 HEAD 的祖先）再 `git push origin HEAD:main`；
    不能快轉就先停下來，跟使用者說明，不要強推或改寫歷史。
  - **推送後不用等編譯**：可以繼續改、繼續推。workflow 有 `concurrency`，同一分支新的推送會取消還在跑的舊編譯，所以被取消（cancelled）不算失敗；要推 main 前，看該分支**最新 commit** 那一輪有沒有成功（`gh run list --branch <分支> -L 3`）。
  - 每次推完或決定不推，都在回報裡用一句話說明（例如「已推上 main」或「試做中，先不推 main」）。
  - session 一開始，先檢查有沒有比 main 新、但還沒合進去的 `claude/*` 分支，有的話告訴使用者。
- App 圖示：`Workout/Assets.xcassets/AppIcon.appiconset/AppIcon.png`，由 `scripts/make_icon.py` 產生（1024px、不透明），同一張也傳給 Feather 來源的 `icon:`。

## FlareStore 憑證能力
完整清單見共用說明：https://github.com/mrhaibaoseal-lang/feather-source/blob/main/CLAUDE.md

- App Groups 只有 `group.81c139ae9a27a7f8.1` ～ `.5` 這 5 個固定 ID。本專案的 entitlements 寫 `.1`，
  `Shared/SharedStore.swift` 執行時逐一測試，取第一個可用的；存資料的 key 都加 `workout.` 前綴。
- 不支援 CloudKit（沒有 iCloud 同步）。

## 角色、裝備、牌位的美術規定
- **不能只換顏色**：每件裝備、每個牌位都要有自己的外形，輪廓、配件、紋路至少一項明顯不同。
  判斷方式：把它改成灰階，還認得出是哪一件。
- **一眼看得出是什麼**：啞鈴要看得到兩頭和握把，披風、手套、鞋子也要有各自的樣子。
  小尺寸也要分得出來（牌位 44pt、角色卡片）。
- **同部位不撞形**：同一個部位，各系列的造型不能重複。新增系列前先看預覽，對照現有的造型。
- **越稀有越華麗**：稀有度和牌位越高，裝飾要越多、輪廓越大，不能只是顏色更亮。
- **要有新意**：每個系列要有主題感（例如冰霜＝冰刀鞋、冰柱披風；王者＝拳擊手套、冠軍腰帶），不要套同一個模板。
- **原創**：不模仿任何遊戲或品牌的圖示（例如特定遊戲的牌位圖、運動品牌標誌）。
- **流程**：
  1. 改 `scripts/art/gear.js`、`scripts/art/badges.js` 的形狀資料。
  2. 跑預覽截圖，自己檢查：裝備看 3 個動作，牌位看各尺寸。
  3. 產生 Swift 檔。
  4. 把預覽圖傳給使用者，再推送。
  - 產生的 `GearArt.swift`、`RankBadgeArt.swift` 不要手改。
  - 詳見 `docs/character-system.md`、`docs/rank-system.md`。
- **動畫**：手遊感、要豐富（粒子、光芒、衝擊波、觸覺節奏）。牌位動畫的公式在 `BadgeMotion.swift` 和 `scripts/art/badge-anim.js`
  各一份，改一邊要改另一邊；先用預覽 HTML 截幾個時間點檢查，再推送。都要支援「減少動態效果」和點畫面跳到結尾。

## 健身系統

- **還沒做的功能、使用者的器材和情況，記在 `docs/roadmap.md`**。開始做健身相關功能前先讀；做完一項就更新它。
- 3D 外包（Antigravity / Gemini）的規範：`docs/art/BLENDER_BRIEF.md`（入口 `AGENTS.md`、`GEMINI.md`）。
- 已經做好的設計（課表、在家／健身房、熱身、遞增遞減、啞鈴槓片、換重量時間）見 `docs/training-system.md`。
