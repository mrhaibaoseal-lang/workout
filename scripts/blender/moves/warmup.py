# 動作批次：熱身。負責：Claude（動作）（見 docs/art/BLENDER_BRIEF.md §0-1）。
# MOVE_META：這個檔案有哪些動作（hero_proto.py 用 ast 讀，只能寫字面值）。
#   bell＝手上拿啞鈴（裝備的啞鈴部位）；lean_back＝背靠椅背／躺椅子，隱藏背部裝備（披風、背包、尾巴）。
MOVE_META = {}

# 熱身動作。寫法照 floor.py／standing_dumbbell.py。
