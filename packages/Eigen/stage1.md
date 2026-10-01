# Eigen build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 5.0.1
- Build system: CMake (header-only; the build exists only to run the install
  rules and to generate `Eigen/Version`)
- Installs: the **entire** `Eigen/` header tree, the generated
  `Eigen/Version`, `eigen3.pc`, and a CMake package config under
  `lib/cmake/eigen3/`. No library file — the `eigen` target is `INTERFACE`.
- Requires: `Eigen@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled: `install(TARGETS eigen EXPORT Eigen3Targets)` (`CMakeLists.txt:241`) is an `INTERFACE` target. Everything that defaults ON at top level and is host-side is off: `EIGEN_BUILD_TESTING` (`:59`, defaults to CTest's `BUILD_TESTING`), `EIGEN_BUILD_DOC` (`:80`, doxygen), `EIGEN_BUILD_DEMOS` (`:82`), and `EIGEN_BUILD_BLAS`/`EIGEN_BUILD_LAPACK` (`:63-64`), which build the bundled Fortran/C linear-algebra helpers — a host build of someone else's BLAS, not a header library. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; no MSVC-specific path is taken with BLAS/LAPACK off. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is a file copy, identical on every
system, and **no architecture check applies**. Eigen's headers select SIMD at
*consumer compile time* by preprocessor, which is exactly why nothing here can
be wrong-architecture. `armv7a-android*` and `i686-android*` match
`aarch64-android*` — no step observes an API level.

**The header layout is the thing to get right, and upstream does it for us.**
This is the trap the brief flagged. `CMakeLists.txt:236` is
`install(DIRECTORY Eigen DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} COMPONENT
Devel)` — the whole tree, recursively, including `Eigen/src`,
`Eigen/unsupported`, `Eigen/lu`, `Eigen/Sparse` and the rest. A recipe that
copied only the top level would produce an install that looks complete and is
unusable, because nearly every public header includes into `Eigen/src`. The
recipe runs upstream's own install rules rather than copying by hand, and that
is the reason. `install(FILES .../include/Eigen/Version DESTINATION
include/Eigen/)` at `:238-239` then replaces the shipped `Version` header with
the generated one, which only happens if the build ran.

**API level notes.** None for the build. For *consumers*, the headers assume
only standard C++ and `<cmath>`/`<cstdlib>`; they do not reference a libc
symbol Eigen's own build must satisfy. So "header-only" really does mean no
target-libc assumption here — I checked for the usual suspects and found none.

**Risks / what a reviewer should check.**

1. **Both discovery mechanisms are deliberately kept ON.**
   `EIGEN_BUILD_PKGCONFIG` and `EIGEN_BUILD_CMAKE_PACKAGE` both default to
   `PROJECT_IS_TOP_LEVEL` (`:86`, `:88`), which is ON here, and the recipe
   passes `=ON` explicitly. So Eigen ships **both** a `.pc` and a CMake
   package config — worth recording because a header-only package with no
   `.pc` is the more common case (plog and range-v3 are the opposite).
2. **BLAS/LAPACK being off is a real scope decision, not a formality.** With
   `EIGEN_BUILD_BLAS=ON`, Eigen's cmake looks for a system BLAS and adds its
   bundled fallback; that fallback is a compiled C library, which contradicts
   a header-only install. Turning them off is what keeps the claim true.
3. **`EIGEN_BUILD_DOC` needs doxygen**, which is not in this prefix — that is
   part of why it is off, not just tidiness.
4. **The two benchmark suites** (`EIGEN_BUILD_BTL`, `EIGEN_BUILD_SPBENCH`,
   `:72-73`) already default OFF; passed explicitly so the intent is visible.
5. Eigen's version comes from **GitLab** (`gitlab.com/libeigen/eigen`), not
   GitHub: `eigen-mirror/eigen` carries only branch names as tags, so pinning
   from there would have produced `nightly`. Recorded in `source.lua`.

**How to verify once built.**

- `include/Eigen/Core` exists — **and so do** `include/Eigen/src/Core/util/`
  and `include/Eigen/unsupported/`. Checking only `Eigen/Core` is exactly the
  mistake the layout trap invites; the `src/` and `unsupported/` presence is
  the check that the recursive install happened.
- `include/Eigen/Version` exists and is the *generated* one
  (`grep -q EIGEN_WORLD_VERSION include/Eigen/Version`).
- `pkg-config --modversion eigen3` reports 5.0.1 — **note the module name is
  `eigen3`, not `eigen`.**
- `lib/cmake/eigen3/Eigen3Config.cmake` exists.
- **`find $OUT -name '*.a' -o -name '*.so'` must return nothing** — the single
  check that proves nothing was compiled and that BLAS/LAPACK stayed off.
- `find $OUT -name 'libblas*' -o -name 'liblapack*'` must also return nothing
  (risk 2).
- Compare two systems' `include/Eigen/` with `diff -r`: any difference is a
  bug.
