#!/usr/bin/env bash
# seed.sh — propagate shared lecture files into every clean-revealjs deck.
#
#   ./seed.sh              apply (default)
#   ./seed.sh --check      report drift, change nothing (exit 1 if drift found)
#   ./seed.sh --dry-run    show what would change
#   ./seed.sh --list       list the decks that would be seeded
#
# Targets are DISCOVERED, never listed: any directory under <course>/lecture/
# whose index.qmd or _metadata.yaml declares `clean-revealjs`. New lectures are
# picked up automatically. Excluded: old*, and model-experiment forks.
#
# Everything seeded is a RELATIVE SYMLINK into _seed/, so a deck can never drift
# from the canonical copy. Editing _seed/courses/<course>/_metadata.yaml updates
# every deck in that course at once.

set -euo pipefail

SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SEED_DIR")"
COURSES="${COURSES:-hci infointeractdsgn appProtoStudio}"
EXCLUDE_GLOBS="old* claude0* qwen0*"

MODE=apply
case "${1:-}" in
  --check)   MODE=check   ;;
  --dry-run) MODE=dryrun  ;;
  --list)    MODE=list    ;;
  "")        MODE=apply   ;;
  *) echo "usage: $0 [--check|--dry-run|--list]" >&2; exit 2 ;;
esac

drift=0
changed=0

say() { printf '%s\n' "$*"; }

# relative path from $1 to $2
relpath() {
  python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' "$1" "$2"
}

is_excluded() {
  local b="$1" g
  for g in $EXCLUDE_GLOBS; do
    # shellcheck disable=SC2053
    [[ $b == $g ]] && return 0
  done
  return 1
}

# Build the per-course clean extension variant (pristine + font substitution).
# This keeps _seed/common/_extensions pristine and updatable via `quarto update`,
# while still producing the per-course font each course expects.
build_variant() {
  local course="$1" font="$2" weights="$3" pkgs="$4"
  local src="$SEED_DIR/common/_extensions"
  local dst="$SEED_DIR/build/$course/_extensions"
  local pkg owner
  rm -rf "$dst"; mkdir -p "$dst"
  for pkg in $pkgs; do
    owner="${pkg%%/*}"
    mkdir -p "$dst/$owner"
    cp -R "$src/$pkg" "$dst/$owner/"
  done
  local scss="$dst/grantmcdermott/clean/clean.scss"
  [ -f "$scss" ] || return 0
  python3 - "$scss" "$font" "$weights" <<'PY'
import re, sys
path, font, weights = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
fam = font.replace(' ', '+')
s = re.sub(r"@import url\('https://fonts\.googleapis\.com/css\?family=[^']*'\);",
           f"@import url('https://fonts.googleapis.com/css?family={fam}:{weights}&display=swap');", s)
s = re.sub(r'^\$font-family-sans-serif:.*$',
           f'$font-family-sans-serif: "{font}", sans-serif !default;', s, flags=re.M)
s = re.sub(r'^\$presentation-heading-font:.*$',
           f'$presentation-heading-font: "{font}", sans-serif !default;', s, flags=re.M)
open(path, 'w').write(s)
PY
}

# link <target-abs> <linkpath-abs>
link() {
  local target="$1" linkpath="$2" dir rel
  dir="$(dirname "$linkpath")"
  rel="$(relpath "$dir" "$target")"
  if [ -L "$linkpath" ] && [ "$(readlink "$linkpath")" = "$rel" ]; then
    return 0                                    # already correct
  fi
  drift=1
  case "$MODE" in
    check|dryrun) say "    would link  $(basename "$linkpath")  ->  $rel" ;;
    apply)
      rm -rf "$linkpath"
      ln -s "$rel" "$linkpath"
      say "    linked  $(basename "$linkpath")  ->  $rel"
      changed=$((changed+1)) ;;
  esac
}

# A single-course repo (e.g. hci-lecture) can be cloned under any directory
# name, so the course can't be inferred from the path there. The outer repo
# declares it in .seedcourse, which travels with the clone.
FIXED_COURSE=""
if [ -f "$ROOT/.seedcourse" ]; then
  FIXED_COURSE="$(tr -d '[:space:]' < "$ROOT/.seedcourse")"
  [ -d "$SEED_DIR/courses/$FIXED_COURSE" ] || {
    echo "!! .seedcourse names '$FIXED_COURSE' but _seed/courses/$FIXED_COURSE does not exist" >&2
    exit 1
  }
fi

# ---- ownership: each _seed checkout owns the decks nearest to it -----------
# There can be more than one _seed on a machine: the shared ~/courses/_seed and
# a submodule copy inside a course repo (e.g. hci/lecture/_seed) so that a clone
# of that repo is self-contained. A deck belongs to whichever _seed is nearest
# walking up from it, which keeps the two checkouts from fighting over decks.
nearest_seed() {
  local d; d="$(cd "$1" && pwd)"
  while [ "$d" != "/" ]; do
    [ -d "$d/_seed" ] && { echo "$d/_seed"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

# ---- discover decks -------------------------------------------------------
# Search both layouts and let the ownership check sort them out:
#   <seed>/../*/            e.g. hci/lecture/_seed  -> sibling deck dirs
#   <seed>/../*/lecture/*/  e.g. courses/_seed      -> <course>/lecture/<deck>
decks=(); skipped=0
while IFS= read -r d; do
  [ -d "$d" ] || continue
  b="$(basename "$d")"
  [ "$b" = "_seed" ] && continue
  # never treat the seed's own course-config dirs as decks: they contain a
  # _metadata.yaml declaring clean-revealjs and would otherwise self-match
  case "$d/" in "$SEED_DIR"/*) continue;; esac
  is_excluded "$b" && continue
  files=()
  [ -f "$d/index.qmd" ]      && files+=("$d/index.qmd")
  [ -f "$d/_metadata.yaml" ] && files+=("$d/_metadata.yaml")
  [ ${#files[@]} -gt 0 ] || continue
  grep -q "clean-revealjs" "${files[@]}" 2>/dev/null || continue
  # Which course does this deck belong to? Normally derived from the path
  # (<course>/lecture/<deck>), but a collaborator's clone of a single course
  # repo can be checked out under any directory name, so an explicit binding
  # in <repo-root>/.seedcourse wins when present.
  if [ -n "$FIXED_COURSE" ]; then
    course="$FIXED_COURSE"
  else
    course="$(basename "$(dirname "$(dirname "$d")")")"
    case " $COURSES " in *" $course "*) ;; *) continue;; esac
  fi
  owner="$(nearest_seed "$d" || true)"
  if [ "$owner" != "$SEED_DIR" ]; then skipped=$((skipped+1)); continue; fi
  decks+=("$d")
done < <({ find "$ROOT" -mindepth 1 -maxdepth 1 -type d
           find "$ROOT" -mindepth 3 -maxdepth 3 -type d -path "*/lecture/*"; } 2>/dev/null | sort -u)

if [ "$MODE" = list ]; then
  [ ${#decks[@]} -gt 0 ] && printf '%s\n' "${decks[@]#$ROOT/}"
  say "-- ${#decks[@]} deck(s) owned by $SEED_DIR"
  [ "$skipped" -gt 0 ] && say "-- $skipped deck(s) owned by another _seed, skipped"
  exit 0
fi

# ---- refresh the vendored bibliography ------------------------------------
# _seed/common/master.bib is a REAL FILE, not a symlink into ../masterbib, so
# that _seed is self-contained and can be cloned to a collaborator's machine.
# masterbib/ remains canonical; this copies from it whenever it is present.
# masterbib/ may be several levels up (a _seed submodule sits deeper in the
# tree than the shared one), so walk upward looking for it.
find_masterbib() {
  local d="$SEED_DIR"
  while [ "$d" != "/" ]; do
    [ -f "$d/masterbib/master.bib" ] && { echo "$d/masterbib/master.bib"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}
BIB_CANON="$(find_masterbib || echo /nonexistent)"
BIB_SEED="$SEED_DIR/common/master.bib"
if [ -f "$BIB_CANON" ]; then
  if ! cmp -s "$BIB_CANON" "$BIB_SEED"; then
    drift=1
    case "$MODE" in
      check|dryrun) say "== bibliography is stale; would copy masterbib/master.bib -> _seed/common/" ;;
      apply) cp -p "$BIB_CANON" "$BIB_SEED"; say "== refreshed _seed/common/master.bib from masterbib/" ;;
    esac
  fi
else
  say "== note: masterbib/ not present (collaborator checkout); using vendored master.bib"
fi

# ---- build per-course extension variants ----------------------------------
for c in $COURSES; do
  conf="$SEED_DIR/courses/$c/course.conf"
  [ -f "$conf" ] || continue
  # shellcheck disable=SC1090
  SANS_FONT=""; SANS_WEIGHTS=""; EXTENSIONS=""; FILES=""
  . "$conf"
  if [ "$MODE" = apply ]; then
    build_variant "$c" "$SANS_FONT" "$SANS_WEIGHTS" "$EXTENSIONS"
  fi
done

# ---- seed each deck -------------------------------------------------------
for d in "${decks[@]}"; do
  course="$(basename "$(dirname "$(dirname "$d")")")"
  conf="$SEED_DIR/courses/$course/course.conf"
  [ -f "$conf" ] || { say "!! no course.conf for $course, skipping $d"; continue; }
  SANS_FONT=""; SANS_WEIGHTS=""; EXTENSIONS=""; FILES=""
  # shellcheck disable=SC1090
  . "$conf"

  say "== ${d#$ROOT/}"

  # common invariants
  for f in iSchoolLogoLight.png quarto.png autofade.lua master.bib; do
    link "$SEED_DIR/common/$f" "$d/$f"
  done

  # per-course files
  for f in $FILES; do
    [ -e "$SEED_DIR/courses/$course/$f" ] || continue
    link "$SEED_DIR/courses/$course/$f" "$d/$f"
  done

  # Extensions: symlink the WHOLE _extensions directory. Quarto resolves a
  # symlinked _extensions/ dir, but refuses to load a symlink to an individual
  # extension package inside it ("Unable to read the extension").
  link "$SEED_DIR/build/$course/_extensions" "$d/_extensions"
done

say ""
case "$MODE" in
  check)
    if [ "$drift" -eq 1 ]; then say "DRIFT DETECTED in ${#decks[@]} deck(s). Run ./seed.sh to fix."; exit 1
    else say "OK — all ${#decks[@]} deck(s) in sync."; fi ;;
  dryrun) say "dry run: ${#decks[@]} deck(s) inspected." ;;
  apply)  say "seeded ${#decks[@]} deck(s); $changed link(s) written." ;;
esac
