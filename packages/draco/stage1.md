# draco build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive, cmake only — no Makefile)
- Version pinned: 1.5.7
- Build system: cmake
- Installs: `lib/libdraco.a` (static, encoder + decoder); `include/draco/` headers plus the generated `draco_features.h`; **no pkg-config file**
- Requires: `draco@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | draco is C++11 (`CMAKE_CXX_STANDARD 11` in its `CMakeLists.txt`) and deliberately freestanding: its portability layer uses only `<cstdint>`, `<cstring>`, `<cstdlib>` and, on Windows, `_aligned_malloc`/`_aligned_free` behind `#ifdef _WIN32`. On non-Windows it uses the standard `malloc`/`free` path, so Bionic is fine. `DRACO_TESTS=OFF` (`generic.lua:9`) removes the gtest suite, which is the only place a real platform dependency could hide. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | draco is arch- and endian-neutral; the bitstream reader has explicit endian handling rather than assuming. |
| x86_64-mingw | WILL BUILD | draco has a first-class Windows path, including the `_aligned_malloc` branch and its `.def`/export logic; `BUILD_SHARED_LIBS=OFF` sidesteps any export question anyway. |
| clang-native | WILL BUILD | Native; topackage.md:146 records DRACO 1.5.7 as `[x]` with `elf64-littleaarch64` archive members and no `.pc`. |

## API level notes

**21 is the floor and draco clears it.** draco is the clearest case in the
shard of a project that deliberately keeps itself free of platform
dependencies — its `draco/core/portability.h` exists precisely so the rest
of the tree does not care. The generated `draco_features.h` records the
feature set, not the platform, so the *same* header is installed on every
system; only the `.a` differs.

## Risks / what a reviewer should check

- **`DRACO_TESTS=OFF` is the only option the recipe passes**
  (`generic.lua:9`), and the comment says so. The gtest suite is large and
  would also pull `packages/googletest` into the dependency graph for no
  benefit at build time. Good.
- **The recipe does not disable `DRACO_TRANSCODER_SUPPORTED` or the
  `draco_encoder`/`draco_decoder` test tools** by name. If upstream adds
  more host programs to the default target, they would be built. The
  current 1.5.7 default target is library-only when tests are off, so this
  is fine today.
- **GitHub tag archive, not a release asset.** The comment at
  `generic.lua:6-7` records why: "The tag archive has CMake, not a
  Makefile", and draco publishes no release tarballs with pre-generated
  build files. Correct choice.
- **No `.pc` file**, so consumers link `-ldraco` and pass
  `-DDRACO_...` defines, or use draco's own `draco_features.h`. This is
  recorded in topackage.md:146 and is a real usability cost that the
  readme should carry.

## How to verify once built

- `lib/libdraco.a`
- `include/draco/draco_features.h` (generated) and `include/draco/compression/encode.h`
- `readelf -h lib/libdraco.a` → `Machine: AArch64` on Android targets
- `llvm-nm lib/libdraco.a | grep -c draco_encoder` → non-zero, proving the
  encoder side really compiled
- No `.pc` file; consumers link `-ldraco`
