"""Tonal (tone-on-tone) recolor of the GOD GEAR master art.
Keeps the bevel/metal detail by mapping the art's luminance into a narrow band
around the garment color. Usage: tonal.py master.png out.png HEXCOLOR [mode]
mode: auto (default) | dark (ink darker than garment) | light (ink lighter)."""
import sys
import numpy as np
from PIL import Image

def tonal(src, hexcolor, mode="auto"):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    lum = (0.2126*rgb[...,0] + 0.7152*rgb[...,1] + 0.0722*rgb[...,2])[..., None]
    g = np.array([int(hexcolor[i:i+2], 16) for i in (0, 2, 4)], np.float32) / 255.0
    gl = float(0.2126*g[0] + 0.7152*g[1] + 0.0722*g[2])
    if mode == "auto":
        mode = "light" if gl < 0.35 else "dark"
    if gl < 0.08:  # black / near-black garment: charcoal-to-graphite tones (pure black ink would vanish)
        lo, hi = np.array([0.10]*3), np.array([0.42]*3)
    elif gl > 0.80:  # white / cream garment: soft white-on-white tones
        lo, hi = g*0.70, g*0.95
    elif mode == "light":
        lo, hi = np.clip(g*1.15+0.04, 0, 1), np.clip(g*1.6+0.22, 0, 1)
    else:
        lo, hi = g*0.42, g*0.80
    out = lo + (hi - lo) * lum
    res = np.concatenate([out, alpha], -1)
    return Image.fromarray((np.clip(res, 0, 1)*255).astype(np.uint8), "RGBA")

if __name__ == "__main__":
    src, dst, hexc = sys.argv[1:4]
    mode = sys.argv[4] if len(sys.argv) > 4 else "auto"
    tonal(src, hexc.lstrip("#"), mode).save(dst, optimize=True)
