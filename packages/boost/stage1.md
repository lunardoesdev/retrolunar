# stage1 — Boost 1.92.0 (build forecast)

- Version pinned: **1.92.0**, from the `archives.boost.io/release/` listing.
- URL: `https://archives.boost.io/release/1.92.0/source/boost_1_92_0.tar.gz`
- Archive verified before reading: **235384471 bytes**, matching the size the
  server lists for that path; `curl` reported `HTTP 200 size=235384471` and
  `tar tzf` listed **93850 entries** with exit 0. No truncation. The tarball
  has exactly one top-level directory, `boost_1_92_0`.
- Build system: **b2/jam**. Not cmake, not meson, not autotools. There is no
  `configure` and no top-level `CMakeLists.txt`; the top level is
  `Jamroot`, `boost-build.jam`, `boostcpp.jam`, `bootstrap.sh`,
  `bootstrap.bat`.
- Requires: `boost@source`, and `boost@native` (for the b2 engine — see
  "Native or target" below).
- Files: `source.lua`, `generic.lua`, `clang-native.lua`, this file.
  **No `android.lua`**, on purpose.

## The headline: this package is a HARD GATE for CGAL

`packages/CGAL/stage1.md` records a blocker, and this package is what
removes it. CGAL's `cmake/modules/CGAL_SetupCGAL_CoreDependencies.cmake:51`
and `cmake/modules/CGAL_SetupBoost.cmake:17` both say, unconditionally:

```cmake
find_package( Boost 1.74 REQUIRED )
```

CGAL's adder wrote no `generic.lua` precisely because a `require("boost")`
of a package that does not exist makes the loader hard-error
(`src/loader.lua:223`, `error("module '" .. mod .. "' not found")`), so
shipping the recipe would have handed the reviewer a known-broken file.
`packages/boost/` now exists, so `require("boost")` resolves and CGAL can
proceed. **Until this package builds on a system, CGAL remains blocked on
every one of the six systems**, and that is the correct state to record
rather than work around.

**This package does not make CGAL build. It makes CGAL's dependency
resolvable.** Whether CGAL then compiles is CGAL's own question and belongs
in CGAL's stage2/stage3, not here.

### And `find_package` needs the CMake package files, not just headers

This is the part worth stating loudly, because "Boost is headers, ship the
headers" is the obvious guess and **it is wrong here.**

CGAL's root `CMakeLists.txt:4` declares
`cmake_minimum_required(VERSION 3.15...3.31)`. The `...3.31` upper bound sets
every policy introduced up to 3.31 to NEW, and **CMP0167** (introduced in
CMake 3.30) removes the `FindBoost` module:
`/usr/share/cmake/Modules/FindBoost.cmake:388-391` is

```cmake
cmake_policy(GET CMP0167 _FindBoost_CMP0167)
if(_FindBoost_CMP0167 STREQUAL "NEW")
  message(FATAL_ERROR "The FindBoost module has been removed by policy CMP0167.")
endif()
```

So with CGAL's policy range, `find_package(Boost 1.74 REQUIRED)` can only be
satisfied by a **package config** — `BoostConfig.cmake` plus
`BoostConfigVersion.cmake` — not by CMake's bundled find module.

I checked this rather than asserting it. With the host's cmake 4.4.3, a
project using CGAL's exact `cmake_minimum_required` line, and a prefix
containing **only** `include/boost/version.hpp` and `include/boost/config.hpp`:

```
CMake Error at CMakeLists.txt:3 (find_package):
  By not providing "FindBoost.cmake" in CMAKE_MODULE_PATH this project has
  asked CMake to find a package configuration file provided by "Boost", but
  CMake did not find one.
  ...
    BoostConfig.cmake
    boost-config.cmake
```

A headers-only install would therefore leave CGAL blocked even after this
package succeeded. That is the single strongest argument for the recipe
below, and it is why the recipe runs b2 instead of `cp -r`-ing the headers.

## Native or target — and why the split

**Boost is a target package, but its build tool is native.** Both files
exist for that reason.

The decisive evidence is `bootstrap.sh:225-240`:

```sh
# Build bjam
if test "x$BJAM" = x; then
  $ECHO "Building B2 engine.."
  pwd=`pwd`
  CXX= CXXFLAGS= "$my_dir/tools/build/src/engine/build.sh" ${TOOLSET}
  ...
  BJAM="$my_dir/tools/build/src/engine/b2"
  cp "$BJAM" .
```

Note `CXX= CXXFLAGS=`: upstream **deliberately blanks the compiler
variables** before building the engine, so it is built by the *host*
compiler no matter what toolchain the surrounding build is using. Then the
resulting `b2` binary **runs** on the build machine to read `Jamroot` and
drive everything else. A b2 built with the cross `$CXX` would be an
aarch64-android or x86_64-w64-mingw32 ELF that could never usefully execute
here, and executing it to find out would be emulation, which AGENTS.md
forbids outright.

So:

- `packages/boost/generic.lua` — the real install, for every target system.
  It does `require("boost@native")` and then calls the bare `b2`, which
  resolves to `$NATIVE_PREFIX/bin/b2` because the loader prepends that
  (`src/loader.lua:413`). This is exactly the `packages/file/` shape.
- `packages/boost/clang-native.lua` — builds the b2 engine with
  clang-native's host `$CXX` and installs it as `$OUT/bin/b2`.

**Why there is no `android.lua`.** Nothing in this package is
Android-specific. The engine build takes `$CXX`/`$CXXFLAGS` from whichever
system setup is in effect, and the two flags on the b2 command line are
`--prefix` and `--layout`, which are install-shape decisions, not target
facts. A `packages/boost/android.lua` would be a byte-identical copy of
`generic.lua`, which is the same defect as the `packages/bison/android.lua`
that was deleted for exactly that reason. It is not written.

Contrast with `packages/bison/generic.lua`, which *does* carry a
system-specific concern — `require("gperf@native")` at line 1 plus the
`--enable-relocatable` explanation — because bison's PKGDATADIR problem is a
genuine cross-build issue. Boost has no analogue.

## Subset versus full — the honest trade-off

**This recipe targets the headers + CMake package config, and says plainly
that a full Boost build does not fit `topackage.md`'s rules.**

`topackage.md:106-108` requires a **serial** build with **peak memory under
2 GB**. A full Boost build is:

- the ~50 libraries that have a `build/Jamfile` or `build/Jamfile.v2`
  (46 matches under `libs/*/build/`, of which the real compiled set is
  filesystem, thread, atomic, chrono, date_time, regex, serialization,
  graph, iostreams, locale, log, program_options, context, coroutine, fiber,
  math, mpi, python, timer, wave, …);
- many hours of wall clock and a large transient tree;
- and, decisively, it produces **compiled artifacts whose ABI is tied to the
  target libc**, which is precisely the class of package that needs a real
  build per system.

Claiming a full build "fits" would be exactly the confident guess this
repository's stage files exist to prevent. So the recipe does not attempt it.

**What the recipe installs**, via upstream's own target
`libs/headers/build//install` (this is the supported entry point —
`libs/headers/README.md:3`: *"This is a "fake" library that installs the
Boost headers on `b2 libs/headers/build//install`"*):

| Path under `$OUT` | What | Source of truth |
|---|---|---|
| `include/boost/**` | the header tree, 16394 files (15937 `.hpp`, 304 `.ipp`, 151 `.h`, 2 `.inc`) | `libs/headers/build/Jamfile:64-69` |
| `lib/cmake/boost_headers-1.92.0/boost_headers-config.cmake` | the package config | `boost-install.jam:1031-1032` |
| `lib/cmake/Boost-1.92.0/BoostConfig.cmake` | top-level config, does `find_package(boost_headers ... CONFIG HINTS ...)` | `boost-install.jam:1099` |
| `lib/cmake/Boost-1.92.0/BoostConfigVersion.cmake` | version file | `tools/boost_install/Jamfile:22`, installed at `boost-install.jam:1106` |
| `lib/cmake/BoostDetectToolset-1.92.0.cmake` | toolset detection | `boost-install.jam:1094` |

`--layout=system` is passed explicitly rather than left to the default,
because `boostcpp.jam:84-94` picks `versioned` on NT and `system` elsewhere
based on `os.name` — the **build machine's** OS, which is Linux for every
target in this repo including mingw. Being explicit removes the dependence
on a value that is not a property of the target at all, and `system` layout
is what puts headers at `include/boost/` rather than
`include/boost-1_92_0/` (`boost-install-dirs.jam:15-28` returns an empty
`header-subdir` for `system`). A consumer doing `-I$PREFIX/include` then
finds `<boost/version.hpp>`, which is what `find_package` resolves against.

**The Eigen trap does not apply here, and it is worth saying why.** Eigen's
failure mode was copying only the top level of a header tree. Here the
install is not a hand copy at all: `libs/headers/build/Jamfile:41-52`
recurses with `path.glob-tree` over the whole `boost/` directory, so
`boost/core/`, `boost/numeric/`, `boost/lambda2/`, `boost/spirit/` and the
rest all come along. There are 148 subdirectories under `boost/` in the
tarball and 166 top-level entries; a top-level-only copy would be unusable.
Upstream does the recursion, and the recipe runs upstream's rule.

## What I verified about the header tree

Extracted selectively from the real tarball (never a full 235 MB unpack):

- `boost/` at the top level of the tarball: **17749 entries**, of which
  16412 are regular files and 148 are subdirectories.
- **Zero symlinks in the entire archive** (`tar tvzf | grep -c '^l'` → 0),
  so there is no symlink-dereferencing hazard in the copy.
- 18 files under `boost/` are not headers by extension (`.natvis`, `.m4`,
  `.erb`, `.patch`, `.dtd`, `.re`, `.sh`, `.bat`, `.py`, `.txt`). Upstream's
  `path.glob-tree` filters to `*.hpp *.ipp *.h *.inc`
  (`libs/headers/build/Jamfile:43-45`), so these are excluded. That is
  upstream's choice, not ours, and it is harmless — none is `#include`d.
- `boost/compatibility/cpp_c_headers/` **does not exist in this release**
  (0 entries). `libs/headers/build/Jamfile:46` globs it anyway; an empty
  glob is not an error, it just contributes nothing. Recorded because an
  absence claim needs its command, and because a reviewer seeing "0 entries"
  for something the Jamfile clearly expects should know it is upstream's
  layout, not a broken extraction.
- `boost/version.hpp` in the tarball reads `#define BOOST_VERSION 109200`
  and `#define BOOST_LIB_VERSION "1_92"`, matching `Jamroot:166`
  (`constant BOOST_VERSION : 1.92.0 ;`).

## Verdict table

Nothing is compiled, so no system differs on toolchain grounds. The one
real variable is the **API level**, and for a headers-only install it is
reached only at *consumer* compile time, not here.

**Superseded in one place.** This table was written when `generic.lua` was the
only install path, and it says so in its first line. `x86_64-mingw` no longer
takes that path: `packages/boost/x86_64-mingw.lua` was added because
`packages/i2pd/stage1.md` established that a headers-only Boost cannot satisfy
`find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)`,
and that package now builds and links on mingw. The five other rows are
unchanged and still describe what those systems do. The mingw row below is
kept as written, because its `--layout=system` reasoning still holds; the
compiled subset it did not anticipate is documented in
`packages/i2pd/stage2.md` and `stage3.md`, where the build evidence is.

| System family | Verdict | Basis |
|---|---|---|
| aarch64-android21 | WILL BUILD | No library is compiled. `libs/headers/build/Jamfile` is `path.glob-tree` + `install` + `make` (text emission) — no `lib` rule is reached. The b2 engine is a **host** binary (`bootstrap.sh:229` clears `$CXX`; the loader runs `$NATIVE_PREFIX/bin/b2`), so no target libc is touched. The API-21 gaps AGENTS.md lists (`stderr` as a real symbol, `POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`, `mblen`/`getpass`, `O_BINARY`) cannot bite a build that links nothing. |
| aarch64-android24 | WILL BUILD | Same; the install is byte-identical on every system. |
| aarch64-android35 | WILL BUILD | Same. 35 exposing `mktime_z` is irrelevant here — no `date_time` is compiled. |
| x86_64-android35 | WILL BUILD | Same. Boost's own `combined.cpp` probe accepts `__x86_64__`, so even if a config check ran it would take the intended branch. |
| x86_64-mingw | WILL BUILD | Same, and note the one place the host/target split is load-bearing: `boostcpp.jam:84-94` chooses `--layout` from `os.name`, the **build machine's** OS (Linux), not the target's. `--layout=system` is therefore passed explicitly so the mingw prefix gets `include/boost/`, not `include/boost-1_92_0/`. A `-I$PREFIX/include` consumer on mingw needs the former. |
| clang-native | WILL BUILD | The `clang-native.lua` recipe: `engine/build.sh` compiles the 65 sources at `build.sh:432-497` into a host `b2` (`build.sh:513`). It also builds `generic.lua`'s install, since `clang-native` is itself a system in this repo. |

`armv7a-*` and `i686-*` behave like `aarch64-android*`; no step in this
recipe observes an architecture or an API level.

## The no-emulation question, answered

`boostcpp.deduce-architecture` (`boostcpp.jam:638-688`) calls
`configure.find-builds` on `/boost/architecture//32`, `//64`, `//arm`,
`//combined` etc. Those are **`obj` targets**, declared in
`libs/config/checks/architecture/Jamfile.jam:16-27` as `obj 32 : 32.cpp ;`
— compile-only, no link, no run. `configure.try-find-build`
(`configure.jam:319-320`) drives them through the engine's `UPDATE_NOW`
builtin (`builtins.cpp:1494-1556`), which calls `make()`. There is no
`RUN_OUTPUT`/`testing.run`/`capture-output` anywhere in `configure.jam`
(grepped, zero matches).

The probes themselves are pure preprocessor assertions — `32.cpp` is
`int test[sizeof(void*) == 4? 1 : -1];`, `arm.cpp` is an `#error "Not ARM"`
guard. They detect the *target* by compiling, never by running. So even in
the cross case this is a compile with `$CXX`, which is ordinary and legal.

## Open questions I could NOT establish

These are real gaps, not hedges. A builder should not treat the WILL BUILD
rows as covering them.

1. **I did not run b2.** The brief forbids building, so no `b2` invocation
   in this recipe has ever been executed, not even
   `libs/headers/build//install`. The load-bearing claims are all read from
   source and cited, but "this exact command line produces those five
   paths" is a forecast. **First thing a builder should do:** run the
   generated script on `clang-native` (cheapest system, and it exercises
   both new recipes in one go) and diff the resulting `$OUT` against the
   table above.

2. **The `headers` target at the top level is a trap, and I want it
   double-checked.** `Jamroot:356` reads
   `generate headers : $(all-headers)-headers : <generating-rule>@generate-alias <action>@do-nothing`,`
   with `do-nothing` at `Jamroot:344` — an empty `notfile-target`
   (`Jamroot:346-354`). So `b2 headers` alone should install **nothing**;
   the install is `libs/headers/build//install`. My reasoning is that
   `$(all-headers)` is also *empty* in this tarball, because
   `Jamroot:177-178` globs `libs/*/include/boost` and
   `libs/*/*/include/boost` and **neither exists** — this release uses the
   modular layout with headers pre-assembled at the top level
   (`grep -c 'libs/[^/]*/include/boost/'` → **0**). That also means
   `Jamroot:186-189` never sets `BOOST_MODULARLAYOUT`. I am reasonably but
   not fully confident the whole graph is consistent under that layout; a
   builder who sees b2 fail to parse should look here first, and the
   fallback (`cp -r boost $OUT/include/`) is **not** an acceptable
   substitute, because it would leave CGAL blocked per the CMP0167 finding
   above.

3. **`--layout=system` + `--build-type`.** `boostcpp.jam:97-108` rejects
   `--layout=system` combined with `--build-type=complete`. The default
   build-type is `minimal` (`boostcpp.jam:53-54`), so the recipe is
   consistent as written, but I did not exercise it.

4. **BoostConfig.cmake is generated with a `<version>` and a variant file
   that references a toolset.** `boost-install.jam:238-255` emits
   `_BOOST_SKIPPED(...)` guards keyed on `Boost_COMPILER` when layout is
   `versioned`. Under `system` layout (`:257-294`) the guard keys on
   `Boost_USE_STATIC_LIBS` instead. Whether CGAL's
   `find_package(Boost 1.74 REQUIRED)` — with **no** `COMPONENTS` — accepts
   the result is the one thing in this forecast that most needs a real run.
   CGAL asks for no components, and `boost_headers` is an `INTERFACE`
   target (`boost-install.jam:1024-1027`), so it very likely does; but
   "very likely" is not "verified", and this is the load-bearing step for
   the whole package.

5. **No `.pc` file ships.** Boost has never shipped one, and nothing in
   `boost_install` generates a `pkgconfig` file (checked: the install rules
   in `boost-install.jam` are `libdir`, `cmakedir`, `includedir`,
   `bindir`, `dlldir` only). So `pkg-config --modversion boost` will not
   work and should not be attempted as a verification check.

6. **Consumer-side API-level risk is not assessed.** Boost.System,
   Boost.Filesystem and Boost.Thread all have real code paths that touch
   `getpagesize`, `pthread_*` and `__android_log_write`. A future recipe
   that compiles those libraries for android21 will hit API-21 walls that
   this headers-only install never reaches. Nothing here should be read as
   evidence that a compiled Boost would build on android21.

## How to verify once built

Scoped to paths Boost owns, per the AGENTS.md rule about not counting a
shared directory.

- `test -f $PREFIX/include/boost/version.hpp` — the top level alone proves
  nothing, see below.
- `test -d $PREFIX/include/boost/core` **and**
  `test -d $PREFIX/include/boost/numeric` **and**
  `test -d $PREFIX/include/boost/spirit` — the recursive-install check.
  Checking only `boost/version.hpp` is exactly the mistake the layout trap
  invites; `path.glob-tree` is what makes these three exist.
- `grep -c '^#define BOOST_LIB_VERSION "1_92"' $PREFIX/include/boost/version.hpp`
  → 1, and the file is the one from the tarball, not a generated one (Boost
  does not generate it; only `Eigen/Version` is generated, per Eigen's
  stage1).
- `find $PREFIX -name 'libboost*' | wc -l` → **0**. This is the single check
  that proves nothing was compiled and that the recipe really is the
  headers-only subset.
- `test -f $PREFIX/lib/cmake/Boost-1.92.0/BoostConfig.cmake` and
  `test -f $PREFIX/lib/cmake/Boost-1.92.0/BoostConfigVersion.cmake` — these
  are what CGAL actually needs, and they are the reason the recipe runs b2.
- `test ! -e $PREFIX/include/boost-1_92_0` — confirms `--layout=system`
  took effect and the headers are where a `-I$PREFIX/include` consumer looks.
- **`diff -r` two systems' `include/boost`** — must be identical. If it is
  not, something system-specific leaked into the install.
- `file $NATIVE_PREFIX/bin/b2` must report an **x86-64** ELF (the host),
  never a target architecture. This is the check that the native/target
  split is real and not accidentally inverted.