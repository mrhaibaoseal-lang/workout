"""Draws the app icon (1024x1024, opaque). Run: python3 scripts/make_icon.py"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 2048  # draw at 2x, downscale for smooth edges
OUT = "Workout/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

# Radial dark stage background.
img = Image.new("RGB", (S, S))
px = img.load()
c0, c1, c2 = hexc("#2B3A66"), hexc("#141B2C"), hexc("#0C0F14")
cx, cy = S * 0.5, S * 0.38
maxd = S * 0.85
for y in range(S):
    for x in range(S):
        t = min(1.0, math.hypot(x - cx, y - cy) / maxd)
        if t < 0.5:
            u = t / 0.5
            col = tuple(int(c0[i] + (c1[i] - c0[i]) * u) for i in range(3))
        else:
            u = (t - 0.5) / 0.5
            col = tuple(int(c1[i] + (c2[i] - c1[i]) * u) for i in range(3))
        px[x, y] = col

# Dumbbell on its own layer, then rotate.
layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
mid = S // 2
bar_h = 120
d.rounded_rectangle([mid - 720, mid - bar_h // 2, mid + 720, mid + bar_h // 2], radius=60, fill=hexc("#E9EDF2"))
def box(x0, x1, half, r, col):
    d.rounded_rectangle([min(x0, x1), mid - half, max(x0, x1), mid + half], radius=r, fill=col)
def plates(sign):
    o = lambda dx: mid + sign * dx
    box(o(300), o(490), 430, 70, hexc("#FF8757"))  # big orange plate
    box(o(510), o(660), 320, 60, hexc("#7D9BFF"))  # blue plate
    box(o(680), o(780), 150, 45, hexc("#E9EDF2"))  # collar
plates(1)
plates(-1)
layer = layer.rotate(35, resample=Image.BICUBIC, center=(mid, mid))

# Soft glow under the dumbbell.
glow = layer.split()[3].filter(ImageFilter.GaussianBlur(70))
glow_col = Image.new("RGB", (S, S), hexc("#7D9BFF"))
img = Image.composite(glow_col, img, glow.point(lambda a: int(a * 0.35)))
img.paste(layer, (0, 0), layer)

img = img.resize((1024, 1024), Image.LANCZOS)
img.save(OUT, optimize=True)
print("saved", OUT)
