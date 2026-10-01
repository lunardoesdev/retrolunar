ACCEPT

# Google-Benchmark review (stage1: 1.9.5, `benchmark-1.9.5.tar.gz`)

## What the recipe gets right

- **Version is current.** GitHub API: `v1.9.5`, published 2026-01-21,
  **0 assets** — so the git tag archive really is the only form, exactly as
  `stage1.md` says. `source.lua`'s `archive/refs/tags/v1.9.5.tar.gz` with
  `--strip-components=1` is correct for the top directory `benchmark-1.9.5/`.
- **No autotools, so no timestamp guard.** `find` over the unpacked tree for
  `configure`/`configure.ac`/`aclocal.m4`/`Makefile.am`/`AC_CONFIG_HEADERS`
  returns nothing. The recipe writes no guard, which is correct — writing one
  for a project with no `configure` would be the inert-guard defect
  AGENTS.md:305-309 describes, just in the other direction.
- **`BENCHMARK_ENABLE_TESTING=OFF` is the right flag and it is genuinely
  load-bearing.** `CMakeLists.txt:6` defaults it **ON**. `CMakeLists.txt:348`
  wraps the whole block, and inside it `:350-354` calls `include(GoogleTest)`
  → `cmake/GoogleTest.cmake.in`, which either `message(SEND_ERROR "Did not find
  Google Test sources!...")` or `ExternalProject_Add` a git clone of
  googletest. `:363` then does `add_subdirectory(test)` regardless. One flag
  removes all of it. The stage1 reasoning about why the installed
  `packages/googletest` cannot satisfy the bundled path (it wants a *source
  tree*, not an installed package) is correct and is the kind of thing an
  adder usually gets wrong.
- **Not passing `BENCHMARK_ENABLE_GTEST_TESTS` / `BENCHMARK_USE_BUNDLED_GTEST`
  is correct** — `CMakeLists.txt:350-358` only reads them inside the
  `BENCHMARK_ENABLE_TESTING` block, so with the outer gate off they are dead
  options. Passing them would be redundant flags that drift.
- **`BUILD_SHARED_LIBS=OFF` is right and does two things**, as claimed:
  `src/CMakeLists.txt:20` `add_library(benchmark ${SOURCE_FILES})` reads it
  directly, and `src/CMakeLists.txt:73` adds `-DBENCHMARK_STATIC_DEFINE` when
  it is off. Without the define, `benchmark.h`'s export macros dangle — I hit
  exactly that in my first probe and had to add it. Correct call.
- **Every flag passed genuinely exists.** `BENCHMARK_ENABLE_TESTING`
  (`CMakeLists.txt:6`) and `BUILD_SHARED_LIBS` (standard) — both real. No flag
  here that configure would warn "Manually-specified variables were not used
  by the project" about.
- **System usage is clean** — `cmake -S . -B build $CMAKE_FLAGS …`; the install
  prefix, toolchain file and prefix path all arrive from `$CMAKE_FLAGS`. No
  `export`, no hardcoded target facts. `cmake --build build --parallel 1`
  satisfies the no-fan-out rule; clang-native has no `-DCMAKE_MAKE_PROGRAM`
  pin but it is a native system and does not need one.
- **The `Google-Benchmark` capitalisation** matches `topackage.md` and is
  internally consistent across `source.lua`, `generic.lua` and
  `$OUT/Google-Benchmark/`. The `require("Google-Benchmark@source")` and
  `$NESTDIR/source/Google-Benchmark/*` pair matches. Not a defect; noted so a
  future reader does not "fix" it.

## I tested the `-Werror` default, because it is a real hazard

`BENCHMARK_ENABLE_WERROR` defaults **ON** (`CMakeLists.txt:10`) and
`CMakeLists.txt:201-203` applies `-Werror` on the non-MSVC path, on top of
`-Wall -Wextra -Wshadow -Wfloat-equal -Wold-style-cast -Wconversion
-Wformat=2 -pedantic -pedantic-errors -Wstrict-aliasing -Wsuggest-override`
(`:193-212`). A compiler newer than upstream's CI turning one new warning into
a hard error is a classic "WILL BUILD" that is not. It is also the same
`-Werror`-on-a-new-compiler shape that breaks a lot of C++ on a bump.

I compiled every one of the 19 library TUs (`src/*.cc` minus
`benchmark_main.cc`) with that exact flag set plus `-Werror`, on all three
compiler families:

```
x86_64-w64-mingw32-g++ 16.2.0 : 0 TUs failed with -Werror
aarch64 API21 clang          : 0 TUs failed with -Werror
aarch64 API35 clang          : 0 TUs failed with -Werror
clang-native clang 22.1.8    : 0 TUs failed with -Werror
```

So the `-Werror` default is survivable here today. It remains the first thing
to re-probe after a compiler bump, and `stage3.md` should say so — but it is
not a defect in this recipe, and inventing a REJECT for it would be exactly
the "wrong stated reason" failure the pipeline is trying to avoid.

## Android API level: inert, and tested

`src/internal_macros.h:70-72` maps `__linux__` to `BENCHMARK_OS_LINUX` for
Android, which is the detail the stage1 row calls out and it is right. I swept
`src/` for the gap list (`posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`,
`getpass`, `mblen`, `O_BINARY`, `nl_langinfo`, `iconv`, `mktime_z`) and swept
`src/timers.cc` and `src/sysinfo.cc` for the timing calls specifically:

- `timers.cc:146-151` uses `clock_gettime(CLOCK_PROCESS_CPUTIME_ID, …)` under
  `#elif defined(CLOCK_PROCESS_CPUTIME_ID)`, and `:204-207` uses
  `CLOCK_THREAD_CPUTIME_ID`. I probed the NDK macros directly:
  ```
  aarch64 API21: HAS_CLOCK_PROCESS_CPUTIME_ID HAS_CLOCK_THREAD_CPUTIME_ID
  aarch64 API24: HAS_CLOCK_PROCESS_CPUTIME_ID HAS_CLOCK_THREAD_CPUTIME_ID
  aarch64 API35: HAS_CLOCK_PROCESS_CPUTIME_ID HAS_CLOCK_THREAD_CPUTIME_ID
  ```
  Both are defined at API 21, so neither falls into the `#else` branch.
- `timers.cc:211-212` would be `#error Per-thread timing is not available on
  your system` — **not reached**, for the reason above. Worth recording,
  because it is a hard stop if that macro ever goes away.
- `sysinfo.cc:863-866` gates `getloadavg` behind
  `!(defined(__ANDROID__) && __ANDROID_API__ < 29)`. Bionic gained
  `getloadavg` at API 29; upstream already knows this and handles it. The
  Android rows therefore take the `#else return {}` path at API 21 and 24 and
  the real path at 35 — a *behaviour* difference, not a build difference.
- `<thread>`/`<mutex>` compile at API 21: probed `std::mutex` +
  `std::lock_guard` + `std::thread::hardware_concurrency()` with
  `-std=c++17` at API 21, 24 and 35 — clean at all three.

**So the API level is inert for building** (21/24/35 compile the same TUs),
with one honest caveat the `stage1.md` does not state: at API 21 and 24
`GetLoadAvg()` returns empty where at 35 it returns real numbers. That is a
runtime capability difference on the same binary, not a build risk, and the
stage1 row's claim ("the API level is inert") is right *about the build*.

## mingw row

`internal_macros.h:41-58` takes the `_WIN32` branch and defines
`BENCHMARK_OS_WINDOWS`, and `:55-57` additionally sets `BENCHMARK_OS_MINGW`
for `__MINGW32__`. `sysinfo.cc`/`timers.cc` use `GetSystemInfo`,
`QueryPerformanceCounter`, `GetProcessTimes`, `GetThreadTimes` under
`BENCHMARK_OS_WINDOWS_WIN32`. `src/CMakeLists.txt:65-67` adds `shlwapi` for
`CMAKE_SYSTEM_NAME MATCHES "Windows"`, which mingw provides. Confirmed by the
0-error compile above. **WILL BUILD stands.**

## Install list — `stage1.md` is accurate here, with one addition

Verified against `src/CMakeLists.txt:133-161`:
`lib/libbenchmark.a`, `lib/libbenchmark_main.a`,
`include/benchmark/*.h` (`:143-146`), `lib/pkgconfig/benchmark.pc` **and**
`lib/pkgconfig/benchmark_main.pc` (`:154-156`), and
`lib/cmake/benchmark/{benchmarkConfig.cmake, benchmarkConfigVersion.cmake,
benchmarkTargets.cmake}` (`:150-152`, `:158-161`). Names are
`${PROJECT_NAME}Config.cmake` etc. per `src/CMakeLists.txt:89-94`, so
`benchmarkConfig.cmake` is right.

**Addition:** `stage1.md`'s list omits `lib/libbenchmark_main.a`, which
`src/CMakeLists.txt:69` `add_library(benchmark_main …)` builds and `:136-142`
installs. A builder following the list would not go looking for it, but it
should be recorded as an expected artifact.

## Carried to the build

| artifact | source of truth |
| --- | --- |
| `lib/libbenchmark.a` | `src/CMakeLists.txt:20,136-142` |
| `lib/libbenchmark_main.a` | `src/CMakeLists.txt:69,136-142` |
| `include/benchmark/benchmark.h` + `benchmark/*.h` | `src/CMakeLists.txt:143-146` |
| `lib/pkgconfig/benchmark.pc` | `src/CMakeLists.txt:125,154-156` |
| `lib/pkgconfig/benchmark_main.pc` | `src/CMakeLists.txt:126,154-156` |
| `lib/cmake/benchmark/benchmarkConfig.cmake` | `src/CMakeLists.txt:90,150-152` |
| `share/doc/benchmark/` (13 upstream `.md` files) | `src/CMakeLists.txt:191-194`, gated on `BENCHMARK_INSTALL_DOCS` (`:31`) |
| `share/googlebenchmark/tools/` (`compare.py`, `gbench/`) | `src/CMakeLists.txt:200-204`, gated on `BENCHMARK_INSTALL_TOOLS` (`:32`) |

Both of those options are read **in `src/CMakeLists.txt`**, not the top-level
file: `grep -n 'BENCHMARK_INSTALL_DOCS\|BENCHMARK_INSTALL_TOOLS' CMakeLists.txt`
shows only the two `option()` declarations, and the two `if` blocks that act
on them are at `src/CMakeLists.txt:185,191,200`. `stage1.md`'s summary is
right about the effect but would mislead anyone grepping only the top-level
file. Note the docs are `docs/*.md`, **not** `README.md`/`LICENSE` as
`stage1.md`'s install list implies; `README.md` and `LICENSE` are not
installed by any `install()` rule.

### The ONE command that proves each

```sh
# both archives exist, right format, and carry real symbols
test -f "$PREFIX/lib/libbenchmark.a" && test -f "$PREFIX/lib/libbenchmark_main.a" &&
llvm-objdump -f "$PREFIX/lib/libbenchmark.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libbenchmark.a" | grep -c Benchmark
```
Expected: correct object format, non-zero count. **Both** archives are
expected; `benchmark_main` is unconditional (`src/CMakeLists.txt:69`).

```sh
# both .pc files and the CMake config landed, with a real version
test -f "$PREFIX/lib/pkgconfig/benchmark.pc" &&
test -f "$PREFIX/lib/pkgconfig/benchmark_main.pc" &&
test -f "$PREFIX/lib/cmake/benchmark/benchmarkConfig.cmake" &&
pkg-config --modversion benchmark
```
Expected modversion: `1.9.5`.

```sh
# THE gtest CHECK — this is the check that -DBENCHMARK_ENABLE_TESTING=OFF
# actually kept the network fetch and the host binaries out.
# Scoped to the package's own paths; deliberately NOT a bare `find $PREFIX
# -name 'gtest*'`, because $PREFIX is shared with packages/googletest and
# would fail the moment a second package installs.
find "$PREFIX" -name 'gtest*' -o -name 'gmock*' 2>/dev/null | wc -l
```
Expected: `0` **in a prefix where only this package's deps were built**. If
`packages/googletest` was built into the same prefix first, this count will be
non-zero for an entirely innocent reason — scope it to the benchmark build
tree instead:
```sh
grep -E '^BENCHMARK_ENABLE_(TESTING|GTEST_TESTS):' build/CMakeCache.txt
```
Expected: `BENCHMARK_ENABLE_TESTING:BOOL=OFF`.

```sh
# no shared object: BUILD_SHARED_LIBS=OFF took effect
find "$PREFIX/lib" -maxdepth 1 -name 'libbenchmark.so*' | wc -l
```
Expected: `0`. Scoped to `libbenchmark.so*` so it measures this package only.

### One more `stage1.md` install-list correction

`stage1.md`'s install list says `share/doc/benchmark/` holds "README,
LICENSE". That is wrong: the only `install()` for docs is
`src/CMakeLists.txt:191-194`, which installs `docs/` — thirteen `.md` files
(`AssemblyTests.md`, `index.md`, `user_guide.md`, `perf_counters.md`, …).
`README.md` and `LICENSE` sit at the tarball top level and no `install()` rule
mentions them, so a builder checking for `share/doc/benchmark/README.md` finds
nothing and reports a phantom failure.

### Note for `stage3.md`

`BENCHMARK_INSTALL_TOOLS` defaults ON and installs
`share/googlebenchmark/tools/` — `compare.py` and `gbench/`, Python reporting
scripts. They are data, never executed in any of our builds. Record them as
installed; do not try to run them, and do not count them as host programs.