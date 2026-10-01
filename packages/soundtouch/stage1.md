# soundtouch build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.4.1 (newest official release; 2.3.3 was a silent downgrade)
- Build system: **CMake, not Autotools** — see below
- Installs: static `libSoundTouch.a`, the `soundtouch/` headers,
  `lib/pkgconfig/soundtouch.pc`, and a CMake package config. No
  `soundstretch` utility, no `SoundTouchDLL`.
- Requires: `soundtouch@source` only. No dependencies.

**Autotools question, answered by inspection.** The brief asked me to check
whether soundtouch's `configure` has a switch to skip its host test/example
programs and whether any would try to *run*. The more basic finding came
first: **soundtouch 2.4.1 ships no `configure` at all.** I checked four
official dist tarballs — 2.3.2, 2.3.3, 2.4.0 and 2.4.1 — and all four ship
`configure.ac` and `Makefile.am` with **no generated `configure`**. Debian's
pool copies are `+ds` repacks, not unmodified upstream, so they are not a
usable substitute. The source is therefore the official tarball, and the build
goes through the project's own first-class `CMakeLists.txt` rather than a
bootstrap. Same shape `packages/wolfssl` takes for the same reason.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `SOUNDSTRETCH=OFF` removes the `soundstretch` command-line utility, which defaults **ON** (`CMakeLists.txt:112`) and is the one host program in the project — a transcoder that would link the target library and, if run, transcode audio. What remains is `add_library(SoundTouch ...)` (`:23`), portable C++ with no platform layer; its `NEON` option (`:75`) is compiler-selected for ARM and needs nothing switched off. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above, and `SOUNDTOUCH_DLL=OFF` is passed explicitly: that option (`:135`) builds the Windows DLL wrapper as a *shared* library, which a target prefix has no loader path for. Upstream defaults it OFF, so passing it makes the decision visible rather than inherited. |
| clang-native | WILL BUILD | As above. `OPENMP` defaults OFF (`:84`), so no host OpenMP runtime is pulled in. |

**API level notes.** None. SoundTouch is a self-contained DSP library
(FFT, rate conversion, time stretching) with no libc dependency beyond
`memcpy`/`malloc`.

**Risks / what a reviewer should check.**

1. **Because there is no `configure`, none of the autotools machinery
   applies** — no `$AUTOCONF_CONFIGURE_FLAGS`, no timestamp guard, and in
   particular no config template to name. This is worth stating plainly so a
   later reader does not go looking for one or add `touch config.h.in`, which
   would be an inert guard exactly as AGENTS.md:289-292 describes.
2. **`NEON` defaults ON** (`:75`) and `add_compile_options(-march=...)`-style
   flags may be added for ARM targets. On `aarch64` that is correct and
   portable NEON; it is worth a glance in the compile line for any hard
   `-march` that would break on a different ARM core.
3. **`cmake_minimum_required(VERSION 3.1)`** (`:1`) is old but satisfied.
4. **The installed `.pc` is generated** (`install(FILES
   "${CMAKE_CURRENT_BINARY_DIR}/soundtouch.pc" ...)`, `:160`), so the loader's
   `$OUT`→`$PREFIX` rewrite applies to it. `pkg-config --modversion soundtouch`
   is therefore a real check.

**How to verify once built.**

- `lib/libSoundTouch.a` exists; `include/soundtouch/SoundTouch.h` exists.
- `pkg-config --modversion soundtouch` reports 2.4.1, and
  `pkg-config --cflags --libs soundtouch` resolves.
- `llvm-objdump -f lib/libSoundTouch.a | head -3` prints
  `elf64-littleaarch64` on Android.
- `llvm-nm -C --defined-only lib/libSoundTouch.a | grep -cw
  soundtouch::SoundTouch` non-zero (demangled), proving C++ content is there.
- **`ls $OUT/bin/` must be empty** — `soundstretch` is off. Its presence means
  `SOUNDSTRETCH=OFF` regressed, and it is a target binary that must never be
  run.
- A CMake package config should exist (`install` rules at `:165`/`:180`);
  check the path cmake chose.
- `test ! -e $OUT/lib/libSoundTouchDLL*` — the DLL wrapper is off.
