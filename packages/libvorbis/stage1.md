# libvorbis build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.3.7 (downloads.xiph.org)
- Build system: autotools
- Installs: static `libvorbis.a`, `libvorbisenc.a` and `libvorbisfile.a`,
  the `vorbis/`, `vorbisenc/` headers, and `vorbis.pc` plus `vorbisenc.pc`.
  Docs and examples are off.
- Requires: `libogg` (exists) — a hard link dependency, the Xiph container
  this codec sits on.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-docs --disable-examples` at `generic.lua:9` remove the documentation build (which runs a host `doxygen`/sphinx) and the example programs, both of which would be host programs or would need a host tool. `--enable-static --disable-shared --with-pic` give the three archives. libvorbis is portable C with a hand-written (not NASM) assembly-free inner loop; there is no assembler requirement to trip over on aarch64. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. libvorbis is exercised on Windows upstream; the `vorbisenc` fast paths are selected by the compiler, not by a separate assembler. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. libvorbis uses `malloc`, `stdio` and math
functions; `-lm` is already in every Android system's `LDFLAGS`
(`aarch64-android24/generic.lua:79`), so the `pow`/`log` calls in the window
functions link. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **Three archives, and only one of them is on the default link path.**
   `libvorbisfile.a` pulls in `libvorbisenc.a` and `libogg.a`. A consumer who
   wants the file-level API must link all three, in that order. The `.pc` files
   exist for exactly this, so verify `vorbisfile.pc`'s `Requires` names
   `vorbisenc` and `ogg`. This is the same latent consumer-link class as
   lcms2, libarchive and libevent, and it is the single most likely real
   defect in this recipe.
2. **The `libogg` dependency is real and declared** (`generic.lua:1`),
   unlike kmod's undeclared `xz`. Good.
3. **libvorbis 1.3.7 is a long-stable release** and is what LFS pins. There is
   no 1.4. Worth a check when this is next updated, but not urgent.
4. `--disable-docs` and `--disable-examples` are both upstream-default-off in
   effect, but passing them explicitly matches the house style and documents
   that the docs build (which would need a host sphinx/doxygen) is
   deliberately not run.
5. `make -j1` is present at `:12` — correct.
6. `topackage.md` records this as built: *"static libvorbis, libvorbisenc and
   libvorbisfile; pkg-config --modversion vorbis reports 1.3.7"*. Consistent
   with the three-archive expectation, and it confirms the `.pc` situation is
   at least partially known to work.

**How to verify once built.**

- `lib/libvorbis.a`, `lib/libvorbisenc.a` and `lib/libvorbisfile.a` all exist.
- `include/vorbis/codec.h`, `include/vorbis/vorbisenc.h` and
  `include/vorbis/vorbisfile.h` exist.
- `pkg-config --modversion vorbis` reports 1.3.7.
- `pkg-config --libs vorbisfile` must name `vorbisenc` and `ogg` (or
  `libvorbis`, `libvorbisenc`, `libogg`). A missing one is the consumer
  failure this recipe cannot detect itself.
- `$OBJDUMP -f lib/libvorbisfile.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm -u lib/libvorbisfile.a | grep -c 'ogg_\|vorbis_'` non-zero, proving
  the file layer really references the two archives it needs.
- `$OUT/share/doc` must not exist, confirming `--disable-docs` held.
