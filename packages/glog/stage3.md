# glog 0.7.1 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS** (with a recorded system-level consumer-link blocker)

glog builds cleanly on this system. It carries one unresolved symbol,
`__android_log_write`, which is **not** a build failure — it is the
consumer-link blocker recorded at the end. This is the same defect
abseil-cpp has, and the same one-line system fix clears both.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-glog
rm -f nest/source/.retrolunar-glog && rm -rf nest/source/glog
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'glog@aarch64-android24' > /tmp/build-glog.sh
sh -n /tmp/build-glog.sh          # exit 0 — syntax gate passed
sh /tmp/build-glog.sh
```

## Stale-artifact cleanup — this package HAD stale artifacts

glog was one of the seven with a stamp left by the discarded run. Pre-build
inspection, all dated `Sep 30 23:36`/`23:37`:

```
$ ls -la nest/aarch64-android24/lib/libglog*
-rw-r--r-- 1 si si 560012 Sep 30 23:37 nest/aarch64-android24/lib/libglog.a
$ ls nest/aarch64-android24/lib/pkgconfig/libglog.pc
nest/aarch64-android24/lib/pkgconfig/libglog.pc
$ ls -d nest/aarch64-android24/include/glog nest/aarch64-android24/lib/cmake/glog
nest/aarch64-android24/include/glog
nest/aarch64-android24/lib/cmake/glog
$ ls -a nest/aarch64-android24/.retrolunar-glog
nest/aarch64-android24/.retrolunar-glog
```

**Deleted:** the build stamp, `lib/libglog.a`, `lib/pkgconfig/libglog.pc`, the
whole `include/glog/` tree, the whole `lib/cmake/glog/` tree. Post-delete
check: `clean`.

**The source tree was deleted too:**

```
$ ls -ld --time-style=full-iso nest/source/glog nest/source/.retrolunar-glog
-rw-r--r-- 1 si si  0 2026-09-30 23:36:43 ...  nest/source/.retrolunar-glog
drwxr-xr-x 1 si si 356 2026-09-30 23:36:43 ...  nest/source/glog
```

Both predate the current recipe and came from the discarded run. Version and
URL do match (0.7.1), so this is not a version-drift cleanup — it is removing a
tree no current recipe produced. The source block re-fetched from GitHub during
this run.

**Honest note on the size coincidence.** The rebuilt `libglog.a` is *also*
560012 bytes, the same as the deleted one. Byte count would have been a false
pass. What proves this build is real: the mtime (`Sep 30 23:37` →
`Oct 1 04:15`), the compile/link lines below, a fresh source download, and the
`skip` proof at the end.

## Real work in the log

```
[ 91%] Building CXX object CMakeFiles/glog.dir/CMakeFiles/glog.cc.o
[100%] Linking CXX static library libglog.a
[100%] Built target glog
-- Install configuration: ""
-- Installing: .../out-JA6Ul7/lib/libglog.a
-- Installing: .../out-JA6Ul7/include/glog/export.h
-- Installing: .../out-JA6Ul7/include/glog/log_severity.h
-- Installing: .../out-JA6Ul7/include/glog/logging.h
-- Installing: .../out-JA6Ul7/include/glog/platform.h
-- Installing: .../out-JA6Ul7/include/glog/raw_logging.h
-- Installing: .../out-JA6Ul7/include/glog/stl_logging.h
-- Installing: .../out-JA6Ul7/include/glog/types.h
-- Installing: .../out-JA6Ul7/include/glog/flags.h
-- Installing: .../out-JA6Ul7/include/glog/vlog_is_on.h
-- Installing: .../out-JA6Ul7/lib/pkgconfig/libglog.pc
-- Installing: .../out-JA6Ul7/lib/cmake/glog/glog-modules.cmake
-- Installing: .../out-JA6Ul7/lib/cmake/glog/glog-config.cmake
-- Installing: .../out-JA6Ul7/lib/cmake/glog/glog-config-version.cmake
-- Installing: .../out-JA6Ul7/lib/cmake/glog/glog-targets.cmake
-- Installing: .../out-JA6Ul7/lib/cmake/glog/glog-targets-noconfig.cmake
```

`BUILD_TESTING=OFF` took: **nothing** was written to `bin/`, and no
`*_unittest` exists anywhere in the prefix. `include/glog/export.h` is
present, which is the proof that `generate_export_header` ran — it is
generated, not shipped.

## The `execinfo` behaviour difference, observed

`stage2.md` predicted that on `aarch64-android21`/`24` glog loses the
`HAVE_EXECINFO_BACKTRACE` path because Bionic's `execinfo.h` carries
`__INTRODUCED_IN(33)` on `backtrace` and `backtrace_symbols`, while
`aarch64-android35` keeps it. Confirmed on this system:

```
-- Looking for backtrace
-- Looking for backtrace - not found
-- Looking for backtrace_symbols
-- Looking for backtrace_symbols - not found
```

So this build takes glog's generic backtrace path. **This is a behaviour
difference, not a failure** — glog builds either way, and the artefact is
complete. Recorded so nobody reads the two `-- not found` lines as a broken
build.

## Artifact verification (real output)

The one command that proves it —
`llvm-objdump -f $PREFIX/lib/libglog.a | head -3`:

```
$ llvm-objdump -f nest/aarch64-android24/lib/libglog.a | head -3

nest/aarch64-android24/lib/libglog.a(glog.cc.o):	file format elf64-littleaarch64
architecture: aarch64
```

Corroboration:

| expectation | command | real output |
| --- | --- | --- |
| static archive, this build | `ls -la $PREFIX/lib/libglog.a` | `-rw-r--r-- 1 si si 560012 Oct  1 04:15 nest/aarch64-android24/lib/libglog.a` |
| **generated** `export.h` | `ls -la $PREFIX/include/glog/export.h` | `-rw-r--r-- 1 si si 924 Oct  1 04:15 ...` |
| `logging.h` | `ls -la $PREFIX/include/glog/logging.h` | `-rw-r--r-- 1 si si 73016 Oct  1 04:15 ...` |
| pkg-config version | `pkg-config --modversion libglog` | `0.7.1` |
| CMake package config | `ls $PREFIX/lib/cmake/glog/` | `glog-config.cmake`, `glog-config-version.cmake`, `glog-modules.cmake`, `glog-targets.cmake`, `glog-targets-noconfig.cmake` |
| **no `bin/` output** | `find $PREFIX/bin -name '*unittest*'` and `find $PREFIX/bin -newermt '2026-10-01 04:30'` | both empty |

## Rerun proves the new stamp is real

```
$ sh /tmp/build-glog.sh
skip glog@source (fresh)
skip glog@aarch64-android24 (fresh)
```

## System-level findings

### BLOCKER (recorded, not fixed): the Android systems do not provide `-llog`

**This is a defect in `packages/*android*/generic.lua`, not in this recipe.**
The recipe must not be edited to work around it and was not. It is the same
defect abseil-cpp has, and **one system change repairs both.**

The evidence, measured on this build:

```
$ llvm-nm nest/aarch64-android24/lib/libglog.a | grep -c __android_log_write
1
$ llvm-nm nest/aarch64-android24/lib/libglog.a | grep __android_log_write
                 U __android_log_write
```

Exactly one undefined reference. `src/glog/platform.h:42-45` turns the
NDK wrapper's `__ANDROID__` into `GLOG_OS_ANDROID`, and
`src/utilities.cc:95-103` calls `__android_log_write` unconditionally inside
`AlsoErrorWrite`, which is on ordinary logging paths — not an optional sink.

And the `.pc` proves the gap is not closed downstream either:

```
$ grep -E 'Libs' nest/aarch64-android24/lib/pkgconfig/libglog.pc
Libs: -L${libdir} -lglog
Libs.private: -pthread
```

**No `-llog` in `Libs.private`.** glog knows the dependency exists —
`CMakeLists.txt:463-466` has `target_link_libraries(glog PRIVATE log)` and
sets `-llog` in `glog_libraries_options_for_static_linking`, both inside
`if (ANDROID)`. `ANDROID` is a CMake variable that cmake only sets when
`CMAKE_SYSTEM_NAME` is `Android`, and our toolchain file deliberately keeps
`set(CMAKE_SYSTEM_NAME Linux)`
(`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`).
Neither line ever runs.

**Why this build still succeeds.** `BUILD_SHARED_LIBS=OFF` makes glog a static
archive and `BUILD_TESTING=OFF` removes every executable, so there is no link
step. A static archive is not linked; `cmake --install` copies the `.a` and
the `.pc` without complaint.

**What breaks.** Any consumer linking `libglog.a` on Android gets
`undefined reference to __android_log_write`, and so does a
`find_package(glog)` consumer, since the exported target inherits the empty
link option.

**Where the fix belongs.** The `LDFLAGS` section of each
`packages/*android*/generic.lua`, next to the existing `-lm`
(`packages/aarch64-android24/generic.lua:79`), one `-llog` per file, commented
with the reason. That is **56 system files** — 14 each of `aarch64-*`,
`armv7a-*`, `i686-*`, `x86_64-*`. `x86_64-mingw` and `clang-native` need
nothing. `AGENTS.md` forbids a recipe from `export`ing `LDFLAGS`, and `liblog`
is a Bionic platform library rather than a prefix package, so it belongs in a
system file and nowhere else. `liblog.so` is present in the NDK sysroot at
every API level and `__android_log_write` is declared from API 21 up, so
there is no API-level caveat on the fix.

### Scope, so this record cannot be misread

A **consumer-link** blocker, not a build blocker. glog built successfully; its
archive and its `.pc` are correct and usable as artifacts.

### No recipe change was made

`packages/glog/generic.lua` and `source.lua` are committed unmodified.
