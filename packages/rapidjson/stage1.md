# rapidjson 1.1.0 — stage 1 build forecast

- **Package:** rapidjson
- **Version:** 1.1.0 (release `v1.1.0`, published 2016-08-25)
- **Upstream URL:** `https://github.com/Tencent/rapidjson/archive/refs/tags/v1.1.0.tar.gz`
  (HTTP 200, 1 019 402 bytes, top directory `rapidjson-1.1.0/`)
- **Build system actually used: CMake** (`CMAKE_MINIMUM_REQUIRED(VERSION 2.8)`)
- **No autotools anywhere** — no `configure`, no `configure.ac`, no
  `Makefile.in`. **The autotools timestamp guard does not apply.**

## Plainly: 1.1.0 is still the newest release, and it is nine years old

The Tencent/rapidjson release list has exactly three entries — `v1.1.0`,
`v1.0.2`, `v1.0.1` — and the tag list has five, with `v1.1.0` the newest.
**There is no v1.1.1 or later.** Upstream's activity after 1.1.0 has been on
`master`/`v2.0.0_devel` branches, not in releases. Anyone expecting a recent
version number here is looking for one that does not exist.

Also worth stating: the archive **is** a usable git tag archive, and unlike
zopfli and nanopb it ships no generated build system — but it does **not** need
one, because rapidjson is header-only. `CMakeLists.txt` has **no `add_library`
anywhere in the file**; it only installs headers and metadata.

One consequence worth flagging: the release predates the `thirdparty/gtest`
submodule being useful, and the tag archive's `thirdparty/gtest/` is
**empty** (`.gitmodules` points at google/googletest but a tag archive cannot
carry submodule content). Upstream's own CMake handles this gracefully —
`test/CMakeLists.txt` wraps everything in `IF(GTESTSRC_FOUND)` — so tests
silently build nothing rather than failing.

## What the package installs

With `RAPIDJSON_BUILD_DOC=OFF`, `RAPIDJSON_BUILD_EXAMPLES=OFF`,
`RAPIDJSON_BUILD_TESTS=OFF`:

| Artifact | Comes from |
| --- | --- |
| `include/rapidjson/**` (headers only) | `install(DIRECTORY include/rapidjson ...)`, `CMakeLists.txt:144-146` |
| `lib/pkgconfig/RapidJSON.pc` | `CONFIGURE_FILE` + `INSTALL`, `CMakeLists.txt:132-137`, template `RapidJSON.pc.in` |
| `lib/cmake/RapidJSON/RapidJSONConfig.cmake` | `CMakeLists.txt:163-168`, template `RapidJSONConfig.cmake.in` |
| `lib/cmake/RapidJSON/RapidJSONConfigVersion.cmake` | `CMakeLists.txt:166-168` |
| `share/doc/RapidJSON/readme.md` | `CMakeLists.txt:140-142` |
| `share/doc/RapidJSON/examples/**` (source files, not binaries) | `install(DIRECTORY example/ ...)`, `CMakeLists.txt:148-155` |

**No library file.** That is not an omission in the recipe: rapidjson is a
header-only C++ library and there is no `add_library` in its `CMakeLists.txt`.
`lib/` contains no `.a` and `bin/` contains nothing — the only executable-ish
content is the `.json` test corpus under `bin/`, which is data, not installed.

`RapidJSON.pc` is generated from `RapidJSON.pc.in` with
`includedir=@INCLUDE_INSTALL_DIR@`, and `INCLUDE_INSTALL_DIR` is
`${CMAKE_INSTALL_PREFIX}/include` (`CMakeLists.txt:96`) — an absolute `$OUT`
path that the emitter rewrites to `$PREFIX` in staged `.pc` files. So
`pkg-config --cflags rapidjson` works from the nest.

Because `cmake --install` runs the install rules regardless of what was built,
and nothing needs to be built, the `cmake --build` step in the recipe is
genuinely empty. It is still there so the recipe reads like every other one
and so the step count stays uniform.

## Dependencies

None. rapidjson is pure headers over the C++ standard library — no zlib, no
system library, nothing. `generic.lua` requires only `rapidjson@source`.

A C++ compiler is required at *consume* time, not build time, since nothing
is compiled.

## Per-system verdict

Standing caveats: **armv7a, i686 and x86_64 Android targets behave exactly
like aarch64** for this package — rapidjson ships no source to compile, so
architecture is completely irrelevant; there is not a single `.c`/`.cpp` file
in the install set. **The API level (21 vs 24 vs 35) is the real variable**
and it reaches this package in exactly one place if anything is compiled: the
C++ standard library that libc++ exposes from each API level. Since the recipe
compiles nothing, no header is parsed and no `libc++` symbol is referenced, so
there is no API-level difference between the 21, 24 and 35 rows.

| System | Verdict | Reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** (with the flag that makes it work) | `CMAKE_MINIMUM_REQUIRED(VERSION 2.8)` is below cmake 4's floor of 3.5 and would otherwise be a hard error. `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` (`packages/aarch64-android21/generic.lua:127`) is what makes it configure; I confirmed the mechanism under the installed cmake 4.4.3 with a scratch project declaring `CMAKE_MINIMUM_REQUIRED(VERSION 2.8)` — deprecation warning, exit 0. `PROJECT(RapidJSON CXX)` (`CMakeLists.txt:12`) needs `$CXX`, which the system exports; nothing runs a try-compile that would need a target binary because `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` is set at `:118`. **The important caveat is `-march=native`:** `CMakeLists.txt:76` appends `-march=native -Wall -Wextra -Werror -Wno-missing-field-initializers` to `CMAKE_CXX_FLAGS` unconditionally for Clang (and `:53` does the same for GNU). I tested the aarch64 NDK compiler directly: `aarch64-linux-android21-clang -march=native -c t.c` fails with `clang: error: unsupported argument 'native' to option '-march='`. **`-march=native` is only accepted because `CMAKE_CXX_FLAGS` is never applied to a compile in this configuration** — with all three build options off there are no translation units. If anyone re-enables `RAPIDJSON_BUILD_EXAMPLES` (or the tests), this package breaks on every aarch64 and armv7a target immediately. This is the single most important line in this forecast. |
| `aarch64-android24` | **WILL BUILD** (same caveat) | Identical, including the `-march=native` finding — the error is about the *architecture*, not the API level, so 24 and 35 fail the same way if anything is compiled. |
| `aarch64-android35` | **WILL BUILD** (same caveat) | Identical. Verified separately: `x86_64-linux-android35-clang -march=native -c` **succeeds**, and `armv7a-linux-androideabi35-clang -march=native -c` **fails** with the same `unsupported argument 'native'` message — so if this recipe ever compiles, the aarch64 and armv7a Android rows fail and only x86_64/i686 Android would survive. That asymmetry is worth stating explicitly. |
| `x86_64-android35` | **WILL BUILD** | Identical reasoning, and here `-march=native` would even be accepted if something were compiled (`x86_64-linux-android35-clang -march=native` exits 0). Nothing is compiled, so it does not matter today. |
| `x86_64-mingw` | **WILL BUILD** | `x86_64-w64-mingw32-gcc -march=native -c` exits 0, so even the flag would be fine here; nothing is compiled anyway. `CMAKE_MINIMUM_REQUIRED(VERSION 2.8)` is handled by `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` at `packages/x86_64-mingw/generic.lua:69`. `PROJECT(RapidJSON CXX)` uses `$CXX` = `x86_64-w64-mingw32-g++`, which the system exports. The `WIN32` path at `CMakeLists.txt:102-103` changes only the directory the CMake config lands in (`${CMAKE_INSTALL_PREFIX}/cmake` instead of `lib/cmake/RapidJSON`); note that the `.pc` file's destination at `:136` uses `LIB_INSTALL_DIR`, which is hardcoded to `${CMAKE_INSTALL_PREFIX}/lib` at `:97` and is **not** affected by `WIN32`, so `RapidJSON.pc` still lands in `lib/pkgconfig`. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3, `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` at `packages/clang-native/generic.lua:57`. `ccache` may be picked up by `find_program(CCACHE_FOUND ccache)` at `:43`, which only sets a rule-launch property; with nothing compiled it has no effect. `CMAKE_BUILD_TYPE` is forced to `RelWithDebInfo` if empty (`:20-22`), which likewise only sets flags on compile rules that do not exist. |

## For a reviewer to scrutinise

1. **The recipe works by turning everything off, and that is fragile in a way
   worth naming.** `RAPIDJSON_BUILD_EXAMPLES=OFF` is not cosmetic: it is the
   only thing preventing `-march=native` from reaching an aarch64/armv7a
   compiler, where it is a hard error (`CMakeLists.txt:53,76`). If a future
   reviewer turns examples back on "so we get the sample tools", this package
   breaks on four of the six systems with a confusing error. I could not fix
   that in the recipe — the flag comes from upstream unconditionally and
   AGENTS.md forbids `sed` and patches — so the comment in `generic.lua` says
   why the option is off.
2. **`-Werror` is also in that same upstream flag block** (`:53,76`), and
   `-Weffc++` is added again inside `example/CMakeLists.txt` for GNU. A 2016
   codebase under `-Werror` with a 2026 compiler would be a wall of warnings.
   Same root cause, same reason it is currently harmless.
3. **`CMAKE_BUILD_TYPE` defaults to `RelWithDebInfo`** upstream
   (`CMakeLists.txt:20-22`) and `ZOPFLI_DEFAULT_RELEASE`-style overrides do not
   apply here. No effect while nothing compiles.
4. **The version is nine years old and there is no newer release.** Not a
   recipe problem. The tag is `v1.1.0`, so the URL in `source.lua` is pinned to
   a tag that will not move; a fork or the `v2.0.0_devel` branch would be a
   different package decision, not an update.
5. **`export(PACKAGE ${PROJECT_NAME})` at `CMakeLists.txt:160` writes into the
   user's cmake package registry** (`~/.cmake/packages/RapidJSON`) unless
   `CMAKE_EXPORT_NO_PACKAGE_REGISTRY` is set. I confirmed with a scratch
   project that cmake 4.4.3 still honours `export(PACKAGE)` this way. It does
   not fail the build and does not touch `$OUT`, but it is a write outside the
   nest caused by configuring this package. Flagging it; not fixing it, since
   the only lever would be adding `-DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=ON` to
   the recipe, which a reviewer may or may not want.