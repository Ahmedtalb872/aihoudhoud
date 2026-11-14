from PIL import Image, ImageDraw, ImageFilter
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SRC = os.path.join(REPO, "assets/images/logo_icon.png")
OUT = HERE

# Trend Ride brand green (see lib/core/constants/colors.dart).
BRAND = (46, 158, 21)

def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / max(h - 1, 1)
        d.point((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h), Image.LANCZOS)

# The current logo is already a complete, self-contained circular badge
# (icon + "Trend Ride" wordmark + tagline all baked into one dark-background
# image, unlike the previous brand's separate transparent mark + text this
# script used to compose itself) - so both assets below just place that
# finished badge on a plain backdrop instead of redrawing text next to it.
logo = Image.open(SRC).convert("RGBA")

# ---------------------------------------------------------------- app icon
# 512x512, fully opaque (Play masks its own rounded corners on top). The
# logo is already square and fills its own frame, so this is just a resize.
S = 512
icon = logo.resize((S, S), Image.LANCZOS).convert("RGB")
icon.save(f"{OUT}/icon_512.png")

# --------------------------------------------------------- feature graphic
# 1024x500. Play crops the edges on some surfaces, so the logo stays
# centered within the middle ~80%.
W, H = 1024, 500
feat = vgrad((W, H), (10, 36, 22), (6, 18, 11)).convert("RGBA")

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse(
    [W // 2 - 260, H // 2 - 260, W // 2 + 260, H // 2 + 260], fill=BRAND + (60,)
)
feat = Image.alpha_composite(feat, glow.filter(ImageFilter.GaussianBlur(90)))

mh = 460
sc = mh / logo.height
mark = logo.resize((round(logo.width * sc), mh), Image.LANCZOS)
feat.paste(mark, ((W - mark.width) // 2, (H - mh) // 2), mark)

feat.convert("RGB").save(f"{OUT}/feature_graphic_1024x500.png")

for f in ("icon_512.png", "feature_graphic_1024x500.png"):
    p = f"{OUT}/{f}"
    print(f, Image.open(p).size, f"{os.path.getsize(p)/1024:.0f} KB")
