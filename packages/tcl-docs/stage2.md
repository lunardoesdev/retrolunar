ACCEPT

# tcl-docs 8.6.18 — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

## What the recipe gets right

- **Pure documentation, treated as pure documentation.** The build body is
  `mkdir -p $OUT/share/doc/tcl8.6.18` plus one `cp -r`. Nothing is compiled, no
  configure runs, no flag is passed, nothing is hardcoded to a target. The
  installed bytes are identical on every system, so there is no architecture to
  check — and the honest build record says so rather than treating the absence
  of an `llvm-objdump` check as a gap.
- `$OUT/share/doc/tcl8.6.18` is a versioned directory under `share/doc`, which
  is the conventional place for a documentation payload and does not collide
  with anything else in the prefix. Note the `8.6.18` here is the *docs* release,
  which is deliberately ahead of the Tcl library (`packages/tcl` is 8.6.16) —
  that is correct, not a mismatch, and `topackage.md:76` records the same
  pairing.
- The `cp -r $NESTDIR/source/tcl-docs/*` form copies the unpacked tree's
  contents rather than the directory itself, so `$OUT/share/doc/tcl8.6.18/`
  holds the man pages directly. That is what a reader wants. (The `*` form
  silently skips dotfiles, which for a doc tarball is fine, but if the payload
  ever gains a `.htaccess`-style file it would be dropped — worth a thought, not
  a change.)
- `require("tcl-docs@source")` names no missing package.

## The one coupling worth recording

`tcl-docs` documents the Tcl *library* that `packages/tcl` builds, and the two
are versioned independently (docs 8.6.18 vs library 8.6.16). Nothing enforces
that pairing, and nothing in the recipe references `tcl` — which is correct,
because the docs are genuinely independent data. But it does mean a future Tcl
bump could leave the docs describing a version the prefix does not contain,
with nothing to notice. A line in the backlog entry recording the deliberate
version skew is the cheapest guard; it is a backlog nicety, not a recipe defect.

## Carried to the build

- `share/doc/tcl8.6.18/` — `[ -d share/doc/tcl8.6.18 ]`, and record the file count: `ls share/doc/tcl8.6.18 | wc -l`. For a doc tarball a non-trivial count is the whole check.
- A representative man page — `[ -s share/doc/tcl8.6.18/Tcl.n ]` or whichever the tarball ships; use `-s` so an empty file is caught.
- No library, no headers, no `.pc`, and **no architecture to check** — the builder should record that explicitly rather than searching for a binary that will never exist.
- **Never "test" it by rendering the docs**; the whole point is that nothing is built.
