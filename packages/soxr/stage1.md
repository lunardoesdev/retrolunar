# soxr build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: **0.1.3**, from the git tag `0.1.3` of
  `github.com/chirlu/soxr`
- Build system: **CMake** (`generic.lua`). soxr ships no autotools build, so
  there is no `configure` and no config header template at all. (The tree
  does contain `soxr-config.h.in`, consumed by `configure_file` at
  `CMakeLists.txt:260-262`, but that is the cmake path and needs no guard.)
- Requires: `soxr@source` only (`generic.lua:1`). No package dependencies —
  soxr needs nothing but a C compiler and libm.

## Version pin

0.1.3 is the current stable release and the newest tag in the repository. The
SourceForge release asset `soxr-0.1.3-Source.tar.xz` is unreachable from here
(SourceForge returns HTTP 522 on every mirror host), so the recipe fetches the
GitHub tag archive for the same tag. It is a complete buildable tree: 137
files, `CMakeLists.txt` 10,112 bytes, `src/CMakeLists.txt` 3,705 bytes,
`gzip -t` clean.

## What gets installed

- `lib/libsoxr.a` (`src/CMakeLists.txt:79`)
- `lib/libsoxr-lsr.a` (`src/CMakeLists.txt:103`, from
  `WITH_LSR_BINDINGS`, ON)
- `include/soxr.h`, `include/soxr-lsr.h` (the `PUBLIC_HEADER` properties at
  `src/CMakeLists.txt:86` and `:110`)
- `lib/pkgconfig/soxr.pc` (`src/CMakeLists.txt:92`), generated from
  `src/soxr.pc.in`
- `lib/pkgconfig/soxr-lsr.pc` (`src/CMakeLists.txt:116`)
- `share/doc/libsoxr/README`, `share/doc/libsoxr/LICENCE`,
  `share/doc/libsoxr/NEWS` (`CMakeLists.txt:269-273`, with
  `DOC_INSTALL_DIR` set at `:238-244`)

**Data files loaded from the prefix: none.** soxr is a pure resampler; it
reads no tables from an install prefix. The three `share/doc/libsoxr/` files
are documentation.

## Verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | C only: `project (soxr C)` at `CMakeLists.txt:6` and `add_library` at `src/CMakeLists.txt:79`; no C++ is required because `BUILD_EXAMPLES` is off, which is the only thing that calls the second `project()` at `:104`. The compiled set is the `SOURCES` list at `src/CMakeLists.txt:41-73` — `soxr.c`, `data-io.c`, the `cr`/`fft4g64`/`dbesi0`/`filter` engines and the SIMD variants, all plain C99-era C. A grep of `src/` and `include/` for `pthread_create`, `nl_langinfo`, `mktime_z`, `posix_spawn`, `O_BINARY`, `mblen`, `getpass`, `process_vm_readv` and `POSIX_MADV_*` returns **no hits**, so no API gate applies at any level. Nothing is compiled or run on the host: the `vr-coefs` generator is skipped because `src/vr-coefs.h` exists (see risk 2). |
| aarch64-android24 | WILL BUILD | As above. Nothing in the source reaches an API-26 or API-28 gate. |
| aarch64-android35 | WILL BUILD | As above. `check_library_exists (m pow "" NEED_LIBM)` at `CMakeLists.txt:97` succeeds — the Android systems already carry `-lm` in `LDFLAGS`, and the NDK sysroot has `libm.so` at every API level including 21. |
| x86_64-android35 | WILL BUILD | As above. SIMD selection is by `find_package(SIMD32/SIMD64)` (`CMakeLists.txt:119-127`) over `SetSystemProcessor.cmake`, which derives from `CMAKE_SYSTEM_PROCESSOR`; an unrecognised processor simply leaves `WITH_CR32S`/`WITH_CR64S` off and falls back to the scalar engines at `src/CMakeLists.txt:31-39`. No row is blocked by architecture. |
| x86_64-mingw | WILL BUILD | As above, and the two paths that could have broken are both inert here. `src/CMakeLists.txt:89` skips installing `soxr.pc`/`soxr-lsr.pc` under `NOT WIN32`, so a mingw prefix gets no `.pc` and consumers must link `-lsoxr` or use the header directly — worth knowing, not a build failure. The `MINGW` OpenMP workaround at `CMakeLists.txt:112-115` is unreachable because `WITH_OPENMP=OFF`. |
| clang-native | WILL BUILD | As above. `BUILD_LSR_TESTS` is suppressed by `NOT CMAKE_CROSSCOMPILING` (`CMakeLists.txt:73`) but the recipe passes `-DBUILD_LSR_TESTS=OFF` so the native build is not the one place the flag set differs. |

`armv7a`/`i686` Android behave as `aarch64-android21`: the recipe contains no
`case $HOST_ARCH`, and every decision soxr makes is a cmake option passed
explicitly or a `find_package` that fails the same way on all Android levels.

## API level

**No new wall.** soxr is the cleanest of the three. Its only time-related
code is the optional high-precision clock (`WITH_HI_PREC_CLOCK`,
`CMakeLists.txt:75`, ON by default), which uses `clock_gettime` — present in
Bionic from API 21, not one of the gated calls. No `mktime_z`, no
`nl_langinfo`, no `posix_spawn`, no `iconv`.

## Risks / what a reviewer should check

1. **`-DBUILD_TESTS=OFF` is the load-bearing flag.** `BUILD_TESTS` defaults ON
   (`CMakeLists.txt:43`), and `tests/CMakeLists.txt` ends with
   `file (GLOB SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/*.c)` followed by an
   `add_executable` per file — five target binaries for a library package.
   Turning it off also removes the `add_subdirectory (examples)` at
   `CMakeLists.txt:288`, which would otherwise have pulled C++ into a
   `project (soxr C)` build. The `add_custom_target (test-vectors ALL ...)`
   near the end of `tests/CMakeLists.txt` is separately guarded by
   `NOT CMAKE_CROSSCOMPILING`, so it would have been safe on Android — but
   `BUILD_TESTS=ON` would still have compiled the five binaries, so the guard
   is not a reason to leave the option on.
2. **No host program is compiled or run — verified, and it is a real trap.**
   `src/CMakeLists.txt:8-17` compiles `vr-coefs.c` into an executable and
   runs it to generate `vr-coefs.h`. That would be a target binary executed
   on an x86 build host, which this tree forbids outright. It does not
   happen, because the guard is `if (NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/vr-coefs.h)`
   and the release ships that header: `src/vr-coefs.h` is present at
   **5,336 bytes** and `src/vr32.c:14` includes it. If a future release ever
   dropped that header from the tarball, this recipe would start building and
   running a host program on every cross build. A reviewer should keep the
   header's presence in mind when bumping the version.
3. **`-DBUILD_SHARED_LIBS=OFF` is required, not cosmetic.** The option is a
   `cmake_dependent_option` defaulting ON (`CMakeLists.txt:48-50`), and
   `src/CMakeLists.txt:213-219` picks `SHARED` over `STATIC` on top of it.
   `-fvisibility=hidden -DSOXR_VISIBILITY` is added only under
   `cmake_dependent_option(VISIBILITY_HIDDEN ... "BUILD_SHARED_LIBS" OFF)`
   (`CMakeLists.txt:170-176`), so a leaked shared build would also silently
   change the compiled visibility. Turning it off keeps the archive's symbol
   set the plain public API.
4. **`-DWITH_OPENMP=OFF` removes a host-dependent variable.** `WITH_OPENMP`
   defaults ON (`:45`) and `find_package (OpenMP)` at `:107-117` mutates
   `CMAKE_C_FLAGS` when it succeeds. Whether it succeeds depends on the build
   host, so leaving it on would make the compiled output host-dependent. The
   resampler has no threading of its own, so nothing is lost.
5. **`WITH_LSR_BINDINGS` is deliberately left ON.** It builds and installs a
   second archive, `libsoxr-lsr.a`, with its own header and `.pc`. This is
   part of what upstream ships, not test scaffolding. Turning it off is not
   obviously safe either: `src/CMakeLists.txt:124` passes `${LSR}`
   unconditionally to `install (TARGETS ...)`, and with the option off that
   variable is empty, which is a cmake edge the reviewer may want to
   re-check rather than assume.
6. **`BUILD_LSR_TESTS` also guards a second test tree.** `CMakeLists.txt:72-73`
   ties it to `EXISTS ${PROJECT_SOURCE_DIR}/lsr-tests`, which the release
   does carry (`lsr-tests/` is present with its own `config.h.in`). The
   cross-compile guard already excludes it; the explicit flag makes that
   independent of how cmake classifies the build.

## How to verify once built

- `lib/libsoxr.a`, `lib/libsoxr-lsr.a`, `include/soxr.h`, `include/soxr-lsr.h`
- `lib/pkgconfig/soxr.pc` and `lib/pkgconfig/soxr-lsr.pc`; expect the
  `soxr-lsr.pc` **only on non-Windows** targets (`src/CMakeLists.txt:113`)
- `pkg-config --modversion soxr` → `0.1.3`
- `llvm-objdump -f lib/libsoxr.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libsoxr.a | grep -c 'soxr_create'` → **non-zero**,
  proving the engine really compiled in
- `find $PREFIX/lib -name 'libsoxr.so*'` must be **empty** (risk 3)
- `test -f $PREFIX/include/soxr.h && test -f $PREFIX/include/soxr-lsr.h` →
  true, proving `WITH_LSR_BINDINGS` stayed on
- `find $OUT -name 'vr-coefs' -o -name 'vector-gen' | wc -l` → must be **0**,
  scoped to the two host generator names from `src/CMakeLists.txt:12` and
  `tests/CMakeLists.txt`; this is the check that catches risk 2 recurring
- `test -f $PREFIX/share/doc/libsoxr/LICENCE` → true, proving the
  `CMakeLists.txt:269-273` install ran
