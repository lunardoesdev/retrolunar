# meshoptimizer 1.3 — stage 1 build forecast

**Package:** meshoptimizer
**Version:** 1.3
**Upstream:** https://github.com/zeux/meshoptimizer
**Build system:** CMake

This is a forecast from reading upstream source, not a measurement. Nothing
here has been compiled.

## What it installs

- `lib/libmeshoptimizer.a` — static. `MESHOPT_BUILD_SHARED_LIBS` already
  defaults OFF (`CMakeLists.txt:16`), and the recipe leaves it there.
- `include/meshoptimizer.h` — installed by
  `install(FILES src/meshoptimizer.h ... DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})`
  (`CMakeLists.txt:186`).
- `lib/cmake/meshoptimizer/meshoptimizerTargets.cmake`,
  `meshoptimizerConfig.cmake` and `meshoptimizerConfigVersion.cmake`
  (`CMakeLists.txt:183`, `197-210`). CMake consumers use
  `find_package(meshoptimizer)` and link `meshoptimizer::meshoptimizer`.
- **No pkg-config file.** Upstream ships none — there is no `*.pc.in` anywhere
  in the tree, and no `configure_file` of a `.pc` in `CMakeLists.txt`. So there
  is no `pkg-config --modversion meshoptimizer`; consumers link
  `-lmeshoptimizer` and add `-I$PREFIX/include`.
- **No tools.** `demo/` and `gltfpack` are the only executables and both are
  off in the recipe.

## Dependencies

None. No `require()` of any other package, and the build asks cmake for
nothing: no `find_package`, no `pkg_check_modules`, no external include
directory. `src/meshoptimizer.h` includes only `<assert.h>` and `<stddef.h>`,
so the library is self-contained. `MESHOPT_BUILD_GLTFPACK`'s optional
`MESHOPT_GLTFPACK_BASISU_PATH` and `MESHOPT_GLTFPACK_LIBWEBP_PATH` (Basis
Universal, libwebp) are only read inside `if (MESHOPT_BUILD_GLTFPACK)`, which
the recipe turns off, so neither is needed.

## Source

`https://github.com/zeux/meshoptimizer/archive/refs/tags/v1.3.tar.gz` —
confirmed HTTP 200. Extracted top directory is `meshoptimizer-1.3`, stripped by
the recipe. `v1.3` is the newest tag on the repo.

## Switches passed, and why

| Switch | Reason |
| --- | --- |
| `MESHOPT_BUILD_DEMO=OFF` | `demo/main.cpp`, `demo/nanite.cpp`, `demo/tests.cpp` and `tools/objloader.cpp` become the `meshoptdemo` executable. Already the upstream default (`CMakeLists.txt:15`); passed explicitly because it is a host program. |
| `MESHOPT_BUILD_GLTFPACK=OFF` | `gltfpack` is a standalone command-line tool with its own JSON parser, image decoders and `gltf/*.cpp` — twenty sources, `CMakeLists.txt:38-58`. Already OFF upstream (`CMakeLists.txt:14`); passed explicitly for the same reason. It is also the only consumer of `find_package(Threads)` in the whole project (`CMakeLists.txt:174`), so turning it off removes that probe too. |
| `MESHOPT_INSTALL=ON` | The switch that pulls in the header, the archive and the CMake package config. Already the default (`CMakeLists.txt:19`); passed explicitly because the install is the entire point. |

No `android.lua`. There is no Android-only switch: the library is plain C++98
with no platform branches, and there is nothing a target fact would change.

## Per-system verdict

| Family | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | WILL BUILD | `CMakeLists.txt` has no `try_run`, no `check_*_source_runs`, no `find_package` and no `option` that depends on the target. The twenty-one `src/*.cpp` files are plain C++; I scanned them for the constructs that break under a modern default dialect (`register`, dynamic `throw()` specifications, `std::auto_ptr`, `char8_t`) and the only hit is the word "register" inside a comment at `src/meshletcodec.cpp:380`. `$SYSROOT`'s `libc++` supplies everything the sources need. The API level is irrelevant: nothing here is version-gated. |
| `aarch64-android24` | WILL BUILD | As above. |
| `aarch64-android35` | WILL BUILD | As above. |
| `x86_64-android35` | WILL BUILD | As above. The SIMD in `src/vfetchoptimizer.cpp` and `src/vertexcodec.cpp` is selected by preprocessor, not by cmake, and the scalar fallback is always compiled alongside, so the 32-bit and 64-bit targets take the same path. |
| `x86_64-mingw` | WILL BUILD | As above. `MESHOPTIMIZER_API` is only defined for `WIN32` **and** `MESHOPT_BUILD_SHARED_LIBS` (`CMakeLists.txt:105-113`), and that switch is off, so the header exports nothing and there is no `__declspec` to get wrong. Note `CMAKE_SYSTEM_NAME` is `Windows` here (unlike the Android systems), so `WIN32` *is* set — but the shared-library branch that would use it is not taken. |
| `clang-native` | WILL BUILD | As above. No host program is built, so there is nothing to run. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` for every row.
meshoptimizer's cmake never inspects the API level or the ABI, so the level is
not a variable in this family at all.

## What a reviewer should scrutinise

1. **No pkg-config file.** Unlike most packages in this tree, a consumer here
   has no `pkg-config --cflags --libs meshoptimizer`. The `.a` and the header
   install cleanly; the discovery story is CMake-only. If the tree wants
   uniformity here, a hand-written `.pc` in the recipe would be the way, as
   `packages/lua/generic.lua` does — but upstream ships none and I have not
   invented one.
2. **C++ dialect is the compiler default, not upstream's.** Upstream's own
   `Makefile` compiles the library with `-std=gnu++98` (`Makefile:26`) while
   its CMake build sets no `CMAKE_CXX_STANDARD` at all, so the library inherits
   whatever the compiler defaults to: `gnu++17` on the NDK wrappers
   (`__cplusplus == 201703L`, checked) and `gnu++20` on mingw's g++
   (`__cplusplus == 202002L`, checked). My source scan found nothing that C++17
   or C++20 removes, but this is the one thing I would want a real build to
   confirm, and it is the reason this row is not simply "trivially fine".
3. **`cmake_minimum_required(VERSION 3.5...3.30)`** (`CMakeLists.txt:1`) is at
   the floor cmake 4.x accepts, and the systems' `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`
   covers it exactly. The range form also pins policies down to 3.14.
4. **`MESHOPT_WERROR` is OFF upstream and the recipe does not touch it.** Good
   — the project sets `-Wall -Wextra -Wshadow -Wno-missing-field-initializers`
   (`CMakeLists.txt:73`) and would fail the build on any warning the cross
   compilers emit if `-Werror` were ever turned on. Worth remembering if
   someone considers adding it.
