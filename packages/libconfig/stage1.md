# libconfig 1.8.2 — stage 1 build forecast

- **Package:** libconfig
- **Version:** 1.8.2 (release published 2025-12-14; latest stable on the
  hyperrealm/libconfig tag list)
- **Upstream URL:** `https://github.com/hyperrealm/libconfig/archive/refs/tags/v1.8.2.tar.gz`
  (HTTP 200, 3 339 502 bytes, top directory `libconfig-1.8.2/`)
- **Build system actually used: CMake**, *not* autotools. See below.

## The release has no generated `configure`

`tar tzf` over the tag archive shows only `libconfig-1.8.2/configure.ac`,
`libconfig-1.8.2/ac_config.h.in`, `libconfig-1.8.2/Makefile.am`,
`libconfig-1.8.2/aux-build/` and the rest of the autotools *inputs*. There is
no `libconfig-1.8.2/configure`, no `aclocal.m4`, no `Makefile.in`, no
`lib/Makefile.in`. `libconfig-1.8.2/CMakeLists.txt` **is** present.

That matters for two reasons:

1. `./configure` does not exist in the tarball, so the autotools route needs
   `autoreconf -fi` first. That needs autoconf, automake, libtool, flex and
   bison as build requirements — packages `autoconf`, `automake`, `libtool`,
   `flex` and `bison` all exist under `packages/`, but pulling five build-time
   dependencies in to get a library that already ships a working CMake build
   is the wrong trade.
2. The config header is named `ac_config.h.in`, **not** `config.h.in`
   (`AC_CONFIG_HEADERS(ac_config.h)` at `configure.ac:8`). The AGENTS.md
   timestamp guard names `config.h.in`; on the autotools path it would have to
   name `ac_config.h.in` instead. Another reason not to go there.

**The recipe uses CMake and the autotools timestamp guard does not apply** —
there is no `./configure` in it.

Also note `configure.ac:13` contains a literal `sleep 3`, so even the
autotools path costs three seconds of wall clock for nothing.

## What the package installs

With `BUILD_SHARED_LIBS=OFF`, `BUILD_EXAMPLES=OFF`, `BUILD_TESTS=OFF` and
upstream's default `BUILD_CXX=ON`:

| Artifact | Comes from |
| --- | --- |
| `lib/libconfig.a` | `add_library(config ...)` at `lib/CMakeLists.txt:61` |
| `lib/libconfig++.a` | `add_library(config++ ...)` at `lib/CMakeLists.txt:64` |
| `include/libconfig.h` | `PUBLIC_HEADER` property, `lib/CMakeLists.txt:80-82` |
| `include/libconfig.h++` | `PUBLIC_HEADER` on the C++ target |
| `lib/pkgconfig/libconfig.pc` | `lib/CMakeLists.txt:204-218` (UNIX only) |
| `lib/pkgconfig/libconfig++.pc` | `lib/CMakeLists.txt:209-224` (UNIX only) |
| `lib/cmake/libconfig/libconfigConfig.cmake` | `install(EXPORT ...)`, `lib/CMakeLists.txt:193-197` |
| `lib/cmake/libconfig/libconfigConfigVersion.cmake` | `lib/CMakeLists.txt:199-202` |

No tools are installed. The C++ headers are public, so a C++ compiler is a
build requirement on every system.

The two `.pc` files are `configure_file`'d from
`lib/libconfig.pc.cmake.in` / `lib/libconfig++.pc.cmake.in` and embed
`@CMAKE_INSTALL_PREFIX@` literally, so their `libdir`/`includedir` are
absolute `$OUT` paths. The emitter rewrites staged `.pc` `$OUT` to `$PREFIX`
(AGENTS.md "The generated script"), so `pkg-config --modversion libconfig`
works from the nest.

**On `x86_64-mingw` there is no `.pc` file at all**, and that is upstream's
doing, not ours: the whole block is wrapped in `if (UNIX)`
(`lib/CMakeLists.txt:204`) and closed at `lib/CMakeLists.txt:225`. With
`CMAKE_SYSTEM_NAME Windows` in
`packages/x86_64-mingw/x86_64-w64-mingw32-toolchain.cmake`, cmake does not set
`UNIX`, so neither `libconfig.pc` nor `libconfig++.pc` is installed. The
CMake package config under `lib/cmake/libconfig/` is installed regardless.


## Dependencies

None. libconfig is a C99 parser/printer with no library dependencies at all
(`lib/CMakeLists.txt` links `shlwapi` only on `WIN32`, at
`lib/CMakeLists.txt:157`). So `generic.lua` requires only `libconfig@source`.

`libconfig++` needs a C++ compiler, which every one of our systems exports
(`$CXX`). libconfig's CMake does not set a C++ standard, so each compiler's
default applies — that is a C++98-compatible codebase
(`lib/libconfig.h++` uses `std::string` and `std::exception`, nothing newer),
so any default is fine.

## Per-system verdict

Note first: **armv7a, i686 and x86_64 Android targets behave exactly like
aarch64** for this package — libconfig is plain C99 with no arch-specific code
and no SIMD — **except that the API level (21 vs 24 vs 35) is the real
variable**, because the one thing libconfig probes for that could differ by
API level is `newlocale`/`uselocale`/`freelocale`. I checked the API-21 case
directly and it is fine (see below), so no line below calls out an API-level
difference. The API-level column is listed for completeness.

| System | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | CMake 3.10 minimum (`libconfig-1.8.2/CMakeLists.txt:1`), satisfied by the cmake in the nest. `check_symbol_exists(newlocale "locale.h")` (`lib/CMakeLists.txt:110`) links a probe program; all three locale functions are declared unconditionally in the NDK 28.2 sysroot `usr/include/locale.h:102-107` with **no `__INTRODUCED_IN` guard**, so they exist at API 21, and `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` (`packages/aarch64-android21/generic.lua:118`) turns cmake's try-compile into an archive, which needs no runnable binary. Nothing in `lib/*.c` touches anything API-24+. `LDFLAGS` carries `-lm` (`packages/aarch64-android21/generic.lua:78`), which libconfig does not need but does not object to. |
| `aarch64-android24` | **WILL BUILD** | Identical to `aarch64-android21`; same sysroot header, same locale declarations, no API-24 gate involved. |
| `aarch64-android35` | **WILL BUILD** | Identical. The only version-sensitive thing in the whole build is the locale probe, and that header has no version gating. |
| `x86_64-android35` | **WILL BUILD** | Identical reasoning; nothing in libconfig is architecture-dependent (`grep` for `__aarch64__`/`__x86_64__`/`__i386__`/`__arm__` across `lib/` returns nothing). |
| `x86_64-mingw` | **WILL BUILD**, one caveat | CMake sees `WIN32` (the toolchain file sets `CMAKE_SYSTEM_NAME Windows`), so `lib/CMakeLists.txt:157` adds `shlwapi`, which mingw-w64 ships (`libshlwapi.a`). The locale probes **fail** on mingw: `grep -n 'uselocale\|newlocale' /usr/x86_64-w64-mingw32/include/locale.h` returns nothing, so `HAVE_USELOCALE`/`HAVE_NEWLOCALE`/`HAVE_FREELOCALE` are all off. That selects the `#warning "No way to modify calling thread's locale!"` branch at `lib/libconfig.c:116` and the matching one at `lib/libconfig.c:137`. `#warning` is a diagnostic, not an error, so the build completes; **it is only a warning because nothing in the recipe or the system passes `-Werror`**. libconfig behaves correctly anyway: on Windows it is compiled with `LIBCONFIG_WINDOWS_OS` *and* `LIBCONFIG_MINGW_OS` (`lib/wincompat.h:29,32-33`) and takes neither the `_configthreadlocale` path (gated on `!LIBCONFIG_MINGW_OS`, `lib/libconfig.c:101`) nor the locale path, so it runs with the process locale — the same behaviour any Windows libconfig build has. No `.pc` file ships here (see above). |
| `clang-native` | **WILL BUILD** | Plain x86_64 Linux, cmake 4.4.3 satisfies the 3.10 minimum. `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is already in `packages/clang-native/generic.lua:57` and is irrelevant here (3.10 > 3.5). `ccache` may be found by `find_program` at the top-level `CMakeLists.txt:43`, which only sets a launch rule; harmless. |

### Not a blocker, but worth recording

- **`configure.ac:13` has a literal `sleep 3`.** Only reachable on the
  autotools path, which we do not take. Recorded so nobody later "simplifies"
  the recipe into autotools and loses three seconds per build.
- **`set_version_info_from_makefile("Makefile.am" ...)`**
  (`lib/CMakeLists.txt:88`, plus `:90` for the C++ target) reads
  `lib/Makefile.am` with a regex for
  `VERINFO = -version-info X:Y:Z` and calls `message(FATAL_ERROR)` if it does
  not match (`lib/CMakeLists.txt:7`). `lib/Makefile.am:21` has
  `VERINFO = -version-info 15:0:0`, so it matches. It is `FATAL_ERROR`, so a
  future upstream reformat of that line breaks configure loudly rather than
  silently — worth re-checking on any version bump.

## For a reviewer to scrutinise

1. **`BUILD_CXX=ON` is upstream's default and I left it on.** That means
   `generic.lua` pulls a C++ toolchain into five otherwise C-only packages.
   All six systems export `$CXX`, so it costs nothing today. But if a future
   system has no C++ compiler, this package needs `-DBUILD_CXX=OFF` and the
   C++ headers/`libconfig++.pc` silently disappear. Flagging it as the
   most likely thing to need revisiting.
2. **I turn off `BUILD_EXAMPLES` and `BUILD_TESTS` and leave `BUILD_FUZZERS` at
   its default `OFF`.** `BUILD_FUZZERS` is additionally gated on
   `DEFINED ENV{LIB_FUZZING_ENGINE}` (`CMakeLists.txt:33`), so it cannot fire
   in our environment either way.
3. **The `check_symbol_exists` probes are real link tests.** On the cross
   systems `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` makes them
   archive-only, so a *declaration* without a *definition* would read as
   "present". For these three functions Bionic declares and defines them
   together, so the result is right either way — but the probe is weaker than
   it looks on a cross build. Not a problem here; noting the mechanism.