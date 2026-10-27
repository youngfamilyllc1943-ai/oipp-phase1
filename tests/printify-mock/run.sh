#!/usr/bin/env bash
# Offline fire test for rail/printify_draft.sh and rail/printify_sync.sh against a mock Printify API.
# No real credentials and no network. Exit 0 only if every case passes.
set -u; cd "$(dirname "$0")"; HERE=$PWD; ROOT=$(cd ../.. && pwd)
SPEC=$ROOT/rail/specs/gg-athletic-tee.json
rm -rf requests.log w_* product_payload.json publish_payload.json; fail=0
PID=65a1b2c3d4e5f60718293a4b

# case name | mock mode | script | MODE BP PP | expected exit | required output substring
run(){ local name=$1 mm=$2 script=$3 mode=$4 bp=$5 pp=$6 want=$7 needle=$8
  MOCK_MODE=$mm python3 mock.py & local P=$!; sleep 0.6; mkdir -p w_$name
  (cd w_$name && env -i PATH="$PATH" HOME="$HOME" T=MOCKTOKEN BASE=http://127.0.0.1:8765/v1 SHOP_ID=29470786 SPEC="$SPEC" \
     MODE=$mode BP=$bp PP=$pp PID=$PID POLL=15 bash "$ROOT/rail/$script" >out.txt 2>&1); local rc=$?
  kill $P; wait $P 2>/dev/null; for f in product_payload.json publish_payload.json; do [ -f $f ] && mv $f w_$name/; done
  if [ $rc = $want ] && grep -q -- "$needle" w_$name/out.txt; then echo "PASS $name"
  else echo "FAIL $name (exit $rc, want $want, needle '$needle')"; sed 's/^/    /' w_$name/out.txt | tail -8; fail=1; fi; }

# Draft builder
run list-blueprints   ok        printify_draft.sh plan   0   0  0 '"model":"1717"'
run blocks-3001       ok        printify_draft.sh plan   12  99 1 'not on the BMW allowlist'
run list-providers    ok        printify_draft.sh plan   706 0  0 'Mock Provider'
run plan-ok           ok        printify_draft.sh plan   706 99 0 'PLAN OK: 7 variants'
run thin-coverage     thin      printify_draft.sh create 706 99 1 'covers 5 of 7'
run wrong-shop        wrongshop printify_draft.sh plan   706 99 1 'not a Shopify-connected shop'
run duplicate-guard   dup       printify_draft.sh create 706 99 1 'duplicate guard'
run api-error         err       printify_draft.sh create 706 99 1 'mock validation'
run create-ok         ok        printify_draft.sh create 706 99 0 'CREATED printify_product_id='
run loss-flag         loss      printify_draft.sh create 706 99 0 'loss_variants=1'
# Sync
run sync-ok           ok        printify_sync.sh  -      -   -  0 'SYNCED shopify_product_id=10299999999999'
run sync-already      synced    printify_sync.sh  -      -   -  1 'FAIL not-already-synced'
run sync-badprice     badprice  printify_sync.sh  -      -   -  1 'FAIL prices-match-spec'
run sync-loss         loss      printify_sync.sh  -      -   -  1 'FAIL no-loss-variant'
run sync-wrongshop    wrongshop printify_sync.sh  -      -   -  1 'god_gear_shop_connected=false'

# Payload assertions on the successful create
P=w_create-ok/product_payload.json
jq -e '.blueprint_id==706 and .print_provider_id==99 and (.variants|length)==7' $P >/dev/null && echo "PASS payload-shape" || { echo "FAIL payload-shape"; fail=1; }
jq -e '[.variants[].price]==[4900,4900,4900,4900,5400,5900,6400]' $P >/dev/null && echo "PASS payload-prices" || { echo "FAIL payload-prices"; fail=1; }
jq -e --slurpfile s "$SPEC" '.description==$s[0].description_html and .title==$s[0].title' $P >/dev/null && echo "PASS payload-approved-copy" || { echo "FAIL payload-approved-copy"; fail=1; }
jq -e '[.print_areas[0].placeholders[].position]==["front"]' $P >/dev/null && echo "PASS payload-front-only" || { echo "FAIL payload-front-only"; fail=1; }

jq -e '.title and .variants and .images and .description' w_sync-ok/publish_payload.json >/dev/null && echo "PASS publish-payload" || { echo "FAIL publish-payload"; fail=1; }

# Safety assertions across every request made in every case
pubs=$(jq -s '[.[]|select(.p|test("publish"))]|length' requests.log)
[ "$pubs" = 1 ] && echo "PASS publish-only-in-sync-ok (1 call)" || { echo "FAIL publish calls=$pubs (want 1)"; fail=1; }
jq -s -e 'all(.[]; .m=="GET" or .m=="POST")' requests.log >/dev/null && echo "PASS no-delete-put" || { echo "FAIL non GET/POST method"; fail=1; }
jq -s -e 'all(.[]; (.p|test("orders|webhooks"))|not)' requests.log >/dev/null && echo "PASS no-orders-webhooks" || { echo "FAIL orders/webhooks touched"; fail=1; }
grep -rq MOCKTOKEN w_*/out.txt && { echo "FAIL token leaked"; fail=1; } || echo "PASS no-token-in-output"
[ "$(grep -c 'publish.json' "$ROOT/rail/printify_draft.sh")" = 0 ] && echo "PASS draft-script-has-no-publish-call" || { echo "FAIL draft script references publish.json"; fail=1; }

# Workflow guards: secret name and actor allowlist in every Printify workflow
for f in "$ROOT"/.github/workflows/gg-printify-*.yml; do
  b=$(basename "$f")
  grep -q 'secrets.PRINTIFY_TOKEN' "$f" && ! grep -q 'PRINTIFY_API_TOKEN' "$f" && echo "PASS secret-name $b" || { echo "FAIL secret-name $b"; fail=1; }
  grep -q "github.triggering_actor == 'youngfamilyllc1943-ai'" "$f" && echo "PASS actor-allowlist $b" || { echo "FAIL actor-allowlist $b"; fail=1; }
done

rm -rf w_* requests.log product_payload.json publish_payload.json; echo; [ $fail = 0 ] && echo "ALL PASS" || echo "FAILURES PRESENT"; exit $fail
