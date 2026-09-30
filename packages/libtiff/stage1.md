# libtiff forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.7.0 (download.osgeo.org)
- Build system: CMake
- Installs: static `libtiff.a`, the `tiff*.h` headers, and `libtiff-4.pc`.
  Tools, tests, contrib programs and docs are all off.
- Requires: `zlib` (exists), `libjpeg-turbo` (exists). The recipe enables
  `-Djpeg=ON -Dlzma=ON`; it does **not** `require("xz")`, see risks.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Eight switches do the work, and they are the right eight. `-Dtiff-tools=OFF` removes the 20-plus command-line utilities; `-Dtiff-tests=OFF` removes the test suite; `-Dtiff-contrib=OFF` removes the contrib programs (`tiffcrop`, `tiff2pdf`, …); `-Dtiff-docs=OFF` removes the doc build. Then `-Dwebp=OFF -Dlibdeflate=OFF -Dzstd=OFF` drop three optional compression dependencies that are not declared in the `require()` list, so meson/cmake cannot accidentally find host copies, and `-Dlerc=OFF` disables the very experimental codec. `-Dlzma=ON -Djpeg=ON` keep the two declared deps. `-DBUILD_SHARED_LIBS=OFF` is the standard. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | UNCERTAIN | The switches are all fine, and libtiff builds on Windows upstream. The question is whether cmake finds this tree's `libjpeg-turbo` and `liblzma` for a PE target — both are in the prefix, and `$CMAKE_PREFIX_PATH` is set by the system, so it should. What would settle it: whether the configure log reports JPEG and LZMA support as found. |
| clang-native | WILL BUILD | As above. |

**API level notes.** libtiff's core is portable C. The JPEG and LZMA
dependencies are in the prefix and build for every system. No API-gated
symbol. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`-Dlzma=ON` with no `require("xz")` is an undeclared dependency edge.**
   The recipe uses liblzma but never declares it, so the build only succeeds
   because `xz` happens to be in the prefix and the system's
   `PKG_CONFIG_LIBDIR`/`CMAKE_PREFIX_PATH` point there. If `xz` is ever removed
   from the tree, this breaks with nothing in the recipe to explain why. A
   `require("xz")` would make the edge honest. The same is true of
   `libjpeg-turbo`, which *is* declared — so the omission for `xz` looks like
   an oversight rather than a decision.
2. **`-Dzstd=OFF` while this tree has `zstd` is a real choice, not an
   oversight**, and it is defensible: zstd's libtiff support has had
   correctness problems and this tree clearly wants the dependency set
   minimal. But a reviewer should know the option *is* available, because
   turning it on later is a one-word change.
3. **libtiff 4.7.0 is not the newest libtiff** (4.7.x is the current series,
   but 4.8/5.x pre-releases exist). Worth a look when this is next updated.
4. **The tool set is large and entirely host-side**, and
   `-Dtiff-tools=OFF` is what keeps it out. Every other recipe in this shard
   that disables its tools says so in a comment; this recipe's comment is
   implicit in the switch list. Adding one line of comment would help.
5. **`topackage.md` has no entry for libtiff**, yet `lcms2` and `opencv` both
   `require()` it. Load-bearing and unrecorded — the same gap as libpng and
   libjpeg-turbo.
6. `cmake --build build --parallel 1` is correct (`:11`).

**How to verify once built.**

- `lib/libtiff.a` exists; `include/tiffio.h` and `include/tiffvers.h` exist.
- `pkg-config --modversion libtiff-4` reports 4.7.0.
- `$OBJDUMP -f lib/libtiff.a` prints `elf64-littleaarch64` on Android.
- `pkg-config --static --libs libtiff-4` must name **both** the JPEG and the
  LZMA libraries. A missing one is a consumer link failure that this build
  will not reveal.
- `llvm-nm -u lib/libtiff.a | grep -c 'jpeg_\|lzma_'` non-zero, proving the
  codecs really compiled in rather than being stubbed.
- `ls $OUT/bin/` must be empty — a `tiffcp` here means `-Dtiff-tools=OFF`
  regressed.
- `ls $OUT/share/` must not contain a `doc/` directory.
