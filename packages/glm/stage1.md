# glm 1.0.3 — stage 1 build forecast

**Package:** glm
**Version:** 1.0.3
**Upstream:** https://github.com/g-truc/glm
**Build system:** CMake (header-only; the build exists only to run the install
rules)

This is a forecast from reading upstream source, not a measurement. Nothing
here has been compiled.

## What it installs

- `include/glm/` — the whole header tree, installed by
  `install(DIRECTORY glm DESTINATION include PATTERN CMakeLists.txt EXCLUDE)`
  (top-level `CMakeLists.txt:272-276`).
- `share/glm/glmConfig.cmake` and `share/glm/glmConfigVersion.cmake`, from
  `install(EXPORT glm NAMESPACE glm:: DESTINATION share/glm)`
  (`CMakeLists.txt:277-291`).
- No library file: the recipe passes `GLM_BUILD_LIBRARY=OFF`, so the `glm`
  target is an `INTERFACE` library (`glm/CMakeLists.txt:65-67`) rather than the
  one-empty-TU archive upstream builds by default (`glm/CMakeLists.txt:52-63`).
- **No pkg-config file.** Upstream ships none. CMake consumers use
  `find_package(glm)` and link `glm::glm`; everyone else adds
  `-I$PREFIX/include` and includes `<glm/glm.hpp>`.

## Dependencies

None. No `require()` of any other package. glm has no external dependency at
all, and because the recipe compiles nothing there is no pkg-config lookup to
satisfy.

## Source

`https://github.com/g-truc/glm/archive/refs/tags/1.0.3.tar.gz` — confirmed
HTTP 200. This is the git tag tarball, and it is the right source: the 1.0.3
release assets are `glm-1.0.3.7z` and `glm-1.0.3.zip` only, and there is no
`.tar.gz` asset, so the 7z would need a tool this tree does not assume.
Extracted top directory is `glm-1.0.3`, stripped by the recipe.

## Switches passed, and why

| Switch | Reason |
| --- | --- |
| `GLM_BUILD_LIBRARY=OFF` | Header-only library. Upstream's `ON` builds one `static` target from a single source file, `glm/detail/glm.cpp`, purely so IDEs have something to display. Compiling it would put an architecture check on a package that has no compiled content, which is exactly the check AGENTS.md says to avoid. |
| `GLM_BUILD_TESTS=OFF` | The `test/` tree is host programs. Already the upstream default (`CMakeLists.txt:25`); passed explicitly so the recipe says so rather than relying on a default. |
| `GLM_BUILD_INSTALL=ON` | Already the default for a top-level build (`CMakeLists.txt:26`, `GLM_IS_MASTER_PROJECT`); passed explicitly because the recipe's whole purpose is the install. |

No `android.lua`. There is no Android-only switch to pass: nothing is
compiled, so there is no target fact that could differ.

## Nothing is compiled

This is the load-bearing statement for this package. `GLM_BUILD_LIBRARY=OFF`
leaves only the `glm-header-only` and `glm` `INTERFACE` targets
(`glm/CMakeLists.txt:51`, `65-67`). `cmake --build` therefore has nothing to
build, and the install step only copies files. Consequences:

- The installed tree is byte-identical on every system.
- There is no architecture check to make and nothing that can differ between
  aarch64, armv7a, i686, x86_64, mingw and native.
- No `pkg-config --modversion glm` is possible, because no `.pc` ships.

`install(TARGETS glm-header-only glm EXPORT glm)` at `CMakeLists.txt:271` is the
one line worth watching: it installs an `INTERFACE` target with no destination,
which cmake supports. I confirmed against cmake 4.4.3 with a throwaway
`INTERFACE`-only project in `/tmp` that `install(TARGETS <interface> EXPORT ...)`
succeeds and writes the export file. That is a proxy check, not a glm build.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | Nothing is compiled. `cmake -S . -B build $CMAKE_FLAGS` reaches `install(DIRECTORY ...)`, a pure file copy. The API level is irrelevant. |
| `aarch64-android24` | WILL BUILD | As above. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above. |
| `x86_64-mingw` | WILL BUILD | As above. Note `install(EXPORT ...)` on an `INTERFACE` target carries no `.lib` import library and no `IMPORTED_LOCATION`, so there is nothing Windows-specific to break. |
| `clang-native` | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row:
the recipe contains no architecture-dependent step, so the API level is the
only variable in the family, and it changes nothing here.

## What a reviewer should scrutinise

1. **`install(TARGETS ...)` on an `INTERFACE` target with no destination.**
   `CMakeLists.txt:271` names both `glm-header-only` and `glm`, and with
   `GLM_BUILD_LIBRARY=OFF` both are `INTERFACE`. cmake allows installing an
   interface library with no `ARCHIVE`/`LIBRARY` destination; I verified that
   behaviour in isolation, but not with glm's own export set. If the install
   step fails, this line is where to look, and the fallback is to leave
   `GLM_BUILD_LIBRARY` at its default `ON` and accept a one-file
   `libglm.a`.
2. **`cmake_policy(VERSION 3.6...3.14)` at `CMakeLists.txt:4-5`.** glog-era
   policy pinning under cmake 4.x. I expect it to be fine — it sets policies
   *down* to 3.14, which cmake supports — but it is the kind of line that
   warns. What would settle it: the configure log from a real run.
3. **`share/glm` rather than `lib/cmake/glm`.** The package config lands
   outside the directories `find_package` searches by default, so a consumer
   may need `-Dglm_DIR=$PREFIX/share/glm` or `$PREFIX/share/glm` on
   `CMAKE_PREFIX_PATH`. This is upstream's layout, not a recipe choice, and it
   is the same shape toml11 already produces in this tree. Worth confirming
   against the first real consumer.
4. **C++ standard.** glm 1.0.3 needs C++17 or later. Nothing is compiled here,
   so this does not affect the install at all; it constrains *consumers*. The
   NDK wrappers default to `__cplusplus == 201703L` and mingw's g++ to
   `202002L` (both checked with `-dM -E`), so both are fine.
