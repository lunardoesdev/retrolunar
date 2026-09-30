ACCEPT

# GoogleTest 1.17.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- The libraries are built and **no test or sample program is**, which is the
  thing to get right here. `gtest_build_tests` and `gmock_build_tests` default
  OFF upstream and the recipe turns them off explicitly; `gtest_build_samples`
  also defaults OFF and is never enabled. Every googletest test is a target
  binary that nothing could run, so this is the correct cut.
- **The `-DINSTALL_GTEST=OFF` warning in the recipe is the most valuable
  comment in this package.** googletest's own `install()` rules live inside
  `if (INSTALL_GTEST)` (via `install_project` in `cmake/internal_utils.cmake`),
  and `INSTALL_GTEST` defaults ON — so passing OFF would install *nothing at
  all*. That is a real trap, it is documented in the recipe, and it is exactly
  the kind of thing a later maintainer would otherwise "tidy up".
- `-DBUILD_SHARED_LIBS=OFF` gives static `libgtest.a`/`libgmock.a`, consistent
  with the prefix. `cmake --build build --parallel 1` is serial. Install goes
  to `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("googletest@source")` names no missing package. No `@native` need.

## One stale comment, not a reject reason

`generic.lua:8-9` ends with "(and the duplicate legacy `lib/` layout it
controls is harmless)". googletest 1.17.0 has **no** such duplicate:
`install_project(gtest gtest_main)` installs each archive once into
`${CMAKE_INSTALL_LIBDIR}`, and `install_project` has no second `lib/`
destination. Delete the clause — and delete the matching verification item in
`stage1.md`, which tells the builder to expect `$OUT/lib/lib/libgtest.a` "also
present". **It will not exist**, and a builder following that line would
report a phantom defect.

## Carried to the build

- `lib/libgtest.a`, `lib/libgtest_main.a`, `lib/libgmock.a`, `lib/libgmock_main.a` — `llvm-objdump -f lib/libgtest.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). All four must be present.
- `$OUT/lib/lib/libgtest.a` must be **absent** — the legacy duplicate does not exist in 1.17.0, and its presence would mean a different googletest.
- `include/gtest/gtest.h`, `include/gmock/gmock.h` — `[ -f include/gtest/gtest.h ] && [ -f include/gmock/gmock.h ]`.
- `lib/pkgconfig/gtest.pc`, `lib/pkgconfig/gmock.pc` — `pkg-config --modversion gtest` → `1.17.0`, and `pkg-config --modversion gmock` → `1.17.0`.
- `lib/cmake/GTest/GTestConfig.cmake`, `GTestConfigVersion.cmake`, `GTestTargets.cmake` — `[ -f lib/cmake/GTest/GTestConfig.cmake ]`.
- No test or sample binary anywhere under `$OUT` — if one appears, `gtest_build_tests`/`gmock_build_tests` did not take.

## Rework verification

**Verdict: ACCEPT.** First line was already `ACCEPT`; left as `ACCEPT`.

### Correctly fixed

- **The phantom `lib/lib/` layout is gone from `stage1.md`, and the real
  layout replaced it.** `stage1.md:37-40` now reads "**There is no duplicate
  `lib/libgtest.a` layout in 1.17.0.** An earlier version of this file told the
  builder to expect one; that was wrong — `LIBRARY_OUTPUT_DIRECTORY` appears
  nowhere in googletest's CMakeLists. `$OUT/lib` holds four archives and no
  `lib/` subdirectory." Verified: `googletest/CMakeLists.txt:158`
  `install_project(gtest gtest_main)` and `googlemock/CMakeLists.txt:116`
  `install_project(gmock gmock_main)`; inside `install_project`
  (`cmake/internal_utils.cmake:299-333`) the single `install(TARGETS ${ARGN} ...)`
  at `:305-310` sends every target to a *single* `${CMAKE_INSTALL_LIBDIR}`.
  There is no second destination, so `$OUT/lib/lib/` cannot exist.
  **And the verification list was fixed too**: `stage1.md:54-61` no longer
  contains any `$OUT/lib/lib/libgtest.a` "also present" item — a builder
  following the current file will not report a defect that cannot happen.
- **I checked the supporting claim more carefully than the original review
  did, and it holds — but it needed a better reason than the one given.**
  `stage1.md:39` says `LIBRARY_OUTPUT_DIRECTORY` "appears nowhere in
  googletest's CMakeLists". That is true of the top-level and subproject
  `CMakeLists.txt` files, but it is *not* true of the tree:
  `googletest/cmake/internal_utils.cmake:173-175` does set
  `RUNTIME_OUTPUT_DIRECTORY`, `LIBRARY_OUTPUT_DIRECTORY` and
  `ARCHIVE_OUTPUT_DIRECTORY` — to `${CMAKE_BINARY_DIR}/bin` and
  `${CMAKE_BINARY_DIR}/lib`. Those are **build-tree** paths and affect
  nothing that `install()` does, so the conclusion is unaffected; but the
  sentence as written would not survive someone grepping the tree and finding
  the line. Worth tightening to "no *install* rule uses a second output
  directory". This is a wording nit in a file I cannot edit, not a defect in
  the recipe.
- **The recipe still does NOT pass `-DINSTALL_GTEST=OFF`, as required, and the
  warning is intact.** `generic.lua:12` passes only
  `-DBUILD_SHARED_LIBS=OFF -Dgtest_build_tests=OFF -Dgmock_build_tests=OFF`.
  Verified that this omission is load-bearing rather than stylistic:
 `googletest/CMakeLists.txt:20` declares
  `option(INSTALL_GTEST "..." ON)`, and *every* install rule is inside its
  guard — `googletest/CMakeLists.txt:90` `if (INSTALL_GTEST)` wraps the
  include install, the `install(EXPORT ...)` at `:96-100`, and the
  `Catch2`-equivalent config installs at `:102-106`;
  `googlemock/CMakeLists.txt:116` calls the same `install_project`, whose body
  opens `if(INSTALL_GTEST)` at `internal_utils.cmake:300` and closes it at
  `:333`. Passing `OFF` would install **nothing at all** — no headers, no
  archives, no `.pc`, no cmake config. The comment at `generic.lua:7-11`
  records exactly this and still says "do not pass"; it should be kept.
- **The other two switches are real options and both default OFF upstream**,
  so passing them explicitly is belt-and-braces rather than a change in
  behaviour: `googletest/CMakeLists.txt:18`
  `option(gtest_build_tests "Build all of gtest's own tests." OFF)` and
  `googlemock/CMakeLists.txt:11`
  `option(gmock_build_tests "Build all of Google Mock's own tests." OFF)`.
  `gtest_build_samples` also defaults OFF (`googletest/CMakeLists.txt:20`) and
  is never enabled, so no sample binary is built either.
- **Artifact list verified against the tree, not just accepted.** The four
  archives come from `install_project(gtest gtest_main)` +
  `install_project(gmock gmock_main)`, so `libgtest.a`, `libgtest_main.a`,
  `libgmock.a`, `libgmock_main.a` — matches `stage1.md:6`. The `.pc` files come
  from `internal_utils.cmake:325-332`, which `configure_file`s
  `${t}.pc.in` for each target and installs it into
  `${CMAKE_INSTALL_LIBDIR}/pkgconfig`; the four templates exist
  (`googletest/cmake/gtest.pc.in`, `gtest_main.pc.in`,
  `googlemock/cmake/gmock.pc.in`, `gmock_main.pc.in`), so **four** `.pc` files
  are installed, not two. `stage1.md:6` and `:58-59` name only `gtest.pc` and
  `gmock.pc`. That is incomplete rather than wrong — nothing false is claimed —
  but a builder looking for `libgtest_main.pc` should know it is expected.
  Module names resolve by file name (`gtest`, `gtest_main`, `gmock`,
  `gmock_main`) and `gtest.pc.in:5` carries `Version: @PROJECT_VERSION@`, so
  both `pkg-config --modversion` commands at `stage1.md:58-59` work.
  The cmake package dir is `lib/cmake/GTest`, from
  `googletest/CMakeLists.txt:87` `set(cmake_package_name GTest ...)` and `:94`
  `set(cmake_files_install_dir "${CMAKE_INSTALL_LIBDIR}/cmake/${cmake_package_name}")`,
  which matches `stage1.md:6`.
- Nothing else damaged. `generic.lua:13` is
  `cmake --build build --parallel 1` (serial), install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`, no `export` in the recipe, no
  hardcoded target fact, no `sed`/patch/`/dev/null`, and
  `require("googletest@source")` names a package that exists.
- `source.lua` is correct: `CMakeLists.txt:7` is
  `set(GOOGLETEST_VERSION 1.17.0)` in the unpacked tree, matching the pin; the
  tag archive URL answers 200; the tree lands in `$OUT/googletest/`.

### Still wrong, outside my scope

- **`generic.lua:10` still ends "(and the duplicate legacy `lib/` layout it
  controls is harmless)".** That is the clause this stage2 review said to
  delete, and the phantom layout it names does not exist in 1.17.0 — the
  `install_project` body has exactly one `install(TARGETS ...)`. The clause is
  wrong in the same way the old `stage1.md` line was. I am not editing
 `generic.lua`; drop the parenthetical.
- `stage1.md:11` cites `generic.lua:10` for the two test switches, which are
  on `generic.lua:12` after the comment grew. Line-number drift only.

The two things this rework was asked to confirm hold: the phantom layout is
 out of `stage1.md` and replaced with the verified real one, and the recipe
 still does not pass the flag that would install nothing.
