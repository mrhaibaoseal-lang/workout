# 器材：熱身批的牆面（靠牆天使、扶牆擺腿）。負責：Claude（動作，熱身批）。
# 只定義函式，不在載入時建任何東西（props_*.py 每個動作都會 exec）。
# 角色面向 -Y、+X 是角色左邊。舞台圓台由動作檔的 CAM['stage']（x, y, 半徑）決定。

PM['wall'] = toon('wall', hexc('#3B4A66'), 0.85)
PM['wallbase'] = toon('wallbase', hexc('#1B2335'), 0.7)

def build_wall(axis, face, width=2.2, height=2.4):
    """一面簡單的牆（厚 8 cm 的板、踢腳板、幾條直縫）。
    axis='y'：牆在人的後面，牆面（朝向人的那一面）在 y=face，人背對牆；
    axis='x'：牆在人的側面，牆面在 x=face（face<0 ＝ 牆在角色右邊，牆面朝 +X；face>0 ＝ 牆在左邊，牆面朝 -X）。
    回傳 None。"""
    th = 0.04
    if axis == 'y':
        pbox('wall', (0, face + th, height / 2), (width / 2, th, height / 2), 0.012)
        pbox('wallbase', (0, face - 0.012, 0.06), (width / 2, 0.016, 0.06), 0.004)
        for x_ in (-0.7, -0.35, 0.0, 0.35, 0.7):
            pbox('wallbase', (x_, face - 0.002, height * 0.55), (0.004, 0.003, height * 0.45), 0.001, outline=False)
    else:
        sg = -1 if face < 0 else 1             # 牆在 face 的外側（遠離人）
        pbox('wall', (face + sg * th, 0, height / 2), (th, width / 2, height / 2), 0.012)
        pbox('wallbase', (face - sg * 0.012, 0, 0.06), (0.016, width / 2, 0.06), 0.004)
        for y_ in (-0.7, -0.35, 0.0, 0.35, 0.7):
            pbox('wallbase', (face - sg * 0.002, y_, height * 0.55), (0.003, 0.004, height * 0.45), 0.001, outline=False)
