# 訓練系統

## 課表（`Program.swift`）

新手增肌的上下半身分化，每週 4 天，每個部位一週 2 次。（0.30.0 起每天只有第一個重點動作 +1 組，上半身 B 的二頭、三頭 3→2 組。）

| 天 | 重點 | 動作類型（依序） |
|---|---|---|
| 上半身 A | 胸、背 | 水平推 6–10、垂直拉、上斜推、水平拉、側平舉、三頭、二頭 |
| 下半身 A | 大腿前側、臀 | 深蹲、髖鉸鏈、弓步、腿伸展（健身房）、小腿、核心 |
| 上半身 B | 肩、背、手臂 | 垂直推、水平拉、水平推、垂直拉、側平舉、後肩、二頭、三頭 |
| 下半身 B | 臀、大腿後側 | 髖鉸鏈 6–10、臀推、弓步、腿後彎舉、小腿、核心 |

- 每個動作類型從 `ExerciseLibrary` 依器材挑候選，健身房器材的排前面，在家沒有就自動跳過。
- 有負重的候選優先。同一類動作在另一天也有（例如兩個上半身日都有水平推），B 日用第二順位；
  一週只練一次的用首選。0.23.0 起：**單關節動作**每 6 週（減量週後）互換；**複合動作不再輪替**（見「排課升級」）。
- 「槓鈴要組裝，在家少排槓鈴」（`Keys.limitBarbell`，預設開）：在家時槓鈴動作排到最後，
  只有 `keepBarbell` 的位置（下半身 B 的臀推）仍用槓鈴。使用者的槓鈴是兩個啞鈴接起來的，組裝很麻煩。
- 進步：雙重進步法，每組都做到次數上限才加重；只看「最重那幾組」的正式組。

## 自訂（0.19.0，`Custom/CustomStore.swift`、`Custom/CustomViews.swift`）

- **自訂動作**（`Keys.customExercises`，JSON `[CustomExercise]`）：名稱、動作類型、器材、負重、次數／秒數、
  可選的固定範圍、要點。id 是 `custom_` 開頭，建立後不改；刪除只設 `hidden`，`ExerciseLibrary.byId` 仍找得到
  （舊紀錄、PR 要顯示名字）。`ExerciseLibrary.all` = 內建 + 沒刪的自訂；`builtIn` 是內建。
- `candidates`（自動挑、健身房換動作）只有開了「自動挑動作時也排自訂動作」（`Keys.customInAutoPick`，預設關）
  才包含自訂動作，排在內建後面。
- **自訂課表**（`Keys.customPrograms`，JSON `[CustomProgram]`）：可以存好幾份，和內建分開；
  `Keys.activeProgram` 選一份（空字串＝內建）。刪除只設 `hidden`，正在用的被刪就回到內建。
  - `ProgramBuilder.days` 改成 computed：有可用的自訂課表就用它，否則 `builtInDays`。
    自訂的天 id 是 `c_` + 亂碼，`ProgramBuilder.template(id:)` 會從內建和所有自訂課表（含已刪）找回舊紀錄的那天。
  - 每一格（`CustomSlot`）：指定動作（`exerciseId`）或只指定動作類型（自動挑）、組數、次數範圍、休息秒數、
    精簡版要不要做。指定的動作器材不夠或已刪除 → 同類型自動挑，`PlannedExercise.replaced` 記原本的名字，首頁顯示「代替」。
  - 和內建的差別：組數照填的（不自動 +1）；休息用填的（精簡版最多 60 秒）；自動挑時，前面幾天也有同類型
    自動挑的，就往後換一個候選，各天才不會一樣。適應期／減量週少 1 組、熱身、組數排法、加重建議都照舊。
  - 「複製內建課表」會把內建完整版實際的組數（重點動作 +1）和休息（120／60 秒）寫進去，臀推位置保留 `keepBarbell`。
  - 週任務「上下半身都練」：內建看 dayKey，自訂看那天的動作類型（`DayTemplate.halves`，全身日兩邊都算）。
- 都加進 `SettingsBackup.keys`，重裝會還原。

## 在家／健身房（`TrainingPlace`）

- 在家：`Keys.equipment` 勾的器材。健身房：`Equipment.gym`（全部，包含 `.rack`、`.machine`）。
- 「換動作」只在健身房模式出現：同一個動作類型、今天還沒排到的都能換。

## 組（`SetPlanner.swift`）

- `SetKind`：warmup／work／drop。`SetEntry.kind` 存起來；**只有 work 算進步、破紀錄、牌位、里程碑**。
- 熱身：只排複合動作（有 `MovementPattern.region` 的）。同一區（推／拉／腿）第一個動作：
  槓鈴 空槓×10 → 50%×8 → 70%×5 → 85%×3；啞鈴 50%×10 → 75%×5。之後的動作只做 60%×6。
- 排法 `SetScheme`：固定、遞增（80%→100%，次數由上限到下限）、遞減（每組 −10%、+2 下）、
  Drop set（正式組後 −25%、−45% 各一組，不休息）。自動＝新手期固定；單關節動作在進步期加 Drop set。
  使用者選的存在 `Keys.schemes`。
- 休息：熱身組 45/75 秒；下一組是遞減組就不休息；其他照課表。
- RIR：還剩 4 下以上 → 後面的正式組 +1 級；還剩 0 下又沒做到下限 → −1 級。

## 身體數據（`BodyScreen.swift`）

- `BodyLog`：體重、體脂、肩、胸、上臂、腰、臀、大腿、小腿（0 = 沒量）。
- 身形圖：正面剪影，各部位寬度 = 1 + (現在/第一次 − 1) × 3（限制 0.75–1.35），第一次的輪廓用虛線疊在後面。
  沒量的部位用體重變化估一點點。不拍照。

## 啞鈴與槓片（`WeightKit.swift`、`KitEditorView.swift`）

- 設定 → 我的啞鈴與槓片：每組啞鈴記把手重量、各種槓片片數、能不能接成槓鈴、能不能掛下拉架。
- 預設：Tixteel XT-LITE（把手含鎖頭 2 kg，2.5 kg × 12、1.25 kg × 4）＋舊啞鈴（便宜材質，把手估 0.5 kg、連接桿估 0.3 kg，
  3 kg × 8、2.5 kg × 4、1.25 kg × 4，可接槓鈴、可掛下拉架）。
- 用法：兩手各一支（槓片平分給兩支、左右對稱）、只拿一支（`singleDumbbell` 清單）、槓鈴、下拉架。
- 階梯：第一組器材優先，後面的只補更重的；槓鈴相鄰差 ≥ 2.5 kg、下拉架 ≥ 1.25 kg。
- 加重建議、熱身、遞增／遞減、RIR 調整、± 按鈕都只跳到階梯上的重量，並顯示每邊要裝的片。健身房模式不用階梯。

## 換重量的時間

- 每組器材記：一支拆裝鎖頭幾秒、一片幾秒、組成槓鈴幾秒（Tixteel 快鎖 6／3 秒，舊啞鈴旋轉固定環 15／4 秒、組槓鈴 90 秒）。
- `RigState` 記每組器材現在裝成什麼樣子；完成一組就更新。
- **0.35.0 起換重量不再算進休息倒數**（使用者覺得壓力太大）：做完一組後要算「下一組」（同動作或下一個動作的第一組）要換什麼，
  要換就先進「換重量」狀態：休息頁畫出要拆、要加哪幾片，沒有倒數，中間一個大按鈕「換好了」；按下去才開始休息倒數，
  休息秒數就是課表休息（力竭 +30），不再加換重量秒數。通知、Live Activity 也是按下去才排。換重量秒數只當說明文字（預估訓練時間照算）。
  不需要換重量時行為不變（直接倒數）。換重量中按「跳過」或直接做下一組，當作換好、不休息。
- 換重量是在按「換好了」（或休息結束／按下一組完成）時才當作「換好了」，所以換之前改下一組的重量，換法會跟著重算。
- Drop set（兩手各一支的啞鈴）：用另一組啞鈴，在最後一組正式組前的休息就先裝好，做完直接換手上的啞鈴，不用拆片；只降一次。
  滑輪拔片快，照樣降兩次。
- 熱身改用另一組啞鈴：兩手各一支的啞鈴動作，如果正式組用主要啞鈴、又有另一組啞鈴可以做成一對，熱身組（`SetPlanner.warmups`）
  就指定用另一組（`kit` 欄位，和 Drop set 同一個機制），每一組熱身重量吸附成另一組裝得出來的重量（優先不超過目標、
  都太重就用最輕的、永遠低於正式組）。主要啞鈴只裝一次正式組重量：下一組是最後一個熱身時，休息頁順便列「順便裝好正式組」。
  這場有槓鈴動作時，另一組已經被拿去接槓鈴，熱身就退回用主要啞鈴（`avoidKit`）。單支、槓鈴、滑輪、健身房不受影響。
- 換重量的規則在 `SetPlanner.rigSteps`（休息頁和預估時間共用）。
- 槓鈴：訓練一開始提示「先用舊啞鈴組好槓鈴」，整場只組一次，其他動作用 Tixteel。
- 預估時間（`WorkoutTimeEstimator`，今天頁顯示）：照 `makeDraft` 一樣排好每一組（`SetPlanner.plannedSets`，含熱身），
  依序走一遍並記每組器材的 `RigState`；每組 45 秒、休息 = max(課表休息, 換重量 + 30（熱身 + 20）)，Drop set 不休息但換的時間照算；
  有槓鈴動作就加一次組槓鈴的時間，最後加 5 分鐘緩衝。不含力竭多休息。

## 休息頁（`RestScreen.swift`、`RestAlerts.swift`、小工具的 `RestLiveActivity.swift`）

- 做完一組就蓋滿整個畫面：左邊是自己的角色（喘氣 → 每 18 秒喝一次水 → 最後 3 秒擺準備姿勢），右邊是大圓環倒數（最後 10 秒轉橘、最後 3 秒脈動＋每秒震動和音效，時間到圓環填滿變綠、中間往上數「已經超過幾秒」，下面是橘色「開始下一組」按鈕）。
  左上角可以縮小回底部的小休息卡，點小卡再展開。
- 換重量卡放在最上面（休息一開始就要動手），槓片 0.16.0 放大 1.5 倍。
- 下一組：動作、第幾組、重量和次數（可以直接改）、上次同一組的成績和比較。
- 換重量圖解：每邊的槓片畫成方塊（越重越大，1.25 藍、2.5 綠、3 金、5 橘），上排是現在、要拆的打叉，下排是換好的、新加的發亮。
- 動作要點：動作本身的提示＋同一類動作通用的 1–2 句（`ExerciseCues`）。
- 休息時間：正式組選「還剩 0 下」（力竭）多休息 30 秒；休息頁會寫出為什麼休息比較久。
- 背景：休息開始時排一個本地通知（`rest-end`），結束或跳過就取消；App 在前景時不跳。
  訓練提醒重排時只清 `train-` 開頭的通知，不會把休息通知清掉。
- 鎖定畫面／動態島：Live Activity 顯示倒數、下一組、要換的重量；休息結束、離開訓練時關掉。
- 守時連擊（0.16.0）：休息結束後 15 秒內離開休息頁（按「下一組」或提早跳過）＝連擊 +1；沒按就直接做完下一組，再多給 75 秒。
  超過就歸零。連擊 2 以上跳「COMBO ×N」（5、10 以上更華麗）。整場休息 3 次以上：九成準時 +6 碎片、七成 +3，
  在完成畫面顯示最高連擊、準時次數和碎片。連擊不存檔，只在這一場。


## 訓練中的回饋（0.18.0，`Training/SetFeedback.swift`）

- **每組判定**（只判正式組）：做到這組的目標次數（`SetDraft.target`，排課表時的次數）而且還剩 1～2 下 = PERFECT；
  達到次數下限 = GOOD（力竭、太輕也只有 GOOD）；沒達下限 = MISS。**沒填「還剩幾下」不能拿 PERFECT**（使用者決定）。
  動畫 `GradeBurstView`（`WorkoutFX.swift`），預覽 `scripts/art/grade-anim.html`，兩邊公式一一對應。有破紀錄時只播破紀錄。
- **幽靈模式**：第 n 個正式組比上次第 n 個（上次比較少就比最後一組）。同重量比次數，不同重量比推估最大力量（e1RM）。
  輸入時在動作卡即時顯示，做完後休息頁顯示「剛剛這組」。
- **訓練前狀態**：睡眠、痠痛、精神各 1–5（都是越高越好），**強制回答**（使用者決定），答完才排課表。
  總分 ≤5 每個動作少 1 組＋重量降一級；≤8 少 1 組；≥13 只提醒可以多做 1 下，不自動加重
  （器材最小級距 2.5 kg，百分比調整多半等於 0，所以改成調組數）。存在 `WorkoutSession.readiness`。
- **備註**：`WorkoutSession.note`（這次訓練）、`exerciseNotes`（JSON，每個動作）。下次做同一個動作時顯示上次的備註；歷史頁看得到。
- **休息頁**：換重量改成逐步打勾（先組裝／拆，再拆外面的，最後由重到輕裝上）；下一個動作最近 8 次的推估最大力量小圖。
- **任務獎勵**：熱身全部做完每個動作 +1 碎片（最多 3）；做完 Drop set 每個動作 +2（最多 4）。成果畫面顯示 PERFECT／GOOD／MISS 次數。
- **術語說明**：使用者是新手，畫面用白話（「還能再做幾下？」「推估最大力量」「個人紀錄」），術語旁邊放 `InfoTip`（ⓘ），
  說明文字在 `Glossary`。新增術語時一起加說明。

## 工具（0.20.0，`Tools/`）

- **提示音／震動**（`Cue.swift`）：程式產生的正弦波 WAV，音訊用 `.playback` + `.mixWithOthers`
  （靜音開關也聽得到、不打斷音樂）。tick（輕）、count（3-2-1）、go（開始）、rest（低音）、done（三連音）。
  背景提醒用 `ToolAlerts`（本機通知，id 前綴區分）。
- **間歇計時**（`IntervalTimer.swift`、`IntervalScreen.swift`）：今天頁「間歇計時」進入。
  Tabata（20/10 × 8，可改回合）、EMOM（每輪秒數 × 輪數）、AMRAP（限時，按「+1 輪」）、自訂（做／休／回合）。
  先倒數 10 秒準備。用開始時間＋暫停累計算目前階段，切背景回來直接跳到正確位置（`resync` 不補播聲音）；
  開始時把每段的開始時間排成通知（上限 50 則）。每種類型的設定記在 `Keys.intervalSetups`。
  做了 10 秒以上才存 `IntervalLog`（SwiftData，**和 WorkoutSession 分開**，所以不算牌位、週任務、連續天數）；
  歷史頁另一區顯示，可刪。
- **等長計時**（`HoldTimer.swift`）：以秒計的動作（`unit == .seconds`）在「這一組」裡有「開始計時」：
  倒數 3、2、1 → 往上數（每 10 秒輕滴、目標前 3 秒倒數）→ 到目標 done 音＋震動，可以繼續撐 →
  「放下」把秒數填進這組（還是要按「完成這一組」）。鎖屏時到目標會有通知。
- **節拍器**（`Metronome.swift`，`TempoBar`）：以次數計的動作在「這一組」裡，預設關，按 ▶︎ 開始。
  節奏「放-停-起」秒數，例如 3-1-1；先倒數 3 秒，之後循環：慢慢放（低音）、停住（輕滴）、用力（高音），
  放和停的每一秒輕滴，顯示第幾下。每個動作記住上次的節奏（`Keys.tempos`），預設 3-1-1。這組做完（編輯器消失）自動停。
- **捷徑／Siri**（`WorkoutIntents.swift`）：`StartTodayWorkoutIntent`（開 App → 切到今天頁 → 開今天的訓練，
  長度用今天排程的，沒排就用目前選的）、`CompleteSetIntent`（不開 App；訓練畫面開著時用目前這組預定的重量／次數
  完成，直接排休息通知和 Live Activity，Siri 回「啞鈴臥推 12.5 公斤 10 下，完成。休息 90 秒」）。
  橋接用 `AppCommands.shared`。語句在 `zh-Hant.lproj/AppShortcuts.strings`；專案開發語言設成 zh-Hant。
- **匯出 CSV**（`CSVExport.swift`）：設定 →「資料」→ 匯出。每組紀錄、身體數據各一檔（有間歇紀錄多一檔），
  UTF-8 BOM＋CRLF，重量 kg。用系統分享選單。
- kg／lb 切換沒做（見 roadmap「之後再說」）。

## 超級組／循環組（0.21.0，`Training/Superset.swift`）

- 2 個動作輪流做＝超級組，3–4 個＝循環組。**只配單關節**（`MovementPattern.region == nil`），複合動作不配。
  主要是省時間，不會長得比較快（Glossary `.superset` 有寫）。
- 來源：內建課表看設定「單關節動作配成超級組」（`Keys.autoSuperset`，預設關，相鄰的兩兩一組）；
  自訂課表每格 `CustomSlot.linkPrev`（和上一格連，中間的格子沒排到就不連）；訓練中卡片之間按「連成／拆開」
  （兩個都還沒做任何一組才能改）。分組存在 `PlannedExercise.group`，由 `ProgramBuilder.plan` 最後排。
- 器材（`Superset.separateKits`，在家才做）：同組裡第二個用到同一組器材的動作，依序
  ①改用另一組啞鈴（`PlannedExercise.kit`，`WeightLadder.make(item)` 只用那組；接成槓鈴的那組不用）
  ②換成同類型、器材沒被占的動作，沒有就換徒手的（自訂課表指定的動作不換）
  ③分不開就標 `sharedKit`，卡片和今天頁寫「每輪要換重量」。
- 順序（`Superset.order`，訓練和預估時間共用）：A1 B1 A2 B2⋯⋯，Drop set 跟著它前面那組。
  輪內換動作不休息（要換重量就先進「換重量」狀態，按「換好了」直接做下一個動作，沒有倒數）；一輪最後一個做完才休息，休息用同組最長的，
  休息時順便把同組其他動作下一輪的重量裝好（`rigSteps(also:)`）。
- 在超級組裡，排法「自動」不排 Drop set（另一組啞鈴可能被同組動作用）。
- 任務獎勵：每個超級組／循環組的正式組全部做完 +2 碎片（最多 4）。

## 教練講評（0.22.0，`Training/CoachReview.swift`）

- 練完的成果畫面按「好」之後，多一頁「教練講評」：一句總評、做得好、下次。
- **數字一律由程式算**：`WorkoutView.coachFacts` 整理每個動作的正式組、判定、和上次比、PR、停滯重爬、
  下次預計（直接呼叫 `Progression.suggest`，拿這次的組當「上次」）、備註、練前狀態。
- **有 Apple Intelligence**（iOS 26 以上、支援的機型、已開啟）：用 FoundationModels 寫成白話，`@Generable` 固定三個欄位。
  寫出來的字會檢查：數字必須都出現在資料裡、不能有常見簡體字、總長 220 字以內；不合格重試一次，再不行改用自動整理。
- **沒有 AI**：`Coach.basic` 用規則組出同樣三段，右上角標「自動整理」，並提示怎麼開啟 Apple Intelligence。
- `CoachLoader` 在按下「完成訓練」時就開始產生，看成果動畫的幾秒剛好用來等模型。
- 編譯：workflow 會選 Xcode 26 以上；`project.yml` 用 `-weak_framework FoundationModels`，
  workflow 打包後用 `otool` 檢查是弱連結，避免 iOS 17–25 一開就閃退。

## 看懂備註（0.37.0，`Training/NoteReader.swift`）

規格和理由見 `docs/note-reader.md`；這裡只記實作重點。

- **原則**：模型（或規則）只把備註分類成 `NoteFinding`，怎麼調整由程式決定，**使用者按了才生效**，不按什麼都不改。
- **四種情況**：疼痛（`pain`，可帶關節）、太輕／太重（`tooLight`／`tooHeavy`，只給有重量的動作）、左右差（`sideWeak`）、器材姿勢（`gear`，摘要 ≤ 20 字）。
- **兩條路**：有 Apple Intelligence 就用 `@Generable` 讓模型填 findings（字串欄位，回來逐筆驗證：id 要在今天清單、列舉值合法、摘要 ≤ 20 字且沒有簡體字，不合格的丟掉；
  整批出錯或全部不合格就走規則版）；沒有就用 `NoteReader.rules`（否定先拿掉、關鍵字、左右後面 6 字內有「抖、弱…」）。兩條路的結果都經過 `NoteReader.finalize`（去重、太輕＋太重都不列、已設成同一邊的左右差不列）。
- **什麼時候跑**：按「完成訓練」時和 `CoachLoader` 一起開始（`NoteReaderLoader`）；備註都空就不跑。結果放在教練講評頁最下面的「從備註看到」卡片（`NoteFindingsCard`）。
  - pain：［下次減輕兩成］（`Avoid.logPain`＋nudge `.ease`）／［換掉，之後不排］（`Avoid.mark(.pain)`＋`Avoid.logPain`）。
  - tooLight／tooHeavy：nudge `.up`／`.down`。sideWeak：`SideBalance.set`。gear：存提醒。
- **存放**（`NoteStore`）：`Keys.noteNudges`（`workout.noteNudges`，exerciseId → {kind, date}，21 天沒用到失效，同一動作新的蓋舊的）、
  `Keys.noteReminders`（`workout.noteReminders`，按 ✕ 才刪）。完整備份是整個 UserDefaults 一起存，所以兩個 key 自動跟著備份；舊備份沒有它們，還原後就是空的。
- **下次怎麼用**：`makeDraft` 在 `Progression.suggest` 之後呼叫 `NoteNudges.apply`：`.ease` 每組 `ladder.snap(w × 0.8)` 並設 `eased = true`（不當下次加重基準）、
  `.up`／`.down` 用 `ladder.up`／`down`，建議文字前面加一句原因；徒手或重量 0 不套用；熱身組不動。存檔時有做到正式組的動作，它的 nudge 刪掉。
  有提醒的動作，動作卡「上次備註」上面多一行橘色提醒＋✕。
- 0.37.1：規則版先排除「痠痛」「酸痛」（練完肌肉的痠不當成會痛）；「痛」「刺痛」「不舒服」「卡卡」照舊。
- 測試：`WorkoutTests/NoteReaderTests.swift`。

## 排課升級（0.23.0）

### ① 每個部位每週組數平衡（`Training/VolumePlan.swift`）

- 部位怎麼算沿用 `MovementPattern.muscles`（主要 1 組、次要半組），和熱圖一致。
  目標：胸、背闊、股四頭、大腿後側、臀、側三角肌、二頭、三頭 每週 10–16 組；後三角肌、小腿、腹肌、前三角肌、斜方肌 下限 6、上限 16；前臂、腹斜肌、下背不管。
- 內建課表 slot 直接調：上半身 A、B 側平舉 3→4 組，上半身 B 後肩 2→3 組。平衡是保險。
- `ProgramBuilder.plan` 在「內建課表 + 完整版」時，用 `rawPlan` 把 4 天都排一次（不遞迴進平衡）、跑 `VolumePlan.balance`、取出這一天
  （`balancedWeek`），所以今天頁、訓練畫面、預估時間看到的組數一致。平衡只改組數，不增減動作。
  1. 因器材沒有而跳過的格子：組數補到同一天、主要部位（係數 1）有重疊的動作（每個動作最多 4 組）。
  2. 進步期：部位低於下限，就在它「主要出力的單關節動作」加組（每個動作最多 4 組、每天最多因平衡加 2 組，輪流加）。
     適應期／減量週不做這一步（本來就刻意少練；`planned()` 的 −1 組規則照舊，平衡在它之後）。
  3. 某天比平衡前多超過 3 組：從「最超過上限的部位」的動作扣，不低於 2 組。
- UI：今天頁「本週預計組數」（點開才算，`WeeklyVolumeCard`，旁邊 ⓘ `Glossary.weeklySets`）；
  自訂課表編輯頁「每週組數」（`VolumeTable`，低於下限或超過 20 組標色並提醒；**不自動改自訂課表**）。
  `ProgramBuilder.weeklyPlans` 給 UI 用。

### ② 跳重太大（`Training/JumpGuard.swift`）

- `Progression.suggest`（進步期、有負重、全部達標、下一級比較重）：用上次最重組的重量 w、次數 r、RIR（沒填當 1）
  Epley：e1RM = w × (1 + (r + rir) / 30)；下一級 next 做到力竭的次數 = 30 × (e1RM / next − 1)；預計次數 pred = floor(…) − 1。
  - pred ≥ 原本下限：照常加重，建議次數 = min(max(pred, 下限), 原本上限)。
  - pred < 下限：① 次數上限延長（單關節最多 25、複合 15；原上限已達就跳過）；② 已在延長上限：多 1 組（最多多 1）；
    ③ 都做了還是 pred < 下限：加重，次數 = max(pred, 5)，暫時次數範圍 [N, 原下限]，直到某次全部組做到原下限才清掉。
- 狀態存在三個 Keys：`Keys.repCeiling` [id: Int]、`Keys.extraSet` [id: Bool]、`Keys.tempRange` [id: [low, high, 決定加重時的重量]]。
  `suggest` 只讀不寫；練完存檔（`WorkoutView.finish` → `JumpGuard.record`）才依這次成績更新，所以建議可重現。
  `ProgramBuilder.planned()` 套用：次數上限用延長後的（「全部達標」也用它判斷）、組數 +1、暫時範圍取代原範圍。`PlannedExercise.base` 記原本的範圍。
  成功加重（pred 夠）會清掉延長和多 1 組。tempRange 的第三個數字用來分辨「剛決定、還沒換新重量」和「已經在新重量上爬」。
- 建議文字旁顯示 ⓘ（`Suggestion.tip`、`Glossary.bigJump`）。

### ③ 會痛／不喜歡、複合動作不輪替（`Training/Avoid.swift`）

- `Keys.avoidExercises`：JSON [id: {reason: pain/dislike, date}]。`ExerciseLibrary.candidates` 排除；`byId` 照找得到。
  自訂課表指定的動作被標記 → 當成器材不夠，自動挑同類型，首頁顯示「代替」。設定 →「不排的動作」可取消。
- 訓練畫面動作卡選單：「會痛…」→ 「這次減輕 20% 試試」（還沒做的組重量 `ladder.snap(w × 0.8)`，寫一筆 `Keys.painLog` JSON [{exerciseId, date}]，不標記）
- 0.32.0：「會痛…」是子選單，先點哪裡痛（肩膀、手肘、下背、膝蓋、髖部，這個動作會用到的排前面；或「說不上來」），
  再選減輕／換掉／只記下來。紀錄多存 `joint`（舊紀錄沒有）。`Joint.recentPain` 有選關節就用選的，沒有才用 `Joint.involved(pattern).first` 推測；
  同關節提醒（`Joint.caution`）看動作會用到的**所有**關節，回報後今天其他卡片馬上更新。測試：`WorkoutTests/PainJointTests.swift`。
  或「換掉並記住」（標記 pain、換成同類型下一個候選）；「不喜歡，換掉」（標記 dislike）。只有這個動作還沒做任何一組才能換，做了就只給減輕。
- 複合動作（`pattern.region != nil`）選動作的順位不加區塊數；單關節照舊。`Keys.patternShift` JSON ["dayId|pattern": Int] 是額外位移。
  停滯卡有「換一個動作」（`ProgramBuilder.shiftExercise`，只有課表自動挑、且還有其他候選時出現）。
- **升級遷移**（`ProgramBuilder.migrateV023`，App 啟動時、`Keys.pinnedV023` 沒設才做一次）：
  已設定過的使用者，對內建課表和所有自訂課表每個「自動挑的複合動作格」，位移 = 目前區塊 % 候選數
  （舊規則 (block + variant) % n、新規則 (variant + shift) % n，差值剛好是 block % n），讓正在練的動作不變。
- 全部新 Keys（`avoidExercises`、`painLog`、`patternShift`、`pinnedV023`、`repCeiling`、`extraSet`、`tempRange`）都加進 `SettingsBackup.keys`。

## 個人組數與每週總結（0.24.0）

### 練完問恢復（`Training/PersonalVolume.swift` 的 `MuscleCheckView`）

- 成果畫面按「好」之後、教練講評之前多一頁。問今天**主要練到**（係數 1、有目標範圍）而且 **10 天內練過**的部位，
  正式組多的在前、最多 4 個：上次練完的痠痛退了沒（早就不痠／剛好退／還在痠）、「關節不舒服」開關。可跳過，沒答的不存。
- 存 `Keys.muscleFeedback` JSON [MuscleFeedback]（muscle、date、recovery −1 = 沒答、joint），最多留 400 筆。

### 區塊檢討（`PersonalVolume.reviewIfNeeded`，今天頁 onAppear）

- 進到新區塊（`ProgramBuilder.block` 變大，`Keys.volumeReviewedBlock` 記做到哪）時，檢討上一個區塊：
  第 max(3, 區塊第 1 週) 週到第 5 週（不含適應期、減量週）。每個區塊只做一次；跳過好幾個區塊只檢討最近的。
- **進步**（`gain`）：每個主要練這個部位的動作，每次訓練取最好的正式組 e1RM = w × (1 + (次數 + RIR) / 30)（RIR 沒填當 1；
  徒手用次數），至少 3 次的動作才算，比「前 2 次平均」和「最後 2 次平均」，依次數加權平均。不到 **2.5%** = 進步慢；沒有可算的動作 = 紀錄太少。
- **恢復**：區間內的回報。會痛 = 減輕重量的「會痛」紀錄（`painLog`）或標記「會痛」1 次以上、或關節不舒服 2 次以上。
  差 = 會痛，或答題 ≥ 2 次且「還在痠」占一半以上；好 = 答題 ≥ 2 次且不差；其他 = 不知道。
- 決定：進步慢＋恢復好 → +1；進步慢＋恢復差 → −1；進步慢＋不知道、進步正常、紀錄太少 → 0。
  +1 = 每次練這個部位多 1 組 = **每週 ±2 組**（`step`），累積在 `Keys.muscleSetAdjust`，範圍 −4～+6；到上下限就不再動並註明。
  結果存 `Keys.volumeReviews` JSON [BlockReview]（最多 12 筆）。
- **套用**：`VolumePlan.balance` 第 4 步（只在進步期、只有內建課表完整版）：在 1–3 步之後，對每個部位加減 |offset| 組，
  輪流分到不同天；加組優先單關節、組數少的（每個動作最多 5 組），減組優先單關節、組數多的（不低於 2 組）。
  自訂課表不自動改，每週總結會寫「要自己調整」。
- 目標範圍：`PersonalVolume.range` = 一般範圍 + offset；「本週預計組數」內建課表用它，部位旁標「你 +2」。

### 每週總結（`Training/WeeklySummary.swift`）

- 今天頁最上面的卡片「第 N 週總結」：上一週有練、或上一週結束了一個區塊，而且 `Keys.weeklySummarySeen` < N 才出現；按「好」才記成看過。
- `WeeklySummary.facts` 算：次數／目標、正式組、分鐘、各部位實際組數（係數同熱圖）和個人目標、不夠／偏多、破紀錄（這週最好 > 以前最好，以前沒做過不算）、
  停滯動作（`Plateau.stalled`，最多 3 個）、練前狀態平均、回報還在痠／關節不舒服的部位、會痛的動作、區塊檢討結果。
- 寫法同教練講評：有 Apple Intelligence 就用 `WeeklyReplyAI`（總評、這週、下週重點），數字檢查用 `Coach.isValid(_:source:maxLength: 260)`；
  沒有就 `WeeklySummary.basic`。組數調整的清單和「這週實際組數」表是程式直接畫的，不經過 AI。

## 不照計畫時怎麼排（0.25.0）

### 第一次做的動作自動試重（`Training/StartWeight.swift`）

- `StartWeight.strength`：每個內建有負重動作的典型 e1RM，以槓鈴臥推 = 1（兩支啞鈴是一支的重量、單支是那一支、滑輪是掛的重量）。
  沒列的（自訂動作、輔助引體向上機）不推估。
- 參考動作（`TrainingHistory.lifts`，各動作最近一次最好正式組的 e1RM，RIR 沒填當 1）：同一個動作類型優先，
  其次主要部位（係數 1）有重疊的，同級取最近做的。估計 = 參考 e1RM × k新 / k參考 × 0.9，
  做到次數上限、還剩 2 下的重量（Epley 反推），`ladder.snap`。建議次數 = 上限；減量週再 ×0.8。找不到參考就重量 0，一樣當試重。
- 試重組（`ExerciseDraft.trial`，沒紀錄、有負重、不是「只做 1 組」）：第一個正式組做完而且填了還剩幾下，
  用這組的 e1RM 把後面每組算成「做到該組目標次數還剩 2 下」的重量（可以跳好幾級，取代一般的 RIR ±1 級）。
- `TrainingHistory.sync(sessions)`：今天頁算 `day`、訓練畫面 `makeDraft` 前呼叫；紀錄筆數、最新一筆、最新一筆組數或日期變了才重算。只放記憶體。

### 停練回來（`Training/Comeback.swift`）

- `Comeback.detect`：最近一次到今天 ≥ 10 天，或最近 42 天內兩次訓練之間 ≥ 10 天（取最近的那段）。請假的日子也算停練。
- 每個動作停練後第一次做：10–20 天 ×0.9、21 天以上 ×0.8（停練前最重的正式組）。減重後那次全部達標 → 下次直接 `snap(停練前重量)`、次數下限。
  `Progression.suggest` 在減量週以外先走這條；`JumpGuard.record` 遇到這種情況不更新跳重狀態。
- 21 天以上：`ProgramBuilder.phase` 在回來第一次訓練起 7 天內回傳適應期（自己按的減量週優先）。
- 練完存檔時 `TrainingHistory.noteFinished` 先把這次做過的動作記成「回來後做過」，教練講評的「下次預計」才對。
- 週數（區塊、減量週）不暫停，照日曆。

### 以週為單位排天、併成全身日（`Training/WeekFit.swift`）

- `ProgramBuilder.nextDay`：這週答應的全身日 → 課表這週還沒練的第一天 → 這週都練完才照上次的下一天輪。
  一週沒練完，下週從第一天開始。週的起點用 `SharedStore.weekStart`。全身日的紀錄（`merge:` 開頭）拆開算練過哪幾天。
- 今天頁卡片（`MergeDayCard`）：今天還沒練、沒請假、沒手動換天，這週能練的天數（今天 + 排程排到的日子）< 課表這週剩下的天，
  就問要不要把剩下的前 (剩下 − 能練 + 1) 天併成今天的全身日。按「併成全身日」存 `Keys.weekMerge`；「不用」或主卡的「改回分開練」存 `Keys.weekMergeDismissed`（這週不再問）。
- 全身日（`WeekFit.merged`）：依序取每天的重點動作，主要部位已經練到就跳過；再補主要部位還沒練到的其他動作
  （側肩、二頭、三頭、後肩、小腿、腹肌的順序）；每格組數 −1（至少 2），最多 9 個動作。
  每格記 `Slot.source`，選動作照原本那天的順位和「換一個動作」位移，所以和原本那天排到同一個動作。不做每週組數平衡。

### 內建 3 天全身（`ProgramBuilder.fullBodyDays`）

- 全身 A：深蹲、水平推、水平拉 + 腿後彎舉、側平舉 4、二頭、小腿。全身 B：髖鉸鏈、垂直推、垂直拉 + 上斜推、弓步、側平舉 4、三頭、小腿。
  全身 C：臀推（少排槓鈴時仍用槓鈴）、上斜推、水平拉 + 深蹲、後肩、三頭、二頭、核心。
- 同一個動作類型在前面的天出現過，就用下一個候選（同自訂課表的規則）。每週組數照樣由 `VolumePlan.balance` 平衡
  （平衡前約：胸 11、背闊 12、股四頭 10、大腿後 9、臀 13、側肩 10、二頭 10、三頭 10、後肩 7、小腿 6、腹 3 組）。
- 選擇：設定 → 訓練課表，`Keys.builtInProgram`（split4／fullBody3）。選內建課表時 `BuiltInProgram.activate()` 把每週目標改成 4／3。
  `ProgramBuilder.builtInDays` 依選擇回傳；`template(id:)` 兩份都找得到。
- 排程（`Planner`）：3 天全身時先挑前後一天都沒排、沒練的日子，不夠再放寬（還是不排連三天）。


## 疲勞與減量時機、升中階（0.26.0）

### 區塊時鐘（`Training/BlockClock.swift`）
- 區塊 = 進步週＋最後 1 週減量。預設 6 週（和以前一樣），**提早**最早在區塊有 3 個進步週之後（第一個區塊前兩週是適應期，不算），
  **延後**到區塊最長 8 週。改過的減量週存 `Keys.deloadOverrides`（區塊 → 第幾週，附開始日；「從第 1 週重新開始」後舊的自動失效）。
- `ProgramBuilder.phase/block`、`PersonalVolume` 的區塊檢討、`review(endingWeek:)` 都改讀 `BlockClock.locate(week:)`，不再用 `週數 ÷ 6`。
- 舊版的 `Keys.deloadUntil`（記錄頁按的減量週）還會讀，新的不再寫。

### 疲勞判斷（`Training/Fatigue.swift`）
- 看最近 14 天，5 個訊號：訓練前狀態最近 4 次平均比前 6 週中位數低 2 分（基準不到 4 筆就看平均 ≤ 8）；
  同動作最近一次和上一次比，同重量第一組的「次數＋還剩幾下」少 2 以上（2 個動作以上、佔比 30%）；
  力竭組（還剩 0 下）佔 35% 以上且比之前多 15 個百分點；練完回報「還在痠」3 次以上且過半；最近有 3 個以上停滯動作（`Plateau`）。
- 0 個＝正常、1 個＝注意、2 個以上＝該減量。
- 今天頁卡片（`DeloadOfferCard`）：進步週、到了可提早的週、該減量 → 問「這週減量／再撐一週」；
  預定的減量週、這週還沒練、疲勞正常、狀態不低於基準、這個區塊的主項過半有進步 → 問「延後 1 週／照原本減量」。
  一週只問一次（`Keys.deloadAskedWeek`）。記錄頁的減量建議也改用這套（`Plateau.startDeload` 改寫區塊時鐘）。

### 升中階（`Training/Graduation.swift`）
- 條件：新手、用內建課表、進步週、至少 12 個有練的週（一週 ≥ 2 次）、減量後至少練到第 3 週、疲勞不高，
  最近 3 週（不早於減量後）練 2 次以上的主項（不輪替的複合動作，`MainLifts`）至少 3 個、六成以上沒超過之前最佳。
- 卡片「升中階／再等等」（再等等 2 週不問）。升級後全螢幕慶祝（光芒、衝擊波、粒子、觸覺；減少動態效果直接顯示結尾；點畫面跳結尾）。
- 中階排法（只對內建課表的主要負重動作）：上下肢 A 日／全身 A 是重日 6–8 下、休息至少 150 秒；B 日是輕日 12–15 下、休息最多 90 秒；
  全身 C 照原本。今天頁動作後面標「重日／輕日」。
- 區塊加組：進步週的區塊第 3–4 週每個部位每週 +2 組、第 5 週起 +4，加在個人組數上（上限仍是 +6），交給 `VolumePlan.balance` 分配。
- 剛換範圍（上次次數離新範圍 3 下以上）：用上次的推估最大力量換算重量（留 2 下，`Graduation.rangeSwitch`）。
- 重日到器材最重：建議改慢速（下放 3 秒、停 1 秒），或按「換一個動作」換單側版本。
- 設定 → 週期 → 排法可以切回新手（`Keys.trainingLevel`）。

## 弱點加強、手臂／肩膀專項期（0.27.0，`Training/Focus.swift`）

使用者家裡沒有量圍度的尺，所以「長得慢」只看重量進步；選幾個部位、加幾組、專項期多長由 Claude 決定。

### 重點部位（`Focus`）
- 可選：胸、背闊、側肩、後肩、二頭、三頭、股四頭、大腿後側、臀、小腿；**最多 2 個**。每個每週 **+2 組**（一週練 2 次 = 每次 +1）。
  存 `Keys.focusMuscles`（rawValue 逗號隔開）。只對內建課表；自訂課表不自動改。
- 分析（`Focus.analyze`）：最近 12 週（不含適應期、不含這週）每個可選部位的 `PersonalVolume.gain`，至少 5 個部位算得出來才比。
  落後 = 進步 ≤ 中位數的一半，**而且**比中位數少 3 個百分點以上；最慢的 2 個。
- 今天頁卡片（`FocusOfferCard`，排在減量、升中階卡片之後，一次一張）：內建課表、進步週、練滿 6 週（一週 ≥ 2 次）、
  有落後而且不全是重點部位、這個區塊還沒問過（`Keys.focusAskedBlock`）。「設為重點」把落後的放前面、補上原本的（最多 2 個）；
  落後的有手臂／肩膀、而且沒排專項期，多一顆「改試手臂／肩膀專項期」。
- 套用：`Focus.offsets(week:)` = `Graduation.offsets`（個人組數＋中階加組）＋重點＋專項期，合計夾在 −4～+8，交給 `VolumePlan.balance` 第 4 步。
  `PersonalVolume.range`、本週預計組數的「你 +N」用 `Focus.displayOffset`（個人組數＋重點＋專項期）。區塊檢討的累積值（`muscleSetAdjust`）不受影響。
- 設定 → 課表與動作 →「重點部位與專項期」（`FocusSettingsView`）：勾重點部位，旁邊顯示各部位 12 週進步和「落後」。

### 手臂／肩膀專項期（`Specialization`）
- 長度：**一個完整區塊**（預設 5 個進步週＋減量週，跟著區塊時鐘提早／延後）。目前區塊是第 2 個以後、還在第 1–2 週就從這個區塊開始，
  否則從下個區塊開始。存 `Keys.specialization` JSON {block, start（開始日，重新開始後失效）, endSeen}。
- 進步週才生效（`Specialization.active`；減量週、適應期照一般排）：
  - `ProgramBuilder.builtInDays` 用 `Specialization.augment` 在核心前加動作：下半身 A 側平舉 3＋二頭 2、下半身 B 後肩 3＋三頭 2；
    全身 A 三頭 2、全身 B 二頭 2、全身 C 側平舉 3。都不是重點動作（精簡版不排）。手臂、肩膀一週練到 4 次。
  - 每週組數：側肩、後肩、二頭、三頭 +2；胸、背闊、股四頭、大腿後側、臀 −2（維持量，總時間差不多）。
  - `template(id:)` 先找 `builtInDays`，所以訓練畫面拿到的是加過動作的那天。選動作的順位照原本課表（`siblingDays` 不含加的格子），原本的動作不會變。
- 今天頁：排好／進行中顯示一行狀態（`SpecializationStatusRow`）；區塊過了顯示 `SpecializationEndCard`：四個部位這段（不含減量週）的進步和前一個區塊比，
  加上其他部位的中位數，按「好」記成看過。建議隔一個區塊以上再開（只寫在說明，不擋）。設定頁可以取消。
- 新 Keys（`focusMuscles`、`focusAskedBlock`、`specialization`）都加進 `SettingsBackup.keys`。

## 左右平衡（0.28.0，`Training/SideBalance.swift`）

使用者左手明顯比較弱（彎舉、肩推左手先抖、先做不動；左手很久以前骨折過，目前不痛）。

- 設定 →「左右平衡」：`Keys.weakSide`（`WeakSide`：none／left／right，預設 none）、`Keys.weakExtra`（加強組，預設開）。
- **單手做**（`SideBalance.oneArmIds`：啞鈴彎舉、錘式彎舉、側平舉、扶柱側平舉、啞鈴肩推、阿諾肩推、單臂划船、反向飛鳥）：
  設了弱邊就改成單手輪流，弱的那手先做，另一手做到一樣的次數就停。重量照原本（每手一支）。
  不放啞鈴過頭三頭伸展（兩手握一顆，改單手重量等於變兩倍）。
  - `SetDraft.oneArm`；訓練畫面標題「單手，先做左手」，`reps`／`rir` 是弱的那手，下面另一手的次數（預設跟弱邊一樣）和還剩幾下。
  - 存檔：`SetEntry.reps`／`rir` 是弱邊，`otherReps`／`otherRir` 是另一手，`side` 記當時設定的弱邊。
    所以加重、PERFECT 判定、紀錄都看弱的那手（雙重進步法：弱的那手做到上限才加重）。
  - 預估時間：單手的正式組每組多算 30 秒。
- **雙手一起做的上半身負重動作**：動作卡提醒「左手先做不動就停，右手不要多做」。
- **加強組**（`SetKind.weak`，標籤「加」）：二頭、側平舉、垂直推，最後多一組只做弱的那手，重量、次數同最後一個正式組，前面休息 45 秒。
  不算正式組（進步、紀錄、每週組數、牌位都不算）。減量週、只做 1 組的日子不排。
- **差幾下**：兩手都填還剩幾下的組，差 = (另一手次數 + 剩幾下) − (弱邊次數 + 剩幾下)。進步頁「左右平衡」卡（`SideBalanceCard`）列每個動作第一次 → 最近一次的平均差。
  差 1 下以內算平衡；所有有資料的動作最近 3 次都 ≤ 1 下 → 卡片問要不要關加強組（「再練一陣子」4 週內不再問，`Keys.weakExtraSnooze`）。單手做法不會自動關。
- 歷史頁顯示「左 8／右 8」，CSV 多兩欄。新 Keys 都在 `SettingsBackup.keys`。

### 自動偵測、手腳分開（0.29.0）

使用者問「要自己判斷強弱再開關嗎」，決定改成 App 自己偵測。
- 弱邊分手、腳兩個設定：`Keys.weakSide`（手，上半身動作）、`Keys.weakLeg`（腳，下半身動作），`Limb.of(ex)` 用 `pattern.isLower` 分。
- `SideBalance.perSideIds`（單臂划船、扶柱／滑輪側平舉、單腳硬舉、分腿蹲、後跨弓步、單腳臀橋、單腳提踵）**不管有沒有設定都兩邊分開記**；
  `oneArmIds`（雙手啞鈴彎舉、側平舉、肩推、反向飛鳥）只有手設了弱邊才改單手。`SideBalance.sided(ex)`。
- 先做弱邊，沒設定就先做左邊（`SideBalance.first`）。`SetEntry.side` 改成「reps 是哪一邊」（0.28.0 存的弱邊剛好就是先做的那邊，相容）。
- 差：`diff(e)` = 右邊能做的 − 左邊能做的（正 = 左弱）。`limbPoints` 每次訓練、每個部位取平均。
- 偵測（`detect`）：最近 3 次有資料的訓練都 ≥ 2 下而且同一邊 → 今天頁 `SideDetectCard` 問「開啟」或「改成另一邊」；
  「先不要」4 週不再問（`Keys.sideSnoozeArm`／`sideSnoozeLeg`）。
- 加強組加上弓步類（`.lunge`），只在該部位設了弱邊時排。關加強組的提示：所有設了弱邊的部位最近 3 次都 ≤ 1 下。



## 大整理（0.30.0）

使用者說「功能做完再實測」，先做一次全面檢查。改動：

### 加重基準不再被減量週拖下來（`Training/SessionPhase.swift`）
- `WorkoutSession.phase` 存當時的週期；舊紀錄用週數＋區塊時鐘推回來（`SessionPhase.of`）。
- `SetEntry.eased`：練前狀態很差降一級、會痛減 20% 的組。
- `Progression.lastSets` 跳過減量週和「全部是 eased」的那次（找不到才退回最近一次）；`Plateau.perfs` 不算減量週和 eased 組；
  `Comeback` 的停練前重量不看減量週；`JumpGuard.record` 全部 eased 時不更新。

### 破紀錄（`Training/PRRule.swift`）
- 重量紀錄（超過以前最高重量）或次數紀錄（用以前最高重量做更多下）。第一次不算，每次每個動作最多 1 個。
- 訓練中特效、牌位、週任務、進步頁的紀錄清單都用同一套。

### 排課
- 自動排法：Drop set 只在升中階後才自動排（新手固定重量）。
- `slotSets`：只有每天第一個重點動作（`isMainSlot`）+1；減量週組數減半（至少 1 組）、重量 ×0.9；適應期照舊 −1。
- 重點動作不排 `ExerciseLibrary.notMain`（單腳硬舉、單腳臀橋、壺鈴擺盪），沒別的才用。
- 單關節動作輪替的候選從 2 個放寬到 4 個（`topChoices` 的寬度）。
- 停練 14 天以上回來的 14 天內，排到的減量週照一般練（`Comeback.restedRecently`）。

### 教練規則（`Training/CoachRules.swift`）
- **起始重量**：沒有任何參考動作時，用體重推（新手槓鈴臥推推估最大力量 ≈ 體重 × 0.5，沒量體重用 60 kg），再走試重組校準。
  體重由身體數據存檔時寫進 `Keys.bodyWeight`。
- **力竭不加重**：全部達標但每組都填「還剩 0 下」，這次同重量（`RIRCheck.grinding`）。
- **還剩幾下校準**：上一組填 ≥ 2 下、同重量這組卻少 3 下以上 → 提醒填少一點（`RIRCheck.hint`）。
- **器材到頂自動升級**（`Upgrade`）：在家啞鈴最重、每個正式組都做到上限 → 記 `Keys.upgrades`，之後排課換成更難的版本，
  今天頁寫「X 到頂了，升級成這個」。路徑：高腳杯／腳跟墊高／啞鈴深蹲 → 1.5 次高腳杯深蹲；啞鈴羅馬尼亞硬舉 → 單腳；啞鈴臀橋 → 啞鈴臀推。
- **關節提醒**（`Joint`）：14 天內某個動作回報會痛，同一個關節（肩、肘、下背、膝、髖）的其他動作在訓練卡上提醒先輕一點。

### 新動作（在家能做）
腳跟墊高高腳杯深蹲、1.5 次高腳杯深蹲、啞鈴登階、啞鈴仰臥拉舉、上斜椅啞鈴彎舉、集中彎舉、啞鈴仰臥三頭伸展、
啞鈴三頭後踢、胸靠椅反向飛鳥、反向捲腹。都有 `StartWeight.strength`、需要的話加進 `perSideIds`／`oneArmIds`／`singleDumbbell`。

### 目標、獎勵
- 週目標、週任務「練滿」、補給箱都算**天數**（同一天練兩次算 1 天，`SharedStore.trainingDays`）。
- 牌位的訓練分同一天只算最高的一次。

### 測試
- `WorkoutTests/`（XcodeGen 的 `WorkoutTests` target），CI 在打包前用模擬器跑，沒過就不發佈。
  涵蓋動作庫資料一致性、破紀錄、組數、加重建議、減量／減輕不當基準、還剩幾下、主項不排單腳。
  改排課邏輯時一起補測試。

## 熱身與伸展跟做、動作示範（0.31.0）

### 跟做流程（`Training/Mobility.swift`、`Training/MobilityFlowView.swift`）
- **練前動態熱身**：訓練畫面最上面一張卡（回答完狀態、還沒做任何一組、沒按略過才出現），按「開始」全螢幕跟做。
  - 依今天的動作模式挑：一定有手臂繞圈、早安式、徒手深蹲；有上半身加手臂開合、頭上推舉伸展、慢速伏地挺身；
    有下半身加交替後跨弓步、前後擺腿（左右各）、臀橋。全身日約 5 分鐘、只練上半身約 3～4 分鐘。
  - 做完按「開始訓練」回到課表。熱身組（`autoWarmup`）照舊，兩者不衝突：這個是關節活動，熱身組是同動作輕重量。
- **練後伸展**：教練講評頁多一顆「練後伸展跟做（約 N 分鐘）」，旁邊「不用，結束」。
  - 只看有做的動作。每個動作模式對應幾個部位（第一個權重 3、第二個 2、第三個 1），挑分數最高的最多 6 個；
    順序固定站著的先、趴下躺下的後（胸→手臂橫拉→三頭→大腿前側→小腿→髖屈肌→體前彎→抱膝→人面獅身→嬰兒式）。
  - 一次 30～40 秒，單側的做「第一邊／換邊 5 秒／第二邊」。
- 計時跟間歇計時同一套做法（`MobilityRun`：開始時間＋暫停累計＋跳段位移），背景回來會對時。
  每段開始有聲音和震動，最後 3 秒倒數。可以暫停、重做這個（3 秒內再按回上一個）、跳過。
  動作之間的準備：熱身 4 秒、伸展 6 秒（要趴下、躺下）。螢幕保持亮著。不記到歷史、不算分。
- 「減少動態效果」開著時角色不動，只顯示起始姿勢。

### 動作示範動畫（`scripts/art/moves.js` → `Character/MoveFrames.swift`）
- 新動作的骨架用**角度**寫（肢體長度固定，不會變形），產生 Swift 檔；`MoveFrames.swift` 不要手改。
  - `node scripts/art/moves.js preview out.png [id,…]`：用 `docs/character-design.html` 的畫法截 5 個時間點。
  - `node scripts/art/moves.js swift`：寫出 `MoveFrames.swift`。
- 骨架升級（`CharacterPose.swift`）：
  - `Joints.farLimb`：遠側的手腳可以另外擺（弓步、單腳站、股四頭伸展）。沒寫就跟以前一樣是近側往後錯開。
  - 多格影格：`loop` 的動作依序繞（手臂繞圈），其他的 0→1→0 來回；每個動作有自己的週期（伸展 5 秒像呼吸）。
  - 道具 `MoveProp`：平椅、身後的椅子、身前的椅子、牆，畫在角色後面。
- 訓練畫面的示範：`CharacterMove.byExercise` 有專屬動作的用專屬的（分腿蹲、後跨弓步、登階、臀推、臥推、地板臥推、
  仰臥三頭、仰臥拉舉、三頭後踢、屈體伏地挺身、反向捲腹、死蟲式、單腳硬舉、俯臥腿彎舉），其他照動作模式。
- 頭和腳掌的方向（0.31.1）：
  - 頭跟著脖子（肩→頭）的方向轉，站直時不轉；頭上的裝備一起轉（`CharacterRenderer.drawHead` 用轉過的 `Pen`）。
  - 仰躺、頭在右邊的動作其實是側面圖左右翻過來的，資料標 `mirror`（`moves.js` 的 `lie()` 自動帶），
    頭和四肢上的裝備會翻面，臉才會朝上。舊的 `.bridge` 也算。
  - 腳掌沒寫角度時自動算：腳踝貼地就平貼地面、腳尖朝大腿（髖→膝）的水平方向（臀橋、臥推朝遠離頭那邊）；懸空就跟小腿垂直、朝身體正面。
    跪姿後腳踮腳尖、屈體伏地挺身、拉腳跟伸展的腳掌另外寫角度。
- 高位下拉（0.31.1）：舊的「下拉」是站著拿啞鈴往頭上舉，像肩推。改成 `latPulldown`：坐在椅子上面向下拉架、身體微後仰，
  握把從頭上拉到上胸。道具 `cableTower`（直柱、上橫桿、滑輪、椅子），鋼索從滑輪 `MoveProp.pulley` 接到手、畫在身體後面，
  握把畫在手上。高位下拉、窄握下拉、彈力帶下拉都用它。其他滑輪動作（三頭下壓、面拉、滑輪划船）還是照動作模式套舊姿勢。
- 滑輪動作（0.31.1）：所有 `cable_` 開頭的動作（加上彈力帶下拉、下壓）都有專屬示範並畫出滑輪架。
  - 道具形狀和滑輪位置寫在 `moves.js` 的 `PROPS`（`pad` 椅墊、`leg` 椅腳、`frame` 架子），產生 `MoveProp`（MoveFrames.swift），
    預覽和 App 用同一份資料。架子：`cableTower`（下拉架＋椅子）、`cableHigh`（站或跪在前）、`cableHighBack`（背對）、
    `cableLow`（低位，健身房）、`cableRow`（坐姿划船）。
  - 動作的 `grip`：`bar` 直槓、`rope` 三頭繩、`handle` D 型把手。鋼索畫在身體後面，握把畫在手上。
  - 單元測試會檢查每個 `cable_` 動作都有滑輪。

## 0.33.0

### 停練時週數暫停（`Training/TrainingPause.swift`）
- 停練滿 14 天起，程式週數停住（前 14 天照常算，當作休息）。暫停一律是 7 的倍數，每週從星期幾開始不變。
- 0.33.1 修正：暫停從第 14 天開始，不回頭扣已經走過的天數（0.33.0 從第 7 天回頭扣，滿 14 天那天週數會往回跳）；
  還沒回來時暫停蓋到這一週結尾（0.33.0 無條件捨去，停練中週數每週在兩週之間來回跳）；回來時取進位，回來後週數停到週界再走，前後連續。
  0.33.0 存的同一次停練紀錄會被換掉。`TrainingPause.current` 字串沒變就不重新解 JSON。
- `Stats.week` 和 `PersonalVolume.weekStart` 都會扣掉暫停，所以區塊時鐘、減量週、區塊檢討、每週總結、疲勞、畢業判斷全部跟著停。
- 停練偵測（`TrainingHistory.refresh` → `Comeback.detect`）時記錄或延長；還沒回來時也會一直延長，所以停練期間週數就是凍住的。
- 存在 `Keys.trainingPauses`，綁開始日（「從第 1 週重新開始」後清掉）。`Comeback.restedRecently`（回來 14 天內不減量）保留。

### 徒手動作進階（`Training/CoachRules.swift` 的 `Upgrade`）
- 徒手動作**連續 2 次**每個正式組都做到次數上限（秒數類如棒式不算）→ 下次換成同類型更難的版本，今天頁寫「升級自」。在健身房也會升級。
  負重（啞鈴到頂）一次就夠。0.33.1 起建議文字和存檔共用 `Upgrade.target`（器材夠、沒避開、還沒升過），不會答應做不到的升級。
- 路線：伏地挺身 → 暫停伏地挺身 → 弓箭手伏地挺身；屈體伏地挺身 → 腳抬高；桌下划船 → 暫停；徒手深蹲 → 慢速；
  後跨弓步 → 保加利亞分腿蹲 → 暫停分腿蹲；單腳臀橋 → 單腳臀推；毛巾腿彎舉 → 單腳；椅子撐體 → 腳抬高；單腳提踵 → 暫停；死蟲式 → 反向捲腹。
- 新動作放在動作庫最後，平常不會被排到，只有升級時出現。`Upgrade.replacement` 會一路換到最後一級排得了的版本。

### 程度評估（`Training/LevelTest.swift`）
- 第一次使用（可略過）或設定 → 訓練 → 程度評估：伏地挺身最多幾下、高腳杯深蹲 10 下用幾公斤、單手啞鈴划船 10 下用幾公斤（還剩 2 下左右）。
- 換算：伏地挺身 ≈ 推起體重 64%，用 Epley 換成臥推 e1RM；另外兩項是 10 下＋還剩 2 下的 e1RM。
- 給 `StartWeight`：當作「做過的動作」參考（真的練過的優先）；完全沒有相關動作時，用各項換成臥推基準的平均取代「體重 × 0.5」。

### 下半身 A 減量
- 弓步改成輔助 2 組（不在精簡版）。每週組數：股四頭 11、臀 13、大腿後側 10.5，仍在 10–16（有測試）。

### 增肌飲食（`Training/Nutrition.swift`，身體頁最上面）
- 蛋白質：點常見份量（肉魚 25、乳清 22、蛋 7、牛奶 8、豆漿 9、豆腐 10、希臘優格 12 g）或自己填，目標體重 × 1.6 g。只留 120 天。
- 增重速度：最近 6 週體重的線性回歸斜率（至少 2 筆、相隔 10 天）。每週占體重 <−0.1% 在掉、<0.2% 太慢、≤0.5% 剛好、更多太快。
- 每週總結會帶入增重速度和 7 天平均蛋白質，太慢、太快、蛋白質不到 8 成會寫進「下次」。

### 分享圖卡（`Session/ShareCard.swift`）
- 教練講評右上角的分享鈕：日期、哪一天、總重量（負重動作 重量 × 次數）、正式組、分鐘、徒手總次數、PR、PERFECT／GOOD／MISS、牌位、角色。
- `ImageRenderer` 畫成 3 倍圖，用系統分享選單。

### 動作示範影片（`Session/DemoVideo.swift`）
- 動作卡的示範動畫右下角「看影片」：精選的動作在 App 裡用 youtube-nocookie 嵌入播放；沒有精選的按「找影片」開 YouTube 搜尋。
- 精選清單 `DemoVideos.byExercise`，進階版沿用原本動作的影片（`sameAs`）。挑片原則見 `docs/roadmap.md`。

## 0.33.1

- 停練週數暫停修正（見上面 `TrainingPause`）。
- 程度評估：伏地挺身換算最大力量的次數最多算 15 下（Epley 高次數會高估）；測伏地挺身時要填體重，存進結果也更新 `StartWeight.bodyWeight`；
  三項預設關著、打開才算有做，全部關著不能存。
- 每週總結的增重速度和蛋白質用被總結那一週算（不是打開那天）；蛋白質一起給「記了幾天」，記不到 4 天不拿平均給建議。
- 身體頁蛋白質卡顯示「7 天記了幾天」，回到頁面時重新讀紀錄。
- `DemoVideos.isValidId` 只收 ASCII。

## 0.34.0（穩定版：保護資料、修整體檢查找到的問題）

- **訓練中存檔**（`Session/WorkoutResume.swift`）：每完成一組、App 切到背景時存一份（`Keys.workoutInProgress`）。
  今天頁出現「上次的訓練還沒結束」可以接著練或放棄；超過 12 小時、或一組都沒做完就不問。
  還原時照正常流程排課，再依順序把存的動作和每組成績蓋上去（換過、加練的動作也會還原；超級組的連結不還原）。按「完成」或「放棄」會清掉。
- **完整備份**（`Settings/FullBackup.swift`，設定 › 資料）：訓練紀錄、身體數據、間歇紀錄＋ App 自己的所有 UserDefaults（背包、目標、請假、升級……）
  存成一個 JSON 檔；「從備份還原」會先顯示內容再確認，整組取代。Keychain 的 `SettingsBackup` 只存設定，換憑證也可能讀不回來。
- **刪除紀錄收回**（`Session/SessionGrants.swift`）：練完記下這次發的碎片和動作升級，在紀錄頁刪掉那一筆就扣回碎片、退回升級（只退還是這次記的那一條）。
  牌位、補給箱數量是從紀錄算的，刪掉自動重算。
- 「完成」不能重複按（成果畫面淡入時連點會存兩筆）。
- 停練暫停的寫入延到畫面算完之後，今天頁用 `@AppStorage` 看著它重畫。
- 小工具的連續週數改算天數（同一天練兩次算 1 天），和 App 一致；`SharedStore.calendar` 每次用目前時區。
- 休息結束通知不再設 `.timeSensitive`（沒有那個 entitlement，系統會默默降級）。
- `GoalEngine.facts` 紀錄沒變就用上次的結果（今天頁、分頁紅點、牌位每次重畫都會用到）。
- `SettingsBackup` 2 秒內的變動合併成一次，App 進背景時立刻存；提醒重排不會兩次同時跑。


## 第一次的問卷、雲端備份（0.42.0）

### 問卷（`Onboarding/`）
- `OnboardingView(mode: .first)` 取代舊的引導（介紹 → 器材 → 評估）；設定 → 訓練 →「重新填問卷」用 `mode: .redo`。
  頁面：身體資料 → 訓練經驗 → 每週幾天／每次多久 → 會痛的部位 → 器材 → 程度評估 → 左右平衡 →（雲端備份，網址設定後才有）。
  每頁都有「略過」（那一頁填的都不算）；答案放在 `OnboardingAnswers`，按完成才由 `OnboardingFlow.apply` 一次寫進設定，**每個欄位是 nil 就不動**，所以重填不會清掉東西，也不會動訓練紀錄。
- 身體資料：身高 → `Keys.height`；體重 → 寫一筆 `BodyLog` ＋ `StartWeight.noteBodyWeight`；出生年 → `Keys.birthYear`；性別 → `Keys.sex`（男／女／不想說）。
  `Nutrition.calories` 用 Mifflin-St Jeor × 1.55 估每天消耗，增肌建議再加每週增 0.375% 體重所需的盈餘（約 +250～350）。
  **性別是「不想說」或沒填、或缺身高／年齡，就不顯示大卡數字**，只剩原本的增重速度建議。
- 訓練經驗（`Keys.experience`）：2 年以上直接 `Graduation.setLevel(.intermediate)`；其他維持新手（已經是中階的不會被降回去）。
- 每週幾天：3 天（含以下）→ `BuiltInProgram.fullBody3.activate()`，4 天以上 → `split4`；再把 `Keys.weeklyGoal` 設成選的天數。
  正在用自訂課表時不切課表，只改每週目標。星期用 `OnboardingFlow.suggestedWeekdays`（可自己改）→ `Keys.reminderWeekdays`。
- 每次 30 分鐘以內 → `Keys.defaultLength = short`。**這個設定是 0.42.0 新做的**（之前訓練長度只有今天頁的 `@State` 和排程器自動挑）：
  `WorkoutLength.preferred` 給今天頁的初始值，`Planner` 在偏好精簡時不排完整版。設定 → 訓練 → 預設長度也能改。
- 會痛的部位：選 `Joint`（可複選／都沒有）。`OnboardingFlow.painExerciseIds`：動作類型最吃力的關節（`Joint.of`）是選的那個，
  這類的內建動作用 `Avoid.mark(_, reason: .pain)` 標起來，**但每一類至少留一個現在排得了的（優先不用器材的）**，免得整個部位排不出動作。
  已經標過的不重複標；不寫 `painLog`（不會觸發「最近痛」提醒）。想放回來：設定 → 課表與動作 → 不排的動作。
  注意：標記的時間是問卷當下，第一個區塊的每週回顧（`PersonalVolume.recovery`）會把它算成「痛」。
- 程度評估：划船改成「挑一個重量，左右手各做到還剩 2 下左右，記兩邊次數」。`LevelTest.Result` 加 `rowLeftReps`／`rowRightReps`（optional，舊資料照舊解得開，換算用 10 下）。
  換算最大力量用弱的那手（偏保守）。**兩手差 ≥ 2 下 → `SideBalance.set(較弱那手, .arm)`**（`LevelTestView` 存的時候就設，設定頁單獨做評估也一樣）。
- 左右平衡頁：手、腳各問「沒有／左／右」；這次問卷有實測且差 ≥ 2 下時，手的選項鎖住、畫面說明「已依實測設成 X 手較弱」，自己選的不同就以實測為準。
  再問「以前有沒有受過傷」→ `Keys.injuryNote`（只是備註）。
- 新 Keys：`birthYear`、`sex`、`trainingExperience`、`injuryNote`、`defaultLength`、`questionnaireDate`、`cloudEnabled`，都加進 `SettingsBackup.keys`；
  `FullBackup` 備份整個 UserDefaults，所以自動帶到（只有雲端的同步狀態 `cloudLastSync`／`cloudLastError`／`cloudLastHash` 排除，不然每次同步都會讓內容變動）。

### 加密雲端備份（`Cloud/`、`cloud/worker/`）
- 內容就是 `FullBackup` 的 JSON（沿用匯出／還原，沒有另一份格式）→ zlib 壓縮 → `AES.GCM`（256-bit）加密。
  檔案格式：1 byte 版本 ＋ `combined`（nonce 12 ＋ 密文 ＋ tag 16）；版本號也進 AES 的附加驗證資料。
- 金鑰（32 bytes）和存取 token（32 bytes，送出去是 base64url 43 字元）都在 Keychain（`CloudKeychain`，`AfterFirstUnlockThisDeviceOnly`），不進 UserDefaults、備份檔或 log。
- **恢復碼**（`RecoveryCode`）：版本 1 ＋ 金鑰 32 ＋ token 32 ＋ SHA-256 前 2 bytes 檢查碼 = 67 bytes → Crockford Base32 108 個字，每 6 字一組、18 組。
  輸入時不分大小寫、空白橫線不管、O→0、I／L→1；抄錯會被檢查碼擋下。
  第一次開啟（`CloudSetupView`）要輸入第 1 組和最後一組才能繼續；之後在設定 → 資料 →「查看恢復碼」要先 Face ID／密碼（`LocalAuthentication`，`NSFaceIDUsageDescription` 在 `project.yml`）。
- 換手機：問卷第一頁或設定 → 資料 →「從雲端還原」→ 輸入恢復碼 → 列出雲端最近 5 個版本 → 選一個 → 下載、解密 → 顯示內容（幾次訓練、幾筆身體數據、存的時間）→ 確認後走 `FullBackup.restore`，再用同一把金鑰繼續同步。
- 上傳時機（`CloudSync.scheduleUpload`）：練完按「完成」存檔之後、App 離開前景時，2 秒內合併成一次；上傳前算內容雜湊，和上次一樣就不傳；
  上傳中又有新的就等這次傳完再補一次；切到背景時借一個 background task 讓它做完。失敗默默等下次，設定頁顯示「上次同步：時間」或「失敗：原因」。最後上傳的為準。
- 預設關閉。問卷最後一頁（網址設定後才有）和設定 → 資料都能開關；關掉時金鑰留在 Keychain，再開就不用重抄。
- `CloudConfig.workerURLString` 空字串 = 整個功能隱藏（沒有問卷最後一頁、設定沒有區塊）。
- Worker（`cloud/worker/`，TypeScript，D1）：`PUT /v1/blob`、`GET /v1/blob[?version=N]`、`GET /v1/blob/versions`，`Authorization: Bearer <token>`。
  只存 sha256(token) 當使用者 id；密文單筆上限 5 MB（D1 單列上限 2 MB，所以切成 512 KB 的小塊存）；留最近 5 版；
  頻率限制：每個使用者每分鐘 30 次、每個 IP 每分鐘 60 次（用 D1 的 `rate` 表）；不記錄內容、不 `console.log`、例外一律回 `server_error`。
  `cloud/worker/test/worker.test.ts` 用 Node 內建的 SQLite 假裝 D1 跑了一遍（上傳下載、分塊、保留 5 版、別人讀不到、413、429）。
- 部署：`.github/workflows/deploy-worker.yml`（main 上 `cloud/worker/**` 有變更才跑；沒設 secrets 或 `database_id` 還沒填就只跑型別檢查和測試）。使用者要做的事見 `docs/roadmap.md`。

### 測試
- `WorkoutTests/OnboardingCloudTests.swift`：恢復碼來回／容錯／抄錯偵測、加解密（錯金鑰、被改過）、舊的 `LevelTest.Result` 照舊解得開、划船差 2 下判斷、熱量、年齡、課表對應、標會痛至少留一個動作。
