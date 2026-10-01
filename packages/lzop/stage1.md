# lzop build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 1.04
- Build system: autotools. The release ships a generated `configure` (255723
  bytes) plus `aclocal.m4` and `Makefile.in`, so no autoreconf bootstrap is
  needed.
- Config template: **`config.hin`** — `configure.ac:79` reads
  `AC_CONFIG_HEADERS([config.h:config.hin])`. The file `config.hin` is 13960
  bytes and is an entry in the 126-file tarball index. This is one of the
  non-`config.h.in` spellings AGENTS.md lists, and `touch config.h.in` here
  would create an inert file instead of guarding the real template.
- Sub-configured: no. `configure.ac:201` is `AC_CONFIG_FILES([Makefile])`
  alone, and the tree has exactly one `Makefile.in` (top level). The program
  sources live in `src/` but are compiled by the top-level Makefile
  (`Makefile.am:42` `bin_PROGRAMS = src/lzop`, `:43-46`
  `src_lzop_SOURCES = src/*.c`), not by a sub-configure.
- Installs: `bin/lzop` only.

## The dependency that does not exist

**lzop needs LZO, and LZO is not in this prefix.** Both halves are hard
errors in `configure`, not warnings:

- `configure.ac:104-118` looks for the LZO headers in two spellings
  (`lzo/lzoconf.h` + `lzo/lzo1x.h`, then `lzoconf.h` + `lzo1x.h`) and, if
  neither is found, `configure.ac:117` calls
  `AC_MSG_ERROR([LZO header files not found. ...])`. There is no
  `--without-lzo`.
- `configure.ac:145-150` then links against the library:
  `AC_CHECK_LIB(lzo,__lzo_init2,...)` for LZO v1 headers or
  `AC_CHECK_LIB(lzo2,__lzo_init_v2,...)` for v2, each with
  `AC_MSG_ERROR([LZO library ... not found])`.

`ls packages | grep -i lzo` returns nothing: no `packages/lzo`, no
`packages/lzo2`, no `packages/liblzo2`. The recipe therefore carries
`require("lzo")`, which is the correct dependency and **does not resolve
today** — `retrolunar install lzop@<sys>` fails at the loader with a missing
package before any build step runs. That is the honest state, not a recipe
defect.

What LZO would need to be added, for whoever adds it:

- Upstream is `https://www.oberhumer.com/opensource/lzo/`, latest stable
  **liblzo2 2.10**, tarball `lzo-2.10.tar.gz` (autotools; ships `configure`).
- It would install `include/lzo/lzoconf.h`, `include/lzo/lzo1x.h`,
  `include/lzo/lzo1x_odr.h`, `include/lzo/lzoconf.h` and `lib/lzo2.a` (plus
  `lib/lzo2.la`, and a `lzo.pc`? — liblzo2 2.10 does **not** ship a
  pkg-config file, so `lzop`'s `AC_CHECK_LIB(lzo2, __lzo_init_v2)` finds the
  archive through `$LDFLAGS=-L$PREFIX/lib` alone).
- Package name in this repo should be `lzo` (matching the `require("lzo")`
  both recipes now carry). Its own `stage1.md` would have to answer the same
  question lzop does about API levels — liblzo2 is plain C with no
  API-gated symbol, so it is expected to be straightforward.
- Nothing else in the prefix depends on LZO today; lzop and lrzip are the
  only two consumers.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | Not an API-level problem: the loader fails before configure, because `require("lzo")` names a package this prefix does not have. If lzo is added, the level is irrelevant to lzop itself: `src/` contains no use of `nl_langinfo`, `mktime_z`, `posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass` or `O_BINARY`. The only `O_BINARY` in the tree is `src/lzop.c:359-360`, guarded by `#if defined(O_BINARY)`, and `src/miniacc.h:7659`/`:7689` guard theirs the same way, so the API-21 wall does not apply. |
| aarch64-android24 | **WILL NOT BUILD** | Same cause: `lzo` absent. Everything else is clean at this level — `src/` uses only `open`/`read`/`write`/`mmap`/`ioctl`-class POSIX that Bionic has had since API 1. |
| aarch64-android35 | **WILL NOT BUILD** | Same cause: `lzo` absent. No level-gated symbol is used, so nothing about 35 differs from 24 here. |
| x86_64-android35 | **WILL NOT BUILD** | Same cause: `lzo` absent. lzop has no arch-conditional code — `src/conf.h` and the sources contain no `#ifdef __x86_64__`/`__aarch64__` — so the arch is not a factor. |
| x86_64-mingw | **WILL NOT BUILD** | Same cause: `lzo` absent. Additionally UNCERTAIN on its own terms: `configure.ac:46-48` calls `AC_CANONICAL_BUILD/HOST/TARGET`, which is correct, but the tree has DOS/OS2/Windows console back-ends (`src/s_vcsa.c`, `src/s_djgpp2.c`, `src/c_screen.c`) and `B/` batch files, and I did not verify that `src/lzop.c`'s console selection has a working mingw path. That is a separate question from the missing dependency. |
| clang-native | **WILL NOT BUILD** | Same cause: `lzo` absent. On its own terms it would be the easiest target: glibc supplies every symbol `src/` uses. |

Every row is WILL NOT BUILD for the same single reason: **the LZO
dependency is absent from this prefix**, which fails at require-resolution
time, long before any compiler runs. The second column would read WILL BUILD
on the five rows above if `packages/lzo` existed — the citations say so
target by target.

## API level notes

Nothing in lzop is gated above API 21. The full check, over
`src/*.c` and `src/*.h`:

- `O_BINARY`: `src/lzop.c:359` `#if defined(O_BINARY)`,
  `src/miniacc.h:7659` and `:7689` `ACC_COMPILE_TIME_ASSERT` inside the same
  kind of guard. Bionic never defines `O_BINARY`, so these compile out; they
  are not the API-21 `O_BINARY` wall, because the code tests for the macro
  rather than calling it unconditionally.
- `nl_langinfo` (API 26), `mktime_z` (API 35), `posix_spawn` (API 28),
  `process_vm_readv`, `POSIX_MADV_*`, `mblen`, `getpass` (API 24/21 walls):
  **zero hits** in `src/`. Not used anywhere in the package.

So the API level is not a variable for lzop; the missing dependency is.

## Risks / what a reviewer should check

- **The `require("lzo")` is the whole story.** The recipe cannot build until
  `packages/lzo` exists. That is deliberate and documented above.
- **lzop builds no library at all.** `Makefile.am:42` is
  `bin_PROGRAMS = src/lzop`; there is no `lib_LTLIBRARIES`, no
  `_la_` variable and no `include_HEADERS` anywhere in the tree (grep for
  `lib_LTLIBRARIES|pkglib|_la_` in `Makefile.am` returns nothing). So
  `$OUT` gets one executable and no headers, no `.pc`. Consumers do not link
  lzop; they just run `bin/lzop`. Worth stating so a reviewer does not go
  looking for `lib/lzop.a`.
- **No `--disable-*` for the LZO dependency**, so there is no recipe-side
  escape hatch. Confirmed: `configure.ac:61-62` offers only `--disable-asm`
  and `--disable-ansi`.
- **The `make install` step also installs a man page.** `Makefile.am:53`
  `dist_man1_MANS += doc/lzop.1`, and `doc/lzop.1` ships pre-built in the
  tarball. The `pod2man` rules at `Makefile.am:80-96` are inside
  `if MAINTAINER_MODE` (`:77`) and `configure.ac:49` calls
  `AM_MAINTAINER_MODE`, so they do not run in a normal build. No perl needed.
- **Autotools timestamp guard** is `touch aclocal.m4 configure config.hin`
  plus the `Makefile.in` sweep, which covers the single top-level
  `Makefile.in`.

## How to verify once built

- `bin/lzop` exists and is a target ELF
  (`readelf -h bin/lzop` → `Machine: AArch64` on Android targets)
- `bin/lzop.1` installed
- No library and no `.pc` file — that is correct, not a missing artifact
- `mksquashfs`-style cross-checks do not apply; there is nothing to compress
  without running the binary, which this repo does not do
