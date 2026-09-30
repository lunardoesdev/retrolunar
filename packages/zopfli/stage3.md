# zopfli 1.0.3 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-zopfli
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'zopfli@aarch64-android24' > /tmp/build-zopfli.sh
sh -n /tmp/build-zopfli.sh          # exit 0 — syntax gate passed
sh /tmp/build-zopfli.sh
```

## Stale-artifact cleanup

zopfli had **no** stale artifacts. Before the build:

```
$ ls nest/aarch64-android24/lib/libzopfli* nest/aarch64-android24/lib/libzopflipng* \
      nest/aarch64-android24/include/zopfli.h nest/aarch64-android24/bin/zopfli
none
$ ls -a nest/aarch64-android24/.retrolunar-zopfli
ls: cannot access '.../.retrolunar-zopfli': No such file or directory
```

No stamp and no artifacts. The stamp delete was still run unconditionally.
All four artifacts below are mtime-checked at `Oct 1 03:12`, from this build.

## Outcome: **SUCCESS**

Real work in the log — 11 `Building C object` / `Building CXX object` lines
plus four link steps:

```
[ 71%] Building CXX object CMakeFiles/libzopflipng.dir/src/zopflipng/lodepng/lodepng.cpp.o
[ 76%] Building CXX object CMakeFiles/libzopflipng.dir/src/zopflipng/lodepng/lodepng_util.cpp.o
[ 80%] Linking CXX static library libzopflipng.a
[ 80%] Built target libzopflipng
[ 85%] Building C object CMakeFiles/zopfli.dir/src/zopfli/zopfli_bin.c.o
[ 90%] Linking C executable zopfli
[ 90%] Built target zopfli
[ 95%] Building CXX object CMakeFiles/zopflipng.dir/src/zopflipng/zopflipng_bin.cc.o
[100%] Linking CXX executable zopflipng
[100%] Built target zopflipng
-- Install configuration: "Release"
```

Install:

```
-- Installing: .../out-0r0j9d/lib/libzopfli.a
-- Installing: .../out-0r0j9d/lib/libzopflipng.a
-- Installing: .../out-0r0j9d/bin/zopfli
-- Installing: .../out-0r0j9d/bin/zopflipng
-- Installing: .../out-0r0j9d/include/zopfli.h
-- Installing: .../out-0r0j9d/include/zopflipng_lib.h
-- Installing: .../out-0r0j9d/lib/cmake/Zopfli/ZopfliConfig.cmake
-- Installing: .../out-0r0j9d/lib/cmake/Zopfli/ZopfliConfig-release.cmake
-- Installing: .../out-0r0j9d/lib/cmake/Zopfli/ZopfliConfigVersion.cmake
```

`-DZOPFLI_BUILD_SHARED=OFF` took: both libraries are `.a`, and no `.so`
was produced.

## No target binary was executed

The preflight flagged `bin/zopfli` and `bin/zopflipng` as unconditional target
executables (`CMakeLists.txt:136`/`:145`, no upstream switch) whose presence is
expected and whose **execution is forbidden**. They were verified statically
only. `file` output, quoted:

```
nest/aarch64-android24/bin/zopfli: ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV), dynamically linked, interpreter /system/bin/linker64, for Android 24, built by NDK r28c (13676358), not stripped
```

An `aarch64` Android executable cannot run on this x86-64 host. No QEMU, no
emulator, no `binfmt_misc` was used or installed.

## Artifact verification (real output)

The one command that proves it — `test -x $PREFIX/bin/zopfli`:

```
$ test -x nest/aarch64-android24/bin/zopfli
$ echo $?
PASS
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| both binaries, this build | `ls -la $PREFIX/bin/zopfli $PREFIX/bin/zopflipng` | `-rwxr-xr-x 1 si si  68224 Oct  1 03:12 .../bin/zopfli`, `-rwxr-xr-x 1 si si 319912 Oct  1 03:12 .../bin/zopflipng` |
| both libraries, this build | `ls -la $PREFIX/lib/libzopfli.a $PREFIX/lib/libzopflipng.a` | `-rw-r--r-- 1 si si  91516 Oct  1 03:12 .../libzopfli.a`, `-rw-r--r-- 1 si si 307156 Oct  1 03:12 .../libzopflipng.a` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libzopfli.a \| head -3` | `libzopfli.a(blocksplitter.c.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libzopfli.a \| grep ' T ZopfliDeflate'` | `0000000000000840 T ZopfliDeflatePart`, `0000000000003cc4 T ZopfliDeflate` |
| headers | `ls $PREFIX/include/zopfli.h $PREFIX/include/zopflipng_lib.h` | both present |
| CMake package config | `ls $PREFIX/lib/cmake/Zopfli/` | `ZopfliConfig.cmake`, `ZopfliConfig-release.cmake`, `ZopfliConfigVersion.cmake` |
| **no pkg-config file** | `ls $PREFIX/lib/pkgconfig/zopfli.pc` | `no zopfli.pc (correct)` |

The absence of a `.pc` is upstream's own layout, not a recipe defect — the
preflight said so and the build confirms it.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-zopfli.sh
skip zopfli@source (fresh)
skip zopfli@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made; `packages/zopfli/generic.lua` and `source.lua`
are committed unmodified.
