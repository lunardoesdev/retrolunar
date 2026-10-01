# xtensor build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.27.1 (tag `0.27.1`)
- Build system: CMake (header-only)
- Installs: `include/xtensor/`, the generated single-header `include/xtensor.hpp`,
  `xtensor.pc`, a CMake package config under `share/cmake/xtensor/`
  (`CMakeLists.txt:265-308, 344-345`), and the xeus-cpp tagfiles/tags.d trees.
  **No library file** — `add_library(xtensor INTERFACE)` (`:202`).
- Requires: **`xtl` (MISSING)** plus `xtensor@source`. See the blocker below.
- Upstream identity: `github.com/xtensor-stack/xtensor`. 0.27.1 is the newest
  tag; the repository publishes no GitHub "releases" entries, so tags are the
  release list.

## BLOCKER — this package cannot build today: xtl has no recipe

xtensor **hard-requires** xtl:

- `CMakeLists.txt:43` — `set(xtl_REQUIRED_VERSION 0.8.0)`
- `CMakeLists.txt:52-55` — `find_package(xtl ${xtl_REQUIRED_VERSION} REQUIRED)`
  followed by `message(STATUS "Found xtl: ...")`. There is **no** FetchContent,
  no vendored copy and no fallback branch: the only alternative is
  `if (TARGET xtl)` at `:44`, which is false for a top-level build.
- `CMakeLists.txt:211` — `target_link_libraries(xtensor INTERFACE xtl)`, so the
  dependency is exported to every consumer too.

Verified absent, with commands:

- `ls -d packages/xtl` → `No such file or directory`
- `ls packages | grep -i '^xt'` → empty
- `grep -rln 'require("xtl' packages/` → empty (nobody requires it either)
- `grep -i 'xtl' topackage.md` → no entry; xtl is **not on the backlog**

So `require("xtl")` in `generic.lua` cannot resolve, and every row below is
marked on that basis. This is a missing package, not a toolchain problem —
nothing about xtensor itself has been shown to fail. **The fix is to add
`packages/xtl` (header-only, CMake, xtl 0.8.2, `target_compile_features(xtl
INTERFACE cxx_std_17)` at its `CMakeLists.txt:82`) and then this recipe works
unchanged.** I did not create it: xtl is outside my assigned four, and writing
an unrequested fifth package is not my call.

**The headline question — does xtensor need C++14+? It needs C++20.** The brief
guessed C++14. That is wrong for 0.27.1, and it matters because it is the
difference between "builds with the toolchain's default flags" and "does not":

- `CMakeLists.txt:209` — `target_compile_features(xtensor INTERFACE cxx_std_20)`.
- `include/xtensor/utils/xutils.hpp:590` and `:613` use the C++20 `concept`
  keyword **unguarded**, with no `#if __cplusplus` and no `XTENSOR_USE_CPP20`
  gate.
- **Probe:** `#include <xtensor/containers/xtensor.hpp>` plus
  `<xtensor/io/xio.hpp>` and a real 2-D `xt::xtensor<double,2>` aggregate
  initialiser, `-fsyntax-only`, against the NDK libc++ 19:

  | | c++17 | c++20 |
  |---|---|---|
  | aarch64-android21 | FAIL | **OK** |
  | aarch64-android24 | FAIL | **OK** |
  | aarch64-android35 | FAIL | **OK** |
  | x86_64-mingw (g++ 16.2.0) | FAIL | **OK** |
  | clang-native | FAIL | **OK** |

  The c++17 failure is precisely and only the missing `concept`, at
  `xutils.hpp:590` and `:613`:

  ```
  xutils.hpp:590:5: error: unknown type name 'concept'
  xutils.hpp:613:5: error: unknown type name 'concept'
  ```

  (mingw words it `‘concept’ does not name a type; did you mean ‘const’?`.)
  No other diagnostic appears — the failure is the C++20 facility, not a
  missing include or a typo.

**Why that does not stop this recipe.** `cxx_std_20` is an **INTERFACE**
property (`CMakeLists.txt:209`): it constrains *consumers*, and xtensor itself
compiles nothing. So the install is a file copy and needs no flag. What the
recipe records is that **a consumer of this prefix must build at C++20 or
later.** The probe above is the evidence that our own toolchains can do that:
the NDK clang defaults to `__cplusplus` 201703L (probed `-dM`), mingw g++ 16.2
to 202002L, native clang++ to 201703L — so *consumers* need an explicit
`-std=c++20` on Android and native. That is a property of the standard library,
not a recipe defect, and AGENTS.md puts exactly that kind of fact in the system
files rather than in a package recipe, so this recipe passes no `-std` flag.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `find_package(xtl 0.8.0 REQUIRED)` (`CMakeLists.txt:53`) cannot be satisfied: `packages/xtl` does not exist, xtl is not in `topackage.md`, and no other recipe requires it. Independent of system. The C++20 header requirement is *not* the obstacle — probe OK at c++20 on this libc++. |
| aarch64-android24 | **WILL NOT BUILD** | As above. |
| aarch64-android35 | **WILL NOT BUILD** | As above. |
| x86_64-android35 | **WILL NOT BUILD** | As above. |
| x86_64-mingw | **WILL NOT BUILD** | As above; xtl is a cross-cutting gap, not a platform one. Headers verified OK at c++20 here too. |
| clang-native | **WILL NOT BUILD** | As above. Headers verified OK at c++20 here too. |

Every row is blocked by the **same single missing recipe**, so this table is
uniform by construction: no system-specific risk has been left untested. Once
`packages/xtl` exists, re-run the header probe as the acceptance check.

`armv7a-android*` and `i686-android*` match `aarch64-android*`: nothing is
compiled.

**Risks / what a reviewer should check.**

1. **`require("xtl")` will fail at load time today.** The recipe is written as
   it should be once xtl lands, with the blocker recorded in a comment above
   the require. A reviewer should REJECT or park this package rather than try
   to make it pass by dropping the dependency — `CMakeLists.txt:53` is
   `REQUIRED`, so dropping it produces a configure error, not a working build.
2. **C++20 is the floor for consumers, and it is worth writing down.**
   `target_compile_features(xtensor INTERFACE cxx_std_20)` (`:209`) plus the
   unguarded `concept` at `xutils.hpp:590,613`. A consumer built at C++17 fails
   in exactly those two lines.
3. **Nothing else compiles.** `BUILD_TESTS` and `BUILD_BENCHMARK` default OFF
   (`:216-217`), so `add_subdirectory(test)` (`:247`) and
   `add_subdirectory(benchmark)` (`:251`) never run. `DOWNLOAD_GBENCHMARK`
   defaults ON (`:218`) but is only read from the benchmark branch, so **no
   gbenchmark is fetched**.
4. **Optional accelerators are all OFF**: `XTENSOR_USE_XSIMD`, `XTENSOR_USE_TBB`,
   `XTENSOR_USE_OPENMP` (`:62-64`). Their `find_package` calls for xsimd
   (`:83`), TBB (`:90`) and OpenMP (`:95`) therefore never execute — which is
   what keeps xtensor from depending on `tbb` at all, and is worth stating
   given `tbb` is in this same batch.
5. **nlohmann_json is genuinely optional.** `find_package(nlohmann_json 3.1.1
   QUIET)` (`:57`) is `QUIET` and un-`REQUIRED`; it only gates `xjson.hpp`,
   which is excluded from the generated single header (`:331-335`). Note
   `packages/nlohmann-json` **does** exist in this tree, so a future recipe may
   want `require("nlohmann-json")` to get `xjson.hpp` — deliberately not done
   here, to keep the dependency set minimal.
6. **The install copies headers, and upstream does it.** `install(DIRECTORY
   ${XTENSOR_INCLUDE_DIR}/xtensor DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})`
   (`:272-273`) takes the whole `include/xtensor/` tree. The recipe runs
   upstream's install rather than copying by hand.
7. **`cmake_minimum_required(VERSION 3.15..3.29)`** (`:10`) clears the 3.5 floor
   every system carries; no `CMAKE_POLICY_VERSION_MINIMUM` is hardcoded and
   `$CMAKE_FLAGS` is used as-is, per AGENTS.md.

**How to verify once xtl exists and this builds.**

- `include/xtensor/containers/xtensor.hpp` and `include/xtensor/utils/xutils.hpp`
  both exist — the recursive install happened.
- `include/xtensor.hpp` exists (the generated single header) and starts with
  `#ifndef XTENSOR`.
- `share/cmake/xtensor/xtensorConfig.cmake` and `xtensorTargets.cmake` exist.
- `pkg-config --modversion xtensor` reports 0.27.1.
- **No library file:** `find $OUT -name '*.a' -o -name '*.so'` must return
  nothing.
- **No test or benchmark binaries** (risk 3): `find $OUT -name 'test_*' -o -name
  '*benchmark*'` must return nothing.
- `find $OUT -name 'xsimd*' -o -name '*tbb*'` must return nothing (risk 4).
- **The real acceptance check**, and the one that settles the blocker:
  compile `#include <xtensor/containers/xtensor.hpp>` against
  `-I$PREFIX/include -I$PREFIX/include` (xtl's headers land in the same
  `include/`) at `-std=c++20` and confirm it succeeds. `-std=c++17` must fail
  at `xutils.hpp:590` — if it succeeds, the consumer-standard claim in risk 2 is
  wrong and the forecast needs revisiting.
