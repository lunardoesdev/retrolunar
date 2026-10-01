ACCEPT

# Eigen 5.0.1 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

This is the cleanest package in the batch. Every line citation is exact,
the two discovery mechanisms are handled correctly, the version is current,
and the one thing the brief flagged as a consumer-only trap — the pkg-config
module name — is right. Nothing to change.

## Question 1 — is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS …`, `cmake --build build --parallel 1`,
`cmake --install build`. No hardcoded target fact, no `export` of search
flags, no per-target recipe. `require("Eigen@source")` resolves and the tree
lands in `$OUT/Eigen/`. Correct.

## Question 2 — is it doing what Eigen needs?

All line citations checked in the unpacked tree
(`gitlab.com/libeigen/eigen`, tag 5.0.1, top dir `eigen-5.0.1`):

| claim | file:line | verdict |
|---|---|---|
| `EIGEN_BUILD_TESTING`, defaults to CTest's `BUILD_TESTING` | `:59`, over `cmake_dependent_option(BUILD_TESTING … ON "PROJECT_IS_TOP_LEVEL" OFF)` at `:58` | confirmed — and ON here, since Eigen is top-level |
| `EIGEN_BUILD_BLAS` / `EIGEN_BUILD_LAPACK`, default `PROJECT_IS_TOP_LEVEL` | `:63`, `:64` | confirmed, both ON by default |
| `EIGEN_BUILD_BTL` / `EIGEN_BUILD_SPBENCH`, default OFF | `:72`, `:73` | confirmed |
| `EIGEN_BUILD_DOC` | `:80` | confirmed, ON by default (`:78`) |
| `EIGEN_BUILD_DEMOS`, default `PROJECT_IS_TOP_LEVEL` | `:82` | confirmed, ON by default |
| `EIGEN_BUILD_PKGCONFIG`, default `PROJECT_IS_TOP_LEVEL` | `:86` | confirmed |
| `EIGEN_BUILD_CMAKE_PACKAGE`, default `PROJECT_IS_TOP_LEVEL` | `:88` | confirmed |
| `eigen` is an `INTERFACE` target | `:208` `add_library (eigen INTERFACE)` | confirmed |
| `install(DIRECTORY Eigen DESTINATION …)` — whole tree | `:236` | confirmed |
| generated `Eigen/Version` replaces the shipped one | `:238-239` | confirmed |
| `install(TARGETS eigen EXPORT Eigen3Targets)` | `:241` | confirmed |

**All nine options passed genuinely exist.** None is a phantom switch. The
recipe passes them with the defaults' own polarity, which is the right
choice here: everything host-side is off and both discovery mechanisms are
on.

The header-layout trap the brief flagged is handled the right way — by
running upstream's `install(DIRECTORY …)` at `:236` rather than copying
headers by hand, so `Eigen/src`, `Eigen/unsupported` and the rest all land.
The recipe comment says exactly that, and it is right.

The BLAS/LAPACK decision (risk 2) is a real scope decision rather than a
formality, as claimed: `:726`/`:730` are the `add_subdirectory` calls for
the bundled Fortran/C helpers, and leaving them on would contradict the
header-only claim by installing compiled libraries. Off is correct.

## The pkg-config module name — `eigen3`, not `eigen`

**Verified precisely, as asked.** The template is `eigen3.pc.in` at the
top level of the tarball, and it is configured to `eigen3.pc` at `:233`:

```cmake
if(EIGEN_BUILD_PKGCONFIG)
    configure_file(eigen3.pc.in eigen3.pc @ONLY)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/eigen3.pc
        DESTINATION ${PKGCONFIG_INSTALL_DIR})
endif()
```

pkg-config derives the module name from the *file name*, so the module is
`eigen3` and `pkg-config --modversion eigen3` is the correct invocation.
`pkg-config --modversion eigen` would fail. The adder got this right and
flagged it in `stage1.md:72-73`; a consumer would otherwise have found it
the hard way.

The `Version:` field is also sound, and worth confirming since a recipe
could easily ship an empty one: the template has `Version:
@EIGEN_VERSION_NUMBER@`, and `:140-142` builds that from
`EIGEN_MAJOR/MINOR/PATCH_VERSION`, which `:101-115` parses out of the
shipped `Eigen/Version` header. That header reads
`5 / 0 / 1` and `EIGEN_VERSION_STRING "5.0.1"`, so the `.pc` will report
5.0.1.

The `Cflags:` field is `-I${prefix}/@INCLUDE_INSTALL_DIR@`, with
`INCLUDE_INSTALL_DIR` resolved at `:174-181` — the only mildly fiddly part
of Eigen's install logic, and it is handled upstream.

## Source, version, upstream identity

- The URL resolves (`gitlab.com/libeigen/eigen/-/archive/5.0.1/…`, 200).
- **5.0.1 is the current release.** GitLab's tag API for
  `libeigen/eigen` returns, newest first: `5.0.1`, `nightly`, `3.4.1`,
  `5.0.0`, `3.4.0`, … So 5.0.1 is the newest non-`nightly` tag, and pinning
  it is current. (`nightly` is a moving branch, not a release; the recipe is
  right not to pin it — and pinning from `eigen-mirror/eigen` would indeed
  have produced exactly that, since that mirror's "tags" are branch names.
  The `source.lua:1-2` comment records this, which is the right place.)
- `git clone` is not used; a tarball is, and the GitLab archive tarball is
  complete (no submodules needed for an install-only build). Correct choice.
- The tree lands in `$OUT/Eigen/` with `--strip-components=1` over a
  single top directory. Correct.

## The forecast

Six WILL BUILD rows, each citing that nothing is compiled because
`install(TARGETS eigen …)` is an `INTERFACE` target. I checked that the
build really is compile-free rather than taking it on citation: with
`EIGEN_BUILD_TESTING`, `_DOC`, `_DEMOS`, `_BLAS` and `_LAPACK` all OFF and
`_BTL`/`_SPBENCH` already OFF, the `if` at `:90` that sets
`EIGEN_IS_BUILDING_` is false, and the only unconditional commands in the
file are `file(READ …)`, `configure_file` and `install` — there is no
unconditional `add_executable` or `add_custom_target` that builds anything
(the one `add_custom_target` at `:273` is inside the `uninstall` target).
`cmake --build` is a no-op. So the uniform WILL BUILD is earned, for the
same structural reason as plog's: every target is `INTERFACE` and every
compile switch is off.

"API level notes: none" is credible and the positive form is the right one —
Eigen's headers select SIMD at *consumer* compile time by preprocessor, so
there is no target-libc assumption baked into the install, and no step in the
recipe can observe an API level. Nothing in `include/` is touched by the
build at all except the generated `Version` header, which is version
metadata. `armv7a-*` and `i686-*` match the `aarch64-*` rows for the same
reason.

Both discovery mechanisms being deliberately ON is recorded, which is the
right instinct: a header-only package that ships only a `.pc`, or only a
CMake config, is a package half its consumers cannot find. Eigen ships both
and the recipe keeps both.

## Carried to the build

- `include/Eigen/Core` exists — **and so do** `include/Eigen/src/Core/util/`
  and `include/Eigen/unsupported/`. Checking only `Eigen/Core` is the exact
  mistake the layout trap invites; the `src/` and `unsupported/` presence is
  what proves the recursive `install(DIRECTORY …)` at `:236` ran. This is
  scoped to paths Eigen itself owns, so it cannot pass vacuously.
- `include/Eigen/Version` exists and is the *generated* one:
  `grep -q EIGEN_WORLD_VERSION include/Eigen/Version` (the shipped header
  also has that define, so pair it with the `:238` fact that the installed
  one is the cmake-generated copy).
- **`pkg-config --modversion eigen3` reports 5.0.1.** Note the module name
  is `eigen3`; `pkg-config --modversion eigen` failing is expected, not a
  defect. State this in `stage3.md` so the next reader does not file it.
- `lib/cmake/eigen3/Eigen3Config.cmake` exists (`:243-250`,
  `CMAKEPACKAGE_INSTALL_DIR` at `:183`).
- `find $OUT -name '*.a' -o -name '*.so'` returns nothing — the single check
  that proves nothing was compiled and that BLAS/LAPACK stayed off. Scoped
  to `$OUT`.
- `find $OUT -name 'libblas*' -o -name 'liblapack*'` returns nothing.
- Compare two systems' `include/Eigen/` with `diff -r`: any difference is a
  bug, since the install should be byte-identical everywhere.
