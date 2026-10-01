ACCEPT

# xtensor review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, xtensor 0.27.1 (git tag
archive). Tarball verified with `tar tf` (434 entries, top dir
`xtensor-0.27.1/`), extracted to `/home/si/.revE/src2/xtensor-0.27.1`.

## 1. Is it using the SYSTEM?

Yes. `cmake -S . -B build $CMAKE_FLAGS` with no per-target flags at all, no
hardcoded triplet/API/march, no `export` of search flags, no `DESTDIR`, no
`sed`/patch, `cmake --build build --parallel 1` explicit.

That the recipe passes **no** options is itself correct here and is the point:
every option xtensor exposes that would reach for the network or a host tool
is already defaulted off (below), so there is nothing to override.

## 2. Is it doing what the package needs?

**The blocker is real and correctly diagnosed.** `CMakeLists.txt:43-54`:

```
set(xtl_REQUIRED_VERSION 0.8.0)
if(TARGET xtl)
    … version check …
else()
    find_package(xtl ${xtl_REQUIRED_VERSION} REQUIRED)
endif()
```

`REQUIRED`, and the `else()` branch is taken whenever xtl is not already a
target in the same build. There is **no `fallback`/`FetchContent`** — cmake
has no subproject mechanism here, so a missing xtl is a hard configure
failure, not a vendored download. And:

```
$ ls -d packages/xtl
ls: cannot access 'packages/xtl': No such file or directory   (rc=2)

$ grep -n 'xtl' topackage.md
(no hits)
```

So `require("xtl")` in `generic.lua:11` cannot resolve, exactly as the recipe's
own BLOCKER comment says. The recipe is honest and correct, and — importantly
— it is written so that adding `packages/xtl` makes it work with no edit. That
is the right way to record a missing dependency: the recipe stays correct, the
forecast says WILL NOT BUILD.

**The remaining option analysis is accurate; I checked each claim.**

- `CMakeLists.txt:202` is `add_library(xtensor INTERFACE)` — header-only,
  nothing compiled. Confirmed.
- `:209` is `target_compile_features(xtensor INTERFACE cxx_std_20)`. An
  INTERFACE property: it does not affect this build (nothing compiles) but does
  set the standard on consumers. The recipe's reading is right, and the
  unguarded `concept` keyword at
  `include/xtensor/utils/xutils.hpp:590,613` is what makes C++20 a real floor.
- `:216-217` `BUILD_TESTS`/`BUILD_BENCHMARK` default OFF — confirmed, so
  neither is passed.
- `DOWNLOAD_GBENCHMARK` (`:218`) is only consulted by
  `add_subdirectory(benchmark)` at `:250`, which `BUILD_BENCHMARK=OFF` never
  reaches. Correct — no gbenchmark fetch.
- `XTENSOR_USE_XSIMD` / `_TBB` / `_OPENMP` default OFF (`:62-64`), so the
  `find_package` calls at `:83, :90, :95` do not run. Correct.
- `find_package(nlohmann_json 3.1.1 QUIET)` at `:57` is `QUIET` and optional,
  only enabling `xjson.hpp`, which is not in the single-include list
  (`:331-335`). Correct.

So once xtl exists, this recipe needs no flags at all. That is the correct
minimal recipe.

## Forecast

I agree with **6 of 6**. All six rows are WILL NOT BUILD, and the reason —
`packages/xtl` does not exist — is verified three ways (the `REQUIRED`
`find_package`, the `ls`, and the empty `topackage.md` grep). Recording
WILL NOT BUILD honestly for a missing dependency is what AGENTS.md asks for.

Caveat, same as the other cmake/meson packages in this wave: on clang-native
this would also hit the missing-`MESON_FLAGS`-class issue only for *meson*
packages; graphite2 and mold both use cmake and clang-native **does** export
`CMAKE_FLAGS` with `-DCMAKE_INSTALL_PREFIX=$OUT`, so once xtl exists this
package will install correctly on clang-native too.

## Artifacts, had it built

- `include/xtensor/**` (plus `include/xtl/**` only if vendored — it is not)
- `lib/cmake/xtensor/*.cmake`
- `lib/pkgconfig/xtensor.pc`
- **No library file** — INTERFACE target, so no `libxtensor.a`/`.so`. A check
  for one would be a false failure.

## Carried to the build

**Blocked.** `require("xtl")` fails at load time, so no build script is
emitted. Record that precondition at the top of stage3.md rather than
presenting a build that never ran.

```sh
# PRECONDITION
ls -d "$PACKAGEDIR/xtl" || { echo "BLOCKED: no xtl package (xtensor needs >= 0.8.0)"; exit 1; }

# once unblocked:
test -d "$OUT/include/xtensor"           || echo "MISSING xtensor headers"
test -f "$OUT/lib/pkgconfig/xtensor.pc"  || echo "MISSING xtensor.pc"
find "$OUT/lib" -name 'libxtensor.*' | wc -l    # expected 0 — INTERFACE target

# the xtl version must clear 0.8.0; this is the gate that blocked it
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion xtl   # needs >= 0.8.0

# C++20 is an INTERFACE requirement — check the consumer contract, since
# nothing is compiled here to prove it
grep -o 'cxx_std_[0-9]*' "$OUT/lib/cmake/xtensor/"*.cmake | sort -u
# expected: cxx_std_20

# and the headers must actually compile at C++20 from the install prefix
printf '#include <xtensor/xarray.hpp>\nint main(){return 0;}\n' > /tmp/xc.cpp
"$CXX" -std=c++20 -I"$OUT/include" -fsyntax-only /tmp/xc.cpp \
  && echo "OK: C++20 headers self-contained from the install prefix"
```