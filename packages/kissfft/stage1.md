# kissfft build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 131.2.0 (GitHub tag archive — upstream ships **no release
  asset at all**; `api.github.com/repos/mborgerding/kissfft/releases` returns
  empty `assets` for 131.2.0, 131.1.0 and v131)
- Build system: **cmake only** (`cmake_minimum_required(VERSION 3.10)` at
  `CMakeLists.txt:35`). There is no `configure` and no `configure.ac`; the
  tree also ships a hand-written `Makefile`, which this recipe does not use.
- Config template: none. cmake has no `AC_CONFIG_HEADERS` equivalent here.
- Installs: static **`libkissfft-double.a`** (not `libkissfft.a` — see
  risk 4), `kiss_fft.h`, `kissfft.hh`, `kiss_fftnd.h`, `kiss_fftndr.h`,
  `kiss_fftr.h` (`CMakeLists.txt:298-304`), **`kissfft-double.pc`**
  (`KISSFFT_PKGCONFIG` defaults ON, `CMakeLists.txt:49`) and three cmake
  package-config files.
  The two output names carry the datatype because `CMakeLists.txt:72` sets
  `KISSFFT_OUTPUT_NAME = kissfft-${KISSFFT_DATATYPE}`; the recipe pins
  `-DKISSFFT_DATATYPE=double` so that name cannot drift with an upstream
  default change.
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
4. **The artifact names carry the datatype, so the datatype must be pinned.**
   This is the defect that produced the REJECT, and it is worth stating
   precisely because nothing in the tree's naming looks unusual. `KISSFFT_DATATYPE`
   defaults to `float` (`CMakeLists.txt:44`) and flows into **both** output
   names: `CMakeLists.txt:72` sets
   `KISSFFT_OUTPUT_NAME = kissfft-${KISSFFT_DATATYPE}`, which becomes the
   archive via `set_target_properties(... OUTPUT_NAME ...)` at
   `CMakeLists.txt:232-235` and the pkg-config file name at
   `CMakeLists.txt:339-341`. So the build produces `libkissfft-float.a` and
   `kissfft-float.pc` — **not** `libkissfft.a` and `kissfft.pc` — and
   `kissfft.pc.in:9` expands `Libs:` to `-l@KISSFFT_OUTPUT_NAME@`. The recipe
   now pins `-DKISSFFT_DATATYPE=double`, which both gives a conventional
   double-precision library and stops the name drifting if upstream changes
   its default. `CMakeLists.txt:59-64` validates the value, so `double` is a
   legal choice.
5. **The `.pc` reports 131.1.0, not the 131.2.0 tag.** `CMakeLists.txt:29`
   builds `project(kissfft VERSION "${MAKEFILE_EXTRACTED_VERSION}")` out of
   the shipped `Makefile`, whose `KFVER_MAJOR/MINOR/PATCH` are
   `131`/`1`/`0` (`Makefile:20-22`). Upstream tagged 131.2.0 without bumping
   `KFVER_PATCH`. This is an upstream inconsistency, not a build defect; see
   the verification section.
6. **`-lm` is recorded only for the native build.** `CMakeLists.txt:245-247`
   is `if(CMAKE_SYSTEM_NAME MATCHES "^(Linux|kFreeBSD|GNU)$" AND NOT
   CMAKE_CROSSCOMPILING) target_link_libraries(kissfft PRIVATE m)`, so
   `clang-native` gets `m` in the link interface and every cross build does
   not. Harmless here — it is a static archive, and `kissfft.pc.in:9` does not
   mention `-lm` either — but it is a native/cross difference worth knowing
   about, and the Android systems already carry `-lm` in `LDFLAGS`.
7. **The GitHub tag archive is acceptable for this package specifically.**
   AGENTS.md rejects it for packages whose build needs a generated `configure`
   (libyaml). kissfft's only build system is cmake and the archive unpacks to
   the full 51-file tree with no submodule content, so there is nothing
   missing. If a future release ever ships a `configure`, prefer it.
8. `topackage.md` lists kissfft under the Windows (mingw-w64) candidates only
   (line 297), but nothing about this package is Windows-specific; it should
   be ticked on the basis of any one successful system.

**How to verify once built.**

- `lib/libkissfft-double.a` exists. **Not** `libkissfft.a` — with the upstream
  default datatype the archive is `libkissfft-float.a`, and the recipe pins
  `double`.
- `include/kiss_fft.h` and the other four headers exist.
- `pkg-config --modversion kissfft-double` reports **131.1.0**, *not* 131.2.0.
  The pinned `version = "131.2.0"` in `source.lua` is the **git tag**, but
  `CMakeLists.txt:29` builds the project version out of the shipped
  `Makefile`, whose `KFVER_MAJOR/MINOR/PATCH` are `131`/`1`/`0`
  (`Makefile:20-22`), so `MAKEFILE_EXTRACTED_VERSION` and
  `@PKGCONFIG_KISSFFT_VERSION@` both carry **131.1.0**. Upstream did not bump
  `KFVER_PATCH` in the Makefile it ships at that tag. **A `.pc` reporting
  131.1.0 on a correct build is not a regression** — the same class of
  upstream inconsistency `packages/lapack/stage1.md` records for LAPACK's
  own CMake version string.
- `pkg-config --libs kissfft-double` must name **`-lkissfft-double`**
  (`kissfft.pc.in:9` expands to `-l@KISSFFT_OUTPUT_NAME@`). If it says
  `-lkissfft-float`, the datatype did not take and the whole prefix is
  mislinked — this is the check that would catch that.
- `$OBJDUMP -f lib/libkissfft-double.a` prints `elf64-littleaarch64` on
  Android.
- `llvm-nm --defined-only lib/libkissfft-double.a | grep -cw kiss_fft` — the
  expected value is **non-zero** (many codelets); stating it as "exists" is
  not enough to catch a truncated archive.
- `find $PREFIX/lib/cmake/kissfft -name '*.cmake' | wc -l` — expected
  **exactly 3**: `kissfft-config.cmake` and `kissfft-config-version.cmake`
  (`CMakeLists.txt:316-317`) plus `kissfft-double-targets.cmake`, whose name
  is built from `${PROJECT_NAME}-${KISSFFT_DATATYPE}${KISSFFT_EXPORT_SUFFIX}`
  (`CMakeLists.txt:311`). Scope it to `kissfft/cmake`, which this package
  owns: `ls $PREFIX/lib` is not a valid scope check because it holds every
  package in the prefix, and `$OUT` no longer exists once the block has
  published.