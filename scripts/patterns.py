#!/usr/bin/env python3
"""Write four TV test patterns for checking picture settings by eye.

usage: python3 scripts/patterns.py OUT_DIR

Each pattern is saved as a 3840x2160 PNG and as a 1920x1080 JPEG
(<name>-1080.jpg, quality 100, no chroma subsampling). Some TV image viewers
only open the JPEG variant. Requires Pillow (pip install Pillow).

  black-level  bars of level 1..20 on 0 black: background stays black,
               bar 2 to 4 is just visible
  white-clip   bars of level 230..255 on 220 gray: bars up to ~253-255
               stay distinguishable
  grayscale    smooth ramp and 21 steps: no color tint, no banding
  sharpness    1 px lines and small text on gray: no halos or ringing
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 3840, 2160


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow < 10.1 has a single fixed-size bitmap font
        return ImageFont.load_default()


TITLE = font(72)
SMALL = font(36)


def title(draw, text, fill):
    draw.text((W // 2, 250), text, fill=fill, font=TITLE, anchor="mm")


def bars(background, steps, label_gray, heading):
    img = Image.new("RGB", (W, H), (background,) * 3)
    d = ImageDraw.Draw(img)
    bw = W // (len(steps) + 2)
    for i, level in enumerate(steps):
        x = bw * (i + 1)
        d.rectangle([x + 20, 500, x + bw - 20, 1500], fill=(level,) * 3)
        d.text((x + bw // 2, 1620), str(level), fill=(label_gray,) * 3, font=TITLE, anchor="mm")
    title(d, heading, (label_gray,) * 3)
    return img


def black_level():
    return bars(0, [1, 2, 3, 4, 6, 8, 10, 12, 16, 20], 90,
                "BLACK LEVEL: background black, bar 2-4 just visible")


def white_clip():
    return bars(220, [230, 235, 240, 243, 246, 249, 251, 253, 254, 255], 60,
                "WHITE CLIPPING: bars up to 253-255 distinguishable")


def grayscale():
    img = Image.new("RGB", (W, H), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(W):
        v = round(x * 255 / (W - 1))
        d.line([(x, 0), (x, H // 2 - 1)], fill=(v,) * 3)
    steps = 21
    sw = W / steps
    for i in range(steps):
        v = round(i * 255 / (steps - 1))
        d.rectangle([round(i * sw), H // 2, round((i + 1) * sw) - 1, H - 1], fill=(v,) * 3)
    d.text((W // 4, H - 80), "GRAYSCALE: neutral gray, no tint, no banding",
           fill=(200, 200, 200), font=SMALL, anchor="mm")
    return img


def sharpness():
    img = Image.new("RGB", (W, H), (128, 128, 128))
    d = ImageDraw.Draw(img)
    # Odd coordinates: the 2:1 NEAREST downscale to 1080p keeps odd pixels only.
    for x in range(401, 1602, 8):
        d.line([(x, 501), (x, 1301)], fill=(0, 0, 0))
    for y in range(501, 1302, 8):
        d.line([(2201, y), (3401, y)], fill=(255, 255, 255))
    d.ellipse([1500, 1380, 2340, 1880], outline=(0, 0, 0), width=2)
    d.text((1920, 1980), "The quick brown fox jumps over the lazy dog 0123456789",
           fill=(0, 0, 0), font=SMALL, anchor="mm")
    title(d, "SHARPNESS: no white or dark halos around lines and text", (0, 0, 0))
    return img


PATTERNS = {
    "black-level": black_level,
    "white-clip": white_clip,
    "grayscale": grayscale,
    "sharpness": sharpness,
}


def main(argv):
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    out = argv[1]
    os.makedirs(out, exist_ok=True)
    for name, make in PATTERNS.items():
        img = make()
        png = os.path.join(out, name + ".png")
        jpg = os.path.join(out, name + "-1080.jpg")
        img.save(png)
        # NEAREST keeps 1 px detail and exact levels instead of blending them.
        img.convert("RGB").resize((1920, 1080), Image.NEAREST).save(jpg, quality=100, subsampling=0)
        print(png)
        print(jpg)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
