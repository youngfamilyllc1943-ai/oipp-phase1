"""Measures ART-01 against black garments. Writes art_check.json + art01_on_black.png. Exit 1 if ink is not legible on black."""
import json, sys
from PIL import Image
src, out = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGBA"); w, h = im.size
px = [p for p in im.getdata() if p[3] > 128]
def lum(c):
    def ch(v):
        v /= 255; return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])
n = len(px); transparent = 1 - n / (w * h)
avg = tuple(round(sum(p[i] for p in px) / max(n, 1)) for i in range(3))
L = lum(avg); results = {}
for name, bg in {"pure_black": (0, 0, 0), "bc3001_black_approx": (32, 32, 34)}.items():
    lb = lum(bg); results[name] = round((max(L, lb) + 0.05) / (min(L, lb) + 0.05), 2)
verdict = "PASS" if transparent > 0.2 and min(results.values()) >= 3.0 else "FAIL"
rep = {"size": [w, h], "transparent_fraction": round(transparent, 3), "ink_mean_rgb": avg,
       "contrast_ratio_on": results, "threshold": 3.0, "verdict": verdict}
json.dump(rep, open(f"{out}/art_check.json", "w"), indent=1); print(json.dumps(rep))
canvas = Image.new("RGBA", (1600, 600), (32, 32, 34, 255)); art = im.copy(); art.thumbnail((1400, 400))
canvas.alpha_composite(art, ((1600 - art.width) // 2, (600 - art.height) // 2))
canvas.convert("RGB").save(f"{out}/art01_on_black.png")
sys.exit(0 if verdict == "PASS" else 1)
