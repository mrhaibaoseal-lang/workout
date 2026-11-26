# 伸展批次的器材（只放函式，不在載入時建物件；負責：Claude（動作），見 docs/3d-moves/stretch.md）。
# 每個動作都會載入這個檔，所以這裡不能直接建東西。

def build_stretch_wall(y, w=1.5, h=2.2):
    """一面牆（推牆小腿伸展用）：牆面在 y（人在 y 的 +側、面向 -Y 的牆），寬 w、高 h，厚 0.1。回傳牆的物件"""
    if 'wall' not in PM: PM['wall'] = toon('wall', hexc('#2E3A5C'), 0.75)
    return pbox('wall', (0, y - 0.05, h / 2), (w / 2, 0.05, h / 2), bevel=0.006, outline=True)
