# miniaudio build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.11.25 (git tag archive)
- Build system: CMake
- Installs: `include/miniaudio/miniaudio.h`, a **static `libminiaudio.a`**
  (`miniaudio.c` compiled, `CMakeLists.txt:505-508`), and the extras headers
  for whichever backends and node-graph nodes get enabled. **No pkg-config
  file** — upstream ships none.
- Requires: `miniaudio@source` only. No package dependencies.

**Correction to the brief: miniaudio is NOT header-only.** The brief said
"plog and miniaudio are header-only … say plainly that nothing is compiled".
That is true of plog and **false of miniaudio**. `CMakeLists.txt:505` is

```cmake
add_library(miniaudio
    miniaudio.c
    miniaudio.h
)
```

and the install rules then install that target (`CMakeLists.txt:791-795`,
building `${LIBS_TO_INSTALL}`). miniaudio *is usable* header-only — a consumer
can `#define MINIAUDIO_IMPLEMENTATION` in its own TU instead — but this
recipe builds the library, because that is what upstream's install produces
and because a library a consumer can link is more useful than one every
consumer must recompile. I have followed the evidence rather than the
instruction, and flagged it here so the discrepancy is on the record.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `miniaudio.c` is plain C that includes only the platform's own audio headers, selected by preprocessor. The Android backend is present (`miniaudio.h` contains `__ANDROID__` once, at the MA_ANDROID selection). `MINIAUDIO_BUILD_EXAMPLES`/`TESTS`/`TOOLS` all default OFF (`:17-19`) and are passed explicitly. `MINIAUDIO_INSTALL=ON` (`:73`) drives the installs. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; the backend selection is by preprocessor, not by cmake. |
| x86_64-mingw | WILL BUILD | As above. miniaudio's WASAPI/DirectSound/WinMM backends are its best-exercised paths upstream. |
| clang-native | WILL BUILD | As above; the ALSA/PulseAudio/JACK backends probe at configure time and any that is absent is simply not compiled. |

**API level notes.** None found. miniaudio's Android backend uses
`AAudio`/`OpenSL ES`, both of which are in the NDK sysroot and not
API-gated in a way this build trips on. Unlike abseil and glog, **miniaudio
does not need `-llog`**: its `#include <android/log.h>` at `miniaudio.h:13601`
sits inside `#if defined(MA_DEBUG_OUTPUT)` (`:13599-13602`), and that macro is
not defined by the library build, so `__android_log_write` is never referenced.
A consumer that *does* define `MA_DEBUG_OUTPUT` would need `-llog`. Recording
this as a negative result so the abseil/glog `-llog` finding is not
over-applied.

**Risks / what a reviewer should check.**

1. **The library really is compiled**, so unlike plog/Eigen/range-v3 this
   package has a real artifact that could be built for the wrong target.
   `llvm-objdump -f libminiaudio.a` is therefore a meaningful check here and
   not a formality.
2. **Backend autodetection could pull in an unexpected dependency.** The
   `MINIAUDIO_NO_*` options (`:23-40`) turn individual backends off, but by
   default cmake *probes* for ALSA, PulseAudio, JACK and libsndfile and
   compiles what it finds. On `clang-native` that means whatever the host has.
   Nothing here is a hard link failure — the probes use `find_library` and skip
   on absence. A consumer should use `pkg-config --libs miniaudio`, which
   exists and carries the enabled-backend defines from `MINIAUDIO_PC_CFLAGS`
   (`CMakeLists.txt:865-867`), rather than assembling a link line by hand.
   **What would settle it: read the configure summary for which backends were
   enabled and compare it against the generated `.pc`.**
3. **`MINIAUDIO_ENABLE_ONLY_SPECIFIC_BACKENDS`** (`:41`) is the lever for
   pinning the backend set; the recipe does not use it, so the artifact can
   differ between systems. That is a judgement call worth a reviewer's view:
   a consumer wanting a predictable backend list might prefer it set
   explicitly.
4. The optional libvorbis/libopus decoder extras (`:520-575`) are gated on
   `HAS_LIBVORBIS`/`HAS_LIBOPUS`. This prefix *does* have libvorbis and opus,
   so those extras may be compiled in, which would add an undeclared link
   obligation. The recipe does not `require()` them. **Worth checking on the
   first build** whether `libminiaudio_libvorbis.a` appears.

**How to verify once built.**

- `lib/libminiaudio.a` exists and `include/miniaudio/miniaudio.h` exists.
- `llvm-objdump -f lib/libminiaudio.a | head -3` prints
  `elf64-littleaarch64` on Android — load-bearing here, unlike the
  header-only packages.
- `llvm-nm --defined-only lib/libminiaudio.a | grep -cw ma_engine_init`
  non-zero, proving the real implementation compiled in.
- `ls $OUT/bin/` must be empty — the three build switches are all off.
- Check the configure summary for the enabled-backend list (risk 2).
- `find $OUT -name 'libminiaudio_lib*.a'` — if a libvorbis/libopus extra
  appeared, a consumer linking only `libminiaudio.a` may need those too
  (risk 4).
- **`lib/pkgconfig/miniaudio.pc` MUST exist** and
  `pkg-config --modversion miniaudio` should report 0.11.25. It is configured
  at `CMakeLists.txt:867` and installed at `:869-870` whenever
  `MINIAUDIO_INSTALL` is on, which this recipe sets. An earlier version of
  this forecast told the builder to assert the *absence* of a `.pc`; that
  instruction was wrong and would have failed on a correct build.
