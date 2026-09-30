ACCEPT

# systemd-man-pages 262 — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

## What the recipe gets right

- **Pure documentation, installed to the conventional place.** The build body is
  `mkdir -p $OUT/share/man` plus `cp -r $NESTDIR/source/systemd-man-pages/*`.
  Nothing is compiled, no configure runs, no flag is passed, nothing is
  hardcoded to a target, and the installed bytes are identical on every system.
  There is no architecture to check, and the honest build record says so.
- This package is the **data half of the systemd split**, and the split is
  correct: the man pages build standalone with no glibc dependency, while
  `packages/systemd` itself does not (topackage records systemd blocked on
  needing glibc ≥ 2.34 or musl ≥ 1.2.6). So this package is the only part of
  systemd that can exist in this prefix, and installing it without its
  counterpart is right rather than half-done — worth saying in the backlog so a
  reader does not assume the man pages imply systemd is present.
- `require("systemd-man-pages@source")` names no missing package.

## One observation about the destination

The payload goes to `$OUT/share/man/` with **no section subdirectory**. systemd
man pages are conventionally section 5 (`systemd.journal.5`, `systemd.unit.5`,
`systemctl.1` is section 1). If the tarball ships them flat, they land in
`share/man/` rather than `share/man/man5/`, which is unusual and will not be
found by a `man` implementation that looks in `manN/` subdirectories.

That may be fine — many prefixes are consumed by tooling that reads the
directory directly rather than by `man` — but it should be a deliberate,
recorded choice rather than an accident of `cp -r`. If `stage1.md` does not
mention the layout, it should; and if a `man`-style consumer is ever expected,
either `mkdir -p $OUT/share/man/man5` or a `MANPATH` entry is the fix. **Not a
reject reason**: the recipe is correct as written for its stated purpose, and
the builder can see the layout in one `ls`.

The same note applies to `packages/tcl-docs`, which deliberately version-names
its directory and so sidesteps the question.

## Carried to the build

- `share/man/` — `[ -d share/man ]`, and **record the layout and the file count**: `ls share/man | wc -l`. That one command settles both this observation and whether the copy happened at all.
- A representative page — `[ -s share/man/systemd.unit.5 ]` or `[ -s share/man/systemctl.1 ]`, whichever the tarball ships. Use `-s`, so an empty file is caught.
- No library, no headers, no `.pc`, and **no architecture to check**.
- The check that would matter for a `man` consumer: `ls share/man/man5 2>&1` — a missing `man5/` is expected under the current recipe, and its absence is the thing to record rather than to "fix" silently.