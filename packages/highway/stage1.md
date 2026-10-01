# highway build forecast

- Recipe: `generic.lua`, source `source.lua` (no `android.lua`)
- Version pinned: 1.4.0 (tag `1.4.0`, `google/highway`)
- Build system: CMake 3.10 minimum (`CMakeLists.txt:17`)
- Header-only: **no.** Two real static libraries are built.
- Installs: `lib/libhwy.a`, `lib/libhwy_contrib.a`, the whole `hwy/` header
  tree including every `hwy/contrib/<subdir>/` (`:648-654`, `:663-669`),
  `lib/pkgconfig/libhwy.pc` + `libhwy-contrib.pc` (`:719-723`), and
  `lib/cmake/hwy/hwy-config.cmake` + `hwy-config-version.cmake` (`:988-989`).
- Requires: `highway@source` only. No external dependencies — `Threads` and
  `Atomics` are found in cmake and both resolve.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Real C++ compilation, but nothing that observes an API level: `hwy/contrib/sort/vqsort.cc:26-29` disables `VQSORT_GETRANDOM` on Android, and the only other `__ANDROID__` uses are version-gated *upward* (`thread_pool.h:66` needs API ≥ 19 for `pthread_setname_np`; `topology.cc:263,275` fall back to `syscall()` only below API 12, which is unreachable here). `HWY_ENABLE_TESTS=OFF` and `HWY_ENABLE_EXAMPLES=OFF` remove every host program. |
| aarch64-android24 | WILL BUILD | As above; the API-19 `pthread_setname_np` path in `thread_pool.h:66` is satisfied outright. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. The Windows-specific extras are additive: `CMakeLists.txt:410-432` only appends extra `-Wno-*`, and `:586-588` adds `synchronization` only when `HWY_DISABLE_FUTEX` is OFF — `:157-163` forces it ON for Win32 when `libsynchronization.a` is unavailable, so that link is self-guarding. |
| clang-native | WILL BUILD | As above, minus the Android guards. `hwy_list_targets` (`:620`) *is* executed here, but it is a native host binary on a native system, not a target binary under emulation — see risk 2. |

**Target selection is compile-time, not build-system-detected.** This is the
question the brief asked and the answer is favourable: `hwy/detect_targets.h`
derives `HWY_TARGETS` purely from compiler-predefined macros —
`__ARM_NEON__`/`__ARM_NEON_FP` at `:240` and `:514-528`, `__SSE2__` and the
AVX ladder in the x86 sections, `__riscv` at `:123-131` — and `:958-977`
picks the static/dynamic policy from those. The NDK and mingw wrappers
predefine the right ones for their own target, so **a cross build needs no
target override in the recipe**, and none is given. This is the opposite of a
project that probes the *build* machine and would silently bake host SIMD
into a target library.

The three `HWY_CMAKE_*` options that *are* build-system copts
(`HWY_CMAKE_ARM7` `:69`, `HWY_CMAKE_SSE2` `:73`, `HWY_CMAKE_RVV` `:76`) all
default OFF and the recipe leaves them there: `HWY_CMAKE_RVV` in particular
appends `-march=rv64gcv1p0` globally (`:478-486`) and would be actively wrong
on every system in this tree.

## Risks / what a reviewer should check

1. **`HWY_ENABLE_TESTS=OFF` is load-bearing twice.** It defaults ON
   (`:88`). Left on, `:794-796` `configure_file`s a `CMakeLists.txt.in` that
   declares `ExternalProject_Add(googletest GIT_REPOSITORY
   https://github.com/google/googletest.git ...)` and then `:795-806` runs
   `execute_process(cmake ...)` **and** `execute_process(cmake --build .)` —
   a network git clone and a nested build at configure time. Both are
   forbidden here (no network at build time but `curl` in `source.lua`, no
   git in a recipe). It then compiles ~70 test executables (`:941-975`) and
   calls `gtest_discover_tests` on each (`:973`), which *runs* every one of
   them. Turning it off also drops `libhwy-test` from the install
   (`:672-686`) and drops `libhwy-test.pc`, whose `Requires:` is `gtest`
   (`:713`).
2. **`hwy_list_targets` cannot be turned off and is built everywhere.**
   `:620` is unconditional — no option gates it. Its POST_BUILD command at
   `:631-633` runs the binary, wrapped in `if (NOT CMAKE_CROSSCOMPILING OR
   CMAKE_CROSSCOMPILING_EMULATOR)`. I probed this rather than assuming:
   cmake reports **`CMAKE_CROSSCOMPILING=TRUE`** for
   `packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake`
   even though that file deliberately sets `CMAKE_SYSTEM_NAME Linux`, so the
   guard holds and the binary is not run. It is not installed. On
   `clang-native` the build is genuinely native, so it does run — that is a
   host binary, which is allowed, and `|| (exit 0)` makes it non-fatal.
3. **`hwy_test` is still built with tests off.** `:597 add_library(hwy_test
   ...)` is outside every `if`, so `libhwy_test.a` is still compiled. It is
   simply not installed (`:673` is inside `HWY_ENABLE_TESTS`). Nothing to do.
4. **`find_package(Threads)` + `HWY_ENABLE_CONTRIB`.** `:167-169` is a
   `FATAL_ERROR` if Threads is not found while contrib is on. Every Android
   system here already exports `-DTHREADS_PREFER_PTHREAD_FLAG=ON` in
   `$CMAKE_FLAGS` precisely because FindThreads cannot detect Bionic's
   libc-resident pthreads on a cross build, so this is satisfied. On mingw
   and native, Threads is found normally.
5. **`libhwy-contrib.pc` carries `@HWY_THREAD_LIBS@`** (`:9` of
   `libhwy-contrib.pc.in`), which resolves to whatever `CMAKE_THREAD_LIBS_INIT`
   was. Worth eyeballing the installed file; a stray host `-lpthread` there
   would be a real defect, though `$LDFLAGS`/`$CFLAGS` from the system are
   what produce it and they are target-correct.
6. `CMAKE_CXX_VISIBILITY_PRESET hidden` is set unconditionally (`:521`). It
   only affects the shared build, which is off.

## How to verify once built

- `lib/libhwy.a` and `lib/libhwy_contrib.a` exist. **No `.so` anywhere** —
  that is the check that `BUILD_SHARED_LIBS=OFF` took (`:515`, `:526-528`).
- `include/hwy/highway.h` exists, **and so do `include/hwy/contrib/sort/`,
  `include/hwy/contrib/thread_pool/` and `include/hwy/contrib/image/`.** The
  header install at `:663-669` walks `HWY_CONTRIB_SOURCES` and preserves each
  file's directory, so checking only `include/hwy/highway.h` is the mistake
  the layout invites. `hwy_contrib` cannot be used without them.
- `pkg-config --modversion libhwy` reports 1.4.0 — **the module name is
  `libhwy`, not `hwy`** (`libhwy.pc.in:6`). `--modversion hwy` failing is
  expected.
- `lib/cmake/hwy/hwy-config.cmake` and `hwy-config-version.cmake` exist.
- **`find $OUT -name 'libhwy_test*'` must return nothing**, and
  `find $OUT -name 'libhwy-test.pc'` must return nothing. Both are the
  positive proof that `HWY_ENABLE_TESTS=OFF` took effect (risk 1).
- `find $OUT -name 'hwy_list_targets*'` must return nothing — it is built but
  never installed.
- `nm -C lib/libhwy.a` should show NEON symbols (`vld1q_*`) on the aarch64
  archives and SSE/AVX symbols on x86 ones. That is the check that the
  compile-time target detection picked the right kernels (risk: silently host
  kernels in a target library).
