# Setting up to compile lectures on a second machine

The lecture folders don't contain real copies of the shared files (logo, bib,
style, Quarto extensions). Each one is a **relative symlink** into `_seed/`.
That's what keeps 35 decks from drifting apart — but it means `_seed/` has to be
present, in the right place, before anything will render.

## The layout that matters

Symlinks point at `../../../_seed/...` from inside a lecture folder, so `_seed`
must sit **next to the course folder**, not inside it:

```
courses/
├── _seed/          <- must be here
├── hci/
│   └── lecture/
│       ├── 01Intro/        index.qmd + symlinks into ../../../_seed
│       └── 11Evaluation/
└── ...
```

Clone the repo so you end up with exactly that. If `_seed` ends up anywhere
else, every deck fails with `Include directive failed` or
`Unable to read the extension 'clean'`.

## One-time setup

```sh
cd courses/_seed
./seed.sh
```

`_seed/build/` holds the per-course Quarto extension variants. It's generated,
so it isn't committed — `seed.sh` creates it. You'll see:

```
== note: masterbib/ not present (collaborator checkout); using vendored master.bib
```

That's expected. `masterbib/` lives only on Mick's machine; `_seed` carries its
own copy of `master.bib`.

## Everyday use

```sh
cd courses/hci/lecture/11Evaluation
quarto render index.qmd
```

Adding a lecture:

```sh
cd courses/_seed
./newLecture.sh hci 15Wrapup "Wrap-up"
```

## Two things that will surprise you

**1. Shared files are shared.** `_metadata.yaml`, `style.css`, and `endMatter.md`
inside a lecture folder are symlinks. Editing one edits it for **every hci
deck**. That's deliberate — it's how the course subtitle, author list, and
styling stay consistent. Anything specific to one lecture belongs in that
lecture's `index.qmd`.

**2. Some editors break symlinks on save.** Editors that save "atomically"
(write a temp file, then rename over the target) replace the symlink with a real
file. The deck still renders, but it has silently stopped tracking the shared
copy. Before committing:

```sh
./seed.sh --check     # reports drift, exits 1 if found
./seed.sh             # repairs it
```

## What not to commit

Rendered output — `index.html` and `index_files/` — is regenerated on every
render and will conflict constantly. It's in `.gitignore`; leave it there.
