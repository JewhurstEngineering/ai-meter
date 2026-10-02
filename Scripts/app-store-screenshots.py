#!/usr/bin/env python3
"""Render App Store marketing screenshots (iPhone 6.9", 1320x2868).

Usage: python3 Scripts/app-store-screenshots.py [source_dir] [out_dir]
Defaults: artifacts/app-store/source -> artifacts/app-store/iphone-6.9
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1320, 2868
FONT = "/System/Library/Fonts/SFNS.ttf"
ACCENT = (74, 222, 128)
BG_TOP = (6, 10, 9)
BG_BOTTOM = (9, 28, 20)

SRC = sys.argv[1] if len(sys.argv) > 1 else "artifacts/app-store/source"
OUT = sys.argv[2] if len(sys.argv) > 2 else "artifacts/app-store/iphone-6.9"

# (file, headline line 1, accent line 2, subtitle, kind)
SLIDES = [
    ("2.png", "Your Cursor usage,", "at a glance", "Included pools, spend and bonus credit in one place", "phone"),
    ("4.jpg", "Right on your", "Home Screen", "Widgets show usage without opening the app", "widgets"),
    ("8.png", "Know where", "the money goes", "Spend by billing cycle and cost per model", "phone"),
    ("5.png", "Get warned", "before the limit", "Set alert levels for each usage pool", "phone"),
    ("3.png", "Readable for", "everyone", "Color-vision palettes, bar patterns and larger text", "phone"),
    ("6.png", "Private", "by design", "Tokens stay in your iPhone's Keychain", "phone"),
]


def font(size, weight="Bold"):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_name(weight)
    return f


def background():
    bg = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    glow = Image.new("L", (W, H), 0)
    ImageDraw.Draw(glow).ellipse((W * 0.1, H * 0.35, W * 0.9, H * 0.85), fill=90)
    glow = glow.filter(ImageFilter.GaussianBlur(260))
    bg.paste(Image.new("RGB", (W, H), (30, 120, 70)), (0, 0), glow)
    return bg


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return m


def clean_status_bar(img):
    """Replace the captured status bar (time, low battery, location) with a tidy 9:41 one."""
    img = img.copy()
    # Wipe the old status bar by smearing the strip, feathered into the content below it.
    strip_h = 175
    strip = img.crop((0, 0, img.width, strip_h))
    smeared = img.crop((0, 12, img.width, 13)).resize(strip.size, Image.BILINEAR)
    fade = Image.linear_gradient("L").rotate(180).resize(strip.size)
    fade = fade.point(lambda v: 255 if v > 50 else round(v * 255 / 50))
    img.paste(smeared, (0, 0), fade)
    d = ImageDraw.Draw(img)
    white = (255, 255, 255)
    d.text((210, 97), "9:41", font=font(58, "Semibold"), fill=white, anchor="mm")
    # Signal bars
    x, base = 852, 114
    for i, h in enumerate((14, 21, 28, 35)):
        d.rounded_rectangle((x + i * 19, base - h, x + i * 19 + 13, base), 3, fill=white)
    # Wi-Fi
    cx, cy = 967, 118
    for r in (46, 31):
        d.arc((cx - r, cy - r, cx + r, cy + r), 225, 315, fill=white, width=9)
    d.pieslice((cx - 16, cy - 16, cx + 16, cy + 16), 225, 315, fill=white)
    # Battery
    bx, by = 1020, 80
    d.rounded_rectangle((bx, by, bx + 78, by + 37), 11, outline=(150, 150, 150), width=3)
    d.rounded_rectangle((bx + 6, by + 6, bx + 72, by + 31), 6, fill=white)
    d.rounded_rectangle((bx + 82, by + 12, bx + 88, by + 25), 3, fill=(150, 150, 150))
    return img


def phone(screen, width):
    scale = width / screen.width
    screen = screen.resize((width, round(screen.height * scale)), Image.LANCZOS)
    sw, sh = screen.size
    screen_r = round(165 * scale)
    bezel = 20
    edge = 5
    bw, bh = sw + 2 * (bezel + edge), sh + 2 * (bezel + edge)
    body = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), screen_r + bezel + edge, fill=(78, 82, 80))
    d.rounded_rectangle((edge, edge, bw - 1 - edge, bh - 1 - edge), screen_r + bezel, fill=(8, 8, 8))
    body.paste(screen, (bezel + edge, bezel + edge), rounded_mask(screen.size, screen_r))
    iw, ih = round(378 * scale), round(111 * scale)
    ix, iy = (bw - iw) // 2, bezel + edge + round(33 * scale)
    d.rounded_rectangle((ix, iy, ix + iw, iy + ih), ih // 2, fill=(0, 0, 0))
    return body


def drop_shadow(canvas, layer, pos, blur=60, opacity=170, offset=30):
    alpha = layer.getchannel("A")
    shadow = Image.new("L", canvas.size, 0)
    shadow.paste(alpha.point(lambda a: opacity if a else 0), (pos[0], pos[1] + offset))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new("RGB", canvas.size, (0, 0, 0)), (0, 0), shadow)
    canvas.paste(layer, pos, layer)


def caption(canvas, line1, line2, sub):
    d = ImageDraw.Draw(canvas)
    big = font(118, "Bold")
    d.text((W // 2, 250), line1, font=big, fill=(255, 255, 255), anchor="ms")
    d.text((W // 2, 385), line2, font=big, fill=ACCENT, anchor="ms")
    d.text((W // 2, 478), sub, font=font(46, "Regular"), fill=(170, 186, 178), anchor="ms")


def widgets_slide(src):
    img = Image.open(src).convert("RGB")
    boxes = [(82, 276, 1124, 760), (82, 877, 1124, 1963)]
    cards = []
    for b in boxes:
        c = img.crop(b).convert("RGBA")
        c.putalpha(rounded_mask(c.size, 66))
        cards.append(c)
    return cards


def render(slide):
    name, l1, l2, sub, kind = slide
    canvas = background()
    caption(canvas, l1, l2, sub)
    src = os.path.join(SRC, name)
    if kind == "phone":
        p = phone(clean_status_bar(Image.open(src).convert("RGB")), 1010)
        drop_shadow(canvas, p, ((W - p.width) // 2, 590))
    else:
        cards = widgets_slide(src)
        target_w = 1150
        y = 640
        for c in cards:
            c = c.resize((target_w, round(c.height * target_w / c.width)), Image.LANCZOS)
            drop_shadow(canvas, c, ((W - target_w) // 2, y), blur=50, opacity=200, offset=24)
            y += c.height + 70
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, slide in enumerate(SLIDES, 1):
        path = os.path.join(OUT, f"{i:02d}-{os.path.splitext(slide[0])[0]}.png")
        render(slide).save(path, optimize=True)
        print(path)


if __name__ == "__main__":
    main()
