ACCEPT

# opencv — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job, per AGENTS.md:226-229.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
  No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- **`-DBUILD_LIST=core,imgproc,imgcodecs,videoio` is the load-bearing flag**
  and is exactly right: opencv builds hundreds of modules by default and the
  module list is the only way to get a prefix-sized subset.
- The disable set is thorough and correctly named: `-DBUILD_TESTS=OFF
  -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOCS=OFF -DBUILD_JAVA=OFF
  -DBUILD_OBJC=OFF -DBUILD_opencv_apps=OFF
  -DBUILD_opencv_java_bindings_generator=OFF`. `-DBUILD_JAVA=OFF` pairs with
  `-DBUILD_opencv_apps=OFF`; leaving the first on would look for a JDK.
- `-DBUILD_PNG=OFF -DBUILD_JPEG=OFF -DBUILD_TIFF=OFF -DBUILD_WEBP=OFF
  -DWITH_TIFF=OFF` are mutually consistent, and note that `-DBUILD_*` and
  `-DWITH_*` are **different option families** in opencv — mixing them is a
  common mistake and this recipe does not.

## Two things to flag

1. **`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` duplicates what the system already
   provides.** `packages/aarch64-android24/generic.lua:128` sets it in
   `$CMAKE_FLAGS` already. Harmless (cmake takes the last value) but it is a
   system flag restated in a recipe, the pattern AGENTS.md:211-212 warns about.
   Drop it from here — *unless* opencv's own `CMakeLists.txt` sets a policy
   version before `$CMAKE_FLAGS` is read, in which case a comment saying so is
   required. The forecast should settle which.

2. **`require("libtiff") require("libwebp") require("openjpeg")` with
   `-DBUILD_TIFF=OFF -DBUILD_WEBP=OFF`** means three packages are built and
   installed but unused by their one consumer here. Not a defect — all three
   are backlog entries in their own right — but the forecast should note it so
   nobody assumes opencv validates them.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libopencv_core.a`, `imgproc`, `imgcodecs`, `videoio` | `ls $PREFIX/lib/libopencv_*.a` — four archives, matching `-DBUILD_LIST` |
| `$PREFIX/include/opencv4/opencv2/core.hpp` | `test -f $PREFIX/include/opencv4/opencv2/core.hpp` — note the `opencv4` versioned dir, which moves with the ABI major |
| `$PREFIX/lib/pkgconfig/OpenCV.pc` | `pkg-config --modversion opencv4` — the pkg-config module is `opencv4`, not `opencv` |
| no apps | `find $PREFIX/bin -name "opencv_version"` → empty, proving `-DBUILD_opencv_apps=OFF` took |
| no Java | `test ! -e $PREFIX/share/java`, proving `-DBUILD_JAVA=OFF` took |
