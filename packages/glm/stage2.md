ACCEPT

# glm 1.0.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`1.0.3` tree. I did not build anything.

## What the recipe does right

- `source.lua`: `1.0.3` is the newest tag (I re-queried: `1.0.3, 1.0.2, 1.0.1,
  1.0.0`). The recipe uses the git tag archive, which is the right call here
  because the 1.0.3 release assets are `glm-1.0.3.7z` and `glm-1.0.3.zip` only
  — there is no upstream `.tar.gz`, and a 7z would need a tool this tree does
  not assume. URL 200, top dir `glm-1.0.3/`. Guarded download, `curl -C -`
  resume, `rm -rf src`, `mkdir -p $OUT/glm`.
- `generic.lua` requires only `glm@source`. Nothing missing, no `@native` need.
- Every build-system flag comes from `$CMAKE_FLAGS`; the three `-D` values are
  package choices. No `export`, no hardcoded architecture/triplet/API level,
  no `-I`/`-L`, no `sed`, no patch, no `/dev/null`, serial build, install into
  `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `GLM_BUILD_LIBRARY=OFF` is correct and matters: with it off, `glm` becomes an
  `INTERFACE` library (`glm/CMakeLists.txt:65-68`) instead of the compiled
  archive, so nothing is compiled and the installed tree is identical on every
  system. `GLM_BUILD_TESTS=OFF` keeps the `test/` host programs out (already the
  default, `CMakeLists.txt:25`, passed explicitly so the recipe does not lean
  on a default). `GLM_BUILD_INSTALL=ON` is what makes the recipe exist.
- No `android.lua` is needed, and saying so is right: nothing is compiled, so no
  target fact can differ between aarch64, armv7a, i686, x86_64, mingw and
  native.
- `cmake_minimum_required(VERSION 3.6...3.14 FATAL_ERROR)` plus
  `cmake_policy(VERSION 3.6...3.14)` (`CMakeLists.txt:2-3`) — 3.6 is at/above
  cmake 4's floor, so `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is not strictly
  needed here, but relying on the system's is still the right discipline.
- `stage1.md` is honest. Its most valuable sentence is the one flagging its own
  weakest point: `install(TARGETS glm-header-only glm ... EXPORT glm)`
  (`CMakeLists.txt:271`) installs an `INTERFACE` target with no destination, and
  the author says plainly that they verified that behaviour "in isolation, but
  not with glm's own export set", and names the fallback
  (`GLM_BUILD_LIBRARY=ON`, accepting a one-file `libglm.a`) if the install
  step fails. That is exactly the right way to hand a forecast to a builder.

## Non-blocking observations (not a reject reason)

1. Both the recipe comment and `stage1.md` call `glm/detail/glm.cpp` "a single
   empty translation unit". It is not empty: it is 263 lines of explicit
   template instantiations of `vec<1, ...>`, `qua<...>`, `dualqua<...>` and
   `tdualquat<...>`. It is fair to call it pointless for a header-only library,
   but "empty" is the wrong word, and the file is the *only* `.cpp` under `glm/`
   — so with `GLM_BUILD_LIBRARY=ON` the archive contains that one object and
   nothing else. Worth tightening when the file is next edited; the decision to
   turn it off is right either way.
2. The package config lands in `share/glm/`, not `lib/cmake/glm/`
   (`CMakeLists.txt:277-291`), so a consumer needs `-Dglm_DIR=$PREFIX/share/glm`.
   That is upstream's layout. The loader's staging-path rewrite
   (`src/loader.lua:454-458`) does not cover `$OUT/share/glm/*.cmake` — but
   `install(EXPORT)` generates an `_IMPORT_PREFIX`-relative file with no baked
   `$OUT` in it, so nothing is actually broken. `stage1.md` item 3 says this
   correctly.
3. glm 1.0.3 requires C++17 or later from *consumers*. Nothing is compiled
   here, so the install is unaffected; the NDK wrappers default to
   `__cplusplus == 201703L` and mingw's g++ to `202002L`, so both are fine
   when a consumer appears.

## Carried to the build

Expected under `$NESTDIR/<sys>/`, identical on every system:

| Artifact | The one check that proves it |
| --- | --- |
| `include/glm/glm.hpp` | `[ -f include/glm/glm.hpp ]` |
| `include/glm/glm`, `include/glm/gtc/matrix_transform.hpp`, `include/glm/gtx/*.hpp` | `[ -f include/glm/glm/vec2.hpp ]` — the whole header tree is installed by `install(DIRECTORY glm ... PATTERN "CMakeLists.txt" EXCLUDE)`, so a spot check across `glm/`, `gtc/`, `gtx/`, `ext/`, `simd/`, `detail/` proves the copy was recursive |
| `share/glm/glmConfig.cmake` | `[ -f share/glm/glmConfig.cmake ]` — note the path, `share/glm`, not `lib/cmake/glm` |
| `share/glm/glmConfigVersion.cmake` | `[ -f share/glm/glmConfigVersion.cmake ]` |

**No library file and no pkg-config file, both correct.** glm ships no
`*.pc.in` and with `GLM_BUILD_LIBRARY=OFF` there is no `libglm.a`. A missing
`lib/libglm.a` and a missing `pkg-config --modversion glm` are the *expected*
outcome, not failures.

**There is no architecture to check** — nothing is compiled, so
`llvm-objdump -f` has nothing to point at. That is the point of the recipe, and
the builder should say so in the build record rather than hunting for an
artifact.

**If the install step fails**, the one line to look at is
`CMakeLists.txt:271` (`install(TARGETS glm-header-only glm EXPORT glm)` with
both targets `INTERFACE` and no `ARCHIVE`/`LIBRARY` destination). The
documented fallback is to drop `-DGLM_BUILD_LIBRARY=OFF` and accept a
one-file `libglm.a`.

Rerun should print `skip ... (fresh)`.
