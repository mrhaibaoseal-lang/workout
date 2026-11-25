# 動作卡：地板徒手 2（`scripts/blender/moves/floor2.py`，2026-11-25）

補動作庫缺的 3D 示範。全部徒手（椅子、立柱、毛巾是器材）。`[angles]` 範圍寫在 `MOVE_META`，`clipbatch.py --series basic` 全 PASS。
來源說明：兩個來源盡量找同一個變化式；找不到的寫「參考是 ○○ 版」。**ACE 搜尋有些動作找不到同名頁面，已寫明。**
風險：全部「一般」，教練審查清單（`coach-review.md`）照樣登記。

## birdDog 鳥狗式（`bird_dog`）
- 起始：四足跪姿，手在肩正下方、膝在髖正下方，背平直、頭中立。結束＝對側手臂（耳旁）和腿（和背成一線）伸到和地板平行，停 1 秒，收回，換邊。48 格＝每邊 24 格。
- 關節：支撐手肘 160～180°；髖 90～110°（軀幹微微頭高，因為手臂比大腿長）→ 伸腿時 160～180°；膝 85～100° → 165～180°。
- 常見錯誤：塌腰／拱背、骨盆歪（髖翻開）、腿抬太高、聳肩。
- App 提示：髖和肩保持水平，像背上放著一杯水；手腳抬到和地板平行就好，不用更高；慢慢來不要甩。
- 來源：[ACE bird dog](https://www.acefitness.org/resources/everyone/exercise-library/14/bird-dog/)（手臂到肩膀高度、髖與地板平行不傾斜）、[ExRx bird dog](https://exrx.net/WeightExercises/ErectorSpinae/BWBirdDog)（緩慢、不甩動）、[Harvard Health](https://www.health.harvard.edu/exercise-and-fitness/bird-dog-exercise-for-your-core-how-to-do-it-safely)。
- 來源分歧：無。
- 注意：示範沒做「身體重心往支撐側移一點」（`trunk()` 只支援前後傾）。

## sidePlank 側棒式（`side_plank`，前臂版）
- 起始＝結束（靜止，只有呼吸起伏 ±0.8°）：側躺，下面前臂撐地、手肘在肩正下方、前臂朝前垂直身體，雙腳上下疊，髖抬起，頭肩髖膝踝成一直線；上面的手叉在髖上。
- 關節：下手肘 85～100°、髖 165～180°、膝 170～180°。
- 常見錯誤：髖下沉、髖往前或往後轉（身體要面向正前方）、聳肩、頭掉下去。
- App 提示：想像髖骨往天花板頂；腳底（外緣）也要用力；脖子跟著脊椎成一直線。
- 來源：[NASM side plank](https://www.nasm.org/resource-center/exercise-library/side-plank)、[MasterClass side plank guide](https://www.masterclass.com/articles/side-plank-guide)（手肘在肩正下方）、[Peloton](https://www.onepeloton.com/en-AU/blog/side-planks)（前臂版、腳要用力）。ACE 沒有找到同名頁面。
- 注意：預設是「腳疊在一起」版；兩條腿相貼，所以大腿互碰（basic 約 106 對／格）是身體貼合不是穿模。

## proneYTW 俯臥 Y-T-W（`prone_ytw`）
- 起始：趴在地板、額頭微抬、雙腳伸直，雙手放地。依序做 Y（手臂斜前方，約 35° 離身體中線）→ T（和肩同高向兩側）→ W（手肘彎 90°、往身體兩側收，肩胛夾緊）。每個姿勢：手離地約 17 cm、上背只離地約 10°，停 0.7 秒，放下。72 格＝每個姿勢 24 格。
- 關節：手肘 W 時 80～105°，Y／T 160～180°；髖、膝伸直 165～180°。
- 常見錯誤：聳肩、用腰（下背）拱起來借力、頭仰起、甩動、W 時手肘外翻。
- App 提示：力量來自肩胛骨往後下夾，不是腰；頭保持跟脊椎成一直線看地板；慢慢來，抬到腰要開始拱就停。
- 來源：[ACE 俯臥肩胛穩定系列（I-Y-T-W-O）](https://www.acefitness.org/resources/everyone/exercise-library/249/prone-scapular-shoulder-stabilization-series-i-y-t-w-o-formation/)、[Sussex 大學 T-W-Y 說明（PDF）](https://www.sussex.ac.uk/sport/documents/t-w-y.pdf)（到背開始拱就停）。
- 來源分歧：ACE 的 W 是手肘降到身側約 45°；示範取肘彎 90°、手肘朝腳方向（較保守，不要求肩外旋太大）。

## towelLegCurl 毛巾滑行腿後彎舉（`towel_leg_curl`）與單腳版 slTowelLegCurl（`sl_towel_leg_curl`）
- 起始：仰躺、兩條毛巾墊在腳跟下（光滑地板）、臀橋把髖抬到肩髖膝一直線（軀幹離地約 28°）並維持。腳跟往臀部滑近到膝蓋約 75～80°，停一下，再慢慢滑出去到腿接近伸直（慢放 19 格）。單腳版另一腳離地，伸直、和身體成一直線懸空（髖不能歪）。
- 關節：膝 75°（近）～ 160°（遠）；軀幹離垂直 100～125°（躺著抬髖）。
- 常見錯誤：髖掉下來、骨盆歪（單腳版）、用腰拱起代替髖伸、滑太遠失去控制。
- App 提示：髖一直夾緊抬高；滑出去要慢（離心最有效）；腳尖朝上、腳跟出力。
- 來源：[NISMAT 髖後滑行](https://nismat.org/2023/12/11/hamstring-sliders/)、[Physitrack 單腳毛巾滑行](https://us.physitrack.com/home-exercise-video/hamstring-towel-slide---single-leg)、[STACK](https://www.stack.com/?p=40961)。ACE／NSCA 沒有找到同名頁面。
- 來源分歧：有的版本是雙腳、有的是單腳；示範雙腳版取膝約 75° 最近。

## reverseNordic 反向北歐（`reverse_nordic`）
- 起始：跪在軟墊上、小腿平貼地板往後、腳背貼地，大腿垂直。慢慢往後倒到約 36°（約 2 秒），從膝蓋到頭保持一直線（髖不彎），停 0.3 秒，用大腿力量拉回。雙手往前平舉當平衡。
- 關節：膝 50～90°；髖 165～180°（始終伸直）；軀幹離垂直 0～36°。
- 常見錯誤：髖彎（屁股往腳跟坐）、圓背、倒太多失控、用手撐地借力。
- App 提示：身體像一塊木板；倒的幅度要自己拉得回來（新手只倒一半就好）；膝蓋要墊軟墊。
- 來源：[Stronger by Science 反向北歐](https://www.strongerbyscience.com/reverse-nordic-curls/)、[StrengthLog](https://www.strengthlog.com/reverse-nordic/)（髖保持前頂鎖住）。
- 來源分歧：有人容許髖微彎以完成全幅度；示範取較保守的「髖全程伸直」。

## sissySquat 西西深蹲（單手扶柱；`sissy_squat`）
- 起始：腳跟離地（腳掌 50°）、左手扶身旁立柱（使用者的一體機轉 -90° 放左邊）、右手叉腰。膝蓋往前推、髖往前頂，膝髖肩成一直線整條線往後倒約 34°，小腿前傾約 50°，到底後收回。庫裡寫「扶椅子」；椅子沒有適合高度的立柱，所以用機器立柱（椅子和立柱一體），待確認。
- 關節：膝 98°（最深）～ 175°；髖 165～180°；軀幹離垂直 0～34°。
- 常見錯誤：髖彎（屁股後坐）、膝蓋痛還硬做、靠手拉起來。
- App 提示：膝蓋會承受很大壓力，不舒服就減少深度；手只是扶穩，不是拉；腳跟只要抬一點，不用踮到最高。
- 來源：[Powerlifting Technique sissy squat](https://powerliftingtechnique.com/sissy-squat/)（重點在膝蓋、髖不動）、[Set for Set sissy squats](https://setforset.com/blogs/news/sissy-squats)（扶著東西穩住）。ACE／NSCA 沒有找到同名頁面。
- 風險：膝蓋壓力大，排進教練審查。

## declinePushup 腳抬高伏地挺身（`decline_pushup`）
- 和伏地挺身一樣（身體一直線、手肘往後約 45°），腳尖放在椅子上（約 50 cm），頭低腳高。
- 關節：手肘最深 30～60°（和 `pushup` 同樣深）、最高 160～180°；髖 165～180°；膝 170～180°。
- 常見錯誤：塌腰、聳肩、手肘外開 90°、頭往前探。
- App 提示：先把一般伏地挺身做穩；腳越高越吃力，肩膀會更辛苦。
- 來源：[NASM decline push-up](https://www.nasm.org/resource-center/exercise-library/decline-push-up)、[MasterClass decline push-up guide](https://www.masterclass.com/articles/decline-push-up-guide)。

## elevatedPike 腳抬高屈體伏地挺身（`elevated_pike`）
- 和屈體伏地挺身一樣的倒 V 字，但腳放在椅子上（約 50 cm），髖更高；往下時頭頂往兩手前緣靠近，手肘彎約 90～110°，推起。
- 關節：手肘最深 80～110°；膝 165～180°。
- 常見錯誤：用手肘外開、頭撞地、髖往後縮變成一般伏地挺身。
- App 提示：這個動作肩膀很吃力，動作要小心慢；頭頂輕輕靠近地板就停。
- 來源：沒有找到專門的腳抬高屈體頁面；參考 [NASM decline push-up](https://www.nasm.org/resource-center/exercise-library/decline-push-up)（腳墊高的做法）和已完成的 `pikePushup`（`floor.md`）。**待確認：需要兩個獨立來源。**
- 風險：肩關節在頭上方，排進教練審查。

## 檢查結果（基本款）
- 穿模、deformcheck：見 BLENDER_BRIEF §10 進度表。
