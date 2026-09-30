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

A **consumer-link** blocker, not a build blocker. glog built successfully.

> **Superseded — see "Second build" below.** This section originally
> concluded that "its archive and its `.pc` are correct and usable as
> artifacts", and that no recipe change was needed. Both claims were wrong.
> The archive is fine; the `.pc` was unusable by any C++ consumer on any
> system, and the `-llog` it was missing *is* fixable from a recipe.

### No recipe change was made — **at the time of this build**

`packages/glog/generic.lua` and `source.lua` were committed unmodified by
this build. They are not any more: see "Second build" below.

---

# Second build: the installed `libglog.pc` was unusable by any consumer

The first record above concluded that glog's archive and `.pc` were "correct
and usable as artifacts". **That conclusion was wrong, and this section
supersedes it.** Two link/compile tests against the prefix as it stood
after that build both failed. Nothing in the first build could have caught
them: a static archive is not linked, and a `.pc` is a text file that is
only read by a consumer, and this prefix had no glog consumer.

## The two defects, reproduced on the installed prefix

The `.pc` as installed by the first build, in full:

```
prefix=/home/si/ond/git/retrolunar/nest/aarch64-android24
exec_prefix=/home/si/ond/git/retrolunar/nest/aarch64-android24/bin
libdir=/home/si/ond/git/retrolunar/nest/aarch64-android24/lib
includedir=/home/si/ond/git/retrolunar/nest/aarch64-android24/include

Name: libglog
Description: Google Log (glog) C++ logging framework
Version: 0.7.1
Libs: -L${libdir} -lglog
Libs.private: -pthread
Cflags: -I${includedir}
```

### DEFECT 1 — `Libs.private` has no `-llog`

`libglog.a` has exactly one undefined reference:

```
$ llvm-nm --undefined-only nest/aarch64-android24/lib/libglog.a | grep -c __android_log_write
1
```

A throwaway consumer in `/tmp` (four lines: `#include <glog/logging.h>`,
`InitGoogleLogging`, one `LOG(INFO)`), compiled with the `.pc`'s own
`Cflags` plus the export macro supplied **by hand** so that only the link
was under test, and then linked with **only** what pkg-config reported.
`pkg-config --libs --static libglog` returned
`-L…/lib -lglog -pthread` — no `-llog`:

```
$ /home/si/.local/share/mise/installs/android-sdk/23.0/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang++ /tmp/glogconsumer.o -o /tmp/glogconsumer -L/home/si/ond/git/retrolunar/nest/aarch64-android24/lib -lglog -pthread
ld.lld: error: undefined symbol: __android_log_write
>>> referenced by utilities.cc
>>>               utilities.cc.o:(google::glog_internal_namespace_::AlsoErrorWrite(google::LogSeverity, char const*, char const*)) in archive /home/si/ond/git/retrolunar/nest/aarch64-android24/lib/libglog.a
clang++: error: linker command failed with exit code 1 (use -v to see invocation)
```

exit 1. The system-level `-llog` in the Android systems' `LDFLAGS` does not
help: it only reaches consumers that link through this build system.

### DEFECT 2 — `Cflags` has no `-DGLOG_USE_GLOG_EXPORT`

The same consumer, compiled with **only** the `.pc`'s `Cflags` and nothing
added by hand, does not even compile — 20 errors, the first two being the
real cause:

```
$ /home/si/.local/share/mise/installs/android-sdk/23.0/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang++ -c /tmp/glogconsumer.cc -o /tmp/glogconsumer2.o -I/home/si/ond/git/retrolunar/nest/aarch64-android24/include
In file included from /tmp/glogconsumer.cc:2:
/home/si/ond/git/retrolunar/nest/aarch64-android24/include/glog/logging.h:60:4: error: <glog/logging.h> was not included correctly. See the documentation for how to consume the library.
   60 | #  error <glog/logging.h> was not included correctly. See the documentation for how to consume the library.
      |    ^
In file included from /tmp/glogconsumer.cc:2:
In file included from /home/si/ond/git/retrolunar/nest/aarch64-android24/include/glog/logging.h:63:
/home/si/ond/git/retrolunar/nest/aarch64-android24/include/glog/flags.h:45:4: error: <glog/flags.h> was not included correctly. See the documentation for how to consume the library.
   45 | #  error <glog/flags.h> was not included correctly. See the documentation for how to consume the library.
   104 | DECLARE_int32(logemaillevel);
  105 | DECLARE_int32(logemaillevel);
… (18 further errors: "unknown type name 'GLOG_EXPORT'" and the fallout from it)
fatal error: too many errors emitted, stopping now [-ferror-limit=]
20 errors generated.
```

(The three flag lines above are the compiler echoing the two offending
`DECLARE_*` lines; the full run is 20 errors and the elision is marked.)

So the installed `.pc` was unusable for **any** C++ consumer on **any**
system. This is not an Android artifact.

## Root causes, confirmed in the tree

**Defect 1 — `if (ANDROID)` never fires.** `nest/source/glog/CMakeLists.txt:463-466`:

```cmake
if (ANDROID)
  target_link_libraries (glog PRIVATE log)
  set (glog_libraries_options_for_static_linking "${glog_libraries_options_for_static_linking} -llog")
endif (ANDROID)
```

`ANDROID` is the **cache variable** cmake derives from `CMAKE_SYSTEM_NAME`
being `Android`. Our toolchain files deliberately keep
`set(CMAKE_SYSTEM_NAME Linux)`
(`packages/aarch64-android24/aarch64-linux-android24-toolchain.cmake:3`) to
keep cmake out of its own NDK integration, so the variable is unset and
neither line runs. The first record above had this exactly right; what it
got wrong was the conclusion that no recipe could act on it.

**Defect 2 — the header genuinely requires the macro, and the `.pc` template
has nowhere to put it.** `include/glog/logging.h:55-61`, as installed:

```c
#if defined(GLOG_USE_GLOG_EXPORT)
#  include "glog/export.h"
#endif

#if !defined(GLOG_EXPORT) || !defined(GLOG_NO_EXPORT)
#  error <glog/logging.h> was not included correctly. …
#endif
```

`GLOG_EXPORT` and `GLOG_NO_EXPORT` are defined **only** in the generated
`glog/export.h`, and that file is included **only** under
`GLOG_USE_GLOG_EXPORT`. So a consumer that does not define the macro
cannot obtain the two macros by any other route, and the `#error` is
unconditional. Meanwhile `CMakeLists.txt:416` makes the macro a **PUBLIC**
compile definition of the `glog` target:

```cmake
# CMake always uses the generated export header
target_compile_definitions (glog PUBLIC GLOG_USE_GLOG_EXPORT)
```

which is why a `find_package(glog)` consumer is fine (it arrives as
`INTERFACE_COMPILE_DEFINITIONS`) and only a `pkg-config` consumer breaks.
And `libglog.pc.in:11` is:

```
Cflags: -I${includedir}
```

a literal with **no `@variable@` in it**. `configure_file(… @ONLY)`
(`CMakeLists.txt:515-519`) can only substitute what the template offers, so
**no cmake option, variable or cache answer can reach that line.** There is
no `-DWITH_…`, no `CMAKE_CXX_FLAGS` trick and no installed-header trick: a
compile flag has to reach the consumer, and `Cflags:` is the only channel a
`pkg-config` consumer reads.

## The fix

Two different mechanisms, because the two defects have different shapes.

**Defect 1: a cmake cache answer, `-DANDROID=ON`, in a new
`packages/glog/android.lua`.** It is the smallest available fix: it makes
upstream's own `if (ANDROID)` branch run, which is exactly what that branch
was written for. It is not a patch and it is not a lie — we *are*
cross-compiling for Android; the toolchain file only declines to tell cmake
so. It lives in `android.lua` rather than `generic.lua` because it is an
Android fact: `x86_64-mingw` and `clang-native` have no `liblog`, and
`generic.lua` is the recipe both of them use.

It also repairs the exported CMake package, which a `.pc`-only fix could
not have:

```
$ grep -n 'INTERFACE_LINK_LIBRARIES' nest/aarch64-android24/lib/cmake/glog/glog-targets.cmake
65:  INTERFACE_LINK_LIBRARIES "\$<LINK_ONLY:Threads::Threads>;\$<LINK_ONLY:log>"
```

And it changes nothing about the compiled library. Measured, not assumed:
two builds from the same tree with identical flags, one with
`-DANDROID=ON` and one without, produced **byte-identical** archives —
both 559844 bytes, `cmp` clean — because the branch only adds link
metadata. The one cmake-internal effect is
`/usr/share/cmake/Modules/Compiler/Clang.cmake:84`, which would set
`CMAKE_<lang>_LINK_OPTIONS_IPO` to `-fuse-ld=gold` because
`CMAKE_ANDROID_NDK_VERSION` is unset; glog enables no IPO, so that variable
is never read.

**Defect 2: a rewrite of the staged `.pc` in `$OUT`, in both `generic.lua`
and `android.lua`.** Judgement call, recorded because the no-patch rule
is a hard rule:

```sh
awk '{ if ($0 ~ /^Cflags:/) print $0 " -DGLOG_USE_GLOG_EXPORT"; else print }' "$OUT/lib/pkgconfig/libglog.pc" > "$WORK/libglog.pc"
cp "$WORK/libglog.pc" "$OUT/lib/pkgconfig/libglog.pc"
```

- The no-patch rule covers upstream sources. `libglog.pc.in` and everything
  it is generated from are upstream and are untouched; this runs **after**
  `cmake --install` and edits a generated file in **our own staging
  directory** — the same class of edit the loader itself already performs on
  the same file, for the same reason, at `src/loader.lua:454-468`. It is a
  plain substitution on one line, not a diff against upstream.
- It is genuinely the only route: the `Cflags:` line has no `@variable@`
  (see above), so cmake has nothing to configure.
- A *duplicate* `Cflags:` key was rejected as an alternative, and the
  reason is worth keeping: `pkg-config` resolves a repeated keyword
  last-key-wins, so appending a second `Cflags:` line **replaces** the
  first. Verified:

  ```
  $ printf '…\nCflags: -I${includedir}\nCflags: -I${includedir} -DX\n' > dup.pc
  $ PKG_CONFIG_LIBDIR=. pkg-config --cflags dup
  -DX
  ```

  (only the second line's flags survive) — so the existing line has to be
  rewritten, not appended to.
- The added text contains no `$OUT`, so the loader's staged-`.pc` pass
  takes its `*)` arm and prints the line verbatim. Confirmed: the installed
  file's `prefix`/`libdir`/`includedir` all came through the `$OUT` →
  `$PREFIX` rewrite, and the new text is intact beside them.
- It cannot double-apply. `cmake --install` regenerates the `.pc` from
  `libglog.pc.in` on every build, so the input to the rewrite never already
  carries the macro.

## Stale-artifact cleanup before this build

The first build's outputs were all still in the prefix, so a stale file
could have passed as a fresh one. Deleted first, after recording what was
there:

```
$ ls -la --time-style=full-iso nest/aarch64-android24/lib/libglog.a \
      nest/aarch64-android24/lib/pkgconfig/libglog.pc \
      nest/aarch64-android24/.retrolunar-glog
-rw-r--r-- 1 si si      0 2026-10-01 04:15:03.574687993 +1000 nest/aarch64-android24/.retrolunar-glog
-rw-r--r-- 1 si si 560012 2026-10-01 04:15:03.563687074 +1000 nest/aarch64-android24/lib/libglog.a
-rw-r--r-- 1 si si    412 2026-10-01 04:15:03.563687074 +1000 nest/aarch64-android24/lib/pkgconfig/libglog.pc
$ ls -d nest/aarch64-android24/include/glog nest/aarch64-android24/lib/cmake/glog
nest/aarch64-android24/include/glog
nest/aarch64-android24/lib/cmake/glog
```

**Deleted:** the build stamp, `lib/libglog.a`, `lib/pkgconfig/libglog.pc`,
the whole `include/glog/` tree, the whole `lib/cmake/glog/` tree.
Post-delete `ls` on all five: `No such file or directory`.

The **source tree was not** deleted: `source.lua` is unchanged, so
`nest/source/glog` is still the 0.7.1 tree the current recipe fetched, and
the build log above shows no re-download. The stamp alone was the point —
with it present the emitted script prints `skip glog@aarch64-android24
(fresh)` and the new recipes are never executed at all.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-glog
rm -f nest/aarch64-android24/lib/libglog.a
rm -f nest/aarch64-android24/lib/pkgconfig/libglog.pc
rm -rf nest/aarch64-android24/include/glog nest/aarch64-android24/lib/cmake/glog
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'glog@aarch64-android24' > /tmp/build-glog2.sh
sh -n /tmp/build-glog2.sh          # exit 0
sh /tmp/build-glog2.sh             # exit 0
```

The Android system reaches `packages/glog/android.lua` through its
`recipe_fallbacks`, and the freshness condition follows the selected
recipe, so the new file is what invalidates the stamp:

```
if [ -f $NESTDIR/aarch64-android24/.retrolunar-glog ] && [ $NESTDIR/aarch64-android24/.retrolunar-glog -nt $PACKAGEDIR/glog/android.lua ] && …
```

## The installed `.pc` after the fix

```
prefix=/home/si/ond/git/retrolunar/nest/aarch64-android24
exec_prefix=/home/si/ond/git/retrolunar/nest/aarch64-android24/bin
libdir=/home/si/ond/git/retrolunar/nest/aarch64-android24/lib
includedir=/home/si/ond/git/retrolunar/nest/aarch64-android24/include

Name: libglog
Description: Google Log (glog) C++ logging framework
Version: 0.7.1
Libs: -L${libdir} -lglog
Libs.private: -pthread -llog
Cflags: -I${includedir} -DGLOG_USE_GLOG_EXPORT
```

```
$ pkg-config --modversion libglog
0.7.1
```

## After-fix evidence

Every flag below came out of `pkg-config`; nothing was added by hand.

```
$ pkg-config --cflags libglog
-I/home/si/ond/git/retrolunar/nest/aarch64-android24/include -DGLOG_USE_GLOG_EXPORT
$ pkg-config --libs --static libglog
-L/home/si/ond/git/retrolunar/nest/aarch64-android24/lib -lglog -pthread -llog
```

**Defect 2** — compile with `Cflags:` alone, no hand-added `-D`:

```
$ …/bin/aarch64-linux-android24-clang++ -c /tmp/glogconsumer.cc -o /tmp/glogconsumer2.o -I/home/si/ond/git/retrolunar/nest/aarch64-android24/include -DGLOG_USE_GLOG_EXPORT
exit 0
```

**Defect 1** — link that object with `--libs --static` alone, no
hand-added `-llog`:

```
$ …/bin/aarch64-linux-android24-clang++ /tmp/glogconsumer2.o -o /tmp/glogconsumer -L/home/si/ond/git/retrolunar/nest/aarch64-android24/lib -lglog -pthread -llog
exit 0
```

Combined in one command, for the same result:

```
$ …/bin/aarch64-linux-android24-clang++ /tmp/glogconsumer.cc -o /tmp/glogconsumer -I…/include -DGLOG_USE_GLOG_EXPORT -L…/lib -lglog -pthread -llog
exit 0
```

Static inspection only — **nothing was executed.** This host has
`qemu-aarch64` registered via `binfmt_misc`, so an aarch64 binary invoked
by name would run silently; every check below is `llvm-objdump`, `file`,
`llvm-nm` or `llvm-readelf`.

```
$ llvm-objdump -f nest/aarch64-android24/lib/libglog.a | head -3
nest/aarch64-android24/lib/libglog.a(glog.cc.o):	file format elf64-littleaarch64
architecture: aarch64

$ llvm-objdump -f /tmp/glogconsumer
/tmp/glogconsumer:	file format elf64-littleaarch64
architecture: aarch64

$ file /tmp/glogconsumer
/tmp/glogconsumer:  ELF 64-bit LSB pie executable, ARM aarch64, version 1 (SYSV),
                   dynamically linked, interpreter /system/bin/linker64,
                   for Android 24, built by NDK r28c (13676358), not stripped

$ llvm-readelf -d /tmp/glogconsumer | grep NEEDED
 0x0000000000000001 (NEEDED)  Shared library: [liblog.so]
 0x0000000000000001 (NEEDED)  Shared library: [libc++_shared.so]
 0x0000000000000001 (NEEDED)  Shared library: [libm.so]
 0x0000000000000001 (NEEDED)  Shared library: [libdl.so]
 0x0000000000000001 (NEEDED)  Shared library: [libc.so]
```

The `liblog.so` `NEEDED` entry is the visible form of the fix: the link
picked Bionic's liblog out of the sysroot and recorded it as a runtime
dependency, which is how every Android program consumes it. `libglog.a`
still has its one undefined `__android_log_write` — correct, and now
resolved at consumer link time instead of being an error.

## Rerun proves the new stamp is real

```
$ sh /tmp/build-glog2.sh
skip glog@source (fresh)
skip glog@aarch64-android24 (fresh)
```

## What changed in the recipes

- `packages/glog/android.lua` — **new**. `generic.lua`'s build plus
  `-DANDROID=ON` and the same staged-`.pc` rewrite, with the reasoning.
  Found for every Android target through the systems' `recipe_fallbacks`.
- `packages/glog/generic.lua` — the staged-`.pc` rewrite only. Kept
  system-neutral, so `x86_64-mingw` and `clang-native` get a usable `.pc`
  too. **It does not get `-DANDROID=ON`**, which is correct: they have no
  `liblog`.
- `packages/glog/source.lua` — unchanged.

The system-level `-llog` in the Android systems' `LDFLAGS` is untouched and
is still correct on its own terms: it is what lets abseil-cpp's
`AndroidLogSink` reach liblog. The finding recorded above that `-llog`
"belongs in a system file and nowhere else" was about *this* package's
`.pc`, and it was wrong for this package: the `.pc` is fixed at its own
level, and the system flag never could have fixed it.
