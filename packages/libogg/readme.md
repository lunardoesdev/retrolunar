# libogg

libogg is the container format that every other Xiph codec uses: Vorbis,
FLAC, Opus, Speex and Theora all carry their packets in an Ogg stream. It
provides framing, CRC and the serial/page/packet demultiplexing that
decoders need, and nothing else — there is no audio or video knowledge in
it at all.

The two halves of the API are `ogg_sync_state` (a byte stream in, pages
out) and `ogg_stream_state` (a logical stream of packets, with sequence
numbers and granule positions):

```c
#include <ogg/ogg.h>

ogg_sync_state oy;
ogg_sync_init(&oy);

char buffer[4096];
char *out = ogg_sync_buffer(&oy, 4096);
size_t got = fread(out, 1, 4096, fp);
ogg_sync_wrote(&oy, got);

while (ogg_sync_pageout(&oy, &og) == 1) {
    ogg_stream_state os;
    ogg_stream_init(&os, serialno);
    ogg_stream_pagein(&os, &og);
    while (ogg_stream_packetout(&os, &op) == 1) {
        /* one codec packet */
    }
}
```

Two rules matter in practice: the buffer you hand to `ogg_sync_buffer` must
be kept alive until you call `ogg_sync_wrote`, and the serial number of a
logical stream must be found by scanning pages if you do not already know
it — pages from different logical streams are interleaved in one file.

## What retrolunar builds

A static `libogg.a`, the `ogg/` headers and `ogg.pc`. The bundled
`ogg123`/`oggz`/`oggdec`/`ogg123` test programs are switched off: they are
host programs and this prefix exists to produce libraries.

## Using it

```sh
pkg-config --cflags --libs ogg
```

## Notes

- Autotools build, so the recipe passes `$AUTOCONF_CONFIGURE_FLAGS` and adds
  only package facts: static, `-fpic`, and the test programs off.
- The Autotools timestamp guard is present because the tarball carries
  mtimes that would otherwise make make re-run `aclocal`.
