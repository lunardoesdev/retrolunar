# oneTBB build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2023.1.0 (tag `v2023.1.0`)
- Build system: CMake. **This one really compiles** — unlike Eigen and
  range-v3, oneTBB's `tbb` target is a compiled library.
- Installs: `libtbb`, `libtbbmalloc`, `libtbbmalloc_proxy`, the whole
  `include/` tree, and a CMake package config under `lib/cmake/TBB/`
  (`CMakeLists.txt:313-350`).
- Requires: `tbb@source` only. No dependencies.
- Upstream identity: `github.com/oneapi-src/oneTBB` is canonical. Tags are
  `v`-prefixed years; 2023.1.0 is the newest release tag (2023.2.0 exists only
  as `v2023.2.0-rc1`).

**The headline question — does oneTBB need a recent standard library? No.**
The brief expected C++20/23. It does not:

- `CMakeLists.txt:80-83` defaults `CMAKE_CXX_STANDARD` to **11**.
- Every modern facility is behind a feature macro, not a hard requirement:
  `<memory_resource>` at `include/oneapi/tbb/tbb_allocator.h:25-27` and
  `scalable_allocator.h:35-37` sit under `__TBB_CPP17_MEMORY_RESOURCE_PRESENT`
  (defined at `detail/_config.h:266-267`); `<concepts>` at
  `detail/_range_common.h:22-24` and `detail/_mutex_common.h:23-24` sit under
  `__TBB_CPP20_CONCEPTS_PRESENT` (`detail/_config.h:274-278`).
- **Probe:** `#include <oneapi/tbb/parallel_for.h>`, `parallel_sort.h`,
  `flow_graph.h`, `global_control.h` plus a real `parallel_for`/`parallel_sort`
  call, `-fsyntax-only`, against the NDK at API 21 and API 35, at `-std=c++11`
  and `-std=c++17`: **OK in all four combinations.** Also OK on
  `x86_64-w64-mingw32-g++` 16.2.0 (c++11, c++17) and native `clang++`
  (c++11, c++17).

So **no `-std=gnu++23` is needed anywhere in this recipe, and none is passed.**
Adding it would be a package-local flag with no justification.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Library compiles at the NDK's default `__cplusplus` (201703L, C++17) and at C++11. `TBB_TEST=OFF` keeps `add_subdirectory(test)` (`CMakeLists.txt:350`) from building ~200 doctest executables. The `stderr` worry for API 21 is **not** a blocker — see the probe below. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; `CMAKE_SYSTEM_PROCESSOR` is `aarch64`/`x86_64` in our toolchain files, and `Clang.cmake:67-69` only adds `-mrtm`/`-mwaitpkg` on x86, which the NDK accepts. |
| x86_64-mingw | WILL BUILD | mingw-w64 is a **community-supported** platform for oneTBB (`SYSTEM_REQUIREMENTS.md:59-62`), not a supported one — but the recipe only builds the library, and `MINGW` is handled explicitly at `Clang.cmake:28-29` and `:111-113`. Headers verified above at c++11/c++17. |
| clang-native | WILL BUILD | As above. `-mrtm`/`-mwaitpkg` are added on x86-64 (`Clang.cmake:67-69`). |

`armv7a-android*` and `i686-android*` match `aarch64-android*`: no step in the
recipe observes an API level, and 32-bit targets take `TBB_ARCH 32`
(`CMakeLists.txt:107-112`), which is a size question, not a platform one.

**`stderr` at API 21 — probed, and it is fine.** `AGENTS.md` records API 21 as
lacking a real `stderr`. oneTBB uses it in `src/tbb/assert_impl.h:57,61,70,106`,
`src/tbb/exception.cpp:72`, `src/tbb/misc.cpp:80,90`, `src/tbb/misc.h` and
`src/tbb/tcm_adaptor.cpp:264`. Probe: a shared object containing
`std::fputs(msg, stderr); std::fflush(stderr);`, linked per-API, then
`llvm-nm -D --undefined-only`:

- API 21: no undefined `stderr` at all — it binds to the plain libc symbol.
- API 35: `U stderr@LIBC` (versioned).

Both link (`rc=0`), so the reference resolves on every API level. `O_BINARY`
appears only in `examples/graph/fgbzip2/bzlib.cpp:1518` and
`test/common/doctest.h`, both outside the library — and the whole `examples/`
tree is never added (`TBB_EXAMPLES` defaults OFF).

**Risks / what a reviewer should check.**

1. **`TBB_STRICT=OFF` is the most load-bearing flag here.** Default ON
   (`CMakeLists.txt:116`) turns on `-Werror` via `TBB_WARNING_LEVEL`
   (`Clang.cmake:58`). oneTBB's documented compiler ceiling is Clang 13 /
   GCC 12 (`SYSTEM_REQUIREMENTS.md:71-73`); our clang 19 / gcc 16 are far
   newer and will emit warnings upstream never saw. Only `-Werror` is dropped;
   `-Wall -Wextra` stay.
2. **`TBB_ENABLE_IPO=OFF`.** The IPO block at `CMakeLists.txt:275` is guarded by
   `NOT ANDROID_PLATFORM`, but our toolchain files set `CMAKE_SYSTEM_NAME` to
   `Linux`, so `ANDROID_PLATFORM` is never set and the guard does not fire on
   Android. Upstream's own comment at `:272-273` names the NDK bug LTO trips.
   This is why there is **no `android.lua`**: the same switch is correct on every
   system, so putting it in a per-Android file would leave a live LTO path on
   mingw and native for no reason.
3. **`android/api-level.h` exists — a claim worth double-checking.** It is
   included at `detail/_config.h:511-513` under `#if __ANDROID__`, and the
   NDK wrapper defines `__ANDROID__` (`-dM` probe). The file is
   `sysroot/usr/include/android/api-level.h` — note the **hyphen**. A probe
   using `api_level.h` with an underscore reports "file not found"; that is a
   probe bug, not an NDK gap, and the oneTBB header probe passing at API 21
   already proves the real spelling resolves.
4. **hwloc is not pulled in.** `TBB_DISABLE_HWLOC_AUTOMATIC_SEARCH` defaults to
   `${CMAKE_CROSSCOMPILING}` (`CMakeLists.txt:124`). Probed: a project that sets
   `CMAKE_SYSTEM_NAME` in a toolchain file reports
   `CMAKE_CROSSCOMPILING=TRUE` on both the Android and mingw toolchain files, so
   the pkg-config search at `cmake/hwloc_detection.cmake:58-71` is skipped. On
   `clang-native` it does run, and finds nothing (no hwloc in the prefix,
   `PKG_CONFIG_PATH` empty), which is harmless.
5. **Static means no `tbbbind`.** `CMakeLists.txt:308-311` skips
   `add_subdirectory(src/tbbbind)` when `BUILD_SHARED_LIBS` is off. That is
   upstream's own behaviour, not a loss in this recipe.
6. **`-DCMAKE_POLICY_VERSION_MINIMUM` is not passed.** oneTBB declares
   `cmake_minimum_required(VERSION 3.5.0...3.31.3)` (`CMakeLists.txt:18`), so
   the floor every system already carries (3.5) satisfies it exactly. Per
   AGENTS.md the recipe uses `$CMAKE_FLAGS` and hardcodes nothing.

**How to verify once built.**

- `lib/libtbb.a` exists (static), and `lib/libtbbmalloc.a`.
- `include/oneapi/tbb/parallel_for.h` and `include/oneapi/tbb/version.h` exist;
  `grep -q 'TBB_VERSION_MAJOR 2023' include/oneapi/tbb/version.h`.
- `lib/cmake/TBB/TBBConfig.cmake` and `TBBTargets.cmake` exist.
- `readelf -h lib/libtbb.a`'s member must report the right ELF machine
  (AArch64 / x86-64) and Android API level — the single check that catches a
  wrong-arch or wrong-API archive.
- **No test binaries:** `find $OUT -name 'test_*' -o -name '*-tests'` must
  return nothing (risk 1: `TBB_TEST`).
- `find $OUT -name '*tbbbind*'` must return nothing (risk 5).
- Do **not** run the test suite; these are cross-built target binaries and the
  repo's no-emulation rule applies.
