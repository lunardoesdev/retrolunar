REJECT

# psmisc — stage 2 review

## Required changes

1. **`packages/psmisc/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The timestamp guard is **correct**: `configure.ac` is
`AC_CONFIG_HEADERS([config.h])` and `psmisc/config.h.in` is on disk, so
`touch aclocal.m4 configure config.h.in` at line 8 names the right file. The
recipe is otherwise conventional — no `sed`, no patch, no `/dev/null`, no
exported search flag, flags from `$AUTOCONF_CONFIGURE_FLAGS`.

## Note for the forecast

psmisc's `killall`/`fuser`/`w` read `/proc`, and `psmisc`'s configure probes
for `/proc` contents. Those probes are **compile or link tests**, not run
tests, so they are cross-safe — but the forecast should say so rather than
leave it implied, since a `/proc`-reading package is exactly where a reviewer
would expect a `cross_compiling` branch. Also note psmisc installs `bin`
programs, so expect a wide install fan-out of target binaries.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/killall`, `$PREFIX/bin/fuser` | `test -x $PREFIX/bin/killall && test -x $PREFIX/bin/fuser` |
| `$PREFIX/share/man/man1/killall.1` | `test -s $PREFIX/share/man/man1/killall.1` |
| target binaries, never executed | `file $PREFIX/bin/killall` shows the target arch — do not run it |
| nothing host-arch leaked | `file $PREFIX/bin/* \| grep -c 'x86-64'` → 0 on an Android system |