REJECT

# range-v3 0.12.0 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

The upstream identity, version, tag and install layout are all correct and
verified. The rejection is about what the build actually does: the recipe
passes **no options at all**, and range-v3's options default to **ON** for a
standalone build, so it compiles and links several hundred executables on
every one of the six systems.

## Required changes

1. **Pass the switches that turn the test, example and doc trees off**
   (`packages/range-v3/generic.lua:20`):

   ```diff
   -        cmake -S . -B build $CMAKE_FLAGS
   +        cmake -S . -B build $CMAKE_FLAGS -DRANGE_V3_TESTS=OFF -DRANGE_V3_EXAMPLES=OFF -DRANGE_V3_DOCS=OFF -DRANGE_V3_PERF=OFF
   ```

   The three `CMAKE_DEPENDENT_OPTION`s default ON when `is_standalone`, which
   is true here. `RANGE_V3_PERF` is already OFF but passing it makes the
   intent visible and costs nothing.

2. **Correct the false statements** in `packages/range-v3/generic.lua:11-14`
   ("range-v3 has no options at all - no tests, no examples, no benchmarks
   to switch off") and in `packages/range-v3/stage1.md:24`
   ("range-v3 has **no options at all** … `cmake --build` is a no-op") and
   `stage1.md:31` ("**Nothing is compiled**").

3. **Add the two build-behaviour switches below** if the first fix alone is
   not adopted — see "Two more things that are ON by default".

## The specific thing that would break it

`cmake/ranges_options.cmake` — the file the recipe never looks at — defines
eighteen options, and this is the bottom of it:

```cmake
CMAKE_DEPENDENT_OPTION(RANGE_V3_TESTS
  "Build the Range-v3 tests and integrate with ctest"
  ON "${is_standalone}" OFF)

CMAKE_DEPENDENT_OPTION(RANGE_V3_EXAMPLES
  "Build the Range-v3 examples and integrate with ctest"
  ON "${is_standalone}" OFF)

CMAKE_DEPENDENT_OPTION(RANGE_V3_DOCS
  "Build the Range-v3 documentation"
  ON "${is_standalone}" OFF)
```

and `is_standalone` is YES for a top-level build
(`CMakeLists.txt:9-17`: `get_directory_property(is_subproject PARENT_DIRECTORY)`
is empty at top level, so `set(is_standalone YES)`).

Those three feed straight into the top-level `CMakeLists.txt`:

```cmake
56: if(RANGE_V3_DOCS)
57:   add_subdirectory(doc)
59: if(RANGE_V3_TESTS)
60:   include(CTest)
61:   add_subdirectory(test)
63: if(RANGE_V3_EXAMPLES)
65:   add_subdirectory(example)
```

So the recipe as written pulls in `test/`, `example/` and `doc/`.

**How much that is.** `test/CMakeLists.txt` declares `rv3_add_test` **241
times** across its subdirectories (`test/algorithm` 115, `test/view` 66,
`test/action` 22, `test/utility` 10, `test/iterator` 7, `test/range` 4,
`test/numeric` 5, `test/functional` 2, plus the top-level file), and each
one is an `add_executable` (`CMakeLists.txt:50-54`):

```cmake
function(rv3_add_test TESTNAME EXENAME FIRSTSOURCE)
  add_executable(range.v3.${EXENAME} ${FIRSTSOURCE} ${ARGN})
  target_link_libraries(range.v3.${EXENAME} range-v3)
  add_test(range.v3.${TESTNAME} range.v3.${EXENAME})
endfunction()
```

`example/` adds 13 more via the same function. So the recipe builds
**roughly 254 target executables** where it intends to build none — on
`aarch64-android21`, `aarch64-android24`, `aarch64-android35`,
`x86_64-android35`, `x86_64-mingw` and `clang-native` alike.

`stage1.md:24` states the opposite: *"range-v3 has **no options at all**: no
tests, no examples, no benchmarks to switch off, so there is nothing to
disable and nothing that could build a host program. `cmake --build` is a
no-op."* and `stage1.md:31`: *"**Nothing is compiled** … the install is a
file copy, identical on every system."* Those statements are what made a
uniform WILL BUILD look safe, and they are false. `stage1.md` cites
`CMakeLists.txt:27`, `:34`, `:42` and `:186` — all of which are real and
all of which are correct — and those citations are exactly why the mistake
was made: the top-level `add_subdirectory` calls are at `:57`, `:61`, `:65`,
just past the end of everything the adder read.

`generic.lua:11-14` repeats the error as a standing comment, so it would
mislead the next reader even after the flags are fixed.

## Two more things that are ON by default

Both are in `cmake/ranges_options.cmake` and both are worth passing
explicitly, for the same reason as the three above.

**`RANGES_ENABLE_WERROR` — `ON` by default.** From
`cmake/ranges_flags.cmake`:

```cmake
ranges_append_flag(RANGES_HAS_WALL -Wall)
ranges_append_flag(RANGES_HAS_WEXTRA -Wextra)
if (RANGES_ENABLE_WERROR)
  ranges_append_flag(RANGES_HAS_WERROR -Werror)
endif()
```

I confirmed the NDK compiler accepts `-Werror` (`aarch64-linux-android21-clang
-Werror -c t.c` exits 0), so the flag is really applied. `-Werror` is
global (`add_compile_options`), so it applies to those 254 test/example
translation units as well as to the library headers. Combined with
`RANGES_ASSERTIONS` (ON) and `RANGES_DEBUG_INFO` (ON), this is the
difference between a build that works and one that stops on the first
warning from a 2019-era test corpus on a modern clang. I am not claiming it
*will* fail; I am saying the forecast gives no basis for ruling it out, and
the recipe has no switch to turn it off if it does.

**`RANGES_NATIVE` — `ON` by default.** Also in `ranges_flags.cmake`:

```cmake
if (RANGES_NATIVE)
  ranges_append_flag(RANGES_HAS_MARCH_NATIVE "-march=native")
  ranges_append_flag(RANGES_HAS_MTUNE_NATIVE "-mtune=native")
endif()
```

This one *is* self-guarding, and I checked rather than assumed: the NDK
compiler rejects `-march=native` outright —

```
$ aarch64-linux-android21-clang -O2 -march=native -c t.c -o /dev/null
clang: error: unsupported argument 'native' to option '-march='
$ echo $?
1
```

— so `check_cxx_compiler_flag` behind `ranges_append_flag` sets
`RANGES_HAS_MARCH_NATIVE` false and the flag is never added. **It is not a
defect**, and I am recording that so the next reviewer does not spend time
on it. It is still worth passing `-DRANGES_NATIVE=OFF` explicitly, because
relying on a compiler-rejection probe to protect a cross build is exactly
the kind of luck AGENTS.md warns about elsewhere.

`RANGES_BUILD_CALENDAR_EXAMPLE` (ON) is harmless here: `example/` wraps it
in `find_package(Boost 1.59.0 …)` and only adds the target `if (Boost_FOUND)`
(`example/CMakeLists.txt:25-45`), so with no Boost in `$PREFIX` it is simply
skipped. Worth knowing so nobody adds `-DRANGES_BUILD_CALENDAR_EXAMPLE=OFF`
chasing a Boost error that cannot happen.

`RANGE_V3_DOCS` is worth turning off for a second reason: `doc/CMakeLists.txt`
`return`s early if Doxygen is not found, and Doxygen is not in this prefix,
so it is already inert. Passing `=OFF` states the intent rather than relying
on that.

## Question 1 — is it using the SYSTEM?

Yes, and this is the one part of the recipe that is beyond reproach:
`cmake -S . -B build $CMAKE_FLAGS`, `cmake --build build --parallel 1`,
`cmake --install build`. No hardcoded target fact, no `export` of search
flags, no per-target recipe. `require("range-v3@source")` resolves and the
tree lands in `$OUT/range-v3/`. Correct.

Note that `--parallel 1` is the load-bearing half here in a way it is not for
`make`: without it cmake's default generator would fan out, and with 254
executables in the default target that fan-out would be severe. It is
written, so this is right — but only because the fix above is adopted; the
serial flag is what makes the *intended* build safe, and it does nothing for
the build as currently written beyond making the wrong one slower.

## Question 2 — the rest of the package

**Upstream identity — verified.** `github.com/ericniebler/range-v3` is the
canonical repository and the `range-v3/range-v3` org path does not exist.
The tag list from GitHub's API, newest first, is:

```
fork_point, fork_base, 0.12.0, 0.11.0, 0.10.0, 0.9.1, 0.9.0, 0.5.0, 0.4.0, 0.3.7
```

So the brief's "fork" note is half right, exactly as `stage1.md:17-20` says:
`fork_point` and `fork_base` sit above the newest release and are merge
markers, and **0.12.0 is the newest release tag**. Pinning it is current and
correct. The source URL resolves.

**Install layout — verified, and the trap is handled correctly.**
`CMakeLists.txt:186` is

```cmake
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR} FILES_MATCHING PATTERN "*")
```

— the entire include tree, which is what makes the recipe correct given that
public headers are split across `range/`, `concepts/`, `meta/` and `std/`
and reference each other. Running upstream's install rather than copying by
hand is the right call and the stated reason is right.

**Three `INTERFACE` targets — confirmed** at `:27` (`range-v3-meta`), `:34`
(`range-v3-concepts`) and `:42` (`range-v3`), with aliases
`range-v3::meta`, `range-v3::concepts`, `range-v3::range-v3`, exported at
`:180` under `NAMESPACE range-v3::`. The exported `range-v3::…` hyphenated
names and the three-target structure are both correctly recorded in
`stage1.md` risks 2 and 3 — those notes are right and worth keeping.

**No pkg-config file — confirmed.** `find . -name '*.pc*'` over the whole
tree returns nothing. So does upstream's own `install(EXPORT … FILE
range-v3-config.cmake)` at `:181` plus the `install(FILES …)` at `:182-185`
for `range-v3-config.cmake` and `range-v3-config-version.cmake`. So the
install is: whole `include/` tree, plus a CMake package config under
`lib/cmake/range-v3/`. No library file, no `.pc`. `stage1.md`'s instruction
to record the `.pc` absence as expected rather than as a gap is right.

**`cmake_minimum_required(VERSION 3.6)`** at `:8` — old, but every system's
`$CMAKE_FLAGS` carries `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, so cmake 4.x
accepts it. No action needed.

**One more CMake behaviour worth recording.** `CMakeLists.txt:116-125` and
`:144-147` contain logic that *writes a git tag*:

```cmake
144:    COMMAND ${GIT_EXECUTABLE} -C "${CMAKE_CURRENT_SOURCE_DIR}" commit -m "${RANGE_V3_VERSION}"
147:    COMMAND ${GIT_EXECUTABLE} -C "${CMAKE_CURRENT_SOURCE_DIR}" tag -f -a "${RANGE_V3_VERSION}" -m "${RANGE_V3_VERSION}"
```

`find_package(Git)` is called unconditionally at the bottom of
`cmake/ranges_env.cmake`. I checked what guards it: `:120-125` compares
`${CMAKE_CURRENT_BINARY_DIR}/include/range/v3/version.hpp` (a configure-time
copy) against the source one and only proceeds if they differ, and the
target this belongs to is not in `all`. So it is not reached by
`cmake --build` on a fresh tree, and AGENTS.md's "no git commands in
recipes" rule is not violated by the recipe. It is worth recording because it
is exactly the sort of thing that becomes a real `git commit` in a recipe if
a future change causes a reconfigure with a dirty source tree.

## The forecast

Six WILL BUILD rows, all resting on "nothing is compiled" and "no options at
all". Both halves are false, and they are false in the way that matters:
the recipe compiles and links ~254 executables per system. The per-row
reasons are all "As above", so no row carries independent evidence.

**`x86_64-mingw` specifically:** 254 mingw executables is the *best*-case
scenario for this mistake — the mingw-w64 g++ in this tree can build them.
`clang-native` is the same. The rows that would hurt are the four Android
ones, where 254 `aarch64-linux-androidNN-clang` links run under
`-Werror` with `RANGES_ENABLE_WERROR` on.

The "API level notes: None" reasoning is sound in isolation — range-v3 is
pure C++ standard library and its headers need no libc symbol (the recipe
correctly notes `type_traits`, `tuple`, `utility` and friends are
header-only in both libc++ and libstdc++). But the conclusion drawn from it
— "no step observes an API level", therefore the package cannot be affected —
is only valid for a build that compiles nothing, which is not this one.

## Carried to the build

- `include/range/v3/all.hpp` exists — **and so do** `include/concepts/`,
  `include/meta/` and `include/std/`. Checking only `range/` is the mistake
  the layout trap invites; the other three directories' presence is the
  check that the recursive install at `:186` ran. Scoped to paths range-v3
  owns, so it cannot pass vacuously.
- `include/module.modulemap` exists (installed by the same
  `install(DIRECTORY … FILES_MATCHING PATTERN "*")`).
- `lib/cmake/range-v3/range-v3-config.cmake` and `range-v3-targets.cmake`
  exist (`:181`, `:182-185`).
- **No library file:** `find $OUT -name '*.a' -o -name '*.so'` returns
  nothing. Scoped to `$OUT`.
- **No pkg-config file either:** `find $OUT -name '*.pc'` returns nothing.
  Expected, not a gap.
- **`ls $OUT/bin/` must be empty**, and — the check that would have caught
  this — the build log must contain no `range.v3.*` link lines. The
  executables are not installed, so `$OUT` looks correct either way; the
  only place the defect is visible is the build log and the build time.
  After the fix, `cmake --build` should report no compilation at all.
- A `find_package(range-v3)` consumer must be able to link
  `range-v3::range-v3`; that is the one functional check worth doing.
- Compare two systems' `include/` with `diff -r`: any difference is a bug.
