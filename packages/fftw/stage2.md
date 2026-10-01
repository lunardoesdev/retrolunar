REJECT

# fftw 3.3.11 — stage 2 review

Checked against the unpacked `fftw-3.3.11` tree in `$HOME/dl`.

## Required changes

1. **`generic.lua:22` — `touch aclocal.m4 configure config.h.in` is at column 0,
   outside the indented build body.**

   The whole file is a Lua long string, so this is only cosmetic in the source
   — but AGENTS.md:224-225's allowed verb list is `cp`, `./configure`, `cmake`,
   `make`, `touch`, `find`, `mkdir`, `cat`-heredocs, and the guard's `touch` is
   the only line not indented to match its neighbours. Every other recipe in
   this tree indents it. Fix the indentation.

   That is the trivial one. This is why the package is rejected:

2. **`generic.lua:18` — `--with-pic` is not an fftw option, and passing it is
   at best inert.**

   fftw's `configure.ac` has **no** `AC_ARG_WITH` and no `pic` reference at
   all:

   ```
   $ grep -n "AC_ARG_WITH" configure.ac      → no matches
   $ grep -n "pic" configure.ac              → only line 333, MPICC
   $ grep -n "PIC" config.h.in               → no matches
   $ ./configure --help | grep -i pic
     --enable-pic[=PKGS]  try to use only PIC/non-PIC objects [default=use
   ```

   `--with-pic` is a **libtool** option, and libtool's `LT_INIT` does accept it
   — `configure:10426` contains `# Check whether --with-pic was given` and
   parses it into `pic_mode`. So it is not an *unrecognised* option that would
   trigger autoconf's warning, and the build will not fail. But fftw never
   consults `pic_mode` for anything that matters here: the package is built
   `--disable-shared`, and fftw's own compile flags come from
   `FFTW_CFLAGS`/the config header, not from libtool's PIC mode.

   The net effect is that `--with-pic` is a **flag from a different build
   system**, passed to a package that does not use it, justified in the
   comment as making the static archive position-independent. Meanwhile
   **position independence is already guaranteed on every system in this tree
   by `$CFLAGS`**: all four Android families set `CFLAGS="-O2 -fPIC"`, as do
   `x86_64-mingw` and `clang-native` (the latter two via `-fPIC` in `$CFLAGS` /
   `CXXFLAGS`). Drop the flag and the archive is still PIC; keep it and the
   recipe carries a misleading claim about what makes the artifact
   position-independent.

   Per AGENTS.md:441 ("a nonexistent flag is worse than a missing one"), and
   per the brief's own framing, a flag that does not do what the comment says
   is the defect. **Required: remove `--with-pic`**, and correct
   stage1.md:96-98, which claims "`--with-pic` defaults to 'use PIC for both',
   so it is explicit rather than a change of behaviour" — the default is
   libtool's `pic_mode=default` and the sentence describes a mechanism fftw
   never consults.

3. **stage1.md:114-117 — a "Carried to the build" check that cannot match its
   target, and a miscount next to it.**

   ```
   $ grep -c 'HAVE_NEON\|HAVE_AVX2\|HAVE_SSE2' $WORK/config.h should be 0 nonzero defines
   $ ls $OUT/bin/ — expected to contain fftw3-wisdom only
   ```

   Two problems. First, `grep -c` on a pattern with three alternatives counts
   **matching lines**, and it returns **0 with exit status 1** when there are
   none — so a builder who runs it under `set -e` or reads the exit code gets a
   *failure* for a *passing* result. This is the inverted-assertion and
   masked-exit-status pair AGENTS.md:570-579 warns about. Second, and worse:
   `$WORK` is deleted by the block's `trap 'rm -rf "$WORK" "$OUT"' EXIT` on
   success (AGENTS.md:100-104, `:115`), so by the time a builder runs a
   post-build verification **`$WORK/config.h` does not exist** — `grep -c` on a
   missing file prints an error and returns 2. The check is unrunnable as
   written, and its 768-character rendering makes that easy to miss.

   The right place to check this is *inside* the build body, or against
   something that survives. Since the recipe cannot `export` a search flag but
   **may** `cat`/inspect under `$OUT`, the surviving artifact is the installed
   `include/fftw3.h` (which carries the same `HAVE_*` macros) — or simply
   drop the check and rely on the log line
   `configure: ... checking for SSE2 ... no`. **Required: replace it with a
   runnable check, or remove it.**

   `ls $OUT/bin/` is likewise unscoped in a way that matters: after a
   successful build `$OUT` is gone too. Scope to the package's own names.

## The claims that hold

Most of this forecast is careful and correct, and I want that on the record.

- **3.3.11 is current, and the tarball ships a generated `configure`.**
  `configure` is present and carries the autoconf 2.69 stamp. No `autoreconf`
  needed or wanted. Correct.
- **The config template is `config.h.in`, and the decoy is real.**
  `configure.ac:33` is `AM_CONFIG_HEADER(config.h)`, and the top-level
  `config.h.in` is 12,425 bytes against `cmake.config.h.in`'s 11,603. Both
  files exist, so the decoy genuinely is a live trap — and the guard names the
  right one. `touch aclocal.m4 configure config.h.in` +
  `find . -name 'Makefile.in' | xargs touch` is the correct guard, in the
  correct position (after `./configure`, before `make`). The `find .` sweep is
  also necessary here: `AC_CONFIG_FILES` (`configure.ac:798+`) lists **~60**
  generated `Makefile`s across the kernel/simd/dft/rdft subdirectories, so a
  top-level-only sweep would leave most of them live.
- **"No codelet-select machinery at all" — I searched six spellings and got
  zero files, from a verified-complete extraction:**
  ```
  codelet select : 0      codelet_select : 0      CODELOT_LIST : 0
  codelet-select : 0      mini_codelet   : 0      CODELOT_LIST : 0
  ```
  This is the claim the brief singled out as most in doubt, and it is
  **correct**. Older FFTW chose among pre-generated codelets by compiling and
  *running* a selector during the build; that machinery is simply not in
  3.3.11. Combined with every `--enable-<isa>` family defaulting to `no`
  (`configure.ac:119` sse2, `:138` avx2, `:192` neon, all
  `have_*=$enableval, have_*=no`) and `grep -c "AC_TRY_RUN\|AC_RUN_IFELSE"`
  returning **0 in both `configure.ac` and `configure`**, the conclusion holds:
  **passing no `--enable-*` flag is the correct cross answer, and nothing in the
  build executes a compiled program.** I checked this carefully because the
  binfmt_misc/qemu situation means a target binary would run *silently* rather
  than failing loudly.
- **`--disable-fortran` is mandatory.** `configure.ac:679` defaults
  `enable_fortran=yes` and the branch runs `AC_PROG_F77` (`:682`). No system in
  `packages/` exports `$FC` or `$F77`, and there is no gfortran or flang on
  this build host. Correct.
- **`--disable-doc` is mandatory.** `Makefile.am:36-43` blanks `DOCDIR` and
  drops `doc/` from `SUBDIRS` when `BUILD_DOC` is false
  (`configure.ac:54`), and `doc/Makefile.am:3` is `info_TEXINFOS = fftw3.texi`,
  which automake builds through `makeinfo`. Texinfo is blocked in this tree.
  Correct.
- **Threads left off is a real decision, correctly reasoned** — `--enable-threads`
  (`configure.ac:731`) drives `ACX_PTHREAD`, which on a cross build cannot find
  a separate pthreads library and can leave a `-lpthread` no Android sysroot
  satisfies. Correct, and the same wall the ISA-L entry records.

## What installs

`lib/libfftw3.a`, the `fftw3.h` family, `fftw3.pc` (`Makefile.am:166-169`), the
FFTW3 CMake package config (`Makefile.am:171-181`), plus `bin/fftw3-wisdom` and
its man page (`tools/Makefile.am:3`, `bin_PROGRAMS`). The two programs
`make -j1` compiles are `tests/bench` (`noinst_PROGRAMS`, not installed) and
`fftw3-wisdom` (installed, never executed here) — both target binaries, which
is allowed. `mpi/` is inside `if MPI` with `--enable-mpi` defaulting off
(`configure.ac:322`), and `genfft` is inside `if MAINTAINER_MODE`
(`Makefile.am:8`, `AM_MAINTAINER_MODE` at `configure.ac:34`), so neither is
built. No host program runs. Clean.

## The system

`./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared
--disable-fortran --disable-doc`, then `make -j1`, `make install`. `--host`,
`--build` and `--prefix` all from the system. No hardcoded target facts, no
exported search flags, no `android.lua` (nothing Android-specific).
`require("fftw@source")` only, correct — no dependencies. Everything else about
the system question is clean; the `--with-pic` flag is the one place a
non-system flag crept in without doing anything.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six on the substance. The build will very likely succeed; a scalar
`libfftw3.a` over `malloc`/`free`/`memcpy` plus `clock_gettime`,
`getpagesize`, `posix_memalign` and the `sin`/`cos` family
(`configure.ac:604`, all API 21) reaches none of the documented walls, and
`--disable-fortran --disable-doc` remove the two features that need tools this
prefix lacks. **I keep these six** — the forecasts are right. The REJECT is
for the recipe defects above, not for the per-system analysis.

## Verdict

REJECT, on two recipe defects and one unrunnable check rather than on any
system verdict. `--with-pic` is a libtool option fftw never consults, passed
with a comment claiming it makes the archive position-independent when
`$CFLAGS` already guarantees that on every system here — a flag that does not
do what the recipe says is exactly the failure mode AGENTS.md:441 describes.
The guard's `touch` is misindented. And the `grep -c … $WORK/config.h` check
cannot run at all, because `$WORK` is removed on success, while its `grep -c`
would return exit 1 for the passing case even if it could. The forecast's
substance — including the codelet-select absence claim I was asked to distrust
— is correct and should be preserved.
