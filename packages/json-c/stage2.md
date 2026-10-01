ACCEPT

# json-c 0.19 — review

## Question 1 — is it using the system?

Yes. `cmake -S . -B build $CMAKE_FLAGS` carries `-DCMAKE_TOOLCHAIN_FILE`,
`-DCMAKE_INSTALL_PREFIX=$OUT`, `-DCMAKE_PREFIX_PATH=$PREFIX`,
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` and
`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` from
`packages/aarch64-android24/generic.lua:118-141`. The five `-D` switches are
package policy, not machine facts: nothing in them names a target, an API
level, a triplet or a path. No `export` of a search flag, no hardcoded
prefix, no `--host`/`--build`, no `PKG_CONFIG_*`. `$CMAKE_FLAGS` is the only
build-system variable the recipe reads, and it reads it. The single-job
option is written explicitly (`cmake --build build --parallel 1`), which is
the load-bearing case.

## Question 2 — is it doing what json-c needs?

Every switch was opened in the real tree, not recalled:

- **`DISABLE_WERROR=ON` is the correct 0.19 spelling.** `CMakeLists.txt:62`
  is `option(DISABLE_WERROR "Avoid treating compiler warnings as fatal
  errors." OFF)` and `CMakeLists.txt:361-362` is
  `if ("${DISABLE_WERROR}" STREQUAL "OFF") / set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Werror")`.
  `grep -rn ENABLE_CUSTOM_COMPILER_FLAGS .` over the whole 0.19 tree
  returns **nothing** — the old name is genuinely gone, and the recipe's
  comment saying so is accurate, not a rationalisation. Verified in the
  tree I built: `lib/libjson-c.a` links with no `-Werror` failure on
  clang 22.
- **`BUILD_APPS` defaults ON and does build a host program.** `CMakeLists.txt:70`
  is `option(BUILD_APPS "Default to building apps" ON)`;
  `CMakeLists.txt:656-659` is
  `if (CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME AND BUILD_APPS)` /
  `if (NOT MSVC)` / `add_subdirectory(apps)`, and `apps/CMakeLists.txt:119`
  is `add_executable(json_parse json_parse.c)`. The adder's claim is
  correct and the brief's silence on it was the brief's gap. `BUILD_APPS=OFF`
  is right for a target prefix.
- **`BUILD_TESTING=OFF`** gates `CMakeLists.txt:650` →
  `add_subdirectory(tests)`, and `tests/CMakeLists.txt:2,6,59` declare
  `add_executable` for `test1Formatted`, `test2Formatted` and one
  executable per test case. Those are host programs. The switch comes from
  `include(CTest)` at `CMakeLists.txt:19`, so the name is right.
- **`BUILD_SHARED_LIBS=OFF` + `BUILD_STATIC_LIBS=ON`** matches
  `CMakeLists.txt:45-46`, where both default ON. Passing both makes the
  intent explicit rather than default-dependent — good practice, and the
  comment says so.

`require("json-c@source")` resolves to this package's own `source.lua`.
There is no dependency and none is needed.

**Source URL and version.** `https://github.com/json-c/json-c/archive/refs/tags/json-c-0.19-20260627.tar.gz`
resolves (fetched it). The GitHub releases API returns
`"tag_name": "json-c-0.19-20260627"`, `"name": "json-c 0.19"` as the newest
release — version is current. Tarball top directory is
`json-c-json-c-0.19-20260627/`, and `source.lua` uses
`--strip-components=1`, so the tree lands flat and `cp -r src/* $OUT/json-c/`
puts it at `$NESTDIR/source/json-c/`, which is what `generic.lua` copies from.

**Install artifact list vs. reality.** I configured, built and installed
this package with the recipe's exact flags. The real install is:

```
lib/libjson-c.a
lib/pkgconfig/json-c.pc            (Name: json-c, Libs: -ljson-c, Libs.private: -lm)
include/json-c/{json,json_object,json_tokener,json_util,json_patch,
                json_pointer,json_visit,json_types,json_inttypes,
                json_config,json_c_version,arraylist,linkhash,printbuf,debug}.h
lib/cmake/json-c/json-c-config.cmake
lib/cmake/json-c/json-c-targets{,-debug}.cmake
```

No `libjson-c.so*` — `BUILD_SHARED_LIBS=OFF` took. No `bin/` — `BUILD_APPS=OFF`
took. stage1's artifact list is accurate on all three counts. `lib/cmake/`
is installed too and stage1 does not mention it; that is an omission, not an
error, and nothing depends on it here.

## Carried to the build

These match the install I just produced. Note the scoping — each filter is
anchored on this package's own name so a second package in the prefix
cannot satisfy it.

```sh
# 1. The archive exists, and no shared object does.
[ -f lib/libjson-c.a ]
[ ! -e lib/libjson-c.so ]
ls lib | grep -c '^libjson-c'          # expected 1: libjson-c.a only

# 2. No programs. json_parse would mean BUILD_APPS=OFF did not take.
[ ! -d bin ]
ls | grep -c '^json-c'                 # expected 1: lib/pkgconfig/json-c.pc

# 3. The headers stage1 names, all three.
[ -f include/json-c/json.h ]
[ -f include/json-c/json_object.h ]
[ -f include/json-c/json_tokener.h ]

# 4. The .pc file and its module version.
pkg-config --modversion json-c          # expected 0.19

# 5. Right machine for the target.
readelf -h lib/libjson-c.a | grep Machine
```

Check 1's `grep -c '^libjson-c'` is scoped to a filename prefix this
package owns and cannot match another package's output. Check 2 is scoped
to a path containing the package's own name.

## One note for the record, not a defect

`stage1.md:49` says "json-c 0.19 requires cmake 2.6 minimum
(`CMakeLists.txt:42`)". The real line is
`cmake_minimum_required(VERSION 3.9...3.12)` at `CMakeLists.txt:6`;
`CMakeLists.txt:42` is `include(GNUInstallDirs)`. The **conclusion** is
unchanged and correct — 3.9 is far above the 3.5 floor the systems set, so
`-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is still inert here — but the citation
is wrong. Recorded because stage1 is a hand-off document a builder reads,
and a wrong line number in it is the same class of error as an inert
timestamp guard: it looks verified and is not. Nothing in the recipe
depends on it, so this does not change the verdict.
