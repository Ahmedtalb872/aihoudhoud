from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SRC   = os.path.join(REPO, "assets/images/logo_icon.png")
OUT   = HERE
FONT  = os.path.join(HERE, "fonts/cairo800.ttf")
FONT6 = os.path.join(HERE, "fonts/cairo600.ttf")

GOLD      = (237, 158,  53)
GOLD_DEEP = (166, 101,  12)
TEAL      = ( 16,  78,  85)
NAVY      = ( 15,  23,  42)
CREAM_HI  = (255, 250, 240)
CREAM_LO  = (250, 226, 190)

def trim(im):
    """Crop the logo down to its non-transparent bounding box."""
    bbox = im.getchannel("A").getbbox()
    return im.crop(bbox)

def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        t = y / max(h - 1, 1)
        d.point((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((w, h), Image.LANCZOS)

logo = trim(Image.open(SRC).convert("RGBA"))

# ---------------------------------------------------------------- app icon
# 512x512, fully opaque (Play masks its own rounded corners on top).
S = 512
icon = vgrad((S, S), CREAM_HI, CREAM_LO).convert("RGBA")

# a soft gold halo behind the mark so it lifts off the background
halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(halo).ellipse([70, 70, S - 70, S - 70], fill=GOLD + (58,))
icon = Image.alpha_composite(icon, halo.filter(ImageFilter.GaussianBlur(46)))

box = int(S * 0.78)
lw, lh = logo.size
sc = min(box / lw, box / lh)
mark = logo.resize((round(lw * sc), round(lh * sc)), Image.LANCZOS)
icon.paste(mark, ((S - mark.width) // 2, (S - mark.height) // 2 + 6), mark)
icon.convert("RGB").save(f"{OUT}/icon_512.png")

# --------------------------------------------------------- feature graphic
# 1024x500. Play crops the edges on some surfaces, so everything that
# matters stays inside the middle ~80%.
W, H = 1024, 500
feat = vgrad((W, H), (11, 58, 64), (7, 32, 38)).convert("RGBA")

glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([W - 620, -220, W - 20, 380], fill=GOLD + (70,))
gd.ellipse([-180, H - 200, 320, H + 220], fill=(20, 184, 166, 45))
feat = Image.alpha_composite(feat, glow.filter(ImageFilter.GaussianBlur(120)))

# logo on the right (RTL layout: mark leads, text follows to its left)
mh = 300
sc = mh / logo.height
lm = logo.resize((round(logo.width * sc), mh), Image.LANCZOS)
feat.paste(lm, (W - lm.width - 78, (H - mh) // 2), lm)

d = ImageDraw.Draw(feat)
title = ImageFont.truetype(FONT, 92)
sub   = ImageFont.truetype(FONT6, 40)
tag   = ImageFont.truetype(FONT6, 30)

tx = W - lm.width - 128           # right edge of the text column
d.text((tx, 150), "الهدهد", font=title, fill=(255, 252, 245), anchor="rs",
       language="ar", direction="rtl")
d.text((tx, 218), "تطبيق الكابتن", font=sub, fill=GOLD, anchor="rs",
       language="ar", direction="rtl")
d.text((tx, 300), "اقبل الطلبات · وصّل الركاب · اربح يوميًا", font=tag,
       fill=(178, 205, 208), anchor="rs", language="ar", direction="rtl")

d.rounded_rectangle([tx - 250, 336, tx, 396], radius=30, fill=GOLD)
d.text((tx - 125, 375), "موريتانيا", font=tag, fill=(38, 24, 4), anchor="ms",
       language="ar", direction="rtl")

feat.convert("RGB").save(f"{OUT}/feature_graphic_1024x500.png")

for f in ("icon_512.png", "feature_graphic_1024x500.png"):
    p = f"{OUT}/{f}"
    print(f, Image.open(p).size, f"{os.path.getsize(p)/1024:.0f} KB")
