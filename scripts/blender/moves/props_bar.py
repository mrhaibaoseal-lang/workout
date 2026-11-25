# 器材：單槓（引體向上、反手引體、懸垂舉膝用）。負責：Claude（動作）。每次都會載入，只定義函式（呼叫才建物件）。
# 使用者沒有單槓，動作庫有這些動作，所以畫一個獨立式單槓架：兩支立柱＋橫槓。橫槓的父物件叫 bar（clipcheck 不算手握槓的穿透）。

def build_pullbar(bz, by=0.0, half=0.60):
    """獨立單槓：橫槓高 bz（中心）、y＝by，立柱在 x＝±half。回傳橫槓物件（固定不動）"""
    bar = bpy.data.objects.new('bar', None); sc.collection.objects.link(bar)
    for o_ in (pcyl('chrome', (0, by, bz), 0.017, 2 * half + 0.1, (1, 0, 0), n=16),
               pcyl('rubber', (0.45, by, bz), 0.0195, 0.10, (1, 0, 0), n=12), pcyl('rubber', (-0.45, by, bz), 0.0195, 0.10, (1, 0, 0), n=12)):
        o_.parent = bar
    for sx in (1, -1):
        pbox('frame', (half * sx, by, (bz + 0.03) / 2), (0.028, 0.028, (bz + 0.03) / 2), 0.006)          # 立柱
        pbox('frame', (half * sx, by + 0.18, 0.03), (0.04, 0.30, 0.03), 0.008)                           # 底座（往後伸，不擋腳）
        pbox('frame', (half * sx, by - 0.10, 0.03), (0.04, 0.06, 0.03), 0.008)
        pbox('rubber', (half * sx, by + 0.30, 0.008), (0.045, 0.045, 0.008), 0.003)
    return bar
