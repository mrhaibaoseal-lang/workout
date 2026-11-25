# 動作卡：健身房器械（`scripts/blender/moves/machine.py`＋`props_machine.py`，2026-11-26）

補動作庫缺的 3D 示範。**全部是「健身房動作」**：使用者沒有這些機器（BLENDER_BRIEF §4），示範只是讓動作庫完整；App 端要標「健身房動作／需要器械」，不要排進在家課表。
器材是簡化的機器（座墊、靠背、配重塊、槓桿管、握把），不畫商標。`[angles]` 範圍寫在 `MOVE_META`，`clipbatch.py --series basic` 要全 PASS。
風險：除肩推機外都是「一般」；**機器肩推（`machineShoulderPress`）＝高（肩關節在頭上）**。

**共同提示（App 文案用）**：機器要先調座位（對準關節軸心、握把與目標高度一致）；重量先選能慢慢做 12～15 下的；
不要用甩的、不要讓配重塊在底部撞下去；關節伸到「接近伸直」就好、不要鎖死。

## legPress 腿推機（坐姿）
- 起始：坐在座墊、靠背後倒 25°，臀部貼住座墊、不離開；雙腳平放踏板與肩同寬、踏板中間；膝蓋朝腳尖方向。雙手握座墊兩側握把。膝蓋從接近伸直（約 165°，不鎖死）慢慢彎到約 90°，停一下，再用整個腳掌推回去。
- 關節：膝 80～100°（最深）～ 155～178°（伸直）；髖 55～95°（最深）。
- 常見錯誤：膝蓋鎖死、屁股離開座墊（骨盆後捲、下背離墊）、膝蓋往內倒、只用腳尖推、放得太深讓下背離開靠背。
- App 提示：整個腳掌（尤其腳跟）推；膝蓋朝腳尖方向、不要內夾；屁股和下背全程貼住；伸直時膝蓋微彎、不要鎖死。
- 來源：[NASM 腿推機](https://www.nasm.org/resource-center/exercise-library/leg-press)、[Mayo Clinic 腿推機](https://www.mayoclinic.org/health/leg-press/MM00745)（最低不要讓膝蓋小於 90°；推到接近伸直、不鎖膝）、[ExRx 槓桿腿推機](https://exrx.net/WeightExercises/GluteusMaximus/LV45LegPress)（靠背與安全擋調到不勉強彎腰的範圍）。
- 來源分歧：多數寫膝約 90° 起算，ExRx 偏向做到髖完全彎曲；示範取 90°（較保守，下背不離墊）。示範踏板與腿近乎水平，真實機器多半斜 45° 或坐姿垂直，**差在機器型式**（本示範是水平坐姿腿推機）。

## legExtension 腿伸展機（坐姿）
- 起始：坐在座墊、靠背後倒 10°，膝蓋對準機器軸心，墊子壓在腳踝前方（脛骨下段、腳踝上方）；雙手握座墊兩側握把。大腿貼座墊不動，把小腿往上伸直到膝約 170°，停一下，慢慢放回到膝約 90°。
- 關節：膝 80～100°（起）～ 160～180°（頂）。
- 常見錯誤：甩起來（用慣性）、屁股離開座墊、墊子放太高（脛骨中段）、膝蓋鎖死後用力撞、放得太快讓配重塊撞下去。
- App 提示：膝蓋對準機器軸心；伸到頂停一下、大腿前面（股四頭肌）用力；放下比抬起更慢；膝蓋有不舒服就縮小範圍或減輕重量。
- 來源：[Club Sports 腿伸展](https://cslife.clubsports.com/trainer-tip-proper-leg-extension-form/)（墊子太高會減少活動範圍；NASM 認證教練撰寫）、[Rep Fitness 腿伸展](https://repfitness.com/blogs/training/leg-extensions)（調整靠背使膝蓋對準機器軸心）、[Powerlifting Technique](https://powerliftingtechnique.com/how-to-do-leg-extensions-the-right-way/)（墊子在腳踝上方、背部完整貼住）。
- 來源分歧：沒有找到 ACE／NASM 官方頁面；以上為教練文章，彼此一致。頂端是否「鎖死」未明說，示範取 170°（不鎖死、較保守）。

## machineLegCurl 腿後彎舉機（坐姿）
- 起始：坐在座墊、靠背後倒 8°，腿往前伸（膝約 170°），下方墊子在小腿後面（腳踝上方、阿基里斯腱附近）；上面一塊墊子壓在大腿上；雙手握座墊兩側握把。把腳跟往下往後彎到膝約 85～90°，停一下，慢慢放回。
- 關節：膝 65～100°（最深）～ 150～178°（起）。
- 常見錯誤：屁股離開座墊（用腰代償）、甩動、墊子壓在腳跟上或太高、大腿墊太鬆（大腿抬起）。
- App 提示：大腿壓墊要壓緊；腳跟用力往下往後拉，大腿後側（腿後肌）收緊；放回要慢；全程背貼靠背。
- 來源：[NASM 坐姿腿彎舉](https://www.nasm.org/resource-center/exercise-library/seated-leg-curl)、[Rep Fitness 坐姿腿彎舉](https://repfitness.com/blogs/training/seated-leg-curls)（大腿壓墊在膝上方、小腿墊在腳踝上方）。
- 來源分歧：PureGym 說腳跟放在滾筒上，其他來源放在小腿／阿基里斯腱附近；示範取小腿後側（腳踝上方）。

## assistedPullup 輔助引體機（跪墊）
- 起始：選好配重（配重越重＝越輕鬆），雙膝跪在可升降的跪墊上，雙手正握上方握把、比肩略寬，手臂打直、肩膀下沉。用背把胸口拉向握把，下巴過握把，停一下，慢慢放回到手臂伸直。
- 關節：手肘 160～180°（底）～ 35～70°（頂）。
- 常見錯誤：沒放到手臂打直就拉（半幅度）、聳肩、晃動借力、輔助太重一直停在同一個重量。
- App 提示：先把肩膀往下壓，再用手肘往口袋方向拉；放下要慢到手臂伸直；輔助重量隨進步慢慢減少。
- 來源：[ExRx 輔助引體（跪姿）](https://exrx.net/WeightExercises/LatissimusDorsi/AsPullupOpenKneeling)（握太寬會縮小活動範圍）、[Healthline 輔助引體](https://www.healthline.com/health/assisted-pull-ups)（慢慢放下到手臂伸直、膝蓋彎曲）、[Fitbod 輔助引體](https://fitbod.me/exercises/assisted-pull-up)（跪在墊上、核心繃緊使身體從肩到膝成直線）。
- 來源分歧：The Prehab Guys 認為彈力帶輔助、脊椎較中立，比跪墊好；機器版是多數來源的標準，示範取機器版。這是跪姿，所以和 `pullup` 的差別只在下半身。

## machineChestPress 胸推機（坐姿）
- 起始：座位調到握把約與胸口（乳頭）同高、略低於肩；坐正、背靠墊（後倒 5°）、肩胛後收貼靠墊、雙腳平踩地板；雙手中立握（掌心相對）。手肘從約 90° 推到約 165°（不鎖死），停一下，慢慢放回到手肘約 90°。
- 關節：手肘 65～100°（起）～ 155～178°（頂）；軀幹前傾 0～15°。
- 常見錯誤：座位太低讓握把壓到肩膀、聳肩、背離開靠墊（拱腰）、手肘鎖死、放回時配重塊撞下去。
- App 提示：肩胛收緊貼住靠墊；推出去時手肘不鎖死；放回時握把到胸口附近就好、不要被拉到肩膀後面；腳踩穩。
- 來源：[ACE 坐姿胸推](https://www.acefitness.org/resources/everyone/exercise-library/188/seated-chest-press/)（握把約與胸中同高、不深過胸前）、[NASM 胸推機](https://www.nasm.org/resource-center/exercise-library/chest-press-machine)、[Pure Gym 坐姿胸推](https://www.puregym.com/exercises/chest/bench-press/seated-chest-press/)。
- 來源分歧：握把高度有人寫「肩下約 2 吋」、有人寫「乳頭高度」；示範取握把略低於肩、約胸中。握法：握把有水平（掌心朝下）也有中立兩種；示範取中立。

## machineShoulderPress 肩推機（坐姿；高風險）
- 起始：座位調到握把約與肩同高（或略高）、雙腳平踩地板；坐正、背靠墊（後倒 8°）；握把在肩旁、手肘約 90°、前臂垂直。往上推到手臂接近伸直（約 165°，握把在頭上方偏前），停一下，慢慢放回到手肘約 90°。
- 關節：手肘 65～100°（起）～ 155～178°（頂）；軀幹前傾 0～15°。
- 常見錯誤：腰往後挺（用背推）、聳肩、手肘鎖死、放太低壓到肩、握把離頭太遠。
- App 提示：背貼靠墊、核心繃緊（不要把腰壓扁也不要過度拱）；推起時肩膀不要聳到耳朵；手肘不鎖死；肩膀不舒服就降重量或停止。
- 來源：[ACE 坐姿肩推](https://www.acefitness.org/resources/everyone/exercise-library/186/seated-shoulder-press/)（握把與肩同高或略高、不鎖手肘；保持腰部自然弧度）、[Powerlifting Technique 肩推機](https://powerliftingtechnique.com/shoulder-press-machine/)（雙腳踩穩的座位高度）、[Austin CC 肩推](https://austincc.edu/hirsh/ExerciseGuide/shoulderpress.htm)（背平貼、不鎖肘）。
- 來源分歧：握法（Sussex 寬握 1.5 倍肩寬、Fitbod 略寬於肩、Strength Level 允許中立）；推的方向（Muscle & Strength 正上方、ACE 手肘略往前）。示範取中立握、略往前上方（較保守）。
- 風險：肩關節在頭上＝**高**。

## machineRearDelt 反向飛鳥機（面對機器、胸貼墊）
- 起始：面對機器坐著，座位調到握把與肩同高；胸口貼住胸墊（墊頂略低於腋下），雙手握把在身體前方、手臂近乎伸直（手肘約 165°）；用後肩把手臂往兩側打開到和肩膀成一直線（略在胸線前），停一下，慢慢放回。
- 關節：手肘 145～178°；上臂離身體前方的外展角 0～40°（起）～ 65～95°（頂）。
- 常見錯誤：聳肩、拱腰用身體推、胸離開胸墊、手往後拉得太遠超過身體（肩膀前翻）、用甩的。
- App 提示：胸口全程貼墊；手肘帶著手往兩側打開，想像把肩胛骨往中間夾；不要拉到身體後方；放回要慢。
- 來源：[Gravitus 後肩機](https://gravitus.com/guides/exercises/rear-delt-machine)（座位使握把與肩關節同高、胸貼墊）、[Muscle & Strength 反向飛鳥機](https://www.muscleandstrength.com/exercises/machine-reverse-fly)、[Garage Gym Reviews 反向 Pec Deck](https://www.garagegymreviews.com/reverse-pec-deck)。
- 來源分歧：握法（中立或正握，視把手而定）；手臂是否完全伸直（有人保持微彎）。示範取微彎（165°）、中立握；打開角度取到肩線略前為止（FitnessVolt 警告不要超過身體後方）。
