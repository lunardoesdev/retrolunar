ACCEPT

# libogg — stage 2 review

## What the recipe gets right

- **`make -j1` at line 10** — serialised correctly.
- The guard at line 8 is the standard form; `libogg` ships a top-level
  `config.h.in`, verified in the unpacked tree.
- `--disable-oggtest --disable-vorbistest` at line 9 are real upstream switches
  and correctly keep the example/test programs out — the same class of decision
  libseccomp's reviewer had to require, done here properly.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add

`libvorbis` does `require("libogg")`, so libogg is a **leaf dependency of
libvorbis** here. Whatever verdict it gets propagates; do not treat them as
independent.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libogg.a` | `ls $PREFIX/lib/libogg.*` |
| `$PREFIX/include/ogg/ogg.h` | `test -f $PREFIX/include/ogg/ogg.h` |
| `$PREFIX/lib/pkgconfig/ogg.pc` | `pkg-config --modversion ogg` |
| no test programs | `find $PREFIX/bin -name "oggtest*"` → empty, proving `--disable-oggtest` took |
