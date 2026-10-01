# tl::expected build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.1 (tag `v1.3.1`)
- Build system: CMake (header-only)
- Installs: `include/tl/expected.hpp`, `expected.natvis`, and a CMake package
  config under `share/cmake/tl-expected/` (`CMakeLists.txt:49-63`). **No
  library file and no pkg-config file** — the target is `INTERFACE`
  (`:28`) and upstream ships no `.pc.in`.
- Requires: `tl-expected@source` only. No dependencies.
- Upstream identity: `github.com/TartanLlama/expected`. The project is
  "expected"; there is no `tl-expected` repository. The directory here is
  `tl-expected` to match the `topackage.md` spelling and because `tl::expected`
  is not a legal directory name.

**The headline question — does tl::expected require C++23 `<expected>`? No, and
the premise is inverted.** The brief expected this to be the hard case. It is the
softest of the four:

- tl::expected *is* a `<expected>` polyfill. It provides the facility; it does
  not consume it.
- `include/tl/expected.hpp` includes only `<exception>`, `<functional>`,
  `<type_traits>`, `<utility>` (lines 23-27) — **`<expected>` is nowhere in the
  header.** There is nothing to gate.
- `CMakeLists.txt:14-16` defaults `CMAKE_CXX_STANDARD` to **14**.
- **Probe:** `#include "tl/expected.hpp"` plus a real `tl::expected<int,int>` and
  `tl::unexpected<int>`, `-fsyntax-only`: **OK at API 21, 24 and 35 at
  `-std=c++14`, `c++17`, `c++20` and `c++23`; OK on mingw g++ 16.2.0 at c++14,
  c++17, c++20; OK on native clang++ at all four.** No flag is needed on any
  system, so none is passed.
- The header is version-adaptive by design: `TL_CPLUSPLUS` at lines 35-38
  selects `TL_EXPECTED_CXX14` (`:99-100`) and `TL_EXPECTED_EXCEPTIONS_ENABLED`
  (`:28-30`), with explicit workarounds for MSVC 2015, GCC 4.9/5.4/5.5 and
  `_LIBCPP_VERSION && __cplusplus == 201103L` (`:32`, `:248`). Nothing in that
  list is a wall here.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Header-only (`add_library(expected INTERFACE)`, `CMakeLists.txt:28`): nothing is compiled, so the install is a file copy identical everywhere. Probe OK at C++14 (the upstream default) and every higher standard. `EXPECTED_BUILD_TESTS=OFF` keeps the Catch2 FetchContent at `:70-72` — a build-time network fetch — and the test executables out of a cross build. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `INTERFACE` target and a file copy are portable. The `EXPECTED_BUILD_PACKAGE_DEB`/`WIX` generator logic at `:93-103` is inside `EXPECTED_BUILD_PACKAGE`, which is off. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*`: nothing is
compiled and no step observes an API level.

**For the record, the NDK *does* have `<expected>`** — the brief asked me to
check, and the answer is the opposite of the suspicion. NDK 28.2.13676358 ships
libc++ 19.0.0 (`sysroot/usr/include/c++/v1/__config:65`,
`#define _LIBCPP_VERSION 190000`). Probe of `#include <expected>` with a real
`std::expected<int,int>`:

- `-std=c++14`, `c++17`, `c++20`: **FAILS**, with
  `error: no member named 'expected' in namespace 'std'` — the header is gated
  on `__cplusplus >= 202302L`, as C++23 requires.
- `-std=c++23`: **OK** at API 21, 24 and 35.

`sysroot/usr/include/c++/v1/expected` is present on disk and pulls in
`__expected/{bad_expected_access,expected,unexpect,unexpected}.h`. So this NDK
is not a `<expected>` wall at C++23 — it simply is not one before C++23, and
tl::expected does not ask for C++23.

**Risks / what a reviewer should check.**

1. **`BUILD_TESTING=OFF` is not optional.** `include(CTest)` at `CMakeLists.txt:12`
   turns `BUILD_TESTING` on, and `EXPECTED_BUILD_TESTS` is a
   `cmake_dependent_option` defaulting ON whenever it is (`:20-22`). Left alone
   the build does `FetchContent_MakeAvailable(Catch2)` from a github zip
   (`:70-72`) — a network fetch at build time, which AGENTS.md forbids — and
   then builds `tl-expected-tests` (`:76`). The recipe passes both
   `BUILD_TESTING=OFF` and `EXPECTED_BUILD_TESTS=OFF`; the first is what the
   dependent option keys on, the second states the intent.
2. **`EXPECTED_BUILD_PACKAGE=OFF`.** Defaults ON (`:18`) and reaches CPack with
   `DEB`/`RPM` binary generators (`:97-116`) — host-side packaging for a target
   prefix. Off makes the project `return()` at `:87-89` before `include(CPack)`.
   This also disposes of the undefined-variable test at `:101`
   (`if (EXPECTED_BUILD_RPM)` is never declared as an option).
3. **No `.pc` file.** `find` for `*.pc.in` in the tree returns nothing, so there
   is nothing for the loader's `$OUT`→`$PREFIX` rewrite to fix. Consumers use
   `find_package(tl-expected)` or add `-I$PREFIX/include`. Worth recording so
   nobody writes `pkg-config --cflags tl-expected` and calls it broken.
4. **`install(DIRECTORY "include/" TYPE INCLUDE)` at `:63`** copies the whole
   `include/` tree — today just `tl/expected.hpp`. The recipe runs upstream's
   own install rather than copying by hand, which is why a future added header
   cannot be silently dropped.
5. **Installed layout is `share/cmake/`, not `lib/cmake/`.** `:42` and `:54` use
   `${CMAKE_INSTALL_DATADIR}`. A consumer's `find_package(tl-expected)` searches
   `share/` too, so this works — but it differs from most packages in this tree,
   which is a fact worth knowing rather than a defect.
6. **`cmake_minimum_required(VERSION 3.14)`** (`:1`) clears the 3.5 floor every
   system already carries, so no `CMAKE_POLICY_VERSION_MINIMUM` is hardcoded and
   `$CMAKE_FLAGS` is used as-is, per AGENTS.md.

**How to verify once built.**

- `include/tl/expected.hpp` exists (note the `tl/` subdirectory — checking for
  `include/expected.hpp` is the obvious wrong path).
- `share/cmake/tl-expected/tl-expected-config.cmake` and
  `tl-expected-targets.cmake` exist.
- **No library file:** `find $OUT -name '*.a' -o -name '*.so'` must return
  nothing.
- **No pkg-config file:** `find $OUT -name '*.pc'` must return nothing (risk 3).
- **No Catch2 and no test binary:** `find $OUT -name 'Catch2*' -o -name
  '*expected-tests*'` must return nothing (risk 1).
- A consumer compiling `#include <tl/expected.hpp>` against
  `-I$PREFIX/include` at `-std=c++17` must succeed — the one functional check
  worth doing.
- Compare two systems' `include/` with `diff -r`: any difference is a bug.
