# elfutils build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 0.193
- Build system: autotools
- Installs: **only libelf** — `lib/libelf.a` (or `.so`); `include/libelf.h`, `include/gelf.h`, `include/nl.h`, `include/dwarf.h` etc.; `lib/pkgconfig/libelf.pc`; `lib/lzma`/`libz` are *used*, not installed
- Requires: `bzip2` (exists), `xz` (exists, 5.8.1), `zlib` (exists, 1.3.1), `elfutils@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (configure)** | topackage.md:20 records "blocked: configure requires argp_parse, absent in Bionic", and I confirmed it: `usr/include/argp.h` does not exist anywhere in the NDK r28b sysroot. elfutils' `libdwfl/` (and `libdw/`) are built with argp for their `dwfl-*` main-like reporting, and `configure` fails at the `AC_CHECK_HEADERS([argp.h])`/link stage before any of the recipe's flags are consulted. The recipe's `--disable-debuginfod --enable-libdebuginfod=dummy` (`generic.lua:11-13`) addresses reachability, not argp. |
| aarch64-android24 | **WILL NOT BUILD (configure)** | Same; `argp.h` is absent from the whole sysroot, not API-gated. |
| aarch64-android35 | **WILL NOT BUILD (configure)** | Same. This one is *not* fixed by a new API level — the header simply is not shipped. |
| x86_64-android35 | **WILL NOT BUILD (configure)** | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD (configure)** | mingw-w64 has `argp.h` via an optional package but the base toolchain here does not, and elfutils is ELF-only besides. |
| clang-native | **UNCERTAIN** | The host glibc *does* have `<argp.h>`, so configure gets past the recorded blocker. Whether the rest of 0.193 builds and whether `make -C libelf install` (the narrow install at `generic.lua:16`) produces a working libelf is a separate question. Flagged, not claimed. |

## API level notes

**The recorded blocker is not an API-level one, and the distinction
matters.** topackage.md files elfutils under the general blocked list with
"configure requires argp_parse, absent in Bionic". `argp_parse` is a
*GNU C library* extension: glibc provides it, Bionic never has and never
will, at any API level. So unlike `nl_langinfo` (API 26) or `mktime_z`
(API 35), no new `aarch64-androidNN` directory unblocks elfutils. Only
upstream gaining a no-argp configuration, or dropping libdwfl, would — and
the recipe's narrow `make -j1 -C libelf install` shows the author was
already steering toward libelf-only; the problem is that **configure runs
before** that selection takes effect.

## Risks / what a reviewer should check

- **The open question from the first review is now closed, and the answer
  is no.** I asked whether elfutils 0.193 has a `--disable-libdw` /
  `--disable-libdwfl` and did not check. Checked: `./configure --help`
  offers 47 `--enable-*` / `--disable-*` / `--with-*` / `--without-*`
  options, and **none** of them removes a directory from the unconditional
  `SUBDIRS` line (`Makefile.am:31-32`, which lists `libdw`, `libdwfl`,
  `libdwelf`, `libdwfl_stacktrace`, `libstack`, `libebl`, `backends` and
  `tests` outright). The only test-tree-adjacent options are
  `--enable-helgrind`, `--enable-valgrind`, `--enable-tests-rpath` and
  `--with-biarch`, none of which touches `SUBDIRS`. So there is no flag, and
  the recipe should not invent one.
- **But the flag is not needed, and this is the more useful result.** libelf
  compiles standalone: `libelf/Makefile.in` needs only
  `$(top_builddir)/config.h`, which `./configure` has generated, and
  `config/eu.am:34` supplies `-I$(top_srcdir)/lib` for `common.h` and
  `abstract.h`. The recipe is now scoped to `make -j1 -C libelf` +
  `make -j1 -C libelf install`, so it never descends into the rest of the
  tree on any system. That is the shape `packages/libnuma` already uses.
  **Configure is what needs argp, not libelf** — so on a target that merely
  lacks argp, libelf may well be reachable, and that path is now as narrow
  as it can be. It is still untested on a target, because `./configure`
  aborts there before any of this runs. Worth a builder's one attempt before
  the package is written off.
- **The `libelf.pc` copy at `generic.lua:17-18`** is a hand-copy of a
  generated file, which AGENTS.md discourages in spirit (it prefers
  ordinary upstream install steps). It exists because `make -C libelf
  install` does not place it. Correct but worth noting.
- **bzip2/xz/zlib are required for the whole tree**, not just libelf:
  `libdwfl/` minidebuginfo support uses lzma and zlib. So even a libelf-only
  build pays for three dependencies in its configure.
- **The `touch ... config.h.in` guard at `generic.lua:14` is correct here** —
  elfutils does have a top-level `config.h.in`. One of the few in the shard
  where the standard guard line is exactly right.

## How to verify once built

Not verifiable on any target in this repo today. On a host with `argp.h`:

- `lib/libelf.a` (or `libelf-0.193.so`)
- `include/libelf.h`, `include/gelf.h`
- `lib/pkgconfig/libelf.pc` and `pkg-config --modversion libelf` → `0.193`
- `readelf -h lib/libelf.a` → `Machine: AArch64` on Android targets
- `ls $OUT/lib` should show libelf and **nothing else** — if `libdw.so` or
  `libdwfl.so` appear, the narrow install regressed
