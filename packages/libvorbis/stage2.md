ACCEPT

# libvorbis — stage 2 review

## What the recipe gets right

- **`make -j1` at line 10** — serialised correctly.
- The guard at line 8 is the standard form; `libvorbis` ships a top-level
  `config.h.in`.
- `--disable-docs --disable-examples` are real switches keeping the docs and
  the `oggenc`/`ogg123` tools out of the build.
- `require("libogg")` puts ogg in the queue first, so ogg is in `$PREFIX`.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## One thing the forecast must confirm

`--disable-docs` keeps vorbis's own doc target out, but vorbis generates C
from documentation comments with a **Perl** script at build time. The recipe
requires no perl. Either upstream skips the generator when docs are disabled,
or this needs `require("perl@native")` added — the forecast should say which,
because a hidden host-tool dependency fails at `make -j1` confusingly.
`packages/libxcrypt` and `packages/intltool` handle the same situation by
requiring `perl@native` explicitly.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libvorbis.a`, `libvorbisenc.a` | `ls $PREFIX/lib/libvorbis*.a` — two static archives |
| `$PREFIX/include/vorbis/codec.h` | `test -f $PREFIX/include/vorbis/codec.h` |
| `$PREFIX/lib/pkgconfig/vorbis.pc` | `pkg-config --modversion vorbis` |
| no CLI tools | `find $PREFIX/bin -name "oggenc"` → empty |
| ogg really linked | `llvm-nm --undefined-only $PREFIX/lib/libvorbis.a \| grep -c ogg_` → non-zero |
