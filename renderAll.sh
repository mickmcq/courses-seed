#!/usr/bin/env bash
# renderAll.sh — re-render every seeded deck. Reports pass/fail per deck.
#   ./renderAll.sh            all courses
#   COURSES=hci ./renderAll.sh   one course
set -uo pipefail
SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SEED_DIR")"
ok=0; fail=0; failed=()
while IFS= read -r rel; do
  d="$ROOT/$rel"
  printf '%-50s ' "$rel"
  if (cd "$d" && timeout 900 quarto render index.qmd >/tmp/render.log 2>&1); then
    printf 'OK   %s\n' "$(ls -lh "$d/index.html" 2>/dev/null | awk '{print $5}')"
    ok=$((ok+1))
  else
    printf 'FAIL\n'
    fail=$((fail+1)); failed+=("$rel")
    cp /tmp/render.log "/tmp/renderfail-$(echo "$rel" | tr / _).log"
  fi
done < <("$SEED_DIR/seed.sh" --list | grep -v '^--')
echo
echo "rendered OK: $ok   failed: $fail"
for f in "${failed[@]:-}"; do [ -n "$f" ] && echo "  FAILED: $f  (log: /tmp/renderfail-$(echo "$f" | tr / _).log)"; done
