# 動作卡：單槓／滑輪（`scripts/blender/moves/bar_cable.py`，2026-11-26）

補動作庫缺的 3D 示範。單槓用新器材 `moves/props_bar.py` 的 `build_pullbar`（橫槓高 2.30 m，一般門框單槓 2.1～2.3 m）；滑輪動作用使用者的啞鈴椅＋高位滑輪一體機。
`[angles]` 範圍寫在 `MOVE_META`，`clipbatch.py --series basic` 要全 PASS。

**使用者沒有單槓**（BLENDER_BRIEF §4）：引體向上、反手引體、懸垂舉膝是動作庫裡的「單槓動作」，示範只是讓動作庫完整；App 端要標「需要單槓」，沒有單槓的人不要排進課表（或用 `pulldown` 取代）。
風險：引體向上／反手引體／懸垂舉膝＝一般（肩關節在頭上、需要握力，肩膀有傷者不做）；高位滑輪下劈＝一般（旋轉類，下背不要代償）；單手高位下拉＝一般。

## pullup 引體向上（正握）／chinup 反手引體（反握）
- 起始：雙手握橫槓。引體向上正握（掌心朝前）、比肩略寬（手腕 x ±0.36 m，肩關節在 ±0.27）；反手引體反握（掌心朝向自己）、約與肩同寬（±0.28）。手臂打直懸垂、膝蓋微彎、腳離地、肩膀往下沉不聳肩。用背把胸口拉向橫槓，手肘往下往身體兩側收，下巴過槓，頂端停一下，慢慢放回到手臂打直（全程控制、不甩腿）。48 格一循環（上 18、停 4、下 22）。
- 關節：手肘 165～180°（底）～ 35～60°（頂；反手引體 30～60°）；膝 120～175°。
- 常見錯誤：沒有放到手臂打直就拉下一下（半幅度）、用甩腿／踢腿借力（kipping）、聳肩、只用下巴過槓而不是胸口靠近、頭往前伸、放下時直接掉。
- App 提示：先把肩膀往下壓離耳朵，再用手肘往口袋方向拉；到下巴過槓、胸口靠近橫槓；放下要慢（至少 2 秒）直到手臂伸直；身體不要晃，腳不要踢。**做不起來就用高位下拉練。**
- 來源（引體向上）：[StrongLifts 引體向上](https://stronglifts.com/pullup/)（底部手臂完全伸直、頂端下巴過槓）、[Healthline 引體向上](https://www.healthline.com/health/pull-ups)（正握、下巴過槓）、[Tom's Guide](https://www.tomsguide.com/news/youve-been-doing-pull-ups-all-wrong-heres-how-to-fix-them)（手肘在槓下、貼近身體兩側；用胸口去靠槓）。
- 來源（反手引體）：[NASM 反手引體 vs 引體向上](https://www.nasm.org/resource-center/blog/chin-ups-vs-pull-ups-the-difference-the-benefits-muscles-worked)（先設定肩胛、從完全懸垂做到下巴過槓、核心繃緊減少擺盪）、[ACE Do-It-Better 反手引體](https://www.acefitness.org/continuing-education/certified/february-2025/8800/the-ace-do-it-better-series-chin-ups/)、[Repfitness 反手引體](https://de.repfitness.com/blogs/training/how-to-do-chin-ups)（與肩同寬）。
- 來源分歧：握距——有人寫正握「肩寬」、有人寫「略寬」，示範取略寬 0.72 m（肩寬 0.54）；頂端「下巴過槓」或「胸口靠槓」（Tom's Guide），示範取下巴過槓、胸口靠近。反手引體的手腕示範是 0.56 m，與肩同寬偏窄。
- **示範的做法（程式上的重點）**：手舉過頭或懸吊時 `keyall` 的鎖骨跟轉會把肩膀抬高約 7 cm，釘在槓上的手腕就會把手肘硬壓彎（只剩約 117°，看起來像沒伸直）。`bar_cable.py` 的 `clav_delta`／`hang_trunk` 用同一公式預先算出位移，讓肩膀「抬完之後」剛好在目標位置，手肘才能打直到 ≥ 165°。

## hangingKnee 懸垂舉膝
- 起始：雙手正握橫槓、與肩同寬、手臂打直懸垂、肩膀下沉。用腹部把骨盆往後捲（posterior pelvic tilt），膝蓋往胸口抬到大腿約過水平（髖約 70°），小腿自然垂下（膝約 90°）；頂端停一下，慢慢放回（不甩、不晃）。48 格一循環（上 20、停 5、下 20）。
- 關節：手肘 165～180°；髖 55～85°（頂）～ 160～180°（底）；膝 60～110°（頂）～ 160～180°（底）。
- 常見錯誤：前後甩動借力、只抬腿而骨盆沒有後捲（變成髖屈肌動作）、腰過度挺、放下時直接掉。
- App 提示：先吐氣、把骨盆捲向肚臍（腹部先用力），再抬膝蓋；放下比抬起更慢；肩膀下沉、不要晃。**新手先彎膝版（這個示範就是）。**
- 來源：[Healthline 懸垂舉膝](https://www.healthline.com/health/fitness/hanging-knee-raises)（不甩動、控制）、[MasterClass 懸垂舉膝](https://www.masterclass.com/articles/hanging-knee-raises-guide)、[PureGym 懸垂舉膝](https://puregym.com/exercises/abs/hanging-knee-raises)。ACE／ExRx 這次沒有找到同名頁面。
- 來源分歧：有的說「膝蓋抬到胸口」、有的說「大腿到水平」；示範取大腿略過水平（較保守、肩膀負擔小）。

## highChop 高位滑輪下劈（跪姿，雙手握三頭繩）
- 起始：右膝著地、左腳在前（膝約 90°），人跪在椅子旁邊（機器轉 -90°，人離椅子遠一點）。雙手握三頭繩，在靠滑輪那側的肩膀／臉旁；用身體像砍柴一樣轉動，雙手沿對角線往對側（左）髖外側下劈，上身同時往左轉、微微前彎；髖不動。頂端停一下，慢慢放回。48 格一循環（下 22、停 4、回 18）。
- 關節：手肘 **70～180°**（見下）；左膝 80～105°；軀幹前傾 0～12° → 18～40°。
- 常見錯誤：用手臂拉而不是轉軀幹、髖跟著轉（失去跪姿的意義）、膝蓋往內倒、聳肩、下背過度扭轉。
- App 提示：髖固定、核心繃緊；轉的是胸口，不是手臂；眼睛跟著手；放回去要慢。**肩膀不舒服就把重量降到很輕。**
- 來源：[FMS 半跪姿繩索劈砍](https://www.functionalmovement.com/exercises/chop_from_half_kneeling_with_cable_bar)（半跪、髖穩定、轉的是軀幹）、[Fitwill 跪姿高低反旋轉劈砍](https://fitwill.app/exercise/7584/cable-kneeling-high-low-anti-rotation-chop/)（單把手、雙手、對角線拉到外側髖附近；胸口跟著手轉就是重量太重）、[ACE 跪姿劈砍](https://www.acefitness.org/education-and-resources/lifestyle/exercise-library/340/kneeling-wood-chop/)（同族變化式）、[Eleiko 半跪穩定劈砍](https://eleiko.inspire360.com/resource/659d730d29fc1a6371030f7c)。NASM 沒有找到同名頁面。
- 來源分歧：來源是「直槓／單把手」；示範用三頭繩（這台機器只有三頭繩可選）。有的版本把重點放在「反旋轉（身體不轉）」（Fitwill），有的是「旋轉」（FMS）；動作庫叫「下劈」，示範取「軀幹轉動、髖不動」。
- **肩寬限制（卡片必寫）**：肩寬 0.54 m，兩手握的是同一條繩（兩手只隔約 0.12 m），所以**兩條手臂不可能同時伸直**：離繩較遠那隻伸到約 99%，另一隻就必須彎。實測手肘 74～170°。真人也一樣（單把手時兩手臂都是微彎），所以範圍寫 70～180°，不是 90°以上。
- **雙手左右錯開 6 cm、沿繩前後錯開 4.5 cm**（一前一後握繩），避免兩隻手互穿。
- 風險：旋轉＋肩關節在斜上方，**一般**。

## oneArmPulldown 單手高位下拉（示範右手）
- 起始：**這台機器跪不了**（椅子和立柱一體，滑輪在椅子後上方）：改成**坐姿**（和 `pulldown` 一樣：靠背後倒 24°、腳勾滾筒），右手握 D 型把手，手臂在頭上方前伸（手臂近乎伸直），左手扶左大腿。把手肘往下往身體側邊拉，到把手在肩旁（手肘貼身），頂端停一下，慢慢放回到手臂伸直。48 格一循環（下 18、停 6、回 20）。
- 關節：右手肘 35～75°（底）～ 150～178°（起）；右上臂離垂直 0～40°（拉到底）～ 140～175°（起）。
- 常見錯誤：身體往後倒借力、手肘往外甩（沒有往下往身體側邊收）、聳肩、放回時整隻手被拉上去。
- App 提示：先把肩膀壓下，再用手肘往下；手肘指向身體後下方；上身不要晃、不要往後倒。
- 來源：[Bodybuilding.com 單手下拉](https://bodybuilding.com/exercises/one-arm-lat-pulldown)（手肘貼向身體側邊）、[Legion 單手下拉](https://legionathletics.com/single-arm-lat-pulldown/)（手肘往髖部、把手到胸側）、[PureGym 單手下拉](https://www.puregym.com/exercises/back/lat-exercises/single-arm-lat-pulldown/)（坐姿版，大腿墊固定）、[BarBend 單手下拉](https://barbend.com/single-arm-lat-pulldown/)。
- 來源分歧：**標準是跪姿（單膝跪）**（Bodybuilding.com 的跪姿高位滑輪），也有坐姿版（PureGym）；示範用坐姿（機器限制），**差在少了核心穩定的需求，待教練確認**。把手終點：有的說到胸側、有的說到肩旁，取肩旁（較保守）。

## 檢查結果（2026-11-26）
- `[angles]` 基本款全 PASS。highChop 的手肘範圍原先猜 90°，量到最小 74°（肩寬限制，見上），所以把範圍改成 70～180°，不是改動作。
- 修正紀錄：highChop 穿模 2949 → 27：起點雙手往前（手臂不再橫過頭）、終點手往左離開大腿、兩手沿繩錯開。oneArmPulldown 280 → 14：腿要在 `trunk` 之後才擺（第 0 格腿飛掉的老問題）。
- 系列穿模（24 格加總，只記錄）：pullup／chinup 約 7.2k（暗影／曙光）、hangingKnee 最高 7.7k（符文）、highChop 最高 4.7k（曙光）、oneArmPulldown 最高 5.2k（鈦甲）。基本款：pullup 24、chinup 15、hangingKnee 12、highChop 27、oneArmPulldown 14；沉地全 0。
- deformcheck（基本款）單格壞面 pullup 356、chinup 400、hangingKnee 613、highChop 631、oneArmPulldown 623；單一部位 ≤ 76（肩／鎖骨／肘窩）。
- 未做：§8-1 獨立審查。
