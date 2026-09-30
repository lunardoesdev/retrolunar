ACCEPT

# libtiff — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job, per `AGENTS.md:226-229`.
- `cmake -S . -B build $CMAKE_FLAGS` takes every toolchain fact from the
  system; nothing is re-specified and no search flag is exported.
- No `sed`, no patch, no `/dev/null`, **no `DESTDIR`** — plain
  `cmake --install build`, correct because `$CMAKE_FLAGS` already carries
  `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `-Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-contrib=OFF -Dtiff-docs=OFF` is
  exactly the libseccomp-class fix applied correctly: tiff's `tools/`,
  `test/` and `contrib/` subdirectories are real and would otherwise be built.
  Four separate switches for four separate directories is the right thoroughness.
- `-Dwebp=OFF -Dlerc=OFF -Dzstd=OFF -Dlibdeflate=OFF -Dlzma=ON -Djpeg=ON`
  deliberately keeps only the dependencies this tree actually has
  (`xz`, `zlib`, `libjpeg-turbo` are all `require`d).
- `require("zlib")` and `require("libjpeg-turbo")` put those in the queue first.

## What the forecast should add

Note that `-Djpeg=ON` depends on `libjpeg-turbo`, whose recipe is
`packages/libjpeg-turbo/generic.lua` — so this package is gated on it. Also
record that tiff's `.pc` file is `libtiff-4.pc`, whose upstream name
carries the ABI major — a version bump changes it, so the forecast should
warn.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libtiff.a` | `ls $PREFIX/lib/libtiff.a` — static, confirming `-DBUILD_SHARED_LIBS=OFF` |
| `$PREFIX/include/tiffio.h` | `test -f $PREFIX/include/tiffio.h` |
| `$PREFIX/lib/pkgconfig/libtiff-4.pc` | `pkg-config --modversion libtiff-4` |
| no tools installed | `test ! -e $PREFIX/bin/tiffinfo` — proves `-Dtiff-tools=OFF` took |
| jpeg really linked | `llvm-nm --undefined-only $PREFIX/lib/libtiff.a \| grep -c jpeg_` → non-zero |
