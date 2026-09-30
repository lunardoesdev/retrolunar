# coreutils build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 9.7
- Build system: autotools
- Installs: ~100 programs into `bin/` (`ls`, `cp`, `mv`, `cat`, `sed`, `tar`-adjacent tools, `test`, `[`, `env`, `date`, …), plus `info/coreutils.info` and man pages; **no library, no `.pc`**
- Requires: `acl` (exists, 2.3.2), `coreutils@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | coreutils 9.7 is careful about Bionic: its `lib/` directory carries explicit `AC_CHECK_FUNCS` for every extension and falls back to the gnulib substitutes it bundles, which is exactly how `getgrent`, `nl_langinfo`-adjacent and `siginfo` gaps are handled without a wall. Its gnulib copy of `getopt` replaces the libc one, so Bionic's reduced `getopt` is irrelevant. The one recipe change (`--enable-no-install-program=kill,uptime`, `generic.lua:8`) removes two tools that procps and psmisc provide. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral apart from gnulib's own byte-order handling, which is compiled per host. |
| x86_64-mingw | WILL BUILD | coreutils' gnulib base handles mingw; several tools are still built but the package is large and the build is serial (`make -j1`), so this is slow rather than hard. |
| clang-native | WILL BUILD | Native; topackage.md:16 records Coreutils 9.7 as `[x]`. |

## API level notes

**coreutils is unusually well-suited to low API levels and 21 is fine.**
That is a deliberate upstream property, not luck: gnulib's
`AC_CHECK_FUNCS`-driven substitution means a missing Bionic function
produces a bundled replacement, not a compile error. The one thing to keep
an eye on is that a *newer* coreutils may start using a function gnulib has
not yet replaced, which is a version-bump risk rather than a current
blocker. Nothing in 9.7 needs an API above 21.

## Risks / what a reviewer should check

- **This is the slowest serial build in the shard.** ~100 programs at
  `make -j1`. AGENTS.md mandates serial builds to stay under 2 GB, so this
  is correct, but it means a coreutils build dominates any recipe that
  depends on it.
- **`--enable-no-install-program=kill,uptime` is a fact about this package
  set, not about coreutils.** If psmisc or procps were removed, two tools
  would silently disappear from the prefix. Worth a comment in the readme.
- **`require("acl")`** is for the `cp --preserve=xattr` and `ls -@` paths.
  If `acl` stops building, coreutils stops building — an invisible
  dependency by name alone. The `stage1.md` next door is the place to check.
- **No `-Wno-error` guard and no system-level `CFLAGS` addition.** The
  Android systems' `$CFLAGS` is `-O2 -fPIC ... -DANDROID`, which is what
  coreutils' configure wants for Bionic. Good: the platform fact lives in
  the system, not the recipe.
- **The man pages are built from the release's pre-generated `.1` files**
  or regenerated with help2man depending on mtimes. coreutils ships
  `man/*.1` pre-built, and the release tarball's mtimes make the shipped
  ones win. There is no explicit `touch man/*.1` guard the way
  `diffutils/generic.lua:12` has one. Not a problem at 9.7.

## How to verify once built

- `bin/ls`, `bin/cp`, `bin/env`, `bin/test`
- `ls $OUT/bin | wc -l` → roughly 100 entries
- `bin/kill` and `bin/uptime` should be **absent** (procps/psmisc own them)
- `file bin/ls` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- `share/info/coreutils.info` present
- No library, no `.pc`
