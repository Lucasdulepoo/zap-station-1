#!/usr/bin/env python3
"""Gera os ícones do app a partir da geometria da marca (mesma de lib/core/widgets/zap_logo.dart
e assets/brand/zap_station_mark.svg). Requer Pillow.

Uso (na raiz do projeto):  python3 tools/generate_brand_assets.py
"""
import math
import os
import sys

from PIL import Image, ImageDraw

BG = (0x0B, 0x0D, 0x10, 255)
ACCENT = (0x00, 0xD1, 0xFF, 255)
WHITE = (0xFF, 0xFF, 0xFF, 255)

BOLT = [(0.58, 0.14), (0.31, 0.54), (0.48, 0.54), (0.42, 0.86), (0.69, 0.45), (0.52, 0.45)]
SS = 4  # supersampling para bordas suaves

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")


def draw_mark(size, background=None, content_scale=1.0):
    """Desenha a marca em um quadrado `size`. content_scale reduz a marca (zona segura adaptativa)."""
    big = size * SS
    img = Image.new("RGBA", (big, big), background or (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    box = big * content_scale
    off = (big - box) / 2

    def pt(nx, ny):
        return (off + nx * box, off + ny * box)

    hexagon = [
        pt(0.5 + 0.46 * math.cos(math.radians(-90 + 60 * i)), 0.5 + 0.46 * math.sin(math.radians(-90 + 60 * i)))
        for i in range(6)
    ]
    width = max(1, round(box * 0.05))
    d.line(hexagon + [hexagon[0], hexagon[1]], fill=ACCENT, width=width, joint="curve")
    d.polygon([pt(x, y) for x, y in BOLT], fill=WHITE)

    return img.resize((size, size), Image.LANCZOS)


def rounded_icon(size):
    """Ícone legado (pré-Android 8): quadrado arredondado grafite com a marca."""
    big = size * SS
    base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(base).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=BG)
    base = base.resize((size, size), Image.LANCZOS)
    mark = draw_mark(size, None, 0.74)
    base.alpha_composite(mark)
    return base


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print("ok", os.path.relpath(path, ROOT))


def main():
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    adaptive = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}

    for dens, px in legacy.items():
        save(rounded_icon(px), os.path.join(RES, f"mipmap-{dens}", "ic_launcher.png"))
    for dens, px in adaptive.items():
        # 66/108 é a zona segura do ícone adaptativo.
        save(draw_mark(px, None, 0.60), os.path.join(RES, f"mipmap-{dens}", "ic_launcher_foreground.png"))

    save(draw_mark(1024, BG, 0.80), os.path.join(ROOT, "assets", "icon", "icon.png"))
    save(draw_mark(432, None, 0.60), os.path.join(ROOT, "assets", "icon", "icon_foreground.png"))
    save(draw_mark(512, BG, 0.80), os.path.join(ROOT, "assets", "icon", "play_store_512.png"))


if __name__ == "__main__":
    sys.exit(main())
