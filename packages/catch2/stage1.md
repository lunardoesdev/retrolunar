# catch2 build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 3.8.1
- Build system: cmake
- Installs: `lib/libCatch2.a`, `lib/libCatch2Main.a` (static); `catch2/` and `catch2-matchers/` headers; `lib/cmake/Catch2/Catch2Config.cmake`; `share/pkgconfig/catch2.pc` and `share/pkgconfig/catch2-with-main.pc` (Catch2 3.8.1 ships both, CMakeLists.txt:172-188)
- Requires: `catch2@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Catch2 v3 is C++14. Its sources use the standard library, `<cstdio>`, `<stdexcept>` and `std::` facilities only; the `CATCH_CONFIG_*` machinery does not reach for any POSIX extension. The recipe turns off tests and extras (`generic.lua:9`), which removes the entire `src/catch2/.../Test*` tree and the reporters that would be the only plausible place for a platform call. The NDK's `libc++` is complete enough for C++14 at API 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | Catch2 has no arch-conditional code. |
| x86_64-mingw | WILL BUILD | Same C++14, plus Catch2 already supports MSVC/mingw as a first-class platform. `BUILD_SHARED_LIBS=OFF` avoids any DLL-export question. |
| clang-native | WILL BUILD | Native; topackage.md:226 records Catch2 3.8.1 as `[x]` with `elf64-littleaarch64` archive members and no `.pc`. |

## API level notes

Not a variable. Catch2 is a pure C++ library over the standard library, so
the Android API level does not enter into it. The only Android-specific
consequence of using it *from* a target program is that the consumer needs
`libc++`, which every NDK target has.

## Risks / what a reviewer should check

- **`-DCATCH_INSTALL_DOCS=OFF` and `-DCATCH_INSTALL_EXTRAS=OFF` are both
  on** (`generic.lua:9`). Docs would otherwise pull a Doxygen/LaTeX
  dependency into the build; extras pulls approvaltests and benchmark
  sources. Both are host-side and correctly off.
- **`BUILD_SHARED_LIBS=OFF` gives two archives**, `libCatch2.a` and
  `libCatch2Main.a`. A consumer that only links `Catch2::Catch2` gets the
  assertions; `Catch2::Catch2WithMain` is what supplies `main`. Worth
  stating in the readme rather than the recipe.
- **The `-Werror` question.** Catch2's own CMake does not add `-Werror`, and
  the Android systems' `$CXXFLAGS` is `-O2 -fPIC -I$PREFIX/include -DANDROID`
  with no warning flags, so a warning in a newer clang cannot become an
  error. Good.
- **GitHub tag archive, not a release asset** (`source.lua:5`). Fine for
  cmake; no generated script is lost.

## How to verify once built

- `lib/libCatch2.a`, `lib/libCatch2Main.a`
- `include/catch2/catch_test_macros.hpp`, `include/catch2/catch_all.hpp`
- `lib/cmake/Catch2/Catch2Config.cmake`
- `readelf -h lib/libCatch2.a` → `Machine: AArch64` on Android targets
- `pkg-config --modversion catch2` and `pkg-config --modversion catch2-with-main` both report `3.8.1`; `find_package(Catch2)` also works
