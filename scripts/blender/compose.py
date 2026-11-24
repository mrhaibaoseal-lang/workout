"""把圖和文字拼成一張 PNG（用 Blender 的影片剪輯器，不需要 PIL）。review_sheet.py 用。
blender -b -P scripts/blender/compose.py -- <spec.json>
spec：{"out": 輸出路徑, "w": 寬, "h": 高, "bg": [r, g, b], "items": [...]}，座標用像素、原點在左上角：
  {"type": "image", "path": 路徑, "x": 左, "y": 上, "w": 寬}（高度照比例）
  {"type": "text", "text": 文字, "x": 左, "y": 上, "size": 字高(像素), "color": [r, g, b], "align": "left"|"center"}
"""
import bpy, sys, json, os

spec = json.load(open(sys.argv[sys.argv.index('--') + 1], encoding='utf-8'))
W, H = spec['w'], spec['h']
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.data.scenes.new('compose'); bpy.context.window.scene = sc
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGB'
sc.view_settings.view_transform = 'Standard'; sc.display_settings.display_device = 'sRGB'
sc.frame_start = sc.frame_end = 1; sc.frame_set(1)
se = sc.sequence_editor_create()
strips = se.strips if hasattr(se, 'strips') else se.sequences
font = None
for fp in (r'C:\Windows\Fonts\msjh.ttc', r'C:\Windows\Fonts\mingliu.ttc'):
    if os.path.exists(fp): font = bpy.data.fonts.load(fp); break

ch = 1
bg = strips.new_effect('bg', 'COLOR', ch, 1, length=1); bg.color = list(spec.get('bg', [0.1, 0.1, 0.12])); ch += 1
for it in spec['items']:
    t = it['type']
    if t == 'image':
        s = strips.new_image(f'i{ch}', it['path'], ch, 1)
        iw, ih = s.elements[0].orig_width, s.elements[0].orig_height
        sc_ = it['w'] / iw
        s.transform.scale_x = s.transform.scale_y = sc_
        s.transform.offset_x = it['x'] + it['w'] / 2 - W / 2
        s.transform.offset_y = H / 2 - (it['y'] + ih * sc_ / 2)
        try: s.fit_method = 'ORIGINAL'
        except Exception: pass
    elif t == 'text':
        s = strips.new_effect(f't{ch}', 'TEXT', ch, 1, length=1)
        s.text = it['text']; s.font_size = it.get('size', 24); s.color = list(it.get('color', [1, 1, 1])) + [1.0]
        if font: s.font = font
        al = it.get('align', 'left')
        s.anchor_x = {'left': 'LEFT', 'center': 'CENTER', 'right': 'RIGHT'}[al]; s.anchor_y = 'TOP'
        s.location = (it['x'] / W, 1 - it['y'] / H)
        s.use_shadow = False
    ch += 1
sc.render.filepath = spec['out']
bpy.ops.render.render(write_still=True)
print('COMPOSE', spec['out'])
