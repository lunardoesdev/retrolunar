# abseil-cpp 20260817.0 — stage 1 build forecast

**Package:** abseil-cpp
**Version:** 20260817.0
**Upstream:** https://github.com/abseil/abseil-cpp
**Build system:** CMake

This is a forecast from reading upstream source, not a measurement. Nothing
here has been compiled. This recipe is being written for the first time on the
main line — see the `topackage.md` note at the end.

## What it installs

- One static `libabsl_<module>.a` per concrete module, under `lib/`. The
  top-level `install(EXPORT ...)` and each `absl_cc_library`'s own
  `install(TARGETS ...)` (`CMake/AbseilHelpers.cmake:352-358`) put them there.
- `include/absl/` — the header tree, from
  `install(DIRECTORY absl DESTINATION include ... PATTERN "options.h" EXCLUDE)`
  (`CMakeLists.txt:196-203`), plus a **rewritten** `include/absl/base/options.h`
  generated at configure time to match the compiled ABI
  (`CMakeLists.txt:206`, `:266-268`). Consumers get the generated one, not the
  checked-in one.
- `lib/pkgconfig/absl_<module>.pc` — **one per module, and no aggregate
  `absl.pc`.** `CMake/AbseilHelpers.cmake:211` writes
  `lib/pkgconfig/absl_${_NAME}.pc` inside the per-target function and installs
  it at `:224`; there is no top-level `.pc` anywhere in the tree. Each file
  carries `Requires:` naming its absl dependencies and `Libs:` naming
  `-labsl_<module>`.
- `lib/cmake/absl/abslConfig.cmake`, `abslConfigVersion.cmake` and
  `abslTargets.cmake` (`CMakeLists.txt:174-192`). `abslConfig.cmake` is three
  lines: `find_dependency(Threads)` then the targets file
  (`CMake/abslConfig.cmake.in`).
- **No tools, no examples.** The CMake build defines none.

## Dependencies

None in this prefix. The only `find_package` calls in the whole project are
`find_package(Threads REQUIRED)` (`CMakeLists.txt:91`) and, inside the testing
branch only, `find_package(GTest REQUIRED)`. `Threads` is satisfied by the
Android systems' existing `-DTHREADS_PREFER_PTHREAD_FLAG=ON` and by the
mingw/native defaults. No `require()` of any other package appears in the
recipe.

`ABSL_USE_EXTERNAL_GOOGLETEST` (default OFF) plus the `absl` package already in
this prefix would be the alternative to downloading GoogleTest — but with
testing off entirely, neither is needed and neither is used.

## Source

`https://github.com/abseil/abseil-cpp/archive/refs/tags/20260817.0.tar.gz` —
confirmed HTTP 200. Extracted top directory is `abseil-cpp-20260817.0`,
stripped by the recipe. `20260817.0` is the newest tag; the one before it is
`20260526.0`.

## Switches passed, and why

| Switch | Reason |
| --- | --- |
| `BUILD_SHARED_LIBS=OFF` | This prefix is static throughout. `ABSL_BUILD_MONOLITHIC_SHARED_LIBS` is also OFF (`CMakeLists.txt:126`) and, per its own warning at `:129-131`, would be ignored without this. |
| `ABSL_BUILD_TESTING=OFF` | **The switch that keeps the build offline and host-free.** The gate is `if((BUILD_TESTING AND ABSL_BUILD_TESTING) OR ABSL_BUILD_TEST_HELPERS)` (`CMakeLists.txt:136`). `include(CTest)` at `CMakeLists.txt:28` sets `BUILD_TESTING` ON by default, and with `ABSL_USE_EXTERNAL_GOOGLETEST` at its OFF default (`:109-111`) the else branch runs `include(CMake/Googletest/DownloadGTest.cmake)` (`CMakeLists.txt:166`) — which **fetches GoogleTest at configure time and then configures and builds it with a host compiler** (`CMake/Googletest/DownloadGTest.cmake:8-30`). That is a network fetch and a host build in the middle of a cross build, and it also breaks the rule that nothing but `curl` in `source.lua` touches the network. |

Honest note on that switch: `ABSL_BUILD_TESTING` **already defaults OFF**
(`CMakeLists.txt:102-103`), so a plain `cmake -S . -B build` does *not* fetch
GoogleTest. The flag is belt-and-braces — it pins the behaviour so a future
upstream default flip, or a `CTest`-enabled parent project, cannot turn a
cross build into a networked host build. `ABSL_BUILD_TEST_HELPERS` is likewise
already OFF (`:105-106`). Passing it explicitly is what documents the intent
and makes the recipe independent of two separate upstream defaults.

There is **no `try_run` anywhere** in the abseil CMake — I grepped `CMake/`,
`absl/` and every `CMakeLists.txt` for `try_run` and `check_cxx_source_runs`
and found none — so nothing in the configure step executes a target binary.

No `android.lua`. There is no switch that makes the Android build *work*; the
one Android-specific problem is a consumer link issue, below, and it is a
system fact rather than a recipe fact.

## The `-llog` finding: a system change, not a recipe change

**This is the platform finding the reviewer needs to see, and it belongs to the
Android systems, not to this recipe.**

The chain, all verified against the extracted `20260817.0` tree and against
this repo's own Android systems:

1. The NDK clang wrappers **always** predefine `__ANDROID__`. Confirmed
   directly: `aarch64-linux-android24-clang -dM -E` prints `#define __ANDROID__ 1`
   alongside `__ANDROID_MIN_SDK_VERSION__ 24`.
2. `absl/log/internal/log_sink_set.cc:119` is `#if defined(__ANDROID__)`, and
   the `AndroidLogSink` class it guards (`:120-149`) calls
   `__android_log_write` at `:127` and `:130`. The class is instantiated
   unconditionally in `GlobalLogSinkSet`'s constructor at `:175-177`. So the
   `AndroidLogSink` is always compiled on Android, and `__android_log_write` is
   always an undefined symbol in `libabsl_log_internal_log_sink_set.a`.
3. `absl/log/CMakeLists.txt:237` adds
   `$<$<BOOL:${ANDROID}>:-llog>` to that target's `LINKOPTS` — upstream knows
   the dependency exists.
4. **`${ANDROID}` is the CMake variable, and it is not set here.** The Android
   toolchain files deliberately keep `set(CMAKE_SYSTEM_NAME Linux)` (see
   `packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:1-3`,
   whose comment explains that setting it to `Android` would start cmake's own
   NDK integration magic). cmake sets the `ANDROID` variable only when
   `CMAKE_SYSTEM_NAME` is `Android`. I probed this with the repo's own toolchain
   file and a throwaway project in `/tmp`: cmake printed
   `ANDROID is FALSE/undefined`, and the generator expression evaluated to
   `$<$<BOOL:>:-llog>`, i.e. **empty**. No `ANDROID` is set anywhere in any
   `packages/*android*/generic.lua` or `*.cmake` — I grepped all of them.
5. A second, independent reason the flag would not reach a consumer even if
   `ANDROID` were set: `PC_LINKOPTS` is built from `ABSL_CC_LIB_LINKOPTS`
   (`CMake/AbseilHelpers.cmake:210`), which is a *different* variable from the
   `LINKOPTS` the `-llog` lives in. The `.pc` files never carry `-llog`.
6. The Android systems' `LDFLAGS` carry `-lm` but **not `-llog`**:
   `packages/aarch64-android24/generic.lua:79`, in the `LDFLAGS` section
   immediately after the Bionic-keeps-math-in-libm comment.

### Does this fail abseil's own build, or only its consumers' links?

**Only the consumers' links.** abseil builds static archives, and a static
archive is not linked — `cmake --build` produces `.a` files that may carry
undefined symbols without complaint, and `cmake --install` copies them and the
`.pc` files without complaint. abseil's own build succeeds on every Android
target today. What fails is anything downstream that links
`libabsl_log_internal_log_sink_set` (directly, or transitively through
`libabsl_log`): the consumer gets `undefined reference to __android_log_write`.
The same applies to a `find_package(absl)` consumer, since `abslTargets.cmake`
inherits the same empty `-llog`.

### The fix, and where it goes

**`-llog` belongs in the Android systems' `LDFLAGS`.** Concretely:
`packages/aarch64-android24/generic.lua:79`, in the `LDFLAGS` section right
next to the `-lm` line and the comment explaining why `-lm` is always safe —
**and in its 55 sibling systems.** There are 56 `*android*` directories under
`packages/` (14 each of `aarch64`, `armv7a`, `i686`, `x86_64`, API 21-35), and
I confirmed all 56 already carry that `-lm` line, so it is a uniform one-line
addition to each. `x86_64-mingw` and `clang-native` need nothing.

This is a **system change, not a recipe change**, for two reasons: it is a
property of Bionic (`__android_log_write` lives in `liblog`, which is a
platform library, not a prefix package), and AGENTS.md forbids `export`ing
`LDFLAGS` in a recipe. The glog recipe I wrote alongside this one has the
identical problem via `CMakeLists.txt:463-466` and is fixed by the same edit —
one system change repairs both packages.

No API-level caveat: `liblog.so` is in the NDK sysroot at every level
(`$SYSROOT/usr/lib/{aarch64,x86_64}-linux-android/{21,24,35}/liblog.so` all
checked), and `__android_log_write` is declared at API 21 and API 35 alike (I
compiled a call against both wrappers).

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD; **consumers will fail to link without `-llog`** | The build itself is uneventful: no `try_run`, no GoogleTest fetch (testing off), no `find_package` beyond `Threads`, which `-DTHREADS_PREFER_PTHREAD_FLAG=ON` satisfies. The `AndroidLogSink` compiles fine — the *declaration* is in the sysroot's `android/log.h` at every API level. `libabsl_log_internal_log_sink_set.a` ends up with an undefined `__android_log_write`, which is invisible until something links it. Nothing in the API-21 wall list (AGENTS.md:368) applies: abseil uses no `posix_spawn`, `mblen`/`getpass` or `O_BINARY`. |
| `aarch64-android24` | WILL BUILD; **consumers will fail to link without `-llog`** | Identical. API 24 is the level at which the toolchain file exports `CPPFLAGS` (`:70`) and carries the `-lm` comment block, so it is the representative system for the fix. |
| `aarch64-android35` | WILL BUILD; **consumers will fail to link without `-llog`** | Identical. No API-35-specific behaviour in abseil's CMake. |
| `x86_64-android35` | WILL BUILD; **consumers will fail to link without `-llog`** | Identical. The only MinGW-conditional bits in the whole build (`-ladvapi32`, `-lbcrypt` at `absl/base/CMakeLists.txt:306` and `absl/random/CMakeLists.txt:606`) are gated on `$<BOOL:${MINGW}>`, which is false here; there is no `$<BOOL:${ANDROID}>` anywhere in abseil other than the `-llog` line. |
| `x86_64-mingw` | **UNCERTAIN** | The NDK finding does not apply — no `__ANDROID__`, no `android/log.h`, no `-llog`. The reason for uncertainty is different: this is the one target where abseil's *Windows* code paths become live, and I have not been able to verify them against a real compile. `absl/base/internal/low_level_alloc.cc:45`, `poison.cc:35`, `scoped_set_env.cc:18` and `sysinfo.cc:20` all `#include <windows.h>`, and `absl/synchronization` and `absl/strings` carry Windows-specific sources. `absl/base/internal/scoped_set_env.cc` in particular uses Windows process-environment APIs, and mingw-w64's `windows.h` coverage of those is good but not identical to MSVC's. The build does declare `-ladvapi32` and `-lbcrypt` for `MINGW`, which suggests upstream expects them to be needed. **What would settle it: one `cmake --build build --parallel 1` under `x86_64-mingw`, and then `llvm-nm`/`nm` on the resulting archives.** I am not marking this WILL BUILD because "upstream supports MinGW" and "this particular MinGW toolchain supports it" are different claims and I have only evidence for the first. |
| `clang-native` | WILL BUILD | Native, no `__ANDROID__`, no `ANDROID` and no `MINGW` branch taken, so neither the `-llog` nor the Windows libraries apply. The one thing to watch is `find_package(Unwind)` — abseil does not call it, so nothing host-specific leaks in. C++17 is the floor (`CMake/AbseilHelpers.cmake:348-350`, `cxx_std_17` at `:767`); the host `clang++` defaults to `__cplusplus == 201703L` (checked), which satisfies it exactly. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.
abseil's CMake never inspects the API level, and the `AndroidLogSink` is
compiled identically on 32-bit Bionic, so the `-llog` consumer failure is
uniform across all 56 Android systems.

## What a reviewer should scrutinise

1. **`-llog` in the systems' `LDFLAGS` — the one thing that must not be lost.**
   This recipe is correct without it; the *consumers* are not. Since protobuf
   22+ links absl, the first real consumer will hit it immediately, and the
   symptom (`undefined reference to __android_log_write`) does not name absl,
   so it will be easy to misdiagnose. The same one-line system change also
   fixes glog.
2. **The archive count in the stale `topackage.md` line.** See below — "94
   static `libabsl_*.a` archives" does not match what I counted in the source
   and should not be carried forward unverified.
3. **`x86_64-mingw` is UNCERTAIN, not WILL BUILD.** If the build fails there,
   the Windows sources under `absl/base/internal/` are where to look first. A
   failure would not be a reason to drop the package: the other five families
   are independent of it.
4. **No aggregate `absl.pc`.** Confirmed by reading `CMake/AbseilHelpers.cmake:211`
   — one `.pc` per module, generated into the build tree and installed from
   there. Consumers must use `find_package(absl)` or enumerate the per-module
   files. This is upstream's design, not a recipe limitation, and it is worth
   stating in `readme.md` so nobody writes `pkg-config --cflags absl`.
5. **`ABSL_PROPAGATE_CXX_STD` is left ON** (upstream default,
   `CMakeLists.txt:48-50`). It attaches `cxx_std_17` as an `INTERFACE`
   compile feature, so any consumer that links an absl target inherits the
   C++17 requirement. That is intended upstream behaviour, but it means a
   C++11 consumer cannot use this prefix's absl without overriding it.

## The existing `topackage.md` entry is stale

`topackage.md:163` already carries:

```
- [x] abseil-cpp 20260817.0 (94 static libabsl_*.a archives, absl/ headers,
  one absl_<name>.pc per module and a lib/cmake/absl package config; archive
  members are elf64-littleaarch64. ABSL_BUILD_TESTING=OFF so the GoogleTest
  fetch and the test binaries stay out. Required by protobuf 22+, so it is the
  first link of that chain. Note upstream ships no aggregate absl.pc, so use
  find_package(absl) or link the per-module .pc files)
```

**There was no `packages/abseil-cpp/` directory** — I confirmed that before
writing anything — so the `[x]` and its build evidence describe a working copy
that was thrown away. `packages/abseil-cpp/` is being written now, for the
first time on this line.

**Is the entry accurate?** Partly. The *version*, the *switch*
(`ABSL_BUILD_TESTING=OFF`), the *artifact shape* (`absl/` headers, one
`absl_<name>.pc` per module, a `lib/cmake/absl` package config) and the
*no-aggregate-`absl.pc` note` are all correct — I verified each against the
extracted `20260817.0` source. The **"94 static `libabsl_*.a` archives" count is
not supported by the source**: I counted 256 `absl_cc_library` calls across
`absl/*/CMakeLists.txt`, of which 187 have an `SRCS` list and would produce an
archive. (That count comes from parsing the CMake sources, so it is an
indication, not a count — but it is nowhere near 94, and 94 should not be
repeated as fact.) The `elf64-littleaarch64` claim was true of the discarded
build and will be true again once this recipe is run; it is not something this
document can confirm.

**What the builder should change it to.** After a successful build on
`aarch64-android24`, replace line 163 with the observed facts rather than this
forecast — in particular the **real** `libabsl_*.a` count, `file libabsl_base.a`
output for the archive members, and `pkg-config --modversion absl_base`
reporting 20260817. The recipe's comment in `generic.lua` should also gain the
`-llog` consumer caveat, and the entry should note that Android consumers need
`-llog` from the systems' `LDFLAGS`. Until that run happens, the honest state
of the entry is: **written but unbuilt**.

I have not edited `topackage.md`, per the brief.
