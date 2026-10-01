ACCEPT

# protobuf review (stage1: 36.2, `protobuf-36.2.tar.gz`)

## The two claims the assignment asked me to settle — both are CORRECT

### 1. `protobuf_BUILD_LIBUPB=OFF` really is honoured. I traced the whole graph.

`CMakeLists.txt:31-47` declares, with these defaults:

| option | line | default |
| --- | --- | --- |
| `protobuf_BUILD_LIBUPB` | :39 | **ON** |
| `protobuf_BUILD_LIBPROTOC` | :38 | **OFF** |
| `protobuf_BUILD_PROTOC_BINARIES` | :36 | **ON** |
| `protobuf_BUILD_PROTOBUF_BINARIES` | :35 | ON |
| `protobuf_BUILD_LIBPROTOBUF` | :37 | ON |
| `protobuf_BUILD_TESTS` | :32 | OFF |

The re-enabling cascade is `CMakeLists.txt:123-126`:
```cmake
if (protobuf_BUILD_PROTOC_BINARIES OR protobuf_BUILD_TESTS)
  set(protobuf_BUILD_LIBPROTOC ON)
endif ()
```
and the forcing branch is `CMakeLists.txt:132-135`:
```cmake
if(protobuf_BUILD_LIBPROTOC AND NOT protobuf_BUILD_LIBUPB)
  message(WARNING "Building protoc binaries requires building libupb. As such, protobuf_BUILD_LIBUPB is being forced to ON.")
  set(protobuf_BUILD_LIBUPB ON)
endif()
```

The recipe passes `-Dprotobuf_BUILD_PROTOC_BINARIES=OFF` **and**
`-Dprotobuf_BUILD_TESTS=OFF`. Both members of the `:123` OR are therefore
false, `LIBPROTOC` stays at its `OFF` default, the `:132` branch never fires,
and `LIBUPB=OFF` is honoured. The chain is exactly as the adder described.

I also checked the *other* direction of the same graph, which the adder did
not mention and which is the sharper statement of why the flag is safe:
`CMakeLists.txt:120-122` is
```cmake
if (protobuf_BUILD_LIBUPB)
  message(FATAL_ERROR "protobuf_BUILD_LIBPROTOBUF=OFF requires protobuf_BUILD_LIBUPB=OFF.")
endif()
```
That FATAL_ERROR fires only when `LIBPROTOBUF` is off. The recipe leaves
`LIBPROTOBUF` at its default ON, so it cannot fire.

And the resulting target set is real, not assumed: `CMakeLists.txt:307-333`
shows `libprotobuf-lite` (`:311`), `libprotobuf` (`:316`),
`libprotoc` only `if (protobuf_BUILD_LIBPROTOC)` (`:319`), `libupb` only
`if (protobuf_BUILD_LIBUPB)` (`:326`), `protoc` only
`if (protobuf_BUILD_PROTOC_BINARIES)` (`:330`). With the recipe's flags, only
the first two exist, plus `utf8_range` from `cmake/utf8_range.cmake:11`.
`cmake/libupb.cmake:19` is `add_library(libupb STATIC …)` — a private,
never-installed target — so dropping it removes ~200 source files and a large
generated minitable from the build, and nothing this prefix would consume.

### 2. The `-llog` call is right: **check `$LDFLAGS`, do not add a flag.**

`packages/abseil-cpp/generic.lua` builds with `__ANDROID__` predefined (every
NDK clang wrapper predefines it), and abseil's `log_sink_set.cc` compiles an
`AndroidLogSink` that calls `__android_log_write`. That symbol is in Bionic's
liblog. But all four Android systems already carry it:

| system | evidence |
| --- | --- |
| `aarch64-android24` | `generic.lua`: `LDFLAGS="$LDFLAGS -llog"`, in the `-lm`/`-llog` section |
| `aarch64-android21`, `aarch64-android35`, `x86_64-android35` | same, each with the in-place comment |

and AGENTS.md:382-396 records why: because our toolchain files deliberately set
`CMAKE_SYSTEM_NAME` to `Linux`, cmake never sets `ANDROID`, so glog's and
abseil's own `if (ANDROID) → target_link_libraries(… log)` never fire. Hence
the explicit `-llog`.

So the recipe is correct **not** to add it. Adding `-llog` to
`generic.lua` would be a target fact in a system-neutral file — the exact thing
AGENTS.md:211-222 forbids — and would duplicate a flag every Android system
already sets. **`stage3.md` must record this as "check `$LDFLAGS`" if a
consumer link ever fails, not "add a flag here".** Recording it now so the
builder does not "fix" it.

`x86_64-mingw` and `clang-native` are unaffected: `__ANDROID__` is undefined,
so abseil's sink is not compiled and there is nothing to resolve.

## The tarball choice is right, and the reason is the interesting part

`source.lua` uses the **release tarball**, not a git clone, and AGENTS.md:152-154
says to clone when the tarball is incomplete. The adder's justification is that
the release tarball carries `third_party/` as real content, and I confirmed it:
`ls protobuf-36.2/third_party/` → `utf8_range/ jsoncpp.BUILD zlib.BUILD
BUILD.bazel`, and `third_party/utf8_range/CMakeLists.txt` exists with real
content. That matters because `cmake/utf8_range.cmake:4-8` is:
```cmake
if (NOT EXISTS "${protobuf_SOURCE_DIR}/third_party/utf8_range/CMakeLists.txt")
  message(FATAL_ERROR "Cannot find third_party/utf8_range directory …")
endif()
```
A hard configure failure, not a warning. `abseil-cpp` is **not** vendored, which
is correct and is why the `find_package(absl CONFIG)` at
`cmake/abseil-cpp.cmake:16` has to succeed — which is what
`require("abseil-cpp")` guarantees. If it did not, `:20-29` falls through to
`FetchContent` of abseil from GitHub: a network fetch inside a cross build.

Version skew is fine in one direction and only one: the prefix has abseil
`20260817.0` (`packages/abseil-cpp/source.lua`), newer than protobuf's pin of
`20250512.1` (`cmake/dependencies.cmake:15`). `find_package` wins. If abseil
were ever downgraded below the pin, `cmake/dependencies.cmake` would be reached
and the FetchContent path would fire. Worth a line in `stage3.md`.

## What the recipe gets right

- **Version is current.** GitHub API: `v36.2`, published 2026-09-17;
  `protobuf-36.2.tar.gz` (7 339 736 bytes) is one of its 15 assets. Top
  directory `protobuf-36.2/`, `--strip-components=1` correct.
- **No autotools → no guard.** No `configure`, `configure.ac`, `aclocal.m4`
  or `Makefile.am` anywhere in the tree. The recipe writes no timestamp guard,
  which is correct.
- **Every flag genuinely exists** — this is the check that catches the "a flag
  that does not exist is worse than a missing flag" failure. All nine passed
  options resolve to a real `option()` or a real read in the tree:
  `protobuf_BUILD_SHARED_LIBS` (`:48`), `protobuf_BUILD_PROTOC_BINARIES`
  (`:36`), `protobuf_BUILD_LIBUPB` (`:39`), `protobuf_BUILD_TESTS` (`:32`),
  `protobuf_BUILD_CONFORMANCE` (`:33`), `protobuf_BUILD_EXAMPLES` (`:34`),
  `protobuf_WITH_ZLIB` (`:56`), plus standard `BUILD_SHARED_LIBS`. **No
  configure "Manually-specified variables were not used" warning is possible.**
- **`protobuf_WITH_ZLIB=OFF` is a deliberate narrowing, and the recipe says
  so.** `CMakeLists.txt:199-203` would otherwise `find_package(ZLIB)` and set
  `HAVE_ZLIB 1`. Turning it off removes zlib-backed gzip from the wire format.
  That is a **capability** decision, not a host-program one — the only flag in
  this recipe that does that — and `generic.lua:41-43` states it plainly. A
  reviewer who wants zlib should delete that one flag and nothing else.
  Note this makes the `require("zlib")` at `generic.lua:2` unused by this
  package; harmless, and `stage1.md` says why it is kept (other consumers).
- **`protobuf_BUILD_PROTOC_BINARIES=OFF` also removes the generator
  plugins**, which `generic.lua:22-27` claims: `cmake/install.cmake:61-83`
  installs `protoc` plus one `protoc-gen-{upb,upbdefs,upb_minitable}` per
  generator, and that whole block is `if (protobuf_BUILD_PROTOC_BINARIES)`.
  Correct. A target `protoc` could never be run here anyway.
- **System usage is clean** — `cmake -S . -B build $CMAKE_FLAGS …`,
  `cmake --build build --parallel 1`, `cmake --install build`. Everything
  system-supplied. No `export`, no hardcoded target facts, no fan-out.
- **`find_package(Threads REQUIRED)` at `CMakeLists.txt:196` is satisfied
  everywhere**: the Android systems put `-DTHREADS_PREFER_PTHREAD_FLAG=ON` in
  `$CMAKE_FLAGS` precisely for this; mingw and native resolve `-pthread`
  normally, and `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` means no
  try-run is needed.
- **`require()`s resolve**: `abseil-cpp`, `zlib` both exist under `packages/`.

## Android API level: inert, and tested

Sweeping `src/google/protobuf/` for the gap list (`posix_spawn`,
`process_vm_readv`, `POSIX_MADV_*`, `getpass`, `mblen`, `O_BINARY`,
`nl_langinfo`, `iconv`, `mktime_z`): **zero hits**. protobuf's runtime uses
`open`/`read`/`write`/`close`/`mmap`/`munmap`, `malloc`, atomics and
`std::mutex`/`std::condition_variable` — libc++ header facilities backed by
Bionic libc at every API level. The `.proto` timestamp helpers use `time()`
and `localtime()`, not `mktime_z`. **The API level really is inert.**

## mingw row

`cmake/abseil-cpp.cmake:45` takes the `BUILD_SHARED_LIBS AND MSVC` branch;
`BUILD_SHARED_LIBS` is OFF and cmake does not set `MSVC` for mingw-w64 GCC, so
the `absl::abseil_dll` path is not taken and the plain per-module target list
at `:56-92` is used. `CMakeLists.txt:181-182`'s `check_linker_flag` for
`-Wl,--version-script` simply reports false on PE ld and protobuf takes its
`else` path. `__ANDROID__` undefined → no liblog concern. **WILL BUILD
stands**, and the tree already builds abseil on mingw.

## Install list — two corrections to `stage1.md`

1. **`lib/cmake/protobuf/protobufConfig.cmake` does not exist.** The installed
   files are hyphenated: `cmake/install.cmake:162-171` configures
   `protobuf-config.cmake`, `protobuf-config-version.cmake`,
   `protobuf-module.cmake`, `protobuf-options.cmake`,
   `protobuf-generate.cmake`, and `:175-179` installs the export as
   `protobuf-targets.cmake`. Only the `protobuf-config.cmake.in` *template*
   uses that spelling — and it does, so there is no capital-C no-hyphen file
   anywhere.
2. `include/google/upb/**` is correctly marked conditional in `stage1.md`, and
   with `LIBUPB=OFF` it is **not** installed: `cmake/install.cmake:104-116`
   appends `libupb_hdrs` and installs the four bootstrap headers only
   `if (protobuf_BUILD_LIBUPB)`. A builder should expect no `upb/` headers.

Everything else is real: `lib/libprotobuf.a`, `lib/libprotobuf-lite.a`
(`cmake/install.cmake:41-59`), `lib/pkgconfig/protobuf.pc` and
`protobuf-lite.pc` (`:85-92`, both gated on the target existing, both will).
`stage1.md`'s list of `.pb.h` files matches `release_all_options_protos_files`
at `src/file_lists.cmake:1033+`, which `cmake/install.cmake:101` folds into
`protobuf_HEADERS`.

**Note the version string the builder will actually see.**
`pkg-config --modversion protobuf` returns **`36.2.0`**, not `7.36.2`.
`cmake/protobuf.pc.cmake:8` is `Version: @protobuf_VERSION@`, and
`CMakeLists.txt:152-160` builds `protobuf_VERSION` as
`${MINOR}.${PATCH}.0` from `protobuf_VERSION_STRING "7.36.2"` (`:94`) →
`MINOR=36`, `PATCH=2` → `"36.2.0"`. `7.36.2` is the C++ language ABI version
and reaches only `protobuf-config-version.cmake`, never the `.pc`.

## Carried to the build

`clang-native` is the system to build this on. Artifacts under `$PREFIX`:

| artifact | source of truth |
| --- | --- |
| `lib/libprotobuf.a` | `cmake/install.cmake:41-59` |
| `lib/libprotobuf-lite.a` | same |
| `lib/libutf8_range.a`, `lib/libutf8_validity.a` | `third_party/utf8_range/CMakeLists.txt:73-77` |
| `include/google/protobuf/*.h` incl. `descriptor.pb.h` | `cmake/install.cmake:97-146` |
| `lib/pkgconfig/protobuf.pc`, `protobuf-lite.pc` | `cmake/install.cmake:85-92` |
| `lib/pkgconfig/utf8_range.pc` | `third_party/utf8_range/CMakeLists.txt:87-91` |
| `lib/cmake/protobuf/protobuf-config.cmake` (+ `-version`, `-module`, `-options`, `-generate`, `protobuf-targets.cmake`) | `cmake/install.cmake:162-185` |

### The ONE command that proves each

```sh
# both archives exist, right format, hold real symbols
test -f "$PREFIX/lib/libprotobuf.a" && test -f "$PREFIX/lib/libprotobuf-lite.a" &&
llvm-objdump -f "$PREFIX/lib/libprotobuf.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libprotobuf.a" | grep -c MessageLite
```
Expected: correct object format, non-zero count. **Both** archives are
expected; `libprotobuf-lite` is unconditional (`CMakeLists.txt:311`).

```sh
# THE LIBUPB CHECK — this is the check that matters for this package.
# Scoped to protobuf's own archive names so a second package's .so in lib/
# cannot make it pass or fail.
find "$PREFIX/lib" -maxdepth 1 \( -name 'libupb.*' -o -name 'libprotoc.*' \) | wc -l
find "$PREFIX/bin" -maxdepth 1 -name 'protoc*' 2>/dev/null | wc -l
```
Expected: `0` and `0`. **A `libupb.a` here means the `CMakeLists.txt:132`
forcing branch fired and `-Dprotobuf_BUILD_LIBUPB=OFF` was silently
overridden** — exactly the trap the previous worker fell into. The `.pc`
template `cmake/upb.pc.cmake` is only configured `if (TARGET libupb)`
(`cmake/install.cmake:35-38`), so its absence is a second, independent signal.

```sh
# abseil was found in the prefix and NOT fetched: no FetchContent download
# directory exists in the build tree
ls build/_deps 2>/dev/null | wc -l
```
Expected: `0`. A non-empty `_deps` means `cmake/abseil-cpp.cmake:20-35` fell
through to `FetchContent` — a network fetch inside the build.

```sh
# -Dprotobuf_WITH_ZLIB=OFF took effect
llvm-nm -u "$PREFIX/lib/libprotobuf.a" | grep -cE 'deflate|inflate'
```
Expected: `0`.

```sh
# both .pc files landed and carry the upstream numbering
test -f "$PREFIX/lib/pkgconfig/protobuf.pc" && test -f "$PREFIX/lib/pkgconfig/protobuf-lite.pc" &&
pkg-config --modversion protobuf &&
grep -m1 '^Requires:' "$PREFIX/lib/pkgconfig/protobuf.pc"
```
Expected modversion: **`36.2.0`** (see above — not `7.36.2`, not `36.2`).
The `Requires:` line is built at `cmake/install.cmake:3-17` from
`protobuf_ABSL_USED_TARGETS` plus `utf8_range`, so it should name the absl
module `.pc` files (`absl_strings`, `absl_status`, …) and `utf8_range`. If it
is empty, the absl module `.pc` files are missing from the prefix, which is a
`packages/abseil-cpp` problem, not this recipe's.

```sh
# no shared objects: BUILD_SHARED_LIBS=OFF took effect
find "$PREFIX/lib" -maxdepth 1 \( -name 'libprotobuf.so*' -o -name 'libprotobuf-lite.so*' \) | wc -l
```
Expected: `0`.

### For the builder, on Android

If a **consumer** link fails with `undefined symbol: __android_log_write`,
the cause is `$LDFLAGS`, not this recipe — the Android systems carry
`-llog` already. Confirm with:
```sh
llvm-nm -u "$PREFIX/lib/libabsl_log.a" | grep -c __android_log_write
```
Expected `1` on Android (that reference is correct and intentional) and `0` on
mingw/native. Then check `echo "$LDFLAGS"` in the build environment for `-llog`.
**Do not add `-llog` to `packages/protobuf/generic.lua`.**