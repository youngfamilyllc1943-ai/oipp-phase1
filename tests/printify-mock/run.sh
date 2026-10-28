#!/usr/bin/env bash
# Offline fire test for rail/printify_draft.sh and rail/printify_sync.sh against a mock Printify API.
# No real credentials and no network. Exit 0 only if every case passes.
set -u; cd "$(dirname "$0")"; HERE=$PWD; ROOT=$(cd ../.. && pwd)
REAL_SPEC=$ROOT/rail/specs/gg-athletic-tee.json
# Test spec = real spec with the artwork flag forced true, so create paths can be exercised. The real spec is tested separately.
SPEC=$(mktemp); jq '.front_art.approved_for_garment_color=true' "$REAL_SPEC" > "$SPEC"
rm -rf requests.log w_* product_payload.json publish_payload.json; fail=0
PID=65a1b2c3d4e5f60718293a4b

# case name | mock mode | script | MODE BP PP | expected exit | required output substring
run(){ local name=$1 mm=$2 script=$3 mode=$4 bp=$5 pp=$6 want=$7 needle=$8
  MOCK_MODE=$mm python3 mock.py & local P=$!; sleep 0.6; mkdir -p w_$name
  local spec=$SPEC; [ "$name" = create-blocked-art ] && spec=$REAL_SPEC
  (cd w_$name && env -i PATH="$PATH" HOME="$HOME" T=MOCKTOKEN BASE=http://127.0.0.1:8765/v1 SHOP_ID=29470786 SPEC="$spec" \
     MODE=$mode BP=$bp PP=$pp PID=$PID POLL=15 bash "$ROOT/rail/$script" >out.txt 2>&1); local rc=$?
  kill $P; wait $P 2>/dev/null; for f in product_payload.json publish_payload.json; do [ -f $f ] && mv $f w_$name/; done
  if [ $rc = $want ] && grep -q -- "$needle" w_$name/out.txt; then echo "PASS $name"
  else echo "FAIL $name (exit $rc, want $want, needle '$needle')"; sed 's/^/    /' w_$name/out.txt | tail -8; fail=1; fi; }

# Draft builder (approved blank: Bella+Canvas 3001 = blueprint 12; 1717 = blueprint 706 must be refused)
run list-blueprints   ok         printify_draft.sh plan   0   0  0 '"model":"3001"'
run blocks-1717       ok         printify_draft.sh plan   706 99 1 'not on the approved-blank allowlist'
run list-providers    ok         printify_draft.sh plan   12  0  0 'Mock Provider'
run plan-ok           ok         printify_draft.sh plan   12  99 0 'PLAN OK: 7 variants'
run thin-coverage     thin       printify_draft.sh create 12  99 1 'covers 5 of 7'
run wrong-shop        wrongshop  printify_draft.sh plan   12  99 1 'not a Shopify-connected shop'
run duplicate-guard   dup        printify_draft.sh create 12  99 1 'duplicate guard'
run api-error         err        printify_draft.sh create 12  99 1 'mock validation'
run create-ok         ok         printify_draft.sh create 12  99 0 'CREATED printify_product_id='
run loss-flag         loss       printify_draft.sh create 12  99 0 'loss_variants=1'
run create-blocked-art ok        printify_draft.sh create 12  99 4 'BLOCKED: front artwork is not approved'
# Sync (hidden-first)
run sync-ok           ok         printify_sync.sh  -      -   -  0 'SYNCED shopify_product_id=10299999999999 visible=false'
run sync-vis-ignored  visignored printify_sync.sh  -      -   -  1 'did not confirm hidden state'
run sync-vis-missing  vismissing printify_sync.sh  -      -   -  1 'visible=missing'
run sync-already      synced     printify_sync.sh  -      -   -  1 'FAIL not-already-synced'
run sync-badprice     badprice   printify_sync.sh  -      -   -  1 'FAIL prices-match-spec'
run sync-loss         loss       printify_sync.sh  -      -   -  1 'FAIL no-loss-variant'
run sync-wrongshop    wrongshop  printify_sync.sh  -      -   -  1 'god_gear_shop_connected=false'

# Payload assertions on the successful create
P=w_create-ok/product_payload.json
jq -e '.blueprint_id==12 and .print_provider_id==99 and (.variants|length)==7' $P >/dev/null && echo "PASS payload-shape" || { echo "FAIL payload-shape"; fail=1; }
jq -e '[.variants[].price]==[4900,4900,4900,4900,5400,5900,6400]' $P >/dev/null && echo "PASS payload-prices" || { echo "FAIL payload-prices"; fail=1; }
jq -e --slurpfile s "$SPEC" '.description==$s[0].description_html and .title==$s[0].title' $P >/dev/null && echo "PASS payload-approved-copy" || { echo "FAIL payload-approved-copy"; fail=1; }
jq -e '.visible==false' $P >/dev/null && echo "PASS payload-created-hidden" || { echo "FAIL payload-created-hidden"; fail=1; }
jq -e '[.print_areas[0].placeholders[].position]==["front"]' $P >/dev/null && echo "PASS payload-front-only" || { echo "FAIL payload-front-only"; fail=1; }

jq -e '.title and .variants and .images and .description' w_sync-ok/publish_payload.json >/dev/null && echo "PASS publish-payload" || { echo "FAIL publish-payload"; fail=1; }

# Safety assertions across every request made in every case
pubs=$(jq -s '[.[]|select(.p|test("publish"))]|length' requests.log)
[ "$pubs" = 1 ] && echo "PASS publish-only-in-sync-ok (1 call)" || { echo "FAIL publish calls=$pubs (want 1)"; fail=1; }
jq -s -e 'all(.[]; .m=="GET" or .m=="POST" or (.m=="PUT" and (.body|fromjson)=={"visible":false}))' requests.log >/dev/null && echo "PASS only-GET/POST-and-hide-PUT" || { echo "FAIL unexpected method or PUT body"; fail=1; }
jq -s -e 'all(.[]; .m!="DELETE")' requests.log >/dev/null && echo "PASS no-delete" || { echo "FAIL delete called"; fail=1; }
jq -s -e 'all(.[]; (.p|test("orders|webhooks"))|not)' requests.log >/dev/null && echo "PASS no-orders-webhooks" || { echo "FAIL orders/webhooks touched"; fail=1; }
grep -rq MOCKTOKEN w_*/out.txt && { echo "FAIL token leaked"; fail=1; } || echo "PASS no-token-in-output"
[ "$(grep -c 'publish.json\|"visible":true\|visible: true' "$ROOT/rail/printify_draft.sh")" = 0 ] && echo "PASS draft-script-has-no-publish-call" || { echo "FAIL draft script references publish.json"; fail=1; }

grep -q '"visible":true\|visible: true' "$ROOT/rail/printify_sync.sh" && { echo "FAIL sync can set visible"; fail=1; } || echo "PASS sync-never-sets-visible"
# The Rail has no Shopify credential and no Shopify endpoint: every curl targets $BASE (Printify) only, so it cannot edit or archive the existing draft.
if ! grep -h 'curl ' "$ROOT"/rail/*.sh | grep -v '"\$BASE\$p"' | grep -q . && ! { grep -qi 'myshopify\|admin/api\|graphql' "$ROOT"/rail/*.sh "$ROOT"/.github/workflows/gg-printify-*.yml || grep -q 'secrets.SHOPIFY\|SHOPIFY_[A-Z]*TOKEN' "$ROOT"/rail/*.sh "$ROOT"/.github/workflows/gg-printify-*.yml; }; then echo "PASS rail-cannot-touch-shopify-draft"; else echo "FAIL rail has a non-Printify request path"; fail=1; fi

# Workflow guards: secret name and actor allowlist in every Printify workflow
for f in "$ROOT"/.github/workflows/gg-printify-*.yml; do
  b=$(basename "$f")
  grep -q 'secrets.PRINTIFY_TOKEN' "$f" && ! grep -q 'PRINTIFY_API_TOKEN' "$f" && echo "PASS secret-name $b" || { echo "FAIL secret-name $b"; fail=1; }
  grep -q "github.triggering_actor == 'youngfamilyllc1943-ai'" "$f" && echo "PASS actor-allowlist $b" || { echo "FAIL actor-allowlist $b"; fail=1; }
done

rm -rf w_* requests.log product_payload.json publish_payload.json; echo; [ $fail = 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $fail
