ACCEPT

# tomlplusplus 3.4.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **The comment names the exact artifact set** — `toml.hpp`, `toml_forward.hpp`
  and `toml.h` — rather than saying "the headers". That is the useful detail,
  because those three files are installed by three separate rules in
  tomlplusplus's CMake and a single-path check would miss two of them. It also
  makes clear that `toml.h` is the C interface, which is easy to overlook in a
  C++-first library and matters for any C consumer.
- `-DTOMLPLUSPLUS_BUILD_TESTS=OFF` is a real option and the comment gives the
  reason in the rule's own terms: the tests are a **host C++ suite**, the
  category AGENTS.md says a cross build must not compile.
- Header-only, so nothing is compiled, the installed tree is identical on every
  system, and **there is no architecture to check**. The honest build record
  says so rather than treating the absence of an `llvm-objdump` step as a gap —
  this is the same reasoning `packages/toml11` applies, and both packages get it
  right.
- No flag is hardcoded to a target, nothing is `export`ed, no `sed`, no patch,
  no `/dev/null`, and the build body stays inside AGENTS.md's allowed command
  list. `cmake --build build --parallel 1` is serial even though there is
  nothing to build, which keeps the recipe uniform with every other one.
- Install goes to `$OUT` via the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("tomlplusplus@source")` names no missing package; tomlplusplus has
  no dependencies.

## The one thing worth knowing for a consumer

tomlplusplus 3.x requires **C++17** from consumers. Nothing is compiled here, so
the install is unaffected, but the constraint lands on whoever imports the
header. The NDK wrappers default to `gnu++17` and mingw's g++ to `gnu++20`, so
both are satisfied — worth one line in `stage1.md` only because the C++ floor is
the sort of thing a future consumer discovers rather than the builder.

Note also that this recipe differs from `packages/toml11`'s in one visible way:
toml11 passes no install option, because it defaults on, whereas tomlplusplus's
`TOMLPLUSPLUS_INSTALL` also defaults on for a top-level build. Neither states
that explicitly. That is a consistency nicety between two sibling recipes rather
than a defect in either — and given AGENTS.md's "do not depend on a default"
spirit, naming it in both would be the better habit.

## Carried to the build

- `include/tomlplusplus/toml.hpp` — `[ -f include/tomlplusplus/toml.hpp ]`.
- `include/tomlplusplus/toml_forward.hpp` — `[ -f include/tomlplusplus/toml_forward.hpp ]`. **A separate install rule**; its absence is exactly the failure a `toml.hpp`-only check would miss.
- `include/tomlplusplus/toml.h` — `[ -f include/tomlplusplus/toml.h ]`. The C interface, third separate rule, and the one most likely to be assumed absent.
- `lib/cmake/tomlplusplus/tomlplusplusConfig.cmake` (and `tomlplusplusConfigVersion.cmake`) — `[ -f lib/cmake/tomlplusplus/tomlplusplusConfig.cmake ]`. Note the config may live under `share/` depending on the release; record the real path. `lib/cmake/*/*.cmake` *is* inside the loader's `$OUT`→`$PREFIX` rewrite set.
- No library and no `.pc` — both absences are correct for a header-only package.
- No test binary anywhere under `$OUT`; its presence means `-DTOMLPLUSPLUS_BUILD_TESTS=OFF` did not take.
- **No architecture check is possible or needed** — say so explicitly in the build record rather than searching for a binary that will never exist.