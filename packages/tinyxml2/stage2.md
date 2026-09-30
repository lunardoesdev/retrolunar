ACCEPT

# tinyxml2 11.0.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- All three switches are real tinyxml2 CMake options and all three are the right
  cuts: `-Dtinyxml2_BUILD_TOOLS=OFF` drops `xmltest` and `tinystr`, and
  `-Dtinyxml2_BUILD_TESTING=OFF` drops the test suite. The comment names both
  programs and calls them **host programs**, which is the category AGENTS.md
  says a cross build must not compile — not "unused", not "large".
- **`-Dtinyxml2_INSTALL=ON` is the right explicit spelling.** tinyxml2
  defaults `tinyxml2_INSTALL` on only for a top-level build, so naming it is
  the "do not depend on a default" discipline that keeps this recipe correct if
  the release ever changes. It also reads clearly as "this option is what makes
  the package exist".
- `-DBUILD_SHARED_LIBS=OFF` gives the static `libtinyxml2.a` the prefix wants.
  `cmake --build build --parallel 1` is serial, and install goes to `$OUT` via
  the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- No `sed`, no patch, no `/dev/null`, nothing hardcoded to a target, nothing
  `export`ed, and the build body stays inside AGENTS.md's allowed command list.
- `require("tinyxml2@source")` names no missing package — tinyxml2 has no
  dependency at all, which is why no include or library path is passed.

## One note for the forecast

tinyxml2 compiles a `tinyxml2.cpp` amalgamation into the library, so unlike a
genuinely header-only package this one does produce an object. That means there
*is* an architecture to check here, unlike `toml11` or `tomlplusplus` in the same
shard. `stage1.md` should not group it with the header-only packages when it
gives its "no architecture to check" reasoning, and the builder should run
`llvm-objdump -f` rather than skipping straight to a header presence check.

## Carried to the build

- `lib/libtinyxml2.a` — `llvm-objdump -f lib/libtinyxml2.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libtinyxml2.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/tinyxml2.h` — `[ -f include/tinyxml2.h ]`. That is the entire public surface.
- `lib/pkgconfig/tinyxml2.pc` — `pkg-config --modversion tinyxml2` → `11.0.0`. tinyxml2 ships one, inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `lib/cmake/tinyxml2/tinyxml2Config.cmake` — `[ -f lib/cmake/tinyxml2/tinyxml2Config.cmake ]`; record the exact filename, as tinyxml2 has used both `tinyxml2Config.cmake` and `tinyxml2-config.cmake` across releases.
- **The check that settles the recipe:** no `bin/xmltest` and no `bin/tinystr`, and no test binary anywhere under `$OUT`. Their presence means one of the two `-D` switches had the wrong name and was silently ignored — that is the failure to look for here, not a missing artifact.
- `bin/` may still contain `cmake/` scripts; no other content is expected.