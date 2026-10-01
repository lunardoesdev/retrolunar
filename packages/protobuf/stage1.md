# protobuf build forecast

- **Package:** protobuf
- **Version:** 36.2 (release `v36.2`, 2026-09-17, newest on
  protocolbuffers/protobuf)
- **Upstream URL:** `https://github.com/protocolbuffers/protobuf/releases/download/v36.2/protobuf-36.2.tar.gz`
  (HTTP 200, 7 339 736 bytes, top directory `protobuf-36.2/`)
- **Build system: cmake** (`CMakeLists.txt:1` sets a minimum; see the caveat
  below). No autotools anywhere in the tree.
- **Config template: none.** No `AC_CONFIG_HEADERS`, no `config.h.in`. protobuf
  generates headers into the build tree. **No timestamp guard applies and none is
  written.**
- **Dependencies required:** `abseil-cpp` (**exists**), `zlib` (exists, but the
  recipe turns protobuf's zlib support off — see below, so it is required only
  to be present, not used).
- **Installs:** `lib/libprotobuf.a`, `lib/libprotobuf-lite.a`,
  `include/google/protobuf/*.h` (plus `any.pb.h`, `descriptor.pb.h`,
  `duration.pb.h`, `empty.pb.h`, `field_mask.pb.h`, `source_context.pb.h`,
  `struct.pb.h`, `timestamp.pb.h`, `type.pb.h`, `wrappers.pb.h`),
  `include/google/protobuf/compiler/**`, `include/google/upb/**` (if libupb is
  on), `lib/pkgconfig/protobuf.pc`, `lib/pkgconfig/protobuf-lite.pc`,
  `lib/cmake/protobuf/*`. **No `protoc` binary** — see the LIBUPB section.

## The two questions the assignment asked me to settle

### 1. Can `protobuf_BUILD_LIBUPB` actually be turned off? — **Yes, but only because protoc is also off.**

The previous worker's claim was "upstream forces it on whenever
`protobuf_BUILD_LIBPROTOC` is on". **That part is exactly true**, and I found it
at `CMakeLists.txt:132-134`:

```cmake
if(protobuf_BUILD_LIBPROTOC AND NOT protobuf_BUILD_LIBUPB)
  message(WARNING "Building protoc binaries requires building libupb. As such, protobuf_BUILD_LIBUPB is being forced to ON.")
  set(protobuf_BUILD_LIBUPB ON)
endif()
```

But the premise is not forced. The full option graph, read out of
`CMakeLists.txt:31-135`:

| option | line | default |
| --- | --- | --- |
| `protobuf_BUILD_LIBUPB` | :39 | **ON** |
| `protobuf_BUILD_LIBPROTOC` | :38 | **OFF** |
| `protobuf_BUILD_PROTOC_BINARIES` | :36 | **ON** |
| `protobuf_BUILD_PROTOBUF_BINARIES` | :35 | ON |
| `protobuf_BUILD_LIBPROTOBUF` | :37 | ON |
| `protobuf_BUILD_TESTS` | :32 | OFF |

The chain that re-enables it is `CMakeLists.txt:124-126`:

```cmake
if (protobuf_BUILD_PROTOC_BINARIES OR protobuf_BUILD_TESTS)
  set(protobuf_BUILD_LIBPROTOC ON)
endif ()
```

So: `protobuf_BUILD_PROTOC_BINARIES=OFF` **and** `protobuf_BUILD_TESTS=OFF`
(the default) leaves `LIBPROTOC` off, which means the `:132` forcing branch
never fires, and `protobuf_BUILD_LIBUPB=OFF` is **honoured**.

**What is actually built, therefore:** `libprotobuf-lite` and `libprotobuf`
(`CMakeLists.txt:311-320`) plus `utf8_range` (`cmake/utf8_range.cmake:11`,
which `add_subdirectory`s the vendored copy). **Not** `libprotoc`, **not**
`libupb`, **not** `protoc`, **not** the three `protoc-gen-upb*` plugins
(`cmake/install.cmake:66-70` installs one per generator, and that whole block is
`if (protobuf_BUILD_PROTOC_BINARIES)` at `:61`).

Dropping libupb is worth it: `cmake/libupb.cmake:19` builds it as a
`STATIC` `add_library` with hidden visibility, explicitly commented at `:17-18`
as *"upb does not support shared library builds, and is intended to be
statically linked as a private dependency"*. It is a **private dependency of
protoc**, not a library this prefix would consume, and it pulls in a large
generated minitable blob. So `LIBUPB=OFF` is both honoured and correct here.

**Corollary a reviewer should know:** had the recipe wanted `protoc` (say, to
generate `.pb.cc` for a consumer), then `protobuf_BUILD_LIBUPB=OFF` would have
been **silently overridden with a WARNING** and the flag would have been inert.
That is the trap the previous worker hit. This package does not want `protoc`,
so the flag is real.

### 2. `-llog` — where it comes from, and why the recipe does not add it

The measured trap: **abseil's `absl/log/internal/log_sink_set.cc` compiles an
`AndroidLogSink` whenever `__ANDROID__` is predefined**, and that macro is
predefined by every NDK clang wrapper — so abseil in this prefix *does* contain
a call to `__android_log_write`, which lives in **Bionic's `liblog`**.

I verified the fix is already in place, in the systems rather than the recipe:

| system | file:line |
| --- | --- |
| `aarch64-android21` | `packages/aarch64-android21/generic.lua:85` — `LDFLAGS="$LDFLAGS -llog"` |
| `aarch64-android24` | `packages/aarch64-android24/generic.lua:86` |
| `aarch64-android35` | `packages/aarch64-android35/generic.lua:85` |
| `x86_64-android35` | `packages/x86_64-android35/generic.lua:81` |

Each is commented in place: *"liblog.so is in every NDK sysroot"* and, in the
android21 case, *"at consumer link time; liblog.so is in every NDK sysroot and
the glog's own -llog never fires here"*. So `libabsl_log.a`'s reference to
`__android_log_write` resolves **at consumer link time from `$LDFLAGS`**, which
cmake picks up for the static-archive link lines it generates.

**Therefore the recipe must not add `-llog`.** Adding it would duplicate the
flag, and it would be a target fact in a system-neutral file — the exact thing
AGENTS.md forbids. The dependency is satisfied by the **system's `LDFLAGS`**,
not by anything in `packages/protobuf/generic.lua`.

This matters here more than for most packages, because **protobuf is a static
library and so is abseil**: the undefined `__android_log_write` is not resolved
until something links both archives, and protobuf does not itself link
abseil's log sink into a shared object. The *builder* will hit `undefined
symbol: __android_log_write` if `-llog` is missing — and the first thing to
check should be the system's `LDFLAGS`, not this recipe.

`x86_64-mingw` and `clang-native` are unaffected: `__ANDROID__` is not
predefined, so abseil's sink is not compiled at all.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | abseil is found by `find_package(absl CONFIG)` at `cmake/abseil-cpp.cmake:16`, resolved from `$CMAKE_PREFIX_PATH=$PREFIX` (in `$CMAKE_FLAGS`). If it were **not** found, `:20` would fall through to `FetchContent` of abseil from GitHub at `:24-29` — a network fetch inside a cross build, which the `require("abseil-cpp")` above prevents. The abseil in the prefix is 20260817.0, newer than the `20250512.1` pinned at `cmake/dependencies.cmake:15`, so the `find_package` path is the right one. `-llog` comes from the system's `LDFLAGS` (see above). protoc off ⇒ LIBPROTOC off ⇒ LIBUPB off, no forcing warning. No host program is compiled: tests and conformance are off, examples are off upstream, and `protoc` is off. |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above; `__ANDROID__` is predefined here too, so the same `-llog` path applies (`packages/x86_64-android35/generic.lua:81`). |
| `x86_64-mingw` | **WILL BUILD** | `__ANDROID__` is not defined, so no `AndroidLogSink` and no `liblog` concern at all. `abseil-cpp` and `protobuf` both support mingw-w64 and this tree already builds abseil there. `protobuf_BUILD_SHARED_LIBS=OFF` avoids the MSVC-DLL path; on mingw cmake does not set `MSVC`, so the `BUILD_SHARED_LIBS AND MSVC` abseil branch at `cmake/abseil-cpp.cmake:45` is not taken. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3; `__ANDROID__` undefined, no liblog. |

**API level notes.** **No new wall.** protobuf's own runtime
(`src/google/protobuf/`) uses `mmap`/`munmap`/`open`/`read`/`write`/`close`,
`malloc`, `memcpy`, `atomic` operations and `std::mutex`/`std::condition_variable`
— libc++ header facilities whose implementations are in Bionic's libc at every
API level. It does **not** call `mktime_z` (API 35) — the `.proto` timestamp
helpers use `time()` and `localtime()`. It does not call `nl_langinfo`
(API 26), `iconv` (API 28) or `posix_spawn` (API 28). **The API level is inert.**

**Risks / what a reviewer should check.**
1. **`protobuf_BUILD_LIBUPB=OFF` is honoured *only* because protoc is off.**
   This is the single most important thing to re-check on any version bump: if
   upstream changes the `:124` cascade so that `LIBPROTOC` is on by default,
   the `:132` branch would print its WARNING and silently re-enable libupb, and
   the flag would become inert — a silent scope change, not a failure.
2. **A stale build directory would keep a protoc/libupb from a previous
   configure.** The freshness stamp covers the recipe file, so an ordinary
   rebuild is clean, but a manual re-run inside a dirty `$WORK` could retain
   cached option values.
3. **`protobuf_WITH_ZLIB=OFF` is a real narrowing.** `CMakeLists.txt:199` would
   otherwise `find_package(ZLIB)` and define `HAVE_ZLIB`, giving protobuf gzip
   support for the wire format. Turning it off removes `zlib` from the runtime
   link. This is a deliberate minimality choice for a target prefix, and the
   `zlib` require is then only there so the package is present in the prefix for
   *other* consumers. **A reviewer who wants zlib-backed protobuf should delete
   that one flag** — it is the only flag in this recipe that removes capability
   rather than removing host programs.
4. **`protobuf_INSTALL` is left ON** (default, `:31`) and gates
   `cmake/install.cmake` at `:376-378`. It also feeds
   `utf8_range_ENABLE_INSTALL` (`cmake/utf8_range.cmake:10`), so turning it off
   would also drop the vendored utf8_range install.
5. **The static-archive link is where `-llog` surfaces.** protobuf's own
   archives will not fail to build; the undefined `__android_log_write` appears
   when `libabsl_log.a` is first linked into an executable. `stage3.md` should
   record whether that happened and, if so, that the cause was `$LDFLAGS`, not
   this recipe.
6. **Version skew in the prefix is fine in one direction only.** abseil
   20260817.0 > protobuf's pinned 20250512.1, so the `find_package` path wins.
   If abseil were ever *downgraded* below 20250512.1, `cmake/dependencies.cmake`
   would be reached and the FetchContent path would fire.

**How to verify once built.**
- `lib/libprotobuf.a`, `lib/libprotobuf-lite.a`, `include/google/protobuf/message.h`,
  `include/google/protobuf/descriptor.pb.h`, `lib/pkgconfig/protobuf.pc`,
  `lib/cmake/protobuf/protobufConfig.cmake`
- `pkg-config --modversion protobuf` → `7.36.2` — **note this is not `36.2`.**
  `CMakeLists.txt` sets `protobuf_VERSION_STRING "7.36.2"` (a distinct upstream
  numbering: major 7, then 36.2). `pkg-config --modversion protobuf` reporting
  `7.36.2` is correct, not a bug.
- `llvm-objdump -f lib/libprotobuf.a | head` → `elf64-littleaarch64` on aarch64
- **LIBUPB check (the one that matters):**
  `ls $PREFIX/lib/libupb*` → must be **empty**, and `ls $PREFIX/lib/libprotoc*`
  → must be **empty**, and `ls $PREFIX/bin/protoc*` → must be **empty**.
  A `libupb.a` present means the `:132` forcing branch fired and
  `protobuf_BUILD_LIBUPB=OFF` was overridden.
- **`-llog` check:** `llvm-nm -u $PREFIX/lib/libabsl_log.a | grep -c __android_log_write`
  → 1 on Android (expected), and then confirm the link succeeds using the
  system's `LDFLAGS`. On mingw and native the same grep → 0.
- `grep -m1 'Requires' lib/pkgconfig/protobuf.pc` should list the absl modules
  (`cmake/install.cmake:3-17` builds that list from
  `protobuf_ABSL_USED_TARGETS`)
- `llvm-nm -u lib/libprotobuf.a | grep -cE 'deflate|inflate'` → **0**, confirming
  `protobuf_WITH_ZLIB=OFF`
- Rerun should print `skip protobuf (fresh)`.