ACCEPT

# plog 1.1.11 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

## Question 1 — is it using the SYSTEM?

Yes. The whole build body is `cmake -S . -B build $CMAKE_FLAGS ...` plus
`cmake --build build --parallel 1` and `cmake --install build`. There is no
hardcoded target fact, no `export`, no `CPPFLAGS`/`LDFLAGS`/`PKG_CONFIG_*`
override, and no per-target recipe. The install target comes from
`-DCMAKE_INSTALL_PREFIX=$OUT` inside `$CMAKE_FLAGS` and the search path from
`-DCMAKE_PREFIX_PATH=$PREFIX`. `require("plog@source")` resolves
(`packages/plog/source.lua` exists). Correct.

## Question 2 — is it doing what plog needs?

Every citation in the recipe and in `stage1.md` was opened in the unpacked
tree (`SergiusTheBest/plog` tag 1.1.11, top dir `plog-1.1.11`, stripped):

| claim | file:line | verdict |
|---|---|---|
| plog target is `INTERFACE` | `CMakeLists.txt:24` `add_library(${PROJECT_NAME} INTERFACE)` | confirmed |
| `PLOG_BUILD_SAMPLES` defaults ON at top level | `:17` `option(... ${IS_TOPLEVEL_PROJECT})` | confirmed |
| `PLOG_BUILD_TESTS` defaults OFF | `:19` `option(PLOG_BUILD_TESTS "Build tests" OFF)` | confirmed |
| `if(ANDROID)` INTERFACE-link block | `:33-35` | confirmed, and see below |
| `cmake_minimum_required` 3.27 / 3.0 split | `:1-5` | confirmed |
| installs `include/plog/` | `:64-67` | confirmed |
| installs cmake package config | `:58-62`, `:82-85` | confirmed |
| installs `README.md` + `LICENSE` | `:69-74` | confirmed |
| no `.pc` anywhere | `find` for `*.pc*` → nothing | confirmed |

Version 1.1.11 is the newest tag on the canonical repo, and the adder's note
that the brief's `SergeyLutskan/plog` is the wrong owner is right —
`SergiusTheBest/plog` is where the 1.1.x tags live. The source URL resolves
and the tree lands in `$OUT/plog/`. No host program can be built: with
`PLOG_BUILD_SAMPLES=OFF` the `add_subdirectory(samples)` at `:44` is not
reached, and with `PLOG_BUILD_TESTS=OFF` the `add_subdirectory(test)` at
`:49` is not reached. The three targets/paths it installs are portable, so
there is no wrong-architecture risk.

### The `if(ANDROID)` question, answered

`CMakeLists.txt:33-35` is

```cmake
if(ANDROID)
    target_link_libraries(${PROJECT_NAME} INTERFACE log)
endif()
```

The adder's position — that this is metadata-only and no `android.lua` is
needed — is **correct**, and the reasoning is stronger than it was stated.
Two independent reasons:

1. The line cannot fire here. cmake derives `ANDROID` from
   `CMAKE_SYSTEM_NAME`, and every one of our toolchain files deliberately
   sets it to `Linux` (that is the whole point of the flag: it keeps cmake
   out of its own NDK integration). So `ANDROID` is unset and `:34` is
   dead code in every build this tree produces. This is the same fact as
   glog's, and the same fix would apply — `-DANDROID=ON` in an
   `android.lua` — if it were ever needed.
2. Even if it *did* fire, the only thing it could change is the
   `INTERFACE_LINK_LIBRARIES` entry in the exported
   `lib/cmake/plog/plogConfig.cmake`. There is no archive whose bytes could
   differ, because an `INTERFACE` library compiles nothing. glog's
   justification (build twice, `cmp` the archives) is not even available
   here, because there is no archive to compare. So the glog-style
   "byte-identical" proof is not needed and cannot be performed.

A consumer on Android that does want `-llog` gets it from the Android
system's own `LDFLAGS` (every Android system file already carries `-llog`,
`packages/aarch64-android24/generic.lua:86`), which is the correct place
for that fact. Nothing about plog should reach into that.

**What ships in a `.pc` for plog: nothing — there is no `.pc`.** The stage1
instruction to record that absence is the right instruction and the builder
should keep it: `find $PREFIX -name '*.pc' -newer …` scoped to plog will
find nothing, and that is correct, not a gap.

## The forecast

`stage1.md` claims WILL BUILD on all six systems with a cited reason per
row, and the "Nothing is compiled" statement is the reason. That is the
kind of claim the review gate exists to check, and here it holds: the only
targets in the project are `INTERFACE`, and the only two `add_subdirectory`
calls are behind options the recipe pins OFF. The x86_64-mingw row's
"INTERFACE + GENERATED export sets are portable" is also sound — a generated
export set contains no compiler-detected content when nothing is compiled.

The forecast is unusually well-evidenced (real line numbers, a positive
negative-result instruction, and a risk the author flagged *against* their
own convenience — the missing `android.lua`). No UNCERTAIN is warranted.

## Carried to the build

- `include/plog/Log.h` exists, with `Init.h`, `Appender.h`, `Formatters.h`
  alongside. `stage1.md:58` names these four.
- `lib/cmake/plog/plogConfig.cmake` and `plogConfigVersion.cmake` exist
  (`CMakeLists.txt:58-62`, `:82-85`).
- `find $OUT -name '*.a' -o -name '*.so'` returns nothing. This is the check
  that proves nothing was compiled; it is scoped to `$OUT` (this package's
  own stage dir), not to `$PREFIX`, so it cannot pass vacuously.
- `find $OUT -name '*.pc'` returns nothing. Expected, not a gap.
- `grep -c log $OUT/lib/cmake/plog/plogConfig.cmake` returns 0. This is
  `stage1.md`'s risk 1 check and it is load-bearing: it is the positive
  proof that `CMakeLists.txt:33-35` did not fire. State the expected value
  (0) in `stage3.md` so a reader can compare rather than infer.
