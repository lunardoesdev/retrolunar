ACCEPT

# libwebp — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- `-DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF
  -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF
  -DWEBP_BUILD_ANIM_UTIL=OFF` turns off every CLI tool, and
  `-DWEBP_BUILD_LIBWEBPMUX=OFF -DWEBP_BUILD_LIBWEBPDEMUX=OFF` turns off the
  two extra libraries. This is thorough and correct: those `WEBP_BUILD_*`
  names are upstream's own, and without them `make` would link seven
  programs this prefix does not need.
- `-DBUILD_SHARED_LIBS=OFF` gives the static archive the prefix wants.

## One thing to verify

`packages/opencv/generic.lua` does `require("libwebp")` but then passes
`-DBUILD_WEBP=OFF -DWITH_WEBP=OFF`. So libwebp is built and installed but
unused by its one consumer in this tree. Not a defect — it is in the backlog
in its own right — but the forecast should note it so nobody assumes opencv
exercises it.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libwebp.a` | `ls $PREFIX/lib/libwebp.a` — static, confirming `-DBUILD_SHARED_LIBS=OFF` |
| `$PREFIX/include/webp/decode.h`, `encode.h` | `test -f $PREFIX/include/webp/decode.h` |
| `$PREFIX/lib/pkgconfig/libwebp.pc`, `libwebpmux.pc`, `libwebpdemux.pc` | `pkg-config --modversion libwebp`; only `libwebp.pc` should exist given the two `-OFF` flags |
| no tools | `find $PREFIX/bin -name "cwebp" -o -name "dwebp"` → empty, proving the seven `WEBP_BUILD_*=OFF` flags took |
