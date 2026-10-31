import traceback
try:
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
    _,pfs=call('GET',f'/mockup-generator/printfiles/{cp}'); pf=pfs['result']
    _,pfe=call('GET',f'/mockup-generator/printfiles/{cp}?technique=EMBROIDERY'); pe=pfe['result']
    pfile={p['printfile_id']:p for p in pf['printfiles']+pe['printfiles']}
    for vpe in pe['variant_printfiles']:
        for x in pf['variant_printfiles']:
            if x['variant_id']==vpe['variant_id']: x['placements'].update(vpe['placements'])
    import struct
    def png_size(url):
        with urllib.request.urlopen(url,timeout=60) as r: h=r.read(32)
        return struct.unpack('>II',h[16:24])
    def pos(vid, placement, url, frac_w, top_frac):
        vp=[x for x in pf['variant_printfiles'] if x['variant_id']==vid][0]['placements']
        note('placements',json.dumps(list(vp.keys()))) if placement not in vp else None
        f=pfile[vp[placement]]; AW,AH=f['width'],f['height']; w,h=png_size(url)
        W=int(AW*frac_w); H=int(W*h/w)
        if H>AH: H=AH; W=int(H*w/h)
        return {'area_width':AW,'area_height':AH,'width':W,'height':H,'top':int((AH-H)*top_frac),'left':int((AW-W)/2)}
    for col,cs in [(k,v) for k,v in spec['colors'].items() if (os.environ.get('ONLY') or k)==k]:
        pv=[v['id'] for v in cat['result']['variants'] if v['color']==cs['pf'] and v['size']=='M']
        if not pv: note('m '+col,'no variant'); continue
        u1,u2,u3=f"{RAW}/{cs['wm']}.png",f"{RAW}/{spec['sleeve']}.png",f"{RAW}/{cs['back']}.png"
        jobs=[('emb',{'variant_ids':pv,'format':'jpg','technique':'EMBROIDERY','files':[
            {'placement':'embroidery_chest_center','image_url':u1,'position':pos(pv[0],'embroidery_chest_center',u1,1.0,0.5)},
            {'placement':'embroidery_sleeve_left_top','image_url':u2,'position':pos(pv[0],'embroidery_sleeve_left_top',u2,1.0,0.5)}],
          'options':[{'id':'thread_colors_chest_center','value':[cs['thread']]},{'id':'thread_colors_sleeve_left_top','value':[spec['sleeve_thread']]}]}),
          ('back',{'variant_ids':pv,'format':'jpg','technique':'DTG','files':[{'placement':'back','image_url':u3,'position':pos(pv[0],'back',u3,0.7,0.15)}]})]
        for tag,body in jobs:
            c,r=call('POST',f'/mockup-generator/create-task/{cp}',body)
            tk=(r.get('result') or {}).get('task_key') if isinstance(r.get('result'),dict) else None
            if not tk:
                note(f'm {col} {tag}',f'HTTP {c} {json.dumps(r.get("error") or r.get("result"))[:400]}'); time.sleep(62); continue
            for i in range(24):
                time.sleep(5); c,r=call('GET',f'/mockup-generator/task?task_key={tk}')
                st=r['result']['status']
                if st in ('completed','failed'): break
            res=r['result']; urls=[]
            for m in res.get('mockups',[]):
                urls.append(m['mockup_url']); urls+=[x['url'] for x in m.get('extra',[])]
            note(f'm {col} {tag}', f"{st} {json.dumps(urls)} {json.dumps(res.get('error',''))[:300]}")
            time.sleep(62)
except Exception as e:
    print('::error title=py::'+traceback.format_exc().replace('\n',' | ')[-1500:])
    raise
