#!/bin/sh
# 把動作庫要用的 3D 動作全部匯出到 Workout/Hero3D/（0.56.0）：每個動作一份 hero3d_clip_<動作>.json，
# 有器材的動作多一份 hero3d_prop_<動作>.json／.bin。不動 hero3d.usdz、貼圖、hero3d.json（那些由 build_app.sh 產生）。
# 用法：sh scripts/blender/build_moves.sh            （全部動作）
#       MOVES=benchPress,pulldown sh scripts/blender/build_moves.sh   （只重跑幾個）
# Windows 上用 Git Bash 跑；BLENDER 可指定 Blender 路徑。JOBS＝同時跑幾個 Blender。
set -e
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
D=$(cd "$(dirname "$0")" && pwd); R="$D/../.."; DST="$R/Workout/Hero3D"
ALL="titan,frost,pig,night,dawn,rune,astral,street,neon,lava,gold,shadow"
SERIES="${SERIES:-$ALL}"
OUTFITS="${OUTFITS:-basic,$ALL}"
JOBS="${JOBS:-6}"
RW=$(cd "$R" && pwd -W 2>/dev/null || pwd)   # Blender 要絕對路徑（Windows 用 C:/ 寫法）
mkdir -p "$R/out"
# 動作清單：各 moves/*.py 的 MOVE_META（只讀字面值）
if [ -z "$MOVES" ]; then
  MOVES=$(python - <<PY
import ast, glob, os
out = []
for f in sorted(glob.glob(os.path.join(r"$(cd "$D" && pwd -W)", "moves", "*.py"))):
    for n in ast.parse(open(f, encoding="utf-8").read()).body:
        if isinstance(n, ast.Assign) and any(getattr(t, "id", "") == "MOVE_META" for t in n.targets):
            out += list(ast.literal_eval(n.value))
print(",".join(out))
PY
)
fi
# 換裝零件（各系列穿整套建一次，clip 模式要拿來算接地）：out/outfit_<系列>/ 已經有就沿用，FORCE=1 重建
for s in $(echo "$OUTFITS" | tr ',' ' '); do
  if [ "$FORCE" = 1 ] || [ ! -f "$R/out/outfit_$s/parts.blend" ]; then
    rm -f "$R/out/outfit_$s/parts.blend"
    ( GEAR="top=$s,bottom=$s" QUICK=1 MOVE=squat NORENDER=1 "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$RW/out/outfit_$s" > "$R/out/outfit_$s.log" 2>&1 \
      && "$B" -b "$RW/out/outfit_$s/hero.blend" -P "$D/export_app.py" -- "$RW/out/outfit_$s" squat outfit >> "$R/out/outfit_$s.log" 2>&1 \
      || { echo "outfit $s 失敗，見 out/outfit_$s.log"; exit 1; } ) &
    n=$((${n:-0} + 1)); if [ $((n % JOBS)) -eq 0 ]; then wait; fi
  fi
done
wait
export OUTFITS OUTFIT_DIR="$RW/out"
# 每個動作：建模（帶全部系列的剛性零件）→ 匯出動作＋器材
one() {
  m="$1"
  EXPORT=$SERIES QUICK=1 NORENDER=1 MOVE=$m "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$RW/out/app_$m" > "$R/out/app_$m.log" 2>&1 \
    && "$B" -b "$RW/out/app_$m/hero.blend" -P "$D/export_app.py" -- "$RW/Workout/Hero3D" "$m" clip >> "$R/out/app_$m.log" 2>&1 \
    && grep "^clip " "$R/out/app_$m.log" || echo "FAIL $m（out/app_$m.log）"
}
export -f one 2>/dev/null || true
i=0
for m in $(echo "$MOVES" | tr ',' ' '); do
  one "$m" &
  i=$((i + 1)); if [ $((i % JOBS)) -eq 0 ]; then wait; fi
done
wait
ls "$DST"/hero3d_clip_*.json | wc -l
