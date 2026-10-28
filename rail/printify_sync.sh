#!/usr/bin/env bash
# GOD GEAR Printify -> Shopify sync for ONE product built by printify_draft.sh. Hidden-first, fail-closed.
#
# Order of operations (nothing is published unless every step before it passes):
#   1. Shop is the Shopify-connected GOD GEAR shop.
#   2. Product passes the spec checks (title, sizes, prices, no loss variant, front print, not already synced, not locked).
#   3. Product visibility is set to hidden (visible=false) and READ BACK as hidden. If Printify does not
#      report visible=false, the run stops here and nothing is sent to Shopify.
#   4. Publish (the only publish call in the Rail), then wait for the Shopify product id.
# The run never sets a product visible, never archives or edits the existing Shopify draft, never orders or deletes.
# Shopify-side read-back (status + Online Store publication) is done by SU-WaB right after the run;
# the run is not accepted until that read-back shows the product is not on the storefront.
# Env: T, SHOP_ID, SPEC, PID (24-hex Printify product id), BASE (optional), POLL (seconds, default 180), EVIDENCE (dir)
set -euo pipefail
BASE=${BASE:-https://api.printify.com/v1}
POLL=${POLL:-180}
EVIDENCE=${EVIDENCE:-evidence}; mkdir -p "$EVIDENCE"
: "${T:?}" "${SHOP_ID:?}" "${SPEC:?}" "${PID:?}"
[[ "$PID" =~ ^[0-9a-f]{24}$ ]] || { echo "REJECTED: product id"; exit 2; }
PPATH="/shops/$SHOP_ID/products/$PID"

call() { # method path [body-file]; only the three calls this script needs are allowed
  local m=$1 p=$2 b=${3:-} code
  case "$m $p" in
    "GET /shops.json"|"GET $PPATH.json"|"PUT $PPATH.json"|"POST $PPATH/publish.json") ;;
    *) echo "REJECTED: $m $p is not allowed in sync"; exit 3 ;;
  esac
  if [ -n "$b" ]; then
    code=$(curl -sS -o resp.json -w '%{http_code}' -X "$m" -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" -H "Content-Type: application/json" --data @"$b" "$BASE$p")
  else
    code=$(curl -sS -o resp.json -w '%{http_code}' -X "$m" -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" "$BASE$p")
  fi
  echo "$m $p -> HTTP $code"
  [ "${code:0:1}" = 2 ] || { echo "error: $(head -c 400 resp.json)"; rm -f resp.json; exit 1; }
}

# 1. Shop
call GET "/shops.json"
ok=$(jq --argjson id "$SHOP_ID" '[.[] | select(.id==$id and .sales_channel=="shopify")] | length' resp.json)
echo "god_gear_shop_connected=$([ "$ok" = 1 ] && echo true || echo false)"; [ "$ok" = 1 ] || exit 1

# 2. Spec checks
call GET "$PPATH.json"; cp resp.json product.json
fail=0
for c in \
 "title|.title == \$s[0].title" \
 "not-already-synced|((.external // {}) | .id // null) == null" \
 "not-locked|(.is_locked // false) == false" \
 "enabled-variant-count|([.variants[]|select(.is_enabled)]|length) == (\$s[0].sizes|length)" \
 "prices-match-spec|all(.variants[]|select(.is_enabled); .price == \$s[0].price_cents[(.title|split(\" / \")|map(select(. as \$z | \$s[0].sizes|index(\$z)))|first)])" \
 "no-loss-variant|all(.variants[]|select(.is_enabled); (.cost == null) or (.price > .cost))" \
 "front-print-present|any(.print_areas[].placeholders[]; .position==\"front\" and (.images|length)>0)" \
 "blueprint-pinned|(\$s[0].expected_blueprint_id // .blueprint_id) == .blueprint_id"; do
  n=${c%%|*}; e=${c#*|}
  if jq -e --slurpfile s "$SPEC" "$e" product.json >/dev/null 2>&1; then echo "PASS $n"; else echo "FAIL $n"; fail=1; fi
done
[ "$fail" = 0 ] || { echo "STOP: checks failed, nothing published"; exit 1; }

# 3. Hidden-first: set visible=false and require Printify to report it back before any publish.
echo '{"visible":false}' > vis.json
call PUT "$PPATH.json" vis.json
call GET "$PPATH.json"
vis=$(jq -r 'if has("visible") then (.visible|tostring) else "missing" end' resp.json)
echo "visible_after_put=$vis"
if [ "$vis" != "false" ]; then echo "STOP: Printify did not confirm hidden state (visible=$vis). Nothing published."; exit 1; fi

# 4. Publish, then wait for the Shopify product id.
cat > pub.json <<'J'
{"title":true,"description":true,"images":true,"variants":true,"tags":true,"keyFeatures":true,"shipping_template":true}
J
call POST "$PPATH/publish.json" pub.json
end=$((SECONDS+POLL))
while [ $SECONDS -lt $end ]; do
  call GET "$PPATH.json"
  ext=$(jq -r '(.external // {}) | .id // empty' resp.json)
  if [ -n "$ext" ]; then
    jq '{printify_id:.id, visible, external}' resp.json > "$EVIDENCE/sync_result.json"
    echo "SYNCED shopify_product_id=$ext visible=$(jq -r .visible resp.json)"
    echo "REQUIRED NEXT: SU-WaB Shopify read-back of product $ext (status, Online Store publication, SKUs). Existing draft 10249996501184 untouched."
    rm -f resp.json; exit 0
  fi
  sleep 10
done
echo "PENDING: publish accepted, Shopify id not reported within ${POLL}s (is_locked=$(jq -r '.is_locked' resp.json)). SU-WaB checks Shopify directly."
rm -f resp.json
