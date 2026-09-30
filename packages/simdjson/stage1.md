# simdjson build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.12.3 (`github.com/simdjson/simdjson/archive/refs/tags/v3.12.3.tar.gz`)
- Build system: **CMake** (`cmake -S . -B build` at `generic.lua:12`)
- Installs: `lib/libsimdjson.a`, `include/simdjson.h`,
  `include/simdjson/*.h`, `include/simdjsondom.h` and the other amalgamation
  headers, `lib/pkgconfig/simdjson.pc`, plus a CMake package config
- Requires: `simdjson@source` only (`generic.lua:1`). **No dependencies** —
  which is the point of this recipe, see the workaround below.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe's central move is `cmake --build build --target simdjson --parallel 1` (`generic.lua:13`) — naming the library target so that simdjson's tests, examples, benchmark and fuzzers are never compiled. Those host programs link `-lrt`, which **Bionic does not provide at any API level**; that is the wall the `--target` avoids, and it is why the recipe comment (`generic.lua:6-11`) exists. With only the library built, the remaining sources are `src/simdjson.cpp` plus the per-implementation files under `src/generic/` and `src/westmere/`, which use `stdatomic.h` and `<cmath>`. `stdatomic.h` exists in the NDK at API 21. `log10` and friends resolve because `$LDFLAGS` carries `-lm` at `packages/aarch64-android21/generic.lua:78` — as `packages/simdjson/readme.md:53-55` already records. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; simdjson selects its implementation at **runtime**, not compile time, so one archive works on every arch. |
| x86_64-mingw | WILL BUILD | `--target simdjson` also removes the `-lrt` problem here. simdjson's CMake guards its westmere path on x86; on mingw it falls back to the generic implementation. |
| clang-native | WILL BUILD | Native; `-lrt` *exists* here, but the `--target` restriction still applies, so the same subset is built everywhere. |

**API level notes.** **No new wall.** `-lrt` is the only Bionic gap that
applies and it is a *link-time library* absence, not an API-level one — the
host programs are simply never built, so the gap never arises. Everything
simdjson's library target itself uses (`stdatomic.h`, `<cmath>`, `mmap`/
`mprotect` for the backends) is present at API 21. **The API level is
genuinely inert for this package** and no row should be read as
API-sensitive.

**Risks / what a reviewer should check.**
1. **`--target simdjson` is load-bearing and undocumented upstream.** simdjson
   has no `BUILD_TESTS`-style option; the recipe comment is the only record of
   why. The install rules for the archive, the headers *and* the generated
   single-header `simdjson.h` all hang off that target
   (`generic.lua:11` claims so), so if a future simdjson release detaches an
   install rule from the `simdjson` target, the install silently installs
   less. Worth re-checking on a version bump.
2. **`-DBUILD_SHARED_LIBS=OFF` is passed but `BUILD_STATIC_LIBS` is not.**
   simdjson defaults its static target on, so this is belt-and-braces. Fine.
3. **This is a textbook "someone hit a wall" recipe and the workaround is
   still there.** It is good design and should stay: the alternative would be a
   `sed` or an upstream patch, both forbidden by AGENTS.md.
4. `SIMDJSON_ENABLE_THREADS` defaults `ON` and pulls pthread. Bionic has
   pthreads **in libc**, with no `-lpthread` at all — and the archive is static,
   so no link line is produced that could ask for `-lpthread`. Harmless, but
   that is why the readme's note about the Android systems "already providing
   it" is loose: there is no separate thread library at all.

**How to verify once built.**
- `lib/libsimdjson.a`, `include/simdjson.h`, `include/simdjsondom.h`,
  `include/simdjson/error.h`, `lib/pkgconfig/simdjson.pc`
- `pkg-config --modversion simdjson` → 3.12.3
- `llvm-nm --defined-only lib/libsimdjson.a | grep -c _ZN8simdjson` — a large
  non-zero count proves the C++ symbols are there
- `llvm-objdump -f lib/libsimdjson.a | head` → `elf64-littleaarch64` on aarch64
- `strings include/simdjson.h | grep -m1 3.12.3` for the version stamp
- **Confirm the install did not include test binaries**: `find . -name
  '*_test*' -o -name 'benchmark*'` under the prefix should come back empty.