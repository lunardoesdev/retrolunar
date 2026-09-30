# FLAC

FLAC is Xiph's lossless audio codec: it compresses PCM with a predictable
worst case and decodes faster than it is played, which is why it is the
format of choice for archival audio and for lossless containers (Ogg FLAC,
usually with Vorbis or Opus for the lossy part).

The library is a small streaming API: create a decoder or encoder, feed it
`FLAC__StreamDecoderReadCallback` frames, push it.

```c
#include <FLAC/stream_decoder.h>

FLAC__StreamDecoder *dec = FLAC__stream_decoder_new();
FLAC__stream_decoder_init_stream(dec, read_cb, NULL, NULL, NULL, NULL, analysis_cb, NULL);
while (FLAC__stream_decoder_process_single(dec) != FLAC__STREAM_DECODER_END_OF_STREAM) {
    FLAC__int32 samples[4096];
    FLAC__uint32 got;
    FLAC__stream_decoder_process_single(dec);
    FLAC__stream_decoder_read_decoded_pcm(dec, samples, 4096, &got);
}
FLAC__stream_decoder_finish(dec);
FLAC__stream_decoder_delete(dec);
```

Everything is driven by the callback: the library never touches a file
itself, which is what makes it usable in a player, a resampler or a test.

## What retrolunar builds

Static `libFLAC.a` (the C library), `libFLAC++.a` (the C++ stream decoder
wrapper) and `libFLAC++-plugins.a` if the plugins were built, plus the
`FLAC/` headers and `flac.pc`. Built against the libogg in this prefix for
the Ogg mapping layer. The `flac` and `metaflac` command line tools and the
test suite are off: host programs.

## Using it

```sh
pkg-config --cflags --libs flac
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the recipe
  adds only package facts: static, `-fpic`, and the test programs off.
- The C++ wrapper is a convenience, not a separate implementation: it
  forwards to the C library and adds a `std::vector`-based interface.
- For the Ogg container mapping, link `ogg` as well; `flac.pc` records it
  only when the mapping was built, so a program embedding FLAC in Ogg needs
  both on the link line.
