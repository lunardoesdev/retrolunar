# tinyxml2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 10.0.0
  (`github.com/leethomason/tinyxml2/archive/refs/tags/10.0.0.tar.gz`)
- Build system: **CMake** (`generic.lua:9`)
- Installs: `lib/libtinyxml2.a`, `include/tinyxml2.h`, `lib/pkgconfig/tinyxml2.pc`,
  plus a CMake package config
- Requires: `tinyxml2@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library is one file, `src/tinyxml2.cpp`, plus `src/tinyxml2error.cpp`, and it uses only `<cstdio>`, `<cstdlib>`, `<cstring>`, `<cctype>`, `<cmath>` and the STL. `-Dtinyxml2_BUILD_TOOLS=OFF -Dtinyxml2_BUILD_TESTING=OFF` (`generic.lua:9`) keeps `xmltest` (which uses `readline`) and `tinystr` out of the build. No Bionic gap is reached. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; tinyxml2 has no arch-specific code. |
| x86_64-mingw | WILL BUILD | As above. tinyxml2's `XML_USE_MSTL` is off by default, so it does not pull in `<atlbase.h>`. |
| clang-native | WILL BUILD | Native; same subset. |

**API level notes.** **No new wall.** tinyxml2's compiled surface is
`fopen`/`fread`/`fwrite`/`fclose`/`fseek` (via `XMLDocument::SaveFile`/
`LoadFile`), `malloc`/`realloc`/`free` and `strlen`. All present at API 21.
Notably it does **not** use `nl_langinfo`, so the API-26 wall is clear, and it
does not use locale at all — XML is a fixed character set. The API level is
inert.

**Risks / what a reviewer should check.**
1. **`tinyxml2_BUILD_TESTING=OFF` is the load-bearing flag.** The test target
   `xmltest` links `readline` and, more importantly, is a **host
   executable**; building it on a cross system produces a target binary nobody
   can run. Turning it off is the ordinary upstream switch, not a workaround.
2. **`-Dtinyxml2_INSTALL=ON` is upstream's default**, so like snappy's test
   flag this documents intent rather than fixing anything.
   `-DBUILD_SHARED_LIBS=OFF` is the one that matters — tinyxml2's CMake honours
   it and would otherwise install a `libtinyxml2.so.10` with a versioned soname.
3. **`XML_SHARED` is a separate variable** from `BUILD_SHARED_LIBS` in some
   tinyxml2 CMake versions, and the recipe passes only the latter. If a future
   release makes `XML_SHARED` default to `ON` independently, a shared object
   could appear despite `-DBUILD_SHARED_LIBS=OFF`. **Worth checking on a
   version bump** — the verification step below (searching for `*.so*`) is the
   check that would catch it.
4. No `-std=` is pinned. tinyxml2 10.0.0 sets its own `CMAKE_CXX_STANDARD`
   requirement in its CMake (C++11), and all six `$CXX` defaults satisfy it, so
   no language flag is hardcoded. Correct.
5. 10.0.0 is the current release line; no upgrade pressure.

**How to verify once built.**
- `lib/libtinyxml2.a`, `include/tinyxml2.h`, `lib/pkgconfig/tinyxml2.pc`
- `pkg-config --modversion tinyxml2` → `10.0.0`
- `llvm-objdump -f lib/libtinyxml2.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libtinyxml2.a | grep -c 'XMLDocument'` → non-zero
- `find $PREFIX/lib -name 'libtinyxml2.so*'` must be **empty** (risk 3's check)
- `find $PREFIX/bin -name 'xmltest' -o -name 'tinystr'` must be **empty**,
  proving `-Dtinyxml2_BUILD_TOOLS=OFF` took effect