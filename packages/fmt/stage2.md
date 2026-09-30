ACCEPT

# fmt 11.1.4 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- `-DFMT_TEST=OFF` and `-DFMT_DOC=OFF` are both **ON by default** for a master
  project, and both pull host-side work: the test targets and the doc build.
  Turning them off is the correct cut, and passing them explicitly means the
  recipe does not depend on a default that could be flipped upstream.
- `-DFMT_INSTALL=ON` is the default too, but it is the switch that produces the
  headers, `libfmt.a`, `fmt.pc` and the cmake package, so naming it is right.
- `-DBUILD_SHARED_LIBS=OFF` gives the static `libfmt.a` the prefix wants.
  `cmake --build build --parallel 1` is serial, install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("fmt@source")` names no missing package.
- The Android systems' `-DTHREADS_PREFER_PTHREAD_FLAG=ON` and their C++17
  defaults leave fmt alone: upstream's floor is `cxx_std_11`, and the NDK
  wrappers default to `gnu++17`.

## One stale comment, not a reject reason

`generic.lua:6-7` says "FMT_TEST and the bundled program are host programs".
**fmt 11.1.4's `CMakeLists.txt` declares no `add_executable` at all** — it
builds only the `fmt` and `fmt-header-only` library targets. There is no
bundled program, and `$OUT/bin` stays empty. This also answers `stage1.md`'s
open question ("`bin/fmt` only if FMT_INSTALL puts it there — `ls $OUT/bin`
settles it"): it never does.

Fix the comment to drop the bundled-program claim and say that `FMT_INSTALL`
is what produces the headers, `libfmt.a`, `fmt.pc` and the package config.

## Carried to the build

- `lib/libfmt.a` — `llvm-objdump -f lib/libfmt.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libfmt.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/fmt/format.h`, `include/fmt/core.h` — `[ -f include/fmt/format.h ] && [ -f include/fmt/core.h ]`. `core.h` is **generated at configure time** from `base.h`, so its presence proves the configure step completed.
- `lib/pkgconfig/fmt.pc` — `pkg-config --modversion fmt` → `11.1.4`.
- `lib/cmake/fmt/fmt-config.cmake`, `fmt-config-version.cmake`, `fmt-targets.cmake` — `[ -f lib/cmake/fmt/fmt-config.cmake ]`.
- `bin/` must be **absent** — fmt 11.1.4 builds no executable, and an `fmt` binary here would mean a different upstream tree.
- No test binary anywhere under `$OUT`; `-DFMT_TEST=OFF` should keep them out.

## Rework verification

**Verdict: ACCEPT.** First line was already `ACCEPT`; left as `ACCEPT`.

### Correctly fixed

- **The open question about `bin/fmt` is closed, and closed correctly.**
  `stage1.md:6` now ends "**no binaries** — fmt 11.1.4's CMakeLists.txt
  contains no `add_executable`", and `stage1.md:54` is now the flat
  verification "`$OUT/bin` does not exist". Verified in the unpacked tree:
  every `add_executable` in the whole fmt 11.1.4 CMake is under `test/` —
  `test/CMakeLists.txt:29,98,133`,
  `test/add-subdirectory-test/CMakeLists.txt:7,13`,
  `test/cuda-test/CMakeLists.txt:32,45`, `test/find-package-test/CMakeLists.txt:7,13`,
  `test/fuzzing/CMakeLists.txt:17` and `test/static-export-test/CMakeLists.txt:29`.
  The top-level `CMakeLists.txt` has none. And `test/` is only reached via
  `:501` `if (FMT_TEST)` / `:503` `add_subdirectory(test)`, which
  `-DFMT_TEST=OFF` prevents, so none of them is even configured.
- **The install target list settles it independently.**
  `CMakeLists.txt:426` `set(INSTALL_TARGETS fmt fmt-header-only)` and `:434`
  `install(TARGETS ${INSTALL_TARGETS} ...)` — two *library* targets
  (`add_library(fmt ...)` at `:307`, `add_library(fmt-header-only INTERFACE)`
  at `:366`). There is no program in the install set, so `$OUT/bin` cannot be
  created. The claim at `stage1.md:6` is not merely true, it is
  structurally guaranteed.
- **The `fmt.pc` and library paths are right.** `:403-404` sets
  `FMT_PKGCONFIG_DIR` to `${CMAKE_INSTALL_LIBDIR}/pkgconfig` and `:456` installs
  `fmt.pc` there; `FMT_LIB_DIR` is `${CMAKE_INSTALL_LIBDIR}` and `:440-441`
  installs the archive there. `lib/pkgconfig/fmt.pc` is inside the loader's
  rewrite set (`src/loader.lua:454`), and `pkg-config --modversion fmt`
  resolves by file name, so `stage1.md:52` works as written.
- `generic.lua:10` is `cmake --build build --parallel 1` (serial), install
  goes to `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`, and there is
  no `export`, no hardcoded target fact, no `sed`/patch/`/dev/null`.
  `require("fmt@source")` names a package that exists; no `android.lua` is
  needed and none exists.
- `source.lua` is correct: `include/fmt/base.h:24` is
  `#define FMT_VERSION 110104`, which is 11.1.4 — matching the pin. The tag
  archive URL answers 200 and the tree lands in `$OUT/fmt/`.

### Still wrong, outside my scope

- **`generic.lua:6-7` still says "FMT_TEST and the bundled program are host
  programs".** There is no bundled program in 11.1.4, so the comment names a
  target that does not exist and attributes the absence to the wrong flag —
  `FMT_TEST` governs the test targets, and `FMT_INSTALL` is what produces the
  headers, `libfmt.a`, `fmt.pc` and the package config. `stage1.md:26-34`
  still carries the same stale reasoning ("`FMT_INSTALL` also governs whether
  the bundled `bin/fmt` program is installed... `$OUT/bin/fmt` may well exist").
  I am not editing `generic.lua` or `stage1.md`; the comment should be
  corrected to the true mechanism, now that `stage1.md:6` states the verified
  fact.

The specific open question this rework set out to close is now closed with a
 verified citation, the recipe was not touched, and no system-derived flag or
 target fact was disturbed.
