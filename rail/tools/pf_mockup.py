import json, os, sys, time, urllib.request
T=os.environ['T'].strip(); S='18823775'; spec=json.load(open(sys.argv[1]))
RAW='https://raw.githubusercontent.com/youngfamilyllc1943-ai/oipp-phase1/main/rail/art/pf'
def call(method, path, body=None):
    req=urllib.request.Request('https://api.printful.com'+path, method=method, data=json.dumps(body).encode() if body else None,
        headers={'Authorization':'Bearer '+T,'X-PF-Store-Id':S,'Content-Type':'application/json','User-Agent':'GOD-GEAR-Rail'})
    try:
        with urllib.request.urlopen(req, timeout=60) as r: return r.status, json.load(r)
    except urllib.error.HTTPError as e:
        try: return e.code, json.load(e)
        except Exception: return e.code, {}
def note(t,m): print(f'::notice title={t}::{m}'[:3000]); sys.stdout.flush()
cp=spec['catalog_product']; _,cat=call('GET',f'/products/{cp}')
for col,cs in spec['colors'].items():
    pv=[v['id'] for v in cat['result']['variants'] if v['color']==cs['pf'] and v['size']=='M']
    if not pv: note('m '+col,'no variant'); continue
    body={'variant_ids':pv,'format':'jpg','files':[
        {'placement':'embroidery_chest_center','image_url':f"{RAW}/{cs['wm']}.png"},
        {'placement':'embroidery_sleeve_left_top','image_url':f"{RAW}/{spec['sleeve']}.png"},
        {'placement':'back','image_url':f"{RAW}/{cs['back']}.png"}],
      'options':[{'id':'thread_colors_chest_center','value':[cs['thread']]},{'id':'thread_colors_sleeve_left_top','value':[spec['sleeve_thread']]}]}
    c,r=call('POST',f'/mockup-generator/create-task/{cp}',body)
    tk=(r.get('result') or {}).get('task_key') if isinstance(r.get('result'),dict) else None
    if not tk: note('m '+col,f'HTTP {c} {json.dumps(r.get("error") or r.get("result"))[:400]}'); continue
    for i in range(24):
        time.sleep(5); c,r=call('GET',f'/mockup-generator/task?task_key={tk}')
        st=r['result']['status']
        if st in ('completed','failed'): break
    res=r['result']
    urls=[]
    for m in res.get('mockups',[]):
        urls.append(m['mockup_url']); urls+= [x['url'] for x in m.get('extra',[])]
    note('m '+col, f"{st} {json.dumps(urls)} {json.dumps(res.get('error',''))[:300]}")
    time.sleep(3)
