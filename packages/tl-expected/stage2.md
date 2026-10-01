ACCEPT

# tl-expected review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, tl::expected 1.3.1 (git tag
archive `v1.3.1.tar.gz`). Tarball verified with `tar tf` (32 entries, top dir
`expected-1.3.1/`), extracted to `/home/si/.revE/src2/expected-1.3.1`.

## 1. Is it using the SYSTEM?

Yes. `$CMAKE_FLAGS` only. No hardcoded triplet/API/march, no `export` of search
flags, no `DESTDIR`, no `sed`/patch,
`cmake --build build --parallel 1` explicit.

## 2. Is it doing what the package needs?

**Header-only, as claimed.** `CMakeLists.txt:28` is
`add_library(expected INTERFACE)` and `:35` adds the `tl::expected` ALIAS.
Nothing is compiled, so no compiler-version or API-level risk.

**Both switches exist and both are needed.** Verified in `CMakeLists.txt`:

```
18: option(EXPECTED_BUILD_PACKAGE "Build package files as well" ON)
20: cmake_dependent_option(EXPECTED_BUILD_TESTS ...)
```

**`EXPECTED_BUILD_TESTS=OFF` is load-bearing, and the mechanism is worse than
"just builds tests".** `CMakeLists.txt:66-73` (inside the tests block) does:

```
FetchContent_Declare(Catch2 URL
  https://github.com/catchorg/Catch2/archive/v2.13.10.zip)
FetchContent_MakeAvailable(Catch2)
```

That is a **network fetch at configure time**, which AGENTS.md forbids outright
("no network access at build time except `curl` in `source.lua` fetch
blocks"). Note also that `include(CTest)` at `:12` turns `BUILD_TESTING` on by
default, and `cmake_dependent_option` at `:20-22` makes
`EXPECTED_BUILD_TESTS` default ON whenever `BUILD_TESTING` is on — so **both**
of the recipe's `-D` switches are needed: `-DBUILD_TESTING=OFF` stops CTest
enabling the option, and `-DEXPECTED_BUILD_TESTS=OFF` stops it regardless.
Both are correct.

**`EXPECTED_BUILD_PACKAGE=OFF` is also load-bearing.** `CMakeLists.txt:97-116`
pulls in CPack with DEB and RPM binary generators. Those are host-side
packaging steps, and the recipe notes the build returns at `:87-89` before
CPack is included, so with it off none of that runs.

**No host program is compiled and none is executed**, and no target binary is
ever run. No API gates apply — a header-only C++ library.

## Version and provenance

`v1.3.1` is the current release of TartanLlama/expected (the project is
"expected"; there is no separate `tl-expected` repository, as `source.lua`
notes). The `tl-expected` directory name is the right call — it matches
`topackage.md`'s spelling so the `require()` token agrees, and it avoids
colliding with a generic "expected" package name.

One note for the next update: 1.3.x is the current line, but this project's
canonical modern home is `github.com/xtensor-stack/expected` (moved from
TartanLlama). The TartanLlama URL still resolves — I fetched from it — so this
is not a defect, but the migration is worth doing at the next version bump.

## Artifacts — what actually installs

Header-only INTERFACE target:

- `include/tl/expected.hpp` (and any sibling headers in `include/tl/`)
- cmake package config under `lib/cmake/tl-expected/` or
  `include/tl-expected/` — governed by `EXPECTED_BUILD_PACKAGE`; with it OFF,
  **the cmake package config is not installed**, so consumers use the headers
  directly or via `add_subdirectory`. Worth the builder knowing.
- **No library file** — no `libexpected.a`, no `.so`. A check for one would be
  a false failure.

## Forecast

I agree with **6 of 6**. All six rows are WILL BUILD, correctly: a header-only
INTERFACE library with its two build-time escape hatches (network FetchContent
and CPack) both switched off, nothing compiled, no API gate.

## Carried to the build

```sh
# 1. artifacts. NOTE: no library file exists — INTERFACE target only.
#    Checking for libexpected.a would be a false failure.
test -f "$OUT/include/tl/expected.hpp" || echo "MISSING tl/expected.hpp"
find "$OUT/lib" -name 'libexpected.*' | wc -l    # expected 0

# 2. THE NETWORK-FETCH CHECK, and it is the one that matters. Catch2 must not
#    have been fetched, and there must be no _deps/ in the build tree.
test -d "$WORK/build/_deps" && echo "REGRESSION: FetchContent ran (network fetch at configure time)"
grep -rci 'catch2' "$WORK/build/CMakeCache.txt"   # expected 0
find "$WORK/build" -iname '*catch*' | head        # expected: no output

# 3. CPack must not have been included (EXPECTED_BUILD_PACKAGE=OFF)
find "$WORK/build" -name 'CPackConfig.cmake' -o -name 'CPack*.cmake' | head
echo "(no output above = no CPack)"

# 4. all three switches, read from the cache rather than assumed
grep -E '^(BUILD_TESTING|EXPECTED_BUILD_TESTS|EXPECTED_BUILD_PACKAGE):' \
     "$WORK/build/CMakeCache.txt"
# expected: BUILD_TESTING=OFF, EXPECTED_BUILD_TESTS=OFF, EXPECTED_BUILD_PACKAGE=OFF

# 5. no $OUT left in any installed artifact — the loader rewrite ran
#    (src/loader.lua:455-460 sweeps lib/pkgconfig and lib/cmake)
grep -rl "$OUT" "$OUT"/lib/pkgconfig/*.pc "$OUT"/lib/cmake/*/*.cmake 2>/dev/null
echo "(no output above = clean)"

# 6. a consumer must be able to include the header from the install prefix
printf '#include <tl/expected.hpp>\nint main(){return 0;}\n' > /tmp/consumer.cpp
"$CXX" -std=c++17 -I"$OUT/include" -fsyntax-only /tmp/consumer.cpp \
  && echo "OK: header is self-contained from the install prefix"
```