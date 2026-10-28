#!/usr/bin/env bash
# GOD GEAR Printify draft builder. Creates at most ONE unpublished Printify product from a fixed spec file.
# Never publishes, never orders, never deletes, never prints the token or account data.
# Env: T (token), SHOP_ID, MODE (plan|create), SPEC (path), BP (blueprint id, 0 = search allowlisted models),
#      PP (provider id, 0 = list providers), BASE (default https://api.printify.com/v1)
set -euo pipefail
BASE=${BASE:-https://api.printify.com/v1}
: "${T:?}" "${SHOP_ID:?}" "${MODE:?}" "${SPEC:?}" "${BP:?}" "${PP:?}"

api() { # method path [json-body-file]
  local m=$1 p=$2 b=${3:-} code
  case "$m" in GET|POST) ;; *) echo "REJECTED: method $m"; exit 3 ;; esac
  case "$p" in */publish*|*/orders*|*/webhooks*) echo "REJECTED: forbidden endpoint"; exit 3 ;; esac
  if [ -n "$b" ]; then
    code=$(curl -sS -o resp.json -w '%{http_code}' -X "$m" -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" -H "Content-Type: application/json" --data @"$b" "$BASE$p")
  else
    code=$(curl -sS -o resp.json -w '%{http_code}' -X "$m" -H "Authorization: Bearer $T" -H "User-Agent: GOD-GEAR-Rail" "$BASE$p")
  fi
  echo "$m ${p%%\?*} -> HTTP $code"
  if [ "${code:0:1}" != "2" ]; then
    echo "error: $(jq -c 'if type=="object" then (.errors // .error // .message // keys) else "n/a" end' resp.json 2>/dev/null | head -c 600)"
    rm -f resp.json; exit 1
  fi
}

TITLE=$(jq -r '.title' "$SPEC")
COLOR=$(jq -r '.color' "$SPEC")

# 1. Shop check: the target must be the Shopify-connected GOD GEAR shop. Prints a yes/no only.
api GET "/shops.json"
ok=$(jq --argjson id "$SHOP_ID" '[.[] | select(.id==$id and .sales_channel=="shopify")] | length' resp.json)
echo "god_gear_shop_connected=$([ "$ok" = 1 ] && echo true || echo false)"
[ "$ok" = 1 ] || { echo "FAIL: shop $SHOP_ID is not a Shopify-connected shop on this account"; exit 1; }

# 2. Blueprint: search the catalog for allowlisted models, or verify the chosen one.
if [ "$BP" = "0" ]; then
  api GET "/catalog/blueprints.json"
  jq -c --slurpfile s "$SPEC" '.[] | select(.model as $m | $s[0].allowed_models | index($m)) | {id,title,brand,model}' resp.json
  echo "STOP: choose blueprint_id from the list above and re-run"; exit 0
fi
api GET "/catalog/blueprints/$BP.json"
echo "blueprint=$(jq -c '{id,title,brand,model}' resp.json)"
jq -e --slurpfile s "$SPEC" '.model as $m | $s[0].allowed_models | index($m)' resp.json >/dev/null \
  || { echo "FAIL: blueprint model $(jq -r .model resp.json) is not on the approved-blank allowlist $(jq -c .allowed_models "$SPEC")"; exit 1; }
EXP=$(jq -r '.expected_blueprint_id // empty' "$SPEC")
if [ -n "$EXP" ] && [ "$EXP" != "$BP" ]; then echo "FAIL: spec pins blueprint $EXP, got $BP"; exit 1; fi

# 3. Providers.
if [ "$PP" = "0" ]; then
  api GET "/catalog/blueprints/$BP/print_providers.json"
  jq -c '.[] | {id,title,location:(.location.country // null)}' resp.json
  echo "STOP: choose provider_id and re-run"; exit 0
fi

# 4. Variants: every spec size must exist exactly once in the spec colour.
api GET "/catalog/blueprints/$BP/print_providers/$PP/variants.json"
jq -c --slurpfile s "$SPEC" '
  $s[0] as $sp
  | [.variants[] | select((.options.color|ascii_downcase)==$sp.color) | select(.options.size as $z | $sp.sizes | index($z))]
  | map({id, size: .options.size, price: $sp.price_cents[.options.size], is_enabled: true})' resp.json > variants.json
echo "matched_variants=$(jq -c 'map({id,size,price})' variants.json)"
want=$(jq '.sizes|length' "$SPEC")
have=$(jq '[.[].size]|unique|length' variants.json); total=$(jq 'length' variants.json)
if [ "$have" != "$want" ] || [ "$total" != "$want" ]; then
  echo "FAIL: provider $PP covers $have of $want spec sizes in $COLOR ($total rows); spec requires exact coverage"; exit 1
fi

if [ "$MODE" = "plan" ]; then echo "PLAN OK: $want variants would be created. No write performed."; exit 0; fi
[ "$MODE" = "create" ] || { echo "REJECTED: mode"; exit 2; }

# Artwork gate: create only with artwork approved for this garment colour (contrast/QC evidence in the spec).
if [ "$(jq -r '.front_art.approved_for_garment_color // false' "$SPEC")" != "true" ]; then
  echo "BLOCKED: front artwork is not approved for a $COLOR garment ($(jq -r '.front_art._qc // "no QC record"' "$SPEC" | head -c 160)...). Nothing created."; exit 4
fi

# 5. Duplicate guard: abort if a product with this title already exists in the shop (all pages).
page=1
while :; do
  api GET "/shops/$SHOP_ID/products.json?limit=50&page=$page"
  dup=$(jq -r --arg t "$TITLE" '[.data[] | select(.title==$t) | .id] | first // empty' resp.json)
  if [ -n "$dup" ]; then echo "FAIL: duplicate guard - '$TITLE' already exists as printify_product_id=$dup. Nothing created."; exit 1; fi
  last=$(jq -r '.last_page // 1' resp.json)
  [ "$page" -ge "$last" ] && break; page=$((page+1))
done
echo "duplicate_guard=clear"

# 6. Upload allowlisted artwork (URL comes from the spec file, never from inputs).
jq '.front_art | {file_name, url}' "$SPEC" > up.json
api POST "/uploads/images.json" up.json
IMG=$(jq -r '.id' resp.json); echo "front_image_id=$IMG size=$(jq -c '{width,height}' resp.json)"
if [ "$(jq -r '.back_art // empty | .url // empty' "$SPEC")" != "" ]; then
  jq '.back_art | {file_name, url}' "$SPEC" > up.json
  api POST "/uploads/images.json" up.json
  BIMG=$(jq -r '.id' resp.json); echo "back_image_id=$BIMG"
else BIMG=""; echo "back_print=none (spec has no print-ready back art)"; fi

# 7. Create the product. Products are created unpublished; this script contains no publish call.
jq -n --slurpfile s "$SPEC" --slurpfile v variants.json --argjson bp "$BP" --argjson pp "$PP" --arg img "$IMG" --arg bimg "$BIMG" '
  $s[0] as $sp | $v[0] as $vs
  | {title: $sp.title, description: $sp.description_html, tags: $sp.tags, visible: false,
     blueprint_id: $bp, print_provider_id: $pp,
     variants: ($vs | map({id, price, is_enabled})),
     print_areas: [{ variant_ids: ($vs | map(.id)),
       placeholders: ([{position:"front", images:[{id:$img, x:$sp.front_art.x, y:$sp.front_art.y, scale:$sp.front_art.scale, angle:$sp.front_art.angle}]}]
         + (if $bimg=="" then [] else [{position:"back", images:[{id:$bimg, x:$sp.back_art.x, y:$sp.back_art.y, scale:$sp.back_art.scale, angle:$sp.back_art.angle}]}] end)) }]}' > product.json
api POST "/shops/$SHOP_ID/products.json" product.json

# 8. Evidence for CRITIC: id, visibility, per-size cost vs price, mockups. Saved to $EVIDENCE for upload.
EVIDENCE=${EVIDENCE:-evidence}; mkdir -p "$EVIDENCE"
jq '{id,title,visible,is_locked,blueprint_id,print_provider_id,variants:[.variants[]|select(.is_enabled)|{id,title,price,cost}],images:[.images[]?|{src,position,is_default}]}' resp.json > "$EVIDENCE/printify_product.json"
jq -r '.images[]? | .src' resp.json | head -8 > "$EVIDENCE/mockup_urls.txt"
echo "CREATED printify_product_id=$(jq -r '.id' resp.json) visible=$(jq -r '.visible' resp.json)"
jq -r '.variants[] | select(.is_enabled) | "variant \(.title) price=\(.price) cost=\(.cost // "n/a") contribution_before_shipping_fees=\(if .cost then (.price - .cost) else "n/a" end)"' resp.json
loss=$(jq '[.variants[] | select(.is_enabled and .cost != null and .price <= .cost)] | length' resp.json)
echo "loss_variants=$loss"
jq -r '.images[]? | select(.is_default or (.position=="front")) | "mockup \(.position) \(.src)"' resp.json | head -6
rm -f resp.json
