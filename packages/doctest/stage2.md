ACCEPT

# doctest 2.4.11 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- Header-only, so nothing is compiled — and the recipe says so rather than
  pretending there is a build. `cmake --build build --parallel 1` is a no-op,
  which is fine and uniform with the other recipes.
- `-DDOCTEST_WITH_TESTS=OFF` is **genuinely load-bearing** and worth calling
  out: it defaults to ON when doctest is the main project, and turning it off
  is what keeps the `examples/` tree — which includes MPI targets and would
  look for an MPI compiler — out of the configure. A recipe that left it at
  the default would be a real defect.
- `cmake_minimum_required(VERSION 3.0)` is covered by the system's
  `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`. Install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `require("doctest@source")` names no missing package.

## One observation, not a reject reason

`-DDOCTEST_WITH_MAIN_IN_STATIC_LIB=ON` is the upstream default and is inert
here — the target it controls is `EXCLUDE_FROM_ALL` and never installed.
Passing it is harmless but adds a line that means nothing, which is how
`stage1.md` came to call it "slightly odd". Either drop it or add half a
sentence saying it is stated for clarity and changes nothing. Low priority.

`stage1.md`'s artifact list is otherwise correct but incomplete: it omits
`include/doctest/extensions/*.h` and the three helper modules in
`lib/cmake/doctest/` (`doctest.cmake`, `doctestAddTests.cmake`,
`doctestTargets.cmake`). All three are installed and the last one is what
`find_package(doctest)` consumers need.

## Carried to the build

- `include/doctest/doctest.h` — `[ -f include/doctest/doctest.h ]`.
- `include/doctest/extensions/*.h` — `[ -f include/doctest/extensions/prime_numbers.h ]`; the extensions subdirectory is a separate install rule and is easy to miss.
- `lib/cmake/doctest/doctestConfig.cmake`, `doctestConfigVersion.cmake` — `[ -f lib/cmake/doctest/doctestConfig.cmake ]`.
- `lib/cmake/doctest/doctest.cmake`, `doctestAddTests.cmake`, `doctestTargets.cmake` — all three present; `doctestTargets.cmake` is the one a `find_package(doctest)` consumer needs.
- No library and no `.pc` — doctest ships none, and both absences are correct.
- **No `examples/` or MPI artifacts** anywhere under `$OUT`; their presence means `-DDOCTEST_WITH_TESTS=OFF` did not take.
- There is no architecture to check, and the builder should say so in the build record rather than treating it as a gap.
