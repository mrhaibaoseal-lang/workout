# 介面改版（方向 A：深色舞台）交接

原型：https://claude.ai/artifact/8E5ojNkjep8yjKovzqhKQX（使用者選了 A）。

## 已完成（2026-11-20）
- `Workout/Theme.swift`：色票與共用元件（themeCard、themeScreen、Tag、Ring、HotButtonStyle、GhostButtonStyle）。全 App `.preferredColorScheme(.dark)`。
- 今天、訓練中、進步：照原型重做（TodayView / WorkoutView / ProgressScreen）。
- 訓練中：正在做的動作卡上方有角色示範（`CharacterMove.forExercise`，新增 11 個動作骨架）。
- 行程、課表、班表核對、設定、Onboarding：深色化；行程改成日期膠囊＋當日時間軸，左滑刪除改成長按刪除。
- 設定備份到 Keychain（`SettingsBackup.swift`），重裝自動還原；訓練紀錄與角色背包不備份。

## 待上機確認
- 新動作骨架（弓步、側平舉、反向飛鳥側面視角只是近似；臀橋／伏地挺身／棒式的地面位置）。
- 設定頁 Form 裡摘要卡與器材 grid 的排版。
- 行程頁時間軸色條高度。
