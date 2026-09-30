ACCEPT

# xxhash 0.8.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **`-S cmake_unofficial` is the single most important line in this recipe, and
  the comment says exactly why.** xxhash ships its CMake build in a
  subdirectory rather than at the top level, so `cmake -S .` would configure
  the wrong tree. A reader who "tidied" that to `-S .` would get a configure
  that either errors or does nothing useful, and the comment prevents it.
  This is the same class of detail as `packages/tcl`'s `./unix/configure` run
  from the source root: the build system is not where you would guess, and the
  recipe says so.
- `-DBUILD_SHARED_LIBS=OFF` is the static control the prefix uses everywhere.
- **The comment states the `xxhsum` position honestly**: "Static library,
  header, pkg-config file and the `xxhsum` tool; nothing here ever runs a
  target binary." `xxhsum` is a *target* CLI, not a host program — it is
  xxhash's own deliverable, like `flatc` in `packages/flatbuffers` — so
  shipping it is correct. The second clause is the important one: it says
  explicitly that it is built and never executed, which is the distinction
  AGENTS.md draws between "host program, must not build" and "target program,
  must not run". Getting that the wrong way round is the most common recipe
  error in this tree.
- `cmake --build build --parallel 1` is serial; install goes to `$OUT` via the
  system's `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch, no `/dev/null`,
  nothing hardcoded to a target, nothing `export`ed.
- `require("xxhash@source")` names no missing package.

## The one thing `stage1.md` should verify

The upstream CMake in `cmake_unofficial/` has historically gated its tests and
benchmarks behind options that **default to ON** when xxhash is the top-level
project. If that is still true in 0.8.3, the recipe is missing switches and
would build host programs — the same defect I found in `expat` and `flac` in
earlier waves.

The build-`--target` workaround is also available and would be a valid
alternative (`cmake --build build --target xxhash`), though naming the switches
is cleaner where they exist. So the check is: list the `add_executable` calls
under `cmake_unofficial/` and see what guards them. That is cheap and it is the
only open question in this package.

## Carried to the build

- `lib/libxxhash.a` — `llvm-objdump -f lib/libxxhash.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libxxhash.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/xxhash.h` — `[ -f include/xxhash.h ]`.
- `lib/pkgconfig/libxxhash.pc` — `pkg-config --modversion libxxhash` → `0.8.3`. xxhash ships one, inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `bin/xxhsum` — `[ -x bin/xxhsum ]`. Expected, and it is a **target** program: **never run it**.
- **The check that settles the open question:** no test or benchmark binary anywhere under `$OUT` — `find $OUT -name '*bench*' -o -name 'xxhsum*test*'` must return nothing. A `bin/xxhsum` is correct; anything else means a host program was built and the recipe must not be recorded as built until a switch is added.
- `lib/cmake/xxhash/xxhashConfig.cmake`, if the release ships one — `[ -f lib/cmake/xxhash/xxhashConfig.cmake ]`.
- **And a sanity check on the `-S`:** the configure log must reference `cmake_unofficial`. If it references the top-level `CMakeLists.txt`, the source directory is wrong and nothing downstream can be trusted.