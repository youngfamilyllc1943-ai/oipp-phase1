#!/usr/bin/env bash
# Copies an evidence directory to run-<label> on the gg-evidence branch. Used because run logs/artifacts are stored
# on blob hosts SU-WaB cannot reach; git is reachable. Never copies anything outside the given directory.
set -euo pipefail
SRC=$1; LABEL=$2
[ -d "$SRC" ] && [ -n "$(ls -A "$SRC")" ] || { echo "no evidence to store"; exit 0; }
grep -rIl -- "${T:-__none__}" "$SRC" && { echo "REFUSED: token found in evidence"; exit 1; } || true
d=$(mktemp -d); cp -r "$SRC" "$d/run-$LABEL"
cd "$(mktemp -d)" && git init -q && git remote add origin "$(git -C "$GITHUB_WORKSPACE" remote get-url origin)"
git -C "$GITHUB_WORKSPACE" config --get-regexp 'http\..*\.extraheader' | while read k v; do git config "$k" "$v"; done
if git fetch -q --depth 1 origin gg-evidence 2>/dev/null; then git checkout -q FETCH_HEAD; else git checkout -q --orphan gg-evidence; fi
cp -r "$d/run-$LABEL" . && git add "run-$LABEL"
git -c user.name=gg-evidence-bot -c user.email=actions@users.noreply.github.com commit -qm "evidence $LABEL"
for i in 1 2 3; do git push -q origin HEAD:refs/heads/gg-evidence && exit 0; git fetch -q --depth 1 origin gg-evidence && git rebase -q FETCH_HEAD || true; sleep 3; done
echo "evidence push failed"; exit 1
