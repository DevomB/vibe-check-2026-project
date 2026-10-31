#!/bin/sh
# Download every free full text listed in PAPERS.md into papers/ (git-ignored).
# Usage: sh docs/research/fetch_papers.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$here/papers"
grep -E '^\| [A-E][0-9]{2} \|.*https?://' "$here/PAPERS.md" | while IFS='|' read -r _ id title url _; do
  id=$(echo "$id" | tr -d ' ')
  url=$(echo "$url" | tr -d ' ')
  slug=$(echo "$title" | sed 's/^ *//; s/[.:].*//' | tr -c 'A-Za-z0-9\n' '-' | cut -c1-40 | sed 's/-*$//')
  out="$here/papers/$id-$slug.pdf"
  if [ -s "$out" ]; then echo "have  $out"; continue; fi
  if curl -sSfL --max-time 60 -A "Mozilla/5.0 (research fetch)" -o "$out" "$url"; then
    echo "got   $out"
  else
    echo "FAIL  $url"; rm -f "$out"
  fi
done
