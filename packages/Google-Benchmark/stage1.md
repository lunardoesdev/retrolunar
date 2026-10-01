# Google-Benchmark build forecast

- **Package:** Google-Benchmark (recipe and directory are named with upstream's
  capitalisation; the tree has no other convention for a capitalised name, and
  `topackage.md` lists it that way)
- **Version:** 1.9.5 (release `v1.9.5`, 2026-01-21, newest on google/benchmark)
- **Upstream URL:** `https://github.com/google/benchmark/archive/refs/tags/v1.9.5.tar.gz`
  (HTTP 200, 267 259 bytes, top directory `benchmark-1.9.5/`)
  The release list has **no assets**, so the git tag archive is the only form.
- **Build system: cmake** (`cmake_minimum_required` — see the caveat below).
  No autotools anywhere in the tarball.
- **Config template: none.** No `AC_CONFIG_HEADERS`, no `config.h.in` — it is a
  cmake project. **No timestamp guard applies and none is written.**
- **Dependencies required: none.** No `require()` of any other package.
- **Installs:** `lib/libbenchmark.a`, `include/benchmark/benchmark.h`,
  `include/benchmark/`, `lib/pkgconfig/benchmark.pc`,
  `lib/pkgconfig/benchmark_main.pc`, `lib/cmake/benchmark/benchmarkConfig.cmake`,
  `share/doc/benchmark/` (README, LICENSE).

### The gtest question, answered from the tree

The assignment asked whether it needs a native gtest at build time. The answer
is **yes by default, and the recipe's one switch removes it**:

- `CMakeLists.txt:6` — `option(BENCHMARK_ENABLE_TESTING ... ON)`, so testing is
  **on** out of the box.
- `CMakeLists.txt:348-363` — the whole block is `if (BENCHMARK_ENABLE_TESTING)`.
  Inside it, at `:350-352`, if `BENCHMARK_ENABLE_GTEST_TESTS` is on and the
  `gtest`/`gtest_main`/`gmock`/`gmock_main` targets do not already exist, then:
  - `BENCHMARK_USE_BUNDLED_GTEST` (default **ON**, `:41`) → `include(GoogleTest)`
    at `:354`, which pulls in **`cmake/GoogleTest.cmake.in`**;
  - that file declares an `ExternalProject` named `googletest`, searches
    `GOOGLETEST_PATH` (default `/usr/src/googletest`), and if it is not found
    and `ALLOW_DOWNLOADING_GOOGLETEST` is off, it calls
    `message(SEND_ERROR "Did not find Google Test sources!...")` — a hard
    configure failure;
  - with `ALLOW_DOWNLOADING_GOOGLETEST=ON` it would instead
    `ExternalProject_Add(... GIT_REPOSITORY https://github.com/google/googletest.git)`,
    i.e. a **network fetch at configure time followed by a host build**.
- `CMakeLists.txt:363` then does `add_subdirectory(test)` regardless of the
  gtest branch, so the test programs are host binaries.

`BENCHMARK_ENABLE_TESTING=OFF` short-circuits **all** of that: no
`GoogleTest.cmake.in`, no `ExternalProject`, no `find_package(GTest)`, no
`add_subdirectory(test)`. The two finer switches are therefore redundant once
the outer one is off, and the recipe does not pass them.

Note this tree **does** have `packages/googletest` and `packages/doctest` — but
neither would satisfy the bundled path, which wants a *source tree* at
`GOOGLETEST_PATH`, not an installed package. The only way to use the installed
one would be `BENCHMARK_USE_BUNDLED_GTEST=OFF`, which then does
`find_package(GTest CONFIG REQUIRED)` at `:356`. **The recipe does neither**,
because the tests are host programs and must not be compiled at all on a cross
build.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | With testing off, the only targets are `benchmark` (library, `src/CMakeLists.txt:20`) and `benchmark_main` (`:77`). `CMakeLists.txt:142` sets `CMAKE_CXX_STANDARD 17` and `:146` turns extensions off, so it needs C++17 — NDK clang 19 provides that at API 21. The library sources use `<cstdint>`, `<cstring>`, `<chrono>`, `<thread>` and `<mutex>`. **`<thread>` and `<mutex>` are libc++ header facilities, not Bionic ones**, and the implementation lives in Bionic's libc since forever — `std::thread::hardware_concurrency()` reads from it. No API-24+ symbol is called directly. |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above; no arch-specific code and no SIMD intrinsics in this library. |
| `x86_64-mingw` | **WILL BUILD** | benchmark is deliberately platform-portable and CI-tests Windows. `src/benchmark_runner.cc` and `src/sysinfo.cc` use `GetSystemInfo`/`QueryPerformanceCounter` under `#ifdef _WIN32`, and the Android path (`gettid`, `/proc/self/status` for CPU affinity) is behind `#if defined(__linux__) && !defined(__ANDROID__)` — worth naming because it means the Android rows take the *generic* timing path, which is the reason `std::chrono` rather than `clock_gettime` is what matters. No `-lpthread`: `std::thread` is in libc++ and Bionic has no separate thread library; on mingw it is in `libwinpthread` which the toolchain links by default. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3. |

**API level notes.** **No new wall.** The one library-level API worth naming
is that benchmark's `sysinfo.cc` reads the number of online CPUs. On Linux that
is `std::thread::hardware_concurrency()` → `sched_getaffinity`/`/proc`, all
present at API 21. Nothing uses `nl_langinfo` (API 26), `iconv` (API 28),
`mktime_z` (API 35), `posix_spawn` (API 28) or `process_vm_readv` (API 21
absent). **The API level is inert.**

**Risks / what a reviewer should check.**
1. **`BENCHMARK_ENABLE_TESTING=OFF` is the load-bearing flag and it is
   non-obvious**, because the failing paths are indirect: a `SEND_ERROR` about
   missing googletest sources, or an `ExternalProject` git clone of googletest
   into the build tree. Both would be caught by a reviewer reading
   `cmake/GoogleTest.cmake.in`, which is a separate file from the one the
   option lives in.
2. **`BENCHMARK_ENABLE_INSTALL` stays ON deliberately** (`CMakeLists.txt:29`,
   default ON). It gates the archive, the headers, both `.pc` files and the
   CMake config (`src/CMakeLists.txt:134-161`). Turning it off would install
   nothing at all.
3. **`BENCHMARK_INSTALL_TOOLS`** (`CMakeLists.txt:32`) installs the Python
   reporting scripts under `tools/gbench/`. They are data, never executed, and
   harmless — but a reviewer seeing `tools/` in a C++ package's install set
   should know that is why.
4. **`BUILD_SHARED_LIBS=OFF` also sets `BENCHMARK_STATIC_DEFINE`.**
   `src/CMakeLists.txt:73` adds `-DBENCHMARK_STATIC_DEFINE` when it is off, and
   `BUILD_SHARED_LIBS` is what `add_library(benchmark ...)` at `:20` reads
   directly. Passing it is what makes the archive static; the extra define is
   upstream handling the `BENCHMARK_EXPORT` visibility for us.
5. **Directory name is capitalised (`Google-Benchmark`)** and so is the
   `$OUT/Google-Benchmark` staging path. Nothing else in the tree uses
   capitals, so a reviewer may want to confirm that is intended rather than a
   slip. The recipe is internally consistent either way, and `require()`,
   `$NESTDIR/source/Google-Benchmark` and `stage1.md` all agree.
6. **No `require("googletest")`** — and that is correct rather than an
   oversight, per the reasoning above: the installed gtest cannot satisfy the
   bundled path, and the tests must not be compiled at all on a cross build.

**How to verify once built.**
- `lib/libbenchmark.a`, `include/benchmark/benchmark.h`,
  `lib/pkgconfig/benchmark.pc`, `lib/pkgconfig/benchmark_main.pc`,
  `lib/cmake/benchmark/benchmarkConfig.cmake`
- `pkg-config --modversion benchmark` → `1.9.5`
- `llvm-objdump -f lib/libbenchmark.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libbenchmark.a | grep -c Benchmark` → non-zero
- `find $PREFIX -name 'gtest*' -o -name '*gmock*'` → **empty**, and
  `find $NESTDIR/tmp -name googletest-src` → **empty**: the two checks that
  prove `-DBENCHMARK_ENABLE_TESTING=OFF` actually kept gtest out, including
  the network-fetch path
- `find $PREFIX/lib -name '*.so*'` → **empty** (risk 4)
- `grep -m1 Cflags lib/pkgconfig/benchmark.pc` should carry `-I${includedir}`
  and no absolute `$OUT` path after the loader's rewrite