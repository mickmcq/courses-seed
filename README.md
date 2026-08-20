# `_seed/` — one source of truth for lecture slide files

Replaces the old scheme (`ssBoilerplate/` + hand-maintained `propagate` scripts),
which drifted because every destination path had to be listed by hand.

## How it works

Two layers:

- **`common/`** — files that are identical in every deck, in every course:
  `iSchoolLogoLight.png`, `quarto.png`, `autofade.lua`, `master.bib`
  (a symlink to `../../masterbib/master.bib`, still the canonical bib), and
  `_extensions/` holding **pristine, unmodified** extensions.
- **`courses/<course>/`** — what legitimately differs per course:
  `_metadata.yaml` (subtitle, authors, format options), `style.css`,
  `endMatter.md` (hci only), and `course.conf` (font choice, extension list).

Everything seeded into a deck is a **relative symlink** into `_seed/`, so a deck
cannot drift. Editing `_seed/courses/hci/_metadata.yaml` changes all hci decks
at once.

## Commands

```sh
./seed.sh              # apply — symlink shared files into every deck
./seed.sh --check      # report drift, change nothing (exit 1 if drift)
./seed.sh --dry-run    # show what would change
./seed.sh --list       # list the decks that would be seeded

./newLecture.sh <course> <dirName> "Title"   # scaffold a new deck, then seed it
./renderAll.sh                               # re-render every deck, report pass/fail
```

## Targets are discovered, never listed

`seed.sh` seeds any directory under `<course>/lecture/` whose `index.qmd` or
`_metadata.yaml` declares `clean-revealjs`. New lectures are picked up
automatically — this is the specific failure the old `propagate` scripts had.

Excluded by name: `old*`, `claude0*`, `qwen0*`.

Also excluded automatically, because they are not clean-revealjs decks:

| deck | what it is |
|---|---|
| `hci/lecture/14Conclusion` | plain `revealjs`, `theme: simple` |
| `hci/lecture/hciExperiments` | an HTML document, not a slideshow |

To bring one of these onto the house format there is a bootstrap step, because
discovery keys on `clean-revealjs` and a converted deck's `index.qmd` keeps only
its `title:` — the format lives in the shared `_metadata.yaml`. So symlink that
file in by hand first, then seed:

```sh
cd <course>/lecture/<deck>
ln -s ../../_seed/courses/<course>/_metadata.yaml _metadata.yaml
cd - && ./_seed/seed.sh          # picks the deck up and writes the rest
```

Cut the deck's own YAML header down to `title:`, replace its hand-written
References/END/Colophon slides with `{{< include endMatter.md >}}`, and copy in
`mathjax-config.js` from any seeded deck (the clean extension loads it via
`format-resources`; `seed.sh` does not manage it). `seed.sh` overwrites a local
`style.css` or `master.bib` with the shared symlink, so check first that the
deck's bibliography is a subset of `common/master.bib`.

## Per-course fonts without forking the extension

hci uses Fira Sans; the others use stock Roboto. Previously this lived as a hand
edit inside `_extensions/grantmcdermott/clean/clean.scss`, which is why the
extension froze at old versions — an edited extension can't be updated.

Now `common/_extensions/` stays pristine and `seed.sh` **generates** the
per-course variant into `build/<course>/_extensions/`, substituting the font from
`course.conf`. The generated hci `clean.scss` is byte-identical to the old hand
fork, so nothing changed visually.

To update an extension:

```sh
cd _seed/common && quarto update grantmcdermott/clean
cd .. && ./seed.sh          # rebuilds every course variant and relinks
```

`build/` is generated output — never edit it, it is wiped on each run.

## Two Quarto quirks worth knowing

1. **Don't set `theme:` at the document level** to add an scss overlay. It
   replaces the extension's theme rather than adding to it, and the clean styling
   silently vanishes. That's why the font is handled by generation instead.
2. **`_extensions/` may be a symlink, but the packages inside it may not.**
   Symlinking `_extensions/grantmcdermott/clean` gives
   `ERROR: Unable to read the extension 'clean'`. Symlinking the whole
   `_extensions/` directory works. `seed.sh` does the latter.


## More than one `_seed` on a machine

`hci/lecture/_seed` is a **submodule** of the `hci-lecture` repo, so that a clone
of that repo is self-contained for a collaborator. `~/courses/_seed` is the
shared checkout used by the courses that aren't shared.

Each checkout owns the decks *nearest* to it, walking up the tree, so the two
never fight over the same deck:

| checkout | owns |
|---|---|
| `hci/lecture/_seed` (submodule) | the 17 hci decks |
| `~/courses/_seed` | infointeractdsgn (17) + appProtoStudio (1) |

Run `seed.sh` from whichever checkout owns the decks you changed; `--list` shows
what each one claims. They are the same repo, so a change made in one must be
pushed and pulled into the other.

## Superseded

- `ssBoilerplate/` — its role is now `_seed/common` + `_seed/courses/*`.
- `masterbib/propagate` — `master.bib` is symlinked from `masterbib/`, so it is
  always current with no propagation step. The script still lists non-lecture
  targets (syllabi, `stats/`, `cli/`, `promptEngr/`, `db/`, `uxproto/`) that
  `_seed` does not yet cover, so don't delete it until those are migrated.
- `boilerplate/propagate` — syllabus files, untouched by this system.
