# Blender 3D 原型（2026-11-22 試做中）

雲端容器：`apt-get install -y blender libegl1 libgl1-mesa-dri python3-numpy`（Ubuntu 套件是 4.0.2，沒有 USD 匯出）。
blender.org 下載站被網路政策擋，PyPI 的 `bpy` 需要 Python 3.11。

- `hero_proto.py`：程序化建角色（基本款：橘色貼身背心、深藍灰短褲、蛋形頭無下巴零件）（Skin modifier 身體＋衣服、骨架自動權重、頭髮／眼睛／鞋／啞鈴剛性部件）、
  啞鈴深蹲 48 格（關節座標 → 骨頭矩陣）、EEVEE 卡通兩階著色＋反向外殼描邊。
  `xvfb-run -a blender -b -P scripts/blender/hero_proto.py -- <輸出資料夾> 0 12 24`
- `export_app.py`＋`build_app.sh`：給 App 的 USDZ＋材質表＋動作 JSON＋上衣／下身換裝貼圖（Blender 5.2，見 docs/3d-system.md 階段 1）。
  換裝共用工具 `outfit_util.py`（讀塗色節點鏈、展 UV、numpy 烘貼圖）；總覽圖 `outfit_review.py`（`WAIST=1` 腰部特寫），輸出到 `out/`。
- `export_glb.py`：`blender -b <輸出資料夾>/hero.blend -P scripts/blender/export_glb.py` → 帶骨架和動畫的 GLB。

- `gear_titan.py`：鈦甲系列 3D 測試版（`GEAR=titan`），頭盔、胸甲、腹甲、能量核心、肩甲、機械手甲、大腿甲、護膝、
  推進靴、雙筒噴射背包、能量膠囊啞鈴；全像掃描環只在 `FX=1` 時加（示範影片不放特效）。硬殼零件用倒角不細分，剛性綁在骨頭上。

- `gear_frost.py`：冰霜系列（`GEAR=frost`，史詩）：冰晶毛帽、冰柱領 T 恤（塗在身體上，`tank`＋`frst` 兩個屬性）、冰裂紋長褲、高筒冰刀鞋、霜凍手套、冰柱披肩＋冰晶立領、冰塊啞鈴。預覽 `docs/art/blender/frost.png`。
- `gear_pig.py`：小豬系列（`GEAR=pig`，撲滿主題）：豬耳豬鼻帽、粉紅 T 恤＋奶油肚皮＋金幣（塗在身體上，`tank`＋`pgbelly`＋`pgtrim`）、玫瑰短褲＋捲尾巴＋塗色反摺（`pgcuff`）、
  豬蹄靴、豬蹄手套、陶瓷撲滿背包（背墊貼背）、豬臉啞鈴。背靠椅背的動作（`LEAN_BACK`）尾巴也隱藏。預覽 `docs/art/blender/pig.png`。
- 英雄類四系列（2026-11-25，`GEAR=night|dawn|rune|astral`，都不含特效）：
  - `gear_night.py` 夜巡者（史詩）：義警兜帽＋眼罩、長袖戰術背心（塗色 `tank`＋`ntvest`，雙 V 徽章、斜背帶、工具腰帶）、戰術長褲（側袋、護膝）、戰術靴、手套＋前臂鰭刃、扇形下緣斗篷（橘內裡、立領）、手裏劍啞鈴。
  - `gear_dawn.py` 曙光（傳說）：旭日頭環、白藍長袖戰衣（`tank`＋`dwblue`，金高領、星章、金肩飾、太陽扣腰帶）、藍長褲＋金側線（`dwstripe`）、及膝長靴、金色喇叭護手、金邊藍長披風、旭日啞鈴。
  - `gear_rune.py` 符文戰神（傳說）：青銅角盔、無袖戰甲（胸甲片、毛皮披肩、尖刺圓肩甲、發光符文）、腿甲（鱗片、膝刺、脛甲）、青銅戰靴、尖刺拳套、背負巨劍、符石啞鈴。
  - `gear_astral.py` 星界魔導（傳說）：漂浮星晶冠、靛藍法袍（`tank`＋`astrim`，扇形立領、菱形寶石、喇叭袖、燕尾後擺）、星點長褲（`asdot`）＋尖角褲口、捲尖巫師鞋、手背漂浮行星、能量羽翼、星核啞鈴。
  - 材質名前綴 `nt`／`dw`／`rn`／`as` 在 `clipcheck.py` 算硬裝備；身體塗色叫 `skin_<系列>`、長褲叫 `pants_<系列>`（算身體）。長褲系列和底色在 `hero_proto.py` 的 `PANTS`。
- 街頭／霓虹／熔岩／黃金／暗影（2026-11-25，`GEAR=street|neon|lava|gold|shadow`，不含特效；預覽 `docs/art/blender/<系列>.png`、5 套並排＋換裝混搭 `gear5.png`）：
  - `gear_street.py` 街頭（稀有，6 部位）：反戴棒球帽（帽舌朝後、黃星）、長袖帽 T（`tank`＋`srpocket` 袋鼠口袋＋`srtrim` 羅紋，抽繩、背後帽兜）、白籃球褲＋藍側條（`srstripe`）、高筒籃球鞋、露指手套＋毛巾護腕、電鍍疊片啞鈴。
  - `gear_neon.py` 霓虹（史詩）：環繞發光護目鏡＋耳機天線、長袖緊身衣（`necy`／`nemg` 青、洋紅電路紋，發光端點、六角核心）、深色長褲＋青側線（`nestripe`）＋膝燈、低筒發光跑鞋、發光指節手套、分段能量背環、八角發光啞鈴。
  - `gear_lava.py` 熔岩（史詩）：岩石頭帶冒火舌、岩石背心（`lvcrack`／`lvcore` 發光裂紋、肩上岩塊、岩漿核）、橘短褲＋褲管火舌（`lvflame`、`lvhem`）、岩石戰靴＋鞋跟火焰、岩石火拳、火舌下緣披風、岩漿縫石塊啞鈴。
  - `gear_gold.py` 黃金（傳說）：王者之冠（尖頂珍珠、紅絨、金球十字）、金背心＋紅滾邊（`gdtrim`）＋金鍊大獎牌、紅拳擊短褲＋金側條（`gdstripe`）＋冠軍腰帶、翼靴、黃金拳擊手套、白貂毛邊紅披風＋白貂披肩、金星啞鈴。
  - `gear_shadow.py` 暗影（傳說）：包頭面罩（只露眼縫、紫光眼、新月、腦後飄帶）、長袖戰衣（`sdline` V 線、`sdwrapt` 前臂綁帶）＋厚圍巾飄尾＋紫晶、長褲交叉綁腿（`sdwrap`）＋大腿短刀、分趾忍者鞋、利爪手甲、破布下緣披風、虛空球啞鈴。
  - 共用工具（`gear_util.py`）：`blob`（低面數橢球）、`face_lite`／`hair_lite`（臉、頭髮低面數版）、`seg_field`（身體塗色的折線紋路）、`flame`（火舌）、`rock`（石塊）、`ring_arc`（圓弧管）、`torso_y`（軀幹表面 y）、`shorts_trim`（短褲花色＋身體褲管口同步塗）。
  - 材質前綴 `sr`／`ne`／`lv`／`gd`／`sd` 在 `clipcheck.py` 算硬裝備；長褲 `pants_<系列>2`、短褲 `shorts_<系列>`、身體塗色 `skin_<系列>` 算身體。
- `gear_util.py`：各系列共用的造型工具（`obox`、`cyl`、`shell`、身體塗色 `add_layer`、T 恤形狀 `tee_parts`、袖長可調 `sleeve_paint`、臉 `face`、頭髮 `hair`、頭盔殼 `cap_shell`、圓管 `tube`、面片 `panel`、星形 `star`、寶石 `gem`、披風 `back_drape`），hero_proto 在載入系列檔前 exec；新系列加進 hero_proto 的 `SERIES_FILES`。

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
  全部動作 × 系列一次跑、只重跑有變動的組：`python scripts/blender/clipbatch.py`（結果在 `out/clipcache/`）。
- 接地修正（moves3d.py 結尾）、背靠椅背的動作隱藏背部裝備（動作檔 `MOVE_META` 的 `lean_back`）。
- 檢查方法：從正上方看伏地挺身（上背最容易穿）；依頂點最大權重骨頭上色找是哪根骨頭帶出來的。
預覽：`docs/art/blender/`（`squat_basic.gif`、`squat_titan.gif`、`cmp.png`）。

驗收工具（2026-11-24，BLENDER_BRIEF §5-2、§9-1）：
- **角度自動判定**：動作的 `MOVE_META` 加 `'angles'`（字面值）。`moves3d.py` 的 `measure_pose(pose.bones)` 從骨頭姿勢量：`knee.L/R`、`hip.L/R`、`elbow.L/R`（內角，伸直＝180°）、
  `trunk_lean`（胸骨頭離垂直，0＝直立）、`uarm_trunk.L/R`（上臂和「軀幹往下」夾角，躺著也適用）、`uarm_vert.L/R`（上臂離世界垂直往下，90＝水平）。`uarm_flare.L/R`（手肘往身體左右外開的角度，躺著、趴著也適用）。
  寫法：`{'knee': (70, 180)}`＝整個循環最小值不能小於 70、最大值不能大於 180（任一邊可寫 `None`＝不限）；
  `{'knee': {'min': (70, 85)}}`＝最小值要落在 70～85（`'max'` 同理，可兩個都寫）。名稱不帶左右＝左右都檢查，`'knee.L'`＝只檢查左邊。容差 0.5°。名稱打錯會直接 FAIL。
  `python scripts/blender/clipbatch.py --moves squat --series basic`：先照常跑穿模檢查，再由 `anglecheck.py` 對 hero.blend 量一次（`angles.json`，每個動作只量一個系列），
  判定每次都重算，印 `[angles] squat: PASS`／`FAIL …`，每組在 `summary.json` 多一欄 `angles`（status、fails、每個量的最小／最大）；FAIL 時結束碼 1；沒寫 `angles` 顯示「未設定」。
  指紋：計算時拿掉 `MOVE_META` 的 `angles` 欄位 → **只改 angles 不會重跑穿模檢查**，也不用重新量（只重新判定，不開 Blender）。改 `moves3d.py`、`anglecheck.py`、動作姿勢才會重量。
  單獨量：`blender -b <輸出>/hero.blend -P scripts/blender/anglecheck.py -- angles.json`。
- **審查總覽圖**：`python scripts/blender/review_sheet.py standing_dumbbell`（批次檔名）或 `--moves squat,press`。每個動作一張 4×4（原本鏡頭、正面、側面、正上方 × 起始、中段、最深、回程），
  加整批縮圖 `_overview.png`，輸出到 `out/review/<批次>/`（不進 git）。基本款、草稿品質；hero.blend 沿用 clipcache 裡指紋最新的那組、否則重建（`--fresh` 強制重建）。
  `review_render.py`（Blender 端：量角度選格、4 個鏡頭渲染）、`compose.py`（用 Blender 的影片剪輯器拼圖和標字，不需要 PIL）。「最深」＝變化最大的那個量離起始最遠的格，中段／回程＝去程／回程走到一半的格。

滑輪 A 批（2026-11-24，`moves/cable.py`、`moves/props_cable.py`、動作卡 `docs/3d-moves/cable.md`）：
- 一律用使用者的一體機 `build_bench`（椅子和立柱不能分開；鋼索只從椅子側出、不長）。`bench_scene(back_deg, flip)` 包裝它（`flip`＝整台繞 Z 轉 180°，人背對立柱；回傳的 `xf` 要乘在機器座標上）；站姿動作靠背放平、人跨站在椅面兩側（`stand_legs` 的 `ankle_w`）。`build_rope()` 三頭繩（`key_rope` 照手骨頭位置擺繩、握把段順著手的握把軸）、`build_latbar(gx)` 下拉槓、`make_cables()`／`key_cables()` 鋼索和配重。繩子和槓子的父物件叫 `bar`（clipcheck 不算手握東西的穿透）。
- `moves3d.py` 新增 `stand_legs`、`elbow_hinge`（三頭下壓／過頭伸展／直臂下拉共用：上臂方向＋手肘內角，**不釘手腕**：手臂舉高時鎖骨把肩膀抬高，釘手腕會把手肘硬壓彎）。
- **骨頭擺放順序**：骨頭矩陣是相對父骨頭算的，要先擺骨盆／胸（`trunk`），再擺腿；反過來第 0 格（骨盆從靜止姿勢轉過來）腿會飛掉。
- 手肘彎的方向：手臂垂下時前臂往前折，一路照這個旋轉方向（`elbow_hinge` 的 `flex`）；反過來就是手肘過度伸展，像骨折。

用途定位（使用者 2026-11-22）：3D 主要用在**訓練中的動作示範**；角色換裝 3D 只是測試。

弓步／臀橋批次（2026-11-24，`moves/lunge_bridge.py`，動作卡 `docs/3d-moves/lunge_bridge.md`）：
- `moves3d.py` 新增共用姿勢函式（不改既有函式）：`lunge_pose(t, front, rear, hy, knee, lean)` ＝弓步族群範本（前腳踝釘住、**前膝內角決定髖高**，後腳用 `rear_toe`／`rear_fixed`／`rear_step_back`／`rear_air` 回傳的函式決定；後腳構不到時髖不再升高）；
  `hang_arms` 手臂垂在身側拿啞鈴；`bridge_pose(phi, C, foot_y, …)` ＝臀橋族群範本（上背接觸點 C 和腳踝釘住，軀幹仰角 phi 決定髖高）。
- 動作：`lunge`（原地分腿站姿）、`splitSquat`（保加利亞，椅子轉 90° 放人後面）、`reverseLunge`（後跨）、`stepUp`（踩上椅子靠背那段）、`bridge`（地板，兩顆啞鈴各壓一側髖骨）、`hipThrust`（上背靠座墊前緣、槓鈴）。
  變化版只換 `front`／`rear`／`hy`／`knee`／`lean`；椅子用 `place_bench(back_deg, 轉角, 位置)`（呼叫 `build_bench` 再把新物件掛到轉向的空物件上）；臀推的槓鈴 `build_barbell()` 在這個檔裡。
