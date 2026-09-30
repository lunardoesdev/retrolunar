# gawk build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 5.3.2
- Build system: autotools
- Installs: `bin/gawk` (and `bin/awk` → gawk, `bin/nawk`); `include/gawk.h`? no — `libgawk.a` is a convenience archive, **not installed**; `info/gawk.info`; man pages; **no library, no `.pc`**
- Requires: `gawk@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | topackage.md:27 records "blocked: needs `nl_langinfo`, Bionic exposes it at API 26". Confirmed: `usr/include/langinfo.h` exists in the NDK r28b sysroot but its declarations are behind `__BIONIC_AVAILABILITY_GUARD(26)` as `__INTRODUCED_IN(26)` — the same shape topackage.md:45 records for `less` with the line number `langinfo.h:97`. gawk's `libport/popen.c`, `locale.c` and the `strftime`/`strftime_l` paths call `nl_langinfo`. |
| aarch64-android24 | **WILL NOT BUILD** | Same symbol, same guard; 24 < 26. |
| aarch64-android35 | WILL BUILD | 35 ≥ 26, so `nl_langinfo` is declared and gawk's locale code compiles. The recipe is unchanged for this row and should need no new flags. |
| x86_64-android35 | WILL BUILD | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | mingw-w64's CRT has no `nl_langinfo` at all — it is not an Android API-level question but a platform one. gawk on MinGW is a known-partial port. |
| clang-native | WILL BUILD | glibc has `nl_langinfo` unconditionally; the same `__INTRODUCED_IN` guard does not exist. |

## API level notes

**26 is the floor, and this is a genuine API-level blocker — one of the
cleanest in the shard.** The same root cause blocks `packages/less`
(topackage.md:45) and `packages/pkgconf` (topackage.md:67), and the three
entries agree with each other. The only fixes are raising the target API or
patching the call site, and the first is available here (`aarch64-android35`
exists) while the second is forbidden by the no-patch rule. So the honest
verdict is: **gawk builds on the API-35 systems and on the host, and is
blocked on every lower Android system.**

## Risks / what a reviewer should check

- **gawk is a two-configure package, and the guard had to cover both.**
  `configure.ac:494` is `AC_CONFIG_SUBDIRS(extension)`, and `extension/` is a
  full sub-configure: it ships its own `configh.in`, `configure`,
  `aclocal.m4` and `Makefile.in`, with `extension/configure.ac:129` declaring
  its own `AC_CONFIG_HEADERS([config.h:configh.in])` — the same declaration as
  the top level at `configure.ac:472`. `find . -name configh.in` returns
  exactly two hits, `./configh.in` and `./extension/configh.in`. An earlier
  version of the recipe guarded only the top-level template and left the
  `find ... Makefile.in` sweep to reach `extension/Makefile.in`, which meant
  `extension/configh.in` — the sub-configure's own autoheader target — was
  still live and could re-run from a tarball mtime. The guard now sweeps all
  four files by name rather than naming either directory, so the two
  sub-configures cannot drift apart.
- **The recipe passes no flags at all** (`generic.lua:7`). That is correct
  for this package in the sense that no flag can work around a missing
  libc symbol — but it also means the recipe has never been exercised on
  Android at all, and there is no evidence anyone has tried. If a reviewer
  expects a `android.lua` here, its absence is the finding.
- **gawk is used by this prefix's own build tooling** in some setups
  (autotools' `missing` scripts, `libtool` trace). Those uses are on the
  *build host* and are served by the host's own gawk, not this package, so
  the blocker does not propagate. Worth confirming nobody has wired a
  target gawk into a build step.
- **`--with-readline` is not passed**, so gawk links no line editor. That is
  the right call for a target prefix (and avoids depending on
  `packages/readline`), but it does reduce the tool.
- **`make -j1 install` at `generic.lua:13`** is the whole build. gawk's
  `make all` also builds `libgawk.a`, a convenience archive used only by
  gawk's own tests; it is built and discarded. Not a problem, just a small
  waste at `make -j1` serial speed.
- **No `touch` guard for `info/gawk.info`.** gawk ships a pre-built
  `.info`; if its mtime ever loses to `doc/gawk.texi`, make will want
  `makeinfo`. Same minor asymmetry noted for bison and findutils.

## How to verify once built

- `bin/gawk`, `bin/awk`, `bin/nawk`
- `info/gawk.info`
- `file bin/gawk` → `ELF 64-bit LSB pie executable, ARM aarch64, ... for Android 35`
  — the API level in the string is the whole story for this package
- No library, no `.pc`
