#!/bin/sh
# 產生 App 用的 3D 檔案到 Workout/Hero3D/（技術驗證版）：深蹲帶全部零件，伏地挺身只取動作。
# Windows 上用 Git Bash 跑；BLENDER 可指定 Blender 路徑（要 4.2 以上，有 USD 匯出）。
# SERIES：剛性部位（頭、手、腳、背、啞鈴）帶哪些系列。OUTFITS：上衣／下身換裝帶哪些系列（各建一次模、烘貼圖）。
set -e
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
D=$(cd "$(dirname "$0")" && pwd); R="$D/../.."; DST="$R/Workout/Hero3D"
SERIES="${SERIES:-frost,titan}"
# 符文（rune）先不帶：上衣＋下身的零件約 2.9 萬頂點，USDZ 會到 9.5 MB（2026-11-25 量）
OUTFITS="${OUTFITS:-basic,frost,titan,pig,night,dawn,astral}"
# 換裝：每個系列穿整套上衣＋下身建一次模（靜止姿勢就夠，並行），存塗色和零件
mkdir -p "$R/out"
for s in $(echo "$OUTFITS" | tr ',' ' '); do
  rm -f "$R/out/outfit_$s/parts.blend"
  ( GEAR="top=$s,bottom=$s" QUICK=1 MOVE=squat NORENDER=1 "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$R/out/outfit_$s" > "$R/out/outfit_$s.log" 2>&1 \
    && "$B" -b "$R/out/outfit_$s/hero.blend" -P "$D/export_app.py" -- "$R/out/outfit_$s" squat outfit >> "$R/out/outfit_$s.log" 2>&1 \
    || { echo "outfit $s 失敗，見 out/outfit_$s.log"; exit 1; } ) &
done
wait
for s in $(echo "$OUTFITS" | tr ',' ' '); do test -f "$R/out/outfit_$s/parts.blend" || { echo "outfit $s 沒有產生"; exit 1; }; done
export OUTFITS OUTFIT_DIR="$R/out"
rm -f "$DST"/hero3d_top_*.png "$DST"/hero3d_bottom_*.png "$DST"/hero3d_cloth_*.png
EXPORT=$SERIES QUICK=1 MOVE=squat "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$R/out/app_squat"
"$B" -b "$R/out/app_squat/hero.blend" -P "$D/export_app.py" -- "$DST" squat full
EXPORT=$SERIES QUICK=1 MOVE=pushup "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$R/out/app_pushup"
"$B" -b "$R/out/app_pushup/hero.blend" -P "$D/export_app.py" -- "$DST" pushup clip
ls -la "$DST"
