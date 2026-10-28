"""Offline mock of the Printify v1 endpoints the Rail uses. No real credentials, no network.
MOCK_MODE selects behaviour: ok | thin | dup | err | wrongshop | synced | badprice | loss | visignored | vismissing"""
import http.server, json, os, urllib.parse
LOG = open('requests.log', 'a')
MODE = os.environ.get('MOCK_MODE', 'ok')
SIZES = ["XS", "S", "M", "L", "XL", "2XL", "3XL", "4XL", "5XL"]
PRICE = {"S": 4900, "M": 4900, "L": 4900, "XL": 4900, "2XL": 5400, "3XL": 5900, "4XL": 6400}
PID = "65a1b2c3d4e5f60718293a4b"
STATE = {"published": False, "visible": True}

def product():
    v = []
    for i, s in enumerate(["S", "M", "L", "XL", "2XL", "3XL", "4XL"]):
        price = PRICE[s] + (100 if MODE == "badprice" and s == "M" else 0)
        cost = 7000 if MODE == "loss" and s == "4XL" else 1550 + 200 * i
        v.append({"id": 2000 + i, "title": f"Black / {s}", "price": price, "cost": cost, "is_enabled": True})
    ext = {"id": "10299999999999", "handle": "gg-athletic-everyday-tee"} if (STATE["published"] or MODE == "synced") else None
    p = {"id": PID, "title": "GG ATHLETIC™ Everyday Tee", "blueprint_id": 12, "visible": STATE["visible"], "is_locked": False, "variants": v,
         "print_areas": [{"variant_ids": [x["id"] for x in v], "placeholders": [{"position": "front", "images": [{"id": "img_mock_1"}]}]}],
         "images": [{"src": "https://images-api.printify.com/mock/front.jpg", "position": "front", "is_default": True}]}
    if ext: p["external"] = ext
    if MODE == "vismissing": p.pop("visible")
    return p

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj):
        b = json.dumps(obj).encode(); self.send_response(code)
        self.send_header('Content-Type', 'application/json'); self.end_headers(); self.wfile.write(b)
    def handle_any(self):
        n = int(self.headers.get('Content-Length') or 0); body = self.rfile.read(n).decode() if n else ''
        auth = self.headers.get('Authorization', '')
        u = urllib.parse.urlparse(self.path); p = u.path.split('/v1', 1)[1]; q = urllib.parse.parse_qs(u.query)
        LOG.write(json.dumps({"m": self.command, "p": p, "auth_ok": auth == "Bearer MOCKTOKEN", "body": body}) + "\n"); LOG.flush()
        if auth != "Bearer MOCKTOKEN": return self.send(401, {"error": "unauthorized"})
        if self.command == "DELETE" or '/orders' in p: return self.send(500, {"error": "FORBIDDEN CALL"})
        if p == "/shops.json":
            sid = 11111 if MODE == "wrongshop" else 29470786
            return self.send(200, [{"id": sid, "title": "GOD GEAR", "sales_channel": "shopify"}])
        if p == "/catalog/blueprints.json":
            return self.send(200, [{"id": 12, "title": "Unisex Jersey Tee", "brand": "Bella+Canvas", "model": "3001"},
                                   {"id": 706, "title": "Unisex Garment-Dyed T-shirt", "brand": "Comfort Colors", "model": "1717"}])
        if p == "/catalog/blueprints/12.json": return self.send(200, {"id": 12, "title": "Unisex Jersey Short Sleeve Tee", "brand": "Bella+Canvas", "model": "3001"})
        if p == "/catalog/blueprints/706.json": return self.send(200, {"id": 706, "title": "Unisex Garment-Dyed T-shirt", "brand": "Comfort Colors", "model": "1717"})
        if p.endswith("/print_providers.json"): return self.send(200, [{"id": 99, "title": "Mock Provider", "location": {"country": "US"}}])
        if p.endswith("/variants.json"):
            if MODE == "thin": v = [{"id": 1000 + i, "options": {"color": "Black", "size": s}} for i, s in enumerate(["S", "M", "L", "XL", "2XL"])]
            else: v = [{"id": 1000 + 10 * j + i, "options": {"color": c, "size": s}} for j, c in enumerate(["Black", "White"]) for i, s in enumerate(SIZES)]
            return self.send(200, {"id": 99, "variants": v})
        if p == "/shops/29470786/products.json" and self.command == "GET":
            page = int(q.get("page", ["1"])[0])
            data = [{"id": "aaaaaaaaaaaaaaaaaaaaaaaa", "title": "Other product"}]
            if MODE == "dup" and page == 2: data.append({"id": PID, "title": "GG ATHLETIC™ Everyday Tee"})
            return self.send(200, {"current_page": page, "last_page": 2, "data": data})
        if p == "/uploads/images.json" and self.command == "POST":
            return self.send(200, {"id": "img_mock_1", "width": 4248, "height": 462})
        if p == "/shops/29470786/products.json" and self.command == "POST":
            if MODE == "err": return self.send(400, {"errors": {"reason": "mock validation"}})
            open('product_payload.json', 'w').write(body)
            return self.send(200, product())
        if p == f"/shops/29470786/products/{PID}.json" and self.command == "PUT":
            j = json.loads(body or "{}")
            if set(j) != {"visible"}: return self.send(500, {"error": "UNEXPECTED UPDATE FIELDS"})
            if MODE != "visignored": STATE["visible"] = j["visible"]
            return self.send(200, product())
        if p == f"/shops/29470786/products/{PID}.json": return self.send(200, product())
        if p == f"/shops/29470786/products/{PID}/publish.json" and self.command == "POST":
            if STATE["visible"] is not False: return self.send(500, {"error": "PUBLISHED WHILE VISIBLE"})
            STATE["published"] = True; open('publish_payload.json', 'w').write(body)
            return self.send(200, {})
        return self.send(404, {"error": "not found"})
    do_GET = do_POST = do_PUT = do_DELETE = handle_any

http.server.ThreadingHTTPServer(('127.0.0.1', 8765), H).serve_forever()
