# Catch2

Catch2 is a C++ test framework: `TEST_CASE`, `REQUIRE`, `SECTION` and a
runner that reports failures with values and source locations. Version 3
is a redesign of the v2 API into a compiled library plus a thin header
layer, which is why this is a real build rather than a header drop-in.

```cpp
#include <catch2/catch_test_macros.hpp>

TEST_CASE("vectors grow", "[vec]") {
    std::vector<int> v;
    REQUIRE(v.empty());

    SECTION("one element") {
        v.push_back(1);
        REQUIRE(v.size() == 1);
    }
}
```

Sections re-run the whole test case once per leaf, so each branch sees fresh
state — the reason Catch2 tests are readable. Link one of two libraries:
`Catch2::Catch2WithMain` if you want its `main`, or `Catch2::Catch2` plus
your own.

## What retrolunar builds

Two static libraries: `libCatch2.a` (the framework) and `libCatch2Main.a`
(its `main`), the `catch2/` headers, and a CMake package config. Docs and
extras are off.

Catch2 does **not** install a pkg-config file, so CMake consumers use
`find_package(Catch2)` and `include(Catch)`, and everyone else links
`libCatch2Main.a libCatch2.a` manually.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and Catch2's own
  switches for what to skip. Catch2 also needs `CATCH_INSTALL_DOCS=OFF` to
  keep its (very large) documentation out of the prefix.
- The reporter output includes ANSI colour and a configurable console
  width; `catch_discover_tests` works only when the test binary can run,
  which a target binary on a build machine cannot, so CMake integration here
  is limited to `add_executable` + `catch_discover_tests` being unused.
- Because the libraries are static and built with `-fPIC`, they link into
  shared objects too.
