# cmark build forecast

- **Package:** cmark
- **Version:** 0.31.2 (release 2026-02-14, newest on commonmark/cmark)
- **Upstream URL:** `https://github.com/commonmark/cmark/archive/refs/tags/0.31.2.tar.gz`
  (HTTP 200, 267 259 bytes, top directory `cmark-0.31.2/`)
  The release list has **no assets**, so the git tag archive is the only form.
- **Build system: cmake** — **NOT autotools.** This corrects the assignment's
  "cmark is autotools". See below.
- **Config template: none.** No `AC_CONFIG_HEADERS` because there is no
  `configure.ac`. **No timestamp guard applies and none is written.**
- **Dependencies required: none.** No `require()` of any other package.
- **Installs:** `lib/libcmark.a`, `include/cmark.h`, `include/cmark_ctype.h`,
  `lib/pkgconfig/libcmark.pc`, `lib/cmake/cmark/cmarkConfig.cmake` +
  version + targets, `bin/cmark` (the reference CLI), `share/man/man1/cmark.1`,
  `share/man/man3/cmark.3`.
- **Upstream ships both a `.pc` file and a CMake package config** —
  `src/libcmark.pc.in` and `src/cmarkConfig.cmake.in` are both in the tarball.

### The autotools correction

The assignment said "cmark is autotools". **It is not, at 0.31.2.** I listed the
archive and there is no `configure`, no `configure.ac`, no `aclocal.m4`, no
`Makefile.am` anywhere in it. The complete top level is:

```
CMakeLists.txt  Makefile  Makefile.nmake  Makefile.nmake  nmake.bat
README.md  changelog.txt  toolchain-mingw32.cmake  shell.nix
.editorconfig  .gitattributes  .gitignore  COPYING  benchmarks.md  why-cmark-and-not-x.md
```

So there are **two** hand-written build systems (a plain `Makefile` and an
nmake one for native Windows), plus cmake. The only `.in` files are
`src/cmarkConfig.cmake.in`, `src/cmark_version.h.in` and
`src/libcmark.pc.in` — all cmake, none an autotools config template.
**The recipe takes cmake** and there is no timestamp guard to write.

### Are the extension/test programs built by default?

**The test programs: yes, and that is the flag that matters.**

- `CMakeLists.txt:20` — `include(CTest)`, which **defines `BUILD_TESTING` as ON**
  by default.
- `CMakeLists.txt:117-120` — `if(BUILD_TESTING)` adds `add_subdirectory(api_test)`
  and `add_subdirectory(test)`. Both are host test programs that link the
  library and run it.

So `BUILD_TESTING=OFF` is load-bearing on a cross build, and it is the *only*
lever: cmark ships no `CMARK_TESTS` option of its own.

**The extensions: no, they are not built.** The test/extensions tree is reached
*only* through that `BUILD_TESTING` branch. There is no separate extension
option to disable, and `CMARK_LIB_FUZZER` (`CMakeLists.txt:53`) — the one other
thing that adds a subdirectory — defaults **OFF**.

**`bin/cmark` is built and installed unconditionally.**
`src/CMakeLists.txt:54` has a plain `add_executable(cmark_exe ...)` with no
guard, and `:63` installs it. That is a *target* executable: on a cross build it
compiles fine and is never run here. Same situation as `flac`/`metaflac` in
`packages/flac/stage1.md`.

**The man pages: installed, and only on non-Windows.**
`CMakeLists.txt:114-116` is
`if(NOT CMAKE_SYSTEM_NAME STREQUAL Windows) add_subdirectory(man) endif()`,
with upstream's own comment at `:112-113`: *"should this be enabled for MinGW,
which sets CMAKE_SYSTEM_NAME to Windows, but defines `MINGW`."*
`man/CMakeLists.txt` only ever does two `install(FILES ...)` of pre-built
`cmark.1` and `cmark.3` — no roff tooling runs.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | Testing off removes both host subdirectories. What remains is `libcmark` (`src/CMakeLists.txt`) and `cmark_exe`. cmark is strict C89/C99-with-prototypes; `CMakeLists.txt:87-92` adds `-Wall -Wextra -pedantic` and `-Wstrict-prototypes` but **no `-Werror`**, so warnings cannot fail the build. Its libc surface is `calloc`/`realloc`/`free`, `memcpy`, `strlen`, `fopen`/`fread`/`fwrite` and `printf` — no POSIX-only call at all (see the mingw row, which corrects a `popen` claim in my first draft). **No API-24+ symbol.** |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above. |
| `x86_64-mingw` | **WILL BUILD** | The verdict is unchanged but my first draft's evidence for it cited a `popen` call in `src/cmdline.c` **that does not exist** — there is no `cmdline.c` in the tree and `grep` for `popen` over every `src/*.c` and `src/*.h` returns zero hits. Here is the evidence that is real. (1) The `man/` subdirectory is **skipped**, because our toolchain file sets `CMAKE_SYSTEM_NAME Windows` (`packages/x86_64-mingw/x86_64-w64-mingw32-toolchain.cmake:2`) and `CMakeLists.txt:114` is `if(NOT CMAKE_SYSTEM_NAME STREQUAL Windows) add_subdirectory(man) endif()` — with upstream's own TODO at `:112-113` noting MinGW sets `MINGW` but not the system name. No man pages install here, by upstream's design. (2) cmark has **no sockets, no threads, no `poll`, no `fork` and no `popen`**; the whole POSIX surface of the CLI is `fopen`/`fread`/`printf`/`fwrite` plus one Windows-only branch, `main.c:17-20` → `#if defined(_WIN32) && !defined(__CYGWIN__) #include <io.h> #include <fcntl.h> #endif`, used at `main.c:95-98` for `_setmode(_fileno(stdin), _O_BINARY)`. mingw-w64 supplies `<io.h>` and `<fcntl.h>`, so the branch compiles and the *other* branch is never taken. (3) `CMakeLists.txt:87-92` adds `-pedantic` but **no `-Werror`**, so GCC 16's diagnostics are warnings and cannot fail the build. (4) The build is `add_library` plus one `add_executable` (`src/CMakeLists.txt:54`), so nothing is executed at build time. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux, cmake 4.4.3; `cmake_minimum_required(VERSION 3.14)` is satisfied, and the systems' `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is irrelevant at 3.14. |

**API level notes.** **No new wall.** cmark's core is a CommonMark parser with
no I/O beyond stdio and no platform dependency, and the CLI is
`fopen`/`fread`/`printf` — my first draft said the CLI "adds `popen` for the
`--paginate` option", and that is wrong on both counts: there is no `popen`
anywhere in `src/`, and `main.c`'s `print_usage` (`:31-46`) lists no
`--paginate` option at all. None of the AGENTS.md API-21 absences applies, and
there is no use of `nl_langinfo` (API 26), `iconv` (API 28) or `mktime_z`
(API 35) — cmark does its own UTF-8 validation internally (`src/utf8.c`).
**The API level is inert.**

**Parallelism / memory:** **does not need a parallel build, and the recipe does
not ask for one.** cmark is two translation units' worth of library plus one
executable; `cmake --build build --parallel 1` is the only build invocation and
peak memory is far under the 2 GB rule. Nothing in cmark's build scripts
requires or assumes parallelism.

**Risks / what a reviewer should check.**
1. **`BUILD_TESTING=OFF` is load-bearing and non-obvious**, because it is
   `include(CTest)` at `:20` that silently defaults it ON — not a
   cmark-specific option. Without it, `api_test` and `test/` are added as host
   programs on a cross build.
2. **The man pages do not install on mingw**, by upstream design
   (`CMakeLists.txt:114`). A reviewer verifying the install set on mingw should
   expect `share/man` to be **empty** and should not read that as a failure.
   This is the one place the two families' install sets legitimately differ.
3. **`CMARK_SHARED` / `CMARK_STATIC` are deprecated** — `CMakeLists.txt:36-52`
   emits `message(AUTHOR_WARNING)` if either is defined and tells you to use
   `BUILD_SHARED_LIBS`. The recipe uses the standard name, so the warning does
   not fire. Worth knowing in case a reviewer greps for `CMARK_STATIC` and
   concludes the recipe is wrong.
4. **`CMARK_LIB_FUZZER=OFF` is the default and is left alone.** It would add
   `-fsanitize=fuzzer` flags (`CMakeLists.txt:100-108`) and
   `add_subdirectory(fuzz)` at `:121-123`.
5. **`bin/cmark` installs on every system.** Unavoidable — there is no upstream
   switch for it, and `src/CMakeLists.txt:63` installs `cmark_exe` in the same
   `install(TARGETS cmark_exe cmark ...)` as the library. Worth stating so a
   reviewer does not go looking for a flag that does not exist.
6. **`cmake_minimum_required(VERSION 3.14)`** means the systems'
   `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` is not needed here. Recording it so the
   absence of a cmake-version workaround is understood as correct rather than
   forgotten.

**How to verify once built.**
- `lib/libcmark.a`, `include/cmark.h`, `include/cmark_ctype.h`,
  `lib/pkgconfig/libcmark.pc`, `lib/cmake/cmark/cmarkConfig.cmake`
- `pkg-config --modversion libcmark` → `0.31.2` — **note the `lib` prefix**;
  `lib/libcmark.pc.in` uses that name and it is easy to type `cmark` instead
- `llvm-objdump -f lib/libcmark.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libcmark.a | grep -c cmark_parse_document` → non-zero
- **Testing check:** `find $PREFIX -name '*test*'` → empty, and
  `find $NESTDIR/tmp -name CMakeCache.txt -exec grep -l 'BUILD_TESTING:BOOL=ON' {} +`
  → empty. That is the check that the CTest default was overridden.
- `find $PREFIX/lib -name '*.so*'` → **empty**
- On mingw: `find $PREFIX/share/man` → **empty**, which is correct per risk 2
- `strings lib/libcmark.a | grep -m1 0.31.2` for the version stamp