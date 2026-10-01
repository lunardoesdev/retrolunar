# range-v3 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 0.12.0
- Build system: CMake (header-only)
- Installs: the whole `include/` tree — `range/`, `concepts/`, `meta/`,
  `std/` and `module.modulemap` — plus a CMake package config under
  `lib/cmake/range-v3/` (`range-v3-config.cmake`,
  `range-v3-config-version.cmake`, `range-v3-targets.cmake`). **No library
  file and no pkg-config file** — the three targets are all `INTERFACE`
  (`CMakeLists.txt:27`, `:34`, `:42`) and upstream ships no `.pc`.
- Requires: `range-v3@source` only. No dependencies.

**Upstream identity, checked.** range-v3 is developed at
**`github.com/ericniebler/range-v3`**, which is the canonical repository for
the library; the `range-v3/range-v3` organisation path does not exist (404).
The brief's note about a fork is half right: what the repo does carry is a
history from the older pre-fork tree, and the two tags above the newest
release — `fork_point` and `fork_base` — are merge markers, not releases.
**0.12.0 is the newest release tag** and is what is pinned.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Nothing is compiled **once the three build options are off** — every target is `INTERFACE`. `RANGE_V3_TESTS`, `RANGE_V3_EXAMPLES` and `RANGE_V3_DOCS` are `CMAKE_DEPENDENT_OPTION`s defaulting ON when standalone (`ranges_options.cmake:43,47,55`) and drive `add_subdirectory` at `CMakeLists.txt:57,61,65`; the recipe passes all three OFF, plus `RANGE_V3_PERF` and `RANGE_V3_HEADER_CHECKS`. Without them this row would build ~254 host executables. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; `INTERFACE` targets and a file copy are portable. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is a file copy, identical on every
system, and **no architecture check applies** — but only because the recipe
now turns the build options off. See risk 1: an earlier version of this
forecast claimed range-v3 had no options at all, which was false. `armv7a-android*` and
`i686-android*` match `aarch64-android*` — no step observes an API level.

**The header layout is the thing to get right, and upstream does it for us.**
`CMakeLists.txt:186` is
`install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
FILES_MATCHING PATTERN "*")` — the entire include tree. That matters because
range-v3's public headers are split across four directories and reference each
other: `#include <range/v3/...>`, `<concepts/...>`, `<meta/...>` and
`<std/...>` are all resolved from the same include root. Copying only
`range/` would produce an install that looks plausible and fails on the first
`#include <meta/...>`. The recipe runs upstream's install rather than copying
by hand, which is the reason.

**API level notes.** None, and worth a positive statement rather than an
assumed one: range-v3 is pure C++ standard library. I checked its headers for
the usual suspects and found no libc or platform assumption — it needs
`type_traits`, `tuple`, `utility` and friends, all header-only in libc++ and
libstdc++. So "header-only" does mean no target-libc obligation for consumers
either.

**Risks / what a reviewer should check.**

2. **No pkg-config file.** Unlike Eigen (which ships `eigen3.pc`), range-v3
   ships none — `find` for `*.pc.in` returns nothing. A consumer either uses
   the CMake package config (`find_package(range-v3)`) or adds
   `-I$PREFIX/include` by hand. Worth recording so nobody writes
   `pkg-config --cflags range-v3` and concludes the package is broken.
3. **Three targets, not one.** `range-v3`, `range-v3-concepts` and
   `range-v3-meta` are separate `INTERFACE` targets, all exported
   (`CMakeLists.txt:180`). A consumer wanting only concepts links
   `range-v3::concepts`. The main header-only entry point is
   `range-v3::range-v3`.
4. **The exported target names are `range-v3::…`** (`NAMESPACE` on line 181)
   — note the hyphen, which is unusual and easy to mistype.
5. **`module.modulemap` is installed** by the same `install(DIRECTORY)` rule.
   It matters for Clang module consumers and is easy to overlook when checking
   the install by hand.

**How to verify once built.**

- `include/range/v3/all.hpp` exists — **and so do** `include/concepts/`,
  `include/meta/` and `include/std/`. Checking only `range/` is exactly the
  mistake the layout trap invites; the other three directories' presence is
  the check that the recursive install happened.
- `include/module.modulemap` exists.
- `lib/cmake/range-v3/range-v3-config.cmake` and `range-v3-targets.cmake`
  exist.
- **No library file:** `find $OUT -name '*.a' -o -name '*.so'` must return
  nothing.
- **No pkg-config file either:** `find $OUT -name '*.pc'` must return nothing
  — that is expected, not a gap (risk 1).
- A `find_package(range-v3)` consumer must be able to link
  `range-v3::range-v3`; that is the one functional check worth doing.
- Compare two systems' `include/` with `diff -r`: any difference is a bug.
