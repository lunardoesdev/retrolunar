REJECT

# lapack 3.12.1 — stage 2 review

**This review is of a forecast, not of a buildable package.** LAPACK 3.12.1
cannot be built on any system in this tree, the recipe's build body will fail
if run, and the recipe is written as though it will not. That is the finding.

## Required changes

1. **The recipe ships a build body that will be executed, and it cannot
   succeed. It must not be queued for a builder.**

   `generic.lua:20-22`:

   ```sh
   cmake -S . -B build $CMAKE_FLAGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCBLAS=ON
   cmake --build build --parallel 1
   cmake --install build
   ```

   This is an ordinary, runnable recipe. `retrolunar install 'lapack@<sys>'`
   will queue it, the builder will run it, and `cmake -S . -B build` will abort
   at `CMakeLists.txt:313` with "No Fortran compiler found." The comment above
   it says "Do not attempt this build until a system provides one" — but a
   comment is not a guard. Nothing in the recipe stops the loader from
   queueing it, and nothing tells the builder at the point of execution that
   the failure is expected rather than a regression to be worked around.

   The brief asked whether the build body is "an honest blocked placeholder
   rather than something that pretends to build." **It is not honest: it
   pretends to build.** A placeholder that fails loudly and unavoidably, with a
   message a builder cannot mistake for a regression, is honest. This one is
   indistinguishable from a recipe that is expected to work.

   **Required — pick one, and make the recipe say which it is:**

   - **(a) Make it fail immediately and legibly.** Replace the three cmake
     lines with an explicit refusal that names the blocker:

     ```sh
     echo "lapack: BLOCKED — CMakeLists.txt:313 calls enable_language(Fortran)" >&2
     echo "lapack: with no guard; no system in packages/ exports \$FC and the" >&2
     echo "lapack: NDK ships no Fortran compiler. See stage1.md." >&2
     exit 1
     ```

     That still fails, but it fails in one line with a message that cannot be
     mistaken for a build regression, and it costs nothing to run.

   - **(b) Do not ship a build recipe at all.** Keep `source.lua` and
     `stage1.md` (the forecast is genuinely valuable — it is the record of
     *why* this is blocked and what would unblock it), and either remove
     `generic.lua` or leave it as the refusal in (a). A package directory with
     a source recipe and a stage1 but no build recipe cannot be queued at all,
     which is the cleanest expression of "blocked".

   Either is defensible. What is not defensible is the current state, where the
   recipe reads as buildable and the blocker lives only in a comment.

2. **stage1.md:88-92 tells the reviewer to decide something that is not the
   reviewer's to decide, and the "How to verify" section that follows it is
   unreachable.** stage1.md:91 says a reviewer should decide whether to
   attempt the build at all; but AGENTS.md:539-545 makes the builder the role
   that runs builds and commit failures, and this failure is not a build
   result — it is a toolchain fact. State the blocker as a system-level gap
   (a target `$FC` in the system files) in the stage1's own terms, and stop
   asking for a ruling.

## The blocker itself — verified, and the forecast's reading of it is correct

I checked the cited lines rather than accepting the citation.

**`CMakeLists.txt:313` is an unguarded `enable_language(Fortran)`:**

```cmake
309:if(NOT LATESTLAPACK_FOUND)
310:  message(STATUS "Using supplied NETLIB LAPACK implementation")
311:  set(LAPACK_LIBRARIES ${LAPACKLIB})
312:
313:  enable_language(Fortran)
```

**And the neighbouring branches *are* guarded, which is what makes :313 read as
deliberate rather than as an oversight in the branch structure:**

```cmake
283:  include(CheckLanguage)
284:  check_language(Fortran)
285:  if(CMAKE_Fortran_COMPILER)
286:    enable_language(Fortran)
...
301:  else()
302:    message(STATUS "--> CMake couldn't find a Fortran compiler, so it cannot check ...")
303:    set(LATESTLAPACK_FOUND TRUE)
```

That asymmetry is the whole argument, and it holds. The reference path has no
such escape.

**All three escape routes are closed, as claimed:**

- Turn off the Fortran side — `CMakeLists.txt:215-219` is
  `if(NOT (BUILD_SINGLE OR BUILD_DOUBLE OR BUILD_COMPLEX OR BUILD_COMPLEX16))`
  → `FATAL_ERROR("Nothing to build, no precision selected.")`. Verified.
- Supply an external LAPACK — that is the `LATESTLAPACK_FOUND` path, closed by
  the missing Fortran compiler at `:286`. Verified.
- Build only `BLAS/` and `CBLAS/` — not expressible: `:313` runs on the way to
  building anything.

**`SRC/` really is 2038 Fortran files:** `ls SRC/*.f | wc -l` → **2038**.
Confirmed.

**No Fortran compiler exists anywhere:**

- No system exports `$FC`, `$F77` or `$FLIBS` — `grep -rl 'FC=\|F77=\|FLIBS'
  packages/*/generic.lua` returns no system files (only two package dirs
  without a `generic.lua` produce errors, and two non-directory paths).
- No Fortran compiler on this build host: `which gfortran flang f77` finds
  none.
- The NDK ships none (181 tools in `toolchains/llvm/prebuilt/linux-x86_64/bin`,
  no Fortran).

So the **WILL NOT BUILD** verdict on all six systems is correct, and it is a
toolchain fact rather than an API-level one — identical at 21, 24 and 35,
identical on mingw and native. Correctly reasoned.

## What the recipe gets right

- **The flags it would use are real.** `BUILD_SHARED_LIBS` and `BUILD_TESTING`
  are standard; `CBLAS` is `option(CBLAS "Build CBLAS" OFF)` at `:259`, so
  passing `-DCBLAS=ON` is a deliberate choice stated in the comment. No
  invented options.
- **No config template, so no guard.** No `configure`, no `configure.ac`, no
  `aclocal.m4`, no `config.h.in` anywhere. The recipe has no autotools guard,
  correctly. The absence is evidenced in stage1.md:9-13 against a complete
  6697-member extraction rather than asserted.
- **The system.** All cmake flags via `$CMAKE_FLAGS`, `--parallel 1`, no
  fan-out, no exported search flags, no hardcoded target facts.
  `require("lapack@source")` only.
- **stage1.md:94-98 explicitly forbids the tempting wrong fix** — pointing `$FC`
  at a host gfortran, "if one appeared it would produce a host x86-64 Fortran
  object in an aarch64 library". That is exactly the reasoning AGENTS.md:636-640
  wants recorded, and it is right.
- **stage1.md:116-125 names what would actually unblock it**, and points at
  the cheaper path first: consume OpenBLAS's f2c-converted LAPACK (which *is* C,
  and which `packages/openblas` in this same tree already builds with
  `NOFORTRAN=1`) rather than building Reference-LAPACK at all. That is the
  right recommendation and it is the one a reviewer should act on.

## A note on `CMAKE_DISABLE_FIND_PACKAGE` style workarounds

For completeness, because someone will try: there is no cmake-level dodge
here. `enable_language(Fortran)` is a hard language request, not a
`find_package`, so `CMAKE_DISABLE_FIND_PACKAGE_*` does not apply, and
`-DCMAKE_Fortran_COMPILER=` pointing at nothing fails earlier. The only real
answers are the two in stage1.md:116-125.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL NOT BUILD | WILL NOT BUILD | yes |
| aarch64-android24 | WILL NOT BUILD | WILL NOT BUILD | yes |
| aarch64-android35 | WILL NOT BUILD | WILL NOT BUILD | yes |
| x86_64-android35 | WILL NOT BUILD | WILL NOT BUILD | yes |
| x86_64-mingw | WILL NOT BUILD | WILL NOT BUILD | yes |
| clang-native | WILL NOT BUILD | WILL NOT BUILD | yes |

Six for six, and these are six forecasts I can sign without reservation: the
blocker is a missing toolchain component, verified present-as-absent in three
independent places, and it is identical on every system. This is what a
correct blocked forecast looks like.

The disagreement is entirely about the **recipe**, not the forecast. The
forecast is the most useful artefact this package has produced; the recipe
undermines it by looking buildable.

## Verdict

REJECT — on the recipe, with the forecast explicitly endorsed. `CMakeLists.txt:313`
is unguarded where its neighbours are guarded, the three escape routes are
closed, `SRC/` is 2038 Fortran files, and no Fortran compiler exists for any
system: the WILL NOT BUILD on all six rows is correct and well evidenced. But
`generic.lua` ships three runnable cmake lines that will be queued, executed and
failed, with the blocker recorded only in a comment above them. A blocked
package should refuse legibly in one line, or ship no build recipe at all —
not present a build command that cannot work. That is the change.
