# zlib-ng

zlib-ng is a drop-in replacement for zlib that keeps the same API and adds
hand-written SIMD paths for the functions that dominate real compression:
adler32, crc32, deflate and inflate. On aarch64 it typically compresses
20-40% faster than stock zlib at comparable ratios, which matters when a
protocol or container format forces zlib on you and the zlib on you is slow.

The API is zlib's: `deflateInit2`, `inflate`, `crc32`, `adler32` and the
rest, with the `z_stream` struct unchanged. Two additions are worth knowing:

- `zng_*` prefixed entry points exist for the optimised variants
  (`zng_deflate`, `zng_inflate`).
- `PREFIX` macros let you rename the whole zlib API at compile time, so
  zlib-ng can live in the same binary as stock zlib without a symbol clash.

## What retrolunar builds

`libz-ng.a`, the single `zlib-ng.h` header and `zlib-ng.pc`. Built with
`ZLIB_COMPAT=OFF`, so it exports the plain zlib API: the fastest path for a
consumer that only needs "zlib, but faster".

The upstream examples and the bundled minizip-ng are host programs and are
not built.

## Using it

```c
#include <zlib-ng.h>

z_stream s;
deflateInit2(&s, 9, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);
```

At build time:

```sh
pkg-config --cflags --libs zlib-ng
```

If something links stock zlib by name, keep them apart:

```sh
cc -DPREFIX=zng_ ... $(pkg-config --cflags zlib-ng)
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS`, so the toolchain,
  install prefix and search prefix are the system's business.
- The Android systems put `-lm` in `LDFLAGS`, which matters here: zlib-ng's
  optimised paths call `log2` and friends, and Bionic keeps those in libm.
