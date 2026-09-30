# sdl2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.32.10
  (`github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-2.32.10.tar.gz`)
- Build system: **CMake** (`generic.lua:6`)
- Installs: `lib/libSDL2.a`, `include/SDL2/*.h`, `lib/pkgconfig/sdl2.pc`,
  plus a CMake package config
- Requires: `sdl2@source` only (`generic.lua:1`). **No package dependencies**,
  because every subsystem that would need one is switched off — see below.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The flag set at `generic.lua:6` is aggressive on purpose and every subsystem that could reach for a missing library is off: `SDL_AUDIO=OFF` (no PulseAudio/ALSA), `SDL_CAMERA=OFF`, `SDL_HAPTIC=OFF`, `SDL_GPU=OFF`, `SDL_LOCALES=OFF` (which is what drops `iconv.h` — Bionic only exposes that at API 28), and `SDL_SYSTEM_ICONV=OFF`. `SDL_VIDEO=ON` is kept, and that is safe on Android only because SDL's Android video backend lives in the `android/` subproject and is not part of this autotools/CMake build; the Unix backend's KMSDRM path is `#if`-gated and falls back to `SDL_VIDEO_DRIVER_DUMMY`/`OFFSCREEN` selection at configure time. Remaining subsystems use `pthread` (in libc on Bionic — **there is no `-lpthread` at all**, and none is asked for) and `mmap`. |
| aarch64-android24 | WILL BUILD | As above. `SDL_LOCALES=OFF` and `SDL_SYSTEM_ICONV=OFF` mean the API-28 `iconv.h` gap does not apply here or anywhere else in this build. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; SDL's Windows backend is self-contained (`win32/`), and `-DWIN32_LEAN_AND_MEAN` is not needed since no Windows headers conflict. |
| clang-native | UNCERTAIN | **As above except `SDL_VIDEO=ON`, which is the one flag that could pull an X11 dependency on a native Linux host.** |

**API level notes.** **No new wall, and `SDL_LOCALES=OFF` is what guarantees
that.** This is the flag that matters: SDL's locale support uses `iconv`, and
**Bionic has no separate `-liconv` and only exposes `<iconv.h>` from API 28**.
With `SDL_LOCALES=OFF` and `SDL_SYSTEM_ICONV=OFF`, no iconv call is compiled in
at all, so API 21, 24 and 35 behave identically. The other two API-21 items in
the AGENTS.md:368 list — `mblen`/`getpass` and `posix_spawn` — are not used by
SDL's core at all.

**Risks / what a reviewer should check.**
1. **`SDL_VIDEO=ON` is the odd one out and it is why `clang-native` is
   UNCERTAIN rather than WILL BUILD.** Every other subsystem in `generic.lua:6`
   is disabled to avoid a missing dependency; `SDL_VIDEO` is *enabled* while
   `SDL_GPU=OFF`. On the Android targets the Linux/KMSDRM and X11 backends are
   unavailable so cmake selects a stub, but on `clang-native` the same option
   makes cmake look for X11, and if `libX11-dev` is absent configure fails.
   **What would settle it:** check whether `cmake --find-package` finds X11 on
   the build host, or simply set `SDL_VIDEO=OFF` if the prefix is not meant to
   ship a windowing stack — which for a target-prefix package manager is the more
   coherent choice, since a target prefix cannot show windows anyway.
2. **The flag list is long (18 `-D` options on one line) and undocumented.**
   Unlike every other cmake recipe in this tree, there is **no explanatory
   comment** above the `cmake` line. That is a real gap against AGENTS.md's
   "Explain non-obvious flags". A reviewer should ask for at least a comment
   grouping them: *host-program switches* (`SDL_TEST`, `SDL_TESTS`,
   `SDL_EXAMPLES`, `SDL_INSTALL_TESTS`), *missing-dependency switches*
   (`SDL_AUDIO`, `SDL_CAMERA`, `SDL_HAPTIC`, `SDL_GPU`, `SDL_LOCALES`,
   `SDL_SYSTEM_ICONV`), and *shape* (`BUILD_SHARED_LIBS=OFF`, `SDL_SHARED=OFF`,
   `SDL_STATIC=ON`, `SDL_LIBC=ON`).
3. **`SDL_SHARED=OFF` *and* `-DBUILD_SHARED_LIBS=OFF` are both passed.** SDL
   has its own `SDL_SHARED` option *and* honours the standard one, so passing
   both is belt-and-braces rather than redundant. Fine, but worth knowing which
   one would silently stop working if upstream changed.
4. **`SDL_TEST=OFF` and `SDL_TESTS=OFF` look like the same flag spelled two
   ways.** SDL 2.32 uses `SDL_TEST` (the single option) and `SDL_TESTS` does not
   exist; cmake ignores unknown cache variables silently, so `SDL_TESTS=OFF` is
   a no-op. Harmless, but a reviewer should prune it.
5. **`SDL_LIBC=ON` is the default** and is documented by upstream as meaning
   "do not link any C library beyond libc" — which is exactly right for a Bionic
   prefix. Good choice.
6. **2.32.10 is the current 2.32 release.** No upgrade pressure.

**How to verify once built.**
- `lib/libSDL2.a`, `include/SDL2/SDL.h`, `include/SDL2/SDL_video.h`,
  `lib/pkgconfig/sdl2.pc`
- `pkg-config --modversion sdl2` → `2.32.10`
- `llvm-objdump -f lib/libSDL2.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm -u lib/libSDL2.a | grep -cE 'iconv_|XOpenDisplay|pulse_|av_'`
  must be **0** — this single check validates the whole `generic.lua:6` flag set
  at once and is the one to run first
- `llvm-nm -u lib/libSDL2.a | grep -c pthread_create` → **non-zero** is
  *expected* here (unlike zstd), because SDL's threading subsystem uses
  pthread_create which Bionic provides **in libc**. The check is that no
  `-lpthread` appears in any link line, which `find $PREFIX/lib -name
  'libpthread*'` confirms is empty.
- `find $PREFIX/lib -name '*.so*'` → **empty**
- `find $PREFIX/bin -name 'test*'` → **empty**, proving `SDL_TEST=OFF` took
**Predicted configuration summary.** SDL2's cmake ends with a one-line
summary of what it configured. Expect: video driver `dummy` or `offscreen`
only (no X11, Wayland or KMSDRM in Bionic's sysroot, so nothing else can be
selected); audio `Disabled` (`-DSDL_AUDIO=OFF`); `HIDAPI` present, and the
summary line says whether the backend is *system* or *in-tree* — that is the
check worth comparing against the `SDL_HIDAPI=ON` note in the recipe; and
`SDL_RENDER` present but with no usable presentation target, which is the
deliberate trade recorded in `generic.lua`. The builder should diff that
summary line against this paragraph and against the recipe comment; a
surprise here is a subsystem that silently found a backend it should not
have.
