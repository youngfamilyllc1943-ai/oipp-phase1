import json, os, sys, time, struct, urllib.request, traceback
sys.excepthook=lambda t,v,tb: print('::error title=trace::'+' | '.join(traceback.format_exception(t,v,tb))[-3000:].replace('\n',' '))
T=os.environ['T'].strip(); S='18823775'; KEY=sys.argv[1]; N=int(os.environ.get('NCOL','2'))
spec=json.load(open('rail/line/gg-line.json'))['products'][KEY]
RAW='https://raw.githubusercontent.com/youngfamilyllc1943-ai/oipp-phase1/main/rail/art/pf'
def call(m,p,b=None):
    r=urllib.request.Request('https://api.printful.com'+p,method=m,data=json.dumps(b).encode() if b else None,
      headers={'Authorization':'Bearer '+T,'X-PF-Store-Id':S,'Content-Type':'application/json','User-Agent':'GOD-GEAR-Rail'})
    try:
        with urllib.request.urlopen(r,timeout=90) as x: return x.status,json.load(x)
    except urllib.error.HTTPError as e:
        try: return e.code,json.load(e)
        except Exception: return e.code,{}
def note(t,m): print(f'::notice title={t}::{m}'[:3500]); sys.stdout.flush()
cp=spec['catalog']; _,cat=call('GET',f'/products/{cp}')
pf={}; 
for tech in ('','?technique=EMBROIDERY'):
    _,r=call('GET',f'/mockup-generator/printfiles/{cp}{tech}'); r=r['result']
    for f in r['printfiles']: pf[f['printfile_id']]=f
    for vp in r['variant_printfiles']: pf.setdefault(('v',vp['variant_id']),{}).update(vp['placements'])
def size(u):
    with urllib.request.urlopen(u,timeout=60) as r: h=r.read(32)
    return struct.unpack('>II',h[16:24])
def mp(vid,pl):
    k=pf[('v',vid)]
    return pl if pl in k else next((x for x in k if x.startswith(pl)), next((x for x in k if 'front' in x or 'chest' in x), pl))
def pos(vid,pl,u,frac=1.0,top=0.5):
    pl=mp(vid,pl)
    if pl not in pf[('v',vid)]: note('placements',json.dumps(list(pf[('v',vid)].keys())))
    f=pf[pf[('v',vid)][pl]]; AW,AH=f['width'],f['height']; w,h=size(u)
    W=int(AW*frac); H=int(W*h/w)
    if H>AH: H=AH; W=int(H*w/h)
    return {'area_width':AW,'area_height':AH,'width':W,'height':H,'top':int((AH-H)*top),'left':int((AW-W)/2)}
def url(art,hexv): return f"{RAW}/{art}-{hexv}.png"
cols=list(spec['colors'].items())[:N]
for col,tonal in cols:
    vs=[v for v in cat['result']['variants'] if v['color']==col]
    pick=[v for v in vs if v['size'] in ('M','One size','S/M')] or vs
    vid=pick[0]['id']
    emb=[{'placement':e['p'],'url':url(e['art'], tonal if e['thread']=='tonal' else e['thread']),'thread':'#'+(tonal if e['thread']=='tonal' else e['thread'])} for e in spec['emb']]
    prn=[{'placement':p['p'],'url':url(p['art'],tonal),'frac':p['frac'],'top':p['top']} for p in spec['print']]
    # estimate
    items=[{'variant_id':vid,'quantity':1,'files':[{'type':e['placement'],'url':e['url']} for e in emb]+[{'type':p['placement'],'url':p['url']} for p in prn],
            'options':[{'id':('thread_colors' if e['placement']=='embroidery_front' else 'thread_colors_'+e['placement'].replace('embroidery_','')),'value':[e['thread']]} for e in emb]}]
    c,r=call('POST','/orders/estimate-costs',{'recipient':{'name':'Estimate','address1':'100 Main St','city':'Fort Wayne','state_code':'IN','country_code':'US','zip':'46802'},'items':items})
    note(f'{KEY} {col} cost',f"HTTP {c} {json.dumps(r['result'].get('costs') if isinstance(r.get('result'),dict) else [r.get('result'),r.get('error')])[:500]}")
    jobs=[('EMBROIDERY',[{'placement':mp(vid,e['placement']),'image_url':e['url'],'position':pos(vid,e['placement'],e['url'])} for e in emb])]
    if prn: jobs.append(('DTG',[{'placement':p['placement'],'image_url':p['url'],'position':pos(vid,p['placement'],p['url'],p['frac'],p['top'])} for p in prn]))
    for tech,files in jobs:
        c,r=call('POST',f'/mockup-generator/create-task/{cp}',{'variant_ids':[vid],'format':'jpg','technique':tech,'files':files})
        tk=(r.get('result') or {}).get('task_key') if isinstance(r.get('result'),dict) else None
        if not tk: note(f'{KEY} {col} {tech}',f'HTTP {c} {json.dumps(r.get("error") or r.get("result"))[:400]}'); time.sleep(62); continue
        for i in range(30):
            time.sleep(5); c,r=call('GET',f'/mockup-generator/task?task_key={tk}')
            if r['result']['status'] in ('completed','failed'): break
        urls=[]
        for m in r['result'].get('mockups',[]): urls.append(m['mockup_url']); urls+=[x['url'] for x in m.get('extra',[])]
        note(f'{KEY} {col} {tech}',f"{r['result']['status']} {json.dumps(urls)}")
        time.sleep(62)
