# portaudio build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: **19.7.0**, from the git tag `v19.7.0` of
  `github.com/PortAudio/portaudio`
- Build system: **CMake** (`generic.lua`). PortAudio ships both CMake and
  Autotools; the Autotools path is unusable here (risk 1).
- Config template: **none for Autotools.** `configure.in` has no
  `AC_CONFIG_HEADERS` at all, so there is no `config.h.in` to guard.
  The CMake build does ship `cmake_support/options_cmake.h.in` (964 bytes),
  but it belongs to the cmake path, which has no timestamp guard.
- Requires: `portaudio@source` only (`generic.lua:1`). No package
  dependencies.

## Version pin, and why not 19.7.1

The current upstream release is **V19.7.1**, and it is published only on
SourceForge. SourceForge answers **HTTP 522** from this network — probed on
`downloads.sourceforge.net`, `master.dl.sourceforge.net`,
`cytranet-dal`, `phoenixnap` and `altushost-swe` — and no mirror carries
it (`distfiles.gentoo.org`, `sources.buildroot.net` and the Debian pool
`portaudio19_` all 404; the pool only ever had 19.6.0 and 19.7.0). The
upstream file archive at `www.portaudio.com/archives/` and
`files.portaudio.com/archives/` likewise has no 19.7.1 file.

The recipe therefore pins the newest **reachable** release tag, `v19.7.0`,
whose archive is a complete autotools+cmake tree. A reviewer should treat
this as a deliberate, documented deviation from "latest stable", not an
oversight.

## What gets installed

From the CMake install block (`CMakeLists.txt:452-465`), with
`PA_BUILD_STATIC=ON`/`PA_BUILD_SHARED=OFF` and ALSA/JACK off, so
`PA_PUBLIC_INCLUDES` is just `include/portaudio.h`:

- `lib/libportaudio.a` (the static target, `CMakeLists.txt:382`; the shared
  one at `:373` is off)
- `include/portaudio.h`
- `lib/pkgconfig/portaudio-2.0.pc`
- `lib/cmake/portaudio/portaudioConfig.cmake`,
  `lib/cmake/portaudio/portaudioConfigVersion.cmake`,
  `lib/cmake/portaudio/portaudio-targets.cmake`
- `share/doc/portaudio/README.md`, `share/doc/portaudio/LICENSE.txt`
  (`CMakeLists.txt:452-453`)

**Data files loaded from the prefix: none.** PortAudio opens audio devices
through host-API libraries; it reads no tables, presets or sounds from an
install prefix. The two files under `share/doc/` are documentation.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | CMake path, so the `configure.in:393` pthread abort is never reached. Compiled surface is `src/common/*.c` plus `src/hostapi/skeleton/pa_hostapi_skeleton.c` (`Makefile.in:50-60`, and the CMake `PA_SOURCES` list) — ALSA, JACK and OSS are all excluded by `-DPA_USE_ALSA=OFF -DPA_USE_JACK=OFF`, and the Windows-only backends are inside the `IF(WIN32)` block that ends at `CMakeLists.txt:240`. Grep of `src/` and `include/` for `nl_langinfo`, `mktime_z`, `posix_spawn`, `O_BINARY`, `mblen`, `getpass`, `process_vm_readv` and `POSIX_MADV_*` returns **no hits**, so no API gate applies. `stderr` appears only in `src/common/pa_debugprint.c` and `src/hostapi/alsa/pa_linux_alsa.c`, neither of which is compiled (debug output is OFF at `CMakeLists.txt:336`, ALSA is off). See risk 2 for the installed `.pc`. |
| aarch64-android24 | WILL BUILD | As above. No API-26 or API-28 gate is reachable from this source set. |
| aarch64-android35 | WILL BUILD | As above. `libm` is present in the NDK sysroot at every API level, so the `-lm` that `CMakeLists.txt:320` puts in the `.pc` resolves here as well as everywhere else. |
| x86_64-android35 | WILL BUILD | As above. PortAudio's backends are selected by `IF(WIN32)`/`IF(APPLE)`/`ELSEIF(UNIX)` (`CMakeLists.txt:240-323`), never by CPU, so no row is architecture-blocked. |
| x86_64-mingw | WILL BUILD | The `IF(WIN32)` block selects WMME, DirectSound, WASAPI and WDMKS, which link `winmm`, `dsound`, `ole32`, `uuid`, `setupapi` (`CMakeLists.txt:145`, `:166`, `:192-241`) — all present in mingw-w64. ASIO self-disables: `FIND_PACKAGE(ASIOSDK)` (`CMakeLists.txt:149`) finds no SDK, so the `ELSE()` at `:153` sets `PA_USE_ASIO` OFF. `FindASIOSDK.cmake:12` raises `FATAL_ERROR` off Windows, but it is only reached from inside the `IF(WIN32)` block, so Android and native never call it. |
| clang-native | WILL BUILD | As above. |

`armv7a`/`i686` Android behave as `aarch64-android21`: the recipes contain no
`case $HOST_ARCH`, and every PortAudio decision above is made from
`WIN32`/`APPLE`/`UNIX` or from an explicit cmake option.

## API level

**No new wall.** I looked for each gate named in AGENTS.md and for the audio
libraries' own usual ones. The compiled source set reaches no gated symbol at
any API level. PortAudio's only notable platform dependency is pthreads, and
only through the Autotools probe — which is exactly why this recipe does not
use Autotools.

## Risks / what a reviewer should check

1. **The CMake-not-Autotools comment is load-bearing, and both halves were
   checked, not assumed.**
   - The archive ships a **generated** `configure` (575,139 bytes, header
     `Generated by GNU Autoconf 2.69`), so Autotools is available — this is
     not a wolfSSL/Vim-style "inputs but no generated build system".
   - The Autotools *input* is `configure.in` (18,452 bytes), **not**
     `configure.ac`, and the tree uses `[[ ]]` bash-style tests throughout.
   - `configure.in:393` really does hard-error without `-lpthread`.
     **Verified by probe, not by reading:** compiling and linking a
     `pthread_create()` call with the NDK's
     `aarch64-linux-android24-clang` and `-lpthread` fails with
     `ld.lld: error: unable to find library -lpthread`; the same command
     without `-lpthread` links. `find` over the whole NDK sysroot for
     `libpthread*` returns nothing. The identical probe against the host
     `clang` **does** link, which is why `clang-native` would have been fine
     and the four Android rows would not have.
2. **The installed `portaudio-2.0.pc` carries a dead `-lpthread` on every
   Unix target, including all four Android rows.** `CMakeLists.txt:320`
   unconditionally appends `-lm -lpthread` to `PA_PKGCONFIG_LDFLAGS`, and
   `cmake_support/portaudio-2.0.pc.in:11` interpolates it into `Libs:`. The
   *build* is unaffected — `PA_LIBRARY_DEPENDENCIES` (`:321`) reaches only
   `TARGET_LINK_LIBRARIES` (`:377`, `:386`) and a `STATIC` target performs no
   link step — but `pkg-config --libs portaudio-2.0` on Android will hand a
   consumer `-lpthread`, which Bionic cannot satisfy. There is **no cmake
   option** that controls this line, so it cannot be fixed with a flag, and
   editing the generated `.pc` is the `awk`-on-`$OUT` case AGENTS.md permits
   only as an explicitly justified measure. I have left it alone and am
   recording it instead: it is a platform fact, and the Android systems are
   where such facts belong. A reviewer should decide whether to fix the
   generated file or accept it.
   mingw is unaffected — `CMakeLists.txt:320` is inside the `ELSEIF(UNIX)`
   block that starts at `:275`.
3. **`-DPA_USE_ALSA=OFF -DPA_USE_JACK=OFF` are not defaults; they override
   this host.** The build machine has `/usr/include/alsa/asoundlib.h`,
   `/usr/include/jack/jack.h`, `/usr/lib64/libasound.so`, and both `alsa` and
   `jack` resolve through `pkg-config`. Without the two flags, `clang-native`
   would compile `src/hostapi/alsa/pa_linux_alsa.c` and `pa_jack.c` and emit
   a `.pc` naming host audio libraries the target will not have.
4. **No autotools timestamp guard is present, and correctly so.** This is a
   CMake recipe. For the record, had the Autotools path been usable, the
   guard would have been `touch aclocal.m4 configure Makefile.in` and
   **nothing else** — there is no config header template to name. That
   absence is established positively: `find` over the entire 355-file tree
   for `*.in` returns only the 15 files listed below, none of which is a
   config header, and `grep -n AC_CONFIG_HEADER configure.in` exits 1.
   `Makefile.in` is 7,265 bytes, `aclocal.m4` 315,422 bytes, `configure`
   575,139 bytes, all read from a verified-complete extraction.
5. **The Autotools `all` target really would have built 41 programs.**
   `Makefile.in:159` is `all: lib/$(PALIB) all-recursive tests examples
   selftests`, with no conditional. This is the "cross build must not compile
   or run test/example programs" case the brief flagged, and it is why the
   build system choice matters more here than usual.
6. **19.7.0 vs 19.7.1.** See the version section. If SourceForge becomes
   reachable, the bump is a one-line change to `version` and the URL, and the
   recipe's flags should carry over unchanged.

## How to verify once built

- `lib/libportaudio.a`, `include/portaudio.h`, `lib/pkgconfig/portaudio-2.0.pc`
- `pkg-config --modversion portaudio-2.0` → `19`
- `find $PREFIX/lib -name 'libportaudio.so*'` must be **empty** (risk: a future
  release flipping `PA_BUILD_SHARED`'s default; the recipe pins it OFF)
- `llvm-objdump -f lib/libportaudio.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libportaudio.a | grep -c Pa_Initialize` → **1**,
  proving the skeleton backend linked and the library is not empty of API
- `llvm-nm -u lib/libportaudio.a | grep -cE 'snd_pcm_open|jack_client_open'`
  → must be **0**, which is the check that `-DPA_USE_ALSA=OFF
  -DPA_USE_JACK=OFF` did its job and no host audio backend leaked in
- `find $OUT -name 'patest*' -o -name 'paex_*' -o -name 'paqa*' | wc -l`
  → must be **0**: scoped to the package's own binary names, this proves the
  41 host programs of risk 5 were never built
- `grep -c 'lpthread' $PREFIX/lib/pkgconfig/portaudio-2.0.pc` → expect **1**
  on every Unix target. This is the standing record of risk 2; on Android the
  builder should note that a consumer using `pkg-config --libs` will fail to
  link, rather than treating the line as a build regression.
