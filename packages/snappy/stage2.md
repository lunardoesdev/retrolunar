ACCEPT

# snappy 1.2.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- `-DBUILD_SHARED_LIBS=OFF` is the static control the prefix uses everywhere.
- `-DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=OFF` are both real
  snappy CMake options, and the comment gives the reason in terms the rulebook
  accepts: the tests and benchmarks are **host programs**, which is the
  category AGENTS.md says a cross build must not compile. snappy's tests
  compile the library into a test binary and its benchmarks pull in
  `google/benchmark`; both are exactly what the rule is aimed at.
- The comment's phrase "would just be dead weight in a target prefix" is
  accurate — nothing in a prefix can run either program.
- `cmake --build build --parallel 1` is serial, and install goes to `$OUT` via
  the system's `-DCMAKE_INSTALL_PREFIX=$OUT`. No `sed`, no patch, no
  `/dev/null`, no `export` of search flags, and nothing hardcoded to a target.
- `require("snappy@source")` names no missing package, and snappy has no
  dependency of its own — nothing in the prefix needs to be searched for, which
  is why the recipe passes no include or library path. Worth stating, because
  in this tree most recipes list two or three `require()`s and a zero-dependency
  recipe can look like an omission.

## Non-blocking observation

snappy's CMake has no `find_package` for anything, so `$CMAKE_PREFIX_PATH`
being set is irrelevant here. The one thing a reviewer should confirm against
the tarball is that `SNAPPY_BUILD_TESTS`/`SNAPPY_BUILD_BENCHMARKS` are the
option names in this release rather than, say, `BUILD_TESTS` — a wrong name
would be silently ignored by cmake and the host programs would build anyway,
which is the failure mode `--target`-style workarounds exist to avoid. If
`stage1.md` does not cite the option lines, that is the one gap.

## Carried to the build

- `lib/libsnappy.a` — `llvm-objdump -f lib/libsnappy.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libsnappy.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/snappy.h`, `include/snappy-snapshot.h`, `include/snappy-stubs-public.h` — `[ -f include/snappy.h ]`.
- `lib/pkgconfig/snappy.pc` — `pkg-config --modversion snappy` → `1.2.2`. snappy ships one, and `lib/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set.
- **The check that settles the recipe:** no test or benchmark binary anywhere under `$OUT`. `find $OUT -name '*bench*' -o -name 'snappy_unittest*'` must return nothing. If either appears, one of the two `-D` switches had the wrong name and was silently ignored — that is the failure to look for, not a missing artifact.
- No CMake package config unless the release ships one; consumers normally use the `.pc`.