# Brotli

Brotli is a general-purpose compression library from Google, designed to
compete with gzip and deflate on the web while compressing more densely. It
ships as three libraries plus two command line tools:

- `libbrotlienc` — the encoder, including the slower Zopfli-based mode.
- `libbrotlidec` — the decoder.
- `libbrotlicommon` — shared dictionary, transforms and helpers.
- `bin/brotli`, `bin/brotlicli` — the command line tools.

The encoder takes a quality level from 0 to 11: 0 is fastest and worst, 11
is slowest and best. Decoding is a single call, so inflating Brotli data is
far cheaper than compressing it.

## What retrolunar builds

Three static libraries, the `brotli/` headers, the pkg-config files
(`libbrotlienc.pc`, `libbrotlidec.pc`, `libbrotlicommon.pc`) and both tools.
Everything is static: a target prefix should not carry a shared object that
nothing on the device will load from the right soname path.

## Using it

```c
#include <brotli/encode.h>

size_t bound = BrotliEncoderMaxCompressedSize(input_size);
uint8_t *out = malloc(bound);
size_t out_size = bound;
if (!BrotliEncoderCompress(BROTLI_DEFAULT_QUALITY, BROTLI_DEFAULT_WINDOW,
                            input_size, input, &out_size, out)) {
    /* out of memory or bad arguments */
}
```

At build time:

```sh
pkg-config --cflags --libs libbrotlienc
```

## Notes

- The build is upstream's CMake, so every flag comes from the system through
  `$CMAKE_FLAGS`: toolchain file, install prefix and search prefix.
- The encoder references `log2()`, which on Android lives in `libm` rather
  than in `libc`. The Android systems therefore put `-lm` in `$LDFLAGS`; a
  hand-rolled link that bypasses those flags needs `-lm` itself.
- The tools are ordinary target programs. retrolunar never runs a target
  binary, so they are built for completeness, not for cross-checking.
