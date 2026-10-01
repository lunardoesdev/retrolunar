ACCEPT

# cmark review (stage1: 0.31.2, `cmark-0.31.2.tar.gz`)

## The autotools claim: the assignment was wrong and the adder was right

The assignment asserted "cmark is autotools". It is not. I did not take the
adder's word for it — AGENTS.md:528-534 is explicit that an absence claim with
no command behind it is the weakest thing a review can make, so here is the
command and its output, run against the unpacked tree:

```
$ cd cmark-0.31.2
$ for f in configure configure.ac aclocal.m4 Makefile.am acinclude.m4 config.h.in; do
      printf "%-14s " "$f"; [ -e "$f" ] && echo PRESENT || echo absent; done
configure      absent
configure.ac   absent
aclocal.m4     absent
Makefile.am    absent
acinclude.m4   absent
config.h.in    absent

$ find . \( -name 'configure*' -o -name 'aclocal.m4' -o -name 'Makefile.am' \
        -o -name 'acinclude.m4' -o -name 'config.h.in' \) -print
   (no output)

$ grep -rn 'AC_CONFIG_HEADERS' .
   (no output)
```

Not one autotools artefact anywhere in the tarball. The top level is
`CMakeLists.txt`, `Makefile`, `Makefile.nmake`, `nmake.bat`,
`toolchain-mingw32.cmake` — two hand-written build systems plus cmake. The
recipe therefore writes **no timestamp guard**, which is exactly right: a
guard for a project with no `configure` is the inert-guard defect
(AGENTS.md:305-309) in mirror image. The adder's `generic.lua:9-12` comment
states this and is correct.

## What the recipe gets right

- **Version is current.** GitHub API: `0.31.2`, published 2026-02-14,
  **0 assets**, so the git tag archive is the only form.
  `source.lua`'s `archive/refs/tags/0.31.2.tar.gz` with `--strip-components=1`
  is right for top directory `cmark-0.31.2/`.
- **`BUILD_TESTING=OFF` is the right flag, it is the only lever, and it is
  load-bearing.** `CMakeLists.txt:20` is a bare `include(CTest)`, which
  defines `BUILD_TESTING` **ON**. `CMakeLists.txt:117-120`:
  ```cmake
  if(BUILD_TESTING)
    add_subdirectory(api_test)
    add_subdirectory(test testdir)
  endif()
  ```
  Those are host programs that link the library and run it. There is no
  `CMARK_TESTS` option — `CMakeLists.txt:53` declares only
  `CMARK_LIB_FUZZER` (OFF by default) and `BUILD_SHARED_LIBS` (`:54-55`).
  So `BUILD_TESTING` is genuinely the only handle, and the recipe uses it.
- **`CMARK_LIB_FUZZER` correctly left alone**: default OFF
  (`CMakeLists.txt:53`); ON would add `-fsanitize=fuzzer` (`:100-108`) and
  `add_subdirectory(fuzz)` (`:121-123`).
- **`BUILD_SHARED_LIBS=OFF` is right and the deprecation note is right.**
  `CMakeLists.txt:35` defaults it to `NO` already, and `:36-52` emits
  `message(AUTHOR_WARNING)` for the deprecated `CMARK_SHARED`/`CMARK_STATIC`.
  Stating it is harmless and makes the static shape explicit.
- **`cmake_minimum_required(VERSION 3.14)`** (`CMakeLists.txt:1`) means
  `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` in `$CMAKE_FLAGS` is not needed here —
  and the recipe does not rely on it, correctly.
- **System usage is clean**: `cmake -S . -B build $CMAKE_FLAGS …`,
  `cmake --build build --parallel 1`, `cmake --install build`. Prefix,
  toolchain file and prefix path all from `$CMAKE_FLAGS`. No `export`, no
  hardcoded target facts, no fan-out.
- **`require()`s resolve**: only `require("cmark@source")`, and
  `packages/cmark/source.lua` exists.

## The mingw row, which the assignment said was the one most likely wrong

It holds. Three separate claims, each checked against the tree or the system
files:

1. **Man pages are skipped on mingw, by upstream design.**
   `CMakeLists.txt:112-116`:
   ```cmake
   # TODO(compnerd) this should be enabled for MinGW, which sets CMAKE_SYSTEM_NAME
   # to Windows, but defines `MINGW`.
   if(NOT CMAKE_SYSTEM_NAME STREQUAL Windows)
     add_subdirectory(man)
   endif()
   ```
   And `packages/x86_64-mingw/x86_64-w64-mingw32-toolchain.cmake:4` is
   `set(CMAKE_SYSTEM_NAME Windows)`, so the condition is false and `man/` is
   skipped. `man/CMakeLists.txt` only does two `install(FILES ...)` of
   pre-built `cmark.1`/`cmark.3` — no roff tooling runs either way. So
   `share/man` empty on mingw is correct, not a failure. This is the one place
   the two families' install sets legitimately differ and `stage1.md` says so.

2. **The `popen` claim is FALSE, and it does not matter — but it must be
   corrected.** `stage1.md`'s mingw row asserts cmark's "only POSIX-shaped
   call is `popen`, which mingw-w64 supplies in `libmingw32`/`libmsvcrt` and
   which is reached through `src/cmdline.c` behind a Windows branch".
   **Neither `popen` nor `src/cmdline.c` exists.** Commands:
   ```
   $ grep -rn 'popen' cmark-0.31.2/
      (no output)
   $ ls cmark-0.31.2/src/cmdline.c
      ls: cannot access 'cmdline.c': No such file or directory
   ```
   The only `_WIN32` uses in the library are `src/main.c:17` and `src/main.c:95`,
   which include `<io.h>`/`<fcntl.h>` and call `_setmode(_fileno(stdin), _O_BINARY)`.
   The conclusion (no POSIX obstacle on mingw) is right; the stated evidence
   is invented. Per AGENTS.md:504-508 a false justification is a real defect
   because it is what makes the next person "fix" a correct flag — so this must
   be corrected in `stage1.md`. It does **not** change the verdict: the row is
   right for a different, verifiable reason (see 3).

3. **What actually settles it: no POSIX-only surface, and no `-Werror`.**
   The library and CLI use stdio plus `calloc`/`realloc`/`free`/`memcpy`/
   `strlen`. `CMakeLists.txt:86-93` adds `-Wall -Wextra -pedantic
   -Wstrict-prototypes` but **no `-Werror`**, so a `-pedantic` diagnostic
   under GCC 16 is a warning, not a stop. `CMakeLists.txt:7-9` sets
   `-std=c99` with extensions off, which mingw-w64 GCC 16 satisfies. And the
   tarball ships `toolchain-mingw32.cmake`, i.e. upstream CI-tests MinGW.
   I compiled all 19 library sources plus `main.c` against mingw-w64 GCC
   16.2.0: the only failures were my own stub missing the cmake-generated
   `cmark_export.h`, which `src/CMakeLists.txt:47-48`
   (`generate_export_header`) supplies in a real build. No upstream defect.

## Android API level: inert

Sweeping `src/` for the gap list (`posix_spawn`, `process_vm_readv`,
`POSIX_MADV_*`, `getpass`, `mblen`, `O_BINARY`, `nl_langinfo`, `iconv`,
`mktime_z`): **zero hits**. `src/main.c:97-99` does use `_O_BINARY`, but only
under `#if defined(_WIN32) && !defined(__CYGWIN__)` (`main.c:17`, `:95`), so the
Android rows never see it. cmark does its own UTF-8 validation in
`src/utf8.c` rather than calling `iconv`, and needs no locale. **The API
level really is inert** — 21, 24 and 35 compile the same sources.

## `bin/cmark` is built and installed on every system

`src/CMakeLists.txt:54-63` has an unguarded `add_executable(cmark_exe …)`
installed in the same `install(TARGETS cmark_exe cmark …)` as the library. It
is a **target** executable: it compiles on a cross build and is never run
here. There is no upstream switch for it. `stage1.md` records this correctly;
a builder should expect `bin/cmark` and not go hunting for a flag.

## Install list — two corrections to `stage1.md`

1. **`lib/cmake/cmark/cmarkConfig.cmake` does not exist.** The generated file
   is `cmark-config.cmake` (hyphen): `src/CMakeLists.txt:81-84`
   `configure_package_config_file("cmarkConfig.cmake.in" … "${CMAKE_CURRENT_BINARY_DIR}/generated/cmark-config.cmake")`,
   installed as `cmark-config.cmake` at `src/CMakeLists.txt:90-94`, alongside
   `cmark-config-version.cmake` and `cmark-targets.cmake`. Only the *input*
   template uses the capital-C no-hyphen spelling.
2. `share/man/man1/cmark.1` and `share/man/man3/cmark.3` are correct, and
   **absent on mingw** per item 1 above.

Everything else is real: `lib/libcmark.a`, `include/cmark.h`,
`include/cmark_ctype.h`, `include/cmark_export.h`, `include/cmark_version.h`
(`src/CMakeLists.txt:73-78`), `lib/pkgconfig/libcmark.pc` (`:70-71`),
`bin/cmark` (`:63-68`).

**`pkg-config --modversion libcmark` is `0.31.2`** — the `lib` prefix is real,
from `src/libcmark.pc.in:6` `Name: libcmark`. That is the module name, and
there is only one `.pc` in the tree.

## Carried to the build

| artifact | source of truth |
| --- | --- |
| `lib/libcmark.a` | `src/CMakeLists.txt:8,63-68` |
| `include/cmark.h`, `cmark_ctype.h`, `cmark_export.h`, `cmark_version.h` | `src/CMakeLists.txt:73-78` |
| `lib/pkgconfig/libcmark.pc` | `src/CMakeLists.txt:4-6,70-71` |
| `lib/cmake/cmark/cmark-config.cmake` (+ `-version`, `-targets`) | `src/CMakeLists.txt:81-100` |
| `bin/cmark` | `src/CMakeLists.txt:54-63` (unguarded) |
| `share/man/man{1,3}/cmark.{1,3}` | `man/CMakeLists.txt`; **skipped on mingw** |

### The ONE command that proves each

```sh
# the archive exists, is the right format, and holds the parser
test -f "$PREFIX/lib/libcmark.a" &&
llvm-objdump -f "$PREFIX/lib/libcmark.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libcmark.a" | grep -c cmark_parse_document
```
Expected: correct object format, non-zero count.

```sh
# all four headers, the .pc and the CMake config landed
test -f "$PREFIX/include/cmark.h" && test -f "$PREFIX/include/cmark_ctype.h" &&
test -f "$PREFIX/include/cmark_export.h" && test -f "$PREFIX/include/cmark_version.h" &&
test -f "$PREFIX/lib/pkgconfig/libcmark.pc" &&
test -f "$PREFIX/lib/cmake/cmark/cmark-config.cmake" &&
pkg-config --modversion libcmark
```
Expected modversion: `0.31.2`. Note the module name is **`libcmark`**, and the
config file is **`cmark-config.cmake`** with a hyphen — `cmarkConfig.cmake`
does not exist.

```sh
# THE BUILD_TESTING CHECK. Scoped to the package's own build tree, because
# $PREFIX is shared with every other package in the nest.
grep -E '^BUILD_TESTING:' build/CMakeCache.txt
```
Expected: `BUILD_TESTING:BOOL=OFF`. **Do not** use `find $PREFIX -name '*test*'`
as the check — `$PREFIX` holds every package's output and any file with
"test" in its name from another package makes it fail for no reason.

```sh
# no shared object: BUILD_SHARED_LIBS=OFF took effect
find "$PREFIX/lib" -maxdepth 1 -name 'libcmark.so*' | wc -l
```
Expected: `0`.

```sh
# the CLI is present and is a target binary we never run
file "$PREFIX/bin/cmark"
```

### On mingw only

```sh
find "$PREFIX/share/man" 2>/dev/null | wc -l
```
Expected: `0`, **correctly**. `CMakeLists.txt:114` skips `man/` when
`CMAKE_SYSTEM_NAME` is `Windows`. Do not report this as a missing artifact.