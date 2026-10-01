# physfs build forecast

- Recipe: `generic.lua`, source `source.lua` (no `android.lua` — see risk 5)
- Version pinned: 3.2.0 (tag `release-3.2.0`, `icculus/physfs`)
- Build system: CMake, `cmake_minimum_required(VERSION 3.0)`
  (`CMakeLists.txt:14`)
- Header-only: **no.** `libphysfs.a` is built.
- Installs: `lib/libphysfs.a`, `include/physfs.h`,
  `lib/pkgconfig/physfs.pc`, `lib/cmake/PhysFS/PhysFSConfig.cmake`.
- Requires: `physfs@source` only. **No external dependencies** — see risk 3.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `PHYSFS_BUILD_TEST=OFF` removes `add_executable(test_physfs)` *and* its install (`CMakeLists.txt:215`); `PHYSFS_BUILD_SHARED=OFF` leaves one static archive. The Android backend needs `<jni.h>` and `<android/log.h>` (`src/physfs_platform_android.c:12-14`), and I verified both headers are present in the NDK sysroot. No API-21 wall: the platform layer uses `open`/`read`/`lseek`/`readdir` and no wall symbol. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. `physfs_platforms.h:29` selects `PHYSFS_PLATFORM_WINDOWS` on `_WIN32`/`_WIN64` without `__CYGWIN__`, and `CMakeLists.txt:170-172` then adds `-DPHYSFS_STATIC` so the archive does not try to export DLL symbols. `PHYSFS_NO_CDROM_SUPPORT` is not needed — PhysFS guards its CD-ROM code on that macro, not on the platform. |
| clang-native | WILL BUILD | As above, on the `PHYSFS_PLATFORM_UNIX` backend (`physfs_platforms.h:48-51`). |

`armv7a-*`/`i686-*` match the `aarch64-*` rows.

## Backends: the brief asked which build by default, and the answer is "all,
and that is correct"

The VFS archiver backends are ten `option()`s, **all defaulting TRUE**
(`CMakeLists.txt:116-146`): `PHYSFS_ARCHIVE_ZIP`, `_7Z`, `_GRP`, `_WAD`,
`_HOG`, `_MVL`, `_QPAK`, `_SLB`, `_ISO9660`, `_VDF`.

**None of them is turned off in this recipe, and that is the deliberate
answer to the brief's question.** The brief asked to disable any backend
"that needs a display or a host filesystem assumption you cannot justify".
There are none:

- **No display.** PhysFS is a file-I/O abstraction; nothing in it opens a
  window, a display server or an input device.
- **No host-filesystem assumption.** Every archiver is a pure decoder over a
  caller-supplied byte buffer. Critically, the compressed formats do **not**
  look for a system library: 7z and zip carry vendored decompressors
  (`src/physfs_lzmasdk.h`, `src/physfs_miniz.h`), and `CMakeLists.txt` has no
  `find_package(ZLIB)` or `find_package(LZMA)` anywhere. Turning them off
  would shrink the library for no buildable reason.
- The two filesystem-ish archivers, `dir` and `unpacked`, use only POSIX
  `open`/`read`/`write`/`readdir` (`src/physfs_archiver_dir.c`,
  `src/physfs_platform_posix.c:19,124`) — nothing a target lacks.
- The one genuinely platform-sensitive capability, CD-ROM support, PhysFS
  disables **for Android by itself**: `src/physfs_platforms.h:47` sets
  `PHYSFS_NO_CDROM_SUPPORT` in the `__ANDROID__` branch (`:43-47`), driven by
  the NDK compiler's own predefine.

## Risks / what a reviewer should check

1. **`PHYSFS_BUILD_TEST=OFF` is load-bearing, and worse than it looks.**
   It defaults TRUE (`:199`). Beyond building a host program,
   `CMakeLists.txt:215` does `list(APPEND PHYSFS_INSTALL_TARGETS
   test_physfs)` — so an interactive terminal test binary would be
   **installed into `$PREFIX/bin`**. It also drags in `find_path` for
   readline (`:200`) and `find_library` for curses (`:203`), which on a cross
   build would consult the sysroot through `CMAKE_FIND_ROOT_PATH_MODE_LIBRARY
   ONLY`.
2. **`PHYSFS_BUILD_DOCS=OFF`** defaults TRUE (`:245`) and reaches
   `find_package(Doxygen)` + `add_custom_target(docs …)`. Doxygen is not in
   this prefix; the target would simply not be created, but the option is off
   to keep that probe out of the configure log.
3. **No external dependencies, and that is a verified claim.** The only
   `find_library` calls in the file are `pthread` (`:58`), `be`/`root` for
   Haiku (`:48-50`) and the readline/curses pair under `PHYSFS_BUILD_TEST`
   (`:200-205`). `pthread` is inside `if(UNIX AND NOT WIN32 AND NOT APPLE)`
   and is `find_library`, not `find_package`, so on Android it resolves
   against the sysroot or is simply not found — and then
   `if(PTHREAD_LIBRARY)` at `:59` leaves `OPTIONAL_LIBRARY_LIBS` untouched
   rather than failing. No `require()` beyond `physfs@source` is needed.
4. **The static library's name differs per platform, and both spellings are
   deliberate.** `CMakeLists.txt:156` sets `OUTPUT_NAME "physfs"` only
   `if(NOT MSVC)`; on MSVC the archive keeps the name `physfs-static` to
   avoid colliding with the DLL's import library. We are on mingw, which is
   not MSVC, so the file is `lib/libphysfs.a` and `physfs.pc`'s `-lphysfs`
   resolves. Worth confirming on mingw rather than assuming.
5. **No `android.lua` is needed, and here is why.** The Android backend is
   selected by the **compiler's** `__ANDROID__` predefine at
   `src/physfs_platforms.h:43-47`, which the NDK wrapper sets — the same
   principle AGENTS.md states for libvpx/glog. There is no cmake variable,
   no `if(ANDROID)` block and no build-system gate anywhere in
   `CMakeLists.txt` for Android, so there is no Android-only switch for a
   recipe to set. Creating an `android.lua` would mean hardcoding a platform
   fact into a second file for no effect.
   `physfs_platform_android.c` includes `<jni.h>` and `<android/log.h>`; I
   checked both in the NDK 28 sysroot and both are present. The `__android_log_*`
   calls live in a static archive with no link step, and every Android system
   here already carries `-llog` in `LDFLAGS` for exactly this class of
   reference.
6. `src/physfs.c:1236` carries `#ifndef __ANDROID__` around APK-vs-directory
   handling — a consumer-side behaviour difference, not a build one.

## How to verify once built

- `lib/libphysfs.a` exists. **No `libphysfs.so*`** — that is the check that
  `PHYSFS_BUILD_SHARED=OFF` took.
- `include/physfs.h` exists (single public header; there is no
  `include/physfs/` subdirectory).
- `lib/pkgconfig/physfs.pc` exists and `pkg-config --modversion physfs`
  reports **3.2.0** — **the module name is `physfs`, not `physfs-static`**
  (`extras/physfs.pc.in:7`).
- `lib/cmake/PhysFS/PhysFSConfig.cmake` exists (`CMakeLists.txt:227-231`).
- **`find $OUT -name 'test_physfs*'` must return nothing.** This is the
  load-bearing check for risk 1: the test program is not merely unbuilt, it
  must not be *installed* into `$PREFIX/bin`. Also `find $OUT/bin` should
  return nothing at all.
- The archive should contain all ten archivers. `llvm-nm lib/libphysfs.a`
  and grep for `PHYSFS_Archiver_` symbols: `zip`, `sevenZ`, `GRP`, `WAD`,
  `HOG`, `MVL`, `QPAK`, `SLB`, `ISO9660`, `VDF` — ten, plus `dir` and
  `unpacked`. Fewer means an archiver was compiled out.
- Compare the two systems' `include/` with `diff -r`: any difference is a bug.
