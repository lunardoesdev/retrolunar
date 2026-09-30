# findutils build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 4.10.0
- Build system: autotools
- Installs: `bin/find`, `bin/find` is the package; also `bin/xargs`; `share/man/man1/find.1`; **no library, no `.pc`**
- Requires: `findutils@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | topackage.md:24 records "blocked: needs `mktime_z`, Bionic exposes it at API 35", and I confirmed the exact declaration in the NDK r28b sysroot: `usr/include/time.h:171` is `time_t mktime_z(timezone_t _Nonnull __tz, struct tm* _Nonnull __tm) __INTRODUCED_IN(35);`. findutils' `lib/fstime.c` calls `mktime_z` for its `-newermt`/`-printf %T@` date handling, so it cannot compile below 35. |
| aarch64-android24 | **WILL NOT BUILD** | Same symbol, same line; 24 < 35. |
| aarch64-android35 | WILL BUILD | At exactly 35 the symbol is declared, so `lib/fstime.c` compiles. This is the one Android row that is expected to work, and the recorded blocker is consistent with it. |
| x86_64-android35 | WILL BUILD | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | mingw-w64's `time.h` has no `mktime_z` and no `timezone_t` at all, so `lib/fstime.c` fails for a second, independent reason. |
| clang-native | WILL BUILD | glibc has `mktime_z` unconditionally. |

## API level notes

**This is the cleanest API-level story in the shard: 35 is the floor and
the recipe is already right for it.** topackage.md:24 says exactly this
and my check of `time.h:171` confirms the `__INTRODUCED_IN(35)` guard
verbatim. The same guard shape blocks `packages/tar` (topackage.md:78,
"Bionic guards `mktime_z` until API 35"), so the two are consistent with
each other.

Note what this means in practice: `findutils@aarch64-android35` and
`findutils@x86_64-android35` should build, and every *lower* Android
system is out. That is a statement about the available system directories,
not about the recipe.

## Risks / what a reviewer should check

- **`--localstatedir="$OUT/var/lib/locate"` at `generic.lua:8`** is the one
  recipe-specific change and it is correct: `updatedb`/`locate` write their
  database under `localstatedir`, and pointing it at `$OUT` keeps the
  stage clean. Worth confirming that `make install` then creates
  `$OUT/var/lib/locate` rather than failing on a missing parent — `install`
  creates directories with `$(MKDIR_P)`, so it should.
- **The recipe does not set `ac_cv_func_...` cache answers**, so if a future
  findutils adds a *second* Bionic gap, it will surface as a fresh
  compile error rather than a silent misdetect. That is the preferred
  failure mode under AGENTS.md, so this is fine.
- **The man page build.** findutils ships pre-built `doc/find.1` etc. in
  the tarball. There is no `touch doc/*.1` guard here the way
  `diffutils/generic.lua:12` has one. Not a problem at 4.10.0, but it is
  the one asymmetry worth noting.
- **`xargs` and `find` are separate binaries** and both are installed.
  Consumers of the prefix will want both; neither is a library.

## How to verify once built

- `bin/find`, `bin/xargs`
- `share/man/man1/find.1`
- `file bin/find` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android 35`
  — note the API in the string, since 35 is the whole story here
- `$OUT/var/lib/locate` directory exists (the `--localstatedir` target)
- No library, no `.pc`
