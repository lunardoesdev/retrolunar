# fmt build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 11.1.4
- Build system: cmake
- Installs: `lib/libfmt.a` (static); `include/fmt/*.h` plus the generated `fmt/core.h` and `include/fmt/base.h`; `lib/pkgconfig/fmt.pc`; `lib/cmake/fmt/fmt-config.cmake`; **no binaries** — fmt 11.1.4's CMakeLists.txt contains no `add_executable`
- Requires: `fmt@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | fmt is a header-heavy C++11 library whose only compiled translation unit is `src/format.cc`, plus `src/os.cc` (which reads `/proc/self/maps` on Linux) and `src/os_unix.cc`. Those use `<cstdio>`, `<cstring>`, `<fstream>`-free paths and `fmt::file`; `os.cc` guards its Linux-specific `/proc` read behind `#ifdef FMT_OS_LINUX` with a portable fallback, so Bionic is fine. `FMT_TEST=OFF` and `FMT_DOC=OFF` (`generic.lua:9`) remove the test suite and the doc build. Nothing needs an API above 21. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | fmt is arch-neutral; no SIMD or intrinsics. |
| x86_64-mingw | WILL BUILD | fmt's `os_windows.cpp` is selected by `_WIN32`, and `BUILD_SHARED_LIBS=OFF` avoids the `__declspec` question. |
| clang-native | WILL BUILD | Native; topackage.md:221 records fmt 11.1.4 as `[x]` with `pkg-config --modversion fmt` = 11.1.4 and `elf64-littleaarch64` archive members. |

## API level notes

**21 is the floor and fmt clears it.** fmt is one of the few C++
libraries in the shard that is genuinely self-contained, and it is the
dependency of `packages/spdlog`, so its reliability is load-bearing.

## Risks / what a reviewer should check

- **`FMT_INSTALL=ON` at `generic.lua:9` is doing real work and is easy to
  misread.** The recipe comment says it "pulls the headers and the `.pc`
  file in", which is true — but `FMT_INSTALL` also governs whether the
  bundled `bin/fmt` program is installed. The comment calls the bundled
  program a host program it is turning off, but does not name the flag that
  does it; `FMT_TEST=OFF` covers the *test* target, not `fmt`. So
  `$OUT/bin/fmt` may well exist as a target binary. Harmless (nothing runs
  it here), but the comment is imprecise and the "Installs" line in this
  file reflects the ambiguity.
- **fmt 11 uses C++11 as a floor** and the NDK's libc++ at API 21 is
  complete for C++11, so no `-std` override is needed. Worth knowing,
  because a future fmt major that requires C++17 would need one — and the
  Android systems' `$CXXFLAGS` sets no `-std`, leaving clang's default
  (gnu17) in charge.
- **`fmt/format.cc` is a single large translation unit.** Under
  `cmake --build build --parallel 1` it is compiled serially, which is
  correct per AGENTS.md and avoids the peak-memory problem. Nothing to fix.
- **`include/fmt/base.h` and `fmt/core.h` are generated** by fmt's own
  `base.h`/`core.h` generation step. Their presence is a good build check;
  if `FMT_INSTALL` had been mis-passed they would be missing.

## How to verify once built

- `lib/libfmt.a`
- `include/fmt/format.h`, `include/fmt/base.h` (generated),
  `include/fmt/core.h` (generated)
- `lib/pkgconfig/fmt.pc` and `pkg-config --modversion fmt` → `11.1.4`
- `readelf -h lib/libfmt.a` → `Machine: AArch64` on Android targets
- `$OUT/bin` does not exist
- `lib/cmake/fmt/fmt-config.cmake` present
