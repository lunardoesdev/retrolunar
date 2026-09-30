# toml11 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 4.4.0
  (`github.com/ToruNiina/toml11/archive/refs/tags/v4.4.0.tar.gz`)
- Build system: **CMake** (`generic.lua:9`)
- Installs: `include/toml11/**/*.hpp`, `include/toml/*.hpp` (the compatibility
  path, per `generic.lua:6-8`), plus a generated CMake package config.
  **No library, no pkg-config file.**
- Requires: `toml11@source` only (`generic.lua:1`)

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `-DTOML11_BUILD_TESTS=OFF` (`generic.lua:9`) leaves only the `install` target, which is a copy — toml11 is header-only and has no compiled sources at all. Nothing reads a sysroot, so no Bionic API-level wall applies. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above — and since nothing is compiled, the C++ standard library never comes into it at build time. |
| clang-native | WILL BUILD | As above. |

**API level notes.** **Not applicable, and this is the design.** Header-only:
`cmake --build build --parallel 1` (`generic.lua:10`) compiles nothing, so there
is no architecture check to perform and no way a target fact could leak into
the install. The installed tree is byte-identical on all six systems.

The consequence a reviewer should hold onto: **toml11's actual C++ requirements
are imposed on the *consumer*, not here.** toml11 4.x needs C++17 and
`<charconv>`/`<filesystem>` for some parts; those are NDK-provided at API 21,
so there is no wall — but that is a claim about the consumer's compile, not
about this recipe, and this recipe cannot verify it.

**Risks / what a reviewer should check.**
1. **Header-only means there is no `pkg-config` file and no `.a`.** A reviewer
   verifying this package should be looking for `include/toml11/toml.hpp` and
   should treat the absence of a library as correct, not as a failure. This is
   the same shape as `packages/tomlplusplus/stage1.md` in this shard.
2. **The dual install path is the interesting detail.** `generic.lua:6-8` says
   the install copies into *both* `include/toml11` and `include/toml`. That
   means `#include <toml11/toml.hpp>` and the legacy `#include <toml/toml.hpp>`
   both work, which is a compatibility guarantee for existing consumers. It
   doubles the header count in the prefix; a reviewer who prefers one path
   should say so explicitly rather than let a future cleanup silently break
   `#include <toml/…>` consumers.
3. **`TOML11_BUILD_TESTS=OFF` is upstream's default**, so this documents
   intent. The tests are a host C++ suite (`tests/` with catch2-style
   harnesses) and would produce unrunnable target binaries.
4. **Version 4.4.0 is the current 4.x line.** No upgrade pressure, but note
   this is the v4 series; v5 exists upstream with a different API, so a future
   bump is not a patch-level change.
5. No `-std=` is pinned, and none should be: for a header-only package the
   consumer chooses the dialect.

**How to verify once built.**
- `include/toml11/toml.hpp`, `include/toml11/parser/*.hpp`,
  `include/toml/toml.hpp` (the compatibility path),
  `lib/cmake/toml11/toml11Config.cmake`
- `find $PREFIX -name '*.a' -o -name '*.so*' -o -name '*.pc'` → **empty**,
  which is the correct result and the check that nothing was compiled
- `test -f $PREFIX/include/toml/toml.hpp` → true, proving the compatibility
  install path (risk 2)
- `grep -m1 'TOML11_VERSION' $PREFIX/include/toml11/version.hpp` → `400` or
  whatever upstream encodes for 4.4.0, to confirm the headers are the pinned
  release
- A `find` diff against `$NESTDIR/source/toml11/` should show every header
  copied and nothing generated inside `include/`.