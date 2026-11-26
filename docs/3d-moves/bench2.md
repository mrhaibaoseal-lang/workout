# 動作卡：椅子 2（`scripts/blender/moves/bench2.py`，2026-11-25）

補動作庫缺的 3D 示範。器材全是使用者的啞鈴椅＋立柱一體機（`build_bench`）和啞鈴；撐體的墊腳箱是示意用的 45 cm 高墊子（家中椅子／矮凳代替）。
`[angles]` 範圍寫在 `MOVE_META`，`clipbatch.py --series basic` 要全 PASS。來源說明：ACE／NASM／ExRx 找不到同名頁面的已寫明。
風險：全部「一般」（撐體肩關節前側受力）。

## dbFly 啞鈴平躺飛鳥（`db_fly`）
- 起始：平躺（靠背 90°），雙手各一顆啞鈴對握，手臂在胸口正上方、手肘微彎。慢慢往兩側打開（像抱大樹），到手臂約與肩同高（胸口有拉開感）就停，再把啞鈴畫弧合起來。48 格一循環（下 22、停 4、回 15）。
- 關節：手肘 156～170°（全程固定微彎約 164°）；上臂離垂直往下 165～178°（頂端近乎垂直朝上）→ 80～100°（打開到水平）。
- 常見錯誤：手臂打太直（肩肘受傷）、打開過低（肩前側拉傷）、變成臥推（手肘彎太多）、挺腰離椅。
- App 提示：手肘像固定在微彎的角度不動；只往下到胸口有被拉開的感覺就好，不用硬壓；合起來時像抱大樹，不是往上推。
- 來源：[ACE 胸部動作庫](https://www.acefitness.org/exercise-library-details/8/21/)（平躺、手肘微彎、手腕中立）、[ExRx 上斜飛鳥](https://exrx.net/WeightExercises/PectoralClavicular/DBInclineFly)（手肘全程固定微彎）、[Sussex 大學 dumbbell flyes](https://www.sussex.ac.uk/sport/documents/dumbbell-flyes.pdf)。
- 來源分歧：ExRx 是上斜版；示範用平躺（ACE 是平躺版）。角度：有來源寫彎 10～20°，取 16°（較保守）。NASM 沒有找到同名頁面。

## declineCrunch 下斜捲腹（`decline_crunch`）
- 起始：躺在稍微下斜（靠背 100°）的椅子上，膝蓋彎約 100～120°，腳踝勾在椅子前端滾筒後面，雙手抱一顆啞鈴貼在胸口（啞鈴立在胸前，兩手托住上端；使用者 2026-11-26 要求）。用腹部把上背捲離椅面約 36°（下背留在椅面），頂端停一下，慢慢放回（背不用完全碰到底）。48 格一循環（捲 18、停 6、放 18、停 6）。
- 關節：軀幹離垂直 100°（躺）→ 約 64°（捲起），膝 85～125°。
- 常見錯誤：用手拉頭（頸痛）、整個軀幹坐起來變仰臥起坐（髖屈肌代償）、甩動、屏氣。
- App 提示：只把肩胛骨捲離椅面，下巴和胸口之間留一個拳頭；用腹部慢慢捲、慢慢放；吐氣時往上捲。
- 來源：[Fitbod decline crunch](https://fitbod.me/exercises/decline-crunch)（只抬肩胛骨、不要整個軀幹）、[Fitnessvolt decline crunch](https://fitnessvolt.com/decline-crunch/)（和一般捲腹相同但幅度較大）、[Planfit decline crunch](https://planfit.ai/exercise/decline-crunch)（用核心不用慣性）。ACE／NASM／ExRx 沒有找到同名頁面。
- **待確認：**使用者的椅子靠背是否能調到 90° 以上（下斜）；若不能，改成平躺（靠背 90°）版本，示範少了「頭低腳高」的部分。示範的腳踝在滾筒後面、腳尖朝上頂住滾筒（這台滾筒離地只有 22 cm、比座面低很多，沒辦法把腳踝塞到滾筒下，所以改成「頂住」）；雙手抱一顆啞鈴立在胸前（2026-11-26 由「雙手交叉」改成抱啞鈴；只留右手那顆、左手托在旁邊，做法同 pullover；啞鈴離胸口 0.17 m 時硬碰撞最少），不用手放頭後（容易拉脖子）。

## sideLyingLateral 啞鈴側躺側平舉（`db_side_lying_lateral`，示範右手）
- 起始：左側躺在斜背（45°）椅子上，左手彎著放在頭下當枕頭，雙腿彎起疊在一起（右腿在上、膝蓋朝胸口那側；這台椅子座面離地 47 cm、前面又有立柱，腿沒辦法像一般斜背椅那樣伸直垂下去），右手拿啞鈴垂在身前。手肘微彎（約 165°）固定，用肩膀把啞鈴從身體旁畫弧舉到和身體垂直（肩高），停一下，慢慢放回。48 格一循環。
- 關節：右手肘 155～175°；上臂離軀幹往下 12° → 90°（和 `lateral` 同樣舉到肩高）。
- 常見錯誤：身體往後翻借力、用甩的、聳肩、舉過肩高、頭掉在椅子上。
- App 提示：身體不要往後倒，肩膀壓低；手肘領先手腕，像倒水一樣微微轉；放下要慢（至少 2 秒）。
- 來源：[ExRx 上斜側平舉](https://exrx.net/WeightExercises/DeltoidLateral/DBInclineLateralRaise)、[NFPT incline side lateral raise](https://nfpt.com/how-to-do-incline-side-lateral-dumbbell-raises/)（側躺、腋下對齊椅子上緣、手肘微彎、舉到手肘和肩同高）、[Dmoose](https://www.dmoose.com/blogs/shoulders/incline-dumbbell-side-lateral-raise)。
- 來源分歧：椅子角度各家 30～60°；示範取 45°。下面的左手與雙腿的擺法 ExRx／NFPT 沒寫：示範左手放頭下當枕頭（另一種是抱著椅子）、雙腿彎起疊著（為了避開這台椅子的座面與立柱），**未經專業確認**。這些來源是「側躺在上斜椅上」，和庫裡「斜躺側平舉」同一個變化式。

## concentrationCurl 集中彎舉（`db_concentration_curl`，示範右手）
- 起始：坐在椅墊上（椅子轉 90°、長邊在人的左右兩側，人面向側邊，這樣前傾時頭不會撞到立柱）、雙腳打開（比肩寬）、上身前傾，右手肘頂在右大腿內側、手臂垂直往下垂，左手放在左膝上撐著。啞鈴從幾乎打直（約 170°）彎到頂（約 45°），手肘全程不離開大腿，頂端不把啞鈴疊在手肘正上方；慢慢放回。48 格一循環（每邊做）。
- 關節：右手肘 35～55°（頂）～ 160～180°（底）；膝 85～125°；軀幹前傾 40～72°（示範約 63°：椅子座面高，肩膀要在手肘正上方，幾何上前傾偏大；手肘放在大腿內側靠膝蓋那段）。
- 常見錯誤：手肘離開大腿滑上去、用身體甩起來、利用大腿推手肘借力、聳肩。
- App 提示：手肘「放」在大腿內側當支點，輕輕壓住就好，不要借腿力；只動前臂；頂端停一下、慢慢放。
- 來源：[PureGym concentration curls](https://www.puregym.com/exercises/arms-and-shoulders/bicep-curl/concentration-curls/)（手肘靠大腿內側、另一手扶對側腿）、[Powerlifting Technique](https://powerliftingtechnique.com/concentration-curls/)（頂端不要把啞鈴疊在手肘上方）、[Repfitness](https://repfitness.com/blogs/training/concentration-curls)（略往前傾）。ACE／NASM／ExRx 沒有找到同名頁面。
- 來源分歧：有的說「手肘」靠大腿、有的說「上臂背面」；有人說用力壓大腿（PureGym）、有人說不要借腿力（ATHLEAN-X）。示範取「輕壓、不借力」。

## benchDip 椅子撐體（`bench_dip`）／elevatedBenchDip 腳抬高（`elevated_bench_dip`）
- 起始：椅子轉 90°（長邊朝人），背對椅子坐在邊緣，雙手撐在椅緣（比肩略窄、手指朝前扣住邊），臀部離開椅面往前，雙腳往前伸（一般版腳跟踩地、膝微彎；腳抬高版腳放在高約 45 cm 的墊子上、腿近乎伸直）。手肘往後彎到約 90°（上臂約與地面平行），身體貼近椅子垂直下降，再推起但不鎖死手肘。48 格一循環（下 20、停 4、上 18）。
- 關節：手肘 75～100°（底）～ 150～175°（頂）；一般版膝 100～175°，腳抬高版膝 145～180°。
- 常見錯誤：手肘往外開（肩膀受傷）、聳肩、下降太深（肩前側過度拉伸）、臀部離椅子太遠、鎖死手肘。
- App 提示：手肘指向後面，不是往兩側；肩膀壓下，離耳朵遠一點；下降到手臂和地面平行就好；肩膀會痛就不要做。
- 來源：[NASM bench dips](https://www.nasm.org/resource-center/exercise-library/bench-dips)（手肘 90°、不往外開、不鎖死）、[MasterClass bench dip guide](https://www.masterclass.com/articles/bench-dip-exercise-guide)（上臂與前臂 90°、底部停一下）、[Healthline bench dips](https://www.healthline.com/health/fitness-exercise/bench-dips)（手肘外開會把力轉到肩膀）。腳抬高版：[Peloton triceps dips](https://www.onepeloton.com/blog/triceps-dips)（難度更高、肩膀負擔大）。ACE／ExRx 沒有找到同名頁面。
- 來源分歧：有的建議下降到上臂和地面平行、有的說 90°；取較保守的 90°（上臂略高於水平）。腳抬高版有教練建議肩膀有問題的人直接不做，卡片與 App 提示要寫。
- 說明：示範用使用者的椅子轉 90° 當撐體椅（靠背平放，手撐在靠背墊的長邊）；庫裡寫「椅子」，不要求一定是這台。

## 檢查結果（2026-11-26）
- `[angles]` 基本款全 PASS。
- clipcheck（基本款，硬碰撞單格最大；軟墊接觸不算）：dbFly 2、benchDip 4、elevatedBenchDip 6、sideLyingLateral 8、declineCrunch 24（抱啞鈴後：手貼胸口 20、兩手互碰 24，皆為手托啞鈴的接觸；原手交叉版 1）、concentrationCurl 4，剩下的都是兩條大腿內側互碰。
- 其他系列（只記錄，使用者 2026-11-24 決定可接受）：見 BLENDER_BRIEF §10 的進度列。
- deformcheck（基本款）單格壞面 dbFly 348、declineCrunch 439（抱啞鈴版）、benchDip 461、elevatedBenchDip 433、concentrationCurl 871、sideLyingLateral 1098（膝蓋彎很深的自穿）；都在肩／鎖骨／膝窩／肘窩，同已完成動作的量級。
- 做法提醒：側躺時腿要用 `leg_side`（大腿／小腿的骨頭 z 軸朝身體背面）；用 `leg_to`（世界座標決定骨頭滾轉）會讓兩條大腿的剖面和骨盆差 90°，褲子在胯下互穿約 100 對／格。
