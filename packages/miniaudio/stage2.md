REJECT

# miniaudio 0.11.25 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

Two things had to be settled before this could be judged: the `-llog`
question, and whether the artifact list matches what upstream installs.
The first is **clean**. The second is **not**, and it is a REJECT.

## Required change (one line, both files)

**The recipe installs a pkg-config file, and both `generic.lua` and
`stage1.md` say it does not.** Upstream ships `miniaudio.pc.in` and installs
the generated `miniaudio.pc` whenever `MINIAUDIO_INSTALL` is on — which the
recipe explicitly turns on.

Evidence from the unpacked tree (tag 0.11.25, top dir `miniaudio-0.11.25`):

```
$ ls miniaudio.pc.in
miniaudio.pc.in

$ grep -n "configure_file" CMakeLists.txt
867:configure_file("${CMAKE_CURRENT_SOURCE_DIR}/miniaudio.pc.in" "${CMAKE_CURRENT_BINARY_DIR}/miniaudio.pc" @ONLY)

$ sed -n '869,871p' CMakeLists.txt
if(MINIAUDIO_INSTALL)
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/miniaudio.pc" DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
```

`miniaudio.pc.in` is a real, fully-formed file (8 fields, `Libs:
-L${libdir} -lminiaudio`, plus `Requires.private` / `Libs.private` slots
that upstream fills from the detected backends).

So the two false statements to correct:

- `packages/miniaudio/generic.lua:21-22` — the comment
  "No pkg-config file - upstream ships none" is false. The switch that
  causes it is `-DMINIAUDIO_INSTALL=ON` on the same command. Delete the
  claim; do not add a switch to suppress the file.
- `packages/miniaudio/stage1.md:8-9` — "**No pkg-config file** — upstream
  ships none" is false for the same reason.
- `packages/miniaudio/stage1.md:88` — the verification instruction
  "**No `.pc` is expected** — `find $OUT -name '*.pc'` should return nothing"
  is the expensive one. This is precisely the phantom defect AGENTS.md
  warns about in the other direction: the builder runs a check that is
  guaranteed to fail on a *correct* build, and then either reports a defect
  that does not exist or, worse, is tempted to "fix" it by suppressing the
  install. Replace it with an assertion that the file **is** there.

Everything else in the recipe is correct and should be left alone.

## Question 1 — is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS …`, `cmake --build build --parallel 1`,
`cmake --install build`. No hardcoded target facts, no `export` of search
flags, no per-target recipe. `--parallel 1` is explicit, so the build does
not fan out. `require("miniaudio@source")` resolves. Correct.

## Question 2 — the two load-bearing claims

### "miniaudio is NOT header-only" — CONFIRMED, and the adder was right to override the brief

`CMakeLists.txt:504-508`:

```cmake
# Static Libraries
add_library(miniaudio
    miniaudio.c
    miniaudio.h
)
```

and `:516` `list(APPEND LIBS_TO_INSTALL miniaudio)`, consumed by the
`install(TARGETS ${LIBS_TO_INSTALL} …)` at `:876-880`. `BUILD_SHARED_LIBS`
is never set in this `CMakeLists.txt`, so with cmake's default (OFF) the
target is a static `libminiaudio.a`. The brief's "header-only" description
was wrong and the adder followed the evidence and flagged the discrepancy,
which is the correct behaviour. This is exactly the kind of override the
pipeline exists to permit.

### The `-llog` question — CONFIRMED CLEAN, and it is worth stating precisely

**The adder's negative result is correct: the library build does not need
`-llog`.** Two independent confirmations.

*Static evidence.* The only `#include <android/log.h>` in the library is at
`miniaudio.h:13601`, and it sits inside the `MA_DEBUG_OUTPUT` block:

```
13599:#if defined(MA_DEBUG_OUTPUT)
13600:#if defined(MA_ANDROID)
13601:    #include <android/log.h>
13602:#endif
```

`__android_log_print` is called at `:13617`, also inside that block.
`MA_DEBUG_OUTPUT` only enters `COMPILE_DEFINES` when
`MINIAUDIO_DEBUG_OUTPUT` is set (`CMakeLists.txt:280-282`), and that option
defaults **OFF** (`:72`). So the library build never compiles the block.
The `android/log.h` inclusion is not gated on API level at all.

*Empirical evidence.* I compiled `miniaudio.c` for real against the NDK,
exactly as the recipe would, at both ends of the API range:

```
$ .../bin/aarch64-linux-android21-clang -O2 -fPIC -c miniaudio.c -o ma21.o   # exit 0
$ .../bin/aarch64-linux-android35-clang -O2 -fPIC -c miniaudio.c -o ma35.o   # exit 0
$ .../bin/llvm-nm -u ma21.o | grep -i android_log
(no output)
```

Zero `__android_log_*` undefined symbols in the archive. **The recipe fails
to link only if the adder were wrong, and the adder is not.** No `-llog`
is required, and — worth being precise about why — it would not be the
recipe's job to add it: `libminiaudio` is a *static archive* built with no
link step, so a missing `-llog` could not fail this build at all. It would
surface only in a consumer that compiles miniaudio with `MA_DEBUG_OUTPUT`
defined, and that consumer's system already supplies `-llog`
(`packages/aarch64-android24/generic.lua:86`). The negative result is
recorded so the glog/abseil `-llog` finding is not over-applied here, which
is exactly what `stage1.md:40-48` says it is for.

### Backends actually selected — no Bionic or mingw gap

`stage1.md` risk 2 asks the reviewer to read the configure summary. I
settled it directly instead, with `-dM` on the real compilation for each
family:

| system | `MA_HAS_*` selected | pull-in risk |
|---|---|---|
| aarch64-android21/24/35 | `AAUDIO`, `OPENSL`, `NULL` | none — see below |
| x86_64-mingw | `WASAPI`, `DSOUND`, `WINMM`, `NULL` | none — all `kernel32`/`ole32`/`avrt`, in every mingw sysroot |
| clang-native | `ALSA`, `PULSEAUDIO`, `JACK`, `NULL` | none — all `dlopen`'d |

The Android case is the one worth spelling out, because **AAudio is API 26+
and this tree builds android21**. It is not a problem: `MINIAUDIO_NO_RUNTIME_LINKING`
defaults OFF (`:70`), so `ma_context_init__aaudio` (`:40073-40109`) `dlopen`s
`libaaudio.so` and `dlsym`s every entry point rather than linking them. The
direct-link `#else` branch at `:40110-40151` is not compiled, and it is
gated on `__ANDROID_API__ >= 29` for the newest entry point anyway. The
empirically confirmed fact is stronger still: the compile at API 21 produced
a clean object. The full undefined-symbol set of the API-21 archive is
libc/libm/`libdl` only — `dlopen`, `dlsym`, `pthread_*`, `malloc`, `memcpy`,
`exp`, `pow`, `sin`, `__system_property_get`, … — every one of which is in
Bionic's libc, libm or libdl, and `-lm`/`-llog` are already in every Android
system's `LDFLAGS`. **No missing library on any of the six systems.**

`stage1.md` risk 4 (libvorbis/libopus extras) is real and correctly flagged as
a thing to watch: the nest's `aarch64-android24` prefix does carry
`vorbisfile.pc` and `opus.pc`, so `pkg_check_modules` at `:360`/`:389` can
succeed there and add `miniaudio_libvorbis`. That is an *extra* archive
alongside `libminiaudio.a`, not a build failure, and the adder did not
`require()` those packages — correctly, since it must not add an undeclared
dependency. Keep the check.

## The forecast

Every row is WILL BUILD and every row cites `miniaudio.c` as "plain C that
includes only the platform's own audio headers, selected by preprocessor".
I did not accept that on citation — I compiled it at API 21 and API 35 with
the NDK and both succeed with exit 0. The uniform WILL BUILD is earned here
for the first time in this batch, and it is earned for a reason the adder
could not have had: the library build compiles no `__ANDROID_API__`-gated
code path that Bionic lacks.

One caveat on the rows, not a defect: `MINIAUDIO_ENABLE_ONLY_SPECIFIC_BACKENDS`
(`:40`) is left off, so the enabled-backend set genuinely differs per system
(`stage1.md` risk 3 says so). That is a defensible choice — it is upstream's
own default and it keeps the recipe free of per-system facts — and it does
not affect buildability.

## Carried to the build

- `lib/libminiaudio.a` exists and `include/miniaudio/miniaudio.h` exists
  (`CMakeLists.txt:511-513`, `:876-880`).
- **`lib/pkgconfig/miniaudio.pc` exists** — this replaces the false "no `.pc`"
  instruction. `pkg-config --modversion miniaudio` must report 0.11.25
  (the `Version:` field is `@PROJECT_VERSION@`, from
  `project(miniaudio VERSION 0.11.25 …)`).
- `$OBJDUMP -f lib/libminiaudio.a` prints `elf64-littleaarch64` on Android.
  Load-bearing here, unlike the header-only packages.
- `llvm-nm --defined-only lib/libminiaudio.a | grep -cw ma_engine_init` is
  non-zero, proving the real implementation compiled in.
- `llvm-nm -u lib/libminiaudio.a | grep -c __android_log_` must be **0**.
  This is the regression test for the `-llog` finding: if anyone ever adds
  `MA_DEBUG_OUTPUT` to the build, this goes non-zero and a consumer link
  starts needing `-llog`. State the expected value (0).
- `ls $OUT/bin/` is empty — `MINIAUDIO_BUILD_EXAMPLES/TESTS/TOOLS` are all
  OFF (`:17-19`), each of which would add a host program.
- `find $OUT -name 'libminiaudio_lib*.a'` — report what appears. If
  `libminiaudio_libvorbis.a` does, that is `stage1.md` risk 4 confirming
  itself, not a defect.
