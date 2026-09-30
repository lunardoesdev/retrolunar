ACCEPT

# draco 1.5.7 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- `DRACO_TESTS=OFF` is the one switch that matters, and draco's test suite is
  a large gtest tree. Turning it off is the correct cut, and the recipe comment
  says why.
- Everything else that could pull in a host program is already OFF by default
  in `cmake/draco_options.cmake` — `DRACO_TRANSCODER_SUPPORTED`,
  `DRACO_WASM`, `DRACO_UNITY_PLUGIN`, `DRACO_MAYA_PLUGIN` — and
  `DRACO_INSTALL` is ON. So the target really is library + headers +
  generated `draco_features.h`, with no host or target programs. The recipe is
  right not to pass a pile of switches that are already off.
- `-DBUILD_SHARED_LIBS=OFF` gives the static `libdraco.a`.
  `cmake_minimum_required(VERSION 3.12)` is satisfied.
  `cmake --build build --parallel 1` is serial, install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("draco@source")` names no missing package.
- The recipe comment correctly notes that the tag archive has CMake, not a
  Makefile — which matters, because it is the same "hand-written Makefile
  versus autoconf versus cmake" distinction AGENTS.md cares about.

## One citation slip in the forecast, not a reject reason

`stage1.md` cites "C++11 in its CMakeLists.txt". The top-level `CMakeLists.txt`
only sets a C++ standard when the transcoder is enabled, and the transcoder is
off here — so the C++ standard that actually applies is the compiler default.
The conclusion (nothing in the library needs a specific dialect) is right; the
citation is not. The transcode tools `stage1.md` worries about are also
already off by default rather than merely unmentioned, which is a stronger
answer than the one given.

## Carried to the build

- `lib/libdraco.a` — `llvm-objdump -f lib/libdraco.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/draco/compression/encode.h`, `include/draco/compression/decode.h` — `[ -f include/draco/compression/encode.h ] && [ -f include/draco/compression/decode.h ]`.
- `include/draco/draco_features.h` — `[ -f include/draco/draco_features.h ]`. This one is **generated at configure time**, so its presence is the proof that the configure step ran to completion, not just that a file was copied.
- No `bin/` — if `draco_encoder` or `draco_decoder` appear, something other than the transcoder path built.
- No `.pc`; draco ships none, and a missing `pkg-config --modversion draco` is correct.
