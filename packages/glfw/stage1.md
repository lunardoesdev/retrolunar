# glfw 3.5.1 — stage 1 build forecast

**Package:** glfw
**Version:** 3.5.1
**Upstream:** https://github.com/glfw/glfw
**Build system:** CMake 3.16...3.28, `CMakeLists.txt` + `src/CMakeLists.txt`

A forecast from reading upstream source. Nothing here has been compiled or
configured.

## The headline question: can GLFW build without a windowing backend?

**Yes — and that is the only way it builds here.** GLFW 3.5 always compiles its
null backend, and every real backend is behind a switch that can simply be off:

- `src/CMakeLists.txt:1-8` — `null_platform.h null_joystick.h null_init.c
  null_monitor.c null_window.c null_joystick.c` are **unconditional** members of
  the `glfw` library target. They are listed in the `add_library()` call itself,
  not inside any `if()`.
- `src/platform.h:40` — `#include "null_platform.h"` is unconditional; the real
  backends sit inside `#if defined(_GLFW_WIN32)` / `_GLFW_COCOA` /
  `_GLFW_WAYLAND` / `_GLFW_X11` guards that resolve to false when those macros
  are undefined.
- `src/platform.c:78-79` — `_glfwSelectPlatform()` short-circuits
  `GLFW_PLATFORM_NULL` straight to `_glfwConnectNull()`; `src/platform.c:82`
  is the error string for a binary with nothing else compiled in.

What X11 and Wayland add on top is the *probes*, not the library:

| Probe | Citation |
| --- | --- |
| `find_package(X11 REQUIRED)` | `src/CMakeLists.txt:176` |
| `FATAL_ERROR "RandR headers not found"` | `src/CMakeLists.txt:181` |
| `FATAL_ERROR "Xinerama headers not found"` | `src/CMakeLists.txt:187` |
| `FATAL_ERROR "Xkb headers not found"` | `src/CMakeLists.txt:191` |
| `FATAL_ERROR "Xcursor headers not found"` | `src/CMakeLists.txt:199` |
| `FATAL_ERROR "XInput headers not found"` | `src/CMakeLists.txt:205` |
| `FATAL_ERROR "X Shape …"` (Xext) | `src/CMakeLists.txt:211` |
| `FATAL_ERROR "Failed to find wayland-scanner"` (a host program) | `src/CMakeLists.txt:77` |

None of these fire with `-DGLFW_BUILD_X11=OFF -DGLFW_BUILD_WAYLAND=OFF`, and
`src/CMakeLists.txt:47-66` (the `target_sources` blocks and the
`GLFW_BUILD_X11 OR GLFW_BUILD_WAYLAND` block that pulls in `posix_poll.c` and
`linux_joystick.c`) is skipped entirely. I checked `src/CMakeLists.txt` for any
`FATAL_ERROR` outside those blocks; the only others are the two removal notices
for `GLFW_USE_OSMESA` and `GLFW_USE_WAYLAND` (`CMakeLists.txt:17,23`), which
fire only if those removed variables are set.

**The honest consequence:** the installed GLFW creates no real window. A
consumer must call `glfwInitHint(GLFW_PLATFORM, GLFW_PLATFORM_NULL)` at
runtime. This is not a workaround — both switches are upstream's own and
`GLFW_BUILD_X11`/`GLFW_BUILD_WAYLAND` are documented options
(`CMakeLists.txt:29-30`) — but "GLFW builds" here means "GLFW's null backend
builds".

## What it installs

- `lib/libglfw3.a` — static. `BUILD_SHARED_LIBS` is already OFF upstream
  (`CMakeLists.txt:9`); `src/CMakeLists.txt:100-106` picks the output name
  `glfw3` for a static build.
- `include/GLFW/glfw3.h`, `include/GLFW/glfw3native.h` (`CMakeLists.txt:98`).
- `lib/pkgconfig/glfw3.pc` from `CMake/glfw3.pc.in` (configured at
  `src/CMakeLists.txt:342`, installed at `CMakeLists.txt:110-112`).
- `lib/cmake/glfw3/glfw3Config.cmake`, `glfw3ConfigVersion.cmake`,
  `glfwTargets.cmake` (`CMakeLists.txt:100-109`).
- **No executables.** Examples and tests are off; see below.

## Switches passed, and why

| Switch | Reason |
| --- | --- |
| `GLFW_BUILD_X11=OFF` | No X11, no RandR/Ininerama/Xkb/Xcursor/XInput/Xext headers, anywhere on any of these targets. Would `FATAL_ERROR` at `src/CMakeLists.txt:176-211`. Already the effective value on mingw (`WIN32` false ⇒ `cmake_dependent_option` forces OFF, `CMakeLists.txt:29`). |
| `GLFW_BUILD_WAYLAND=OFF` | Same, plus `src/CMakeLists.txt:77` requires a `wayland-scanner` **host program**, which nothing here guarantees. |
| `GLFW_BUILD_EXAMPLES=OFF` | Defaults ON for a standalone build (`GLakeLists.txt:10`); 12 example programs, host code. |
| `GLFW_BUILD_TESTS=OFF` | Defaults ON standalone (`CMakeLists.txt:11`); 21 test programs, host code. |
| `GLFW_BUILD_DOCS=OFF` | Defaults ON (`CMakeLists.txt:12`) and `docs/CMakeLists.txt:3` requires Doxygen ≥ 1.9.8. |
| `BUILD_SHARED_LIBS=OFF` | Already the upstream default (`CMakeLists.txt:9`); passed explicitly because a target prefix has no loader path for a versioned object. |
| `GLFW_BUILD_EXAMPLES=OFF` | Defaults ON for a standalone build (`CMakeLists.txt:10`); 12 example programs, host code. |
| `GLFW_BUILD_TESTS=OFF` | Defaults ON standalone (`CMakeLists.txt:11`); 21 test programs, host code. |

**No `android.lua`.** Nothing here is an Android-only switch. Both backend
switches are the same package-level decision on every system, so they belong in
the system-neutral fallback (AGENTS.md, 'Writing a build recipe'), and there is
no `if (ANDROID)` branch in GLFW's own CMake for them to unlock.

## Dependencies

**None.** No `require()` other than `glfw@source`. `find_package(Threads
REQUIRED)` (`CMakeLists.txt:48`) is the only find, and every system already
exports `-DTHREADS_PREFER_PTHREAD_FLAG=ON` in `$CMAKE_FLAGS` precisely because
Bionic keeps pthreads in libc where FindThreads' libc probe fails.
`src/CMakeLists.txt:184-206` then does three *optional* `find_library` calls
(`rt`, `m`, `${CMAKE_DL_LIBS}`); each is guarded by `if (...)` plus
`mark_as_advanced`, so a miss is a no-op — which is what happens for `librt` in
the NDK sysroot.

## Source

`https://github.com/glfw/glfw/archive/refs/tags/3.5.1.tar.gz`. GLFW publishes
**no binary release asset** on any tag — I checked the asset list of the
latest release and `https://github.com/glfw/glfw/releases/download/3.5.1/glfw-3.5.1.tar.gz`
returns HTTP 404. The tag archive is the same artifact GitHub links as
"Source code". Archive's single top-level directory: `glfw-3.5.1`, stripped by
the recipe. 159 files, 5.0 MB.

## API-level gating

I grepped every file in `src/` for each of the documented API walls —
`process_vm_readv`, `posix_spawn`, `mblen`, `getpass`, `O_BINARY`,
`POSIX_MADV_*`, `mktime_z`, `nl_langinfo`, `iconv`, `stderr`, `scandir`,
`getline`, `pidfd_*`. In the sources that a null-only build actually compiles
(`context.c`, `init.c`, `input.c`, `monitor.c`, `platform.c`, `vulkan.c`,
`window.c`, `egl_context.c`, `osmesa_context.c`, `null_*.c`, `posix_time.c`,
`posix_thread.c`, `posix_module.c`) there are **zero** hits. The only hits in
the tree are:

- `memfd_create` — `src/CMakeLists.txt:70` and `src/wl_window.c:106`, both
  inside `if (GLFW_BUILD_WAYLAND)`, which is off.
- `dlopen` — `src/posix_module.c:39`, Bionic has it from API 21.
- `pthread_*` — `src/posix_thread.c:44,58,65,71,78,90,97,103`, Bionic has these
  in libc at every level.
- `clock_gettime` — `src/posix_time.c:47,55`, Bionic has it at every level.

So the API level is not a variable for this package: the compiled set of
sources is identical at 21 and at 35.

One C dialect note: `src/CMakeLists.txt:97-99` sets `C_STANDARD 99` with
`C_EXTENSIONS OFF`, i.e. strict `-std=c99`, and `src/CMakeLists.txt:269` adds
`_DEFAULT_SOURCE` when `CMAKE_SYSTEM_NAME STREQUAL "Linux"`. Our Android
toolchain files deliberately set `CMAKE_SYSTEM_NAME` to `Linux`
(`packages/aarch64-android35/aarch64-linux-android35-toolchain.cmake:2`), so
that `_DEFAULT_SOURCE` does fire on Android — which it must, or `posix_*` would
lose its declarations under `-std=c99`.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | Null-only source set, no API-gated call (see above), `find_package(Threads REQUIRED)` satisfied by the system's `-DTHREADS_PREFER_PTHREAD_FLAG=ON`, `_DEFAULT_SOURCE` supplied at `src/CMakeLists.txt:269` because our toolchain sets `CMAKE_SYSTEM_NAME=Linux`. |
| `aarch64-android24` | WILL BUILD | As above; the API level is not an input to this build. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above. GLFW is pure C99 with no SIMD and no architecture branches — `grep -rn '\bAVX\|\bSSE\|__aarch64__\|__x86_64__' src/` finds nothing outside `deps/`, which is not compiled into the library. |
| `x86_64-mingw` | WILL BUILD | `CMAKE_SYSTEM_NAME=Windows`, so `WIN32` is true and `GLFW_BUILD_WIN32` stays ON (`CMakeLists.txt:27`); `GLFW_BUILD_X11`/`GLFW_BUILD_WAYLAND` are already forced OFF by their `UNIX` condition, so passing them explicitly is harmless and identical to the other rows. The Win32 sources use only `<windows.h>` and the Win32 SDK. |
| `clang-native` | WILL BUILD | Same source set as the Android rows. Worth noting the default here would have been *different*: `UNIX` is true, so both backends default ON and the build would have tried `find_package(X11 REQUIRED)`. The recipe turns them off, so this row is identical to the others. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.

## What a reviewer should scrutinise

1. **"GLFW builds" means "GLFW's null backend builds."** A reviewer who expects
   a usable window here is wrong, and the recipe's comment says so. But it is
   also the reason this is WILL BUILD and not WILL NOT BUILD: the question is
   whether the *library* compiles and installs, and it does, using upstream's
   own documented switches.
2. **`find_package(Threads REQUIRED)`** (`CMakeLists.txt:48`) is the one probe
   that must succeed on every row. It should, given
   `THREADS_PREFER_PTHREAD_FLAG=ON` is already in every system's
   `$CMAKE_FLAGS`, but this is the flag I would expect to break first if
   something did.
3. **`glfw3.pc`'s `Libs.private`** is built from `glfw_PKG_LIBS`
   (`src/CMakeLists.txt:104-107,340-344`), which on a null-only Unix build is
   just `-lm` and possibly `-ldl`. That is correct for this prefix and worth
   confirming against the real generated file after a build.
4. **`CMAKE_C_EXTENSIONS OFF` + `_DEFAULT_SOURCE`** only works because our
   toolchain files set `CMAKE_SYSTEM_NAME` to `Linux`. If that ever changes to
   `Android`, `src/CMakeLists.txt:269` stops firing and `posix_time.c` /
   `posix_thread.c` lose their declarations under `-std=c99`. This is a real
   coupling to a deliberate system-level decision, not a package bug.