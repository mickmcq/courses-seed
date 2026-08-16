#!/usr/bin/env bash
# newLecture.sh — scaffold a new lecture deck and seed it.
#
#   ./newLecture.sh <course> <dirName> "Lecture Title"
#
# e.g.  ./newLecture.sh appProtoStudio 02sketching "Sketching"
#
# Creates <course>/lecture/<dirName>/index.qmd containing only a title, then
# runs seed.sh so every shared file is symlinked in. All shared config comes
# from _seed/courses/<course>/_metadata.yaml.

set -euo pipefail

SEED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SEED_DIR")"

if [ $# -lt 3 ]; then
  echo "usage: $0 <course> <dirName> \"Lecture Title\"" >&2
  echo "courses available: $(ls "$SEED_DIR/courses" | tr '\n' ' ')" >&2
  exit 2
fi

course="$1"; name="$2"; title="$3"
dest="$ROOT/$course/lecture/$name"

[ -d "$SEED_DIR/courses/$course" ] || { echo "no seed config for course '$course'" >&2; exit 1; }
[ -e "$dest" ] && { echo "already exists: $dest" >&2; exit 1; }

mkdir -p "$dest"
cat > "$dest/index.qmd" <<EOF
---
title: "$title"
---

# [Section]{.r-fit-text}

## First slide

Content goes here.

## References
EOF

echo "created $dest/index.qmd"

# Link _metadata.yaml first: seed.sh discovers decks by looking for
# `clean-revealjs`, and a title-only index.qmd doesn't declare it yet.
rel="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[2], sys.argv[1]))' \
       "$dest" "$SEED_DIR/courses/$course/_metadata.yaml")"
ln -sfn "$rel" "$dest/_metadata.yaml"

COURSES="$course" "$SEED_DIR/seed.sh" >/dev/null
echo "seeded. render with:  cd $dest && quarto render index.qmd"
