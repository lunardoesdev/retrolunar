# libwebp forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.4.0 (git tag archive)
- Build system: CMake
- Installs: static `libwebp.a`, `libwebpdemux.a`, `libwebpmux.a`,
  `libwebpdecoder.a`, the `src/webp/` headers, and `libwebp.pc`,
  `libwebpmux.pc`, `libwebpdemux.pc`. **All command-line tools are off.**
- Requires: `libwebp@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Eight switches, all of them turning something **off** that would otherwise be a host program: `WEBP_BUILD_CWEBP`, `DWEBP`, `IMGWEBP`, `VWEBP`, `GIF2WEBP`, `ANIM_UTILS`, `WEBPINFO`. The last three switches are the subtle ones: `WEBP_BUILD_LIBWEBPMUX=OFF` and `WEBP_BUILD_LIBWEBPDEMUX=OFF` drop the muxing and demuxing *libraries*, not just tools. This is a deliberate scope reduction — the prefix wants the codec, not the container plumbing — and it is worth a reviewer's attention because it changes the *artifact set*, not just the binary set. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. libwebp builds cleanly on Windows upstream, and with every tool off there is nothing platform-specific left. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. libwebp's core is freestanding C — it is the
reference implementation other codecs measure against, and it deliberately
avoids libc beyond `malloc`/`free`. No API-gated symbol, no assembler
requirement. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`WEBP_BUILD_LIBWEBPMUX=OFF` and `WEBP_BUILD_LIBWEBPDEMUX=OFF` reduce the
   deliverable, and nothing in the recipe explains why.** Every other switch is
   obviously "a host program off". These two remove *libraries* that a consumer
   of animated or demuxed WebP would need. If the intent is "the prefix ships
   the codec only", that is a reasonable scope decision — but it belongs in a
   comment, and the recipe's single comment line (`:6-11`) does not mention it.
   This is the most substantive thing a reviewer should decide here.
2. **`opencv` in this tree `require()`s `libwebp`** but the opencv recipe
   passes `-DBUILD_WEBP=OFF` and `-DWEBP_BUILD_...` (see
   `packages/opencv/generic.lua:16-17`), so opencv does not actually link it
   either. **libwebp currently has no consumer in the tree.** Combined with the
   missing `topackage.md` entry, that makes it a candidate either for building
   once to confirm or for dropping.
3. **Four archives means four `.pc` files and a link-order obligation.**
   `libwebpmux.a` and `libwebpdemux.a` both need `libwebp.a`; with those two
   off here, only `libwebp.a` and `libwebpdecoder.a` should appear. Verify the
   install actually produced only what the switches imply — if
   `libwebpmux.a` is present, the switch did not take.
4. **`-DBUILD_SHARED_LIBS=OFF` is the house convention** and correct. libwebp
   is the kind of library a consumer might want to link statically into a
   shipped binary, which this prefix's static-everywhere policy serves well.
5. `cmake --build build --parallel 1` is correct (`:13`).
6. **`topackage.md` has no entry for libwebp.** It is a dependency-shaped
   package with no recorded build — the same gap as libpng, libjpeg-turbo and
   libtiff.

**How to verify once built.**

- `lib/libwebp.a` and `lib/libwebpdecoder.a` exist.
- `lib/libwebpmux.a` and `lib/libwebpdemux.a` must **not** exist — their
  presence means the two `LIBWEBP*` switches regressed.
- `include/webp/decode.h` and `include/webp/encode.h` exist.
- `pkg-config --modversion libwebp` reports 1.4.0.
- `$OBJDUMP -f lib/libwebp.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libwebp.a | grep -cw WebPEncode` non-zero.
- `ls $OUT/bin/` must be entirely empty — every tool switch is on, so any
  binary here is a regression.
