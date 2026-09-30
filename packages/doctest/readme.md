# doctest

doctest is a header-only C++ test framework in the Catch2 family, but
lighter: it is one header, it compiles an order of magnitude faster than
Catch2, and it keeps the familiar `TEST_CASE`/`SUBCASE`/`REQUIRE` vocabulary.

```cpp
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

TEST_SUITE("vector") {
    TEST_CASE("grows") {
        std::vector<int> v;
        CHECK(v.empty());
        SUBCASE("one push_back") {
            v.push_back(1);
            CHECK(v.size() == 1);
        }
    }
}
```

`REQUIRE` aborts the current test case on failure; `CHECK` continues, so
one test can report several failures. `SUBCASE` blocks re-run the enclosing
case once per leaf, each from a fresh entry point, which is how doctest keeps
state from leaking between branches.

`doctest::Approx` handles floating point comparisons without hard-coding a
tolerance, and the `doctest_config.h` header is where compile-time options
live — most usefully `DOCTEST_CONFIG_TREAT_CHAR_STAR_AS_STRING` and the
`-m`/`-d` runtime flags, which are on the test binary, not on the library.

## What retrolunar builds

Nothing is compiled. The install copies `doctest/doctest.h` and
`doctest/parts/doctest_fwd.h` into `include/doctest/`, and installs a CMake
package config under `lib/cmake/doctest/`. The examples and the test suite
itself stay off.

CMake consumers use `find_package(doctest)` and link `doctest::doctest`;
everyone else adds `$PREFIX/include`, defines
`DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN` in exactly one translation unit, and
links nothing.

## Notes

- CMake build, but only its install rules do work here: the framework is
  header-only, so the recipe passes `$CMAKE_FLAGS` and the option that keeps
  the framework's own test suite out of the build.
- Header-only means zero link cost, which is doctest's whole argument
  against Catch2 — at the price of compile time per test binary.
- doctest reports to stdout with its own reporter; the JUnit reporter
  (`--reporters=junit`) is built in, so CI integration needs no extra
  dependency.
