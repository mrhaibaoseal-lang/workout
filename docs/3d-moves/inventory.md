# 動作庫 × 3D 示範對照（2026-11-25 盤點，動作庫 111 個動作）

目的：每個動作庫動作都要有「看得出是這個動作」的 3D 示範。**專屬**＝新做；**共用**＝沿用已有的 3D 動作（在 App 端登記對照）。
3D 動作名稱＝`MOVE_META` 的鍵（也是 `CharacterMove` 的 rawValue）。判斷標準：截圖看得出是哪個動作；差很多的專屬，差不多的共用。

## A. 已有專屬 3D（不用做；其中有幾個 App 的 `byExercise` 還沒登記，要補對照）
| 動作庫 id | 3D 動作 | App 現況 |
|---|---|---|
| bb_bench、db_bench、db_neutral_press | benchPress | 已登記 |
| bb_floor_press、db_floor_press | floorPress | 已登記 |
| pushup、pause_pushup、archer_pushup | pushup | 靠 forPattern（共用） |
| db_incline_press、bb_incline_bench | inclinePress | **未登記**（目前套伏地挺身） |
| db_incline_fly | inclineFly | **未登記** |
| db_incline_curl | inclineCurl | **未登記** |
| db_chest_row | chestRow | **未登記** |
| db_chest_rear_fly | chestRearFly | **未登記** |
| db_pullover、db_skull、db_kickback | pullover、skullCrusher、kickback | 已登記 |
| db_row、bb_row、band_row | row | forPattern（共用） |
| table_row、pause_table_row | — | **已移除：使用者家中沒有桌子**（2026-11-26，不做 3D、不在對照表） |
| cable_*（下拉、窄握、直臂、三頭下壓、過頭、面拉、捲腹、划船、側平舉） | 滑輪 A／B 批 | 已登記（cable_close_pulldown 共用 pulldown） |
| db_split_squat…、db_hip_thrust、db_glute_bridge、sl_glute_bridge、db_step_up | 弓步／臀橋批 | 已登記 |
| db_sl_rdl、sl_rdl | slRdl | 已登記 |
| db_leg_curl | legCurl | 已登記（地板批，別的 session 做的） |
| plank、reverse_crunch、dead_bug、pike_pushup | plank、reverseCrunch、deadBug、pikePushup | 已登記 |
| squat、bb_squat、goblet_squat、db_squat、heel_goblet、goblet_15、slow_squat | squat（徒手＝bwSquat） | 共用 |
| bb_rdl、db_rdl、db_deadlift | rdl | 共用 |
| db_shoulder_press、bb_ohp、band_press | press | 共用 |
| db_curl、bb_curl、db_hammer_curl、band_curl | curl | 共用（錘式握法差在手腕，不另做） |
| db_overhead_ext | triceps | 共用 |
| db_lateral、band_lateral | lateral | 共用 |
| db_rear_fly、band_pull_apart | rearFly | 共用 |
| calf_raise 等小腿 | calf | 共用（單腳另做 calfSingle，見下） |
| band_pulldown、band_pushdown | pulldown、tricepsPushdown | 共用（彈力帶不畫，使用者沒有） |
| pause_split_squat、pause_calf_raise、sl_hip_thrust | lunge／calf／hipThrust | 共用（暫停版沿用原動作） |

## B. 要新做的專屬 3D（共 33 個，分 5 批；每批獨立 commit）
| 批次（檔案） | 3D 動作名 | 動作庫 id | 備註 |
|---|---|---|---|
| 1 地板徒手（`moves/floor2.py`；**完成 2026-11-25**） | sidePlank | side_plank | 前臂側撐 |
| | birdDog | bird_dog | 四足、對側手腳伸直 |
| | proneYTW | prone_ytw | 趴地，Y→T→W 三個姿勢循環 |
| | sissySquat | sissy_squat | 扶椅子（用使用者的椅子或柱子），膝蓋前推、腳跟離地 |
| | reverseNordic | reverse_nordic | 跪姿身體往後倒 |
| | towelLegCurl | towel_leg_curl | 仰躺臀橋姿勢、腳跟踩毛巾滑出去再拉回 |
| | slTowelLegCurl | sl_towel_leg_curl | 單腳版（另一腳懸空） |
| | declinePushup | decline_pushup | 腳放椅子上 |
| | elevatedPike | elevated_pike | 腳放椅子上的屈體伏地挺身 |
| 2 椅子（`moves/bench2.py`；**完成 2026-11-26**，動作卡 `bench2.md`） | dbFly | db_fly | 平躺飛鳥 |
| | declineCrunch | decline_crunch | 下斜捲腹（椅子靠背放下斜） |
| | sideLyingLateral | db_side_lying_lateral | 側躺在斜背椅 |
| | concentrationCurl | db_concentration_curl | 坐椅邊、手肘頂大腿內側 |
| | benchDip | bench_dip | 椅子撐體 |
| | elevatedBenchDip | elevated_bench_dip | 腳抬高 |
| 3 單槓／滑輪（`moves/bar_cable.py`） | pullup | pullup | 使用者沒有單槓，但動作庫有，照做 |
| | chinup | chinup | 反手 |
| | hangingKnee | hanging_knee | 懸垂舉膝 |
| | highChop | cable_high_chop | 跪姿高位繩索下劈（目前暫用 cableCrunch） |
| | oneArmPulldown | cable_one_arm_pulldown | 跪姿單手 D 把手 |
| 4 器械（`moves/machine.py`，新器材 `props_machine.py`；**2026-11-26 完成，動作卡 `machine.md`，全部標「健身房動作」**） | legPress | leg_press | 通用腿推機 |
| | legExtension | leg_extension | |
| | machineLegCurl | machine_leg_curl | 坐姿腿後彎舉機 |
| | assistedPullup | assisted_pullup | 輔助引體向上機（跪墊） |
| | machineChestPress | machine_chest_press | |
| | machineShoulderPress | machine_shoulder_press | |
| | machineRearDelt | machine_rear_delt | 反向飛鳥機 |
| 5 站姿（`moves/standing_c.py`，新器材 `props_kb.py`；**2026-11-26 完成，動作卡 `standing_c.md`**） | farmerWalk | farmer_walk | 雙手各一顆、走路（原地踏步） |
| | suitcaseCarry | suitcase_carry | 單手、身體不歪 |
| | kbSwing | kb_swing | 壺鈴擺盪（要新器材：壺鈴） |
| | arnoldPress | db_arnold | 手掌從朝身體轉到朝前 |
| | calfSingle | calf_raise、db_calf_raise、pause_calf_raise | 單腳提踵 |
| | leanLateral | db_lean_lateral | 單手扶柱側平舉（身體側傾） |

## C. 仍然共用（登記對照即可，不做專屬）
machine_calf → calf；machine_* 以外的彈力帶系列 → 對應啞鈴／滑輪動作；暫停／慢速版 → 原動作；
cable_one_arm_pushdown → tricepsPushdown；elevated_pike 以外的 pause_* → 原動作。

## 分批規則
照 §0-1：同一個批次檔一次只給一個 session 改；`floor.py` 的 `legCurl` 是別的 session 在做，所以這次新增的地板動作另開 `floor2.py`。

## App 對照（0.56.0）
實際對照表在 `Workout/Hero3D/Hero3DExerciseMap.swift`（動作庫 111 → 3D 動作名，108 個內建動作全有）。與上表不同的一處：`cable_close_pulldown` 用專屬的 `closePulldown`（動作卡 `cable.md` §6）。

