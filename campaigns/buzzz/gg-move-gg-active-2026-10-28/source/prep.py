import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops
A="/tmp/claude-0/ev/run-437f5fe/assets/"
def cutout(src, dst, thr=18, feather=1.2, crop=True):
    im=Image.open(A+src).convert("RGB"); w,h=im.size
    # pixels close to white -> candidate background
    g=im.convert("L"); near=g.point(lambda v: 255 if v>=255-thr else 0)
    # flood-fill background connected to the border
    m=near.copy(); seed=128
    for xy in [(0,0),(w-1,0),(0,h-1),(w-1,h-1),(w//2,0),(w//2,h-1),(0,h//2),(w-1,h//2)]:
        if m.getpixel(xy)==255: ImageDraw.floodfill(m, xy, seed)
    bg=m.point(lambda v: 255 if v==seed else 0)
    alpha=ImageChops.invert(bg).filter(ImageFilter.GaussianBlur(feather))
    out=im.convert("RGBA"); out.putalpha(alpha)
    if crop: out=out.crop(alpha.getbbox())
    out.save(dst); print(dst, out.size)
for n in ["move_front","move_back","active_front","active_back"]:
    cutout(n+".jpg", f"img/{n}.png")
cutout("master_logo.jpg","img/logo.png",thr=10,feather=0.8)
# split the master logo: G mark (top) and wordmark lockup (bottom)
lg=Image.open("img/logo.png"); W,H=lg.size
a=lg.getchannel("A"); rows=[sum(1 for x in range(0,W,4) if a.getpixel((x,y))>40) for y in range(H)]
# find the widest empty band in the middle third as the split
best=None; y=H//3
while y<int(H*0.8):
    if rows[y]==0:
        s=y
        while y<H and rows[y]==0: y+=1
        if not best or (y-s)>(best[1]-best[0]): best=(s,y)
    y+=1
print("split band", best)
if best:
    g=lg.crop((0,0,W,best[0])); g=g.crop(g.getchannel("A").getbbox()); g.save("img/gmark.png")
    t=lg.crop((0,best[1],W,H)); t=t.crop(t.getchannel("A").getbbox()); t.save("img/lockup.png"); print(g.size,t.size)
