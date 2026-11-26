# 練壯 美術需求單（給 Antigravity）

> 這份文件是給 Antigravity 的 agent 讀的。**只產生圖檔，不要改任何程式碼。**

## 0. 規則（一定要遵守）

1. **只能新增檔案到 `Art/` 資料夾**。不要修改 `Workout/`、`WorkoutWidget/`、`Shared/`、`project.yml`、`.github/` 裡的任何東西，也不要建立 `.xcassets`（整合由另一個流程負責）。
2. 檔名、尺寸**完全照表**，全部小寫 PNG、sRGB。
3. 圖裡**不能有任何文字、數字、字母、商標**（包括 T 恤、器材上的字）。
4. 不能模仿任何現有品牌、App、遊戲或角色的樣子。
5. 同一類圖要**風格一致**：先做 1 張樣板給使用者確認，確認後再批次產生其餘。
6. 每做完一批就 `git add Art/` 並 commit，commit 訊息結尾加 `[skip ci]`（避免觸發 iOS 打包）。

## 1. App 是什麼

「練壯」是在**家裡**用自己的器材（啞鈴、槓鈴、彈力帶、單槓、壺鈴、滑輪繩索、健身椅）練肌肉的 iPhone App。
目標使用者是課業、打工很忙的學生：重點是「不用完美，有練就好、絕不連續漏兩次」。
氣氛：**溫暖、鼓勵、不嚇人**，不是健身房猛男風。

## 2. 統一風格（Style Guide）

| 項目 | 規格 |
|---|---|
| 畫風 | 扁平向量插畫（flat vector），圓角、粗細一致的線條，少量柔和陰影，不要寫實、不要 3D、不要漸層過多 |
| 主色 | 活力橘 `#FF6B35` |
| 輔色 | 深藍灰 `#1F2A44`、暖米白 `#FFF4EC`、柔綠 `#3DBE8B`（完成／成功） |
| 人物 | 同一個角色貫穿全部圖：中性、短髮、深藍灰上衣＋橘色褲子、**臉部極簡（無五官或只有簡單點）**、比例自然不誇張 |
| 背景 | 動作圖與插圖：**純色 `#FFF4EC` 圓角方塊背景**（不要透明，App 會直接放在卡片上），不要畫房間場景 |
| 構圖 | 主體置中，四周留 10% 安全邊距 |

**通用英文風格咒語**（每個 prompt 後面都接這段）：

```
flat vector illustration, clean rounded shapes, consistent line weight, minimal soft shadows,
limited palette: vivid orange #FF6B35, dark slate blue #1F2A44, warm off-white #FFF4EC, soft green #3DBE8B,
one gender-neutral character with short hair, dark slate top and orange pants, minimal faceless features,
plain solid #FFF4EC background, centered, 10% margin, no text, no letters, no numbers, no logos, no watermark
```

## 3. 交付清單

### 3-1. App 圖示（最優先）

| 檔名 | 尺寸 | 說明 |
|---|---|---|
| `Art/icon/app_icon.png` | 1024×1024 | 一般模式。**不要自己切圓角**（iOS 會自動加），填滿整張、不透明 |
| `Art/icon/app_icon_dark.png` | 1024×1024 | 深色模式版：背景改深色 `#1F2A44`，圖形保持橘色 |
| `Art/icon/app_icon_tinted.png` | 1024×1024 | 著色模式版：**純灰階**，黑色背景＋白／灰圖形 |

Prompt：
```
iOS app icon, a single bold simplified dumbbell combined with an upward flame or upward arrow shape,
symbol of steady progress, centered, fills about 60% of the canvas, solid vivid orange #FF6B35 background,
symbol in warm off-white #FFF4EC with subtle dark slate #1F2A44 accents, flat vector, no gradient noise,
no text, no letters, square full-bleed, no rounded corners, no border
```
要求：縮到 60×60 還看得出是什麼。先出 3～4 個方向讓使用者挑。

### 3-2. 空狀態與情境插圖

全部 1024×1024，`Art/scenes/`：

| 檔名 | 用在哪 | Prompt 主體（後接通用咒語） |
|---|---|---|
| `empty_history.png` | 還沒有任何訓練紀錄 | the character standing beside a single dumbbell on the floor, looking curious and ready to start |
| `empty_progress.png` | 進步頁還沒資料 | the character next to a small empty line chart with one tiny upward step, optimistic |
| `done_today.png` | 今天練完了 | the character relaxing with a towel around the neck and a water bottle, a small green check mark badge nearby |
| `rest_day.png` | 今天休息日 | the character sleeping peacefully on a cushion, a small crescent moon, calm |
| `missed_nudge.png` | 上次漏練，鼓勵只做 1 組 | the character doing a single easy push-up with a friendly encouraging vibe, small spark shapes |
| `streak.png` | 連續 N 週 | the character holding a small orange flame like a torch, proud but humble |
| `onboarding_equipment.png` | 第一次開啟：選器材 | a neat flat-lay of home gym equipment: pair of dumbbells, barbell, resistance band, kettlebell, pull-up bar, adjustable bench, no character |
| `onboarding_schedule.png` | 第一次開啟：自動排程 | the character holding a phone, a simple weekly calendar grid floating beside with some cells highlighted orange |

### 3-3. 動作示範圖（57 張，量最大）

- 尺寸 1024×1024，`Art/exercises/<id>.png`，**`<id>` 必須和下表一模一樣**。
- 畫的是動作**最關鍵的那一瞬間**（通常是用力位置），側面或 3/4 側面，讓人看得出姿勢。
- 器材要畫對（啞鈴就是啞鈴、彈力帶就是彈力帶）。
- 每張 prompt 格式：
  ```
  exercise demonstration: <英文動作描述>. side view, the character mid-movement showing correct form,
  equipment drawn accurately. + 通用咒語
  ```
- **先做 `goblet_squat` 當樣板**，使用者確認後再做其餘。

| id | 中文 | 英文動作描述（給 prompt 用） |
|---|---|---|
| db_bench | 啞鈴臥推 | dumbbell bench press lying on a flat bench, dumbbells pressed up over the chest |
| db_incline_press | 啞鈴上斜臥推 | incline dumbbell press on a bench set to about 30 degrees |
| bb_floor_press | 槓鈴地板臥推 | barbell floor press lying on the floor, elbows touching the floor |
| db_floor_press | 啞鈴地板臥推 | dumbbell floor press lying on the floor |
| pushup | 伏地挺身 | standard push-up, body in a straight line, chest near the floor |
| decline_pushup | 腳抬高伏地挺身 | decline push-up with feet raised on a chair |
| db_shoulder_press | 啞鈴肩推 | standing dumbbell overhead shoulder press, arms extended |
| db_arnold | 阿諾肩推 | Arnold press, dumbbells rotating from palms-facing-self to palms-forward |
| band_press | 彈力帶肩推 | resistance band overhead press, standing on the band |
| pike_pushup | 屈體伏地挺身 | pike push-up, hips high in an inverted V, head toward the floor |
| db_row | 單臂啞鈴划船 | single-arm dumbbell row, one knee and hand on a bench, flat back |
| db_chest_row | 啞鈴俯臥划船 | chest-supported dumbbell row, lying face down on an inclined bench |
| bb_row | 槓鈴俯身划船 | bent-over barbell row, torso about 45 degrees, bar pulled to the navel |
| band_row | 彈力帶划船 | seated resistance band row, elbows pulled back close to the body |
| cable_pulldown | 高位下拉 | wide-grip cable lat pulldown, bar pulled to the upper chest |
| cable_close_pulldown | 窄握下拉 | close-grip cable pulldown with two handles, elbows down to the sides |
| pullup | 引體向上 | overhand pull-up on a doorway pull-up bar, chin over the bar |
| chinup | 反手引體向上 | underhand chin-up, palms facing the body, chin over the bar |
| band_pulldown | 彈力帶下拉 | resistance band lat pulldown, band anchored high |
| prone_ytw | 俯臥 Y-T-W | lying face down on the floor, arms raised in a Y shape |
| goblet_squat | 高腳杯深蹲 | goblet squat holding one dumbbell at the chest, thighs parallel to the floor |
| db_squat | 啞鈴深蹲 | squat holding two dumbbells at the sides, chest up |
| squat | 徒手深蹲 | bodyweight squat, arms forward for balance |
| bb_rdl | 槓鈴羅馬尼亞硬舉 | barbell Romanian deadlift, hips pushed back, flat back, bar near the shins |
| db_rdl | 啞鈴羅馬尼亞硬舉 | dumbbell Romanian deadlift, hips back, flat back |
| kb_swing | 壺鈴擺盪 | kettlebell swing at the top, kettlebell at chest height, hips fully extended |
| sl_rdl | 單腳羅馬尼亞硬舉 | single-leg Romanian deadlift, torso parallel to the floor, back leg extended |
| db_split_squat | 啞鈴保加利亞分腿蹲 | Bulgarian split squat holding dumbbells, rear foot on a bench |
| db_reverse_lunge | 啞鈴後跨弓步 | reverse lunge holding dumbbells, back knee near the floor |
| split_squat | 保加利亞分腿蹲 | bodyweight Bulgarian split squat, rear foot on a chair |
| reverse_lunge | 後跨弓步 | bodyweight reverse lunge, torso upright |
| bb_hip_thrust | 槓鈴臀推 | barbell hip thrust, upper back on a bench, padded bar on the hips, body straight at the top |
| db_hip_thrust | 啞鈴臀推 | dumbbell hip thrust, upper back on a bench, dumbbell on the hips |
| db_glute_bridge | 啞鈴臀橋 | glute bridge on the floor with a dumbbell on the hips, hips raised |
| sl_glute_bridge | 單腳臀橋 | single-leg glute bridge on the floor, one leg extended |
| db_calf_raise | 啞鈴單腳提踵 | single-leg calf raise on a step edge holding a dumbbell, on tiptoe |
| calf_raise | 單腳提踵 | single-leg calf raise on a step edge, on tiptoe |
| bb_curl | 槓鈴彎舉 | standing barbell biceps curl, elbows fixed at the sides |
| db_curl | 啞鈴彎舉 | standing dumbbell biceps curl, palms up |
| db_hammer_curl | 錘式彎舉 | dumbbell hammer curl, palms facing each other |
| band_curl | 彈力帶彎舉 | resistance band biceps curl, standing on the band |
| cable_pushdown | 繩索三頭下壓 | cable triceps pushdown with a rope attachment, rope spread at the bottom |
| cable_overhead_ext | 繩索過頭三頭伸展 | cable overhead triceps extension with a rope, facing away from the pulley |
| db_overhead_ext | 啞鈴過頭三頭伸展 | overhead triceps extension holding one dumbbell with both hands behind the head |
| band_pushdown | 彈力帶三頭下壓 | resistance band triceps pushdown, band anchored high |
| bench_dip | 椅子撐體 | bench dip with hands on the edge of a chair, legs extended |
| db_lateral | 啞鈴側平舉 | dumbbell lateral raise, arms raised to shoulder height |
| band_lateral | 彈力帶側平舉 | resistance band lateral raise, standing on the band |
| cable_face_pull | 繩索面拉 | seated cable face pull with a rope toward the face, elbows flared out |
| db_rear_fly | 啞鈴反向飛鳥 | bent-over dumbbell reverse fly, arms opened to the sides |
| band_pull_apart | 彈力帶拉開 | resistance band pull-apart at chest height, arms straight |
| cable_crunch | 跪姿繩索捲腹 | kneeling cable crunch under a pulley, torso curled down |
| decline_crunch | 下斜捲腹 | decline crunch on a bench, feet hooked under the roller |
| hanging_knee | 懸垂舉膝 | hanging knee raise from a pull-up bar, knees to the chest |
| dead_bug | 死蟲式 | dead bug on the back, opposite arm and leg extended, lower back flat |
| plank | 棒式 | forearm plank, body in a straight line |

### 3-4. 不需要做的

- 分頁列、按鈕等小圖示：沿用 Apple 的 SF Symbols，不用畫。
- 小工具（Widget）：只用文字和進度條，不用插圖。

## 4. 驗收檢查表

- [ ] 檔名、資料夾、尺寸完全照表（`file Art/**/*.png` 檢查）
- [ ] 圖裡沒有任何文字或數字
- [ ] 人物在所有圖裡是同一個角色、同一套衣服
- [ ] 動作姿勢正確（對照上表中文提示）、器材畫對
- [ ] App 圖示縮小到 60px 仍清楚
- [ ] 沒有改到 `Art/` 以外的任何檔案
