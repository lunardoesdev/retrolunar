# CGAL 6.2.1 — build forecast

**WILL NOT BUILD on any system in this tree.** Blocked on a dependency that
does not exist here. `source.lua` is written and is correct; there is
deliberately **no `generic.lua`**, because any build recipe would have to
`require("boost")` and `packages/boost` is absent — the loader resolves a
missing `require` as a hard error, so shipping the recipe would hand the
reviewer a known-broken file rather than an honest "blocked".

Source: `CGAL-6.2.1.tar.xz` from the GitHub release. Archive verified before
reading: 26604900 bytes, matching the server `Content-Length` exactly,
`xz -t` clean, 7815 entries, and selective extraction recovered 198 of the
archive's 198 `CMakeLists.txt` files. Top directory `CGAL-6.2.1`.

## The blocker

`cmake/modules/CGAL_SetupCGAL_CoreDependencies.cmake:51` is

```cmake
find_package( Boost 1.74 REQUIRED )
```

unconditional, in the core dependency setup every release build goes through.
`cmake/modules/CGAL_SetupBoost.cmake:17` repeats it as
`find_package( Boost 1.74 REQUIRED )`. There is no `-D` that turns it off:
the only Boost-related switch in the root file is
`CGAL_DO_NOT_USE_BOOST_MP` (`CMakeLists.txt:122`), whose help string scopes it
to "the support of boost multiprecision library" — it drops a feature, not the
dependency.

`packages/boost` does not exist. Verified by directory test, not by reading
`topackage.md`: `topackage.md:292` still shows CGAL unchecked *and* `:291`
shows Boost unchecked, but that file is a backlog rather than an inventory —
`packages/openblas` and `packages/lapack` both exist right now with
`topackage.md:295-296` still unchecked. The filesystem was checked directly
for all of these.

## Dependencies, and which of them exist

| Dependency | Required? | Evidence | In `packages/`? |
|---|---|---|---|
| Boost >= 1.74 | **Yes, REQUIRED** | `CGAL_SetupCGAL_CoreDependencies.cmake:51`, `CGAL_SetupBoost.cmake:17` | **No** — blocker |
| GMP | **Yes, essential** | `CMakeLists.txt:545` appends `GMP MPFR` to `CGAL_ESSENTIAL_3RD_PARTY_LIBRARIES` | Yes — `packages/gmp` |
| MPFR | **Yes, essential** | same line | Yes — `packages/mpfr` |
| Qt6 | No | `CMakeLists.txt:513`, install only under `COMPONENT CGAL_Qt6` (`:649-652`) | No — not needed |
| Eigen3, METIS, LEDA, OpenMesh, VTK, OpenCV, TBB, FLAME, IPE, RS3, Ceres, LASLIB, OSQP, pointmatcher | No, all optional | one `CGAL_*_support.cmake` each in `cmake/modules/`; all `find_package` calls with `QUIET`/`OPTIONAL` | No — not needed |

GMP is genuinely satisfiable: `packages/gmp` exists. It must be the prefix's,
not a bundled one — `CMakeLists.txt:755-758` would install a *bundled* GMP
from `auxiliary/gmp/`, but that directory ships only a `README` (11 entries
under `auxiliary/` in total, no `include/` or `lib/`), so the
`IS_DIRECTORY auxiliary/gmp/include AND IS_DIRECTORY auxiliary/gmp/lib` guard
is false and no bundled GMP is installed or used. `auxiliary/zlib/` does not
exist at all, so the `ZLIB_IN_AUXILIARY` branch at `:760-763` cannot fire.

## What a build would look like, once Boost exists

Useful for whoever picks this up, and it is why I am confident the rest is
routine: **CGAL 6 compiles nothing in a release build.** Across all 198
`CMakeLists.txt` files there is no `add_library` outside `demo/`, and the
single `add_executable` in the root (`CMakeLists.txt:1209`,
`check_headers_linked_twice`) sits inside `if(CGAL_BRANCH_BUILD)` (`:914`) ->
`if(CGAL_ENABLE_CHECK_HEADERS)` (`:921`), neither of which holds for a
release tarball. Examples/demos/tests/benchmarks all default off
(`CMakeLists.txt:843-848` passes `OFF` to `CGAL_add_subdirectories`), and
`add_subdirectory(doc)` at `:1233` cannot fire — the tarball has zero
entries under `doc/`. The install is headers (`CMakeLists.txt:728-743`),
`CGALConfig.cmake` + version files (`:765-769`), the cmake modules (`:752-753`)
and the `scripts/` helpers (`:745-750`).

Peak memory is therefore not a concern: nothing is compiled, so the 2 GB
ceiling in `topackage.md:106-108` does not apply.

## Verdict table

| System family | Verdict | Why |
|---|---|---|
| aarch64-android21 | WILL NOT BUILD | `find_package( Boost 1.74 REQUIRED )` fails identically on every system; no API-level factor is reached. |
| aarch64-android24 | WILL NOT BUILD | Same, system-independent blocker. |
| aarch64-android35 | WILL NOT BUILD | Same. |
| x86_64-android35 | WILL NOT BUILD | Same. |
| x86_64-mingw | WILL NOT BUILD | Same. |
| clang-native | WILL NOT BUILD | Same. |

The blocker is a missing package, not a toolchain property, so no system
family differs — which is the honest shape of this forecast rather than six
copies of the same guess.
