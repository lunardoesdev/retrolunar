# plog build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.1.11 (git tag archive from `SergiusTheBest/plog` — the
  brief's `SergeyLutskan/plog` is a 404; `SergiusTheBest/plog` is the real
  repository and carries the 1.1.x tags)
- Build system: CMake
- Installs: `include/plog/`, a CMake package config under `lib/cmake/plog/`
  (`plogConfig.cmake` + `plogConfigVersion.cmake`), and `README.md` + `LICENSE`
  under the doc dir. **No library file, no pkg-config file** — upstream ships
  neither, and the `plog` target is an `INTERFACE` library
  (`CMakeLists.txt:24`).
- Requires: `plog@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled. `PLOG_BUILD_SAMPLES=OFF` removes the only default-ON host program (`samples/`, gated at `CMakeLists.txt:37`), and `PLOG_BUILD_TESTS` defaults OFF already (`:19`). `cmake --build` has nothing to do, so no target fact can leak in. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `INTERFACE` + `GENERATED` export sets are portable, and nothing is compiled. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled.** The install is a file copy, identical on every
system, and **no architecture check applies**. plog is a set of headers over
`std::ostream`; it has no compiled artifact that could be built for the wrong
target. `armv7a-android*` and `i686-android*` match `aarch64-android*` — the
recipe has no step that could observe an API level.

**API level notes.** None for the build. For *consumers*, the one thing worth
knowing is that plog's Android block is `target_link_libraries(plog INTERFACE
log)` (`CMakeLists.txt:32-34`), so a consumer on Android wants `-llog`.

**Risks / what a reviewer should check.**

1. **plog has the same `if(ANDROID)` trap as glog, but here it is provably
   metadata-only.** `CMakeLists.txt:32` is `if(ANDROID) target_link_libraries(
   ${PROJECT_NAME} INTERFACE log) endif()`. Our toolchain files keep
   `CMAKE_SYSTEM_NAME` as `Linux`, so the cmake `ANDROID` variable is never
   set and that line never fires. The effect would be confined to the exported
   `plogConfig.cmake`'s `INTERFACE_LINK_LIBRARIES` — there is no archive to
   differ, because an `INTERFACE` library compiles nothing. That is a stronger
   version of glog's argument (where the archives were byte-identical): here
   there is no build output at all to perturb. **I have deliberately not added
   an `android.lua` for it**; a reviewer should confirm on the first build that
   `lib/cmake/plog/plogConfig.cmake` has no `log` in its interface, and add
   `-DANDROID=ON` via `android.lua` only if a consumer turns out to need
   `-llog`.
2. **`cmake_minimum_required` is 3.27 for cmake ≥ 3.27 and 3.0 otherwise
   (`CMakeLists.txt:2` and `:4`).** The host has cmake 4.4.3, so 3.27 applies
   and is satisfied. Worth knowing because it is unusually new for a
   header-only library.
3. `PLOG_INSTALL=ON` is what runs the install rules at all; passed explicitly.

**How to verify once built.**

- `include/plog/Log.h` exists, and `include/plog/Init.h` / `Appender.h` /
  `Formatters.h` alongside it.
- `lib/cmake/plog/plogConfig.cmake` and `plogConfigVersion.cmake` exist.
- **No library file anywhere:** `find $OUT -name '*.a' -o -name '*.so'` must
  return nothing. That is the single check that proves nothing was compiled.
- `find $OUT -name '*.pc'` must also return nothing — plog ships no
  pkg-config file, and its absence should be recorded rather than assumed.
- `grep -c log lib/cmake/plog/plogConfig.cmake` should be 0 (risk 1).
- Compare two systems' `include/plog/` with `diff -r`: any difference is a bug.
