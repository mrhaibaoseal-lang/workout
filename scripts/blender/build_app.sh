#!/bin/sh
# 產生 App 用的 3D 檔案到 Workout/Hero3D/（技術驗證版）：深蹲帶全部零件，伏地挺身只取動作。
# Windows 上用 Git Bash 跑；BLENDER 可指定 Blender 路徑（要 4.2 以上，有 USD 匯出）。
set -e
B="${BLENDER:-/c/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
D=$(cd "$(dirname "$0")" && pwd); R="$D/../.."; DST="$R/Workout/Hero3D"
SERIES="${SERIES:-frost,titan}"
EXPORT=$SERIES QUICK=1 MOVE=squat "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$R/out/app_squat"
"$B" -b "$R/out/app_squat/hero.blend" -P "$D/export_app.py" -- "$DST" squat full
EXPORT=$SERIES QUICK=1 MOVE=pushup "$B" -b --factory-startup -P "$D/hero_proto.py" -- "$R/out/app_pushup"
"$B" -b "$R/out/app_pushup/hero.blend" -P "$D/export_app.py" -- "$DST" pushup clip
ls -la "$DST"
