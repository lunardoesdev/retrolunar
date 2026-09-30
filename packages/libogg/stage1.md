# libogg build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.5 (downloads.xiph.org release tarball)
- Build system: autotools
- Installs: static `libogg.a`, `ogg/` headers, `ogg.pc`. The two programs are
  off: `--disable-oggtest` (the bit-exactness checker) and
  `--disable-vorbistest`.
- Requires: `libogg@source` only. No dependencies — it is the base of the
  Xiph chain, and `libvorbis` in this tree requires it in turn.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library is the point: `libogg` is a bitstream container with no dependencies and no platform code at all — it is pure C operating on memory buffers and `FILE*` when asked. `--enable-static --disable-shared --with-pic` at `:9` is the whole configuration, and the two `--disable-*` flags remove the only two executables. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; libogg has a `vorbisfile`-style Windows path but the library core is platform-neutral. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. libogg calls `fopen`/`fread`/`fwrite`/`fseek` and
`malloc` — nothing API-gated, and notably nothing that touches the
`O_BINARY` wall (that is a Windows concern, and the only file-I/O entry points
are the optional `ogg_stream_*` file helpers, which are not what a library
consumer uses). `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **This is the most robust package in the shard and the recipe knows it.**
   The comment at `generic.lua:7-8` states the reasoning — libogg is the
   container every other Xiph codec sits on, so it is built static and the
   programs are off. That is the right call and it is why `libvorbis` can
   `require()` it. Nothing to fix.
2. **Verify the dependency edge actually holds.** `libvorbis/generic.lua:1`
   does `require("libogg")`, so this package is load-bearing for
   `libvorbis` (and, transitively, `opus` is independent but `lcms2` and
   others sit alongside). If `libogg` were to fail, `libvorbis` would fail
   with it. Both are marked `[x]`, so this is currently fine — but it means
   `libogg` deserves more attention than its triviality suggests.
3. **The recipe is not serialised**: `make -j1` **is** present at `:15`. This
   is one of the recipes that gets it right. Contrast kbd, less, libffi,
   intltool, kmod, which use bare `make`.
4. **`--with-pic` is correct and matters.** The archive goes into a shared
   prefix alongside shared libraries, and a non-PIC static object in a `.a`
   can fail to link into a `.so` for a consumer. Keeping it is right.
5. `topackage.md` records this as built: *"static libogg.a; pkg-config
   --modversion ogg reports 1.3.5; archive members are elf64-littleaarch64."*
   Consistent with the recipe.

**How to verify once built.**

- `lib/libogg.a` exists; `include/ogg/ogg.h` exists.
- `pkg-config --modversion ogg` reports 1.3.5.
- `$OBJDUMP -f lib/libogg.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libogg.a | grep -cw ogg_sync_pageout` must be
  non-zero — that is the canonical libogg entry point and its presence proves
  real content.
- `ls $OUT/bin/` must be empty: no `ogg123`, no `oggdec`.
- A consumer check is the strongest one: `pkg-config --libs ogg` resolves, and
  a trivial `ogg_stream_pagein` call links. Do **not** run the result.
