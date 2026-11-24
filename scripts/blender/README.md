# Blender 3D 原型（2026-11-22 試做中）

雲端容器：`apt-get install -y blender libegl1 libgl1-mesa-dri python3-numpy`（Ubuntu 套件是 4.0.2，沒有 USD 匯出）。
blender.org 下載站被網路政策擋，PyPI 的 `bpy` 需要 Python 3.11。

- `hero_proto.py`：程序化建角色（基本款：橘色貼身背心、深藍灰短褲、蛋形頭無下巴零件）（Skin modifier 身體＋衣服、骨架自動權重、頭髮／眼睛／鞋／啞鈴剛性部件）、
  啞鈴深蹲 48 格（關節座標 → 骨頭矩陣）、EEVEE 卡通兩階著色＋反向外殼描邊。
  `xvfb-run -a blender -b -P scripts/blender/hero_proto.py -- <輸出資料夾> 0 12 24`
- `export_app.py`＋`build_app.sh`：給 App 的 USDZ＋材質表＋動作 JSON（Blender 5.2，見 docs/3d-system.md 階段 1）。
- `export_glb.py`：`blender -b <輸出資料夾>/hero.blend -P scripts/blender/export_glb.py` → 帶骨架和動畫的 GLB。

- `gear_titan.py`：鈦甲系列 3D 測試版（`GEAR=titan`），頭盔、胸甲、腹甲、能量核心、肩甲、機械手甲、大腿甲、護膝、
  推進靴、雙筒噴射背包、能量膠囊啞鈴；全像掃描環只在 `FX=1` 時加（示範影片不放特效）。硬殼零件用倒角不細分，剛性綁在骨頭上。

- `gear_frost.py`：冰霜系列（`GEAR=frost`，史詩）：冰晶毛帽、冰柱領 T 恤（塗在身體上，`tank`＋`frst` 兩個屬性）、冰裂紋長褲、高筒冰刀鞋、霜凍手套、冰柱披肩＋冰晶立領、冰塊啞鈴。預覽 `docs/art/blender/frost.png`。
- `gear_pig.py`：小豬系列（`GEAR=pig`，撲滿主題）：豬耳豬鼻帽、粉紅 T 恤＋奶油肚皮＋金幣（塗在身體上，`tank`＋`pgbelly`＋`pgtrim`）、玫瑰短褲＋捲尾巴＋塗色反摺（`pgcuff`）、
  豬蹄靴、豬蹄手套、陶瓷撲滿背包（背墊貼背）、豬臉啞鈴。背靠椅背的動作（`LEAN_BACK`）尾巴也隱藏。預覽 `docs/art/blender/pig.png`。
- `gear_util.py`：各系列共用的造型工具（`obox`、`cyl`、`shell`、身體塗色 `add_layer`、T 恤形狀 `tee_parts`），hero_proto 在載入系列檔前 exec；新系列加進 hero_proto 的系列清單。

混搭：`GEAR="head=titan,hands=titan"` 逐部位指定（head top bottom feet hands back bell fx），沒寫的用基本款。
每個部位是獨立零件；上衣／下身換鈦甲時，緊身衣袖子／褲管和底下身體的顏色一起換。預覽 `docs/art/blender/mix.png`。

動作：`moves3d.py`（共用工具，hero_proto 會 exec 它）＋`moves/<批次>.py`（動作本身，檔頭 `MOVE_META` 登記，`MOVE=<名稱>` 選）＋`moves/props_*.py`（器材）。誰負責哪個檔見 `docs/art/BLENDER_BRIEF.md` §0-1。手腳釘在地板／握把上，軀幹用角度、手肘膝蓋用兩節 IK。
伏地挺身：腳尖和手掌固定、身體繞腳尖轉、手肘往後約 45 度。高位下拉：用使用者的「多功能啞鈴椅＋高位下拉架」一體機（`moves/props_bench.py` 的 `build_bench(back_deg)`：前端立柱＋頂部滑輪盒、兩側兩層槓片收納柱、座墊、可調靠背、頭枕＋把手、前端腳踝滾筒、前後底座；不畫商標和彈力繩）。配重＝立柱上的兩顆啞鈴（裝在套住立柱的滑套上，上下各一顆），拉下時整組沿立柱往上滑（使用者確認）。
使用者決定：之後改成 App 內即時 3D（可顯示自己的裝備）；示範影片不放裝備特效。

穿模處理：
- 衣服用 Data Transfer 複製身體權重；衣服底下的身體面塗成衣服色。
- 骨架與權重（2026-11-24 改，BLENDER_BRIEF §6-1）：身體、衣服、裝備都照「建模姿勢」（手臂下垂）建，`B[...]` 是建模姿勢的骨頭位置；
  合併前 `to_apose()` 整組轉成 **A 字靜止姿勢**（上臂離垂直 45°；腿不外張，因為動作檔會拿靜止的腳踝位置當腳的位置），再重算身體自動權重＋平滑（`widen_joints`：肩膀漸變區約 13 cm、肘膝約 9～10 cm，每個頂點最多 4 根骨頭）。
  不再截斷權重（以前 |x|<0.235 的手臂權重全給胸部，舉手就凹陷鼓包）。有 `clavicle.L/R`（胸→肩關節）。上半身用保持體積（雙四元數），髖和腿用線性（第二個 Armature 修改器 Multi Modifier，依頂點群組 `lbs` 混合）：保持體積會讓深蹲胯下鼓成一團。
- `moves3d.py` 的 `keyall` 每格自動做兩件事（動作檔不用改）：鎖骨跟轉（上臂離軀幹超過 60° 後，鎖骨往上轉超出部分的 1/3，最多 20°；
  用 `arm_to` 釘住手腕的手臂會重解 IK，直接 `aim` 的整條手臂跟著肩點平移）；上臂／前臂滾轉校正（`aim` 的「z＝X×y」會讓上臂多扭到 178°，
  改成手肘有彎時照屈曲平面、打直時最小轉動，前臂接著上臂，剩下的扭轉分給前臂和手腕）。
- `deformcheck.py`：身體變形檢查（擠扁、拉扯、法線翻轉、皮膚自穿），`blender -b <輸出>/hero.blend -P scripts/blender/deformcheck.py -- 報告.json 2`（`LBS=1` 看 App 的線性蒙皮）。
- `rigtest.py`：骨架極限姿勢（`MOVE=rigtest`，7 格：手舉過頭、側平舉、前平舉、手肘全彎、深蹲到底、髖鉸鏈、弓箭步）。骨架、權重、身體改動後都要跑它＋deformcheck。
- 手的握法：`arm_to(..., hand_roll=弧度)`／`aim(..., roll=弧度)` 讓手繞自己的軸轉（決定啞鈴握把朝向；0＝握把前後向、90°＝左右向；手舉過頭、側平舉等 `aim` 的滾轉規則見 `keyall` 的校正）。站姿啞鈴批次（`moves/standing_dumbbell.py`）用它；動作檔在 `keyall` 之後量 `[angles]`（鎖骨跟轉會改變實際骨頭方向），數值要落在動作卡（`docs/3d-moves/standing_dumbbell.md`）範圍內。
- 輸出路徑一律用絕對路徑（相對路徑 `out\x` 在這台 Windows 會被寫到 `C:\out\x`）。`NORENDER=1` 只存 hero.blend 不算圖（給 clipcheck／deformcheck）。
- 基本款背心＝身體軀幹塗色（不另做網格，含肩帶）：頂點屬性 `tank`（在背心裡多深，公尺）由著色器判斷 >0，邊緣平滑不鋸齒（`tank_field`），身型是使用者選定的平直倒三角；身體細分 3 級讓塗色邊緣平滑。
- 自動檢查：`blender -b <輸出>/hero.blend -P scripts/blender/clipcheck.py -- 報告.json 2`（見 docs/3d-system.md「防穿模」）。
- 接地修正（moves3d.py 結尾）、背靠椅背的動作隱藏背部裝備（動作檔 `MOVE_META` 的 `lean_back`）。
- 檢查方法：從正上方看伏地挺身（上背最容易穿）；依頂點最大權重骨頭上色找是哪根骨頭帶出來的。
預覽：`docs/art/blender/`（`squat_basic.gif`、`squat_titan.gif`、`cmp.png`）。

用途定位（使用者 2026-11-22）：3D 主要用在**訓練中的動作示範**；角色換裝 3D 只是測試。
