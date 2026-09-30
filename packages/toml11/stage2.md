ACCEPT

# toml11 4.4.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **Header-only, and the recipe is honest about the consequence.** The comment
  says the install "copies the headers into `include/toml11` and into
  `include/toml` (the compatibility path) and generates the cmake config". The
  two-directory install is the load-bearing detail: toml11 ships a
  `toml11/` tree and a legacy `toml/` compatibility tree, and a consumer can
  write either `#include <toml11/toml.hpp>` or `#include <toml/toml.hpp>`. Both
  landing is what makes the package usable by either spelling, and a reviewer
  checking only one of them would think the other is missing.
- `-DTOML11_BUILD_TESTS=OFF` is a real option and the comment gives the reason:
  the tests are a **host C++ suite**. That is the category AGENTS.md says a
  cross build must not compile.
- Nothing is compiled, so the installed tree is identical on every system and
  **there is no architecture to check** — the honest build record should say so
  rather than treat the absence of an `llvm-objdump` step as a gap.
- No flag is hardcoded to a target, nothing is `export`ed, no `sed`, no patch,
  no `/dev/null`. Install goes to `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`, and `cmake --build build --parallel 1` is
  serial even though there is nothing to build.
- `require("toml11@source")` names no missing package; toml11 has no
  dependencies.

## One observation about the C++ dialect

toml11 4.x requires C++17 from *consumers*. Nothing is compiled here, so the
install is unaffected — but the constraint lands on whoever imports the header
next. The NDK wrappers default to `gnu++17` and mingw's g++ to `gnu++20`, so
both are satisfied. If `stage1.md` does not say this, a future consumer on a
C++11-only toolchain would discover it the hard way. A forecast nicety, not a
recipe defect.

## Carried to the build

- `include/toml11/toml.hpp`, `include/toml11/fwd.hpp` — `[ -f include/toml11/toml.hpp ]`.
- `include/toml/toml.hpp` — `[ -f include/toml/toml.hpp ]`. **This is the check that matters most**: the compatibility tree is a separate install rule, and its absence is exactly the failure a single-path check would miss.
- `lib/cmake/toml11/toml11Config.cmake` (and `toml11ConfigVersion.cmake`) — `[ -f lib/cmake/toml11/toml11Config.cmake ]`. Note the config may live under `share/` or `lib/cmake/` depending on the release; record the real path, and note that `lib/cmake/*/*.cmake` *is* inside the loader's `$OUT`→`$PREFIX` rewrite set.
- No library and no `.pc` — both absences are correct for a header-only package.
- No test binary anywhere under `$OUT`; its presence means `-DTOML11_BUILD_TESTS=OFF` did not take (or that the tests are header-only and were "built" as part of the install, which would show up as an unexpected binary).
- **No architecture check is possible or needed** — say so explicitly in the build record.