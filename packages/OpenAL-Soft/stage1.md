# OpenAL-Soft build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.21.0 (git tag `openal-soft-1.21.0`; newest tag besides
  the `utils` branch marker)
- Build system: CMake
- Installs: static `libopenal.a`, `include/AL/`, `lib/pkgconfig/openal.pc`, a
  CMake package config under `lib/cmake/OpenAL/`, **plus the HRTF data files
  and the AmbDec presets** (`install DIRECTORY hrtf` / `presets`,
  `CMakeLists.txt:1402` and `:1408`). No utilities, no examples, no
  `alsoft.conf` sample.
- Requires: `OpenAL-Soft@source` only.

**Note on the 1.21.0 layout**, because it is not what older docs describe:
there is no `alsoft/` subdirectory any more. The top-level `CMakeLists.txt`
*is* the build (`al`, `alc`, `common`, `hrtf`, `presets`, `resources`,
`router`, `utils`, `examples` all sit at the root).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `ALSOFT_UTILS=OFF` removes `openal-info` and `alsoft-config` (`add_subdirectory(utils/alsoft-config)`, `CMakeLists.txt:1469`), `ALSOFT_EXAMPLES=OFF` removes alplay/alstream, and `ALSOFT_INSTALL_EXAMPLES`/`INSTALL_UTILS` stop them being installed. `LIBTYPE=STATIC` avoids a versioned `.so` a target cannot load, and sets `AL_LIBTYPE_STATIC` on the exported target (`:1209`). The mixer is portable C and C++; its Android backend is `alc/backends/oboe*`/`opensl*`. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above, and the MINGW-specific `ALSOFT_BUILD_IMPORT_LIB` (which its own help text says "requires sed") is already skipped when `LIBTYPE=STATIC` (`CMakeLists.txt:1323`) and is additionally passed OFF. |
| clang-native | WILL BUILD | As above. The Linux backends (ALSA, OSS, PulseAudio, JACK) are probed and each absent one is simply not compiled. |

**API level notes.** None found. OpenAL-Soft's Android backend is the Oboe
wrapper or OpenSL ES, both in the NDK sysroot without an API-level gate. No
`stderr`-as-symbol, `posix_spawn` or `O_BINARY` dependency in what gets built
— the host-side utilities and examples that might use them are off.

**Risks / what a reviewer should check.**

1. **The HRTF and AmbDec data must stay on.** `ALSOFT_INSTALL_HRTF_DATA` and
   `ALSOFT_INSTALL_AMBDEC_PRESETS` are passed `=ON` explicitly. They are
   *data*, not host programs: the library reads them from the prefix at
   runtime, and turning them off yields a library that silently loses spatial
   audio. This is the deliberate asymmetry in the recipe — everything
   executable off, everything data on.
2. **`ALSOFT_INSTALL_CONFIG=OFF` drops `alsoftrc.sample`**
   (`install(FILES alsoftrc.sample ...)`, `CMakeLists.txt:1396`). It is a
   sample configuration file; the library falls back to built-in defaults
   when it is absent. Reasonable, but a reviewer who wants a prefix that is
   *configurable* would turn it back on.
3. **`ALSOFT_UPDATE_BUILD_VERSION=OFF`** stops the build trying to re-derive
   a version from git. A tag archive has no history for it to read. Worth
   confirming the resulting library reports 1.21.0 rather than something odd.
4. **`libopenal.a` is a real archive**, so a wrong-architecture build is
   possible in principle and `$OBJDUMP -f` is a meaningful check here.
5. **The router is already off** (`ALSOFT_BUILD_ROUTER`, default OFF,
   `CMakeLists.txt:123`) and needs no switch. Good: it is experimental and
   creates DLLs.

**How to verify once built.**

- `lib/libopenal.a` exists; `include/AL/al.h`, `alc.h`, `efx.h` exist.
- `lib/pkgconfig/openal.pc` exists and `pkg-config --modversion openal` reports
  1.21.0.
- **`grep AL_LIBTYPE_STATIC lib/pkgconfig/openal.pc` must match** — with
  `LIBTYPE=STATIC` (UPPER CASE: every test is `STREQUAL "STATIC"`, and cmake's
  STREQUAL is case-sensitive, so `Static` matches nothing and the build falls
  through to SHARED at `:1257` *and* leaves the `.pc` without the define),
  `CMakeLists.txt:1173-1174` puts `-DAL_LIBTYPE_STATIC`
  into the `.pc` cflags. Its absence means a consumer gets the
  `__declspec(dllimport)` form of the AL headers and will fail to link.
- `llvm-objdump -f lib/libopenal.a | head -3` prints `elf64-littleaarch64`
  on Android.
- `llvm-nm --defined-only lib/libopenal.a | grep -cw alGetVersion` non-zero.
- `lib/cmake/OpenAL/OpenALConfig.cmake` exists (`install(EXPORT OpenAL ...)`,
  `:1378`).
- `ls $OUT/share/openal/hrtf` (or wherever `install(DIRECTORY hrtf)` lands)
  must be non-empty — an empty HRTF directory means the data switch regressed.
- `ls $OUT/bin/` must be **empty**: no `openal-info`, no `alsoft-config`, no
  `alplay`.
- `test ! -e $OUT/etc/OpenAL/alsoft.conf` — the sample config is off.
