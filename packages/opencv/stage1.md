# opencv build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.10.0 (git tag archive)
- Build system: CMake
- Installs: `libopencv_core.a`, `libopencv_imgproc.a`, `libopencv_imgcodecs.a`,
  `libopencv_videoio.a` — **four archives, and only those four**, because of
  `-DBUILD_LIST=core,imgproc,imgcodecs,videoio` at `generic.lua:24`. Plus the
  `opencv4/opencv2/` headers and an `opencv4.pc`.
- Requires: `zlib`, `libjpeg-turbo`, `libpng`, `libtiff`, `libwebp`,
  `openjpeg` — **all six exist** in `packages/`. The widest dependency fan-in
  in the shard.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The recipe is a careful, deliberate scope reduction, and `-DBUILD_LIST` is what makes it tractable. Six `require()`s are declared but **all six image codecs are then switched off** (`-DBUILD_JPEG=OFF -DBUILD_PNG=OFF -DBUILD_TIFF=OFF -DBUILD_WEBP=OFF`, plus `-DWITH_TIFF=OFF`), so the declared dependencies are not actually linked into `libopencv_imgcodecs.a`. What survives is a reduced imgcodecs that can only read whatever opencv's built-in decoders handle — which for PNG means nothing, since PNG is exactly what was turned off. **The dependencies are declared for a reason the flags then remove, and a reviewer should decide whether that is intended.** |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The four-module build should compile, but `videoio` and `imgcodecs` on Windows pull in Media Foundation and GDI+, and `-DVIDEOIO` is left at its default. What would settle it: whether opencv's own CMake reports a videoio backend, or silently builds a stub. |
| clang-native | WILL BUILD | As above. |

**API level notes.** The four retained modules are core algorithms: filters,
geometric transforms, colour conversion, and the DNN-free parts of videoio.
They call `malloc`, `memcpy` and, for threading, `std::thread`/pthreads — the
Android systems' `-DTHREADS_PREFER_PTHREAD_FLAG=ON` covers the latter. No
API-gated symbol, and the codecs that might have needed one are off.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The declared-dependency / disabled-codec contradiction is the main thing
   to resolve.** Six `require()`s at `generic.lua:1-6`, then four
   `-DBUILD_*=OFF` that make four of them unused. This is not wrong per se —
   requiring a dependency ensures it is *present* in the prefix, and opencv's
   CMake probes for it before the `BUILD_*` switch is honoured — but it means
   the recipe's dependency list does not describe the artifact. A reviewer
   should either drop the unused `require()`s or add a comment saying the
   requires are for configure-time probing only.
2. **`-DBUILD_LIST` also silently drops `highgui`, `calib3d`, `features2d`,
   `dnn` and the rest.** A consumer expecting "opencv" will get four modules.
   That is a legitimate scope decision for a phone prefix, and the recipe
   states it plainly at `:24` — but it belongs in `readme.md` too, since that
   is where a consumer looks first.
3. **`imgcodecs` with every codec off is close to useless.** If the goal is
   image handling, PNG and JPEG are the two that matter on Android, and both
   are in this prefix. Enabling `-DBUILD_PNG=ON -DBUILD_JPEG=OFF` would cost
   nothing extra since `libpng` is already a declared, built dependency. **This
   is the single most actionable observation in this file.**
4. **`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is passed a second time** (`:15`)
   even though every system already puts it in `$CMAKE_FLAGS`. Harmless
   duplication, but it is the kind of thing that makes a reader wonder whether
   the system flag is actually there.
5. **`opencv` is the largest build in this shard by a wide margin**, and
   `cmake --build build --parallel 1` is correct here (`:25`) — parallelising
   an opencv build would be genuinely unhelpful for log readability.
6. **`topackage.md` has no entry for opencv.** The AGENTS.md:228-229 note
   records that opencv was the last recipe still using `-j$(nproc …)` and now
   uses `--parallel 1`, so it has been built. But the backlog does not record
   it. Another dependency-shaped package with no entry.

**How to verify once built.**

- `lib/libopencv_core.a`, `libopencv_imgproc.a`, `libopencv_imgcodecs.a` and
  `libopencv_videoio.a` exist — **exactly four**. Any fifth `libopencv_*.a`
  means `-DBUILD_LIST` is not being honoured.
- `include/opencv4/opencv2/core.hpp` and `core/hal/interface.h` exist.
- `pkg-config --modversion opencv4` reports 4.10.0.
- `$OBJDUMP -f lib/libopencv_core.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libopencv_core.a | grep -cw cv::Mat` non-zero.
- **The codec check:**
  `llvm-nm -u lib/libopencv_imgcodecs.a | grep -cE 'png_|jpeg_|TIFF_|WebP'`
  must be **0** with the current flags, and **non-zero** if a reviewer enables
  PNG. That is the check that ties risk 1 and risk 3 together.
- `ls $OUT/bin/` must be empty; `$OUT/share/facecascade/` (from the data
  files) may be present, which is data and fine.
