#!/usr/bin/env python3
"""Generate app + web assets from the design SVGs in assets/.

Run from the repo root:  python3 tools/build_assets.py
Needs: pip install cairosvg pillow
Outputs (committed to git so CI doesn't need these tools):
  app/Sources/StashBar/Resources/Icons/*.pdf   vector UI icons (template images)
  app/Support/AppIcon.iconset/*.png             macOS app icon (CI runs iconutil)
  web/assets/icons/*.svg, web/assets/brand/*    website copies
"""
import io
import os
import re
import shutil

import cairosvg
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS = os.path.join(ROOT, "assets", "icons")
BRAND = os.path.join(ROOT, "assets", "brand")
APP_RES = os.path.join(ROOT, "app", "Sources", "StashBar", "Resources", "Icons")
ICONSET = os.path.join(ROOT, "app", "Support", "AppIcon.iconset")
WEB = os.path.join(ROOT, "web", "assets")


def ink(svg: str) -> str:
    # Template images: macOS only looks at alpha, colour them pure black.
    return re.sub(r'#(0c0a08|000000|ffffff)', '#000000', svg)


def main():
    os.makedirs(APP_RES, exist_ok=True)
    for name in sorted(os.listdir(ICONS)):
        if not name.endswith(".svg"):
            continue
        svg = ink(open(os.path.join(ICONS, name)).read())
        cairosvg.svg2pdf(bytestring=svg.encode(), write_to=os.path.join(APP_RES, name[:-4] + ".pdf"))

    # Brand marks used inside the app
    for name in ["pin-mark-ink"]:
        svg = open(os.path.join(BRAND, name + ".svg")).read()
        cairosvg.svg2pdf(bytestring=svg.encode(), write_to=os.path.join(APP_RES, name + ".pdf"))
    # Menu-bar variant: thinner strokes so it sits with the system's 16pt template icons.
    mb = open(os.path.join(BRAND, "pin-mark-ink.svg")).read().replace('stroke-width="7"', 'stroke-width="5.2"')
    cairosvg.svg2pdf(bytestring=mb.encode(), write_to=os.path.join(APP_RES, "pin-mark-menubar.pdf"))
    for name in ["app-icon-accent", "app-icon-dark", "app-icon-light"]:
        svg = open(os.path.join(BRAND, name + ".svg")).read()
        cairosvg.svg2pdf(bytestring=svg.encode(), write_to=os.path.join(APP_RES, name + ".pdf"))

    # macOS app icon: Big Sur grid = 824px rounded square centred on a 1024 canvas.
    os.makedirs(ICONSET, exist_ok=True)
    src = open(os.path.join(BRAND, "app-icon-accent.svg")).read()
    master = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    body = Image.open(io.BytesIO(cairosvg.svg2png(bytestring=src.encode(), output_width=824, output_height=824)))
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    master.alpha_composite(shadow)
    master.alpha_composite(body, (100, 92))
    for base in [16, 32, 128, 256, 512]:
        for scale in [1, 2]:
            px = base * scale
            suffix = "" if scale == 1 else "@2x"
            master.resize((px, px), Image.LANCZOS).save(os.path.join(ICONSET, f"icon_{base}x{base}{suffix}.png"))

    # Website copies
    os.makedirs(os.path.join(WEB, "icons"), exist_ok=True)
    os.makedirs(os.path.join(WEB, "brand"), exist_ok=True)
    for name in os.listdir(ICONS):
        shutil.copy(os.path.join(ICONS, name), os.path.join(WEB, "icons", name))
    for name in os.listdir(BRAND):
        shutil.copy(os.path.join(BRAND, name), os.path.join(WEB, "brand", name))
    master.resize((180, 180), Image.LANCZOS).save(os.path.join(WEB, "brand", "apple-touch-icon.png"))
    master.resize((64, 64), Image.LANCZOS).save(os.path.join(WEB, "brand", "favicon-64.png"))
    print("assets generated")


if __name__ == "__main__":
    main()
