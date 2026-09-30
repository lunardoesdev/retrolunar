REJECT

# sdl2 2.32.10 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

**The switch names are right — this is not a naming problem. The defect is that
none of them is explained, and one combination in the list is self-contradictory.**

## Required changes

### 1. `packages/sdl2/generic.lua:6` — the flag list has no comment at all

Every other reviewed recipe in this shard explains its switches. This one has a
twenty-one-flag line with **zero** explanation, on a package where SDL2's option
names are genuinely easy to get wrong and where the individual values encode real
decisions. AGENTS.md requires that non-obvious switches be explained.

The names themselves are correct — SDL2 spells them `SDL_<SUB>` rather than the
`ENABLE_<SUB>` pattern most projects use, and the recipe has that right, which is
worth preserving. The missing half is the reasoning.

**Add a comment above line 6 recording, at minimum, the four decisions that a
reader cannot infer:**

```
        # Static library, no SDL2 shared object. SDL2 spells its switches
        # SDL_<SUB>, not ENABLE_<SUB>, so the names below are not a typo.
        #   -DSDL_SHARED=OFF -DSDL_STATIC=ON  is redundant with
        #     -DBUILD_SHARED_LIBS=OFF but harmless; SDL reads both.
        #   -DSDL_TEST/TESTS/EXAMPLES/INSTALL_TESTS=OFF  drops the host
        #     programs - the one thing a cross build must not compile.
        #   -DSDL_AUDIO=OFF  because the recipe keeps no audio backend and
        #     building a target audio driver nothing can run is dead weight.
        #   -DSDL_SYSTEM_ICONV=OFF  so SDL does not probe for a system iconv
        #     that Bionic does not ship separately.
        #   -DSDL_LIBC=ON  is the baseline libc, not a third-party library.
```

### 2. `packages/sdl2/generic.lua:6` — `SDL_VIDEO=ON` with `SDL_GPU=OFF` and `SDL_RENDER=ON` is contradictory

The line passes `-DSDL_VIDEO=ON … -DSDL_GPU=OFF … -DSDL_RENDER=ON`. SDL2's
**render** subsystem is a thin abstraction *over a video subsystem*: with no
window-system backend there is no renderer to draw into. On this prefix there is
no X11, no Wayland and no KMSDRM — Bionic's sysroot has none of them — so
`SDL_VIDEO=ON` compiles a video subsystem whose only available backend is
whatever SDL falls back to (dummy/offscreen), while `SDL_RENDER=ON` builds a
renderer that can never present a frame.

That is not automatically a build failure, but it is dead compiled surface and,
more importantly, it is a decision nobody recorded. Two coherent resolutions:

- if the intent is a library-only prefix with no presentation path, drop
  `-DSDL_VIDEO=ON` and `-DSDL_RENDER=ON` entirely and keep only the
  subsystems that do not need a display (audio is already off; timers, threads,
  filesystem, events, power, joystick);
- if a consumer later needs SDL2's event and timer machinery, keep `SDL_VIDEO=ON`
  and say in the comment that no backend is expected to initialise.

Either way the value must be justified. `SDL_HIDAPI=ON` deserves the same
sentence, since SDL2's HIDAPI can either use the system backend or **build and
bundle its own**, which is a portability decision, not a default.

### 3. `packages/sdl2/stage1.md` — it must say what SDL2 actually configures

SDL2's cmake prints a one-line configuration summary. `stage1.md` should predict
what that line will contain — which video driver, which audio driver, whether
HIDAPI is in-tree or system — and the builder should compare. A forecast that
does not predict the configured backend set is not much of a forecast for a
project with twenty-one switches.

## What the recipe otherwise gets right

- The switch names are genuinely correct, which is the hard part and the part a
  less careful recipe would have got wrong. `SDL_SHARED`/`SDL_STATIC` rather
  than `BUILD_SHARED_LIBS` alone, `SDL_TEST` and `SDL_TESTS` both present
  (SDL2 has had both spellings across releases), `SDL_INSTALL_TESTS`,
  `SDL_SYSTEM_ICONV`, `SDL_LIBC` — all real.
- `-DBUILD_SHARED_LIBS=OFF` supplies the static control, and the SDL2-native
  `SDL_STATIC=ON` agrees with it.
- The host-program switches (`SDL_TEST`, `SDL_TESTS`, `SDL_EXAMPLES`,
  `SDL_INSTALL_TESTS`) are exactly the category AGENTS.md says a cross build
  must not compile, and all four are off.
- `-DSDL_SYSTEM_ICONV=OFF` avoids probing for a system iconv, which matters on
  Android: Bionic has no separate `libiconv`, and SDL2's probe would either fail
  or pick up something unintended.
- `cmake --build build --parallel 1` is serial; install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch, no `/dev/null`,
  nothing hardcoded to a target, nothing `export`ed.
- `require("sdl2@source")` names no missing package — notable, because most SDL2
  builds pull X11, wayland, pulseaudio or alsa, none of which are in this prefix,
  and every one of those is disabled or absent.

## Carried to the build

- `lib/libSDL2.a` — `llvm-objdump -f lib/libSDL2.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **`libSDL2.so*` must be absent** — its presence means `-DSDL_SHARED=OFF` did not take, and a versioned SDL2 shared object in a static prefix is the exact failure `packages/freetype` has.
- `include/SDL2/SDL.h` (or `include/SDL.h`, depending on the release's header layout) — `[ -f include/SDL2/SDL.h ] || [ -f include/SDL.h ]`; record which, because SDL2 moved its headers into a subdirectory at 2.0.2 and the loader's `.pc` rewrite does not cover a header move.
- `lib/pkgconfig/sdl2.pc` — `pkg-config --modversion sdl2` → `2.32.10`, and **`pkg-config --libs sdl2` must name no `-lX11`, `-lwayland-client`, `-lpulse` or `-lasound`**. That is the single most valuable check for this package: it proves no X11/audio backend leaked in.
- **Compare the configure-time summary against what `stage1.md` predicted.** An unexpected video or audio backend name is the finding; on this prefix there should be none.
- No test, example or test-library binary anywhere under `$OUT` — `find $OUT -name 'test*'` must return nothing, and no `libSDL2_test*` may appear.
- `bin/` should be empty: SDL2's `sdl2-config` is a shell script and may be installed; any other binary there is unexpected.