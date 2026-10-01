# doxygen build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.18.0
- Build system: **CMake only.** As of 1.18 the release ships **no `configure`
  and no `configure.ac`** — verified by listing the tree, not assumed. So
  there is no config-header template to name and no autotools timestamp guard
  to write. `cmake_minimum_required(VERSION 3.14)` at `CMakeLists.txt:14`.
- Installs: `bin/doxygen` (`src/CMakeLists.txt:417`).
- Requires: `doxygen@source` only. flex, bison and python3 are **host** tools
  this project does not own, not package dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `src/portable_c.c:11` does `#include <iconv.h>` unconditionally and calls `iconv_open` at `:21` with no `__ANDROID__` guard. Bionic marks that symbol `__INTRODUCED_IN(28)`, so clang raises a hard availability error below API 28. Full detail below. |
| aarch64-android24 | **WILL NOT BUILD** | Identical to the above — the gate is API 28, and 24 is below it. |
| aarch64-android35 | WILL BUILD | API 35 ≥ 28, so `iconv_open`, `iconv` and `iconv_close` are all available and `<iconv.h>` is a real Bionic header. Everything else in the build is host-side. |
| x86_64-android35 | WILL BUILD | As above; same API 35 story, and `execinfo.h` is present. |
| x86_64-mingw | **WILL NOT BUILD** | `portable_c.c` is compiled **unconditionally** into the `doxycfg` library (`src/CMakeLists.txt:196-203`), and the mingw-w64 sysroot on this machine has **no `<iconv.h>` at all**. Full detail below. |
| clang-native | WILL BUILD | glibc ships `<iconv.h>` and `iconv_open` is in libc, so `portable_c.c` compiles and links with no extra library. This is the system where a working copy also lands in `$NATIVE_PREFIX`. |

## The two blockers, precisely

**1. Android API < 28 — `iconv` is `__INTRODUCED_IN(28)`.**

`src/portable_c.c`, compiled with no surrounding platform guard:

```c
11: #include <iconv.h>
...
19: void * portable_iconv_open(const char* tocode, const char* fromcode)
20: {
21:   return iconv_open(tocode,fromcode);
22: }
```

and the declaration is unconditional too — `src/portable.h:49-53` declares
`portable_iconv_open` / `portable_iconv` / `portable_iconv_close` inside a
bare `extern "C" { }` with no platform test.

In the NDK used by this tree (28.2.13676358), the sysroot header is
`sysroot/usr/include/iconv.h` and **all three** entry points are gated:

- `iconv_t _Nonnull iconv_open(...)` — `__INTRODUCED_IN(28)`
- `size_t iconv(...)` — `__INTRODUCED_IN(28)`
- `int iconv_close(...)` — `__INTRODUCED_IN(28)`

The header itself *is* findable at every API level, because our systems put
`-isystem $SYSROOT/usr/include` on `CPPFLAGS` — that is exactly why the
`#include` succeeds and the failure surfaces later, at the call. Clang then
rejects the call as unavailable for `__ANDROID_MIN_SDK_VERSION__` of 21 or 24.
This is a hard error, not a warning, so it fails the compile.

`src/portable_c.c` is listed in `add_library(doxycfg STATIC ...)` at
`src/CMakeLists.txt:196-203` with nothing platform-specific around it (the only
conditionals in that region are the `enable_coverage` blocks at `:187-193`),
so there is no Android build that avoids compiling this file.

**2. `x86_64-mingw` — no `<iconv.h>` exists.**

The same unguarded `#include <iconv.h>` at `src/portable_c.c:11` runs on MinGW
too. mingw-w64 does not ship `<iconv.h>` in its sysroot: searching the whole
machine for `iconv.h` under any `mingw` path returns **nothing**. The
`#if defined(_WIN32)` blocks in `src/portable.cpp` are a separate layer (UTF-8
conversion helpers) and do not remove `portable_c.c` from the build. So the
compile fails with a missing header.

Neither is worked around here. Both would require editing upstream sources,
which this project does not do.

**API level notes.** Beyond the iconv gate: `mktime_z` (API 35) is **not
used** — grepping `src/` for it returns nothing. `nl_langinfo` (API 26) is
**not used** either; `src/portable.cpp` and `src/util.cpp` contain no
`nl_langinfo` or `setlocale` call. `posix_spawn`, `process_vm_readv`,
`POSIX_MADV_*`, `mblen`, `getpass` and `O_BINARY` are all absent. So iconv is
the *only* API gate in this package, and it is the one that decides two of the
six systems. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**perl is NOT needed.** The brief assumed doxygen needs perl for
preprocessing. For 1.18.0 that is not true, and the evidence is a grep across
every build file: `perl` appears in `src/CMakeLists.txt:297` only as the
filename `perlmodgen.cpp` (a C++ translation unit, not a perl script), and in
`doc/CMakeLists.txt:128` only inside `perlmod.dox`, which is part of the user
manual that `build_doc` (OFF by default) would render. Nothing in the build
invokes perl. There is therefore no `require("perl")`.

**Risks / what a reviewer should check.**

1. **flex and bison are host tools, and that is correct.** `CMakeLists.txt:249`
   `find_package(FLEX REQUIRED)` (needs ≥ 2.5.37) and `:259`
   `find_package(BISON REQUIRED)` (needs ≥ 2.7) generate the lexer and parser
   that are then *compiled for the target*. The host running the build has
   flex 2.6.4 and bison 3.8.2, both satisfying the minimums. This is why
   neither `packages/flex` nor `packages/bison` is required: those build
   *target* flex/bison, which a cross build must not execute, and the target
   toolchain is deliberately kept off `PATH` so cmake cannot find them.
2. **`find_package(Python REQUIRED)` at `CMakeLists.txt:248` is a host
   interpreter** driving `configgen.py`, `res2cc_cmd.py`, `scan_states.py` and
   `post_lex.py` in `src/CMakeLists.txt`. All host-side; none executes a target
   binary.
3. **No network access at build time.** Grepping the build for
   `FetchContent`, `ExternalProject`, `file(DOWNLOAD` and `GIT_REPOSITORY`
   returns nothing; the only URL in the cmake tree is
   `cmake/packaging.cmake:46`, a CPack metadata string. The third-party
   libraries are vendored under `deps/` — `deps/fmt`, `deps/spdlog`,
   `deps/sqlite3` — and `use_sys_spdlog` / `use_sys_fmt` / `use_sys_sqlite3`
   all default OFF (`CMakeLists.txt:29-31`).
   *Trap worth recording:* there is **no `third_party/` directory** in this
   tree. An early `ls third_party/` returned nothing, which reads like an
   empty or missing vendored dir; the real location is `deps/`. Anyone
   re-checking this should not conclude the tarball is incomplete — the
   extraction is healthy (1263 files, 38 MB).
4. **`-Dbuild_wizard=OFF` and `-Dbuild_doc=OFF` are stated explicitly.** Both
   are already OFF by default (`CMakeLists.txt:19` and `:23`). `build_wizard`
   is the Qt6 frontend, and Qt does not exist in this prefix, so stating it
   documents that its absence is intended rather than lucky.
5. **C++ dialect is chosen by upstream, not by us**
   (`CMakeLists.txt:100-110`): C++20 on Clang ≥ 19, otherwise C++17. The NDK
   clang in this tree is recent enough for the C++20 arm; mingw's g++ takes
   the C++17 arm. No flag is needed from the recipe.
6. **`cmake/options.cmake` is absent** — this is not an autotools package at
   all, so the tree's `touch aclocal.m4 configure <template>` guard has no
   counterpart here. A reviewer expecting that guard should find none.
7. `topackage.md:353` lists doxygen unchecked; nothing else in the tree
   `require()`s it. Standalone.

**How to verify once built.**

- `bin/doxygen` exists and `[ -x bin/doxygen ]` is true.
- `bin/doxygen --version` must **not** be run on a cross system. Read the
  version from the binary (`strings`) instead and confirm 1.18.0.
- `$OBJDUMP -f bin/doxygen` prints the expected machine.
- On a cross build the log must show flex and bison running (they are host
  tools) and must **not** show any attempt to execute a freshly built doxygen
  binary.
- On `aarch64-android21` / `aarch64-android24` this package is expected NOT to
  build. The signature to look for is clang's availability diagnostic naming
  `iconv_open`, not a generic "not found".