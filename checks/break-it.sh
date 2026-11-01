#!/usr/bin/env bash
# Live "break it" demo: plant a real bug in a COPY of the engine and show that Lean refuses it.
#
# Usage (from anywhere in the repo, after a normal `cd engine && lake build`):
#   checks/break-it.sh                # bug: at a showdown, the LOSER gets the pot
#   checks/break-it.sh --bug fold     # bug: when a player folds, the FOLDER gets the pot
#   checks/break-it.sh --clean        # also build the unchanged copy, to show it passes
#
# It never changes your files: it copies engine/ (with its build cache, engine/.lake) to a
# temporary folder, changes one line there, and builds only the proof file that should catch it.
set -euo pipefail
export PATH="$HOME/.elan/bin:$PATH"

bug="showdown"
clean=0
while [ $# -gt 0 ]; do
  case "$1" in
    --bug) bug="${2:-}"; shift 2 ;;
    --clean) clean=1; shift ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
done

repo="$(cd "$(dirname "$0")/.." && pwd)"
engine="$repo/engine"
[ -d "$engine/.lake/build" ] || { echo "Build the engine first: cd engine && lake build"; exit 2; }

case "$bug" in
  showdown)
    file="Engine/Hand.lean"
    old=$'    | .player0 => fun p => if p = 0 then s.pot else 0\n    | .player1 => fun p => if p = 1 then s.pot else 0'
    new=$'    | .player0 => fun p => if p = 1 then s.pot else 0\n    | .player1 => fun p => if p = 0 then s.pot else 0'
    story="At a showdown, pay the pot to the player with the WORSE hand."
    headline="showdown_pays_better_hand (at a showdown, the better hand wins the pot)"
    target="Engine.Proofs.Payout"
    ;;
  fold)
    file="Engine/Hand.lean"
    old='    | .fold => .ok (h.payFold (other me))'
    new='    | .fold => .ok (h.payFold me)'
    story="When a player folds, give the pot to the player who FOLDED."
    headline="fold_records_other_player (a fold gives the hand to the other player)"
    target="Engine.Proofs.Payout"
    ;;
  *) echo "unknown bug: $bug (use showdown or fold)"; exit 2 ;;
esac

tmp="$(mktemp -d)"
log="$tmp/lean-output.txt"
trap 'rm -rf "$tmp/engine"' EXIT
cp -R "$engine" "$tmp/engine"

# Plant the bug: an exact text replacement. Stop if the line is not found.
python3 - "$tmp/engine/$file" "$old" "$new" <<'EOF'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(old) != 1:
    sys.exit(f"Could not find the line to change in {path}. The engine code has moved; update break-it.sh.")
open(path, "w").write(text.replace(old, new))
EOF

echo
echo "  BUG PLANTED:  $story"
echo "  (one line changed in a copy of $file; your files are untouched)"
echo
echo "  Asking Lean to re-check the proofs..."
start=$(date +%s)
set +e
(cd "$tmp/engine" && lake build "$target") > "$log" 2>&1
status=$?
set -e
secs=$(( $(date +%s) - start ))

if [ $status -eq 0 ]; then
  echo
  echo "  !! Lean ACCEPTED the bug. This should not happen. Full output: $log"
  exit 1
fi

# The first file that fails, and the theorem it is in.
first=$(grep -m1 -oE '^error: [A-Za-z/]+\.lean:[0-9]+' "$log" | sed 's/^error: //')
failfile="${first%%:*}"
failline="${first##*:}"
thm=""
if [ -n "$failfile" ] && [ -f "$tmp/engine/$failfile" ]; then
  thm=$(head -n "$failline" "$tmp/engine/$failfile" | grep -E '^(theorem|lemma|example|def) ' | tail -1 \
        | sed -E 's/^(theorem|lemma|def) ([^ ]+).*/\2/; s/^example.*/an example check/')
fi

echo
echo "  LEAN REFUSES.  (${secs}s)"
echo "  The proof breaks in: $failfile, line $failline"
[ -n "$thm" ] && echo "  Inside:              $thm"
if [ "$failfile" = "Engine/Proofs/Payout.lean" ]; then
  echo "  Theorem that no longer holds: $headline"
else
  echo "  This bug also makes $headline false;"
  echo "  Lean stopped at the first failure, before reaching that proof."
fi
echo "  Full Lean output:     $log"
echo

if [ $clean -eq 1 ]; then
  echo "  Now the same check on the code without the bug..."
  rm -rf "$tmp/engine"
  cp -R "$engine" "$tmp/engine"
  start=$(date +%s)
  if (cd "$tmp/engine" && lake build "$target") > "$tmp/clean-output.txt" 2>&1; then
    echo "  ALL PROOFS PASS.  ($(( $(date +%s) - start ))s)"
  else
    echo "  !! The clean copy failed too. See $tmp/clean-output.txt"
    exit 1
  fi
  echo
fi
