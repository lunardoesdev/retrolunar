# expat build forecast

- Recipe: `generic.lua`, source `source.lua` (release asset, ships a generated `configure` *and* a working `CMakeLists.txt`)
- Version pinned: 2.7.1
- Build system: cmake (the recipe uses it, not autotools)
- Installs: `lib/libexpat.a` (static); `include/expat.h`; `lib/pkgconfig/expat.pc`; `lib/cmake/expat/expat-config.cmake`; no docs, and `bin/xmlwf` only if `EXPAT_BUILD_TOOLS` is left at its default — which the recipe now turns off
- Requires: `expat@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | libexpat is the most portable C library in the shard: `lib/xmlparse.c` and `lib/xmltok.c` are C89 with only `<stdlib.h>`, `<string.h>`, `<stdio.h>`, `<stddef.h>`, `<stdint.h>`, `<string.h>`, `<limits.h>`, `<math.h>` and `<errno.h>`. It has an explicit `HAVE_MEMMOVE`/`HAVE_ISASCII`/`HAVE_STDINT_H` portability layer precisely so it can run everywhere. `EXPAT_BUILD_TESTS=OFF`, `EXPAT_BUILD_EXAMPLES=OFF`, `EXPAT_BUILD_DOCS=OFF` (`generic.lua:9`) remove every host program. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; expat's integer parsing is explicit. |
| x86_64-mingw | WILL BUILD | expat has a first-class Windows path (`expat_config.h` templates for MSVC and mingw), and `EXPAT_SHARED_LIBS=OFF` avoids the `dllimport`/`dllexport` question entirely. |
| clang-native | WILL BUILD | Native; topackage.md:21 records Expat 2.7.1 as `[x]`. |

## API level notes

**21 is the floor and expat has no floor above it — this is the safest
package in the shard.** expat is a self-contained parser with no libc
dependency worth naming, and its own README makes a point of supporting
anything from 1980s compilers to modern ones. It is also the XML parser
that `packages/xml-parser` and `packages/intltool` chain off, so its
reliability is load-bearing for the rest of the build-tool chain.

## Risks / what a reviewer should check

- **The recipe uses cmake although the release asset ships a generated
  `configure`.** That is a deliberate choice, not an oversight: cmake gives
  `-DEXPAT_SHARED_LIBS=OFF` and the three `*_BUILD_*` switches, which is
  cleaner than expat's autotools equivalents. The AGENTS.md rule is that
  flags come from the *right* variable for the build system actually in
  use, and `$CMAKE_FLAGS` is correctly used here.
- **`EXPAT_BUILD_TOOLS` defaults ON for everything except WinCE**
  (CMakeLists.txt:61-66), and line 591 installs `xmlwf` into `bin/`. The
  recipe used to omit the switch and so silently gained a CLI tool on all
  six systems. It is now `-DEXPAT_BUILD_TOOLS=OFF`. An earlier version of
  this file claimed tools were "off by default"; that was wrong.
- **`XML_POOR_ENTROPY` / `XML_CONTEXT_BYTES` are left at their defaults.**
  The Android `xml.h` from the NDK sysroot is not in the picture here
  because expat installs its own `expat.h` into `$OUT/include`, and the
  loader puts `$PREFIX/include` first in the Android systems' `$CFLAGS`
  (aarch64-android21/generic.lua:65). Worth being aware of, because a
  consumer compiling against both the NDK's `libxml2` and this expat would
  get whichever `include/` comes first.
- **No `lib/libexpat.so`:** `EXPAT_SHARED_LIBS=OFF` (`generic.lua:9`).
  Consistent with the static-everywhere norm.

## How to verify once built

- `lib/libexpat.a`
- `include/expat.h`
- `lib/pkgconfig/expat.pc` and `pkg-config --modversion expat` → `2.7.1`
- `readelf -h lib/libexpat.a` → `Machine: AArch64` on Android targets
- `llvm-nm lib/libexpat.a | grep XML_ParserCreate` → defined, proving the
  public entry point compiled
- `bin/xmlwf` must be **absent** — its presence means the tools switch did not take
- `ls bin` should be empty; no examples or test binaries anywhere under `$OUT`
