# openblas build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: **0.3.34** (newest release; `OpenBLAS-0.3.34.tar.gz` release
  asset, 25326686 bytes, matches the server's Content-Length exactly)
- Build system: **hand-written GNU make**, no autotools and no configure. The
  tree ships `Makefile`, `Makefile.system`, `Makefile.rule`, `Makefile.prebuild`,
  `Makefile.install` and a `CMakeLists.txt`. The recipe uses the makefiles,
  because the make path is the one upstream documents for Android.
- Config template: none. There is no `config.h.in`; the generated header is
  `config.h`, written at build time by appending to it
  (`Makefile.prebuild:100`).
- Installs: static `libopenblas.a`, the OpenBLAS headers, and `openblas.pc`
  (`Makefile.install:197-211` generates it, so no template edit is needed).
- Requires: `openblas@source` only. No dependencies.

## Verification of the tree these claims come from

12680 archive members, 12680 paths on disk, name-set diff zero missing and
zero extra. Every file cited below was confirmed non-zero. `/tmp` on this
machine is a tmpfs with an exhausted user quota that truncates writes
silently and that `df` does not report, so nothing here was read from `/tmp`
and every absence claim was re-taken from this verified tree.

## Does it build for aarch64 from a release tarball without patching? Yes.

Upstream documents the exact case in `docs/install.md:637`:

```
make HOSTCC=gcc CC=/opt/.../aarch64-linux-android31-clang ONLY_CBLAS=1 TARGET=ARMV8 RANLIB=echo
```

That is the whole answer: two overrides, no patch. The mechanism is visible
in the tree. `Makefile.system:320` shells out to `Makefile.prebuild` at parse
time, and `Makefile.prebuild:86-100` builds and then **executes**
`c_check`, `f_check`, `getarch` and `getarch_2nd`, redirecting their stdout
into `Makefile.conf` and `config.h`. So the build cannot be left to
autodetect; the makefile *wants* two overrides:

- `Makefile.system:102-103`: `HOSTCC` defaults to `$(CC)`. On a cross build
  that is the cross compiler, so `Makefile.prebuild:103-106` would build
  `getarch` as an aarch64 binary and `Makefile.prebuild:99` would then try to
  execute it here. **Passing `HOSTCC=` a build-machine compiler is mandatory,
  not an optimisation.**
- `Makefile.system:102-106`: `TARGET` adds `-DFORCE_$(TARGET) -DUSER_TARGET`,
  which is what makes `getarch` answer for the target instead of for the
  build CPU. Without it, an x86_64 build machine reports `x86_64` and the
  build compiles x86_64 hand-written assembly with the aarch64 compiler;
  `Makefile:194-195` turns that into
  `$(error OpenBLAS: Detecting CPU failed. Please set TARGET explicitly...)`.

`TARGET` is OpenBLAS's supported-microprocessor name, not a triplet: the
`TargetList.txt` names are `NEHALEM`, `HASWELL`, `ATOM`, `ARMV8`, `CORTEXA57`,
`CORTEXA73`, `ARMV8SVE`.

## What the makefile actually needs

1. **No Fortran compiler is required, and none exists here.** `f_check.pl:54`
   sets `$nofortran = 1` and defaults to gfortran when it finds none, and
   `Makefile:197-198` then reports "Can only compile BLAS and f2c-converted
   LAPACK". What is built is BLAS plus the f2c-converted LAPACK, both C. The
   recipe passes `NOFORTRAN=1` explicitly so the result does not depend on
   what happens to be in `PATH` on the build host. No system in `packages/`
   exports `$FC` or `$F77`, the NDK ships no Fortran compiler at all (181
   tools in `toolchains/llvm/prebuilt/linux-x86_64/bin`, none Fortran), and
   there is no gfortran or flang on this host.
2. **`HOSTCC` is the one thing no system provides.** This is the recipe's
   only unresolved dependency and the reason the verdicts below are UNCERTAIN
   rather than WILL BUILD. See risk 1.
3. **Build flags must be repeated on the install line.** `Makefile:132` says
   so in as many words, because `install` re-runs `Makefile.install` against
   the same configuration.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | UNCERTAIN | The recipe is right as far as the tree can prove it: `HOSTCC` keeps `getarch` native, `TARGET=ARMV8` forces the aarch64 kernels, `NOFORTRAN=1` drops the Fortran half. Two things keep this from being WILL BUILD. (a) `HOSTCC=cc` names a **build-machine** compiler that no retrolunar system exports and no rule derives — it happens to exist on this host (`/usr/bin/cc`), but that is an assumption, not a fact from `packages/`. (b) The adder may not build, so no one has watched `getarch` actually run. Nothing in the source suggests a Bionic problem: OpenBLAS's C core is plain C plus hand-written aarch64 assembly, and Android systems already carry `-lm`. |
| aarch64-android24 | UNCERTAIN | As above; representative system. |
| aarch64-android35 | UNCERTAIN | As above. |
| x86_64-android35 | UNCERTAIN | As above, plus the arch mapping to check: `HOST_ARCH=x86_64` selects `TARGET=HASWELL`. HASWELL hand-written assembly needs AVX2, which every x86-64 Android device of that era has, but it is a stronger floor than `ATOM` and the choice is a policy call the reviewer should confirm. |
| x86_64-mingw | UNCERTAIN | As above. Same `HOSTCC` problem, and additionally OpenBLAS ships no MinGW makefile path of its own — the upstream `quickbuild.win64` exists but the generic `Makefile` route has never been documented for mingw. |
| clang-native | UNCERTAIN | Different reason, and easier. Here `HOST_TRIPLET = BUILD_TRIPLET`, so the recipe passes **no** `TARGET` and `getarch` measures the real host CPU — correct, but it means the resulting library carries this build machine's CPU floor and is not reproducible. `HOSTCC=cc` is harmless (it is the same machine), though passing nothing would also work. |

**API level notes.** OpenBLAS's libc surface is `malloc`, `free`, `mmap`,
`munmap`, `pthread_*` and the math functions. All are API 21. Bionic folds
pthreads into libc, and the Android systems already carry `-lm`, which
OpenBLAS needs for `sqrt`/`pow`. None of the API-21 walls is reachable, and
neither are the 26/28/35 gates. `armv7a-android*` and `i686-android*` follow
the same rows as their x86/aarch64 counterparts — note `armv7a` maps to
`ARMV8` in the recipe, which is correct for the 64-bit-family kernels but
means an armv7a build gets an aarch64-tuned path; that combination should be
reviewed separately rather than inherited silently.

**Risks / what a reviewer should check.**

1. **`HOSTCC` is a build-machine fact that this repo does not model.** Every
   system in `packages/` sets `$CC` to a *target* compiler. There is no
   exported host compiler, so the recipe has to name one. This is the single
   thing standing between UNCERTAIN and WILL BUILD, and it is arguably a
   **system-level gap** (like `ac_cv_func_ffsl` in the Android systems)
   rather than a package defect: a `$HOSTCC` exported by every system would
   fix OpenBLAS and any future package that shells out to a host probe. I did
   not add it to the system files, because that is outside this package's
   scope — flagging it for the director instead.
2. **`TARGET` is a per-microprocessor choice, not a per-architecture one.**
   `ARMV8` for aarch64 is safe. `HASWELL` for x86_64 is a judgement call:
   OpenBLAS would happily build `NEHALEM` or `SANDYBRIDGE` with a lower floor.
   Nothing forces HASWELL.
3. **`ONLY_CBLAS=1` (what upstream's own Android line uses) is deliberately
   NOT used here.** It sets `NO_LAPACK=1` (`Makefile.system:269`), which drops
   the LAPACK part entirely and leaves only CBLAS. `NOFORTRAN=1` keeps more:
   BLAS plus the f2c-converted LAPACK. A reviewer who wants to match upstream's
   documented Android recipe exactly should say which of the two is wanted.
4. **`NO_SHARED=1`** is the repo's static-only policy (`Makefile.rule:118`).
   Without it OpenBLAS also builds a `.so` that no Android loader would find.
5. **The install step is the one most likely to be wrong**, because
   `Makefile:132` warns that build flags must be repeated and it is easy to
   drop `$OB_TARGET_ARGS` on the second line. If only the library lands and
   `openblas.pc` does not, look there first.
6. **Nothing in this build may execute a target binary.** If `HOSTCC` is
   wrong the failure is `Makefile.prebuild:99` trying to run an aarch64
   `getarch` — the exact no-emulation wall AGENTS.md describes. A builder who
   sees "permission denied" or "exec format error" at that point should stop
   and record it, not reach for an emulator.

**How to verify once built.**

- `lib/libopenblas.a` exists.
- `include/cblas.h` exists (OpenBLAS always installs it; there is no separate
  `cblas` package here).
- `pkg-config --modversion openblas` reports 0.3.34.
- `$OBJDUMP -f lib/libopenblas.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libopenblas.a | grep -cw dgemm_` — expected
  **non-zero**. `cblas.h` exists whether or not the kernels built, so it is
  not a sufficient check on its own.
- `llvm-nm --undefined-only lib/libopenblas.a | grep -cw pow` or `sqrt`
  non-zero is expected and is fine: Android systems put `-lm` in `LDFLAGS`, so
  the reference resolves at consumer link time.
- `grep -c '^ARCH=' $WORK/Makefile.conf` — the build log should show
  `ARCH=ARMV8` on aarch64. This is the check that proves `TARGET` actually
  took effect, and it is the single most valuable one to record.