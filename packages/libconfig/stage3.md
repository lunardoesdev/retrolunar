# libconfig 1.8.2 — stage 3 build record

System built for: **`aarch64-android24`**.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libconfig
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libconfig@aarch64-android24' > /tmp/build-libconfig.sh
sh -n /tmp/build-libconfig.sh          # exit 0 — syntax gate passed
sh /tmp/build-libconfig.sh
```

## Stale-artifact cleanup

libconfig had **no** stale artifacts to remove. Before the build:

```
$ ls -la nest/aarch64-android24/lib/libconfig*
(no output)
$ ls -la nest/aarch64-android24/include/libconfig*
(no output)
$ ls nest/aarch64-android24/lib/pkgconfig/libconfig*
(no output)
$ ls -a nest/aarch64-android24/.retrolunar-libconfig
ls: cannot access '.../.retrolunar-libconfig': No such file or directory
```

There was no stamp, and neither `libconfig.a`, `libconfig++.a`, `libconfig.h`,
`libconfig.h++` nor `libconfig.pc` existed in the prefix — this package was
never built by the discarded run. The stamp delete above was still run
unconditionally, as procedure. Every artifact below is also mtime-checked:
all are `Oct 1 03:08`, from this build.

## Outcome: **SUCCESS**

Real work in the log (not a skip — 20 compile/link lines):

```
[  5%] Building C object lib/CMakeFiles/config.dir/grammar.c.o
[ 10%] Building C object lib/CMakeFiles/config.dir/libconfig.c.o
...
[ 47%] Linking C static library ../out/libconfig.a
[ 47%] Built target config
[ 52%] Building C object lib/CMakeFiles/config++.dir/grammar.c.o
...
[ 94%] Building CXX object lib/CMakeFiles/config++.dir/libconfigcpp.cc.o
[100%] Linking CXX static library ../out/libconfig++.a
[100%] Built target config++
```

Configure picked the NDK clang:

```
-- The C compiler identification is Clang 19.0.1
-- The CXX compiler identification is Clang 19.0.1
-- Set version info for config: VERSION=15.0.0, SOVERSION=15
-- Set version info for config++: VERSION=15.0.0, SOVERSION=15
-- Configuring done (1.4s)
-- Generating done (0.0s)
```

Install:

```
-- Install configuration: ""
-- Installing: .../out-AO7HUz/lib/libconfig.a
-- Installing: .../out-AO7HUz/include/libconfig.h
-- Installing: .../out-AO7HUz/lib/libconfig++.a
-- Installing: .../out-AO7HUz/include/libconfig.h++
-- Installing: .../out-AO7HUz/include/libconfig.hh
-- Installing: .../out-AO7HUz/lib/cmake/libconfig/libconfigConfig.cmake
-- Installing: .../out-AO7HUz/lib/cmake/libconfig/libconfigConfig-noconfig.cmake
-- Installing: .../out-AO7HUz/lib/cmake/libconfig/libconfigConfigVersion.cmake
-- Installing: .../out-AO7HUz/lib/pkgconfig/libconfig.pc
-- Installing: .../out-AO7HUz/lib/pkgconfig/libconfig++.pc
```

## Artifact verification (real output)

The one command that proves it — `stage2.md` "Carried to the build":

```
$ ls nest/aarch64-android24/lib/libconfig.a
nest/aarch64-android24/lib/libconfig.a
```

Corroboration, each with its proof command:

| expectation | command | real output |
| --- | --- | --- |
| static archive | `ls -la $PREFIX/lib/libconfig.a` | `-rw-r--r-- 1 si si 77596 Oct  1 03:08 nest/aarch64-android24/lib/libconfig.a` |
| target architecture | `llvm-objdump -f $PREFIX/lib/libconfig.a \| head -4` | `libconfig.a(grammar.c.o):	file format elf64-littleaarch64` / `architecture: aarch64` |
| real code inside | `llvm-nm --defined-only $PREFIX/lib/libconfig.a \| grep ' T config_init'` | `0000000000000658 T config_init` |
| pkg-config version | `pkg-config --modversion libconfig` | `1.8.2` |
| C++ binding pkg-config | `pkg-config --modversion libconfig++` | `1.8.2` |
| C++ header | `test -f $PREFIX/include/libconfig.h++` | present (`nest/aarch64-android24/include/libconfig.h++`) |
| **no shared library** | `ls $PREFIX/lib/libconfig*.so*` | `none (correct)` |

Both archives are present, as `stage2.md` predicted: `libconfig.a` and
`libconfig++.a`, each with its own `.pc` (`libconfig.pc`, `libconfig++.pc`) —
the `BUILD_CXX`-on note in the preflight §3 was correct, expecting exactly one
`.a` would have been the wrong check.

No host programs were installed: `bin/` contains nothing from this build.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-libconfig.sh
skip libconfig@source (fresh)
skip libconfig@aarch64-android24 (fresh)
```

## System-level findings

None. No recipe change was made. `packages/libconfig/generic.lua`,
`source.lua` are committed unmodified.
