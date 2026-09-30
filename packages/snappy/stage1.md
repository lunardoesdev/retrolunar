# snappy build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.2.2 (`github.com/google/snappy/archive/refs/tags/1.2.2.tar.gz`)
- Build system: **CMake** (`generic.lua:9`)
- Installs: `lib/libsnappy.a`, `include/snappy.h`,
  `include/snappy-suffix.h`, `include/snappy-stubs-public.h`,
  `lib/pkgconfig/snappy.pc`, plus a CMake package config
- Requires: `snappy@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library target is pure C++98 with no dependencies: `snappy.cc`, `snappy-sinks.cc`, `snappy-stubs-internal.cc`, `snappy-stubs-internal.h` use only `<cstdio>`, `<cstring>`, `<algorithm>` and the STL. `-DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF` (`generic.lua:9`) keeps the two host programs — which use gtest and a benchmark harness — out of the build. Nothing Bionic lacks is reached. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; snappy has no SIMD and no arch-specific path. |
| x86_64-mingw | WILL BUILD | As above. snappy's CMake has no WIN32-specific source list. |
| clang-native | WILL BUILD | Native; same subset. |

**API level notes.** **No new wall.** snappy's library sources touch no POSIX,
no locale, no threads and no file I/O — compression is a pure function of the
input buffers. The API level is inert, and no row should be read as
API-sensitive.

**Risks / what a reviewer should check.**
1. **`SNAPPY_BUILD_TESTS=OFF` is the default upstream**, so this flag is
   documentation rather than a fix. Worth keeping: it makes the intent
   auditable, and it costs nothing. Unlike simdjson
   (`packages/simdjson/stage1.md`), snappy *does* offer the switch, so this
   recipe is the ordinary case rather than the `--target` workaround.
2. **`-DBUILD_SHARED_LIBS=OFF` is the only shared/static control.** snappy's
   CMake defines its own `BUILD_SHARED_LIBS` option with a default of `ON`, so
   passing `OFF` is genuinely load-bearing here — without it a
   `libsnappy.so.1.1.10` with a versioned soname would land in `$OUT/lib`,
   and nothing on a device loads from that path. The other cmake recipes in
   this tree (jansson, utf8proc, libuv) make the same choice.
3. The C++ standard is **not pinned**. snappy 1.2.2 is C++98-clean and its
   CMake does not set `CMAKE_CXX_STANDARD`, so each `$CXX` default applies.
   All six systems export a working `$CXX`. No `-std=` in the recipe means no
   target fact is hardcoded, which is correct.

**How to verify once built.**
- `lib/libsnappy.a`, `include/snappy.h`, `include/snappy-suffix.h`,
  `lib/pkgconfig/snappy.pc`
- `pkg-config --modversion snappy` → 1.2.2
- `llvm-objdump -f lib/libsnappy.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libsnappy.a | grep -m1 snappy::Compress` — proves
  the mangled C++ symbols are present
- `find $PREFIX/lib -name 'libsnappy.so*'` must come back **empty**: a shared
  object here means `-DBUILD_SHARED_LIBS=OFF` stopped taking effect