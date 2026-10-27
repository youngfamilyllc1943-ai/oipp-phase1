#!/usr/bin/env bash
# GOD GEAR Printify -> Shopify sync for ONE product built by printify_draft.sh.
# The only publish call in the Rail. It runs only after every check below passes.
# Printify publishing creates the product in the connected Shopify store; SU-WaB sets it to DRAFT
# in Shopify immediately afterwards and verifies it. No order, delete or webhook call exists.
# Env: T, SHOP_ID, SPEC, PID (24-hex Printify product id), BASE (optional), POLL (seconds, default 180)
set -euo pipefail
BASE=${BASE:-https://api.printify.com/v1}
POLL=${POLL:-180}
: "${T:?}" "${SHOP_ID:?}" "${SPEC:?}" "${PID:?}"
[[ "$PID" =~ ^[0-9a-f]{24}$ ]] || { echo "REJECTED: product id"; exit 2; }

get() { code=$(curl -sS -o resp.json -w '%{http_code}' -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" "$BASE$1")
  echo "GET $1 -> HTTP $code"; [ "${code:0:1}" = 2 ] || { echo "error: $(head -c 400 resp.json)"; rm -f resp.json; exit 1; }; }

api_shops() { get "/shops.json"
  ok=$(jq --argjson id "$SHOP_ID" '[.[] | select(.id==$id and .sales_channel=="shopify")] | length' resp.json)
  echo "god_gear_shop_connected=$([ "$ok" = 1 ] && echo true || echo false)"; [ "$ok" = 1 ] || exit 1; }
api_shops

get "/shops/$SHOP_ID/products/$PID.json"
cp resp.json product.json
fail=0
for c in \
 "title|.title == \$s[0].title" \
 "not-already-synced|((.external // {}) | .id // null) == null" \
 "not-locked|(.is_locked // false) == false" \
 "enabled-variant-count|([.variants[]|select(.is_enabled)]|length) == (\$s[0].sizes|length)" \
 "prices-match-spec|all(.variants[]|select(.is_enabled); .price == \$s[0].price_cents[(.title|split(\" / \")|map(select(. as \$z | \$s[0].sizes|index(\$z)))|first)])" \
 "no-loss-variant|all(.variants[]|select(.is_enabled); (.cost == null) or (.price > .cost))" \
 "front-print-present|any(.print_areas[].placeholders[]; .position==\"front\" and (.images|length)>0)"; do
  n=${c%%|*}; e=${c#*|}
  if jq -e --slurpfile s "$SPEC" "$e" product.json >/dev/null 2>&1; then echo "PASS $n"; else echo "FAIL $n"; fail=1; fi
done
[ "$fail" = 0 ] || { echo "STOP: checks failed, nothing published"; exit 1; }

cat > pub.json <<'J'
{"title":true,"description":true,"images":true,"variants":true,"tags":true,"keyFeatures":true,"shipping_template":true}
J
code=$(curl -sS -o resp.json -w '%{http_code}' -X POST -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" -H "Content-Type: application/json" --data @pub.json "$BASE/shops/$SHOP_ID/products/$PID/publish.json")
echo "POST publish -> HTTP $code"; [ "${code:0:1}" = 2 ] || { echo "error: $(head -c 400 resp.json)"; exit 1; }

# Wait for the Shopify channel to report back its product id.
end=$((SECONDS+POLL))
while [ $SECONDS -lt $end ]; do
  get "/shops/$SHOP_ID/products/$PID.json"
  ext=$(jq -r '(.external // {}) | .id // empty' resp.json)
  if [ -n "$ext" ]; then echo "SYNCED shopify_product_id=$ext handle=$(jq -r '.external.handle // "n/a"' resp.json)"; echo "NEXT: SU-WaB sets Shopify product $ext to DRAFT and verifies SKUs"; rm -f resp.json; exit 0; fi
  sleep 10
done
echo "PENDING: publish accepted, Shopify id not reported within ${POLL}s (is_locked=$(jq -r '.is_locked' resp.json)). SU-WaB checks Shopify directly."
rm -f resp.json
