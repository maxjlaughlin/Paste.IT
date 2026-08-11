#!/usr/bin/env python3
"""
Generates Paste.IT's app icon (as a macOS .iconset source) and the menu
bar template glyph. Run this whenever the design changes; commit the
resulting PNGs (source assets, not build output).

Requires: pip install Pillow
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONSET_DIR = os.path.join(ROOT, "Assets", "AppIcon.iconset")
LOGO_PATH = os.path.join(ROOT, "Assets", "logo.png")
MENU_BAR_PATH = os.path.join(ROOT, "Sources", "PasteIT", "Resources", "MenuBarIcon.png")

NAVY = (27, 42, 74, 255)      # #1B2A4A
TEAL = (18, 182, 201, 255)    # #12B6C9
WHITE = (255, 255, 255, 255)

MASTER_SIZE = 2048  # supersampled, downscaled for anti-aliasing


def diagonal_gradient(size, color_a, color_b):
    small = 256
    grad = Image.new("RGB", (small, small))
    px = grad.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            r = round(color_a[0] + (color_b[0] - color_a[0]) * t)
            g = round(color_a[1] + (color_b[1] - color_a[1]) * t)
            b = round(color_a[2] + (color_b[2] - color_a[2]) * t)
            px[x, y] = (r, g, b)
    return grad.resize((size, size), Image.BICUBIC)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def draw_clipboard(draw, size):
    # Clipboard body
    margin_x = size * 0.27
    margin_top = size * 0.20
    margin_bottom = size * 0.16
    body = [margin_x, margin_top, size - margin_x, size - margin_bottom]
    body_radius = size * 0.045
    draw.rounded_rectangle(body, radius=body_radius, fill=WHITE)

    # Clip tab at the top
    tab_w = size * 0.22
    tab_h = size * 0.075
    tab_x0 = (size - tab_w) / 2
    tab_y0 = margin_top - tab_h * 0.55
    draw.rounded_rectangle(
        [tab_x0, tab_y0, tab_x0 + tab_w, tab_y0 + tab_h],
        radius=tab_h * 0.4,
        fill=NAVY,
    )

    # Text lines inside the clipboard
    line_h = size * 0.035
    line_x0 = body[0] + size * 0.09
    line_x_full = body[2] - size * 0.09
    line_gap = size * 0.11
    first_y = body[1] + size * 0.14

    widths = [1.0, 0.85]
    for i, w in enumerate(widths):
        y0 = first_y + i * line_gap
        x1 = line_x0 + (line_x_full - line_x0) * w
        draw.rounded_rectangle([line_x0, y0, x1, y0 + line_h], radius=line_h / 2, fill=NAVY)

    # Third line, shorter, followed by a teal "typing cursor" block —
    # the visual cue for "pastes by typing", not by clipboard sync.
    y0 = first_y + 2 * line_gap
    short_w = 0.45
    x1 = line_x0 + (line_x_full - line_x0) * short_w
    draw.rounded_rectangle([line_x0, y0, x1, y0 + line_h], radius=line_h / 2, fill=NAVY)

    cursor_w = size * 0.045
    cursor_gap = size * 0.03
    draw.rectangle([x1 + cursor_gap, y0, x1 + cursor_gap + cursor_w, y0 + line_h], fill=TEAL)


def build_master_icon():
    size = MASTER_SIZE
    bg = diagonal_gradient(size, NAVY[:3], TEAL[:3]).convert("RGBA")
    mask = rounded_mask(size, radius=size * 0.225)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(bg, (0, 0), mask)

    draw = ImageDraw.Draw(canvas)
    draw_clipboard(draw, size)
    return canvas


def build_menu_bar_glyph(size=256):
    # Monochrome (black + alpha) template glyph — macOS tints this
    # automatically for light/dark menu bars, so no color is baked in.
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    margin_x = size * 0.22
    margin_top = size * 0.14
    margin_bottom = size * 0.12
    body = [margin_x, margin_top, size - margin_x, size - margin_bottom]
    line_w = max(2, round(size * 0.055))
    draw.rounded_rectangle(body, radius=size * 0.06, outline=(0, 0, 0, 255), width=line_w)

    tab_w = size * 0.26
    tab_h = size * 0.09
    tab_x0 = (size - tab_w) / 2
    tab_y0 = margin_top - tab_h * 0.5
    draw.rounded_rectangle(
        [tab_x0, tab_y0, tab_x0 + tab_w, tab_y0 + tab_h],
        radius=tab_h * 0.4,
        fill=(0, 0, 0, 255),
    )

    line_h = max(2, round(size * 0.045))
    line_x0 = body[0] + size * 0.13
    line_x_full = body[2] - size * 0.13
    line_gap = size * 0.15
    first_y = body[1] + size * 0.18
    for i, w in enumerate([1.0, 0.65]):
        y0 = first_y + i * line_gap
        x1 = line_x0 + (line_x_full - line_x0) * w
        draw.rounded_rectangle([line_x0, y0, x1, y0 + line_h], radius=line_h / 2, fill=(0, 0, 0, 255))

    return canvas


ICONSET_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def main():
    os.makedirs(ICONSET_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(MENU_BAR_PATH), exist_ok=True)

    master = build_master_icon()

    for name, px in ICONSET_SIZES:
        resized = master.resize((px, px), Image.LANCZOS)
        resized.save(os.path.join(ICONSET_DIR, name))

    master.resize((1024, 1024), Image.LANCZOS).save(LOGO_PATH)

    glyph = build_menu_bar_glyph(256)
    glyph.resize((64, 64), Image.LANCZOS).save(MENU_BAR_PATH)

    print(f"Wrote iconset to {ICONSET_DIR}")
    print(f"Wrote logo to {LOGO_PATH}")
    print(f"Wrote menu bar glyph to {MENU_BAR_PATH}")


if __name__ == "__main__":
    main()
