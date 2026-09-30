REJECT

# glog 0.7.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`v0.7.1` tree. I did not build anything.

**The recipe will build. Both required changes are text only — no flag changes,
no source changes, no build risk.** The rejection is for a false premise
attached to a load-bearing switch, which AGENTS.md forbids ("Explain
non-obvious flags and recipe-local workarounds").

## Required changes

### 1. `packages/glog/generic.lua`, lines 20-23 — the stated reason for `WITH_UNWIND=none` is factually wrong

The comment currently reads:

```
        # WITH_UNWIND=none: no libunwind package in this prefix, and Bionic's
        # sysroot has no unwind.h at all, so letting find_package(Unwind)
        # succeed on the native system would link a different stacktrace
        # backend per system and make the install non-reproducible.
```

"no libunwind package in this prefix" is false. **`packages/libunwind` exists**
(`packages/libunwind/source.lua`, `version = "1.8.3"`, with its own
`generic.lua` and `stage1.md`). It is simply not a dependency of glog, which is
a different statement. A future reader who checks will conclude the author did
not look, and may well "fix" the flag to `WITH_UNWIND=libunwind` on the
strength of the comment.

The decision itself is right, and `stage1.md` states the right reason
elsewhere: Bionic's sysroot has no `unwind.h` or `libunwind.h` at all, so
`find_package(Unwind)` can only ever succeed on `clang-native`, where it would
find the **host's** `/usr/include/libunwind.h` and the host's `libunwind`,
bake `-lunwind` into `Libs.private` (`CMakeLists.txt:435-438`) and compile
`stacktrace_libunwind-inl.h` — while all four Android families would compile
the generic backtrace path. That is the real argument, and it is
reproducibility, not absence.

**Replace lines 20-23 with:**

```
        # WITH_UNWIND=none is a reproducibility choice, not a capability
        # one. Bionic's sysroot has no unwind.h or libunwind.h at all, so
        # find_package(Unwind) can only ever succeed on clang-native, where
        # it would pick up the HOST's libunwind, compile
        # stacktrace_libunwind-inl.h and bake -lunwind into
        # Libs.private (CMakeLists.txt:435-438) - while every Android family
        # would compile the generic backtrace path. Left at the upstream
        # default the artifact would differ per system. packages/libunwind
        # 1.8.3 exists but is deliberately not a dependency here; if the
        # tree ever wants native libunwind stack traces, that is a
        # per-system recipe, not this generic one.
```

### 2. `packages/glog/stage1.md`, the `WITH_UNWIND=none` row and scrutiny item 3 — same false premise

The switch table row reads in part: *"There is no `libunwind` package in this
prefix, and Bionic's sysroot has no `unwind.h` and no `libunwind.h` at all …
So `find_package(Unwind)` fails on every Android system and succeeds on
`clang-native` …"* The second half is the load-bearing half and it is right;
the first clause is the false one. Scrutiny item 3 compounds it: *"If the tree
would rather have libunwind stack traces on the native system, that is a
`libunwind` package plus a per-system recipe"* — the package is already there.

**Required:** delete the clause "There is no `libunwind` package in this
prefix" from that row and lead with the Bionic/host-leak argument instead;
and in item 3, replace "that is a `libunwind` package plus a per-system recipe"
with "that is `require("libunwind")` plus a per-system recipe — the package is
already in the tree at `packages/libunwind` 1.8.3".

A stage1 forecast that asserts a false premise about a load-bearing switch is a
finding against it, independently of the recipe.

### 3. Nothing else is required

No flag changes. No `android.lua` — there is no Android-only switch that makes
this build work, and the one Android problem is the `-llog` consumer link issue
below, which is a system fact. `BUILD_TESTING=OFF`, `WITH_GFLAGS=OFF`,
`WITH_GTEST=OFF`, `WITH_GMOCK=OFF` and `WITH_PKGCONFIG=ON` are all correct as
they stand and must not change.

## What the recipe otherwise does right

- `source.lua`: `v0.7.1` is the newest tag (I re-queried: `v0.7.1, v0.7.0,
  v0.7.0-rc1, v0.6.0`). The v0.7.1 release carries **no downloadable assets**,
  so the git tag archive is the only form — the recipe uses it. URL 200, top
  dir `glog-0.7.1/`. Guarded download, `curl -C -` resume, `rm -rf src`,
  `mkdir -p $OUT/glog`.
- `generic.lua` requires only `glog@source`. Nothing missing, no `@native` need.
- Every build-system flag comes from `$CMAKE_FLAGS`; the seven `-D` values are
  package choices. No `export` of `CPPFLAGS`/`LDFLAGS`/`CFLAGS`, no hardcoded
  architecture/triplet/API level, no `-I`/`-L`, no `sed`, no patch, no
  `/dev/null`, serial build, install into `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `BUILD_TESTING=OFF` is the switch that matters most and it is right:
  `include(CTest)` (`CMakeLists.txt:28`) defaults it ON, and `BUILD_TESTING`
  gates the whole test tree from `CMakeLists.txt:546` to `:961` — ten host
  executables. With it off, no test binary is built and none is run.
- `WITH_GFLAGS=OFF` is correct: I confirmed there is **no `gflags` package**
  under `packages/`, and leaving it ON would let `find_package(gflags 2.2.2)`
  (`:77`) find a *host* gflags on `clang-native`. `WITH_GTEST=OFF` /
  `WITH_GMOCK=OFF` is correct too: **`googletest` does exist** under
  `packages/`, and with `WITH_GTEST` off, `CMAKE_DISABLE_FIND_PACKAGE_GTest` is
  set (`:55-57`) so the `find_package(GTest NO_MODULE)` at `:66` never runs.
  `WITH_PKGCONFIG=ON` is what produces `libglog.pc` (upstream default OFF).
- `find_package(Threads REQUIRED)` (`:85`) is satisfied on Android by the
  systems' existing `-DTHREADS_PREFER_PTHREAD_FLAG=ON`, which is the right way
  round — glog does not need a `threads` recipe.
- The one `check_cxx_source_runs` (`:249`) is inside `if (WIN32 OR CYGWIN)`, so
  no Android system reaches a `try_run`. On mingw it is reached and cmake
  returns `PLEASE_FILL_OUT-FAILED_TO_RUN` in cross-compiling mode without
  aborting; `stage1.md` reports that honestly, and flags that the non-false
  string then makes `if (HAVE_SYMBOLIZE)` (`:277`) true. If the mingw build
  ever fails, the documented lever is `-DWITH_SYMBOLIZE=OFF` (or an
  `x86_64-mingw.lua` carrying it), not a patch.

## Carried to the build

Expected under `$NESTDIR/<sys>/`:

| Artifact | The one check that proves it |
| --- | --- |
| `lib/libglog.a` | `llvm-objdump -f lib/libglog.a \| head -3` shows `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw) |
| `include/glog/logging.h` | `[ -f include/glog/logging.h ]` |
| `include/glog/export.h` | `[ -f include/glog/export.h ]` — generated by `generate_export_header` (`:502-504`), so its presence proves that step ran |
| `lib/pkgconfig/libglog.pc` | `pkg-config --modversion libglog` → `0.7.1`. Installed to `${_glog_CMake_LIBDIR}/pkgconfig` = `$OUT/lib/pkgconfig` (`:970-974`), which is inside the loader's `$OUT`→`$PREFIX` rewrite set. |
| `lib/cmake/glog/glog-config.cmake` and the exported target set | `[ -f lib/cmake/glog/glog-config.cmake ]` |

**No `bin/` should appear.** If any `*_unittest` binary lands in `$PREFIX/bin`,
`BUILD_TESTING=OFF` did not take, and the build has produced ten target
executables that must never be run.

**Record the following as a SYSTEM blocker, not a recipe defect** (see below).

## The `-llog` finding: a SYSTEM defect, identical to abseil-cpp's

glog has exactly the same defect as abseil-cpp, and one system change repairs
both. It is **not** a recipe defect and must not be worked around in a recipe.

The chain, all verified in the extracted `v0.7.1` tree and in this repo's
systems:

1. The NDK wrappers always predefine `__ANDROID__`.
2. `src/glog/platform.h:42-45` turns that into `GLOG_OS_ANDROID`.
3. `src/utilities.cc:49-51` then includes `<android/log.h>`, and
   `src/utilities.cc:95-103` calls `__android_log_write` unconditionally inside
   `AlsoErrorWrite` — reached from ordinary logging paths
   (`src/logging.cc:857`, `:1745`, `src/utilities.cc:135`), not an optional
   sink. So `__android_log_write` is an **undefined symbol in `libglog.a` on
   every Android target**.
4. glog knows the dependency exists — `CMakeLists.txt:463-466`:
   ```cmake
   if (ANDROID)
     target_link_libraries (glog PRIVATE log)
     set (glog_libraries_options_for_static_linking "... -llog")
   endif (ANDROID)
   ```
5. **`ANDROID` is never set here.** cmake sets that variable only when
   `CMAKE_SYSTEM_NAME` is `Android`, and the Android toolchain files
   deliberately keep `set(CMAKE_SYSTEM_NAME Linux)`
   (`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`,
   whose own comment explains that `Android` would start cmake's NDK
   integration magic). So neither `target_link_libraries(glog PRIVATE log)` nor
   `-llog` in `Libs.private` ever happens.
6. `libglog.pc` therefore ships a `Libs.private` with no `-llog`
   (`libglog.pc.in` → `Libs.private: @glog_libraries_options_for_static_linking@`).
7. The 56 Android systems' `LDFLAGS` carry `-lm` but **not `-llog`**. I
   re-checked all of them: 56 `*android*` directories (14 each of aarch64,
   armv7a, i686, x86_64), and 56 of 56 already carry the
   `LDFLAGS="$LDFLAGS -lm"` line; 0 carry `-llog`.

**This does not fail glog's own build.** A static archive is not linked, so
`cmake --build` completes and `cmake --install` copies the `.a` and the `.pc`
without complaint. What fails is every *consumer*: anything linking `libglog.a`
on Android gets `undefined reference to __android_log_write`, and the same for
a `find_package(glog)` consumer, since the exported target inherits the empty
link option.

**Action for the builder: record this as a blocker, do not work around it.**
`-llog` belongs in the Android systems' `LDFLAGS`, next to the `-lm` line at
`packages/aarch64-android24/generic.lua:79` and in its 55 sibling systems. It is
a property of Bionic (`__android_log_write` lives in `liblog`, a platform
library, not a prefix package), and AGENTS.md forbids a recipe from `export`ing
`LDFLAGS`. The systems files are not the recipe author's to edit. `liblog.so`
is present in the NDK sysroot at every API level, and `__android_log_write` is
declared from API 21 up, so there is no API-level caveat.

**Also record, as a behaviour difference rather than a failure:** `backtrace` and
`backtrace_symbols` carry `__INTRODUCED_IN(33)` in Bionic's `execinfo.h`, so on
`aarch64-android21`/`24` glog loses the `HAVE_EXECINFO_BACKTRACE` path and on
`aarch64-android35` it keeps it. glog builds either way.
