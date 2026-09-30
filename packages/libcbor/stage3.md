# libcbor 0.14.0 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libcbor
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libcbor@aarch64-android24' > /tmp/build-libcbor.sh
sh -n /tmp/build-libcbor.sh          # exit 0 — syntax gate passed
sh /tmp/build-libcbor.sh
```

## Stale-artifact cleanup

libcbor had **no** stale artifacts. Before the build:

```
$ ls nest/aarch64-android24/lib/libcbor* nest/aarch64-android24/lib/pkgconfig/cbor.pc nest/aarch64-android24/include/cbor.h
none
$ ls -a nest/aarch64-android24/.retrolunar-libcbor
ls: cannot access '.../.retrolunar-libcbor': No such file or directory
```

No stamp, and neither `libcbor.a`, `cbor.h` nor `cbor.pc` existed in the
prefix. The stamp delete was still run unconditionally, as procedure. The one
artifact below is mtime-checked at `Oct 1 03:10`, from this build.

## Outcome: **SUCCESS**

Real work in the log — 20 `Building C object` lines and one archive link:

```
[  4%] Building C object src/CMakeFiles/cbor.dir/cbor.c.o
[  9%] Building C object src/CMakeFiles/cbor.dir/allocators.c.o
[ 14%] Building C object src/CMakeFiles/cbor.dir/cbor/streaming.c.o
[ 19%] Building C object src/CMakeFiles/cbor.dir/cbor/internal/encoders.c.o
...
-- Configuring done (3.0s)
```

Install (the `.a` is the only library artifact; headers under `include/cbor/`
plus the `cbor.h` umbrella, one `.pc`, and the CMake package config):

```
-- Installing: .../out-sDxwg4/lib/libcbor.a
-- Installing: .../out-sDxwg4/include/cbor.h
-- Installing: .../out-sDxwg4/include/cbor/cbor_export.h
...
-- Installing: .../out-sDxwg4/lib/pkgconfig/libcbor.pc
-- Installing: .../out-sDxwg4/lib/cmake/libcbor/libcborConfig.cmake
-- Installing: .../out-sDxwg4/lib/cmake/libcbor/libcborConfigVersion.cmake
-- Installing: .../out-sDxwg4/lib/cmake/libcbor/libcborTargets.cmake
-- Installing: .../out-sDxwg4/lib/cmake/libcbor/libcborTargets-noconfig.cmake
```

`WITH_EXAMPLES=OFF` took: no example program was compiled or installed, and
`bin/` gained nothing.

## Artifact verification (real output)

The one command that proves it:

```
$ ls nest/aarch64-android24/lib/libcbor.a
nest/aarch64-android24/lib/libcbor.a
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls -la $PREFIX/lib/libcbor.a` | `-rw-r--r-- 1 si si 114862 Oct  1 03:10 nest/aarch64-android24/lib/libcbor.a` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libcbor.a \| head -3` | `libcbor.a(cbor.c.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libcbor.a \| grep ' T cbor_new'` | 18 hits, first `00000000000000d4 T cbor_new_ctrl`, last `0000000000000194 T cbor_new_int64` |
| pkg-config version | `pkg-config --modversion libcbor` | `0.14.0` |
| umbrella header | `test -f $PREFIX/include/cbor.h` | present |
| **no shared library** | `ls $PREFIX/lib/libcbor*.so*` | `no .so (correct)` |

Note on the pkg-config name: the brief's §4 table said to expect
`lib/pkgconfig/cbor.pc`; upstream actually installs **`libcbor.pc`**, and that
is the correct name — `pkg-config --modversion libcbor` answers. Recorded as a
correction to the forecast, not a build problem.

`-DCMAKE_C_STANDARD=99` did what the recipe says it does: upstream's "nodiscard"
probe would otherwise have flipped the whole build to `-std=c23`. No
`-std=c23` or compile diagnostic appears anywhere in the log, and the build is
clean with no warnings.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-libcbor.sh
skip libcbor@source (fresh)
skip libcbor@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made; `packages/libcbor/generic.lua` and
`source.lua` are committed unmodified.
