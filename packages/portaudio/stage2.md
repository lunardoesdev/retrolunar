ACCEPT

# portaudio 19.7.0 — stage 2 review

Checked against the unpacked `PortAudio/portaudio` v19.7.0 tree in `$HOME/dl`,
plus compiler probes against NDK r28.

## The version deviation is real, not lazy

The recipe pins **19.7.0** while 19.7.1 is upstream's latest. I probed both
claimed-unreachable sources myself:

```
$ curl -o /dev/null -w "%{http_code}" -L https://codeload.github.com/PortAudio/portaudio/tar.gz/refs/tags/v19.7.1
404
$ curl -o /dev/null -w "%{http_code}" -L https://sourceforge.net/projects/portaudio/files/PortAudio/19.7.1/pa_stdsource_190701.zip
522
```

GitHub has no `v19.7.1` tag; SourceForge answers 522 (its "origin unreachable"
response) from this network. The pinned URL resolves — I downloaded and
unpacked it, and it is a complete autotools+cmake tree. **The deviation is
documented, the alternative is genuinely unreachable, and pinning the newest
*reachable* release is the right call.** Not laziness.

## The autotools path is genuinely unusable — but the stated reason is half
wrong, and that matters

Two independent reasons, per the comment. I checked both.

**(2) `all` builds host programs with no switch to stop it — CONFIRMED, and the
count is right.** `Makefile.in:159`:

```make
all: lib/$(PALIB) all-recursive tests examples selftests
```

Unconditional. I parsed the three lists out of the real `Makefile.in` rather
than eyeballing them:

```
TESTS     30   (bin/patest1 … bin/pa_minlat)
EXAMPLES   9
SELFTESTS  3
total     42
```

The recipe comment says "29 test programs, 9 examples and 3 selftests"; the
real number is **30** tests, so 42 programs, not 41. stage1.md:124-127 repeats
"41". Off by one in both files. Cosmetic — it does not change the argument,
which is that these are host programs opening audio devices — but a count is
a count, and stage1.md:144 turns it into a build check
(`find $OUT -name 'patest*' -o -name 'paex_*' -o -name 'paqa*' | wc -l` → 0),
which is correctly scoped and unaffected. **Fix the number to 30/42.**

**(1) `configure.in:393` hard-errors without `-lpthread` — the LINE is right,
the CONCLUSION is wrong, and this is the one real finding.** The line is
exactly as quoted:

```
AC_CHECK_LIB(pthread, pthread_create,[have_pthread="yes"],
        AC_MSG_ERROR([libpthread not found!]))
```

at `configure.in:393`. And there is genuinely no `libpthread` in the NDK:

```
$ find $NDK -name 'libpthread*'
(no output)
```

**But `-lpthread` does not fail when you use the NDK wrapper**, which is what
`$CC` is. Probing both:

```
$ aarch64-linux-android24-clang pt.c -o pt -lpthread
ld.lld: error: unable to find library -lpthread      (via wrapper: FAILS)

$ clang-19 --target=aarch64-linux-android24 --sysroot=$SYSROOT pt.c -lpthread
ld.lld: error: unable to find library -lpthread      (raw clang: FAILS)
```

Both fail — so the recipe's conclusion (the autotools path aborts) is
**correct**, and I retract my doubt. The one nuance worth recording: my first
probe appeared to succeed because I piped it through `head`, which masked the
exit status — precisely the failure mode AGENTS.md warns about, caught here by
re-running isolated. The wrapper does pass `-lpthread` through (visible in the
`-###` link line), and ld.lld rejects it.

So both reasons hold. The choice of CMake is right, and `PA_BUILD_TESTS=OFF` /
`PA_BUILD_EXAMPLES=OFF` (`CMakeLists.txt:478`, `:484`) are stated explicitly so
a future default flip cannot start compiling host programs.

## ALSA and JACK must be forced off — CONFIRMED, and the host really has them

This is the most valuable catch in the recipe, and it checks out. The build
host has both:

```
$ ls /usr/lib/pkgconfig/jack.pc          → exists
$ ls /usr/lib64/libasound.so             → exists
$ ls /usr/include/alsa/asoundlib.h       → exists
```

`CMakeLists.txt:277-299` autodetects each with `FIND_PACKAGE(Jack)` /
`FIND_PACKAGE(ALSA)` and turns the option **ON** when found, appending
`-ljack` / `-lasound` to `PA_PKGCONFIG_LDFLAGS` (`:291`, `:314`) — i.e. into
the *installed* `.pc`. Left to autodetect, a `clang-native` build would bake
this machine's audio stack into the target prefix. `-DPA_USE_ALSA=OFF
-DPA_USE_JACK=OFF` prevents it. Exactly right, and the reason is the kind that
only shows up if someone has read the file.

## What installs, and the honest `-lpthread` problem in the `.pc`

`CMakeLists.txt:452-465` installs `libportaudio.a` (`PA_LIBNAME_ADD_SUFFIX` is
OFF off-MSVC, `:352-355`, so `OUTPUT_NAME portaudio` at `:388`), the headers,
`lib/pkgconfig/portaudio-2.0.pc`, the CMake package config, and
`share/doc/portaudio/{README.md,LICENSE.txt}`.

stage1.md:96-105 identifies a real defect in the installed artifact:
`CMakeLists.txt:320` unconditionally appends `-lm -lpthread` to
`PA_PKGCONFIG_LDFLAGS` inside the `ELSEIF(UNIX)` block, and
`cmake_support/portaudio-2.0.pc.in:11` interpolates it into `Libs:`. I
confirmed there is **no cmake option** controlling that line —
`grep -n PA_PKGCONFIG_LDFLAGS CMakeLists.txt` shows only seven hits, all
`SET(... "${PA_PKGCONFIG_LDFLAGS} ...")` accumulations with no guard.

**The adder is right to leave it alone and right about why.** The build is
unaffected (`PA_LIBRARY_DEPENDENCIES` at `:321` reaches only
`TARGET_LINK_LIBRARIES` at `:377`/`:386`, and a STATIC target performs no link
step), and the fix belongs in the Android system files as a platform fact, not
in a package recipe — AGENTS.md:548-551 is explicit that a platform fact is
recorded, not worked around. The `awk`-on-a-generated-`.pc` escape hatch
(AGENTS.md:248-254) exists, but applying it here would encode a Bionic fact in
a package recipe, which is the thing that rule is trying to prevent.

The one thing to fix is stage1.md:147-150, which tells the builder to *expect*
`grep -c 'lpthread' … → 1` and, on Android, to "note that a consumer using
`pkg-config --libs` will fail to link". That framing is too soft: the line is
not a note, it is a known-broken artifact. Say plainly that `pkg-config --libs
portaudio-2.0` on Android cannot link, and that this is a system-level blocker
for `Role 3` to record, not a build regression.

## No target binary is executed

The CMake path with tests and examples off builds the library alone.
`PA_SKELETON_SOURCES` (`CMakeLists.txt:114`) is always in `PA_SOURCES` (`:116`),
so with ALSA and JACK off on Android the compiled set is `src/common/*.c` plus
`src/hostapi/skeleton/pa_hostapi_skeleton.c` — no backend that opens a device.
Nothing in the build runs anything. Clean.

## The system

```
cmake -S . -B build $CMAKE_FLAGS -DPA_BUILD_STATIC=ON -DPA_BUILD_SHARED=OFF \
  -DPA_USE_ALSA=OFF -DPA_USE_JACK=OFF -DPA_BUILD_TESTS=OFF -DPA_BUILD_EXAMPLES=OFF
cmake --build build --parallel 1
cmake --install build
```

All build-system flags via `$CMAKE_FLAGS`; `--prefix` from the system. No
hardcoded target facts, no exported search flags, no `android.lua` (nothing
here is Android-specific — the backend choice is a package-level decision made
identically everywhere). `cmake --build build --parallel 1` — no fan-out.
Every option verified to exist: `PA_BUILD_STATIC:349`, `PA_BUILD_SHARED:350`,
`PA_USE_JACK:279/281`, `PA_USE_ALSA:296/299`, `PA_BUILD_TESTS:478`,
`PA_BUILD_EXAMPLES:484`. No invented flags.

`grep -c '^AC_CONFIG_HEADER' configure.in` → **0**, so no autotools guard is
needed, and the recipe correctly has none. (stage1.md:114-122 says the guard
would be `touch aclocal.m4 configure Makefile.in` and nothing else, which is
right.)

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. mingw: the `IF(WIN32)` block selects WMME/DirectSound/WASAPI/
WDMKS linking `winmm dsound ole32 uuid setupapi` (`:145`, `:166`, `:192-241`),
all present in mingw-w64; ASIO self-disables via `FIND_PACKAGE(ASIOSDK)` at
`:149` finding nothing and the `ELSE()` at `:153`. And `FindASIOSDK.cmake`'s
`FATAL_ERROR` off Windows is unreachable from Android and native, since the
call site is inside `IF(WIN32)`. Correctly reasoned.

## Verdict

ACCEPT. The version deviation is real and properly documented, the build-system
choice is justified by two independently verified reasons, the ALSA/JACK
pinning prevents a real and non-obvious host-leak into the installed `.pc`, and
no target binary is executed. Two documentation fixes ride along: the host
program count is 30 tests / 9 examples / 3 selftests = **42**, not 29/41, and
the `.pc`'s dead `-lpthread` on Android should be stated as a blocker rather
than a note. Neither is a recipe defect.
