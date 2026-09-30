# libvorbis

libvorbis is Xiph's fully open, royalty-free codec for lossy audio. It is
not "Ogg Vorbis": Ogg is the container (libogg), Vorbis is the codec. Its
selling point is quality at a given bitrate — at 128 kbps a well-tuned
Vorbis encode is hard to beat, and it costs nothing to ship.

Three libraries come with it:

- `libvorbis` — decoding.
- `libvorbisenc` — encoding, and the only one with tuning knobs.
- `libvorbisfile` — the convenience layer that reads and writes Ogg Vorbis
  files for you.

Decoding is a straightforward three-state loop:

```c
#include <vorbis/codec.h>
#include <vorbis/vorbisfile.h>

vorbis_info vi;
vorbis_info_init(&vi);
if (vorbis_decode_init(&vi, channels, rate)) { /* not a Vorbis stream */ }

vorbis_dsp_state vd;
vorbis_block vb;
vorbis_dsp_init(&vd, &vi);
vorbis_block_init(&vd, &vb);

float **pcm;
int samples;
while (vorbis_synthesis_pcmout(&vd, &pcm, &samples) == 0) {
    /* pcm[0..1] hold interleaved-free float samples, 'samples' of them */
    vorbis_synthesis_read(&vd, samples);
}
```

`vorbisfile.h` is the shorter path if you are only reading or writing files:
`ov_read_float` gives you a block of floats and handles seeking and headers
for you.

## What retrolunar builds

All three static libraries, the `vorbis/` headers, `vorbis.pc`,
`vorbisenc.pc` and `vorbisfile.pc`. Built against the libogg in this prefix,
with the bundled `ogg123`/`oggdec` tools and the examples off: they are host
programs.

## Using it

```sh
pkg-config --cflags --libs vorbis            # decode
pkg-config --cflags --libs vorbisenc         # encode
pkg-config --cflags --libs vorbisfile        # files
```

For Ogg Vorbis in an Ogg stream, pair it with libogg explicitly; the
pkg-config files pull it in transitively.

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`, plus
  `--with-pic` so the archives link into shared objects, and `--disable-docs`
  to skip the manual formats, which need sphinx or xmlto and are of no use
  here.
- Encoding pulls in `libvorbisenc`, which is noticeably larger than the
  decoder. A player that never encodes can link only `libvorbis`.
