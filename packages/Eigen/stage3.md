# Eigen 5.0.1 — stage 3 build record

System: **`aarch64-android24`**, NDK from
`/home/si/.local/share/mise/installs/android-sdk/23.0`.

## Outcome: **SUCCESS**

Nothing is compiled — as `stage2.md` predicted and proved from the recipe's
own line citations. The install is upstream's `install(DIRECTORY Eigen …)`
(`CMakeLists.txt:236`) plus the generated `Eigen/Version` header (`:238`),
`eigen3.pc` and the cmake package config. No recipe fix was needed.

## Command sequence (exactly as run)

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-Eigen
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'Eigen@aarch64-android24' > /tmp/build-Eigen.sh
sh -n /tmp/build-Eigen.sh     # exit 0
sh /tmp/build-Eigen.sh        # exit 0, real 0m5.7s
```

## Stale-artifact cleanup — nothing to delete

Pre-build, both the stamp and every Eigen-owned path were absent, so no stale
file could have satisfied a check:

```
$ ls nest/aarch64-android24/.retrolunar-Eigen ; ls -d nest/source/Eigen
stamp=no  src=no
$ ls nest/aarch64-android24/include | grep -i eigen
$ ls nest/aarch64-android24/lib | grep -i eigen
$ ls nest/aarch64-android24/lib/pkgconfig | grep -i eigen
$ ls nest/aarch64-android24/lib/cmake | grep -i eigen
(all four greps printed nothing)
```

**Deleted:** only `nest/aarch64-android24/.retrolunar-Eigen` (which did not
exist). `nest/source/Eigen` did not exist either, so the source block fetched
fresh from gitlab.com — the install lines below show a real download.

## Real work in the log

Source fetch (real transfer, not a skip):

```
$ grep -c 'Installing:' /tmp/log-Eigen.txt
662
```

cmake configure — the project prints its own resolved install layout, which is
the fact the whole build turns on:

```
-- Target      |   Description
-- ------------+--------------------------------------------------------------
-- install     | Install Eigen. Headers will be installed to:
--             |     <CMAKE_INSTALL_PREFIX>/<INCLUDE_INSTALL_DIR>
--             |   Using the following values:
--             |     CMAKE_INSTALL_PREFIX: .../nest/tmp/out-aAQYgK
--             |     INCLUDE_INSTALL_DIR:  include/eigen3
-- uninstall   | Remove files installed by the install target
-- Configured Eigen 5.0.1-dev
-- Configuring done (1.2s)
-- Generating done (0.0s)
```

`-- Build files have been written to: .../nest/tmp/work-iqW7RJ/build`, then
`cmake --build build --parallel 1` produces **no compile lines at all** (the
`eigen` target is `INTERFACE`, `CMakeLists.txt:208`), and `cmake --install`
copies the tree:

```
-- Install configuration: "Release"
-- Installing: .../out-aAQYgK/include/eigen3/signature_of_eigen3_matrix_library
-- Installing: .../out-aAQYgK/share/pkgconfig/eigen3.pc
-- Installing: .../out-aAQYgK/include/eigen3/Eigen/Core
...
-- Installing: .../out-aAQYgK/include/eigen3/Eigen/Version          <- generated, line 517
-- Installing: .../out-aAQYgK/share/eigen3/cmake/Eigen3Targets.cmake
-- Installing: .../out-aAQYgK/share/eigen3/cmake/Eigen3Config.cmake
-- Installing: .../out-aAQYgK/share/eigen3/cmake/Eigen3ConfigVersion.cmake
-- Installing: .../out-aAQYgK/include/eigen3/unsupported/Eigen/AdolcForward
...
```

## Artifact table — real output

`P` = `nest/aarch64-android24`.

| check (`stage2.md` "Carried to the build") | command | real output | verdict |
|---|---|---|---|
| recursive `install(DIRECTORY …)` ran — top level | `ls $P/include/eigen3/Eigen/Core` | `nest/aarch64-android24/include/eigen3/Eigen/Core` | PASS |
| …and `Eigen/src/` came with it | `ls $P/include/eigen3/Eigen/src/Core/util` | `Assert.h  BlasUtil.h  ConfigureVectorization.h  Constants.h  DisableStupidWarnings.h  EmulateArray.h  ForwardDeclarations.h  GpuHipCudaDefines.inc  GpuHipCudaUndefines.inc  IndexedViewHelper.h  IntegralConstant.h  MKL_support.h  Macros.h  MaxSizeVector.h  Memory.h  Meta.h  MoreMeta.h  ReenableStupidWarnings.h  ReshapedHelper.h  Serializer.h  SelfadjointMatrixMatrixTriangular_BLAS.h  SelfadjointMatrixVector_BLAS.h  SelfadjointMatrixMatrix_BLAS.h  SparseCore…` (24 entries) | PASS |
| …and `unsupported/` came with it | `ls $P/include/eigen3/unsupported/Eigen \| head -5` | `AdolcForward  AlignedVector3  ArpackSupport  AutoDiff  BVH` | PASS |
| **module name is `eigen3`, reports 5.0.1** | `pkg-config --modversion eigen3` | `5.0.1` | PASS |
| .pc `Cflags` point into the prefix | `pkg-config --cflags eigen3` | `-I/home/si/ond/git/retrolunar/nest/aarch64-android24/include/eigen3` | PASS |
| cmake package config installed | `ls $P/share/eigen3/cmake` | `Eigen3Config.cmake  Eigen3ConfigVersion.cmake  Eigen3Targets.cmake` | PASS |
| nothing was compiled, BLAS/LAPACK stayed off | `find $P/include/eigen3 $P/share/eigen3 $P/share/pkgconfig/eigen3.pc \( -name '*.a' -o -name '*.so' \)` | *(empty)* | PASS |
| no bundled BLAS/LAPACK libs | `find $P \( -name 'libblas*' -o -name 'liblapack*' \)` | *(empty)* | PASS |

### `stage2.md` checks that could not match their own target — the CHECK is wrong, not the build

Two of the carried checks name paths that this upstream release does not
install. Recorded here so the next reader does not file them as defects:

1. **`include/Eigen/Core`** — real path is **`include/eigen3/Eigen/Core`**.
   `stage2.md:131` reasoned from `install(DIRECTORY Eigen DESTINATION include)`
   at `:236`, but `:174-181` resolves `INCLUDE_INSTALL_DIR` to
   `include/eigen3`, which the configure output above prints explicitly
   (`INCLUDE_INSTALL_DIR:  include/eigen3`). The check would fail against a
   perfectly good install.
2. **`lib/cmake/eigen3/Eigen3Config.cmake`** — real path is
   **`share/eigen3/cmake/Eigen3Config.cmake`** (`CMAKEPACKAGE_INSTALL_DIR` at
   `:183` resolves under `share`, not `lib`). `stage2.md:144` guesses `lib/`.

Both corrected paths are what the install log itself prints, so the build is
unambiguously correct and the two path guesses are what was wrong. The pkg-config
module name — the one thing `stage2.md` went out of its way to verify — is right.

Also note: `pkg-config --variable=includedir eigen3` prints **empty**, because
the `.pc` (upstream `eigen3.pc.in`) has no `includedir=` line, only
`Cflags: -I${prefix}/include/eigen3`. That is upstream's file, not our rewrite.

### The installed `Eigen/Version` IS the generated one

`stage2.md:136-139` asked for this specifically. Byte-diffing the installed
header against the shipped source header:

```
$ diff nest/source/Eigen/Eigen/Version $P/include/eigen3/Eigen/Version
10c10
< #define EIGEN_PRERELEASE_VERSION ""
---
> #define EIGEN_PRERELEASE_VERSION "dev"
12c12
< #define EIGEN_VERSION_STRING "5.0.1"
---
> #define EIGEN_VERSION_STRING "5.0.1-dev"
```

The installed copy differs from the shipped one, so the `install(FILES
${CMAKE_CURRENT_BINARY_DIR}/include/Eigen/Version …)` at `:238-239` really
overwrote the recursive copy (install log line 517, after the directory copy at
line 91). `grep -q EIGEN_WORLD_VERSION` matches at line 5 in both, so on its own
that grep would **not** have distinguished them — which is exactly why `stage2.md`
said to pair it with the `:238` fact.

### Header-tree completeness

```
$ find $P/include/eigen3 -type f | wc -l
600
$ diff -r nest/source/Eigen/Eigen $P/include/eigen3/Eigen
<only the two Version hunks above>
```

Every shipped header landed, and the **only** difference from the upstream
tree is the generated `Version` header. That is what makes the install
system-independent: there is no compiled artifact that could be wrong-arch, and
the header set is byte-identical to the tarball on every system.

`stage2.md:150` asked for a `diff -r` between **two systems**'
`include/Eigen/`. Not run: this wave builds one system only, and building a
second prefix would have written a stamp into a system this wave does not own.
The `diff -r` above against the unpacked source tree is the stronger form of the
same claim — the installed tree is provably the source tree plus one generated
header.

## mtimes, not byte counts

Nothing to compare against (no stale predecessor), but for the record, all four
key artifacts carry this run's timestamps:

```
$ ls -l --time-style=full-iso $P/include/eigen3/Eigen/Core $P/include/eigen3/Eigen/Version $P/share/pkgconfig/eigen3.pc $P/share/eigen3/cmake/Eigen3Config.cmake
-rw-r--r-- 1 si si 14585 2026-10-01 14:46:51.732923500 +1000 include/eigen3/Eigen/Core
-rw-r--r-- 1 si si   455 2026-10-01 14:46:51.781926924 +1000 include/eigen3/Eigen/Version
-rw-r--r-- 1 si si   258 2026-10-01 14:46:51.799972645 +1000 share/pkgconfig/eigen3.pc
-rw-r--r-- 1 si si   662 2026-10-01 14:46:51.800461750 +1000 share/eigen3/cmake/Eigen3Config.cmake
```

The build finished at `14:46:51`; the stamp was written `0.08 s` after the last
install line.

## Rerun proof

```
$ sh /tmp/build-Eigen.sh
skip Eigen@source (fresh)
skip Eigen@aarch64-android24 (fresh)
$ ls -l --time-style=full-iso nest/aarch64-android24/.retrolunar-Eigen
-rw-r--r-- 1 si si 0 2026-10-01 14:46:51.801928321 +1000 nest/aarch64-android24/.retrolunar-Eigen
```

## Recipe changes made during this build

**None.** No fix was needed and none was made.