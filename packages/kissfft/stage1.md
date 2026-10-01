# kissfft build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 131.2.0 (GitHub tag archive — upstream ships **no release
  asset at all**; `api.github.com/repos/mborgerding/kissfft/releases` returns
  empty `assets` for 131.2.0, 131.1.0 and v131)
- Build system: **cmake only** (`cmake_minimum_required(VERSION 3.10)` at
  `CMakeLists.txt:35`). There is no `configure` and no `configure.ac`; the
  tree also ships a hand-written `Makefile`, which this recipe does not use.
- Config template: none. cmake has no `AC_CONFIG_HEADERS` equivalent here.
- Installs: static `libkissfft.a`, `kiss_fft.h`, `kissfft.hh`, `kiss_fftnd.h`,
  `kiss_fftndr.h`, `kiss_fftr.h` (`CMakeLists.txt:298-304`), `kissfft.pc`
  (`KISSFFT_PKGCONFIG` defaults ON, `CMakeLists.txt:49`) and a cmake package
  config.
- Requires: `kissfft@source` only. No dependencies.

## Verification of the tree these claims come from

The tag archive is 51 members and unpacks to exactly 51 paths (name-set diff,
zero missing, zero extra). Every file cited below was confirmed non-zero on
disk. This matters here because the two verdicts that could have been wrong
are both absence claims, and `/tmp` on this machine is a tmpfs with an
exhausted user quota that silently truncates writes.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Plain C, libc only. `CMakeLists.txt:123` builds one `add_library(kissfft ...)` from `kiss_fft.c`, `kiss_fftnd.c`, `kiss_fftndr.c`, `kiss_fftr.c` — portable C using `malloc`/`free`/`memcpy`/`sin`/`cos`. No API-gated symbol, no assembly, no host program, no codegen step. `KISSFFT_TEST=OFF` removes the only part of the tree that needs anything external, and `KISSFFT_TOOLS=OFF` removes the `kfc`/`psdpng` programs. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. The library is C with no POSIX dependency; nothing in the build keys off `CMAKE_SYSTEM_NAME`, so our toolchain files' deliberate `Linux` setting is harmless here. |
| clang-native | WILL BUILD | As above. |

**API level notes.** kissfft's libc surface is `malloc`, `free`, `realloc`,
`memcpy`, `memset`, `sin`, `cos` and `printf`. Every one of those is API 21.
The API-21 walls listed in AGENTS.md (`stderr` as a real symbol,
`POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`, `mblen`, `getpass`,
`O_BINARY`) are all absent from kissfft's source. The gates that do bite
elsewhere here — `nl_langinfo` at 26, `iconv.h` at 28, `mktime_z` at 35 — are
absent here too. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **`KISSFFT_TEST` is load-bearing and defaults ON** (`CMakeLists.txt:51`).
   This is not a tidy-up switch: `test/CMakeLists.txt:32` is
   `pkg_check_modules(fftw3 REQUIRED IMPORTED_TARGET ${fftw3_pkg})`, so
   leaving the tests on makes **FFTW a hard configure-time dependency** of
   kissfft through pkg-config. `REQUIRED` means a missing `fftw3.pc` is a fatal
   configure error, not a skipped test. `test/CMakeLists.txt:44` additionally
   builds `testcpp.cc`, a C++ program. Both go away with `KISSFFT_TEST=OFF`.
2. **`KISSFFT_STATIC` is upstream's own switch, not `BUILD_SHARED_LIBS`.**
   `CMakeLists.txt:50` is
   `option(KISSFFT_STATIC "Build kissfft as static (ON) or shared library (OFF)" OFF)`.
   Passing `-DBUILD_SHARED_LIBS=OFF` instead would leave `KISSFFT_STATIC`
   at its OFF default and produce a **shared** `libkissfft.so` in a prefix
   with no loader path for it. The recipe uses the right one.
3. **`cmake_minimum_required(VERSION 3.10)` is above 3.5**, so the
   `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` floor that `$CMAKE_FLAGS` already
   carries is not load-bearing here. Harmless if present; worth knowing it is
   not doing any work, unlike in cjson or glog.
4. **The GitHub tag archive is acceptable for this package specifically.**
   AGENTS.md rejects it for packages whose build needs a generated `configure`
   (libyaml). kissfft's only build system is cmake and the archive unpacks to
   the full 51-file tree with no submodule content, so there is nothing
   missing. If a future release ever ships a `configure`, prefer it.
5. `topackage.md` lists kissfft under the Windows (mingw-w64) candidates only
   (line 297), but nothing about this package is Windows-specific; it should
   be ticked on the basis of any one successful system.

**How to verify once built.**

- `lib/libkissfft.a` exists.
- `include/kiss_fft.h` and the other four headers exist.
- `pkg-config --modversion kissfft` reports 131.2.0.
- `$OBJDUMP -f lib/libkissfft.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libkissfft.a | grep -cw kiss_fft` — the
  expected value is **non-zero** (many codelets); stating it as "exists" is
  not enough to catch a truncated archive.
- `find $OUT -name 'kissfft*' -path '*cmake*'` — the package config is
  expected; `ls $OUT/lib` is not a valid scope check here because it holds
  every package in the prefix.