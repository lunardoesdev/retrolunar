# bash build forecast

- Recipe: `generic.lua` only, source `source.lua` (no per-platform file)
- Version pinned: 5.3
- Build system: autotools
- Installs: `bin/bash`, `bin/bashbug`, `bin/buzh.in`; `info/bash.info`; **no `.pc`, no library**
- Requires: `readline` (exists, 8.3), `bash@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | topackage.md:11 records "Android 24 blocked: getgrent requires API 26", and I confirmed it in the NDK r28b sysroot: `usr/include/grp.h:56` is `struct group* _Nonnull getgrent(void) __INTRODUCED_IN(26);`. `bashline.c:2742` calls `getgrent` (`while (grent = getgrent ())`) when no user/group name is supplied, so a 21 and a 24 target both fail to *compile* that file. The `CC_FOR_BUILD` line in `generic.lua:19` only affects bash's host-side `builtins/` helper and does not touch this, so it cannot help. **Citation note:** an earlier version of this row blamed `libglob/libglob.c`, which does not exist in bash 5.3 — `ls libglob` finds no such directory. The call is in `bashline.c`. |
| aarch64-android24 | **WILL NOT BUILD** | Same symbol, same line. 24 < 26. |
| aarch64-android35 | WILL BUILD | 35 ≥ 26, so `getgrent` is declared and `bashline.c:2742` compiles. The `$CC_FOR_BUILD=cc` with `-std=gnu17` in `generic.lua:19` applies (host-side `builtins/` helper whose `bool` typedef GCC 16 rejects in its default mode). |
| x86_64-android35 | WILL BUILD | Same as aarch64-android35; bash is not arch-conditional in the relevant files. |
| x86_64-mingw | WILL BUILD | bash 5.3's configure has an explicit `mingw*` branch and the recipe passes no `--with-curses`/termcap override; the only interaction is `--with-installed-readline` (`generic.lua:10`), which points at the prefix's readline. |
| clang-native | WILL BUILD | glibc, and `getgrent` is a plain libc entry point there. |

## API level notes

**This package is the clearest API-level case in the a–g shard: 26 is the
floor, and the recipe does nothing to raise it.** The only way to build
`bash@android21` or `bash@android24` is to either raise the target API (out
of scope — the system directories are fixed) or to patch `bashline.c`, which
the no-patch rule forbids. I checked the NDK header rather than taking the
backlog on trust: `grp.h:56` carries `__INTRODUCED_IN(26)` on
`getgrent`.

Related but not the blocker here: API 21 also lacks a real `stderr` symbol
(only a macro), which is what `packages/curl`'s comment describes. bash
does not trip over that because it does not link OpenSSL static archives.

## Risks / what a reviewer should check

- **`bash/android.lua` has been deleted and the flag moved to
  `generic.lua`.** An earlier version of this file described the two as
  "byte-identical apart from the `--std=gnu17` line" and treated that as
  acceptable per AGENTS.md's one-file-per-family rule. That was wrong on the
  merits: the wall is a **cross-compiling** fact, not an Android one.
  `builtins/mkbuiltins.c:23-27` includes `<buildconf.h>` instead of
  `<config.h>` whenever `CROSS_COMPILING` is set (`configure.ac:496` appends
  `-DCROSS_COMPILING`, folded in by `builtins/Makefile.in:64`);
  `buildconf.h.in:42` is `#undef HAVE_C_BOOL` with the comment "defining this
  implies a C23 environment", and it never defines `HAVE_STDBOOL_H`, so
  `bashansi.h:44` `typedef unsigned char bool;` is what compiles. Against
  host gcc 16 at its default `-std=gnu23` that is `error: 'bool' cannot be
  defined via 'typedef'`; `-std=gnu17` is clean. `x86_64-mingw` is *also* a
  cross build — its system file sets `--host=x86_64-w64-mingw32` — resolves
  through `generic.lua`, has no `android.lua`, and therefore hit the identical
  error. `clang-native` is not cross, so the helper includes `<config.h>` and
  compiles clean at either standard, which is why the native build never
  needed the flag and the Android-only placement looked plausible.
- **The `CC_FOR_BUILD`/`CFLAGS_FOR_BUILD` recipe-local override is the
  documented exception** to "never export CFLAGS in a recipe" (AGENTS.md
  allows recipe-local workarounds with a reason). The `CFLAGS_FOR_BUILD`
  spelling is right: `builtins/Makefile.in:64` folds it into
  `CCFLAGS_FOR_BUILD` and `configure.ac:266` declares it `AC_ARG_VAR`, so
  setting it in configure's environment is sufficient. It targets
  `builtins/`'s host helper, not the target library.
- **`--with-installed-readline` binds bash to this prefix's readline 8.3.**
  If `readline` is rebuilt for a system, bash's stamp goes stale and it
  rebuilds too; that is correct, just worth knowing.
- **topackage.md says "Android 24 blocked" but does not mention 21.** The
  blocker is identical at both levels, so the 21 row is blocked for the
  same reason: `grp.h:56` gates `getgrent` at API 26, so 21, 23 and 24 all fail
  to compile `bashline.c:2742` and 35 is expected to build. That is an
  omission in the backlog line rather than a contradiction, but it invites
  someone to try `android21` and lose an hour.

## How to verify once built

- `bin/bash`
- `file bin/bash` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android 35`
- `info/bash.info` present
- No library and no `.pc`; bash is a program
- Run on a device or inspect symbols only — `strings bin/bash | grep getgrent`
  is not a proof, the real check is that the file linked at all
