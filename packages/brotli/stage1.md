# brotli build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive, not a release asset)
- Version pinned: 1.1.0
- Build system: cmake
- Installs: `lib/libbrotlicommon.a`, `lib/libbrotlidec.a`, `lib/libbrotlienc.a` (static); `brotli/` headers; `lib/pkgconfig/libbrotlicommon.pc`, `libbrotlidec.pc`, `libbrotlienc.pc`; `bin/brotli` (brotli 1.1.0 has exactly one `add_executable`, CMakeLists.txt:172 — there is no `brotlicli`)
- Requires: `brotli@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | All three archives are plain C with no libc dependency beyond `string.h`/`stdlib.h`. The one Bionic-specific fact is `-lm`, and it is already handled at the system level: the recipe comment (`generic.lua:7-8`) and topackage.md:123 both record that brotli's zopfli path calls `log2()`, which Bionic keeps in `libm` rather than `libc`, so the Android systems now carry `-lm` in `LDFLAGS` (aarch64-android21/generic.lua:78-79). Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | brotli is endian- and arch-neutral; no SIMD intrinsics beyond plain C. |
| x86_64-mingw | WILL BUILD | brotli's CMakeLists has no platform gate, and `BUILD_SHARED_LIBS=OFF` means no DLL export machinery is needed. |
| clang-native | WILL BUILD | Native; topackage.md:123 records Brotli 1.1.0 as `[x]` with the `-lm` note and the verified `pkg-config --modversion libbrotlienc` = 1.1.0. |

## API level notes

**API 21 is the floor and brotli clears it with room to spare.** The only
Bionic consideration is `log2` living in `libm`; the systems already solve
it globally with `-lm`, so no recipe-level workaround is needed and none is
present. That is the AGENTS.md-preferred outcome: a libc fact handled in
`packages/<sys>/generic.lua` rather than duplicated per package.

## Risks / what a reviewer should check

- **The `brotli` tool is built and there is no switch to turn it off.**
  `generic.lua:6-8` says so explicitly: upstream 1.1.0 has no option to
  exclude it. It is a *target* binary and nothing runs it. The recipe
  comment says `brotli/brotlicli`; only `brotli` exists. This is a known, accepted cost, not an oversight.
- **The source is the GitHub tag archive** (`archive/refs/tags/v1.1.0.tar.gz`,
  `source.lua:5`) rather than a release asset. For a cmake project that is
  fine — there is no generated script to lose — but it means the recipe has
  no upstream tarball checksum to compare against, which the project
  accepts (no checksums, per AGENTS.md).
- **`-DBUILD_SHARED_LIBS=OFF` is passed but brotli's own CMake option is
  `BUILD_SHARED_LIBS`** — correct here, unlike fribidi where meson's
  equivalent is spelled differently. No issue, just noting the recipe got
  it right.
- **The Android `-lm` dependency is implicit.** If someone moves brotli's
  `log2()` usage behind a new build option that drops the zopfli path, the
  `-lm` in the systems becomes dead weight for every other package too.
  Not actionable, just worth knowing the systems' `$LDFLAGS` is load-bearing
  here.

## How to verify once built

- `lib/libbrotlicommon.a`, `lib/libbrotlidec.a`, `lib/libbrotlienc.a`
- `include/brotli/encode.h`, `include/brotli/decode.h`
- `lib/pkgconfig/libbrotlienc.pc` and `pkg-config --modversion libbrotlienc` → `1.1.0`
- `readelf -h lib/libbrotlienc.a` → `Machine: AArch64` on Android targets
- `bin/brotli` present; there is no `brotlicli` in 1.1.0
