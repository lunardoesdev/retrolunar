# libjpeg-turbo forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.0.4 (GitHub release asset)
- Build system: CMake
- Installs: static `libjpeg.a` (and `libturbojpeg.a`),
  `jpeglib.h`/`jmorecfg.h`/`jerror.h`/`jconfig.h`, and `libjpeg.pc` plus
  `libturbojpeg.pc`. No tools: `cjpeg`, `djpeg`, `jpegtran`, `rdjpgcom`,
  `wrjpgcom` are **not** built by this recipe, because libjpeg-turbo 3.x does
  not install them unless `WITH_TOOLS=ON`.
- Requires: `libjpeg-turbo@source` only. No dependencies (NASM is a *build*
  tool and is not declared; see risks).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `ENABLE_SHARED=OFF` / `ENABLE_STATIC=ON` at `generic.lua:6` gives the static archive this prefix wants. `WITH_JPEG8=ON` builds the libjpeg v8 ABI, which older consumers need. No tests and no tools are requested, so nothing is executed. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. libjpeg-turbo is heavily exercised on Windows upstream. The one consideration is that SIMD is selected by the compiler at build time rather than by NASM on this platform, so no assembler is involved. |
| clang-native | WILL BUILD | As above. |

**API level notes.** libjpeg-turbo is freestanding C with no libc dependency
beyond `stdio`/`malloc`, and in SIMD paths not even much of that. No API-gated
symbol. `armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **NASM is a build-time requirement that the recipe does not declare and
   that is not in this prefix.** libjpeg-turbo's CMake looks for NASM to
   assemble the x86 SIMD routines when the compiler is not the one it
   recognises. For **aarch64 and armv7a there is no NASM path at all** (NEON
   is written in intrinsics), so those rows are safe. For **x86_64 and i686**
   — including `x86_64-android35` and `clang-native` — a missing NASM means
   either a configure error or, more likely, a silent fall back to the
   non-SIMD routines. Either way the library is *correct*, just slower. This is
   worth knowing: it is a performance characteristic, not a correctness one,
   and no `.pc` or header will reveal it. Check the configure log for whether
   SIMD was enabled.
2. **This is a dependency of four other packages in the tree** — `lcms2`,
   `libtiff`, `opencv` and (transitively) `minizip-ng`. So a silent failure
   here has a wide blast radius. It is a good candidate for a first build.
3. **`WITH_JPEG8=ON` is a deliberate ABI choice**, not a workaround: it keeps
   v8-compatibility entry points for consumers that need them. Worth keeping.
4. **The recipe does not set `WITH_TOOLS=OFF` explicitly.** In 3.0.4 the
   default is off, so nothing is built — but as with other recipes here,
   passing it explicitly would document that the omission is deliberate rather
   than relying on an upstream default.
5. **`topackage.md` has no entry for this package**, yet four recipes
   `require()` it. So it is load-bearing and unrecorded. It must be building —
   those four packages are marked `[x]` — but the backlog is out of date.
   Worth flagging: a dependency with no entry is a dependency nobody reviews.

**How to verify once built.**

- `lib/libjpeg.a` and `lib/libturbojpeg.a` exist.
- `include/jpeglib.h`, `include/jmorecfg.h`, `include/jconfig.h` exist.
  **`jconfig.h` is the one to check** — it is generated per target and
  records `BITS_IN_JSAMPLE` and the ABI version, so it is the file that proves
  this is a target-correct build rather than a copied header.
- `pkg-config --modversion libjpeg` reports 3.0.4.
- `$OBJDUMP -f lib/libjpeg.a` prints `elf64-littleaarch64` on Android.
- `grep JPEG_LIB_VERSION include/jconfig.h` confirms the v8 ABI switch took.
- `ls $OUT/bin/` must be empty — a `cjpeg` here means the tools got enabled.
