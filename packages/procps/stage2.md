REJECT

# procps — stage 2 review

## Required changes

1. **`packages/procps/generic.lua:9` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The timestamp guard is **correct**: `configure.ac` is
`AC_CONFIG_HEADERS([config.h])` and `procps/config.h.in` is on disk, so
`touch aclocal.m4 configure config.h.in` at line 8 names the right file. The
recipe is otherwise conventional — flags from `$AUTOCONF_CONFIGURE_FLAGS`, no
`sed`, no patch, no `/dev/null`, no exported search flag.

## What to watch

procps installs a lot of small **target** programs (`ps`, `top`, `free`,
`kill`, `uptime`, …). That is permitted — they are target binaries, not host
programs — but it means the `make install` fan-out is wide and a single
missing symbol in one of them fails the whole package. procps is also a
plausible consumer of Bionic gaps in the `AGENTS.md:366-370` list
(`program_invocation_short_name`, `nl_langinfo`), so the Android rows deserve
the same API-level scrutiny `less` and `pkgconf` got. If the forecast marks
them "moderate confidence", it should say *which* symbol is the risk.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/ps` | `test -x $PREFIX/bin/ps` |
| `$PREFIX/share/man/man1/ps.1` | `test -s $PREFIX/share/man/man1/ps.1` |
| target binaries, never executed | `file $PREFIX/bin/ps` shows the target arch — do not run it |
| no host-only helpers leaked | `find $PREFIX/bin -name 'free'` → empty is fine; the check is that nothing in `$PREFIX/bin` is a **host** binary: `file $PREFIX/bin/* \| grep -c 'x86-64'` must be 0 on an Android system |