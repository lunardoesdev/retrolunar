# glog 0.7.1 — stage 1 build forecast

**Package:** glog
**Version:** 0.7.1
**Upstream:** https://github.com/google/glog
**Build system:** CMake **only** — see the correction below

This is a forecast from reading upstream source, not a measurement. Nothing
here has been compiled.

## Correction to the brief: glog 0.7.1 is not autotools

The assignment brief said "glog 0.7.1 is autotools C++". **That is wrong, and
building on it would have produced a recipe that cannot work.** I extracted the
`v0.7.1` tag and listed the whole top level:

```
AUTHORS  BUILD.bazel  CMakeLists.txt  CONTRIBUTORS  COPYING  ChangeLog
MODULE.bazel  README.rst  WORKSPACE  codecov.yml  gcovr.cfg
glog-config.cmake.in  glog-modules.cmake.in  libglog.pc.in
.bazelci/  .github/  bazel/  cmake/  src/
```

No `configure`, no `configure.ac`, no `Makefile.am`, no `aclocal.m4`, no `m4/`.
Cross-checked by asking the GitHub API for the `v0.4.0` top level, which *does*
list `configure.ac` and `Makefile.am`: upstream removed the autotools build
somewhere between 0.4.0 and 0.6.0. The `v0.7.1` release also carries **no
downloadable assets at all** (`releases/tags/v0.7.1` has an empty `assets`
array), so there is no generated-`configure` dist tarball to fall back to,
unlike libyaml in this tree which fetches from pyyaml.org for exactly that
reason. The recipe is therefore CMake, and `./configure` with its
`$AUTOCONF_CONFIGURE_FLAGS` and the `touch aclocal.m4 configure config.h.in`
timestamp guard does not apply to this package.

## What it installs

- `lib/libglog.a` — static, from `install(TARGETS glog ...)` at
  `CMakeLists.txt:963-968`. `SOVERSION 2` is set but is inert for a static
  archive.
- `include/glog/` — the public headers, via the target's `PUBLIC_HEADER`
  property and `PUBLIC_HEADER DESTINATION include/glog`
  (`CMakeLists.txt:966`).
- `lib/pkgconfig/libglog.pc` — only because the recipe passes
  `WITH_PKGCONFIG=ON`; upstream defaults it **OFF** (`CMakeLists.txt:39`).
  The template is `libglog.pc.in` with `Libs: -L${libdir} -lglog`,
  `Libs.private: @glog_libraries_options_for_static_linking@` and
  `Cflags: -I${includedir}`; the generated file is installed at
  `CMakeLists.txt:970-974`. The loader's staged-`.pc` rewrite turns `$OUT`
  into `$PREFIX` on the way out.

  **Two corrections, both found by the build (see `stage3.md`, "Second
  build"). The `.pc` as this forecast describes it is unusable:**

  1. `Cflags:` **must** also carry `-DGLOG_USE_GLOG_EXPORT`. I read
     `CMakeLists.txt:416` (`target_compile_definitions (glog PUBLIC
     GLOG_USE_GLOG_EXPORT)`) as the end of it and missed that
     `libglog.pc.in:11` has **no `@variable@` in its `Cflags` line at
     all**, so that PUBLIC definition reaches a `find_package` consumer
     through `INTERFACE_COMPILE_DEFINITIONS` and reaches a `pkg-config`
     consumer **not at all**. The consequence is a hard failure, not a
     degradation: `include/glog/logging.h:55-61` includes the generated
     `glog/export.h` only under `#if defined(GLOG_USE_GLOG_EXPORT)` and
     then `#error`s when `GLOG_EXPORT`/`GLOG_NO_EXPORT` are undefined, so
     `#include <glog/logging.h>` fails to compile at all. This is a
     genuine upstream packaging quirk on **every** system, not an Android
     artifact, and since the template offers no variable, no cmake option
     can fix it.
  2. `Libs.private:` gains `-llog` on Android, for the reason under "The
     `-llog` finding" below — but see the correction there about *where*
     the fix belongs.
- `lib/cmake/glog/glog-config.cmake` and the exported target set.
- Also generated and installed: `include/glog/export.h`
  (`generate_export_header`, `CMakeLists.txt:502-504`), plus the `glog/`
  platform headers.
- **No tools.** Upstream 0.7.1 ships none in the CMake build.

## Dependencies

None in this prefix. The recipe passes `WITH_GFLAGS=OFF` and
`WITH_GTEST=OFF`, so neither `find_package(gflags 2.2.2)`
(`CMakeLists.txt:76-83`) nor `find_package(GTest NO_MODULE)`
(`CMakeLists.txt:68`) is asked for anything. There is no `gflags` package in
this tree — I checked — and `googletest` is present but deliberately not used.

`find_package(Threads REQUIRED)` (`CMakeLists.txt:85`) and
`find_package(Unwind)` (`CMakeLists.txt:86`) both resolve without help: Bionic
keeps pthreads in libc and the Android systems already pass
`-DTHREADS_PREFER_PTHREAD_FLAG=ON`.

## Switches passed, and why

| Switch | Reason |
| --- | --- |
| `BUILD_SHARED_LIBS=OFF` | Upstream defaults **ON** (`CMakeLists.txt:34`). This prefix is static throughout. |
| `WITH_GFLAGS=OFF` | Upstream defaults ON. gflags is not in this prefix. Turning it off is not a workaround — it is the honest configuration, and it keeps `GLOG_USE_GFLAGS` undefined so glog uses its own flag parsing (`CMakeLists.txt:431-433`). |
| `WITH_GTEST=OFF` | Upstream defaults ON. GoogleTest *is* in this prefix, so without this the build would find it and start wiring the test tree in. `CMakeLists.txt:55-57` additionally sets `CMAKE_DISABLE_FIND_PACKAGE_GTest`. |
| `WITH_GMOCK=OFF` | `cmake_dependent_option` defaulting ON with `WITH_GTEST` (`CMakeLists.txt:46`); it follows `WITH_GTEST` off, passed explicitly for the same reason. |
| `WITH_PKGCONFIG=ON` | Upstream defaults OFF. Needed for `libglog.pc`. |
| `WITH_UNWIND=none` | A **reproducibility** choice, not a capability one. Upstream defaults `libunwind` (`CMakeLists.txt:43`). Bionic's sysroot has **no `unwind.h` and no `libunwind.h` at all** (I listed `$SYSROOT/usr/include`; only `execinfo.h` matches), so `find_package(Unwind)` can only ever succeed on `clang-native` — where the host has `/usr/include/libunwind.h` and ten `libunwind` entries in `ldconfig`. Left at the default, `clang-native` would link `unwind::unwind`, bake `-lunwind` into `Libs.private` (`CMakeLists.txt:435-438`) and compile `stacktrace_libunwind-inl.h`, while every cross family would compile the generic backtrace path. Setting `none` makes the artifact identical on all six families. `packages/libunwind` 1.8.3 **does** exist in this tree; it is deliberately not a dependency here, and the flag is about the host's `unwind.h` leaking in, not about a missing package. |
| `WITH_SYMBOLIZE` | Left at its ON default. It is glog's *own* ELF symbolizer, `src/symbolize.cc`, needing no external library, and it is what makes `--symbolize_full` useful. |

**There is now an `android.lua` (from the build — see `stage3.md`, "Second
build"). This paragraph originally said there was none, because "the one
Android-specific problem is a link-time `-llog` matter for consumers … and
it is not fixable from a recipe". That last clause was wrong.** The gap is
fixable at the recipe level, with `-DANDROID=ON`: that is the cache variable
`if (ANDROID)` at `CMakeLists.txt:463` tests, and setting it by hand makes
upstream's own branch run. That is the whole fix — no patch, and no `.pc`
rewriting for *this* defect — and it repairs the exported CMake target
(`$<LINK_ONLY:log>`) as well as `Libs.private`. It lives in `android.lua`
because it is an Android fact: `x86_64-mingw` and `clang-native` have no
`liblog` and must not get the flag, and `generic.lua` is the recipe both of
them use.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD, consumer link will fail without `-llog` | Configure needs `cmake_minimum_required(VERSION 3.22)` (`CMakeLists.txt:1`); cmake 4.4.3 satisfies it and `$CMAKE_POLICY_VERSION_MINIMUM=3.5` is irrelevant at 3.22. All probes are `check_cxx_symbol_exists` / `check_include_file_cxx` / `check_cxx_source_compiles` — compile-and-link, never run — except the one `check_cxx_source_runs` at `CMakeLists.txt:249`, which is inside `if (WIN32 OR CYGWIN)` and so is not reached. `HAVE_ELF_H` is set (Bionic has `elf.h`) so `HAVE_SYMBOLIZE=1` and `src/symbolize.cc` compiles. `HAVE_EXECINFO_BACKTRACE` is **not** set below API 33: Bionic declares `backtrace` with `__INTRODUCED_IN(33)` (checked in `$SYSROOT/usr/include/execinfo.h:52,64`), and I confirmed by compiling a `backtrace()` call that API 21 and 24 reject it while API 35 accepts it. glog copes — `src/stacktrace.h:47-66` simply leaves `STACKTRACE_H` undefined, so `HAVE_STACKTRACE` is off and the generic path is dropped. That is a feature loss (no stack traces below API 33), not a build failure. |
| `aarch64-android24` | WILL BUILD, consumer link will fail without `-llog` | Identical to API 21 except the API level. `backtrace` is still below 33, so the same feature loss. |
| `aarch64-android35` | WILL BUILD, consumer link will fail without `-llog` | Identical, except `backtrace` and `backtrace_symbols` are available, so `HAVE_STACKTRACE` is on and `src/stacktrace.cc:36-37` includes `stacktrace_generic-inl.h`. `execinfo.h` is in the sysroot. |
| `x86_64-android35` | WILL BUILD, consumer link will fail without `-llog` | Same as `aarch64-android35`. `HAVE_ELF_H` from Bionic's `elf.h`; no 32/64-bit difference in the glog sources. |
| `x86_64-mingw` | **UNCERTAIN** | One concrete concern. `if (WIN32 OR CYGWIN)` at `CMakeLists.txt:245` is entered, and the `check_cxx_source_runs` at `CMakeLists.txt:249` calls `try_run()` in cross-compiling mode. I reproduced this with the repo's own `x86_64-w64-mingw32-toolchain.cmake`: cmake prints `try_run() invoked in cross-compiling mode`, sets the variable to `PLEASE_FILL_OUT-FAILED_TO_RUN`, and **continues** — configure does not abort. But that string is non-empty and is not a false constant, so the following `if (HAVE_SYMBOLIZE)` at `CMakeLists.txt:277` is **true**, and the Windows `dbghelp` branch of `src/symbolize.cc:851-890` is compiled on a variable that never actually passed its test. The `#error BUG: HAVE_SYMBOLIZE was wrongly set` at `src/symbolize.cc:950` sits in the `#else` branch, so it will not fire, but the branch cmake took is not the branch it verified. What would settle it: one `cmake -S . -B build $CMAKE_FLAGS` under `x86_64-mingw`, then read the `HAVE_SYMBOLIZE` line in the generated `build/config.h`. The mitigation is already in place — `HAVE_DBGHELP` is probed independently at `CMakeLists.txt:161` with `check_cxx_symbol_exists` (compile and link, never run), and both `/usr/x86_64-w64-mingw32/include/dbghelp.h` and `/usr/x86_64-w64-mingw32/lib/libdbghelp.a` exist, so the link should resolve. |
| `clang-native` | WILL BUILD | Native, so `BUILD_TRIPLET == HOST_TRIPLET` and no cross complications. `WITH_UNWIND=none` keeps host `libunwind` out, so the artifact matches the cross builds. `pkg-config --modversion libglog` should report 0.7.1. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row
except that the 32-bit NDK sysroots have the same `elf.h` and the same
`__INTRODUCED_IN(33)` on `backtrace`, so the verdicts and the reasons carry
over unchanged. The API level remains the real variable in the family.

## The `-llog` finding — same class of bug as abseil, and a reviewer should see it

glog has **exactly the abseil `-llog` problem**, and it is worth recording
because it means the fix is one system change that repairs two packages.

The chain, all verified in the extracted `v0.7.1` tree:

1. The NDK wrappers always predefine `__ANDROID__`. I confirmed directly:
   `aarch64-linux-android24-clang -dM -E` prints `#define __ANDROID__ 1` (and
   `__ANDROID_MIN_SDK_VERSION__ 24`).
2. `src/glog/platform.h:42-45` turns that into `GLOG_OS_ANDROID`.
3. `src/utilities.cc:49-51` then includes `<android/log.h>` and
   `src/utilities.cc:95-103` calls `__android_log_write` **unconditionally**
   inside `AlsoErrorWrite`. That function is reached from `src/logging.cc:857`,
   `:1745` and `src/utilities.cc:135` — ordinary logging paths, not an
   optional sink. So `__android_log_write` ends up as an undefined symbol in
   `libglog.a` on every Android target.
4. glog *knows* this. `CMakeLists.txt:463-466`:
   ```cmake
   if (ANDROID)
     target_link_libraries (glog PRIVATE log)
     set (glog_libraries_options_for_static_linking "... -llog")
   endif (ANDROID)
   ```
   That is the CMake variable `ANDROID`, **not** the preprocessor macro.
5. **`ANDROID` is never set here.** The Android toolchain files deliberately
   keep `set(CMAKE_SYSTEM_NAME Linux)`
   (`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`),
   which is exactly what stops cmake doing its own NDK integration — and
   `ANDROID` is a variable cmake sets only when `CMAKE_SYSTEM_NAME` is
   `Android`. I probed this with the repo's own toolchain file: cmake printed
   `ANDROID is FALSE/undefined` and the abseil-style generator expression
   evaluated to `$<$<BOOL:>:-llog>`, i.e. empty. So neither
   `target_link_libraries(glog PRIVATE log)` nor the `-llog` in
   `Libs.private` ever happens.
6. `libglog.pc` therefore ships with a `Libs.private` that has no `-llog`, and
   the static archive has an undefined reference.

**This does not fail glog's own build.** A static archive is not linked, so
`cmake --build` completes and `cmake --install` copies the `.a` and the `.pc`
without complaint. It is the *consumer* that fails: anything linking
`libglog.a` on Android gets `undefined reference to __android_log_write`.

**CORRECTION (from the build): this *is* fixable from a recipe, and the
recipe is the right place for glog's half of it.** The paragraph this
replaces argued that `-llog` "belongs in the Android systems' `LDFLAGS` …
and in its 55 sibling systems" and that "a recipe cannot fix this". Both
claims are wrong for `libglog.pc`, and the reasoning error is worth
recording: I reasoned from the rule that a recipe may not `export` `LDFLAGS`
and concluded the flag therefore had to live in a system file. But the
defect is not that a *build* of glog lacks `-llog` — the build has no link
step at all. The defect is that the **`.pc` glog installs** does not tell a
`pkg-config` consumer about liblog, and the systems' `LDFLAGS` can never fix
that, because `LDFLAGS` only reaches consumers that link through this build
system. A `pkg-config --libs --static libglog` consumer is handed
`-L…/lib -lglog -pthread` and nothing else.

The fix is one cache answer in `packages/glog/android.lua`:
`-DANDROID=ON`. That is the variable step 5 above says is unset; setting it
makes upstream's own `if (ANDROID)` branch run, which sets `-llog` in
`Libs.private` and adds `$<LINK_ONLY:log>` to the exported target. It is
not a patch, it is upstream answering a question, and the archive is
byte-identical with and without it.

The systems' `-llog` is still correct on its own terms and is still
needed — for abseil-cpp, whose `absl/log/CMakeLists.txt:237` gates `-llog`
on the identical `$<$<BOOL:${ANDROID}>:-llog>` expression and has the same
`.pc` problem. That one **is** a 56-system change, because abseil's recipe
has no equivalent of `-DANDROID=ON` to put in one place. So: glog's `-llog`
is a recipe fix, abseil's is still a system fix, and this forecast
conflated them.

The `liblog.so` the flag refers to is present in the NDK sysroot at every API
level (`$SYSROOT/usr/lib/{aarch64,x86_64}-linux-android/{21,24,35}/liblog.so`
all checked), and `__android_log_write` is declared at API 21 and 35 alike (I
compiled a call against both), so there is no API-level caveat.

## What a reviewer should scrutinise

1. **`-llog`, above, and its CORRECTION.** The whole finding. glog's own
   build is fine; every Android consumer is not. The fix shipped as
   `-DANDROID=ON` in `packages/glog/android.lua`, not as 56 system files.
2. **`x86_64-mingw` and `HAVE_SYMBOLIZE`.** The `try_run()` result is a
   non-false string, so the Windows `dbghelp` branch of `src/symbolize.cc` is
   compiled on a variable that was never actually tested. This is a genuine
   upstream wart that a cross build trips over. If a real run shows a link
   failure, `-DWITH_SYMBOLIZE=OFF` is the switch to try, and it costs only
   `--symbolize_full` on Windows.
3. **`WITH_UNWIND=none` is a policy decision, not a build necessity.** It
   removes the only place where `clang-native` would otherwise have picked up
   the **host's** `unwind.h` and `libunwind`, which no cross system has. If the
   tree would rather have libunwind stack traces on the native system, that is
   `require("libunwind")` plus a per-system recipe — the package is already in
   the tree at `packages/libunwind` 1.8.3 — and it is a larger change than this
   one, and a genuinely different decision rather than a flag tweak.
4. **No stack traces below Android API 33.** Not a failure, but a real
   behaviour difference between `aarch64-android21`/`24` and
   `aarch64-android35` that a reviewer should know about before someone
   reports it as a bug.
5. **`cmake_minimum_required(VERSION 3.22)`** is the newest floor of any
   package here. The host has cmake 4.4.3 so it is satisfied; a builder on an
   older cmake would not get this far.
