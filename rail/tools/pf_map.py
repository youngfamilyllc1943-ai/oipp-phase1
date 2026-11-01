# Emits Printful catalog variant ids per product/color/size for the line spec (one notice per product).
import json, os, sys, urllib.request
T=os.environ['T'].strip()
spec=json.load(open('rail/line/gg-line.json'))['products']
def get(p):
    r=urllib.request.Request('https://api.printful.com'+p,headers={'Authorization':'Bearer '+T,'User-Agent':'GOD-GEAR-Rail'})
    with urllib.request.urlopen(r,timeout=60) as x: return json.load(x)
for k,s in spec.items():
    vs=get(f"/products/{s['catalog']}")['result']['variants']
    m={}
    for c in s['colors']:
        for z in s['price']:
            hit=[v['id'] for v in vs if v['color']==c and v['size']==z]
            m.setdefault(c,{})[z]=hit[0] if hit else None
    print(f"::notice title=map {k}::{json.dumps(m,separators=(',',':'))}"[:3900])
