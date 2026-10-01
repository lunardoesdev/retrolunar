REJECT

# kissfft 131.2.0 — stage 2 review

Checked against the unpacked `kissfft-131.2.0` tree in `$HOME/dl`. The recipe
is structurally fine, but two artifact-identity errors in the forecast are the
kind a builder trips over on the first command they run.

## Required changes

1. **stage1.md:72 and :75 — the installed archive and `.pc` file are not the
   names the forecast says, and the verification commands cannot match.**

   The forecast says `lib/libkissfft.a` and `pkg-config --modversion kissfft`.
   Neither name is what this build produces. `CMakeLists.txt:45` sets the
   default datatype and `:72` derives the output name from it:

   ```cmake
   45:set(KISSFFT_DATATYPE "float" CACHE STRING "Principal datatype of kissfft: double, float (default), ...")
   ...
   72:set(KISSFFT_OUTPUT_NAME "kissfft-${KISSFFT_DATATYPE}")
   ```

   and `:232-235` applies it:

   ```cmake
   set_target_properties(kissfft PROPERTIES
       OUTPUT_NAME "${KISSFFT_OUTPUT_NAME}"
       EXPORT_NAME "${KISSFFT_OUTPUT_NAME}" ...)
   ```

   With the default `float`, the archive is **`libkissfft-float.a`**, not
   `libkissfft.a`. And `CMakeLists.txt:339-341`:

   ```cmake
   configure_file(kissfft.pc.in "kissfft-${KISSFFT_DATATYPE}.pc" @ONLY)
   install(FILES "${CMAKE_CURRENT_BINARY_DIR}/kissfft-${KISSFFT_DATATYPE}.pc"
           DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
   ```

   so the `.pc` is **`kissfft-float.pc`**, and its own contents agree —
   `kissfft.pc.in:7` is `-l@KISSFFT_OUTPUT_NAME@` → `-lkissfft-float`.

   Concretely: `pkg-config --modversion kissfft` fails with *"Package kissfft
   was not found"*, and `[ -f lib/libkissfft.a ]` is false. Both are listed as
   "how to verify once built" (stage1.md:72, :75). This is the
   AGENTS.md:570-579 failure in its purest form — a check whose filter matches
   only what you expect rather than the real file list, discovered by reading
   `OUTPUT_NAME` instead of assuming it.

   **Required:** either state the real names (`lib/libkissfft-float.a`,
   `pkg-config --modversion kissfft-float`), or pass
   `-DKISSFFT_DATATYPE=double` and state `libkissfft-double.a`. Whichever is
   chosen, the recipe's comment and stage1 must agree — and if a
   datatype-specific name is not wanted, the recipe should pin the datatype
   explicitly so the name does not drift with an upstream default change.

2. **stage1.md:75 — `pkg-config --modversion kissfft` → 131.2.0 is the wrong
   version string independently of the file name.** `CMakeLists.txt:29` builds
   the project version *out of the shipped Makefile*:

   ```make
   export KFVER_MAJOR = 131
   export KFVER_MINOR = 1
   export KFVER_PATCH = 0
   ```

   so `MAKEFILE_EXTRACTED_VERSION` is **`131.1.0`**, and that is what
   `project(kissfft VERSION ...)` and `@PKGCONFIG_KISSFFT_VERSION@` carry. The
   git **tag** is `131.2.0` but upstream did not bump `KFVER_PATCH` in the
   Makefile it ships at that tag. The pinned `version = "131.2.0"` in
   `source.lua` is correct — that is the tag — but the `.pc` will report
   `131.1.0`, and a check expecting `131.2.0` fails on a correct build.

   **Required:** record the expected value as **131.1.0** and note the
   tag/version skew, so the builder does not treat it as a regression. (Same
   class of upstream inconsistency lapack's stage1 flags at stage1.md:99-103
   for its own CMake version string.)

3. **stage1.md:80-81 — a `find` with no assertion, presented as a check.**
   `find $OUT -name 'kissfft*' -path '*cmake*'` — "the package config is
   expected". There is no expected count and no comparison, so it passes
   whether or not anything was installed. Either give it an expected value
   (`→ 3`: `kissfftConfig.cmake`, `kissfftConfigVersion.cmake`,
   `kissfftTargets.cmake`, per `CMakeLists.txt:310-312`) or drop it. The
   adjacent note — that `ls $OUT/lib` is not a valid scope check because it
   holds every package in the prefix — is correct and worth keeping.

## What the recipe gets right

- **CMake only, tag archive only, no release asset.** Confirmed: no
  `configure` and no `configure.ac` in the tree (it does ship a hand-written
  `Makefile`, which the recipe correctly does not use), and the GitHub release
  for 131.2.0 carries no attached asset. The tag archive unpacks to the full
  51-file tree with no submodule content, so nothing is missing — the
  AGENTS.md concern about tag archives applies to packages needing a generated
  `configure`, and this one does not.
- **No config template, so no guard.** Correct, and the recipe has none.
- **`KISSFFT_STATIC` is the right switch, not `BUILD_SHARED_LIBS`.**
  `CMakeLists.txt:50` is
  `option(KISSFFT_STATIC "Build kissfft as static (ON) or shared library (OFF)" OFF)`
  — default **OFF**. Passing `-DBUILD_SHARED_LIBS=OFF` instead would leave
  `KISSFFT_STATIC` at OFF and produce a **shared** `libkissfft.so` in a prefix
  with no loader path for it. The recipe uses the correct one, and stage1.md:52-57
  explains why. This is exactly the "a nonexistent flag is worse than a missing
  one" hazard, avoided.
- **`KISSFFT_TEST=OFF` is load-bearing and correctly identified.**
  `CMakeLists.txt:51` defaults it ON, and `test/CMakeLists.txt:32` is:

  ```cmake
  pkg_check_modules(fftw3 REQUIRED IMPORTED_TARGET ${fftw3_pkg})
  ```

  `REQUIRED` — so a missing `fftw3.pc` is a **fatal configure error**, not a
  skipped test. kissfft would acquire a hard FFTW dependency through
  pkg-config purely because its tests were left on. `test/CMakeLists.txt:44`
  additionally builds `testcpp.cc`, a C++ program. Both go away with the flag.
  Correct, and a genuinely non-obvious trap.
- **`KISSFFT_TOOLS=OFF`** removes `kfc` and `psdpng` (`CMakeLists.txt:360-362`
  `add_subdirectory(tools)`), which are host programs — `kfc` reads `kiss_fft.c`
  at runtime. Right for the same reason every other package here drops its
  programs.
- **`cmake_minimum_required(VERSION 3.10)`** is above 3.5, so the
  `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` floor in `$CMAKE_FLAGS` is inert here.
  Harmless, and stage1.md:58-61 says so rather than claiming credit for it.
- **The library is four portable C files** (`CMakeLists.txt:123-128`:
  `kiss_fft.c kiss_fftnd.c kiss_fftndr.c kiss_fftr.c`, plus `kfc.c` which is
  compiled *into* the library, not as a tool), using `malloc`/`free`/`memcpy`/
  `sin`/`cos`. No assembly, no host program, no codegen step. No API gate
  applies at any level.
- **The system.** All flags via `$CMAKE_FLAGS`, `--parallel 1`, no fan-out, no
  exported search flags, no hardcoded target facts, no `android.lua` (nothing
  keys off `CMAKE_SYSTEM_NAME`, so the toolchain files' deliberate `Linux`
  setting is harmless). `require("kissfft@source")` only, and correctly so —
  with tests off, nothing external is referenced.
- **No target binary is executed.** With `KISSFFT_TEST=OFF` and
  `KISSFFT_TOOLS=OFF`, neither `test/` nor `tools/` is added
  (`CMakeLists.txt:359-371`), and the library build only compiles and archives.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | WILL BUILD | WILL BUILD | yes |
| clang-native | WILL BUILD | WILL BUILD | yes |

Six for six. The library is C with no POSIX dependency, so no row is
architecture-blocked and no API-level facility is reachable — `malloc`, `free`,
`realloc`, `memcpy`, `memset`, `sin`, `cos`, `printf` are all API 21, and none
of the documented walls (API-21 `stderr`/`POSIX_MADV_*`/`process_vm_readv`/
`posix_spawn`/`mblen`/`getpass`/`O_BINARY`, or the 26/28/35 gates) appears in
the source.

One thing worth knowing rather than fixing: `CMakeLists.txt:245-247` does

```cmake
if(CMAKE_SYSTEM_NAME MATCHES "^(Linux|kFreeBSD|GNU)$" AND NOT CMAKE_CROSSCOMPILING)
    target_link_libraries(kissfft PRIVATE m)
endif()
```

so `clang-native` gets `-lm` recorded in its link interface and the cross
builds do not. For a static archive this is a link-time property the consumer
inherits through the `.pc` only if the `.pc` mentions it — and
`kissfft.pc.in:9` does not. Harmless here, but it is a native/cross difference
worth knowing about.

## Verdict

REJECT. The recipe's flags are all real, `KISSFFT_STATIC` is correctly chosen
over `BUILD_SHARED_LIBS`, and the `KISSFFT_TEST` → `pkg_check_modules(fftw3
REQUIRED)` trap is identified and avoided. But the forecast's artifact names
are wrong: the build produces `libkissfft-float.a` and `kissfft-float.pc`
(`CMakeLists.txt:45,72,232-235,339-341`), so two of the three "how to verify"
commands cannot match, and the third expects `131.2.0` where the shipped
`Makefile` says `KFVER_PATCH = 0`, i.e. **131.1.0**. That is the same
check-cannot-match-its-own-target class this review has caught twice already
in this wave, and it is the whole substance of the change.
