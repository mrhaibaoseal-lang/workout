# 相機數次數（Apple Vision）

2026-11-25 使用者決定先走相機辨識，最大的疑慮是準不準。所以先做**準度測試頁**：只記錄關節座標，
不數次數、不存影像。使用者實際做幾組並輸入真正的次數，資料匯出後由主對話在電腦上用 Python 設計演算法、算準度，
數字夠好才做成正式功能。

使用者條件：不想拍到身材，所以**影像一律不存、不上傳**；手機：iPhone 16 Plus（沒有 LiDAR）。

## 第一階段：測試頁（要做的）

### 入口
設定 →「資料」頁（`DataSettingsView`，`Workout/Settings/SettingsPages.swift`）最下面加一個區塊「實驗功能」，
裡面放 NavigationLink「數次數測試」。新檔案放在 `Workout/RepTest/`。

### 流程
1. **選動作**（固定 5 個，用 `ExerciseLibrary` 的 id 和名稱）：

   | id | 建議鏡頭 | 建議擺法（畫面上顯示這行提示） |
   |---|---|---|
   | `db_curl` | 側面 | 手機直立放在腰的高度，離身體約 2 公尺，拍側面 |
   | `db_shoulder_press` | 正面 | 手機直立放在胸口高度，離身體約 2.5 公尺 |
   | `goblet_squat` | 側面 | 手機直立放在膝蓋到腰的高度，離身體約 2.5 公尺，拍側面 |
   | `pushup` | 側面 | 手機直立放在地上，離身體約 2 公尺，拍側面 |
   | `db_hip_thrust` | 側面 | 手機直立放在椅子高度，離身體約 2 公尺，拍側面 |

   另外可以選：鏡頭方向（側面／正面，預設照上表）、前／後鏡頭（預設前鏡頭，使用者才看得到螢幕）。
2. **對位畫面**：相機即時辨識。**預設只畫火柴人**（黑底），有一個開關可以疊上相機畫面（只顯示、不存）。
   這個動作需要的關節（見下）信心值都 ≥ 0.3 時，畫面上方顯示綠色「已入鏡」，否則顯示紅色並寫出缺哪些關節。
   - 需要的關節：彎舉＝肩、肘、腕（左右任一邊完整即可）；肩推＝兩邊肩、肘、腕；深蹲＝肩、髖、膝、踝（任一邊）；
     伏地挺身＝肩、肘、腕、髖、踝（任一邊）；臀推＝肩、髖、膝（任一邊）。
3. **開始**：按「開始」→ 倒數 5 秒（每秒輕震一下，最後一下重震）→ 開始記錄。記錄中畫面顯示大字的秒數和火柴人，
   整個畫面都可以點來停止。上限 3 分鐘，到了自動停。記錄期間不讓螢幕自動關閉。
4. **填答案**：停止後填：實際完整次數（必填，Stepper）、半程次數（預設 0）、重量 kg（選填）、備註（選填），按「存」。
   按「不存」就丟掉。
5. **紀錄清單**：測試頁首頁列出已存的每一組（日期、動作、實際次數、格數、平均 fps），可以左滑刪除。
   清單上方的「匯出全部」把資料用 `ShareSheet`（`Workout/Tools/CSVExport.swift`）分享出去。

### 擷取和辨識
- `AVCaptureSession`，直式，30 fps，解析度 1280×720 就夠（`.hd1280x720`）。`alwaysDiscardsLateVideoFrames = true`。
- 每一格用 `VNDetectHumanBodyPoseRequest`（2D）在背景佇列處理；Vision 還在忙就丟掉這一格，並記到「丟掉的格數」。
- 方向：用直式對應的 `CGImagePropertyOrientation` 送進 Vision，存下的座標是**直式畫面座標**。
  前鏡頭**不要**做左右鏡像，存原始結果，並在 trial 資料記錄用的是哪個鏡頭。
- 同時用 `CMMotionManager` 的 deviceMotion 讀重力向量，記錄手機的傾斜（不用權限）。每格記錄最新的一筆。
- 時間用 sample buffer 的 presentation timestamp，換算成「從開始記錄算起的秒數」。
- 影像處理完就丟掉，不寫檔、不快取。

### 存檔與匯出
- 存在 Application Support 的 `RepTest/` 資料夾。**不**放進 SwiftData、完整備份、雲端備份、SharedStore。
- 每一組一個 `frames_<trialId>.csv`，另外一個 `trials.json` 存所有組的資料（用 Codable）。
- 匯出時產生兩個檔交給 ShareSheet：
  - `trials.csv`：`trial_id,date,exercise_id,view,camera,actual_reps,partial_reps,weight_kg,note,duration_s,frames,dropped_frames,avg_fps,app_version`
  - `frames.csv`（所有組合在一起）：`trial_id,t,gx,gy,gz,` 接著 19 個關節各三欄 `<joint>_x,<joint>_y,<joint>_c`。
    關節順序：`nose,leftEye,rightEye,leftEar,rightEar,neck,leftShoulder,rightShoulder,leftElbow,rightElbow,leftWrist,rightWrist,root,leftHip,rightHip,leftKnee,rightKnee,leftAnkle,rightAnkle`。
    座標是 Vision 的正規化座標（0～1，**原點在左下**），小數 4 位；沒偵測到的關節三欄留空。
    那一格完全沒偵測到人，也要寫一列（關節欄位全空），才看得出斷掉多久。
  - 文字欄位（備註）要做 CSV 跳脫。

### 權限與設定
- `project.yml` 加 `INFOPLIST_KEY_NSCameraUsageDescription: 數次數測試會用相機即時辨識關節位置，影像不會存下來，也不會上傳。`
- 相機權限被拒時，顯示說明和「打開設定」按鈕（`UIApplication.openSettingsURLString`）。
- 部署目標維持 iOS 17.0，用到的 API 都是 17 以下就有的。

### 不要做
- 不數次數、不做任何判斷演算法（之後由主對話分析資料後設計）。
- 不接進訓練流程（`Session/`）。
- 不存、不上傳任何影像。
- 不改 `GearArt.swift`、`RankBadgeArt.swift` 這些產生的檔案。

### 做完的樣子
- GitHub Actions 編譯成功；版號照 CLAUDE.md 合進 main 時定（新功能，升次版本）。
- 單元測試：CSV 輸出（標頭、空關節、跳脫）至少一個測試。

## 使用者的測試方式（測試頁做好後）
每個動作至少錄 4 組，鏡頭照建議擺法：
1. 兩組正常做 8～12 下。
2. 一組故意夾 2～3 下半程（填在「半程次數」）。
3. 一組在記錄中包含拿起、放下啞鈴的動作（備註寫「含拿放」）。
匯出 `trials.csv`、`frames.csv` 交給 Claude 分析。

## 第二階段：分析（主對話做）
- 腳本放 `scripts/repcount/`（Python）：濾波（One-Euro）、每個動作選訊號（用比例，例如手腕到肩的距離除以軀幹長，
  不用原始角度）、左右取信心高的一邊、前一兩下自動校正幅度、遲滯門檻、最短時間、半程另外標記。
- 指標：每組「次數完全正確」的比例、誤差 ±1 以內的比例，分動作列出。
- 想試的：`VNDetectHumanBodyPose3DRequest`（iOS 17）能不能改善鏡頭角度造成的誤差。

## 第三階段：正式功能（看準度再決定）
訓練中開相機數次數，每數到一下震動或報數；組結束時先填好次數，由使用者確認或 ±1 修正。
可延伸：每下的速度變慢多少（估還剩幾下）、左右比較。準度不夠的動作，可以考慮用 AirPods 頭部動作（使用者有 AirPods）補。
