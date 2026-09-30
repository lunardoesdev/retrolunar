# opus build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.5.2 (downloads.xiph.org)
- Build system: autotools
- Installs: static `libopus.a`, `opus/opus.h`, `opus/opusdefines.h` and
  `opus.pc`. **No tools**: `--disable-extra-programs` removes `opusdemo`,
  `opusenc`, `opusdec` and the rest.
- Requires: `opus@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `--disable-extra-programs` at `generic.lua:6` is the important switch: opus's `opusdemo` and `opusenc` are host programs that would link and, in opus's case, actually *play or write audio files* — nothing that should ever run in a cross build. `--disable-doc` removes the docs build (which invokes a host Doxygen/ogdocbook). What remains is the codec, which is portable C with a runtime CPU-feature check. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. Opus builds on Windows upstream; the SILK and CELT layers have no platform code, only an optional `opus_custom_mode` float path. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. opus's `libopus` calls `malloc`, `memcpy` and libc
math (`-lm`, already in every Android system's `LDFLAGS` at
`aarch64-android24/generic.lua:79`). The codec selects SSE4.1/AVX/float
code paths with **runtime** CPU detection, not compile-time flags — so the
same archive runs on any target, and this is one of the few packages in the
shard where nothing at all is architecture-gated. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **A single `.pc` and a single archive means one link obligation**, and it
   is only `libm` — the simplest case in the shard. Still worth checking that
   `opus.pc`'s `Libs.private` names `m`, because opus's `math_*` calls are
   exactly the Bionic case the tree's `-lm` policy exists for.
2. **`--disable-doc` (singular) is correct for opus**, whose configure spells
   it that way, unlike most projects' `--disable-docs`. A reviewer comparing
   this recipe to `libvorbis`'s `--disable-docs` should not "fix" it. The
   recipe passes `--disable-doc` and `--disable-extra-programs`, both correct.
3. **opus is a sibling of libogg/libvorbis in the Xiph lineage but, unlike
   them, it does not depend on libogg.** That is correct — opus is
   self-contained. Worth a reviewer confirming there is no missing
   `require("libogg")`, since the lineage makes it easy to assume.
4. **`--disable-shared --enable-static` is the house pattern** and correct.
5. **`topackage.md` has no entry for opus**, and nothing in the tree
   `require()`s it. So it is a standalone with no recorded build — the same
   standing as lame, mbedtls, libwebp and lua.
6. `make -j1` is present at `:9` — correct.

**How to verify once built.**

- `lib/libopus.a` exists; `include/opus/opus.h` exists.
- `pkg-config --modversion opus` reports 1.5.2.
- `pkg-config --static --libs opus` should name `m` (or `-lm`).
- `$OBJDUMP -f lib/libopus.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libopus.a | grep -cw opus_encode` non-zero.
- **`ls $OUT/bin/` must be empty** — no `opusdemo`, no `opusenc`, no
  `opusdec`. Their presence means `--disable-extra-programs` regressed, and
  `opusdemo` is a program that *plays audio*, so it is emphatically something
  that must never be run here.
- A useful extra check: `llvm-nm -u lib/libopus.a | grep -cw '_mm_'` should be
  **zero**, confirming the SIMD paths use runtime dispatch and intrinsics
  rather than hard-coded x86 intrinsics that would not compile for aarch64.
