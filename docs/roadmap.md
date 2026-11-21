# 待辦清單（健身系統）

最後更新：2026-11-21，版本 0.18.0。做完一項就從這裡刪掉或移到「已完成」，並升版號。
已經做好的設計細節見 `docs/training-system.md`。

## 使用者的情況（排功能時要記得）

- 新手，目標增肌變壯。每週練 4 天，幾乎都在家，很少去健身房。
- 在家器材：
  - **Tixteel XT-LITE 快鎖啞鈴**（主要用）：把手含鎖頭 2 kg，2.5 kg × 12、1.25 kg × 4。
  - **舊的旋轉固定環啞鈴組**：3 kg × 8、2.5 kg × 4、1.25 kg × 4；把手、連接桿是便宜材質，很輕。
    可以接成槓鈴、裝成壺鈴。槓片會掛到下拉架上用。
  - **多功能啞鈴椅＋高位下拉架**（掛槓片），有三頭繩、兩個 D 型把手。
  - 沒有深蹲架、沒有單槓。彈力繩不用。
- **槓鈴是兩支舊啞鈴接起來的，組裝很麻煩**：盡量用啞鈴，槓鈴只留臀推。
- 不想拍自己的身材，身體數據用畫的圖表。

## 下一輪（優先）：使用者要「除了 HealthKit／Watch 全部都做」，分 4 版

0.17.0、0.18.0 已完成（見下方「已完成」）。接著依序做，每版編譯成功就推 main：

### 0.19.0 自訂
- **自訂動作**：名稱、動作類型（MovementPattern，決定部位熱圖）、器材、有沒有負重、次數或秒數。
  `ExerciseLibrary.byId`／`candidates` 要能找到自訂動作（全 App 都靠它查）。
- **自訂課表**：自己排幾天、每天哪些動作（指定動作或指定動作類型）、組數、次數、休息。
  `ProgramBuilder.days` 目前是 static let，改成可切換「內建／自訂」。
- **超級組／循環組**：2–4 個動作同一組號，輪流做，最後一個做完才休息；WorkoutView 的 nextSet／休息邏輯要跟著改。

### 0.20.0 工具
- **間歇計時**：EMOM、Tabata、AMRAP；等長動作計時（棒式，倒數 3、2、1）；節奏節拍器（例如 3-1-1）。
- **捷徑／Siri（App Intents）**：「開始今天的訓練」「完成一組」。
- **匯出 CSV**、kg／lb 切換（顯示換算，存檔一律 kg）。

## 已完成

- 0.18.0：每組判定 PERFECT／GOOD／MISS、幽靈模式（和上次同一組比）、訓練前狀態檢查（強制）、動作／訓練備註、
  換重量逐步打勾、休息頁歷史小圖、熱身／Drop set 碎片獎勵、術語白話化＋ⓘ 說明。細節見 `docs/training-system.md`。
  - 超級組相關的成就等 0.19.0 做超級組時再加。
- 0.17.0：PR 頁（`Training/RecordsScreen.swift`、`Records.swift`）、部位每週組數熱圖、疲勞地圖
  （`Training/MuscleMapView.swift`、`Muscles.swift`，人體圖 `scripts/art/muscles.js` → `Art/MuscleArt.swift`，
  身形圖也改用它）、停滯偵測＋自動減量週（`Training/Plateau.swift`，`ProgramBuilder.phase` 會看減量週）、
  熱身改用另一組啞鈴、預估時間算換重量和組槓鈴（`SetPlanner.plannedSets`、`WorkoutTimeEstimator`）。
- 人體圖的畫法：四肢沿骨頭方向用 (u, v) 座標畫，肌肉裁切在身體裡；比例由 `fixY`／`fix` 統一校正
  （頭 1/8、胯下在一半、身體寬度 ×0.86、腿 ×0.9）。使用者已確認這版比例，改之前先截預覽給他看。

## 要先確認才能做

- **Apple 健康（HealthKit）、Apple Watch**：要先測 FlareStore 憑證支不支援 HealthKit entitlement、
  未簽名 IPA 用 Feather 能不能裝 Watch App。先做小測試版，不要直接承諾。
- 不支援 CloudKit，所以沒有 iCloud 同步；換手機靠匯出／匯入。

## 還沒合進 main 的分支

- `claude/fitness-app-design-style-yohbte`：拳手生涯模式。0.14.0 已挑出請假、保護卡、週任務、押注、逆轉、
  影子對手、總重量、狀態、屬性改接進牌位和角色系統（見 `docs/goals-system.md`）；其餘（XP、等級、排名、獎金、
  選手裝備、掉落、腰帶、6 週訓練營）不要。分支可以刪。
- `claude/amazing-curie-55u0ey`：舊版 App 圖示，main 已經有更新的，不用合。
