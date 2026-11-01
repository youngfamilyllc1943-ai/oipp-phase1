import json, os, urllib.request
T=os.environ['T'].strip(); S='18823775'
RAW='https://raw.githubusercontent.com/youngfamilyllc1943-ai/oipp-phase1/main/rail/art/pf'
body={"recipient":{"name":"Estimate Only","address1":"100 Main St","city":"Fort Wayne","state_code":"IN","country_code":"US","zip":"46802"},
 "items":[{"variant_id":15115,"quantity":1,
   "files":[{"type":"embroidery_chest_center","url":RAW+"/wm-black.png"},{"type":"embroidery_sleeve_left_top","url":RAW+"/badgeG-oldgold.png"},{"type":"back","url":RAW+"/backG-black.png"}],
   "options":[{"id":"thread_colors_chest_center","value":["#000000"]},{"id":"thread_colors_sleeve_left_top","value":["#A67843"]}]}]}
req=urllib.request.Request('https://api.printful.com/orders/estimate-costs',method='POST',data=json.dumps(body).encode(),
  headers={'Authorization':'Bearer '+T,'X-PF-Store-Id':S,'Content-Type':'application/json','User-Agent':'GOD-GEAR-Rail'})
try:
    with urllib.request.urlopen(req,timeout=60) as r: c,j=r.status,json.load(r)
except urllib.error.HTTPError as e: c,j=e.code,json.load(e)
print(f"::notice title=estimate::HTTP {c} {json.dumps(j.get('result',j.get('error')))[:1500]}")
