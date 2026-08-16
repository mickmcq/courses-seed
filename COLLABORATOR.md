# Compiling the lectures on your own machine

The lecture folders don't contain real copies of the shared files (logo,
bibliography, styles, Quarto extensions). Each one is a **symlink** into
`_seed/`. That's what keeps the decks from drifting apart — but it means
`_seed/` has to be populated before anything will render.

`_seed/` is a **git submodule** pointing at
[`mickmcq/courses-seed`](https://github.com/mickmcq/courses-seed). Submodules
are not fetched by a plain `git clone`, which is the one thing that trips
everybody up.

## First time

```sh
git clone --recursive https://github.com/mickmcq/hci-lecture.git
cd hci-lecture/_seed && ./seed.sh
```

`--recursive` is not optional. Without it `_seed/` is an empty directory and
every deck fails with `Include directive failed` or
`Unable to read the extension 'clean'`.

`./seed.sh` builds `_seed/build/`, which holds the Quarto extensions with the
course font applied. It's generated, so it isn't committed. You'll see:

```
== note: masterbib/ not present (collaborator checkout); using vendored master.bib
```

That's expected — `masterbib/` lives only on Mick's machine, and `_seed` carries
its own copy of `master.bib`.

## If you already have a clone

```sh
git pull
git submodule update --init --recursive
cd _seed && ./seed.sh
```

## Everyday use

```sh
cd 11Evaluation
quarto render index.qmd
```

Adding a lecture:

```sh
cd _seed
./newLecture.sh hci 15Wrapup "Wrap-up"
```

## Rendered HTML is no longer tracked

`index.html` and `index_files/` used to be committed — 34 files, 176 MB, and the
cause of most merge conflicts. They're now in `.gitignore`. **Render locally
rather than pulling someone else's output.** Your `index.html` staying dirty is
normal; git won't see it.

## Two things that will surprise you

**1. Shared files are shared.** `_metadata.yaml`, `style.css`, and `endMatter.md`
inside a lecture folder are symlinks into `_seed/courses/hci/`. Editing one edits
it for **every hci deck**. That's deliberate — it's how the subtitle, author
list, and styling stay consistent. Anything specific to one lecture belongs in
that lecture's `index.qmd`.

Because they live in the submodule, changing them is a separate commit:

```sh
cd _seed
# edit courses/hci/_metadata.yaml
git commit -am "..." && git push          # commit in courses-seed
cd .. && git add _seed
git commit -m "bump seed" && git push     # move hci-lecture's pointer
```

**2. Some editors break symlinks on save.** Editors that save "atomically"
(write a temp file, then rename over the target) replace the symlink with a real
file. The deck still renders, but it has silently stopped tracking the shared
copy. Before committing:

```sh
./_seed/seed.sh --check    # reports drift, exits 1 if found
./_seed/seed.sh            # repairs it
```

## If symlinks come through as text files

If `git config core.symlinks` is `false`, git writes symlinks as plain text files
containing the target path, and nothing renders. Fix with:

```sh
git config core.symlinks true
git checkout -- .
```
