# doctest build forecast

- Recipe: `generic.lua`, source `source.lua` (GitHub tag archive)
- Version pinned: 2.4.11
- Build system: cmake — but **nothing is compiled**
- Installs: `include/doctest/doctest.h` (the whole product); `lib/cmake/doctest/doctestConfig.cmake`; **no library, no `.pc`**
- Requires: `doctest@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD (trivially) | Header-only. The install is a file copy plus a generated CMake config; `DOCTEST_WITH_TESTS=OFF` (`generic.lua:9`) keeps the example programs out. Nothing is compiled, so no libc symbol, no API level and no architecture enters into it. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above. |
| clang-native | WILL BUILD | Native; topackage.md:227 records doctest 2.4.11 as `[x]`, "header-only: include/doctest/doctest.h plus a CMake package config. Nothing compiled, so it is identical on every system". |

## API level notes

**No architecture check applies.** For a header-only package the install is
byte-identical on all six systems: one header and one CMake config. The API
level is irrelevant because nothing is compiled. This is stated in
topackage.md:227 and is worth restating here so a reviewer does not go
looking for a Bionic gap that cannot exist.

There is one nuance a *consumer* should know: doctest's header does use
`std::` facilities and, in a few configurations, `<cstdio>`/`assert`. Those
are resolved by the *consumer's* compiler, not this build. A consumer
targeting API 21 links doctest's assertions into its own C++ code and
inherits its own toolchain's floor.

## Risks / what a reviewer should check

- **`-DDOCTEST_WITH_MAIN_IN_STATIC_LIB=ON`** (`generic.lua:9`) is a slightly
  odd combination with a header-only library — there is no static library
  here to put `main` in. It is harmless (the option just configures
  `DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN` behaviour for consumers) but it
  suggests the flag was carried over from the compiled-library version of
  doctest. Not a bug; worth a reviewer's eye if they care about the CMake
  config's contents.
- **The GitHub tag archive** (`source.lua:5`) is the right choice for a
  header-only project: there is no generated `configure` to lose.
- **The `lib/cmake/doctest/` config is subject to the same `$OUT`→`$PREFIX`
  rewrite risk as cJSON's** (see `packages/cjson/stage1.md`). The loader
  rewrites `$OUT` to `$PREFIX` in staged `.pc` and `cmake` files, and
  `doctestConfig.cmake` records `PACKAGE_PREFIX_DIR`. If the loader's globs
  ever change, the symptom is a consumer's `find_package(doctest)` failing,
  not this package's build.

## How to verify once built

- `include/doctest/doctest.h` — the entire artifact
- `lib/cmake/doctest/doctestConfig.cmake`
- `wc -c include/doctest/doctest.h` → roughly 700 KB; if it is small, the
  copy went wrong
- **All six systems should produce an identical `doctest.h`** (compare
  checksums across two nest dirs). That is the strongest verification
  available for a package with nothing to compile.
