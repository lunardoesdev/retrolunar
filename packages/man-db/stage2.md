REJECT

# man-db — stage 2 review

## Required changes

1. **`packages/man-db/generic.lua:19` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

## What the forecast gets right

The timestamp guard is **correct**: `configure.ac` is
`AC_CONFIG_HEADERS([config.h])` and `man-db/config.h.in` is the file on disk,
so `touch aclocal.m4 configure config.h.in` at line 17 names the right file.
This is one of the few in the shard where the standard guard is right as
written — worth saying, since it is the same text that is wrong in seven other
recipes here.

The recipe is otherwise conventional: flags from `$AUTOCONF_CONFIGURE_FLAGS`,
`make install` into `$OUT`, no `sed`, no patch, no `/dev/null`, no exported
search flag.

## A note the forecast should carry

man-db installs **programs**, not a library, and several of them are the kind
this tree installs as target binaries that nothing can run here. That is
allowed (they are target binaries, not host programs), but the forecast should
say so explicitly so a future reviewer does not mistake a non-runnable
`$PREFIX/bin/man` for a failed build. Compare `packages/libseccomp`'s
`scmp_sys_resolver`, which is the same situation.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/man`, `$PREFIX/bin/mandb` | `test -x $PREFIX/bin/man && test -x $PREFIX/bin/mandb` |
| `$PREFIX/share/man/man1/man.1` | `test -s $PREFIX/share/man/man1/man.1` |
| target binaries, never executed | `file $PREFIX/bin/man` shows the target arch — do not run it |
| no `zcat`/`gzip` dependency from the prefix | `grep -c gz $PREFIX/bin/man` — the build must not resolve a host gzip from `$PREFIX` |