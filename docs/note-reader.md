# 看懂備註（0.37.0）

使用者 2026-11-24 決定：**先問再改**；抓四種情況：疼痛、太輕／太重、左右差、器材／姿勢問題。
原則和教練講評一樣：**模型只負責分類，怎麼調整由程式決定，按了才生效**。

## 輸入
- 這次訓練每個動作的備註（`ExerciseNotes.decode(session.exerciseNotes)`，exerciseId → 文字）。
- 整次訓練的備註 `session.note`：只有提到今天某個動作的名字時，才算那個動作的；
  沒有指名動作的「左手先抖」這類左右差，可以不綁動作（用 `limb`）。
- 今天做過的動作清單（id、名稱、是否 `loaded`）。

## 輸出：`NoteFinding`
| kind | 欄位 | 條件 |
|---|---|---|
| `pain` | exerciseId、joint?（`Joint`：shoulder／elbow／lowerBack／knee／hip） | 一定要有 exerciseId |
| `tooLight` | exerciseId | 只給 `loaded` 的動作 |
| `tooHeavy` | exerciseId | 只給 `loaded` 的動作 |
| `sideWeak` | limb（arm／leg）、side（left／right）、exerciseId? | 已經設成同一邊弱（`SideBalance.weak(limb) == side`）就不列 |
| `gear` | exerciseId、摘要（≤ 20 字） | 器材、姿勢、調整位置的事，例如「椅子會晃」「握不住」 |

同一個動作同一種 kind 只留一筆。一筆備註可以有多種（「左肩有點痛，重量太輕」→ pain＋tooLight）。

## 兩條路（新檔 `Workout/Training/NoteReader.swift`）
1. **有 Apple Intelligence**（和 `CoachReview` 同一套條件、`#available`、弱連結）：FoundationModels `@Generable` 產生 findings 陣列，
   kind／joint／limb／side 用字串，回來後逐筆驗證：exerciseId 要在今天清單裡、列舉值要合法、摘要 ≤ 20 字且不含常見簡體字（沿用講評的檢查）。
   不合格的那筆丟掉；整批失敗或丟出錯誤就走第 2 條。
2. **規則版 `NoteReader.rules`**（沒有 AI、或 AI 失敗時；要寫單元測試）：
   - 否定先排除：「不痛」「沒痛」「沒有痛」「不會痛」「不重」「不輕」之類的片段先拿掉。
   - pain：`痛|刺痛|不舒服|卡卡`；關節：`肩`→shoulder、`肘`→elbow、`腰|下背`→lowerBack、`膝`→knee、`髖|屁股側`→hip；找不到關節就 nil。
   - tooLight：`太輕|很輕鬆|太簡單|還能加|可以再重`；tooHeavy：`太重|做不動|做不完|撐不住|力竭太早`。兩個都中就都不列。
   - sideWeak：`左` 或 `右` 後面 6 個字內有 `抖|弱|沒力|先沒|做不動|跟不上|比較差`；`手|臂|肩|彎舉|推` → arm，`腳|腿|膝|臀` → leg；
     沒寫部位時，用那個動作的 `Limb.of`；整次備註也沒有動作可推，就不列。
   - gear：`椅|晃|握不住|滑|卡住|槓片|快鎖|鬆掉|角度|調第` → 摘要用備註原文前 20 字。
   - 規則版的 findings 和 AI 版一樣格式。

## 什麼時候跑、在哪裡問
- 和 `CoachLoader` 一起，在按「完成訓練」時開始（備註都空就不跑）。
- **教練講評頁**最下面加一張卡「從備註看到」，每筆一列，寫出動作名＋看到什麼，加按鈕：
  - pain：［下次減輕兩成］［換掉，之後不排］［不用］
    - 下次減輕：`Avoid.logPain(id, joint:)`＋存 nudge `.ease`。
    - 換掉：`Avoid.mark(id, reason: .pain)`＋`Avoid.logPain(id, joint:)`。
  - tooLight：［下次多加一級］［不用］→ nudge `.up`。
  - tooHeavy：［下次少一級］［不用］→ nudge `.down`。
  - sideWeak：［設成{左／右}邊比較弱］［不用］→ `SideBalance.set(side, for: limb)`（和今天頁的左右差詢問接受時做的事一樣）。
  - gear：［下次提醒我］［不用］→ 存提醒。
  - 按完那一列變成一行灰字「已記下：…」，不能再按。全部不按也沒關係，什麼都不改。
- 沒有任何 finding 就不顯示這張卡。卡片右上角和講評一樣標「AI」或「自動整理」。

## 存放（`Keys` 加兩個，值都加 `workout.` 前綴）
- `Keys.noteNudges`：JSON，exerciseId → `{kind: ease|up|down, date}`。**21 天**沒用到就失效。同一動作新的蓋掉舊的。
- `Keys.noteReminders`：JSON，exerciseId → `{text, date}`。使用者在卡片上按 ✕ 才刪。
- 都要進完整備份（`FullBackup`）的匯出／匯入；舊備份沒有這兩欄要能讀。

## 下次訓練怎麼用
- 建這個動作的 draft 時（`Progression.suggest` 之後），有 nudge 就套用一次：
  - `.ease`：每組重量 `ladder.snap(w * 0.8)`、`eased = true`（不當下次加重的基準，沿用 `SessionPhase`），
    建議文字前面加「上次備註說會痛：先減輕約兩成。」
  - `.up`：重量 `ladder.up(w)`，加「上次備註說太輕：多加一級。」；已經是階梯最重就不改，文字改「上次備註說太輕，但已經是器材最重了。」
  - `.down`：重量 `ladder.down(w)`，加「上次備註說太重：少一級。」
  - 徒手（`!loaded`）或重量 0 的不套用。
- 這次訓練**存檔**時，有做到正式組的動作，它的 nudge 刪掉（用過一次就好）；沒做到的留著。
- 有提醒的動作：動作卡最上面一行橘色 `Label`（`exclamationmark.triangle`），文字是提醒，右邊 ✕ 刪掉。放在「上次備註」上面。

## 不做
- 不自動改任何東西。
- 不改左右差的自動偵測公式（`SideBalance.detect`）；備註只是多一個入口讓使用者設弱邊。
- 不另外做備註編輯畫面、不做歷史備註回溯分析。
