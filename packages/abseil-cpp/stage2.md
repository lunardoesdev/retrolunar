ACCEPT

# abseil-cpp 20260817.0 — stage 2 review

Reviewed against AGENTS.md, all 56 Android systems, the mingw and native
systems, and the extracted `20260817.0` tree. I did not build anything.

**The recipe itself is correct on every system and needs no change.** The
`-llog` problem below is a **system** defect and must not be worked around here.

## What the recipe does right

- `source.lua`: `20260817.0` is the newest tag (I re-queried:
  `20260817.0, 20260526.0, 20260526.rc2, 20260526.rc1`). URL 200, top dir
  `abseil-cpp-20260817.0/`, handled by `--strip-components=1`. Guarded download,
  `curl -C -` resume, `rm -rf src`, `mkdir -p $OUT/abseil-cpp`.
- `generic.lua` requires only `abseil-cpp@source`. Nothing missing from
  `packages/`, no `@native` host tool needed.
- Every build-system flag comes from `$CMAKE_FLAGS`; the two `-D` values are
  package choices. **No `export` of `CPPFLAGS`/`LDFLAGS`/`CFLAGS`, no hardcoded
  architecture, triplet or API level, no `-I`/`-L`, no `sed`, no patch, no
  `/dev/null`, no multi-job build.** Install goes straight to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `BUILD_SHARED_LIBS=OFF` is right: `ABSL_BUILD_MONOLITHIC_SHARED_LIBS` is
  ignored without it (`CMakeLists.txt:126-131`), and this prefix is static
  throughout.
- `ABSL_BUILD_TESTING=OFF` is the switch that keeps the build offline. The gate
  is `if((BUILD_TESTING AND ABSL_BUILD_TESTING) OR ABSL_BUILD_TEST_HELPERS)`
  (`CMakeLists.txt:136`); `include(CTest)` (`:28`) sets `BUILD_TESTING` ON by
  default, and with `ABSL_USE_EXTERNAL_GOOGLETEST` at its OFF default the else
  branch runs `include(CMake/Googletest/DownloadGTest.cmake)` (`:166`), which
  **fetches GoogleTest at configure time and then configures and builds it with
  a host compiler**. A network fetch and a host build in the middle of a cross
  build, and a violation of "no network access at build time except `curl` in
  `source.lua`". Passing it explicitly also pins the behaviour against an
  upstream default flip. Honest belt-and-braces, and `stage1.md` says exactly
  that rather than claiming it fixes an observed failure.
- There is **no `try_run` anywhere** in the abseil CMake, and no
  `check_*_source_runs`, so no target binary is ever executed during configure.
  I grepped `CMake/`, `absl/` and every `CMakeLists.txt` to confirm.
- `find_package(Threads REQUIRED)` (`CMakeLists.txt:98`) is the only
  unconditional `find_package`; the Android systems' existing
  `-DTHREADS_PREFER_PTHREAD_FLAG=ON` satisfies it without a recipe change. The
  testing-branch `find_package(GTest)` is never reached.
- No `android.lua` is needed, and that is the right answer: there is no
  Android-only switch that makes this build work. The one Android problem is a
  consumer link issue, which is a system fact (below), not a recipe fact. Per
  AGENTS.md, `packages/<name>/android.lua` is the only correct home for an
  Android-only switch, and here there is nothing to put in it.
- `stage1.md` is the most honest document I have reviewed in this batch. It
  corrects the brief's premise, marks `x86_64-mingw` **UNCERTAIN** rather than
  claiming WILL BUILD, names the exact files where a mingw failure would live,
  and volunteers that the `topackage.md` entry describing it as already built
  describes a working copy that was thrown away. It also states plainly that
  its own "187 would produce an archive" figure "is an indication, not a count"
  and that 94 "should not be repeated as fact". That is a forecast telling the
  truth about its own confidence, which is the whole point of the document.

## Non-blocking observations

1. abseil's `.pc` files are generated with `file(GENERATE ...)` into
   `${CMAKE_BINARY_DIR}/lib/pkgconfig/absl_<module>.pc` and installed from
   there (`CMake/AbseilHelpers.cmake:211`, `:224-225`). The paths bake
   `CMAKE_INSTALL_PREFIX`, so the loader's `$OUT`→`$PREFIX` rewrite
   (`src/loader.lua:454`) is what makes them usable. Worth glancing at one
   generated file in the build log.
2. `ABSL_PROPAGATE_CXX_STD` is left ON (upstream default), which attaches
   `cxx_std_17` to every absl target's compile features
   (`CMake/AbseilHelpers.cmake:307`). That is intended upstream behaviour, but
   it constrains consumers to C++17+. Nothing for the recipe to do.
3. The `absl/` package config does `find_dependency(Threads)`
   (`CMake/abslConfig.cmake.in`), so a `find_package(absl)` consumer needs the
   same Threads story the build needs. Already satisfied.

## Carried to the build

Expected under `$NESTDIR/<sys>/`:

| Artifact | The one check that proves it |
| --- | --- |
| `lib/libabsl_base.a` (and one `libabsl_<module>.a` per concrete module) | `llvm-objdump -f lib/libabsl_base.a \| head -3` shows `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **Record the real count** — see the `topackage.md` section below. |
| `lib/libabsl_log.a` and the archive that carries the sink | `llvm-nm lib/libabsl_log_internal_log_sink_set.a \| grep __android_log_write` — on **any Android system this must print one `U __android_log_write`**. That single line is the proof of the system defect below. |
| `include/absl/base/options.h` | `[ -f include/absl/base/options.h ]` — this is the *generated* one (`CMakeLists.txt:206`, `:266-268`), not the checked-in copy, so its presence proves the ABI configure step ran |
| `include/absl/strings/string_view.h` | `[ -f include/absl/strings/string_view.h ]` |
| `lib/pkgconfig/absl_base.pc` | `pkg-config --modversion absl_base` → `20260817` |
| `lib/cmake/absl/abslConfig.cmake`, `abslConfigVersion.cmake`, `abslTargets.cmake` | `[ -f lib/cmake/absl/abslConfig.cmake ]` |

**There is no aggregate `absl.pc` and there must not be one** — upstream ships
one `.pc` per module and no top-level file. A failed
`pkg-config --modversion absl` is the expected result; use `absl_base` (or
`find_package(absl)`).

**No `bin/` and no test binaries should appear.** If any `*_test` binary lands
in `$PREFIX/bin`, `ABSL_BUILD_TESTING=OFF` did not take — and the build will
also have tried to download GoogleTest, so check the configure log for network
access.

## The `-llog` finding: a SYSTEM defect, NOT a recipe defect

**State this plainly in the build record: the missing `-llog` in the Android
systems' `LDFLAGS` is a defect in `packages/*android*/generic.lua`. It is not a
defect in this recipe, it is not fixable in this recipe, and the recipe must
not be edited to work around it. The builder must record it as a blocker.**

The chain, all verified in the extracted `20260817.0` tree and in this repo's
systems:

1. The NDK clang wrappers always predefine `__ANDROID__`.
2. `absl/log/internal/log_sink_set.cc:22-24` is
   `#ifdef __ANDROID__ / #include <android/log.h>`, and the `AndroidLogSink`
   class it guards (`:119-149`) calls `__android_log_write` at `:127` and
   `:130`. That class is instantiated unconditionally in `GlobalLogSinkSet`'s
   constructor, so the call is always compiled in on Android.
3. Upstream knows the dependency exists: `absl/log/CMakeLists.txt:237` adds
   `$<$<BOOL:${ANDROID}>:-llog>` to that target's `LINKOPTS`.
4. **`${ANDROID}` is the CMake variable, and it is never set here.** cmake sets
   it only when `CMAKE_SYSTEM_NAME` is `Android`; the Android toolchain files
   deliberately keep `set(CMAKE_SYSTEM_NAME Linux)`
   (`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`).
   So the generator expression evaluates to `$<$<BOOL:>:-llog>`, i.e. empty.
5. A second, independent reason the flag would not reach a consumer even if
   `ANDROID` *were* set: `PC_LINKOPTS` is built from `ABSL_CC_LIB_LINKOPTS`
   (`CMake/AbseilHelpers.cmake:210`), a different variable from the `LINKOPTS`
   the `-llog` lives in. The `.pc` files never carry `-llog`, and for a static
   archive `LINKOPTS` contributes no link option to the `.a` either.
6. The Android systems' `LDFLAGS` carry `-lm` but not `-llog`. I re-checked:
   56 `*android*` directories under `packages/` (14 each of aarch64, armv7a,
   i686, x86_64), 56 of 56 already carry `LDFLAGS="$LDFLAGS -lm"`, and **0**
   carry `-llog`.

**The same defect hits glog identically.** `glog`'s
`src/utilities.cc:49-51` and `:95-103` call `__android_log_write` under
`GLOG_OS_ANDROID`, and glog's own `CMakeLists.txt:463-466` gates
`target_link_libraries(glog PRIVATE log)` and `-llog` in `Libs.private` on the
same unset `ANDROID` variable. So does `libglog.pc`, whose `Libs.private`
therefore lacks `-llog`. **One system change repairs both packages.**

**Scope, stated precisely so the blocker record is not wrong:** this does *not*
fail abseil's or glog's own build. Both produce static archives, and a static
archive is not linked, so `cmake --build` completes and `cmake --install` copies
the `.a` and the `.pc` without complaint. What fails is anything downstream that
links `libabsl_log` (or `libglog.a`) on Android: `undefined reference to
__android_log_write`. Since protobuf 22+ links absl, the first real consumer
will hit it immediately, and the error message does not name absl, so it will be
easy to misdiagnose. Record it as a **consumer-link blocker on all 56 Android
systems**, not as a build failure of these two packages.

**Where the fix belongs (not the recipe author's to make):** the `LDFLAGS`
section of each `packages/*android*/generic.lua`, on the line after the existing
`-lm` — for example `packages/aarch64-android24/generic.lua:79` — one
`-llog` per file, commented with the reason (`__android_log_write` lives in
Bionic's `liblog`, and the `$<$<BOOL:${ANDROID}>:-llog>` that upstream relies on
is dead because our toolchain files keep `CMAKE_SYSTEM_NAME` at `Linux`).
`x86_64-mingw` and `clang-native` need nothing. AGENTS.md forbids a recipe from
`export`ing `LDFLAGS`, and a platform library is not a package.

`liblog.so` is present in the NDK sysroot at every API level and
`__android_log_write` is declared from API 21 up, so there is no API-level
caveat.

## `topackage.md` line 163 — stale and partly unsupported

`topackage.md:163` currently reads:

```
- [x] abseil-cpp 20260817.0 (94 static libabsl_*.a archives, absl/ headers,
  one absl_<name>.pc per module and a lib/cmake/absl package config; archive
  members are elf64-littleaarch64. ABSL_BUILD_TESTING=OFF so the GoogleTest
  fetch and the test binaries stay out. Required by protobuf 22+, so it is the
  first link of that chain. Note upstream ships no aggregate absl.pc, so use
  find_package(absl) or link the per-module .pc files)
```

Three problems:

1. **`[x]` is a lie about the tree.** `packages/abseil-cpp/` did not exist when
   that line was written; the recipe is being written now, for the first time on
   this line. The line describes a working copy that was thrown away. AGENTS.md
   is explicit that `topackage.md` is a backlog, not an inventory, and that a
   package may exist without appearing there — so the failure here is claiming
   build evidence (`elf64-littleaarch64` archive members) that no committed
   recipe ever produced.
2. **"94 static `libabsl_*.a` archives" is unsupported and almost certainly
   wrong.** Counting the `absl_cc_library` calls in the extracted source gives
   on the order of 250, of which roughly 180 have an `SRCS` list and would
   produce an archive. That count comes from parsing CMake sources, so it is an
   indication rather than a measurement — but it is nowhere near 94, and 94 must
   not be carried forward as fact. The honest state of the number is *unknown
   until a build runs.*
3. **The entry omits the one thing a future builder needs to know:** Android
   consumers need `-llog`, and the systems do not currently provide it.

**What the line should become once a real build runs on `aarch64-android24`:**
keep the `[x]` only after the build actually succeeds, and replace the
parenthetical with observed facts rather than this forecast — in particular the
**real** `ls lib/libabsl_*.a | wc -l` count (not 94), the actual
`llvm-objdump -f lib/libabsl_base.a` output for the archive members, and
`pkg-config --modversion absl_base` reporting `20260817`. The entry should also
record the consumer-link caveat, e.g.:

```
- [x] abseil-cpp 20260817.0 (N static libabsl_<module>.a archives [N observed],
  absl/ headers, one absl_<module>.pc per module and a lib/cmake/absl package
  config; no aggregate absl.pc, so use find_package(absl) or the per-module .pc
  files. archive members are elf64-littleaarch64. ABSL_BUILD_TESTING=OFF so the
  GoogleTest fetch and the test binaries stay out. Required by protobuf 22+.
  Note: Android consumers need -llog, which the systems do not yet provide —
  libabsl_log* carries an undefined __android_log_write, and glog's libglog.a has
  the same problem)
```

Until that run happens, the honest state is **written but unbuilt**, and the
line should say so.

**Related, for the builder:** the backlog lines for the other nine of my ten
packages are still `[ ]` and should only be flipped after their own builds —
`topackage.md:147` and `:252` (meshoptimizer), `:152`, `:270`, `:398`
(RapidJSON), `:160`, `:277`, `:410` (libconfig), `:161`, `:411` (libcbor),
`:169`, `:417` (nanopb), `:206` (stb), `:224`, `:282`, `:381` (glog), and
`:125`, `:235`, `:355` (Zopfli), `:204`, `:318` (GLM).
