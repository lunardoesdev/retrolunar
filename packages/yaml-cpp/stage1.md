# yaml-cpp build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.8.0 (`github.com/jbeder/yaml-cpp/archive/refs/tags/0.8.0.tar.gz`)
- Build system: **CMake** (`generic.lua:8`)
- Installs: `lib/libyaml-cpp.a`, `include/yaml-cpp/**`,
  `lib/pkgconfig/yaml-cpp.pc`, plus a CMake package config
- Requires: `yaml-cpp@source` only (`generic.lua:1`). No dependencies — yaml-cpp
  has no external library requirements.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The library is `src/*.cpp` (`scanner.cpp`, `parser.cpp`, `emitter.cpp`, `node.cpp`, `ostream_wrapper.cpp`) plus the bundled `contrib/` sources. It uses the STL, `<cstdio>`, and `utf8cpp` vendored in `include/`. yaml-cpp performs its own Unicode width handling via `contrib/width.h` and does **not** call `wcwidth`, `mbrtowc` or any locale-dependent function — that is the usual Bionic gap for a text library and it does not apply here. Nothing API-24+. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; yaml-cpp has no SIMD and no arch-specific code. |
| x86_64-mingw | WILL BUILD | As above. yaml-cpp's CMake has no WIN32-specific source list. |
| clang-native | WILL BUILD | Native; same flag set. |

**API level notes.** **No new wall.** yaml-cpp's compiled libc surface is
`fopen`/`fstream`/`istream` (for `LoadFile`/`operator<<` to streams) and
`snprintf` in the `ostream_wrapper`. It does not use `nl_langinfo` (API 26),
`iconv` (API 28, and Bionic has no separate `-liconv` — irrelevant here since
none is used) or `mktime_z`. The API level is inert.

**Risks / what a reviewer should check.**
1. **The recipe's three `--*_BUILD_*` flags are load-bearing in a way worth
   naming.** `-DYAML_CPP_BUILD_TESTS=OFF` matters because yaml-cpp's test suite
   links **gtest**, which is not in this prefix — leaving it on would fail at
   configure or link. `-DYAML_CPP_BUILD_TOOLS=OFF` and
   `-DYAML_CPP_BUILD_UTILS=OFF` keep two host programs out. All three are
   upstream switches, which is what AGENTS.md asks for.
2. **`-DYAML_BUILD_SHARED_LIBS=OFF` is spelled with `YAML_` and no `_CPP`.**
   yaml-cpp's option really is named `YAML_BUILD_SHARED_LIBS` (not
   `YAML_CPP_BUILD_SHARED_LIBS`) — an upstream inconsistency, and the recipe has
   it right. **A reviewer should double-check this on a version bump**, because
   if upstream ever renames it to match, the flag silently becomes a no-op and
   a `libyaml-cpp.so.0.8.0` would install with no error. The verification step
   below searches for `*.so*` and is the check that catches it.
3. **No `-std=` is pinned.** yaml-cpp 0.8.0 requires C++11 and its CMake sets
   the requirement itself, so all six `$CXX` defaults satisfy it. Correct — no
   language fact is hardcoded.
4. **0.8.0 is the current release.** No upgrade pressure, and this is the
   post-`0.7` API (the `Node`/`NodeBuilder` interface), so consumers written
   against 0.6 need adjusting — a migration note rather than a build risk.
5. `CMAKE_CXX_COMPILER_ID` is not checked anywhere in this recipe, so no
   compiler-specific flag is in play; gcc and clang take the same path.

**How to verify once built.**
- `lib/libyaml-cpp.a`, `include/yaml-cpp/yaml.h`, `include/yaml-cpp/node/parse.h`,
  `lib/pkgconfig/yaml-cpp.pc`
- `pkg-config --modversion yaml-cpp` → `0.8.0`
- `llvm-objdump -f lib/libyaml-cpp.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libyaml-cpp.a | grep -c YAML::Load` → non-zero,
  proving the mangled C++ symbols are present
- **`find $PREFIX/lib -name 'libyaml-cpp.so*'` must be empty** — this is the
  check for risk 2, and the only way to notice the option name drifting
- `llvm-nm -u lib/libyaml-cpp.a | grep -cE 'wcwidth|mbrtowc'` must be **0**,
  confirming no locale dependency leaked in and that the build is safe at any
  API level