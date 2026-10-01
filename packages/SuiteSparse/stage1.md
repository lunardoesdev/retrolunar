# SuiteSparse 7.14.1 — build forecast

Source: `DrTimothyAldenDavis/SuiteSparse` tag `v7.14.1` (the project has left
the `scipy` org; every `scipy/suitesparse` URL and release feed now 404s).
Archive verified before reading: 100310686 bytes, `gzip -t` clean, 14131
entries; selective extraction recovered 65 of the archive's 65
`CMakeLists.txt` files, and the only zero-byte file in the extracted tree is
`CHOLMOD/Demo/Matrix/empty.tri`, which is test input data. All citations are
from that verified tree.

## BLAS: required, and absent from this prefix

`SuiteSparse_config/cmake_modules/SuiteSparseBLAS.cmake` ends in an
unconditional `find_package ( BLAS REQUIRED )` with no fallback, and
`SuiteSparseLAPACK.cmake` ends in `find_package ( LAPACK REQUIRED )`. The
root file names the affected projects exactly: `CMakeLists.txt:261-264` makes
BLAS mandatory for `cholmod` when `CHOLMOD_SUPERNODAL` is on, and for
`paru`, `spqr`, `umfpack`; `:265-267` then raises `FATAL_ERROR` if
`SUITESPARSE_REQUIRE_BLAS=OFF` while any of those is still enabled.
`CHOLMOD/CMakeLists.txt:291-298` includes both modules unless
`CHOLMOD_SUPERNODAL` is off.

Nothing usable provides that BLAS here today:

- `packages/openblas` exists (0.3.34, `NOFORTRAN=1 NO_SHARED=1`, would yield a
  static `libopenblas.a`) but the directory holds only `generic.lua` and
  `source.lua` — no `stage1.md`, `stage2.md` or `stage3.md`. Unreviewed,
  never built.
- `packages/lapack` exists but its `generic.lua` is a blocked placeholder:
  LAPACK 3.12.1 is CMake-only with 2038 Fortran sources, and its own text says
  "Do not attempt this build until a system provides one" (a Fortran
  compiler). It has **no `stage1.md`**, despite its comment saying
  "See stage1.md" — a dangling reference for whoever reviews that package
  (reported, not fixed: it belongs to the agent that owns it).
  No system in `packages/` exports `$FC`/`$F77` and the NDK has no Fortran.
- No BLAS- or LAPACK-shaped artifact exists in `nest/` for any system.

`topackage.md:295-296` still shows OpenBLAS and LAPACK unchecked, but that
file is a backlog, not an inventory — the two directories appeared without
it being ticked. The recipe therefore does **not** `require()` either.

## What the recipe targets

`SUITESPARSE_ENABLE_PROJECTS` (`CMakeLists.txt:36`, default `"all"`,
expanded at `:40-44` from `SUITESPARSE_ALL_PROJECTS` at `:26-27`) selects
13 of the 18 projects: the four orderings plus CHOLMOD, the standalone
solvers, and `SuiteSparse_config` (required for all of them by
`CMakeLists.txt:218-240`). Excluded, with reasons:

- `umfpack`, `spqr`, `paru` — BLAS, above.
- `lagraph` — `CMakeLists.txt:105-111` appends `graphblas` whenever
  `lagraph` is in the list. GraphBLAS is 6055 of the tarball's 14131 files,
  and upstream carries `GRAPHBLAS_BUILD_STATIC_LIBS` precisely to keep it out
  of a static build, its help string at `CMakeLists.txt:63-65` reading
  "building the library takes a long time". With `lagraph` out, nothing in
  the list depends on GraphBLAS.

CHOLMOD is included in its **simplicial** form only. `CHOLMOD_SUPERNODAL=OFF`
makes `CHOLMOD/CMakeLists.txt:293` add `-DNSUPERNODAL`, which is upstream's
documented no-BLAS configuration: `CHOLMOD/Doc/CHOLMOD_UserGuide.tex:306` and
`:310` say of BLAS and LAPACK "Not needed if -DNSUPERNODAL is used".

## What is *not* built

No executable of any kind. Demos are off upstream
(`SuiteSparsePolicy.cmake:175`, `SUITESPARSE_DEMOS` default OFF) and every
`add_executable` in the tree is inside an `if ( SUITESPARSE_DEMOS )` or
`if ( BUILD_TESTING )` guard — including the 30-odd `*_demo` programs and the
`readhb.f`/`reade.f` Fortran helpers, which is what makes the absent Fortran
compiler a non-issue. No `add_custom_command` in any selected subproject runs
a compiled program; the only live ones in the tree are commented out
(`Mongoose/CMakeLists.txt:509-520`). `SUITESPARSE_USE_CUDA` and
`SUITESPARSE_USE_FORTRAN` both default ON but are `check_language` probes
(`SuiteSparsePolicy.cmake:378`/`:383` and `:321`/`:324`) that find nothing.

## Verdict

| System family | Verdict | Why |
|---|---|---|
| aarch64-android21 | UNCERTAIN | C11 only, and the one timing dependency is handled: `SuiteSparse_config/CMakeLists.txt:85-96` probes `clock_gettime` and only reaches for librt if the first probe fails, which is the API-21 path. But I did not compile any of the 13 subprojects against the API-21 wrappers, so this is unverified. |
| aarch64-android24 | UNCERTAIN | Same code path. OpenMP is forced off in the recipe, so `SuiteSparse_config/CMakeLists.txt:50-56` is not a factor. |
| aarch64-android35 | UNCERTAIN | Same. This is the system I would build on first. |
| x86_64-android35 | UNCERTAIN | Same; no arch-specific code in the 13 selected projects. |
| x86_64-mingw | UNCERTAIN | Same C sources, but this is the one family where a `NOT WIN32` branch would bite, and I did not check the selected subprojects for mingw-specific paths. |
| clang-native | UNCERTAIN | Native build, no cross probes to defeat, but again unbuilt by me. |

UNCERTAIN across the board rather than WILL BUILD: the scoping above is read
directly out of the cmake files, but no part of this package has been
compiled, and the selected set is thirteen libraries rather than one.

## Serial / memory

Thirteen libraries, `cmake --build build --parallel 1`. The largest
selected project is CHOLMOD, an order of timing library of small C files;
GraphBLAS, the one component upstream flags as slow, is excluded. Nothing
here needs to fan out to build, so the 2 GB ceiling in `topackage.md:106-108`
is not the binding constraint here — the honest caveat is wall-clock time,
not peak memory.
