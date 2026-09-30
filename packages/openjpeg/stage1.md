# openjpeg build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.5.2 (git tag archive)
- Build system: CMake
- Installs: static `libopenjp2.a`, the `openjpeg-2.5/` headers, and
  `libopenjp2.pc`. **No tools**: `BUILD_CODEC=OFF` removes `opj_decompress`,
  `opj_compress` and the rest of the `bin/` tree.
- Requires: `openjpeg@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Three switches, two of which matter. `BUILD_TESTING=OFF` removes the test suite (a host program suite with data files). `BUILD_CODEC=OFF` removes the seven command-line tools in `bin/` — the important one, because `opj_decompress` is what a human would use to inspect a JPEG 2000 file, and building it here would produce a target binary that can never be run. `BUILD_SHARED_LIBS=OFF` matches the tree. The library itself is self-contained C99 with no dependency beyond libc and `m` — its floating-point code calls `sqrt`/`pow`, and `-lm` is already in every Android system's `LDFLAGS` (`aarch64-android24/generic.lua:79`). |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. openjpeg is portable C with no platform layer. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. openjpeg is one of the cleanest cross-compile
candidates in the tree: `lib/openjp2/` is C99, uses `malloc`/`memcpy`, and its
only libm use is in the DWT (wavelet transform) maths. No API-gated symbol.
`armv7a-android*` and `i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`BUILD_CODEC=OFF` also removes `opj_dump` and `opj_decompress`, which
   means a prefix consumer has no way to validate a file.** That is a
   deliberate, stated trade — the recipe's comment at `:6-7` says "this prefix
   is for libraries". Correct, and worth confirming nobody expected those
   tools.
2. **`libopenjp2.pc` needs `-lm` in `Libs.private` (or `Libs`).** openjpeg's
   cmake does add `-lm` for non-MSVC targets, but this is exactly the class of
   thing to verify: a static archive that needs `libm` on Bionic and whose
   `.pc` omits it builds perfectly and fails at every consumer. Same latent
   class as lcms2, libarchive, libevent, libtiff and minizip-ng — and here it
   is the *platform's* `-lm`, which this tree already insists on
   everywhere else.
3. **No `-DCMAKE_POLICY_VERSION_MINIMUM` is passed** and none is needed: the
   systems' `$CMAKE_FLAGS` already carries it, and openjpeg 2.5.2 declares a
   recent `cmake_minimum_required`. Worth confirming by reading the tarball's
   top-level `CMakeLists.txt` if the first build fails on a policy error.
4. **`BUILD_TESTING` is the cmake-standard name, not an OpenJPEG-specific
   one** — openjpeg's build does honour it. Contrast with abseil, where
   `BUILD_TESTING` is set by `include(CTest)` and the real switch is
   `ABSL_BUILD_TESTING`. Here the name is literal and correct.
5. **`opencv` in this tree `require()`s `openjpeg`, but its recipe turns every
   codec off** (see the opencv forecast), so openjpeg is again a declared
   dependency that is not actually linked. Worth the same reviewer attention as
   that recipe's other five.
6. **`topackage.md` has no entry for openjpeg** — and unlike several others in
   this shard, I have **no evidence it has ever been built here**, because no
   `[x]` entry mentions it and no other package records depending on it in
   practice. This is a candidate for the first build.

**How to verify once built.**

- `lib/libopenjp2.a` exists; `include/openjpeg-2.5/openjpeg.h` exists — note
  the versioned include directory, which is unusual and worth confirming.
- `pkg-config --modversion libopenjp2` reports 2.5.2.
- **`pkg-config --static --libs libopenjp2` must include `-lm`.** That is the
  check for risk 2 and the most important one in this file.
- `$OBJDUMP -f lib/libopenjp2.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libopenjp2.a | grep -cw opj_decode` non-zero.
- **`ls $OUT/bin/` must be empty.** Any `opj_*` binary here means
  `BUILD_CODEC=OFF` regressed, and those are target binaries that must never
  be run.
- `ls $OUT/lib/` should show only the archive; a `.so` means
  `BUILD_SHARED_LIBS=OFF` regressed.
