# lapack build forecast — **WILL NOT BUILD on any system here**

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.12.1 (`https://www.netlib.org/lapack/lapack-3.12.1.tar.gz`,
  8067105 bytes, matches the server's Content-Length). The GitHub project
  `Reference-LAPACK/lapack` tags v3.12.1 but publishes **no release assets**
  (`api.github.com/.../releases` shows an empty `assets` list for v3.12.1,
  v3.12.0, v3.11.0 and v3.10.1), so netlib is the only real tarball.
- Build system: **cmake only**. The tree ships **no** `configure`, no
  `configure.ac`, no `aclocal.m4`, no `config.h.in` and no `Makefile.in` —
  verified against a complete 6697-member extraction, not inferred from a
  failed grep. It does ship a hand-written `Makefile`, plus `BLAS/` (C),
  `CBLAS/` (C) and `SRC/` (**2038 Fortran `.f` files**).
- Config template: none.
- The decisive line is `CMakeLists.txt:313`.

## Verification of the tree these claims come from

6697 archive members, 6697 paths on disk, name-set diff zero missing and zero
extra. `CMakeLists.txt` is 26164 bytes and every line cited was read from the
file on disk. `/tmp` on this machine is a tmpfs with an exhausted user quota
that truncates writes silently while `df` still reports space free, so this
whole forecast was taken from a verified tree under `/home`.

## The blocker

**LAPACK's reference implementation unconditionally enables the Fortran
language, and this repo has no Fortran compiler for any target.**

`CMakeLists.txt:309-313`:

```cmake
if(NOT LATESTLAPACK_FOUND)
  message(STATUS "Using supplied NETLIB LAPACK implementation")
  set(LAPACK_LIBRARIES ${LAPACKLIB})

  enable_language(Fortran)
```

That `enable_language(Fortran)` is not inside any `if(CMAKE_Fortran_COMPILER)`
guard. That is not an oversight in the branch structure either — the
neighbouring branches *do* guard, which is what makes :313 clearly deliberate:
`:283-287` wraps its own `enable_language(Fortran)` in
`if(CMAKE_Fortran_COMPILER)` after `check_language(Fortran)`, and `:301-305`
has an `else()` that says in as many words "CMake couldn't find a Fortran
compiler, so it cannot check if the provided LAPACK library works" and then
optimistically sets `LATESTLAPACK_FOUND TRUE`. The reference path has no such
escape.

On top of that, `:320-330` compiles Fortran timing sources
(`second_${TIME_FUNC}.f`, `dsecnd_${TIME_FUNC}.f`) via `CheckTimeFunction`.

The three ways around it, and why each is closed:

- **Turn off the Fortran side.** Closed by `CMakeLists.txt:215-219`:
  `if(NOT (BUILD_SINGLE OR BUILD_DOUBLE OR BUILD_COMPLEX OR BUILD_COMPLEX16))`
  is a `FATAL_ERROR` ("Nothing to build, no precision selected"). Those four
  options are the Fortran LAPACK library; all four off means no library.
- **Supply an external LAPACK.** That is the `LATESTLAPACK_FOUND` path, and
  it is closed by the same missing Fortran compiler at `:286`, plus the fact
  that there is no LAPACK in this prefix to supply (see below).
- **Build only the C parts.** Not expressible: `:313` runs on the way to
  building anything, before `BLAS/` or `SRC/` is even reached.

And the compiler does not exist, on any of the six systems:

| check | result |
|---|---|
| systems exporting `$FC`, `$F77` or `$FLIBS` | **zero**, across all 58 system directories in `packages/*/generic.lua` |
| Fortran compiler in the NDK (`ndk/28.2.13676358`) | **none**; 181 tools in `toolchains/llvm/prebuilt/linux-x86_64/bin`, no gfortran/flang/f77 |
| Fortran compiler on this build host | **none**; `gfortran`, `flang`, `f77`, `g77` are all absent from `PATH` |

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | `CMakeLists.txt:313` calls `enable_language(Fortran)` unguarded in the reference-implementation branch, and cmake aborts there when it cannot find a Fortran compiler. The NDK ships none, and no system exports `$FC`. Unreachable at any API level — this is a toolchain fact, not a libc one. |
| aarch64-android24 | WILL NOT BUILD | As above. |
| aarch64-android35 | WILL NOT BUILD | As above. |
| x86_64-android35 | WILL NOT BUILD | As above. |
| x86_64-mingw | WILL NOT BUILD | As above. mingw-w64 ships gcc/g++, not a Fortran compiler, and no system exports `$FC`. |
| clang-native | WILL NOT BUILD | As above. clang-native exports `$CC` and `$CXX` but no `$FC`, and there is no gfortran or flang on the build host. |

**API level notes.** None apply. This is a toolchain blocker, not a libc one,
so it is identical at API 21, 24 and 35, and identical on mingw and native.
The API-21 walls, the 26/28/35 gates and `armv7a`/`i686` are all irrelevant
here: LAPACK never gets as far as compiling any C.

**Risks / what a reviewer should check.**

1. **This recipe is expected to fail, deliberately.** `generic.lua` carries a
   comment saying so and names the blocking line. It should be reviewed as a
   *forecast*, not built. `topackage.md:298` stays unchecked and should
   probably record the blocker in the same style as the other blocked entries
   (e.g. `:70` Pkgconf, `:20` Elfutils) — I was told not to edit that file.
2. **Do not let a builder "fix" this by pointing `$FC` at the host's gfortran.**
   There isn't one, and if one appeared it would produce a host x86-64 Fortran
   object in an aarch64 library. The only honest fixes are a real target
   Fortran compiler in a system file, or a C-only LAPACK from some other
   source.
3. **The version is slightly inconsistent upstream.** `CMakeLists.txt:5-7`
   reads `LAPACK_MINOR_VERSION 12` / `LAPACK_PATCH_VERSION 0` in the 3.12.1
   tarball, so upstream forgot to bump its own CMake version string. Irrelevant
   to the blocker, but worth knowing before anyone trusts
   `pkg-config --modversion lapack` as a 3.12.1 check.
4. **If a Fortran compiler is ever added to the systems, the recipe is not
   automatically correct.** The open questions are whether the f2c-converted
   LAPACK or the real Fortran sources are wanted, and whether `CBLAS` should be
   on (`option(CBLAS "Build CBLAS" OFF)` at `:259`, so the recipe turns it on
   explicitly). `LAPACKE` defaults OFF at `:344` and is only forced on at
   `:349-351` when `LAPACKE_WITH_TMG` is set — it is **not** forced by the
   reference-implementation branch, which is what a fast read of that region
   suggests. Also open: whether OpenBLAS from this same prefix should be
   handed over via `USE_OPTIMIZED_BLAS`/`USE_OPTIMIZED_LAPACK` instead.
   Those are design decisions for whoever revisits this, not something to
   settle now.

**What would have to become true to unblock it.** One of:

- a system file exporting a *target* Fortran compiler (`$FC`) for every system
  that needs it — this is a **system-level** addition, in the same spirit as
  the `ac_cv_func_ffsl` export AGENTS.md describes for the Android systems;
  or
- a decision to consume OpenBLAS's f2c-converted LAPACK (which *is* C, and
  which `openblas/generic.lua` here builds with `NOFORTRAN=1`) instead of
  building Reference-LAPACK at all. That is the cheaper path and is worth
  raising before anyone adds a Fortran compiler.