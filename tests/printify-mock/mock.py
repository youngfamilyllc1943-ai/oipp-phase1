import http.server, json, sys, os
LOG=open('requests.log','a')
SIZES=["XS","S","M","L","XL","2XL","3XL","4XL","5XL"]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def send(self,code,obj):
        b=json.dumps(obj).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.end_headers(); self.wfile.write(b)
    def handle_any(self):
        n=int(self.headers.get('Content-Length') or 0); body=self.rfile.read(n).decode() if n else ''
        auth=self.headers.get('Authorization','')
        LOG.write(json.dumps({"m":self.command,"p":self.path,"auth_ok":auth=="Bearer MOCKTOKEN","body":body})+"\n"); LOG.flush()
        p=self.path.split('/v1',1)[1]
        mode=os.environ.get('MOCK_MODE','ok')
        if auth!="Bearer MOCKTOKEN": return self.send(401,{"error":"unauthorized"})
        if '/publish' in p: return self.send(500,{"error":"PUBLISH CALLED"})
        if p=="/catalog/blueprints/12.json": return self.send(200,{"id":12,"title":"Unisex Jersey Short Sleeve Tee","brand":"Bella+Canvas","model":"3001"})
        if p=="/catalog/blueprints/12/print_providers.json": return self.send(200,[{"id":99,"title":"Mock Provider"}])
        if p.startswith("/catalog/blueprints/12/print_providers/") and p.endswith("/variants.json"):
            if mode=="thin": v=[{"id":1,"options":{"color":"Black","size":"S"}}]
            else: v=[{"id":1000+i,"options":{"color":c,"size":s}} for c in ["Black","White"] for i,s in enumerate(SIZES)]
            return self.send(200,{"id":99,"variants":v})
        if p=="/uploads/images.json" and self.command=="POST":
            return self.send(200,{"id":"img_mock_1","width":4248,"height":462})
        if p=="/shops/29470786/products.json" and self.command=="POST":
            if mode=="err": return self.send(400,{"errors":{"reason":"mock validation"}})
            j=json.loads(body); open('product_payload.json','w').write(json.dumps(j,indent=1,ensure_ascii=False))
            return self.send(200,{"id":"prod_mock_1","visible":False,"variants":j["variants"]})
        return self.send(404,{"error":"not found"})
    do_GET=do_POST=do_PUT=do_DELETE=handle_any
http.server.ThreadingHTTPServer(('127.0.0.1',8765),H).serve_forever()
