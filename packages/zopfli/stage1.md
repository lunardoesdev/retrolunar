# zopfli 1.0.3 — stage 1 build forecast

- **Package:** zopfli
- **Version:** 1.0.3 (release `zopfli-1.0.3`, published 2019-11-27; it is
  still the newest release and the newest tag on google/zopfli)
- **Upstream URL:** `https://github.com/google/zopfli/archive/refs/tags/zopfli-1.0.3.tar.gz`
  (HTTP 200, 195 227 bytes, top directory `zopfli-zopfli-1.0.3/` — note the
  doubled name, GitHub's tag-to-directory mangling; `--strip-components=1`
  makes it irrelevant)
- **Build system actually used: CMake** (`cmake_minimum_required(VERSION 2.8.11)`)

## Plainly: the newest zopfli release is a git tag archive, and it has no
## generated build system beyond what is checked in

- **There is no `v1.0.8`.** `https://github.com/google/zopfli/archive/refs/tags/v1.0.8.tar.gz`
  returns **HTTP 404**, and the tag list (`/repos/google/zopfli/tags`) contains
  only `zopfli-1.0.3`, `zopfli-1.0.2`, `zopfli-1.0.1`, `zopfli-1.0.0`. The
  `1.0.4`–`1.0.8` versions people cite are Chromium-internal zopfli copies, not
  google/zopfli releases. **1.0.3 is the correct newest stable release.**
- **The release tarballs upstream offers are gone.** The GitHub releases API
  returns three releases with an **empty `assets` array** each, so there is no
  upstream `.tar.gz` asset to use; the git tag archive is the only available
  form. This is exactly the "tag archive only" case.
- **What that archive does ship is a complete, hand-written CMake build**, not
  a generated one: `CMakeLists.txt` is checked in at the top level and
  references only files that are in the archive. I verified the two source
  files CMake names that are easy to get wrong — `src/zopfli/zlib_container.c`
  and `src/zopfli/zopfli_lib.c` are both present (`CMakeLists.txt:85-86`).
- There is also a hand-written `Makefile` at the top level; we do not use it.
  There is no `configure`, no `configure.ac`, no autotools anywhere. **The
  autotools timestamp guard does not apply.**

## What the package installs

With `-DZOPFLI_BUILD_SHARED=OFF` (which is also upstream's default when
`BUILD_SHARED_LIBS` is unset, `CMakeLists.txt:23-28`) and
`ZOPFLI_BUILD_INSTALL` at its standalone default of `ON`
(`CMakeLists.txt:34-38`):

| Artifact | Comes from |
| --- | --- |
| `lib/libzopfli.a` | `add_library(libzopfli STATIC ...)`, `CMakeLists.txt:74-87` |
| `lib/libzopflipng.a` | `add_library(libzopflipng STATIC ...)`, `CMakeLists.txt:105-110` |
| `include/zopfli.h` | `install(FILES ...)`, `CMakeLists.txt:173-175` |
| `include/zopflipng_lib.h` | same rule |
| `bin/zopfli` | `add_executable(zopfli src/zopfli/zopfli_bin.c)`, `CMakeLists.txt:136` |
| `bin/zopflipng` | `add_executable(zopflipng src/zopflipng/zopflipng_bin.cc)`, `CMakeLists.txt:145` |
| `lib/cmake/Zopfli/ZopfliConfig.cmake` | `install(EXPORT ...)`, `CMakeLists.txt:188-192` |
| `lib/cmake/Zopfli/ZopfliConfigVersion.cmake` | `CMakeLists.txt:193-195` |

**There is no pkg-config file.** zopfli ships none — no `*.pc.in` in the
tarball at all. Consumers use the CMake package config or `-lzopfli` directly.
Both executables are target binaries that nothing in a prefix can run, but they
cost almost nothing to build and the install rule covers all four targets in
one `install(TARGETS ...)` (`CMakeLists.txt:167`), so naming only the library
targets would leave the install step without files to copy.

Note `libzopflipng` is **C++** (`src/zopflipng/zopflipng_lib.cc` plus lodepng's
`lodepng.cpp`, `lodepng_util.cpp`), so every system needs a working `$CXX`.

## Dependencies

None. zopfli is a DEFLATE compressor written from scratch: it implements its
own hash chains, its own Huffman coding and its own LZ77 match finder
(`src/zopfli/{hash,tree,squeeze,lz77,blocksplitter,katajainen}.c`). It links
`m` on UNIX (`CMakeLists.txt:98-100`) for `sqrt`/`log` in `squeeze.c`, and
nothing else. `generic.lua` requires only `zopfli@source`.

## Per-system verdict

Standing caveats: **armv7a, i686 and x86_64 Android targets behave exactly like
aarch64** — zopfli has no architecture-specific code and no intrinsics
(`grep` for `__aarch64__`/`__arm__`/`__x86_64__`/`_mm_`/`NEON` across `src/`
returns nothing); it is portable C89-era code. **The API level (21 vs 24 vs 35)
is the real variable**, and here it is genuinely inert: I read every libc
symbol zopfli uses and it is `stdlib.h`/`string.h`/`stdio.h` only — `malloc`,
`free`, `realloc`, `memcpy`, `memmove`, `strlen`, `strcmp`, `fopen`, `fread`,
`fwrite`, `fputc`, `putc`, `fprintf`. There is no locale call, no thread, no
socket, no `mkstemp`, no `unistd.h` at all. Nothing in the package needs an API
introduced after 21, so there is no API-level difference between the 21, 24 and
35 rows.

| System | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | Pure C/C++ with no configure-time probes at all — zopfli's `CMakeLists.txt` has **no `check_*`, no `try_run`, no `find_package`**, so `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` is not even exercised for a probe. `target_link_libraries(libzopfli m)` (`CMakeLists.txt:99`) resolves: the Android sysroot has `libm`, and `LDFLAGS` already carries `-lm` (`packages/aarch64-android21/generic.lua:78`). One thing to note: `ZOPFLI_DEFAULT_RELEASE` is `ON` (`CMakeLists.txt:46`), so an empty `CMAKE_BUILD_TYPE` becomes `Release` and `-O3` lands in `CMAKE_C_FLAGS_RELEASE` (`CMakeLists.txt:48-53`); that is a correct optimisation level for a compressor and does not interfere with the `-O2 -fPIC` in `$CFLAGS`. |
| `aarch64-android24` | **WILL BUILD** | Identical. No API-24-gated symbol is used. |
| `aarch64-android35` | **WILL BUILD** | Identical. |
| `x86_64-android35` | **WILL BUILD** | Identical reasoning; same absence of probes, same `-lm`. |
| `x86_64-mingw` | **WILL BUILD**, one real caveat | The `-lm` at `CMakeLists.txt:99` is gated on `if(UNIX AND NOT (BEOS OR HAIKU))`. With `CMAKE_SYSTEM_NAME Windows`, `UNIX` is **not** set, so no `-lm` is added — correct, because mingw's libm is not something a Windows build of zopfli should be forced to link. The caveat is the C++ half: `libzopflipng` and `zopflipng` are built by `x86_64-w64-mingw32-g++` (GCC 16.2.0), and zopfli's CMake **sets no C++ standard**, so the compiler default (gnu++17 for GCC 16) applies. lodepng as vendored in zopfli 1.0.3 is from 2015 and is conservative C++; I grepped `src/zopflipng/` for `auto_ptr`, `std::bind1st`, `register`, `throw()` and `std::uncaught_exception` and found **none**, so the usual C++17 removals do not bite it. `mingw32-makefile`/`unistd.h` is not involved: lodepng has its own Windows paths and zopfli's own sources include only `<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<math.h>` and `"zopfli.h"`. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3. `cmake_minimum_required(VERSION 2.8.11)` is **below cmake 4's floor of 3.5**, so without a floor cmake refuses outright — and every system here supplies one: `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` at `packages/clang-native/generic.lua:57`, `packages/x86_64-mingw/generic.lua:69`, `packages/aarch64-android21/generic.lua:127`. I verified the mechanism works under the installed cmake 4.4.3 with a scratch project declaring `CMAKE_MINIMUM_REQUIRED(VERSION 2.8)`: it configures with a deprecation warning, not an error. Same applies to the Android and mingw rows. |

## For a reviewer to scrutinise

1. **This package is 6 years old (2019-11-27) and there is nothing newer to
   move to.** That is a property of upstream, not of this recipe, but it is
   the thing most worth knowing before anyone opens a ticket about the version.
   The tag is `zopfli-1.0.3`, **not** `v1.0.3`; a tag rename upstream would
   break the URL in `source.lua` immediately.
2. **The tag archive's top directory is `zopfli-zopfli-1.0.3/`** (the tag name
   is itself prefixed). `--strip-components=1` handles it, but it is the kind
   of detail that breaks if anyone tightens the tar command.
3. **`-DZOPFLI_BUILD_SHARED=OFF` is passed explicitly even though it is already
   the default** (`CMakeLists.txt:23-28`: `zopfli_shared_default` is `OFF` when
   `BUILD_SHARED_LIBS` is undefined). It is spelled out so the recipe does not
   depend on a default that reads from another variable.
4. **We install two target executables a device can never run** (`bin/zopfli`,
   `bin/zopflipng`). That is a deliberate trade: `install(TARGETS libzopfli
   libzopflipng zopfli zopflipng ...)` is one rule (`CMakeLists.txt:167`), so
   skipping the binaries would mean installing only two of the four and
   leaving the recipe less obvious. If a reviewer wants them gone, that is an
   upstream patch, not a recipe flag — zopfli has no option for it.
5. **The C++ half is the real risk surface on mingw**, purely because no
   `-DCMAKE_CXX_STANDARD` is pinned and a modern GCC default is applied to
   2015-vintage lodepng. My grep found nothing alarming, but I could not
   compile it, so this row is the least-proven of the six. What would settle
   it: one `g++ -std=gnu++17 -c src/zopflipng/lodepng/lodepng.cpp` on the
   mingw toolchain.