ACCEPT

# man-pages — stage 2 review

## What the recipe gets right

- **Pure data, no build system.** `generic.lua:7-9` loops over `man/*` and
  copies each into `$OUT/share/man/`. No compiler, no `make`, no flags.
- The `for` loop is serial, and there is no `sed`, no patch, no `/dev/null`,
  no `DESTDIR`.
- `$OUT/share/man` is the right destination and matches where every other
  recipe in this tree installs man pages (compare
  `packages/ncurses/generic.lua:16-27` and `packages/m4`).

## One thing to note, not a defect

`generic.lua:7` copies `man/*` including the per-section subdirectories
(`man/man1/`, `man/man3/`, …) via `cp -r "$_s" "$OUT/share/man/"`, so the
section directories are preserved. That is correct and worth stating in the
forecast, because a reviewer expecting flat files would otherwise flag it.

Also note the interaction with the guard-less packages: this tree has **no
mandatory package** for `man` beyond what is installed here, so a consumer
that runs `man` needs both this and `ncurses`. Worth one line.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/share/man/man1/*.1` | `ls $PREFIX/share/man/man1 \| wc -l` → the count the forecast states |
| `$PREFIX/share/man/man3/*.3` | `ls $PREFIX/share/man/man3 \| wc -l` → the count the forecast states |
| section layout preserved | `find $PREFIX/share/man -maxdepth 1 -type d` shows `man1`, `man3`, … |
