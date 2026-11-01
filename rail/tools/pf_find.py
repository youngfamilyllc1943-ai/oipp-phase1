import json, os, urllib.request
T=os.environ['T'].strip()
req=urllib.request.Request('https://api.printful.com/products',headers={'Authorization':'Bearer '+T,'User-Agent':'GOD-GEAR-Rail'})
P=json.load(urllib.request.urlopen(req,timeout=60))['result']
terms=['18500','M2580','18000','6245CM','6277','IND20PNT','jogger','sweatpants','shorts','track jacket','all-over print hoodie','beanie','duffle','IND4000','tank']
for t in terms:
    hits=[{'id':p['id'],'t':p['title'][:60],'emb':'EMBROIDERY' in [x['key'] for x in p.get('techniques',[])]} for p in P if t.lower() in (p['title']+' '+p.get('model','')).lower()][:6]
    print(f"::notice title={t}::{json.dumps(hits)}")
