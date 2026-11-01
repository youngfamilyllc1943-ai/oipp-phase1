import json, os, urllib.request, sys
T=os.environ['T'].strip()
def g(p): return json.load(urllib.request.urlopen(urllib.request.Request('https://api.printful.com'+p,headers={'Authorization':'Bearer '+T,'User-Agent':'GOD-GEAR-Rail'}),timeout=60))['result']
for pid in [380,145,898,206,140,586]:
    r=g(f'/products/{pid}'); p=r['product']
    files=[f['type'] for f in p['files'] if 'embroidery' in f['type'] or f['type'] in ('front','back')]
    cols=sorted({v['color'] for v in r['variants']})
    sizes=sorted({v['size'] for v in r['variants']})
    price=min(float(v['price']) for v in r['variants'])
    tm=g(f'/mockup-generator/templates/{pid}')
    groups=sorted({og for t in tm.get('templates',[]) for og in []} )
    og=json.dumps(tm.get('option_groups',[]))[:200] if isinstance(tm,dict) else ''
    print(f"::notice title={pid} {p['model']}::files={files} | base=${price} | sizes={sizes} | colors({len(cols)})={cols[:40]} | groups={og}")
