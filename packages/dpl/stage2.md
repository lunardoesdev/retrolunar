ACCEPT

# dpl review (stage2)

Recipe: `generic.lua`. Source: `source.lua`, oneDPL 2022.14.0 (git tag
archive). Tarball verified with `tar tf` (1719 entries, top dir
`oneDPL-oneDPL-release-2022.14.0/`), extracted to
`/home/si/.revE/src2/oneDPL-oneDPL-release-2022.14.0`.

## 1. Is it using the SYSTEM?

Yes. `$CMAKE_FLAGS` only; no hardcoded triplet/API/march, no `export` of
search flags, no `DESTDIR`, no `sed`/patch,
`cmake --build build --parallel 1` explicit.

## 2. Is it doing what the package needs?

**`ONEDPL_BACKEND` is the load-bearing switch and the default really is
`tbb`.** `CMakeLists.txt:138-146`:

```
if (NOT DEFINED ONEDPL_BACKEND)
    if (SYCL_SUPPORT)
        set(ONEDPL_BACKEND "dpcpp" CACHE STRING "Threading backend")
    else()
        set(ONEDPL_BACKEND "tbb" CACHE STRING "Threading backend")
    endif()
```

No SYCL on any system here, so the default resolves to `tbb`, and
`CMakeLists.txt:205-212` then runs

```
if (ONEDPL_BACKEND MATCHES "^(tbb|dpcpp|dpcpp_only)$")
    if (ONEDPL_BACKEND MATCHES "^(tbb|dpcpp)$")
        find_package(TBB 2021 REQUIRED tbb OPTIONAL_COMPONENTS tbbmalloc)
        target_link_libraries(oneDPL INTERFACE TBB::tbb)
```

`REQUIRED`. Left at the default, oneDPL would not configure until a TBB
>= 2021 is in the prefix. Note the ordering hazard this creates and the recipe
sidesteps correctly: `packages/tbb` pins **2023.1.0**, which satisfies
`TBB 2021`, so the default *might* have worked — but only by accident of
package ordering, and `-DONEDPL_BACKEND=serial` removes the dependency
entirely, which is the robust choice.

**`serial` is the correct alternative and requires nothing.** Confirmed at
`CMakeLists.txt:283-289`:

```
elseif (ONEDPL_BACKEND MATCHES "^(serial)$")
    target_compile_definitions(oneDPL INTERFACE
        ONEDPL_USE_TBB_BACKEND=0
        ONEDPL_USE_DPCPP_BACKEND=0
        ONEDPL_USE_OPENMP_BACKEND=0
        )
```

Every parallel backend is forced to 0, so no `find_package` runs and no
external library is needed. That makes the install genuinely
system-independent, which is the right property for a header-only package in a
static prefix.

**Header-only, as claimed.** `CMakeLists.txt:151` is
`add_library(oneDPL INTERFACE)` with
`target_compile_features(oneDPL INTERFACE cxx_std_17)`. Nothing is compiled,
so no compiler-version risk and no API-level gate.

**The test tree is entered but builds nothing.** `CMakeLists.txt:356-359` does
`add_subdirectory(test)` whenever oneDPL is top-level, so the recipe's claim
is right that it *is* entered — but every target there is `EXCLUDE_FROM_ALL`
(`test/CMakeLists.txt:92`, `test/kt/CMakeLists.txt:26`), so
`cmake --build` compiles none of it. Correctly characterised: entered, inert.
I confirmed `examples/` is not added at all.

**`ONEDPL_ENABLE_SIMD` left ON is safe.** It only adds a flag to the INTERFACE
target after `check_cxx_compiler_flag` accepts it, so on a compiler lacking
the flag it is a no-op. Correct to leave alone.

## The pkg-config / directory-name question

The brief asks me to check the module names, since the directory is `dpl` but
the library is oneDPL. Three distinct names are in play, and all three are
correct as produced:

| what | name | source |
|---|---|---|
| package directory / `require()` token | `dpl` | recipe convention, matches `topackage.md` |
| pkg-config module | **`dpl`** | `integration/pkgconfig/dpl.pc.in` → installs `dpl.pc` |
| CMake package | **`oneDPL`** | `cmake/templates/oneDPLConfig.cmake.in` → `lib/cmake/oneDPL/` |
| CMake target | `oneDPL` | `add_library(oneDPL INTERFACE)` |

So the pkg-config module is `dpl`, **not** `oneDPL` — a consumer writes
`pkg_check_modules(dpl REQUIRED dpl)`. The recipe's comment says
"ONEDPL_BACKEND is passed through the cache to the installed `dpl.pc`/config",
which uses both names correctly. Good.

Worth recording for the builder: `install(CODE …)` at `CMakeLists.txt:364-366`
plus `install(SCRIPT cmake/scripts/generate_config.cmake)` means the cmake
config lands under `lib/cmake/oneDPL/`. That path **is** covered by the
loader's rewrite sweep (`src/loader.lua:456-457` globs
`$OUT/lib/cmake/*/*.cmake`), so no stale `$OUT` survives. The pkg-config file
lands in `lib/pkgconfig/`, also covered.

## Version and provenance

`oneDPL-release-2022.14.0` is a real tag. The source recipe fetches it from
`github.com/oneapi-src/oneDPL` while its comment says the project moved to
`github.com/uxlfoundation/oneDPL`. The old URL still resolves (I downloaded
from it), so the recipe works; but the newer canonical home is worth using, and
the comment's "2022.14.0 is the newest release tag on either repository"
should be re-checked at update time. Not a defect now.

## Artifacts — what actually installs

- `include/oneapi/dpl/**` — `install(DIRECTORY include/ …)` at
  `CMakeLists.txt:367`
- `lib/cmake/oneDPL/*.cmake` — via the `install(SCRIPT …)` at `:366`
- `lib/pkgconfig/dpl.pc` — from `integration/pkgconfig/dpl.pc.in`
- `share/doc/oneDPL/` (licensing) — `:368`
- **No library at all** — it is an INTERFACE target, so there is no
  `libdpl.a` and no `libdpl.so`. This is the single most important thing for a
  builder to know, because a check for `lib/libdpl.a` would report a false
  failure.

## Forecast

I agree with **6 of 6**. All six rows are WILL BUILD, and correctly so: a
header-only package whose one dependency switch is pinned to a backend
requiring nothing, with no host program compiled and no API gate anywhere.

## Carried to the build

```sh
# 1. artifacts. NOTE: there is NO libdpl.a — this is an INTERFACE target.
#    Checking for a library file would be a false failure.
test -d "$OUT/include/oneapi/dpl"        || echo "MISSING oneapi/dpl headers"
test -f "$OUT/lib/pkgconfig/dpl.pc"      || echo "MISSING dpl.pc"
test -d "$OUT/lib/cmake/oneDPL"         || echo "MISSING lib/cmake/oneDPL"
find "$OUT/lib" -name 'libdpl.*' | wc -l    # expected 0 — INTERFACE target only

# 2. THE BACKEND CHECK. dpl.pc must record the serial backend, not tbb.
#    This is the check that proves -DONEDPL_BACKEND=serial took effect.
cat "$OUT/lib/pkgconfig/dpl.pc"

# 3. the module name is "dpl", not "oneDPL" — both spellings tested so the
#    builder sees which one is real
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion dpl      # expected
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion oneDPL 2>/dev/null \
  || echo "oneDPL is the cmake package name, not a pkg-config module (expected)"

# 4. no $OUT left in either artifact — proves the loader rewrite ran.
#    Scoped to dpl's own files; both paths are covered by the sweep at
#    src/loader.lua:456-457.
grep -l "$OUT" "$OUT/lib/pkgconfig/dpl.pc" "$OUT/lib/cmake/oneDPL/"*.cmake
echo "(no output above = loader rewrite ran)"

# 5. no TBB leaked in: the serial backend must define all three macros to 0
grep -rc 'ONEDPL_USE_TBB_BACKEND=0' "$OUT/lib/cmake/oneDPL/"*.cmake
grep -rn 'TBB::tbb' "$OUT/lib/cmake/oneDPL/" "$OUT/lib/pkgconfig/dpl.pc"
echo "(no TBB::tbb above = serial backend confirmed in the installed config)"

# 6. the test tree may have been CONFIGURED (it is added when top-level) but
#    nothing in it may have been COMPILED
test -d "$WORK/build/test" && \
  find "$WORK/build/test" -name '*.o' | wc -l    # expected 0 (EXCLUDE_FROM_ALL)

# 7. C++17 is what the headers demand, and it is an INTERFACE property
grep -o 'cxx_std_1[47]' "$OUT/lib/cmake/oneDPL/"*.cmake | sort -u
```