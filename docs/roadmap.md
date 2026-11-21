# 待辦清單（健身系統）

最後更新：2026-11-21，版本 0.22.0。做完一項就從這裡刪掉或移到「已完成」，並升版號。
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
- 手機：**iPhone 16 Plus，iOS 27.3**（支援 Apple Intelligence）。

## 下一輪

0.17.0–0.22.0 已完成（見下方「已完成」）。下一步等使用者決定。

## AI 功能的決定（2026-11-21）

- **0.22.0 已做：練完的教練講評**（細節見 `docs/training-system.md`「教練講評」）。等使用者實際用過再調提示詞。
  - 還沒做：每週總結（同樣的作法，資料用部位組數、疲勞地圖、停滯）、看懂備註。
- 原本的規劃（教練講評，Apple Foundation Models，手機上跑）：
  - 訓練結束、每週結束時，寫一段白話講評和下次建議。
  - 數字一律由程式算好再交給模型，模型只負責寫字：PERFECT／GOOD／MISS、PR、停滯、減量週、疲勞地圖、狀態檢查、備註。
  - 用 `@Generable` 讓模型填固定欄位。
  - 只在 iOS 26 以上、支援 Apple Intelligence 的機型開啟（部署目標還是 17.0，用 `#available` 判斷）；
    其他情況或被安全過濾擋下時，改顯示程式產生的固定文字。
  - 使用者是 iPhone 16 Plus，可以用。後來決定不做測試頁，直接接進練完的流程。
  - CI 是 `macos-15` 預設的 Xcode；要用 FoundationModels 得確認或指定 Xcode 26 以上。
- **之後再說：相機數次數／看動作（Apple Vision 姿勢辨識）**。
  - 使用者不想拍身材，所以只能即時分析、不存影像；在家擺手機也不方便。
  - 等使用者主動想要再做。
- **不做**：
  - 雲端模型（Claude／Gemini API）：要 key、要錢、要網路。
  - MediaPipe／MoveNet：Vision 已經夠用，不用另外放模型。
  - OpenPose／YOLO-Pose：授權有限制。
  - wger／free-exercise-db 動作庫：App 已有針對在家器材的中文動作庫和自訂動作。
  - Fitbod 那類自動排課：遞增遞減、停滯偵測、減量週已經做了。

## 之後再說

- **kg／lb 切換**（原排 0.20.0，使用者決定先不做）：器材都是 kg；要做的話只做顯示換算，槓片／換重量清單維持 kg。

## 已完成

- 0.22.0：練完的教練講評（Apple Intelligence，沒有就自動整理）。細節見 `docs/training-system.md`「教練講評」。
- 0.21.0：超級組／循環組（只配單關節、自動分到不同器材、一輪做完才休息、完成 +2 碎片）。細節見 `docs/training-system.md`「超級組」。
- 0.20.0：間歇計時（Tabata／EMOM／AMRAP／自訂，記到歷史但不算牌位）、等長計時、節奏節拍器、
  捷徑／Siri（開始今天的訓練、完成一組）、匯出 CSV。細節見 `docs/training-system.md`「工具」。
- 0.19.0：自訂動作、自訂課表（可存好幾份，和內建分開，選一份來用）。細節見 `docs/training-system.md`「自訂」。
- 0.18.0：每組判定 PERFECT／GOOD／MISS、幽靈模式（和上次同一組比）、訓練前狀態檢查（強制）、動作／訓練備註、
  換重量逐步打勾、休息頁歷史小圖、熱身／Drop set 碎片獎勵、術語白話化＋ⓘ 說明。細節見 `docs/training-system.md`。
  - 超級組相關的成就等做超級組時再加（見「之後再說」）。
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
- `claude/loving-wozniak-c6h4el`：最早版的角色分頁，main 已經重做過角色系統，不用合。
