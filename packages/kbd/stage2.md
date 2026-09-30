REJECT

# kbd — stage 2 review

## Required changes

1. **`packages/kbd/generic.lua:9` — bare `make`, violating the serial-build
   rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The timestamp guard is **correct**: `configure.ac` is
`AC_CONFIG_HEADERS([config.h])` and `kbd/config.h.in` is on disk, so
`touch aclocal.m4 configure config.h.in` at line 8 names the right file.
`--disable-vlock` at line 7 is a real switch and correctly avoids building the
vlock lock-screen helpers.

## The backlog framing needs the same correction as `less`

The backlog lists kbd among entries that "name a symbol absent at *every*
level", which is a stronger claim than "gated at some API level". If that is
right, kbd is **not** recoverable by adding an `android26`-or-later target,
and should be recorded as dropped rather than queued. The forecast should
state which it is, and name the symbol — the difference matters for whether
anyone spends time adding a target. Compare `less`/`pkgconf` (API 26,
recoverable) against `kmod` (`get_current_dir_name`, absent at every level,
not recoverable).

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/loadkeys` (or `showkey`) | `test -x $PREFIX/bin/loadkeys` |
| `$PREFIX/share/man/man1/loadkeys.1` | `test -s $PREFIX/share/man/man1/loadkeys.1` |
| no vlock helpers | `find $PREFIX/bin -name 'vlock'` → empty, proving `--disable-vlock` took effect |
| target binaries, never executed | `file $PREFIX/bin/loadkeys` shows the target arch |