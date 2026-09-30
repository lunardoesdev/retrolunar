# abseil-cpp 20260817.0 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **SUCCESS** (with a recorded system-level consumer-link blocker)

abseil-cpp builds cleanly on this system. It carries one unresolved symbol,
`__android_log_write`, which is **not** a build failure — see "System-level
findings" below, where the missing `-llog` is recorded as a blocker affecting
every Android system.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-abseil-cpp
rm -f nest/source/.retrolunar-abseil-cpp && rm -rf nest/source/abseil-cpp
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'abseil-cpp@aarch64-android24' > /tmp/build-abseil-cpp.sh
sh -n /tmp/build-abseil-cpp.sh          # exit 0 — syntax gate passed
sh /tmp/build-abseil-cpp.sh
```

## Stale-artifact cleanup — this package had the MOST stale artifacts

This is the package the whole stale-artifact warning was about. Pre-build
inspection, all dated `Sep 30 23:36` — i.e. from the **discarded** run whose
recipes no longer exist:

```
$ ls nest/aarch64-android24/lib/libabsl_*.a | wc -l
94
$ ls -la nest/aarch64-android24/lib/libabsl_base.a \
         nest/aarch64-android24/lib/libabsl_log_internal_log_sink_set.a
-rw-r--r-- 1 si si 34042 Sep 30 23:36 .../lib/libabsl_base.a
-rw-r--r-- 1 si si 28680 Sep 30 23:36 .../lib/libabsl_log_internal_log_sink_set.a
$ ls nest/aarch64-android24/lib/pkgconfig/absl_*.pc | wc -l
216
$ ls -d nest/aarch64-android24/include/absl nest/aarch64-android24/lib/cmake/absl
nest/aarch64-android24/include/absl
nest/aarch64-android24/lib/cmake/absl
$ ls -a nest/aarch64-android24/.retrolunar-abseil-cpp
nest/aarch64-android24/.retrolunar-abseil-cpp
```

**Deleted:** the build stamp, all **94** `lib/libabsl_*.a`, all **216**
`lib/pkgconfig/absl_*.pc`, the whole `include/absl/` tree, and the whole
`lib/cmake/absl/` tree. Post-delete check: `no libabsl_* left`,
`no include/absl left`.

**The source tree was deleted too**, on purpose:

```
$ ls -ld --time-style=full-iso nest/source/abseil-cpp nest/source/.retrolunar-abseil-cpp \
         packages/abseil-cpp/source.lua packages/abseil-cpp/generic.lua
-rw-r--r-- 1 si si    0 2026-09-30 23:30:37 ...  nest/source/.retrolunar-abseil-cpp
drwxr-xr-x 1 si si  346 2026-09-30 23:30:37 ...  nest/source/abseil-cpp
-rw-r--r-- 1 si si 1212 2026-10-01 01:00:20 ...  packages/abseil-cpp/generic.lua
-rw-r--r-- 1 si si  447 2026-10-01 01:00:03 ...  packages/abseil-cpp/source.lua
```

The tree and its stamp predate the recipe by more than an hour, and both came
from the discarded run. Version and URL do match
(`project(absl LANGUAGES CXX VERSION 20260817)`), so this is not a
version-drift cleanup — it is removing a tree no current recipe produced. The
source block re-fetched from GitHub during this run as a result.

**Honest note on the size coincidence.** The rebuilt
`libabsl_base.a` is *also* 34042 bytes, the same as the deleted one. As
established above, byte count would have been a false pass here. What proves
this build is real: the mtime (`Sep 30 23:36` → `Oct 1 04:11`), 159
`Building CXX object` lines, a fresh source download, and the `skip` proof
below.

## The archive count: 94 is real, and stage2's estimate was wrong

```
$ ls nest/aarch64-android24/lib/libabsl_*.a | wc -l
94
$ ls nest/aarch64-android24/lib/pkgconfig/absl_*.pc | wc -l
216
```

This build produced **exactly 94** archives — the same number
`topackage.md:163` claimed and the same number the discarded run left in the
nest. `stage2.md` estimated "on the order of 250 `absl_cc_library` calls, of
which roughly 180 have an `SRCS` list and would produce an archive" and said
94 was "unsupported and almost certainly wrong". **It was wrong, and the
measurement beats the parse.** The likely reason the source-parse estimate was
too high is that a large share of `absl_cc_library` calls are test targets
gated behind `ABSL_BUILD_TESTING`, which this recipe sets `OFF` — the parse
counted what exists in the source, the build counts what is built.

`topackage.md:163` should keep its `[x]` and its "94" now that a committed
recipe has produced it, but it must add the consumer-link caveat `stage2.md`
asked for, and it should stop claiming a `[x]` for a line that was written
before any recipe existed.

## Real work in the log

```
-- Configuring done (8.8s)
-- Generating done (3.7s)
```

followed by **159** `Building CXX object` lines and one `libabsl_<module>.a`
link per module. Not a skip, not an empty block.

## The GoogleTest hazard did not fire

Preflight rank 2 named `ABSL_BUILD_TESTING=OFF` failing to take, which would
send the build to `CMake/Googletest/DownloadGTest.cmake` — a network fetch
plus a host-compiled GoogleTest in the middle of a cross build. Verified by
absence, which is the only way this hazard shows up:

```
$ grep -niE 'googletest|download|FetchContent' /tmp/build-abseil-cpp.log
(no output)
```

```
$ ls nest/aarch64-android24/bin/*_test nest/aarch64-android24/bin/absl_*
none (correct)
$ find nest/aarch64-android24/bin -newermt '2026-10-01 04:00'
(no output)
```

`bin/` holds `pcre2test`, `runtest`, `test` — all from other packages,
all older than this build. Nothing in `bin/` was written by abseil.

## Artifact verification (real output)

The one command that proves the *system-level* item —
`llvm-nm $PREFIX/lib/libabsl_log_internal_log_sink_set.a | grep __android_log_write`:

```
$ llvm-nm nest/aarch64-android24/lib/libabsl_log_internal_log_sink_set.a | grep __android_log_write
                 U __android_log_write
```

**Exactly one `U`, no other lines.** That is the proof the `AndroidLogSink`
class *is* compiled in — and therefore the proof of the blocker below.

Architecture, from `llvm-objdump -f`:

```
$ llvm-objdump -f nest/aarch64-android24/lib/libabsl_base.a | head -3

nest/aarch64-android24/lib/libabsl_base.a(casts.cc.o):	file format elf64-littleaarch64
architecture: aarch64
```

The rest:

| expectation | command | real output |
| --- | --- | --- |
| **generated** `options.h` proves the ABI configure step ran | `ls -la $PREFIX/include/absl/base/options.h` | `-rw-r--r-- 1 si si 10440 Oct  1 04:11 nest/aarch64-android24/include/absl/base/options.h` |
| a real header | `test -f $PREFIX/include/absl/strings/string_view.h` | present |
| per-module pkg-config | `pkg-config --modversion absl_base` | `20260817` |
| **no aggregate `absl.pc`** (correct) | `pkg-config --modversion absl` | `Package absl was not found in the pkg-config search path.` |
| CMake package config | `ls $PREFIX/lib/cmake/absl/` | `abslConfig.cmake`, `abslConfigVersion.cmake`, `abslTargets.cmake`, `abslTargets-noconfig.cmake` |
| **no `bin/` output** | `find $PREFIX/bin -newermt '2026-10-01 04:00'` | empty |

## Rerun proves the new stamp is real

```
$ sh /tmp/build-abseil-cpp.sh
skip abseil-cpp@source (fresh)
skip abseil-cpp@aarch64-android24 (fresh)
```

## System-level findings

### BLOCKER (recorded, not fixed): the Android systems do not provide `-llog`

**This is a defect in `packages/*android*/generic.lua`, not in this recipe.**
The recipe must not be edited to work around it and was not.

What the build shows: `libabsl_log_internal_log_sink_set.a` carries exactly
one `U __android_log_write` (quoted above). `absl/log/internal/log_sink_set.cc`
guards that call with `#ifdef __ANDROID__`, which the NDK clang wrapper
predefines, so the `AndroidLogSink` is compiled in unconditionally.

Why it does not fail *this* build: `BUILD_SHARED_LIBS=OFF` makes every target
`add_library(... STATIC "")`, and `ABSL_BUILD_TESTING=OFF` makes
`absl_cc_test` return before its `add_executable`. There is no link step
anywhere in the build. A static archive is not linked.

Why it breaks everything downstream: any consumer that links
`libabsl_log` on Android gets `undefined reference to __android_log_write`.
protobuf 22+ links absl, so the first real consumer hits it immediately, and
the error does not name absl — which makes it easy to misdiagnose.

**Why upstream's own `-llog` does not save us.** Upstream adds
`$<$<BOOL:${ANDROID}>:-llog>` to that target's `LINKOPTS`
(`absl/log/CMakeLists.txt:237`), but `${ANDROID}` is a *CMake* variable that
cmake only sets when `CMAKE_SYSTEM_NAME` is `Android`, and our toolchain file
deliberately keeps `set(CMAKE_SYSTEM_NAME Linux)`
(`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`). The
generator expression therefore evaluates empty. Separately, `PC_LINKOPTS` is
built from `ABSL_CC_LIB_LINKOPTS` (`CMake/AbseilHelpers.cmake:210`), which is
a *different* variable from the `LINKOPTS` the `-llog` lives in — so the
`.pc` files never carried `-llog` either, and would not for a static archive.

**Where the fix belongs.** The `LDFLAGS` section of each
`packages/*android*/generic.lua`, next to the existing `-lm`
(`packages/aarch64-android24/generic.lua:79`), one `-llog` per file, commented
with the reason. That is **56 system files** — 14 each of `aarch64-*`,
`armv7a-*`, `i686-*`, `x86_64-*`. `x86_64-mingw` and `clang-native` need
nothing.

**Scope, so this record cannot be misread.** It is a *consumer-link* blocker,
not a build blocker. abseil-cpp built successfully and its artifacts are
correct and usable. `liblog.so` is present in the NDK sysroot at every API
level and `__android_log_write` is declared from API 21 up, so there is no
API-level caveat on the fix. The same defect hits **glog** identically — see
`packages/glog/stage3.md` — and **one system change repairs both.**

### No recipe change was made

`packages/abseil-cpp/generic.lua` and `source.lua` are committed unmodified.
