# googletest build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 1.17.0
- Build system: cmake
- Installs: `lib/libgtest.a`, `lib/libgtest_main.a`, `lib/libgmock.a`, `lib/libgmock_main.a` (static); `include/gtest/*.h`, `include/gmock/*.h`; `lib/pkgconfig/gtest.pc`, `lib/pkgconfig/gmock.pc`; `lib/cmake/GTest/GTestConfig.cmake`
- Requires: `googletest@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | googletest is C++14 and its runtime uses only the standard library, `<cstdio>`, `<cstring>` and POSIX `open`/`read`/`close`/`write` for its death-test and file-redirect machinery (`gtest-port.cc`, `gtest.cc`), all of which are in Bionic at API 21. `gtest_build_tests=OFF` and `gmock_build_tests=OFF` (`generic.lua:10`) remove the test binaries, which is where a platform dependency would otherwise appear (gtest's death tests fork and the thread tests use pthreads). Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Endian-neutral; gtest's internal hashing is explicit. |
| x86_64-mingw | WILL BUILD | googletest has first-class MSVC/mingw support including `_setmode` for the file-redirect tests; `BUILD_SHARED_LIBS=OFF` avoids `__declspec` entirely. |
| clang-native | WILL BUILD | Native; topackage.md:228 records GoogleTest 1.17.0 as `[x]` with both `gtest` and `gmock` reporting 1.17.0 via pkg-config and `elf64-littleaarch64` archive members. |

## API level notes

**21 is the floor and googletest clears it** — with one nuance worth
naming, because it is the kind of thing that bites later. gtest's
*death tests* and *thread tests* would need `fork`/`pthread_create`, but
both live under the disabled test targets, and death tests additionally
are inherently a *run*-time feature that this repo must never exercise on
a target anyway. So the API level is not a factor for the library as
configured.

## Risks / what a reviewer should check

- **The `-DINSTALL_GTEST=OFF` warning at `generic.lua:7-9` is the single
  most valuable comment in this shard's recipes.** It says: "do not pass
  `-DINSTALL_GTEST=OFF`: googletest's own `install()` rules live inside
  that option's guard, so turning it off installs nothing at all". That is
  a counter-intuitive upstream behaviour that a reviewer would otherwise
  "fix" by adding the flag, silently producing an empty package. topackage.md:228
  records the same fact. Both places say it; good.
- **There is no duplicate `lib/libgtest.a` layout in 1.17.0.** An earlier
  version of this file told the builder to expect one; that was wrong.
  `LIBRARY_OUTPUT_DIRECTORY` *does* appear in the tree, at
  `googletest/cmake/internal_utils.cmake:174`, where it is set to
  `${CMAKE_BINARY_DIR}/lib` — a build-tree path under `-DINSTALL_GTEST=OFF`
  that no install rule reads. So there is no `lib/` subdirectory in the
  install and `$OUT/lib` holds exactly the four archives.
- **`BUILD_SHARED_LIBS=OFF` (`generic.lua:10`) gives four archives, not
  one.** A consumer wanting `gmock` links `libgmock.a` *and* `libgtest.a`;
  a consumer wanting its own `main` links `libgtest.a` and not
  `libgtest_main.a`. Worth stating in the readme.
- **googletest is the upstream gtest, not the `googlemock` split repo**,
  so `gmock` and `gtest` come from one CMake project and one version
  number. Both `.pc` files report 1.17.0. Consistent.
- **This is a dependency of `packages/draco` upstream** (draco's
  `DRACO_TESTS=OFF` is precisely what keeps that dependency out of draco's
  own build). If googletest breaks, draco is unaffected; only a consumer
  wanting draco's tests is. Good separation, and worth stating so nobody
  "helpfully" removes `-DDRACO_TESTS=OFF`.

## How to verify once built

- `lib/libgtest.a`, `lib/libgtest_main.a`, `lib/libgmock.a`, `lib/libgmock_main.a`
- `include/gtest/gtest.h`, `include/gmock/gmock.h`
- `lib/pkgconfig/gtest.pc` and `pkg-config --modversion gtest` → `1.17.0`
- `pkg-config --modversion gmock` → `1.17.0`
- `readelf -h lib/libgtest.a` → `Machine: AArch64` on Android targets
- `lib/cmake/GTest/GTestConfig.cmake` present
