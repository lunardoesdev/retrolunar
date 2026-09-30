# nlohmann-json build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.11.3 (git tag archive)
- Build system: CMake — but only the install rules do any work.
- Installs: `include/nlohmann/json.hpp` (and the other headers),
  `nlohmann_json.pc`, and a CMake package config. **No library file.**
- Requires: `nlohmann-json@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled. `cmake --build build --parallel 1` has no compilation to perform — nlohmann's `JSON_BuildTests=OFF` at `generic.lua:10` removes the test suite, and the library target is `INTERFACE`. The install only copies files. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is byte-identical on every system and
there is no architecture check to make. The recipe says so at `:7-9` and is
explicit that the toolchain flags are "harmless here" and kept only for
uniformity with the rest of the tree — which is the right framing.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*` — the recipe has no step that could observe a level, and the
payload is a single header.

**Risks / what a reviewer should check.**

1. **`JSON_BuildTests=OFF` is the one switch and it is the right one.** nlohmann's
   default `JSON_BuildTests` is **ON**, and the test tree is thousands of
   translation units of host-only code — the single largest compile in this
   shard if left enabled. This switch is what keeps the recipe fast and
   cross-safe.
2. **`cmake_minimum_required` policy under cmake 4.x.** nlohmann 3.11.3
   declares a 3.1-era minimum, which cmake 4.x refuses; the systems'
   `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` in `$CMAKE_FLAGS` covers it, so
   nothing is needed here. Worth knowing that the recipe is *depending* on
   that system flag — if it is ever removed, this recipe breaks.
3. **The recipe passes `$CMAKE_FLAGS` for a build that compiles nothing.** That
   is a deliberate, documented choice (`:8-9`) and I agree with it: keeping
   one uniform invocation shape across the tree is worth more than avoiding a
   few harmless `-D` arguments.
4. **No library means no link line.** A consumer adds `-I$PREFIX/include` and
   nothing else — worth stating because a prefix full of `.pc` files can
   mislead someone into expecting `Libs:` to be non-empty. Check
   `nlohmann_json.pc`: its `Libs:` should be empty or absent.
5. **`topackage.md:151` records this as built** — *"header-only:
   include/nlohmann/json.hpp plus a CMake package config and
   nlohmann_json.pc. Nothing is compiled, so it is identical on every
   system."* **That entry is exactly right** and is the model for how a
   header-only package should be described.
6. `cmake --build build --parallel 1` is correct (`:11`), though it is a no-op.

**How to verify once built.**

- `include/nlohmann/json.hpp` exists, and `include/nlohmann/json_fwd.hpp` for
  the forward-declaration form.
- `lib/pkgconfig/nlohmann_json.pc` exists; `pkg-config --modversion
  nlohmann_json` reports 3.11.3.
- **`pkg-config --libs nlohmann_json` should be empty** — that is the direct
  check that nothing was compiled. Any `-l` here would mean a library slipped
  in.
- A CMake package config should be installed under `lib/cmake/nlohmann_json/`
  or `share/`; check whichever path the project used.
- `find $OUT -name '*.a' -o -name '*.so'` must return **nothing**. That is the
  cleanest single check of "nothing was compiled".
- Compare the two systems' installs byte-for-byte
  (`diff -r` between two systems' `include/nlohmann/`): any difference is a
  bug, since the package is architecture-independent.
