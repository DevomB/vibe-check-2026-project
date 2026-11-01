#!/usr/bin/env bash
# Audit the Lean proofs. Fails (exit 1) if:
#   - the engine does not build,
#   - any main theorem in engine/comparator.json uses an axiom other than
#     propext, Classical.choice, Quot.sound (an unfinished proof shows up as sorryAx),
#   - `sorry`, `admit`, `native_decide`, `maxHeartbeats 0` or a new `axiom` appears in the
#     engine's Lean code (Checks/Challenge.lean is skipped: it is all `sorry` on purpose),
#   - `implemented_by`, `unsafe`, `@[extern ...]` or `debug.skipKernelTC` appears there (each
#     lets running code, or the kernel, differ from what the proofs see),
#   - a `maxHeartbeats` line has no comment saying why (on the line, or on the line above).
# Usage: checks/audit.sh   (from anywhere in the repo)
set -euo pipefail
export PATH="$HOME/.elan/bin:$PATH"
cd "$(dirname "$0")/../engine"
fail=0

echo "== Build"
lake build 2>&1 | tail -1
lake build Checks 2>&1 | tail -1

echo "== Banned words in the Lean code"
banned=$(grep -rnE '(^|[^A-Za-z_.])(sorry|admit|native_decide)([^A-Za-z_]|$)|maxHeartbeats 0|^[[:space:]]*axiom[[:space:]]' \
  --include='*.lean' Engine Poker Checks Engine.lean Poker.lean Main.lean \
  | grep -v '^Checks/Challenge.lean:' \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*--' || true)
if [ -n "$banned" ]; then
  echo "$banned"
  echo "FAIL: banned words found (lines above). Doc comments that mention them must be reworded."
  fail=1
else
  echo "ok"
fi

echo "== Ways to make running code differ from the proofs"
hatches=$(grep -rnE '(^|[^A-Za-z_.])(implemented_by|unsafe)([^A-Za-z_]|$)|@\[[[:space:]]*extern|debug\.skipKernelTC' \
  --include='*.lean' Engine Poker Checks Engine.lean Poker.lean Main.lean \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*--' || true)
if [ -n "$hatches" ]; then
  echo "$hatches"
  echo "FAIL: implemented_by, unsafe, @[extern] or debug.skipKernelTC found (lines above)."
  fail=1
else
  echo "ok"
fi

echo "== Every maxHeartbeats line has a comment"
heartbeats=$(find Engine Poker Checks Engine.lean Poker.lean Main.lean -name '*.lean' -print0 \
  | xargs -0 awk 'FNR == 1 { prev = "" }
      /maxHeartbeats/ && !/--/ && prev !~ /^[[:space:]]*--/ { print FILENAME ":" FNR ": " $0 }
      { prev = $0 }')
if [ -n "$heartbeats" ]; then
  echo "$heartbeats"
  echo "FAIL: maxHeartbeats without a comment saying why (lines above)."
  fail=1
else
  echo "ok"
fi

echo "== Axioms of each main theorem"
names=$(sed -n '/"theorem_names"/,/]/p' comparator.json | grep -oE '"[A-Za-z0-9_.]+"' | tr -d '"' | grep -v theorem_names)
tmp=$(mktemp -d)
{
  echo "import Checks.Solution"
  for n in $names; do echo "#print axioms $n"; done
} > "$tmp/Audit.lean"
out=$(lake env lean "$tmp/Audit.lean" 2>&1)
rm -rf "$tmp"
echo "$out"
for n in $names; do
  line=$(echo "$out" | grep "'$n' " || true)
  if [ -z "$line" ]; then
    echo "FAIL: no axiom report for $n"; fail=1; continue
  fi
  extra=$(echo "$line" | sed -n 's/.*\[\(.*\)\].*/\1/p' | tr ',' '\n' | tr -d ' ' \
    | grep -vE '^(propext|Classical\.choice|Quot\.sound)?$' || true)
  if [ -n "$extra" ]; then echo "FAIL: $n uses $extra"; fail=1; fi
done

if [ "$fail" -ne 0 ]; then echo "AUDIT FAILED"; exit 1; fi
echo "AUDIT PASSED"
