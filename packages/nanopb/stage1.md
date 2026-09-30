# nanopb 0.4.9.2 — stage 1 build forecast

- **Package:** nanopb
- **Version:** 0.4.9.2 (release `nanopb-0.4.9.2`, published 2026-08-25; the
  newest release)
- **Upstream URL:** `https://github.com/nanopb/nanopb/releases/download/nanopb-0.4.9.2/nanopb-0.4.9.2.tar.gz`
  (HTTP 200, 1 197 620 bytes, top directory `nanopb/`)
- **Build system actually used: CMake** (`cmake_minimum_required(VERSION 3.14.0)`).
  Also ships a `build.py` (SCons-driven tests), `conanfile.py`,
  `BUILD.bazel`/`MODULE.bazel` and Swift Package Manager metadata; we use
  CMake. No autotools, no `configure`. **The autotools timestamp guard does not
  apply.**

Note this is the *release asset* tarball, not the git tag archive. The tag
archive would have the same content plus an empty `thirdparty/`; the release
asset is the curated one and is what the recipe uses.

## What the package installs

With `nanopb_BUILD_GENERATOR=OFF`, `BUILD_STATIC_LIBS=ON`,
`BUILD_SHARED_LIBS=OFF` and upstream's default `nanopb_BUILD_RUNTIME=ON`:

| Artifact | Comes from |
| --- | --- |
| `lib/libprotobuf-nanopb.a` | `add_library(protobuf-nanopb-static STATIC ...)` at `CMakeLists.txt:156-163`, installed at `:166-167` |
| `include/nanopb/pb.h`, `pb_common.h`, `pb_encode.h`, `pb_decode.h` | `install(FILES ...)` at `CMakeLists.txt:185-186` |
| `lib/cmake/nanopb/nanopb-config.cmake` | `install(FILES extra/nanopb-config.cmake ...)`, `CMakeLists.txt:181-183` |
| `lib/cmake/nanopb/nanopb-config-version.cmake` | same rule, generated from `extra/nanopb-config-version.cmake.in` |
| `lib/cmake/nanopb/nanopb-targets.cmake` | `install(EXPORT nanopb-targets ...)`, `CMakeLists.txt:177-179` |

**There is no pkg-config file.** nanopb ships none — `tar tzf` shows no
`*.pc.in` anywhere in the tree. Consumers use the CMake config
(`find_package(nanopb)`, `extra/FindNanopb.cmake` also exists) or
`-I$PREFIX/include/nanopb -lprotobuf-nanopb` by hand.

**No tools** (`bin/`): the generator wrapper scripts and `protoc-gen-nanopb`
are installed only inside the `nanopb_BUILD_GENERATOR` block
(`CMakeLists.txt:99-130`), which we switch off — see below.

Two path facts worth knowing before writing a consumer:
- the headers land in **`include/nanopb/`**, not `include/` directly
  (`CMakeLists.txt:186`), so `#include <pb.h>` needs
  `-I$PREFIX/include/nanopb`;
- the exported target's INTERFACE include directory is
  `$INSTALL_INTERFACE:include/nanopb` (`CMakeLists.txt:168-171`), so
  `find_package(nanopb)` users get that automatically.

## Dependencies

None, and — unusually for nanopb — **not even protoc, as long as the generator
is off**, which is worth spelling out because the CMake file looks like it
requires protoc unconditionally:

- `CMakeLists.txt:19-23` does
  `find_program(nanopb_PROTOC_PATH protoc PATHS generator-bin generator
  NO_DEFAULT_PATH)` and then `message(FATAL_ERROR "protoc compiler not found")`
  if it did not resolve. That runs *before* the `if(nanopb_BUILD_GENERATOR)`
  block at `:46`, so it looks fatal.
- It is not fatal for us, because the first `find_program` searches the
  `PATHS generator-bin generator` **relative to the source tree**, and the
  release tarball ships `nanopb/generator/protoc` (mode 0755, a Python 3 shim
  that wraps `grpcio-tools` or a `protoc` on `PATH`). I verified cmake's
  relative-`PATHS` semantics directly with a scratch project on the installed
  cmake 4.4.3: `find_program(X protoc PATHS generator-bin generator
  NO_DEFAULT_PATH)` with `generator/protoc` present resolves to
  `<source>/generator/protoc`, exit 0. So the `EXISTS` test at `:21` passes and
  the `FATAL_ERROR` never fires — without any `protoc` package installed.
- Then `nanopb_BUILD_GENERATOR=OFF` means the shim is never *executed*: the
  `nanopb_generator` custom target (`CMakeLists.txt:57-80`), the
  `find_package(Python REQUIRED COMPONENTS Interpreter)` (`:49`) and the
  `bin/` installs are all inside the disabled block.

`grpcio-tools` is **not** available on this build host
(`python3 -c 'import grpc_tools'` → `ModuleNotFoundError`), which is exactly
why the generator must stay off: leaving it on would fail at build time when
the custom target ran `generator/protoc`.

`generic.lua` therefore requires only `nanopb@source`.

## Per-system verdict

Standing caveats: **armv7a, i686 and x86_64 Android targets behave exactly like
aarch64** — nanopb is portable C89/C99 with no arch conditionals
(`grep` for `__aarch64__`/`__arm__`/`__x86_64__` across `pb_*.c`/`pb*.h`
returns nothing) and no SIMD. **The API level (21 vs 24 vs 35) is the real
variable**, and for nanopb the API level reaches the build in exactly one
place: `pb.h:89` does `#include <stdbool.h>` and `pb.h:196` uses
`_Static_assert`. Both are C99/C11 language facilities, not libc functions, so
they are available on every NDK from API 21 up. nanopb's `.c` files call only
`memcpy`, `memset`, `strlen`, `strcmp` and `snprintf` (`pb_encode.c`,
`pb_decode.c`, `pb_common.c`) — no POSIX, no locale, no threads, no sockets.
**Nothing in this package needs an API introduced after 21**, so the 21, 24 and
35 rows take an identical path.

| System | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | `cmake_minimum_required(VERSION 3.14.0)` (`CMakeLists.txt:1`) is satisfied by the cmake in the nest. `project(nanopb ... LANGUAGES C)` — **C only**, no `enable_language(CXX)`, so this package needs no C++ compiler anywhere. There are no `check_*`, `try_run` or `find_package` calls outside the disabled generator block, so nothing links or runs a test program. `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` is not even reached. The one real risk is `_Static_assert` at `pb.h:196`: the selection chain at `pb.h:178-194` picks the `_Static_assert` form when neither `__ICCARM__`, `_MSC_VER`, `PB_C99_STATIC_ASSERT` nor `__cplusplus` is defined, and NDK clang 19 in its default C mode (C23, per AGENTS.md "NDK clang defaults to C23") supports `_Static_assert` — it was deprecated-but-present in C23 and clang has not removed it. `PB_STATIC_ASSERT(1, STATIC_ASSERT_IS_NOT_WORKING)` at `pb.h:210` is the self-test that would fail loudly if it were not. I could not compile it, so this is the one line I would most want a real build to confirm. |
| `aarch64-android24` | **WILL BUILD** | Identical. No API-24-gated symbol is used, and the `_Static_assert` reasoning is a language-version question, not an API-level one. |
| `aarch64-android35` | **WILL BUILD** | Identical. |
| `x86_64-android35` | **WILL BUILD** | Identical reasoning. `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` is at `packages/x86_64-android35/generic.lua:118`, same as aarch64 — and irrelevant here regardless, since nanopb runs no configure-time probes. |
| `x86_64-mingw` | **WILL BUILD**, two caveats | Caveat 1: the `if(WIN32)` branch at `CMakeLists.txt:106-121` reads `generator/protoc-gen-nanopb.bat` and rewrites `python` to `Python_EXECUTABLE`, then installs the two `.bat` files — **all inside `if(nanopb_BUILD_GENERATOR)`**, which we disable, so this branch is not reached and no `find_package(Python)` happens. Caveat 2: `MSVC AND nanopb_MSVC_STATIC_RUNTIME` at `:31` rewrites `/MD` to `/MT`; that block is gated on `MSVC`, not `WIN32`, and we are GCC here, so it is skipped. `pb.h:178-194` picks `_Static_assert` for GCC too (no `_MSC_VER`, no `__cplusplus`), and GCC 16.2.0 supports it in its default `gnu++17`→C `gnu17` mode — `x86_64-w64-mingw32-gcc -std=c99` compiles `_Static_assert` without complaint. `stdbool.h` and `stdint.h` are in mingw-w64's headers. `snprintf` is used by nanopb only in the optional error-message paths (`PB_NO_ERRMSG` is off), and mingw-w64 has it. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3. `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` (`packages/clang-native/generic.lua:57`) is unused here (14.0 > 3.5). `BUILD_SHARED_LIBS` and `BUILD_STATIC_LIBS` are upstream defaults `OFF`/`ON` (`CMakeLists.txt:10-11`); the recipe states both explicitly so nothing depends on a default that could be flipped by another `-D` in `$CMAKE_FLAGS`. |

## For a reviewer to scrutinise

1. **The recipe relies on `find_program` finding `generator/protoc` in the
   source tree to get past a `FATAL_ERROR`.** This is the least obvious thing
   in the whole package and the first thing to re-check on a version bump. If
   a future release drops `generator/protoc` from the tarball, or if the
   executable bit is lost in transit, `CMakeLists.txt:21` sees
   `NOT EXISTS NOTFOUND` and the configure step **fails hard** even though the
   generator is disabled — the `find_program` and its `FATAL_ERROR` sit
   *above* the option check. The fix at that point is a `protoc` package (or
   passing `-Dnanopb_PROTOC_PATH=<something existing>`), not a source change.
2. **`nanopb_BUILD_GENERATOR=OFF` also disables the `bin/` install**, so this
   package deliberately ships no `protoc-gen-nanopb` wrapper. That is correct
   for a *target* prefix — the generator is a host tool — but it means a
   developer who wants to regenerate `.pb.c` files from this prefix cannot.
   Worth stating as a deliberate choice rather than an omission.
3. **`BUILD_STATIC_LIBS=ON` and `BUILD_SHARED_LIBS=OFF` are spelled out even
   though they match the upstream defaults** (`CMakeLists.txt:10-11`). Same
   rationale as the zopfli `-DZOPFLI_BUILD_SHARED=OFF`: do not depend on a
   default that another flag could change.
4. **The headers land in `include/nanopb/`.** Any future consumer recipe that
   hand-rolls a `pkg-config`-less compile line must add
   `-I$PREFIX/include/nanopb`, not `-I$PREFIX/include`. I have not found such a
   consumer in `packages/` yet, but a protobuf-dependent package would hit it.
5. **`_Static_assert` under the NDK's default C23 is the highest-value thing to
   confirm with a real build.** It is a language feature, not an API level, so
   it should be fine; but it is the only place in this package where a
   toolchain-default choice meets upstream source, and it is a single-line
   compile that would settle it.