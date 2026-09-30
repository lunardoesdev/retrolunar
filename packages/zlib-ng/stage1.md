# zlib-ng build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.2.4 (`github.com/zlib-ng/zlib-ng/archive/refs/tags/2.2.4.tar.gz`)
- Build system: **CMake** (`generic.lua:11`)
- Installs: `lib/libz-ng.a`, `include/zlib-ng.h`, `include/zconf-ng.h`,
  `include/zlib-ng*.h` (the compat headers), `lib/pkgconfig/zlib-ng.pc`
- Requires: `zlib-ng@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `-DZLIB_ENABLE_TESTS=OFF` (`generic.lua:11`) keeps the test suite out; the recipe comment at `generic.lua:9` also names `minizip-ng` as a host program. The library is zlib's own sources plus NEON intrinsics selected by `#if` on `__ARM_NEON`, all header-only intrinsics with no libc dependency. The `gz*.c` file-I/O layer uses the same API-21-present set as `packages/zlib/stage1.md`. Nothing API-24+. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; the SSE2/AVX2 paths are `__builtin_cpu_supports`-style runtime or compile-time `__SSE2__` checks, not separate source lists. |
| x86_64-mingw | WILL BUILD | As above, with the same library-name caveat as zlib (risk 3). |
| clang-native | WILL BUILD | Native; zlib-ng's CMake detects host features. |

**API level notes.** **No new wall, and zlib-ng is not more demanding than
zlib.** It reaches `mmap`, `open`, `read`, `write`, `close`, `stat` and
`gettimeofday`. It does **not** call `mktime_z` (API 35) — its own
`gz_write_header` uses `time()` and `localtime()`. It does not use
`nl_langinfo` or `iconv`. The API level is inert.

**Risks / what a reviewer should check.**
1. **`-DZLIB_COMPAT=OFF` is a genuine, deliberate choice and the comment at
   `generic.lua:7-10` explains it**: built in *native* (not zlib-compatible)
   mode, so callers get the zlib API plus the optimised code at once. The
   alternative, `ZLIB_COMPAT=ON`, would emit `zlib.h` and install as `libz-ng`
   with a zlib-shaped ABI. Turning it off here means **this package does not
   satisfy a consumer that expects `zlib.h`**, which is the main thing a
   reviewer should weigh: is `packages/zlib` the compatibility provider and
   `zlib-ng` the performance provider? As written, both install headers and a
   consumer could get an include-path collision between `include/zlib.h` and
   `include/zlib-ng.h`. **This is worth an explicit decision.**
2. **`-DZLIB_ENABLE_TESTS=OFF` and the minizip-ng note.** The comment names
   minizip-ng as a host program, and `packages/minizip-ng` exists in this tree —
   so a reviewer should check whether zlib-ng's CMake finds that `$PREFIX`
   installation and starts building against it. `ZLIB_ENABLE_TESTS=OFF` should
   prevent it, but the flag name should be verified against zlib-ng 2.2.4's
   actual option (it is `ZLIB_ENABLE_TESTS` in 2.2.x, not
   `BUILD_TESTING`).
3. **The library/header names are unusual** — `libz-ng.a`, `zlib-ng.h`,
   `zlib-ng.pc` — so a consumer's `pkg-config` line is `pkg-config --libs
   zlib-ng`, not `zlib`. Easy to get wrong.
4. **`-DBUILD_SHARED_LIBS=OFF`** is the load-bearing static control, matching
   the rest of the tree.
5. **2.2.4 is the current release** of the 2.2 line.

**How to verify once built.**
- `lib/libz-ng.a`, `include/zlib-ng.h`, `include/zconf-ng.h`,
  `lib/pkgconfig/zlib-ng.pc`
- `pkg-config --modversion zlib-ng` → `2.2.4`
- `llvm-objdump -f lib/libz-ng.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libz-ng.a | grep -cE 'deflate|inflate|crc32'` →
  non-zero
- **Check risk 1 concretely:** `test -f $PREFIX/include/zlib.h` should be
  **false** for this package (native mode does not install a `zlib.h`); a
  `zlib.h` here means `ZLIB_COMPAT=OFF` did not take, and the two zlib packages
  in this prefix would be colliding
- `find $PREFIX/lib -name '*.so*'` → **empty**
- `ls $PREFIX/include/` should show `zlib-ng*` headers and **no** `zconf.h`,
  which is the same check from the other side