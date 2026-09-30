# meshoptimizer 1.3 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-meshoptimizer
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'meshoptimizer@aarch64-android24' > /tmp/build-meshoptimizer.sh
sh -n /tmp/build-meshoptimizer.sh          # exit 0 — syntax gate passed
sh /tmp/build-meshoptimizer.sh
```

## Stale-artifact cleanup

meshoptimizer had **no** stale artifacts and no stamp:

```
$ ls nest/aarch64-android24/lib/libmeshoptimizer* \
      nest/aarch64-android24/include/meshoptimizer.h \
      nest/aarch64-android24/lib/pkgconfig/meshoptimizer.pc \
      nest/aarch64-android24/bin/gltfpack
none
$ ls -a nest/aarch64-android24/.retrolunar-meshoptimizer
ls: cannot access '.../.retrolunar-meshoptimizer': No such file or directory
```

The stamp delete and the `rm -rf` of the four artifact paths were still run
unconditionally, as procedure. The one artifact below is mtime-checked at
`Oct 1 03:20`, from this build.

## Outcome: **SUCCESS**

Real work in the log — 19 `Building CXX object` lines and one archive link:

```
[ 50%] Building CXX object CMakeFiles/meshoptimizer.dir/src/quantization.cpp.o
[ 54%] Building CXX object CMakeFiles/meshoptimizer.dir/src/rasterizer.cpp.o
[ 59%] Building CXX object CMakeFiles/meshoptimizer.dir/src/remesher.cpp.o
...
[ 95%] Building CXX object CMakeFiles/meshoptimizer.dir/src/vfetchoptimizer.cpp.o
[100%] Linking CXX static library libmeshoptimizer.a
[100%] Built target meshoptimizer
```

Install:

```
-- Installing: .../out-Y47yXX/lib/libmeshoptimizer.a
-- Installing: .../out-Y47yXX/include/meshoptimizer.h
-- Installing: .../out-Y47yXX/lib/cmake/meshoptimizer/meshoptimizerTargets.cmake
-- Installing: .../out-Y47yXX/lib/cmake/meshoptimizer/meshoptimizerTargets-noconfig.cmake
-- Installing: .../out-Y47yXX/lib/cmake/meshoptimizer/meshoptimizerConfig.cmake
-- Installing: .../out-Y47yXX/lib/cmake/meshoptimizer/meshoptimizerConfigVersion.cmake
```

`-DMESHOPT_INSTALL=ON` took — the preflight's silent-success hazard (upstream
defaults installation off, and without it the build "succeeds" and installs
nothing) did not happen: four files were installed.

## Artifact verification (real output)

The one command that proves it — `test ! -e $PREFIX/bin/gltfpack`:

```
$ test ! -e nest/aarch64-android24/bin/gltfpack
$ echo $?
0
```

So `-DMESHOPT_BUILD_GLTFPACK=OFF` took and no host program was installed.
`$PREFIX/bin/` gained nothing from this build — its newest entries are all
`Sep 30 20:05` (`zstd`, `zstdcat`, …), i.e. from an earlier package.

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls $PREFIX/lib/libmeshoptimizer.*` | `nest/aarch64-android24/lib/libmeshoptimizer.a` |
| size and mtime | `ls -la $PREFIX/lib/libmeshoptimizer.a` | `-rw-r--r-- 1 si si 361748 Oct  1 03:20 ...` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libmeshoptimizer.a \| head -3` | `libmeshoptimizer.a(allocator.cpp.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libmeshoptimizer.a \| grep ' T meshopt_simplify'` | `0000000000006824 T meshopt_simplifyPrune`, `0000000000005a28 T meshopt_simplify`, `0000000000006bdc T meshopt_simplifyPoints` |
| header | `test -f $PREFIX/include/meshoptimizer.h` | present |
| CMake package config | `lib/cmake/meshoptimizer/meshoptimizerConfig.cmake` | installed (log lines above) |

### One correction to the forecast

`stage2.md` predicted `$PREFIX/lib/pkgconfig/meshoptimizer.pc` checked with
`pkg-config --modversion meshoptimizer`. **Upstream meshopt 1.3 ships no
pkg-config file at all** — verified against the unpacked tree, not assumed:

```
$ find nest/source/meshoptimizer -name '*.pc*'
(no output)
$ grep -c 'pkg' nest/source/meshoptimizer/CMakeLists.txt
0
```

The complete set of `install(` rules upstream
(`nest/source/meshoptimizer/CMakeLists.txt:186-222`) is the target, the
header, the export set, an optional PDB file (Windows only), and the
`MESHOPT_INSTALL` doc block. None of them writes a `.pc`. Verified on the
built prefix:

```
$ ls nest/aarch64-android24/lib/pkgconfig/meshoptimizer.pc
NO meshoptimizer.pc
```

**No `.pc` is correct** — a stage2 forecast error, not a recipe defect, so no
recipe was changed.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-meshoptimizer.sh
skip meshoptimizer@source (fresh)
skip meshoptimizer@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made; `packages/meshoptimizer/generic.lua` and
`source.lua` are committed unmodified.
