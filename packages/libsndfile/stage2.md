REJECT

# libsndfile review (stage1: 1.2.2, `libsndfile-1.2.2.tar.xz`)

## What the recipe gets right

- **Config template verified against the tree.**
  `find libsndfile-1.2.2 -name '*.h.in'` returns exactly one file,
  `src/config.h.in`. `configure.ac:31` reads
  `AC_CONFIG_HEADERS([src/config.h])`. `generic.lua:34` names that path. The
  `src/` spelling is a real trap and the recipe avoids it.
- **Guard position is correct**: `./configure` at `:29`, guard at `:34-35`,
  `make` at `:36`.
- **System usage is clean** — only `$AUTOCONF_CONFIGURE_FLAGS`; no `export` of
  `CPPFLAGS`/`LDFLAGS`/`PKG_CONFIG_*`; `--disable-alsa` is justified by a
  platform fact in a comment, not a hardcoded target triple.
- **The five-codec claim is CORRECT and I verified it at the source.**
  `configure.ac:297-318` probes, in order:

  | module | floor | line |
  | --- | --- | --- |
  | `flac` | `>= 1.3.1` | :297 |
  | `ogg` | `>= 1.3.0` | :302 |
  | `vorbis` | `>= 1.2.3` | :314 |
  | `vorbisenc` | `>= 1.2.3` | :315 |
  | `opus` | `>= 1.1` | :317 |

  and `:321` gates on the exact five-way string:
  ```m4
  AS_IF([test "x$ac_cv_flac$ac_cv_ogg$ac_cv_vorbis$ac_cv_vorbisenc$ac_cv_opus" = "xyesyesyesyesyes"], [
          HAVE_EXTERNAL_XIPH_LIBS=1 ... ], [ ... enable_external_libs=no ])
  ```
  So it is five, all-or-nothing, exactly as asserted.
- **The decision not to pass `--disable-external-libs` is correct**, and the
  mechanism matters: `--disable-external-libs` is documented as
  `[[default=no]]` (`configure.ac:157`) but is *not* the default. `configure.ac:293-296`
  branches on `test "x$enable_external_libs" = "xno"` — with the flag absent,
  `enable_external_libs` is unset, the `no` branch is skipped, and the probes
  run. Passing `--disable-external-libs` would have taken the `:294` branch,
  printed `*** External libs (FLAC, Ogg, Vorbis) disabled. ***`, set
  `HAVE_EXTERNAL_XIPH_LIBS` to nothing, and compiled **every codec out** —
  exactly the silent downgrade the adder predicted. The recipe leaves all
  five enabled. Right call, right reasoning.
- **All five `.pc` files will exist.** I checked the real upstream
  `Makefile.am` files rather than trusting the stage1 summary:
  `flac-1.5.0/src/libFLAC/Makefile.am:52-53` →
  `pkgconfig_DATA = flac.pc`; `libvorbis-1.3.7/Makefile.am:16-17` →
  `pkgconfig_DATA = vorbis.pc vorbisenc.pc vorbisfile.pc` (unconditional, so
  `--disable-examples`/`--disable-docs` in `packages/libvorbis` cannot remove
  it); `libogg-1.3.5/Makefile.am:13-14` → `pkgconfig_DATA = ogg.pc`.
  Versions 1.5.0 / 1.3.7 / 1.3.5 all clear their floors.
- **`--disable-mpeg`, `--disable-alsa`, `--disable-sqlite` all exist.**
  `configure.ac:160`, `:154`, `:151`.
- **`require()`s resolve**: `libogg`, `libvorbis`, `flac`, `opus` all exist.

## Android API level: inert, and tested

Sweeping `src/*.c` for the gap list: the only hit is `O_BINARY` at
`src/file_io.c:583,588,593`, and `file_io.c:73-74` is
```c
#ifndef O_BINARY
#define O_BINARY 0
#endif
```
so it compiles to `0` on Bionic — it is a Windows-only concern guarded by
upstream's own fallback. No `nl_langinfo`, no `mktime_z`, no `iconv`,
no `posix_spawn`. **The API level really is inert for libsndfile.** The
stage1 claim about `src/GSM.c` doing its own ISO-8601 and `src/charset.c`
doing its own conversion both check out: `nl_langinfo` and `iconv` appear
nowhere in `src/`.

---

## Required changes

### 1. `packages/libsndfile/generic.lua:30` — `x86_64-mingw` cannot build this package. Add `--disable-full-suite`, and correct the comment that claims otherwise.

**This is the defect. The `x86_64-mingw` WILL BUILD row is wrong.**

`Makefile.am:432` opens `if FULL_SUITE`, and `Makefile.am:489-492` sits inside
it:

```make
bin_PROGRAMS = programs/sndfile-info programs/sndfile-play programs/sndfile-convert programs/sndfile-cmp \
	programs/sndfile-metadata-set programs/sndfile-metadata-get programs/sndfile-interleave \
	programs/sndfile-deinterleave programs/sndfile-concat programs/sndfile-salvage
endif
```

`FULL_SUITE` comes from `configure.ac:163-165`:

```m4
AC_ARG_ENABLE([full-suite],
	[AS_HELP_STRING([--disable-full-suite], [disable building and installing programs, documentation, only build library [[default=no]])])
AM_CONDITIONAL(FULL_SUITE, test "x$enable_full_suite" != "xno")
```

Same shape as `--disable-external-libs`: the help text says `default=no`, but
with the flag **absent** `enable_full_suite` is unset, `test "x" != "xno"` is
**true**, and `FULL_SUITE` is **ON**. So plain `make` builds and
`make install` installs **ten target executables**.

`programs/sndfile-play.c:41-44`:
```c
#if HAVE_UNISTD_H
#include <unistd.h>
#else
#include "sf_unistd.h"
#endif
```
and `programs/sndfile-play.c:60-73` then selects an audio backend. On mingw,
`HAVE_UNISTD_H` is 1 (mingw-w64 ships `/usr/x86_64-w64-mingw32/include/unistd.h`
— verified present), so the `sf_unistd.h` branch that back-fills the missing
POSIX macros is skipped, and the backend chain reaches
`#elif (OS_IS_WIN32 == 1) → <windows.h> + <mmsystem.h>`.

The hard stop is in the library itself, not the program. `src/file_io.c:499`:

```c
if (S_ISFIFO (statbuf.st_mode) || S_ISSOCK (statbuf.st_mode))
```

`S_ISSOCK` is a glibc/BSD macro. **mingw-w64's headers do not define it.** I
probed it directly:

```
$ cat sock.c
#include <sys/stat.h>
#include <sys/types.h>
#ifndef S_ISSOCK
#error S_ISSOCK_NOT_DEFINED
#endif
...
mingw          sys/stat.h: error: #error S_ISSOCK_NOT_DEFINED
native         sys/stat.h: S_ISSOCK present
aarch64-api21  sys/stat.h: S_ISSOCK present
aarch64-api35  sys/stat.h: S_ISSOCK present
```

and it is a hard error, not a warning, on the toolchain this system names:

```
$ x86_64-w64-mingw32-gcc -O2 -c sock2.c -o o.o        # GCC 16.2.0
sock2.c:3:43: error: implicit declaration of function 'S_ISSOCK' [-Wimplicit-function-declaration]
exit=1
```

`S_ISSOCK` appears exactly once in the whole tree (`src/file_io.c:499`) and is
defined nowhere — not in `src/sfconfig.h`, not in `src/sf_unistd.h` (which
back-fills `S_ISFIFO` and `S_ISREG` but **not** `S_ISSOCK`), not in
`config.h.in`. And `src/file_io.c` is unconditionally in the library:
`Makefile.am:81` → `src_libcommon_la_SOURCES = src/common.c src/file_io.c ...`.

So: **`x86_64-mingw` fails to compile `libsndfile.a`.** Android and
`clang-native` both have `S_ISSOCK` and are fine, which is exactly why the
uniform-42 optimism survived — this only bites on one system, and it is the
one the assignment said to distrust most.

**The fix, and why it is the fix:** `--disable-full-suite` does *not* fix this.
The library still compiles `file_io.c`. This is an upstream defect on
mingw-w64 with GCC ≥ 14 (which made implicit function declarations an error by
default; older GCC only warned and the archive linked with a PLT call that
would never be reached). **AGENTS.md forbids patching upstream, so the recipe
cannot fix it.** Therefore:

- **`packages/libsndfile/stage1.md`** — the `x86_64-mingw` row must change from
  **WILL BUILD** to **WILL NOT BUILD**, citing `src/file_io.c:499`, the
  mingw header probe result above, and `Makefile.am:81`.
- **`packages/libsndfile/generic.lua:25-28`** — the comment block claiming
  *"The test programs are check_PROGRAMS (Makefile.am:87 and onwards), not
  bin_PROGRAMS, so plain `make` does not build them and no switch is needed"*
  is **factually wrong and must be corrected**. It is right about the
  `check_PROGRAMS` at `:87` but wrong about the consequence: `bin_PROGRAMS`
  at `:489` *is* built by plain `make` and *is* installed, and the switch that
  turns it off is `--disable-full-suite` (`configure.ac:163-165`), which the
  recipe does not pass. Replace it with a comment that says: the ten
  `bin_PROGRAMS` at `Makefile.am:489` are gated by `AM_CONDITIONAL(FULL_SUITE)`
  from `configure.ac:165`, whose test is `!= "xno"` and therefore **true by
  default** despite the `[[default=no]]` help text; they are target
  executables, built and installed but never run here, same as `flac`'s
  `flac`/`metaflac`.
- **Recommended, and it removes the ten binaries from every system**: pass
  `--disable-full-suite` on the `./configure` line at
  `packages/libsndfile/generic.lua:29-30`. It is a real, existing option, it
  gates exactly the `bin_PROGRAMS` and `dist_man_MANS` blocks, and this is a
  library package. Note plainly that **this does not fix the `S_ISSOCK`
  failure** — the builder still needs to record that as a system-level
  blocker in `stage3.md` per AGENTS.md:549.

### 2. `packages/libsndfile/stage1.md` — the install list is incomplete in a way that will mislead.

`stage1.md`'s "Installs:" line lists only `lib/libsndfile.a`,
`include/sndfile.h`, `lib/pkgconfig/sndfile.pc`. In fact `Makefile.am:489`
installs **ten** executables into `bin/` (see change 1), and `Makefile.am:65`
installs `include/sndfile.hh` as well as `sndfile.h`. List the binaries, or
state explicitly that `--disable-full-suite` is being used to drop them.

---

## Android rows: correct

All four Android rows and `clang-native` are WILL BUILD, and I agree.
`configure.ac:153-154` makes ALSA `auto`; `--disable-alsa` is a real option
and NDK has no `alsa/asoundlib.h`. `--disable-sqlite` is real and there is no
sqlite package. `O_BINARY` self-defaults to 0. The five codec probes are pure
`PKG_CHECK_MOD_VERSION` calls against the prefix and resolve identically on
every system.

## Carried to the build

`clang-native` is the system to build this on. Artifacts under `$PREFIX`:

| artifact | source of truth |
| --- | --- |
| `lib/libsndfile.a` | `Makefile.am:64` `lib_LTLIBRARIES = src/libsndfile.la` |
| `include/sndfile.h`, `include/sndfile.hh` | `Makefile.am:65` |
| `lib/pkgconfig/sndfile.pc` | `Makefile.am:30` |
| `bin/sndfile-{info,play,convert,cmp,metadata-set,metadata-get,interleave,deinterleave,concat,salvage}` | `Makefile.am:489-492` — absent if `--disable-full-suite` is added |

### The ONE command that proves each

```sh
# the archive exists, is the right format, and holds the library
test -f "$PREFIX/lib/libsndfile.a" &&
llvm-objdump -f "$PREFIX/lib/libsndfile.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libsndfile.a" | grep -c sf_open
```
Expected: correct object format, non-zero count.

```sh
# THE ALL-OR-NOTHING CHECK. This is the one that matters for this package.
grep -E '^(Requires|Requires\.private):' "$PREFIX/lib/pkgconfig/sndfile.pc"
```
`configure.ac:326` sets
`EXTERNAL_XIPH_REQUIRE="flac ogg vorbis vorbisenc opus"` and only inside the
all-five-yes branch; `sndfile.pc.in:8` renders it as `Requires.private:`. So
expected: a line naming **all five** module names. If the line is empty or
short, the all-or-nothing downgrade at `configure.ac:343` fired and configure
printed the warning — the library built but lost every codec. This single
line is the whole reason the `--disable-external-libs` decision matters.

```sh
# and the archives carry no unresolved codec symbols, confirming they are
# recorded as private deps rather than silently dropped
llvm-nm -u "$PREFIX/lib/libsndfile.a" | grep -cE 'FLAC_|vorbis_|opus_|ogg_'
```
Expected: `0`. (Undefined references to the codecs are *correct* — they resolve
at consumer link time via `Requires.private`. A **non-zero** count here means
the codec objects were never compiled in at all.)

```sh
# no API-26/28/35 symbols, confirming the "inert" claim empirically
llvm-nm -u "$PREFIX/lib/libsndfile.a" | grep -cE 'nl_langinfo|iconv|mktime_z|posix_spawn'
```
Expected: `0`.

```sh
# no shared object: --disable-shared took effect
find "$PREFIX/lib" -maxdepth 1 -name 'libsndfile.so*' | wc -l
```
Expected: `0`. Scoped to `libsndfile.so*` under `lib/`, so it measures this
package only and cannot be perturbed by a second package installing.

```sh
pkg-config --modversion sndfile
```
Expected: `1.2.2`.

### For the builder, on `x86_64-mingw`

Do not report a mystery. If asked to try mingw, the failure is
`src/file_io.c:499` `implicit declaration of function 'S_ISSOCK'`, a
**system-level blocker** (an upstream/mingw-w64 incompatibility, not a recipe
defect), to be recorded in `stage3.md` per AGENTS.md:549 and **not** worked
around with `-DS_ISSOCK=...` in the recipe.