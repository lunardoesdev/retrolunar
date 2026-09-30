# GoogleTest

GoogleTest is the C++ test framework with the widest reach: it is what
`ctest` drives by default, what most C++ projects on the planet use, and
what Google's own build systems assume. It provides assertions, test
discovery for CMake, death tests, and — in gmock, which ships in the same
repository — mock objects and matchers.

```cpp
#include <gtest/gtest.h>

TEST(VectorTest, Grows) {
    std::vector<int> v;
    ASSERT_TRUE(v.empty()) << "a new vector must be empty";
    EXPECT_EQ(v.size(), 0u);
}
```

`EXPECT_*` records a failure and continues; `ASSERT_*` stops the current
test. That split is the framework's core convention: `ASSERT_` for
preconditions whose failure makes the rest meaningless, `EXPECT_` for
independent checks.

gmock is the interesting half for C++ with interfaces: `MOCK_METHOD` plus
`EXPECT_CALL` lets a test state expectations ("this gets called twice, with
these arguments") and verify them, and matchers (`ElementsAre`, `Field`,
custom ones) keep that readable.

```cpp
class Storage {
public:
    MOCK_METHOD(void, Write, (std::string_view), (override));
};

TEST(WriterTest, WritesChunks) {
    Storage s;
    EXPECT_CALL(s, Write).Times(2);
    write_in_chunks(s);
}
```

## What retrolunar builds

Four static archives: `libgtest.a` (the framework), `libgtest_main.a`
(its `main`), `libgmock.a` and `libgmock_main.a`. Plus the `gtest/` and
`gmock/` headers, CMake package configs, and `gtest.pc`/`gmock.pc`. The
frameworks' own test suites are off: host programs.

Do **not** pass `-DINSTALL_GTEST=OFF`: googletest's install rules sit inside
that option's guard, so switching it off installs nothing at all. The
duplicate legacy `lib/` layout it controls is harmless.

## Using it

```sh
pkg-config --cflags --libs gtest_main gmock
```

CMake consumers use `find_package(GTest)` and link
`GTest::gtest_main` (and `GTest::gmock` if they need mocks).
`gtest_discover_tests()` works only where the test binary can actually run,
so it is not usable against a target library on the build machine.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` plus googletest's own
  switches for its internal tests.
- GoogleTest and Catch2 are both in this prefix (doctest too). They are not
  interchangeable: GoogleTest's value is gmock and CMake integration, Catch2's
  is a richer expression language, doctest's is compile speed.
- Death tests need a working `fork` and `waitpid` on the machine that runs
  the test, which is the build machine for a cross test binary.
