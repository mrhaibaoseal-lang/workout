# 美術／動畫工具（2026-11-22 安裝）

## Claude Code skills（`.claude/skills/`，跟著 repo 走）
| 資料夾 | 來源 | 授權 | 用途 |
|---|---|---|---|
| `swiftui-animation-dp` | dpearson2699/swift-ios-skills | PolyForm Perimeter（個人用可） | 彈簧、keyframe、PhaseAnimator、減少動態效果 |
| `swiftui-animation-jr` | jamesrochabrun/skills | MIT | 動態設計原則、轉場、Metal shader |
| `swiftui-microinteractions` | iAmVishal16/swiftui-microinteractions | MIT | 84 種微互動範例（只取 SKILL.md） |
| `apple-design` | rshankras/claude-code-apple-skills（design） | MIT | 含 `game-feel`（觸覺、慶祝動畫）、animation-patterns |
| `frontend-design`、`canvas-design`、`algorithmic-art` | anthropics/skills | Apache 2.0 | 美感方向、靜態美術、生成藝術 |

兩個 `swiftui-animation` 同名，已改名加後綴。

## Swift 套件（`project.yml` 的 `packages`，已連到 App target）
- **Vortex**（twostraws, MIT）：粒子系統，煙火／火焰／魔法等預設。首選。
- **EffectsLibrary**（GetStream, Apache 2.0）：另一套粒子效果。
- **Pow**（EmergeTools, MIT）：轉場與「數值改變」特效。
- **Lottie**（airbnb/lottie-spm）：播放 Lottie JSON 動畫。
- **RiveRuntime**（rive-app/rive-ios）：播放 Rive 骨架動畫（編輯器在瀏覽器，Windows 可用）。

目前程式碼都還沒 `import`，用到時再接。確定不用的套件要拿掉，減少 IPA 大小和編譯時間。

## Sports2D（影片 → 關節角度）
- 雲端環境 `workout` 的 setup script 會 `pip install sports2d`，網路放行 `download.openmmlab.com`（姿勢模型）。
- 用法：`sports2d --video_input 影片.mp4 --show_realtime_results false --show_graphs false --do_ik false`
  （結尾可能出現 `'list' object has no attribute 'close'`，是畫圖的 bug，輸出不受影響）。
- 輸出 `*_angles_person00.mot`：tab 分隔，含 `right thigh / right shank / right foot / trunk / right arm / right forearm`
  等肢段角度，可轉成 `scripts/art/moves.js` 的 `torso / arm / leg` 角度（要換算座標方向，轉換腳本還沒寫）。
- 影片要**側拍、全身入鏡、單人**。
