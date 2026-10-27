#!/usr/bin/env bash
# Offline fire test for .github/workflows/gg-printify-draft.yml against a mock Printify API. No real credentials.
set -u; cd "$(dirname "$0")"; rm -rf requests.log product_payload.json w_* build.sh
python3 -c "import yaml;d=yaml.safe_load(open('../../.github/workflows/gg-printify-draft.yml'));open('build.sh','w').write(d['jobs']['run']['steps'][2]['run'].replace('BASE=https://api.printify.com/v1','BASE=\${MOCK_BASE:?}'))"
fail=0
run(){ MOCK_MODE=$2 python3 mock.py & P=$!; sleep 1; mkdir -p w_$1
  (cd w_$1 && env -i PATH=$PATH HOME=$HOME T=MOCKTOKEN MOCK_BASE=http://127.0.0.1:8765/v1 MODE=$3 BP=12 PP=$4 SHOP_ID=29470786 ART_URL=https://cdn.shopify.com/x.png bash -e ../build.sh >out.txt 2>&1); rc=$?
  kill $P; wait $P 2>/dev/null; [ $rc = $5 ] && echo "PASS $1" || { echo "FAIL $1 (exit $rc, want $5)"; fail=1; }; }
run plan-list ok plan 0 0; run plan-variants ok plan 99 0; run create ok create 99 0; run thin-coverage thin create 99 1; run api-error err create 99 1
[ "$(grep -c publish requests.log)" = 0 ] && echo "PASS no-publish" || { echo "FAIL publish called"; fail=1; }
grep -rq MOCKTOKEN w_* && { echo "FAIL token leaked"; fail=1; } || echo "PASS no-token-in-output"
rm -rf w_* build.sh requests.log product_payload.json; exit $fail
