ACCEPT

# spdlog 1.15.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **`-DSPDLOG_FMT_EXTERNAL=ON` with `require("fmt")` is the load-bearing
  decision here, and the comment gives the right reason:** "one formatting
  engine in the whole tree." spdlog bundles its own copy of `fmt` by default,
  so without this flag a prefix ends up with two independent implementations of
  `{format}` in the same process — different type identities, different ABI,
  and a header collision between `include/fmt/` and `include/spdlog/fmt/`.
  Pointing spdlog at the prefix's `fmt` is the correct call and `packages/fmt`
  exists to serve it.
- The host-program switches are right and each is a real option:
  `-DSPDLOG_BUILD_EXAMPLE=OFF`, `-DSPDLOG_BUILD_EXAMPLE_HOOK=OFF`,
  `-DSPDLOG_BUILD_TESTS=OFF`, `-DSPDLOG_BUILD_BENCH=OFF`. spdlog's benchmarks
  are an embedded copy of Google Benchmark, so leaving them on would pull a
  second benchmark framework into a cross configure. They are host programs,
  which is the category AGENTS.md forbids.
- `-DSPDLOG_INSTALL=ON` is explicit about the thing the recipe exists for;
  spdlog defaults it on only for a top-level build, and naming it is the
  "do not depend on a default" discipline.
- `-DBUILD_SHARED_LIBS=OFF` gives `libspdlog.a`. `cmake --build build --parallel
  1` is serial; install goes to `$OUT` via the system's
  `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch, no `/dev/null`, nothing
  hardcoded to a target, nothing `export`ed.
- The comment is two sentences, both carrying information — the artifact set and
  the reason for each class of switch. That is the right density.

## One coupling the forecast should record

`spdlog`'s CMake, when `SPDLOG_FMT_EXTERNAL=ON`, finds `fmt` through
`pkg-config` (or `find_package(fmt)`). That means the recipe's correctness
depends on two things outside itself:

1. `packages/fmt` must have been built for the **same** system, so
   `$PREFIX/lib/pkgconfig/fmt.pc` exists. `require("fmt")` guarantees the
   ordering, and the emitter's freshness stamp makes fmt build first — correct.
2. The `.pc` must be inside `PKG_CONFIG_LIBDIR`. On all three systems I checked
   that is `$PREFIX/lib/pkgconfig` (`packages/aarch64-android24/generic.lua:82`),
   so it resolves.

So the dependency is sound, but it is a real one and the builder should confirm
`pkg-config --exists fmt` before diagnosing anything else. Worth a line in
`stage1.md` if it is not there.

## Carried to the build

- `lib/libspdlog.a` — `llvm-objdump -f lib/libspdlog.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libspdlog.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/spdlog/spdlog.h`, `include/spdlog/fmt/fmt.h` — `[ -f include/spdlog/spdlog.h ]`.
- `lib/pkgconfig/spdlog.pc` — `pkg-config --modversion spdlog` → `1.15.3`, and **`pkg-config --libs spdlog` must name `-lfmt`**. That is the check that proves `SPDLOG_FMT_EXTERNAL=ON` actually took, and it is the one that matters most here.
- **The bundled-fmt check:** `include/spdlog/fmt/bundled/` must be **absent**, and `include/spdlog/fmt/core.h` must be a one-line shim including `<fmt/core.h>` (`head -3 include/spdlog/fmt/core.h`). A real bundled copy here means the flag had the wrong name, and the prefix now has two `fmt` implementations.
- No test, example or benchmark binary anywhere under `$OUT`; their presence means one of the four `-D` switches was silently ignored.
- `lib/cmake/spdlog/spdlogConfig.cmake` — `[ -f lib/cmake/spdlog/spdlogConfig.cmake ]`.