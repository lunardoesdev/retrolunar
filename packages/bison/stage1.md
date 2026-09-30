# bison build forecast

- Recipe: `generic.lua` **and** `android.lua` (byte-identical bodies), source `source.lua`
- Version pinned: 3.8.2
- Build system: autotools (C++ for the skeleton compiler, C for the tables)
- Installs: `bin/bison`, `bin/yacc`; `share/bison/skeleton.h`; `info/bison.info`; **no `.pc`, no library** (a `lib/` convenience archive is built but not installed)
- Requires: `gperf@native` (exists, 3.3), `bison@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | bison's C++ sources (`src/scan-gram.c`, `src/parse-gram.c`, `src/symtab.cc`, `src/tables.cc`) use only libstdc++ and plain POSIX. It generates its skeleton tables with gperf, and both recipes pull `gperf@native` (`generic.lua:1`) so the gperf that runs is the *host* one from `$NATIVE_PREFIX/bin` — which is the only correct choice, because gperf is a build-time tool, not a target artifact. No `nl_langinfo`, no `argp_parse`, no `getgrent`, no `scandir`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | No arch-conditional code in the bison build. |
| x86_64-mingw | WILL BUILD | bison 3.8.2's configure has an explicit `mingw*` branch. The C++ runtime comes from the toolchain's libstdc++, and the mingw system sets `CXXFLAGS="$CFLAGS"` (x86_64-mingw/generic.lua:28) which is the expected shape. |
| clang-native | WILL BUILD | Native; topackage.md:14 records Bison 3.8.2 as `[x]`. |

## API level notes

Not a variable. Nothing in bison's build reaches for a symbol introduced
after API 21. This matters because bison is the *input* to
`packages/automake` and `packages/flex`, so a bison wall would be a wide
one; there isn't one.

## Risks / what a reviewer should check

- **`gperf@native`, not `gperf`** is the whole trick (`generic.lua:1`,
  `android.lua:1`), and it is the same shape
  `packages/libseccomp/generic.lua` uses. If it were dropped, `configure`
  would find the *target* gperf in `$PREFIX/bin` if one existed, and
  executing it would need an emulator. As written, the loader's
  `$NATIVE_PREFIX/bin` PATH entry makes this correct with no extra PATH
  manipulation in the recipe. Good design, and worth a reviewer's
  confirmation that it stays that way.
- **The comment at `generic.lua:11` is placed above `make -j1`**, which
  reads oddly — it explains the gperf dependency, not the make line. Minor.
- **bison's C++ link needs the target libstdc++**, which the NDK provides as
  `libc++.so` plus `libstdc++.a` in the sysroot. Not a prefix dependency,
  but it is why this package is a real cross build rather than a C-only one.
- **The `info` manual is built by makeinfo.** bison's release ships
  `doc/bison.info` pre-built; if that file is ever newer than its `.texi`,
  make will want `makeinfo`. There is no `touch doc/bison.info` guard here
  the way `gperf/generic.lua:12` has one. Not a problem at 3.8.2, but it is
  the one asymmetry with the gperf recipe worth noting.

## How to verify once built

- `bin/bison`, `bin/yacc`
- `share/bison/skeleton.h`
- `info/bison.info`
- `file bin/bison` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android NN`
- No `.pc`; bison is a program
