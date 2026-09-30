ACCEPT

# yaml-cpp 0.8.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- All four switches are real yaml-cpp CMake options and all four are the right
  cuts:
  - `-DYAML_CPP_BUILD_TESTS=OFF` — the gtest suite, a **host program**;
  - `-DYAML_CPP_BUILD_TOOLS=OFF` — `yaml-cpp`/`read-cpp`, host CLIs;
  - `-DYAML_CPP_BUILD_UTILS=OFF` — `tests`/`nodeop`/`nodeop_benchmark`/
    `yaml-benchmark`, host programs;
  - `-DYAML_BUILD_SHARED_LIBS=OFF` — the static control, and the *correct
    spelling*: yaml-cpp's option is `YAML_BUILD_SHARED_LIBS`, not
    `YAML_CPP_BUILD_SHARED_LIBS` and not `BUILD_SHARED_LIBS`. Getting that
    wrong would be silently ignored by cmake and the prefix would get a shared
    `libyaml-cpp.so` with no loader path for it — the same failure as
    `packages/freetype`, which omits its equivalent entirely. This recipe has it
    right.
- `-DYAML_CPP_INSTALL=ON` is explicit about the thing the recipe exists for, and
  yaml-cpp defaults it on only for a top-level build; naming it is the
  "do not depend on a default" discipline.
- The comment at line 7 groups all five values accurately in one sentence —
  artifact set, the ABI toggle, and "Tests, tools and utilities are host
  programs and stay off". That is exactly the level of explanation AGENTS.md
  asks for.
- `cmake --build build --parallel 1` is serial; install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch, no `/dev/null`,
  nothing hardcoded to a target, nothing `export`ed.
- `require("yaml-cpp@source")` names no missing package. yaml-cpp has no
  dependencies, so passing no include or library path is correct.

## One note for the forecast

yaml-cpp 0.8.0 requires **C++11** from consumers, and the NDK wrappers default
to `gnu++17` while mingw's g++ defaults to `gnu++20` — both satisfied, so
nothing to record as a risk. It is worth a line in `stage1.md` only because the
C++ floor is the kind of thing a future consumer hits rather than this build.

## Carried to the build

- `lib/libyaml-cpp.a` — `llvm-objdump -f lib/libyaml-cpp.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). **Also check `ls lib/libyaml-cpp.so*`**: a shared object here means `YAML_BUILD_SHARED_LIBS=OFF` had the wrong name and was ignored.
- `include/yaml-cpp/yaml.h`, `include/yaml-cpp/node/*.h` — `[ -f include/yaml-cpp/yaml.h ]` and `[ -f include/yaml-cpp/node/node.h ]`.
- `lib/pkgconfig/yaml-cpp.pc` — `pkg-config --modversion yaml-cpp` → `0.8.0`. yaml-cpp ships one, inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `lib/cmake/yaml-cpp/yaml-cpp-config.cmake` (or `yaml-cppConfig.cmake`) — `[ -d lib/cmake/yaml-cpp ]`; record the exact filename, since yaml-cpp has changed its config naming between releases.
- **The check that settles the recipe:** no test, tool or benchmark binary anywhere under `$OUT`. `find $OUT -name 'yaml-benchmark' -o -name 'nodeop*' -o -name 'yaml-cpp'` — a `yaml-cpp` binary is the CLI and its presence means `-DYAML_CPP_BUILD_TOOLS=OFF` had the wrong name or the tools are unconditionally built.
- No `bin/` directory should exist at all under the current switches.