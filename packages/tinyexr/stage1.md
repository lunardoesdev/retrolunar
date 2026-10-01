# tinyexr build forecast

- Recipe: `generic.lua` only, source `source.lua`
- Version pinned: 3.2.0 (`v3.2.0`, the current `releases/latest`)
- Build system: **cmake**. The tree also ships a plain `Makefile`, several
  mingw makefiles and a premake script; cmake is used here.
- Installs, all copied by the recipe because upstream has no install rules:
  `lib/libtinyexr.a` **and** `lib/libminiz.a`; `include/tinyexr.h`,
  `include/exr_reader.hh`, `include/streamreader.hh`, `include/miniz.h`.
  **No pkg-config file.** No sample program (`TINYEXR_BUILD_SAMPLE=OFF`).
- Requires: `tinyexr@source` only. **No dependency** — miniz is bundled.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | tinyexr is a self-contained C++ header/implementation pair: `tinyexr.cc` plus a vendored miniz (built in-tree at `CMakeLists.txt:32-34` from `deps/miniz`). Its own surface is `<cstdio>`, `<cstring>`, `<cstdlib>`, `<cmath>`, `<cstdint>` and tinyexr.h — no POSIX calls and no platform layer at all. `TINYEXR_USE_MINIZ=ON` keeps the bundled decompressor so no external zlib is needed. The one link line to check is `target_link_libraries(${BUILD_TARGET} ${TINYEXR_EXT_LIBRARIES} ${CMAKE_DL_LIBS})` at `CMakeLists.txt:42`: on Android `${CMAKE_DL_LIBS}` resolves to `dl`, and the NDK ships a `libdl.a` stub at every API level, so it links. |
| aarch64-android24 | WILL BUILD | As above; nothing is API-level gated. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Same sources; the library is byte-oriented with no arch assumption. |
| x86_64-mingw | UNCERTAIN | tinyexr ships `Makefile.gcc-mingw` and `Makefile.gcc-mingw-msys`, so it is known to build there, but that is the **make** path; I did not check whether its cmake path (which this recipe uses) handles `${CMAKE_DL_LIBS}` and the bundled miniz under a PE toolchain. Flagged, not claimed. |
| clang-native | WILL BUILD | Native glibc; the obvious consumer and the system the Linux candidates list implies. |

## API level notes

**21 is the floor and tinyexr does not approach it.** There is no
`nl_langinfo`, no `scandir`/`versionsort`, no `getsubopt`, no `mktime_z`, no
`fread_unlocked`, no `argp_parse`, no `posix_spawn`, no `process_vm_readv`,
no `O_BINARY`. tinyexr is the most portable thing in this assignment: a
header, an implementation file and a vendored decompressor.

## Risks / what a reviewer should check

- **tinyexr's `CMakeLists.txt` has NO `install()` rules at all.** Verified
  three ways, including running `cmake --install`, which exits **0 without
  even creating the prefix**. That no-op is the whole reason this recipe
  copies files by hand.
- **The copy list is the load-bearing part, and it is longer than it
  looks.** An earlier version of this recipe installed `libtinyexr.a` and
  `tinyexr.h` and called tinyexr.h "the single public header". It is not.
  Three further files are required or the prefix is unusable:
  - `tinyexr.h:749` is `#include "exr_reader.hh"`, and
    `exr_reader.hh:12` is `#include "streamreader.hh"`. Without both, a
    consumer's `#include <tinyexr.h>` is a fatal error.
  - `libtinyexr.a` carries **three undefined symbols** —
    `mz_compress`, `mz_compressBound`, `mz_uncompress` — supplied by the
    separately built `libminiz.a` (`CMakeLists.txt:32`,
    `add_library(miniz STATIC deps/miniz/miniz.c)`). Installing the archive
    without it gives a link failure on any real consumer.
  - `tinyexr.h:770` is `#include <miniz.h>`, because `TINYEXR_USE_MINIZ`
    defaults to 1 (`tinyexr.h:108-109`). `deps/miniz/miniz.h` is a bundled
    third-party header and the public header needs it.
  The recipe chose bundled miniz *specifically* to avoid an external
  dependency, and then originally failed to ship it — the same shape as
  installing a library without the library it links against.
- **The obvious artifact checks do not catch any of that.** `[ -f
  lib/libtinyexr.a ]` and `[ -f include/tinyexr.h ]` both PASS against the
  broken state. That is why the verification below is written consumer-style.

## How to verify once built

Scoped to tinyexr's own artefacts so a second package in the prefix cannot
satisfy them.

```sh
# 1. Present. On its own this would NOT have caught the defect.
[ -f lib/libtinyexr.a ]
[ -f include/tinyexr.h ]

# 2. The headers the public header includes. Without these it cannot be
#    parsed at all.
[ -f include/exr_reader.hh ]
[ -f include/streamreader.hh ]
[ -f include/miniz.h ]

# 3. The second archive libtinyexr.a depends on.
[ -f lib/libminiz.a ]

# 4. libtinyexr.a still carries the unresolved miniz symbols, and that is
#    CORRECT: libminiz.a in the same prefix satisfies them. Expect 3, not 0
#    - expecting 0 would turn a good build into a phantom defect.
llvm-nm --undefined-only lib/libtinyexr.a | grep -c 'mz_\|tinfl\|tdefl'   # 3

# 5. No program, and still no .pc.
[ ! -d bin ]
find . -name 'tinyexr.pc' | grep -c .    # 0
```

**The real end-to-end proof** is a throwaway consumer compiled and linked
against `$OUT` alone, which is what caught all three defects:

```sh
mkdir -p /var/tmp/txcheck && cd /var/tmp/txcheck
printf '#include <tinyexr.h>\nint main(){EXRImage i;InitEXRImage(&i);return 0;}\n' > c.c
cc -std=c++11 -I "$PREFIX/include" c.c \
   "$PREFIX/lib/libtinyexr.a" "$PREFIX/lib/libminiz.a" -o /dev/null
```
