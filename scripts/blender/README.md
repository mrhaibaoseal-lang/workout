# Blender 3D 原型（2026-11-22 試做中）

雲端容器：`apt-get install -y blender libegl1 libgl1-mesa-dri python3-numpy`（Ubuntu 套件是 4.0.2，沒有 USD 匯出）。
blender.org 下載站被網路政策擋，PyPI 的 `bpy` 需要 Python 3.11。

- `hero_proto.py`：程序化建角色（基本款：橘色貼身背心、深藍灰短褲、蛋形頭無下巴零件）（Skin modifier 身體＋衣服、骨架自動權重、頭髮／眼睛／鞋／啞鈴剛性部件）、
  啞鈴深蹲 48 格（關節座標 → 骨頭矩陣）、EEVEE 卡通兩階著色＋反向外殼描邊。
  `xvfb-run -a blender -b -P scripts/blender/hero_proto.py -- <輸出資料夾> 0 12 24`
- `export_glb.py`：`blender -b <輸出資料夾>/hero.blend -P scripts/blender/export_glb.py` → 帶骨架和動畫的 GLB。

- `gear_titan.py`：鈦甲系列 3D 測試版（`GEAR=titan`），頭盔、胸甲、腹甲、能量核心、肩甲、機械手甲、大腿甲、護膝、
  推進靴、雙筒噴射背包、能量膠囊啞鈴；全像掃描環只在 `FX=1` 時加（示範影片不放特效）。硬殼零件用倒角不細分，剛性綁在骨頭上。

混搭：`GEAR="head=titan,hands=titan"` 逐部位指定（head top bottom feet hands back bell fx），沒寫的用基本款。
每個部位是獨立零件；上衣／下身換鈦甲時，緊身衣袖子／褲管和底下身體的顏色一起換。預覽 `docs/art/blender/mix.png`。

動作：`moves3d.py`，`MOVE=squat｜pushup｜pulldown`（hero_proto 會 exec 它）。手腳釘在地板／握把上，軀幹用角度、手肘膝蓋用兩節 IK。
伏地挺身：腳尖和手掌固定、身體繞腳尖轉、手肘往後約 45 度。高位下拉：含椅子、護膝滾筒、立柱、滑輪、鋼索、槓片（跟著升降）、寬握下拉槓。
使用者決定：之後改成 App 內即時 3D（可顯示自己的裝備）；示範影片不放裝備特效。

穿模處理：衣服用 Data Transfer 複製身體權重；衣服底下的身體面直接塗成衣服色。
預覽：`docs/art/blender/`（`squat_basic.gif`、`squat_titan.gif`、`cmp.png`）。

用途定位（使用者 2026-11-22）：3D 主要用在**訓練中的動作示範**；角色換裝 3D 只是測試。
