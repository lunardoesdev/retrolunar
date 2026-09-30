# tomlplusplus build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.4.0
  (`github.com/marzer/tomlplusplus/archive/refs/tags/v3.4.0.tar.gz`)
- Build system: **CMake** (`generic.lua:9`)
- Installs: `include/toml.hpp`, `include/toml_forward.hpp`, `include/toml.h`
  (per `generic.lua:6-8`), plus a generated CMake package config.
  **No library, no pkg-config file.**
- Requires: `tomlplusplus@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `-DTOMLPLUSPLUS_BUILD_TESTS=OFF` (`generic.lua:9`) leaves only the `install` target, which is a copy. tomlplusplus is header-only with no compiled sources, so nothing reads a sysroot and no Bionic API-level wall applies. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

`armv7a-android*` and `i686-android*` match `aarch64-android*` on every row.

**API level notes.** **Not applicable by construction**: header-only, so
`cmake --build build --parallel 1` (`generic.lua:10`) compiles nothing and the
installed tree is byte-identical on all six systems. The C++ requirement is
imposed on the *consumer* — tomlplusplus 3.4 needs C++17 — and `<filesystem>`
/`<charconv>` are NDK-provided at API 21, so there is no wall. But that is a
claim about a consumer's compile, which this recipe cannot verify.

**Risks / what a reviewer should check.**
1. **The install target copies three distinct header spellings**
   (`generic.lua:6-8`): `toml.hpp` (the C++ header), `toml_forward.hpp` (the
   forward declarations used for the ABI-stable pattern) and `toml.h` (the C
   shim). The C shim matters: it lets a C translation unit `#include <toml.h>`
   to parse TOML without any C++ linkage, and it is the piece most likely to
   be dropped by a well-meaning "just install the header" cleanup. A reviewer
   should confirm all three land.
2. **No `.a` and no `.pc` is correct**, not a defect — same shape as
   `packages/toml11/stage1.md` and `packages/stb/stage1.md` in this shard.
3. **`TOMLPLUSPLUS_BUILD_TESTS=OFF` is upstream's default**, documenting intent;
   the tests are a host C++ suite that would produce unrunnable target binaries
   on a cross build.
4. **`source.lua:10` uses `marzer/tomlplusplus`**, which was the historical
   home; the project moved to `marzer` → `tomlplusplus` naming and is now
   maintained under a different org name upstream. The tag `v3.4.0` in this
   repo still resolves (confirmed HTTP 200 during research), so the recipe is
   correct as written — but if a reviewer tries to "update to upstream's
   current home" they should check that the tag namespace still exists there.
5. No `-std=` is pinned and none should be: the consumer picks the dialect.

**How to verify once built.**
- `include/toml.hpp`, `include/toml_forward.hpp`, `include/toml.h`,
  `lib/cmake/tomlplusplus/tomlplusplusConfig.cmake`
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**,
  the check that nothing was compiled
- `test -f $PREFIX/include/toml.h` → true, proving the C shim landed (risk 1)
- `grep -m1 'TOMLPLUSPLUS_VERSION' $PREFIX/include/toml.hpp` → should encode
  3.4.0, confirming the pinned headers
- A `find` diff against `$NESTDIR/source/tomlplusplus/` should show only
  those three headers copied and nothing else installed.