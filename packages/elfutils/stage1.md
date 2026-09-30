# elfutils build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 0.193
- Build system: autotools
- Installs: **only libelf** — `lib/libelf.a` (or `.so`); `include/libelf.h`, `include/gelf.h`, `include/nl.h`, `include/dwarf.h` etc.; `lib/pkgconfig/libelf.pc`; `lib/lzma`/`libz` are *used*, not installed
- Requires: `bzip2` (exists), `xz` (exists, 5.8.1), `zlib` (exists, 1.3.1), `elfutils@source`

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (configure)** | **Confirmed by build** (`stage3.md`, built for `aarch64-android24`). `configure.ac:651` is `AC_SEARCH_LIBS([argp_parse], [argp])` and `configure.ac:654` is `AC_MSG_FAILURE([failed to find argp_parse])`. The block `configure.ac:650-658` is top-level and unconditional — no `AS_IF`, no `AC_ARG_ENABLE` — so `./configure` exits 1 on the missing `argp_parse` symbol. `argp_parse` is a glibc extension and `argp.h` is absent from the entire NDK r28b sysroot, so this is not API-gated. `AC_OUTPUT` never runs: no `config.h`, no `Makefile`. |
| aarch64-android24 | **WILL NOT BUILD (configure)** | The system actually built. Same `argp_parse` failure at `configure.ac:651`/`:654`; log quoted in `stage3.md`: `checking for library containing argp_parse... no` / `configure: error: failed to find argp_parse`. |
| aarch64-android35 | **WILL NOT BUILD (configure)** | Same. Not fixable by a higher API level: `argp.h` is simply not shipped, unlike an `__INTRODUCED_IN`-gated symbol. |
| x86_64-android35 | **WILL NOT BUILD (configure)** | Same, arch-independent — the failure is a missing libc symbol, not a codegen issue. |
| x86_64-mingw | **WILL NOT BUILD (configure)** | Same unconditional `argp_parse` check at `configure.ac:651`/`:654`; the base mingw-w64 toolchain here has no `argp.h`, and elfutils is ELF-only regardless. |
| clang-native | **UNCERTAIN — never built** | Host glibc has `<argp.h>`, so `configure.ac:651` should resolve `argp_parse` to "none required" and the abort does not apply. But no build has been attempted: `./nest/clang-native/` holds neither a `.retrolunar-elfutils` stamp nor `lib/libelf.*`, so nothing here is a verified result. Flagged, not claimed. |

## No row above is rescued by the recipe's `-C libelf` scoping

The `make -j1 -C libelf` steps at `generic.lua:52-53` sit **downstream** of
`./configure`. On every Android and mingw target the build dies at
`configure.ac:654` and those lines never execute. The scoping is still worth
keeping, for a different reason — see "What the `-C libelf` scoping is for"
below — but it changes no verdict in the table.

## API level notes

**The blocker is not an API-level one, and the distinction matters.**
topackage.md files elfutils under the general blocked list with "configure
requires argp_parse, absent in Bionic". `argp_parse` is a *GNU C library*
extension: glibc provides it, Bionic has never shipped `argp.h` and never will.
So no new `aarch64-androidNN` directory unblocks elfutils.

This is the opposite of the cases this repo treats as solvable by raising the
API level. `nl_langinfo` is declared in Bionic as `__INTRODUCED_IN(26)` and
`posix_spawn` as `__INTRODUCED_IN(28)`, so retargeting to
`aarch64-android26` or `aarch64-android28` genuinely fixes a link error for
those symbols. `argp_parse` carries no such gate — there is no API level at
which it appears — so adding `aarch64-androidNN` targets is not a lever here
at all.

Only an upstream change would: making `configure.ac:650-658` conditional on
the components that actually need argp, or dropping `libdwfl`. Both are
upstream patches, which AGENTS.md forbids a recipe from carrying.

## What the `-C libelf` scoping is for — and what it is not

**Not** a rescue. The reasoning that produced it ("libelf builds standalone,
so `make -C libelf` may work on a target that merely lacks argp") is
individually true about libelf and wrong about the build:

- `libelf/Makefile.in:116` does define `CONFIG_HEADER = $(top_builddir)/config.h`,
  and `config/eu.am:34` does supply `-iquote . -I$(srcdir) -I$(top_srcdir)/lib
  -I..`.
- **But** `./configure` is what generates that `config.h`, and it aborts at
  `configure.ac:654` before `AC_OUTPUT` runs. There is no `config.h` to build
  against and no `libelf/Makefile` to descend into. Verified in `stage3.md`
  against the build log and by a standalone re-run of the same configure line.

What it *is* for, both true:

- It stops the recipe compiling `libdw`, `libdwfl`, `libstack`,
  `libbacktrace`, `backends/` and the whole `tests/` tree only to discard
  everything but `libelf`. That waste is real on `clang-native`, the one
  system where `./configure` completes.
- It is the shape the build would take if configure ever did succeed, which
  is why it is worth keeping rather than reverting.

Answering the cache variable does not get past it either — see
"What is not recoverable" below.

## What is not recoverable (all of it, on Bionic)

Every route below was checked against the shipped `configure`, not reasoned
about. None of them is available to a recipe under AGENTS.md.

**Answering the cache variable.** The macro at `configure.ac:651` is
`AC_SEARCH_LIBS`, not `AC_CHECK_LIB`, so the cache variable is
`ac_cv_search_argp_parse` (autoconf's `libs.m4:49` derives `ac_cv_search_$1`;
`ac_cv_lib_argp_parse_argp_parse` is the `AC_CHECK_LIB` spelling and is
ignored here). The shipped `configure:9615` reads exactly
`if test ${ac_cv_search_argp_parse+y}`, so the cache *is* honoured and a
preset value does skip the link probe. It buys nothing:

- Presetting `ac_cv_search_argp_parse=no` does **not** satisfy the probe — it
  takes the `no)` arm of the `case` at `configure.ac:653` and hits the same
  `AC_MSG_FAILURE`. It is the one value that changes nothing.
- Presetting it to `none required` or `-largp` gets past `:654`, and then
  `argp_LDADD` is substituted into `libdw_so_LDLIBS` (`libdw/Makefile.am:112`)
  and into `debuginfod_LDADD` / `debuginfod_find_LDADD`
  (`debuginfod/Makefile.am:73,76`). Since no `libargp` exists on Bionic, that
  is a configure-time failure traded for a link-time one. `libelf` itself
  would not notice — `libelf_so_LDLIBS` (`libelf/Makefile.in:642`) never
  mentions `argp_LDADD` — but reaching libelf is the part that is impossible,
  not the part that is easy.
- And it is not the only wall. Two more unconditional probes follow
  immediately: `fts_close` (`configure.ac:661`, failure at `:664`) and
  `_obstack_free` (`configure.ac:671`, failure at `:674`). A recipe would
  have to answer three cache variables to get past configure.ac:650-678.

Note the mechanism precisely, because it is easy to state backwards:
`AC_SEARCH_LIBS` *does* prepend to `LIBS` on success (`libs.m4:69`,
`configure:9676`) — that is exactly what distinguishes it from `AC_CHECK_LIB`.
elfutils undoes that itself one line later with `LIBS="$saved_LIBS"`
(`configure.ac:652`, shipped `configure:9680`), so `LIBS` is clean either way.
The lasting effect of a pre-set answer is `argp_LDADD` in the generated
`Makefile`s, not a poisoned `LIBS`.

**No configure switch.** All 47 `--enable/--disable/--with/--without` options
in `./configure --help` were enumerated; none removes a directory from the
unconditional `SUBDIRS` line at `Makefile.am:31-32`.

**New API levels.** Not a lever, as above.

**Upstream patch or a stub `libargp`.** Both forbidden by AGENTS.md
("recipes must not patch upstream sources"; vendored or locally applied
patches are out).

**Conclusion: elfutils 0.193 is not buildable on Bionic.** The only honest
forward motion is an upstream change to `configure.ac:650-658` (gate the argp
probe on the components that need it) or dropping `libdwfl`. `clang-native`
is the one system where this package could still produce something, and that
has never been attempted.

## Other notes on the recipe, still true

- The `libelf.pc` hand-copy at `generic.lua:55` is deliberate and necessary:
  `config/Makefile.am:37` has `pkgconfig_DATA = libelf.pc libdw.pc`, so the
  `.pc` is installed by `make -C config install`, not by
  `make -C libelf install`. (Confirmed in `stage2.md`.)
- `bzip2`/`xz`/`zlib` are needed by the whole tree, not just libelf —
  `libdwfl/`'s minidebuginfo support uses lzma and zlib — so even a
  libelf-only build pays for three dependencies in its configure.
- The `touch ... config.h.in` guard at `generic.lua:50` is correct: elfutils
  really does have a top-level `config.h.in`, matching `AC_CONFIG_HEADERS([config.h])`
  at `configure.ac:53`.

## How to verify once built

Not verifiable on any target in this repo today. On a host with `argp.h`:

- `lib/libelf.a` (or `libelf-0.193.so`)
- `include/libelf.h`, `include/gelf.h`
- `lib/pkgconfig/libelf.pc` and `pkg-config --modversion libelf` → `0.193`
- `readelf -h lib/libelf.a` → `Machine: AArch64` on Android targets
- `ls $OUT/lib` should show libelf and **nothing else** — if `libdw.so` or
  `libdwfl.so` appear, the narrow install regressed
