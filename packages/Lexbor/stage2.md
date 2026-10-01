REJECT

# Lexbor review (stage1: 3.0.0, `lexbor-3.0.0.tar.gz`)

## What the recipe gets right

- **Version is current.** GitHub API: `v3.0.0`, published 2026-03-31,
  **0 assets** — so the git tag archive is the only form.
  `source.lua`'s `archive/refs/tags/v3.0.0.tar.gz` with `--strip-components=1`
  is right for top directory `lexbor-3.0.0/`.
- **No autotools, so no guard.** No `configure`/`configure.ac`/`aclocal.m4`/
  `Makefile.am` anywhere. The recipe writes no timestamp guard, correctly.
- **`LEXBOR_BUILD_SHARED=OFF` is the only flag passed and it is the right one.**
  `CMakeLists.txt:52` declares `option(LEXBOR_BUILD_SHARED … ON)`, so shared
  **is** the upstream default and must be turned off.
- **Every other gate really is already OFF upstream**, and the recipe is right
  to leave them alone rather than restate them. All verified at
  `CMakeLists.txt:51-67`: `LEXBOR_BUILD_WASM` `:51` OFF, `LEXBOR_BUILD_EXAMPLES`
  `:53` OFF, `LEXBOR_BUILD_TESTS` `:54` OFF, `LEXBOR_BUILD_TESTS_CPP` `:55` OFF,
  `LEXBOR_BUILD_BENCHMARKS` `:57` OFF, `LEXBOR_BUILD_UTILS` `:58` OFF,
  `LEXBOR_BUILD_FUZZER` `:59` OFF. Those are exactly the `add_subdirectory`
  calls at `:367` (tests), `:375` (examples), `:382` (utils), `:389`
  (benchmarks) plus the WASM and fuzz blocks — so **no host program is
  compiled**. Correct and correctly minimal.
- **`LEXBOR_BUILD_STATIC` defaults ON** (`:54`), so with shared off the static
  archive is still built: `CMakeLists.txt:211-221`
  `add_library(${LEXBOR_LIB_NAME_STATIC} STATIC ${LEXBOR_SOURCES})` where
  `:194` sets `LEXBOR_LIB_NAME_STATIC` to `lexbor_static` and `:215` sets
  `OUTPUT_NAME` to the same → **`liblexbor_static.a`**. Confirmed.
- **The static target really is the one the CMake config exports.**
  `CMakeLists.txt:236-238` calls `ADD_MODULE_LIBRARY(STATIC lexbor_static …)`,
  and `config.cmake:345-353` installs that target into the export set, so
  `lexbor-targets.cmake` gets the correct `lexbor::lexbor_static`. A
  `find_package(lexbor)` consumer is fine. **`stage1.md` is right about that.**
- **`LEXBOR_WITHOUT_THREADS` correctly left alone.** `CMakeLists.txt:51`
  declares it ON and the header comment at `:8` says "Not used now, for the
  future". I confirmed the substance: `grep -rn 'pthread'
  source/lexbor/` returns **zero hits** across all 216 `.c` files. There is no
  thread library to resolve and, on Bionic, no separate `-lpthread` anyway.
- **System usage is clean** — `cmake -S . -B build $CMAKE_FLAGS …`,
  `cmake --build build --parallel 1`, `cmake --install build`. Prefix,
  toolchain file and prefix path all from `$CMAKE_FLAGS`. No `export`, no
  hardcoded target facts, no fan-out.
- **The `-DLEXBOR_BUILD_SHARED=OFF` is enough on mingw** — `config.cmake:45-49`
  selects the port directory from `if (WIN32)`, not from `LEXBOR_BUILD_SHARED`,
  so `windows_nt` is picked on mingw regardless and
  `ports/windows_nt/config.cmake` supplies `-Wno-pedantic-ms-format`.
- **`require()` resolves**: only `require("Lexbor@source")`.
- **No host tool is needed at build time**, so no `require("...@native")` — see
  the note at the end.

### I compiled it rather than trusting the "no platform surface" claim

lexbor's `stage1.md` asserts no sockets, no `fork`, no POSIX-only headers, no
pthread. Checking the includes in `source/lexbor/` gives exactly
`dirent.h float.h inttypes.h limits.h math.h memory.h stdarg.h stdbool.h
stddef.h stdint.h stdio.h stdlib.h string.h sys/stat.h sys/sysctl.h sys/types.h
time.h windows.h` — all of which exist on every target. I then compiled the
port sources and the module sources:

```
aarch64 API21 (posix port, -std=c99 -pedantic): 0 errors
aarch64 API35 (posix port):                      0 errors
mingw GCC 16 (windows_nt port, -DLEXBOR_STATIC): 0 errors of 72 TUs
```

The `-DLEXBOR_STATIC` in the mingw probe matters: without it the export macros
dangle and you get dozens of "definition is marked dllimport" errors. With it,
all 72 translation units compile. That define comes from
`CMakeLists.txt:221` (`target_compile_definitions(... PUBLIC "LEXBOR_STATIC")`)
on the static target, so the real build has it.

### Android API level: inert, and tested

Sweeping `source/lexbor/` for the gap list (`posix_spawn`, `process_vm_readv`,
`POSIX_MADV_*`, `getpass`, `mblen`, `O_BINARY`, `nl_langinfo`, `iconv`,
`mktime_z`, `getaddrinfo`, `pthread_`, `strptime`, `localtime`): **zero hits**.
lexbor does its own Unicode normalisation and IDNA in `lexbor/unicode/`
instead of calling libc locale or `iconv`, and its file access is plain stdio.
`ports/posix/lexbor/core/fs.c` uses only `opendir`/`readdir`/`closedir` and
`fopen`/`fread`. **The API level really is inert** — 21, 24 and 35 compile the
same sources.

### One thing worth noting that is NOT a defect

On Android our toolchain files deliberately set `CMAKE_SYSTEM_NAME` to `Linux`
(AGENTS.md:255-262, so cmake's own NDK integration stays out of the way), and
`ports/posix/config.cmake` has
`if(CMAKE_SYSTEM_NAME STREQUAL "Linux") add_definitions(-D_POSIX_C_SOURCE=199309L) endif()`.
So Android gets `_POSIX_C_SOURCE=199309L`. I compiled with exactly that define
at API 21 and API 35 and it is clean — lexbor needs nothing from the POSIX
namespace beyond what 199309L provides. Recording it so a future reader does
not mistake the define for an Android artifact.

---

## Required changes

### 1. `packages/Lexbor/generic.lua` — the installed `lexbor.pc` names a library that this recipe does not build, and the stated reason for leaving it alone is false.

**The mismatch is real.** With `-DLEXBOR_BUILD_SHARED=OFF`, the only archive
produced is `liblexbor_static.a` (`CMakeLists.txt:211-221`, installed via
`config.cmake:345-353`). But `lexbor.pc.in` says:

```
Libs: -L${libdir} -l@PROJECT_NAME@
```

and `CMakeLists.txt:193` sets `set(LEXBOR_LIB_NAME "${PROJECT_NAME}")` with
`PROJECT_NAME` = `lexbor` (`CMakeLists.txt:44`). So the installed `.pc` renders
`Libs: -L${libdir} -llexbor`, and `pkg-config --libs lexbor` emits
`-llexbor`, **which does not exist in this prefix**. Every pkg-config consumer
of lexbor in the tree fails to link.

**The stated reason for not fixing it is wrong, and that is the REJECT.**
`packages/Lexbor/stage1.md` risk 1 says:

> This is an upstream inconsistency, not a recipe error — and AGENTS.md forbids
> patching, so the recipe cannot fix it.

Both halves of that are wrong. AGENTS.md:239-254 says the opposite, in as
many words:

> Rewriting a *generated* artifact the build itself just produced, under
> `$OUT`, is not patching an upstream source and is allowed: use `awk` plus
> `cp`, never `sed -i` […] a `.pc` written by `cmake --install` into `$OUT` is
> an artifact we made, and the loader already rewrites that same file for
> `$OUT`→`$PREFIX` (`src/loader.lua:454-468`), so a recipe correcting a field
> in it is doing by hand what the loader does mechanically.

and it names `packages/glog/generic.lua` as **the worked example** — where a
generated `libglog.pc` in `$OUT` is rewritten with `awk` precisely because its
`Cflags` line needed a field no cmake option could reach. lexbor's `Libs` line
is the same shape: the value cmake substitutes is wrong for a static-only
build, and no `LEXBOR_*` option can change it, because the template uses
`@PROJECT_NAME@` and nothing else.

This is precisely the "wrong stated reason" failure AGENTS.md:504-508
describes: a false justification is what makes the next person go and "fix" a
flag that was correct, or to leave a defect in place because they were told it
was unfixable.

**Required change:** add, after `cmake --install build` in
`packages/Lexbor/generic.lua` (i.e. after line 27), an `awk` rewrite of the
**generated** `.pc` under `$OUT` — the glog shape exactly, with a comment
citing AGENTS.md:239-254 and `packages/glog/generic.lua:68-69`:

```sh
awk '{ if ($0 ~ /^Libs:/) print "Libs: -L${libdir} -llexbor_static"; else print }' \
    "$OUT/lib/pkgconfig/lexbor.pc" > "$WORK/lexbor.pc"
cp "$WORK/lexbor.pc" "$OUT/lib/pkgconfig/lexbor.pc"
```

`lexbor.pc` is generated by `CMakeLists.txt:428-436` into
`${PROJECT_BINARY_DIR}` and installed into `$OUT/lib/pkgconfig/`, so it is a
build artifact under `$OUT` — inside the scope AGENTS.md:248-250 draws, and
never in `$WORK` or the unpacked tree. `cmake --install` regenerates it every
build, so the rewrite cannot double-apply, and the line contains no `$OUT`, so
the loader's staged-`.pc` pass prints it verbatim.

Two constraints on the substitute, so the adder cannot get this wrong:
- The line must keep `-L${libdir}` — dropping it breaks consumers that rely on
  it, and `glog`'s comment (`generic.lua:58-61`) records why a duplicate
  `Libs:` key is not an alternative: pkg-config resolves last-key-wins, which
  **drops** the `-L` rather than adding to it.
- The replacement must be the **whole line**, not an append, because the same
  last-key-wins rule applies.

If the adder prefers not to ship a `.pc` at all over shipping a wrong one, that
is a defensible alternative and I will accept it — but it must be argued in
`stage1.md` against the AGENTS.md:239-254 text, not against "patching is
forbidden".

### 2. `packages/Lexbor/stage1.md` — three of the listed install paths do not exist.

Verified against `config.cmake:357-373` (`INSTALL_MODULE_HEADERS`), which is
the only rule that installs headers:

```cmake
install(DIRECTORY "${dir_search}" DESTINATION "include/${pname}"
        FILES_MATCHING PATTERN "*.h")
```
with `dir_search = source/lexbor/<module>`. `install(DIRECTORY)` reproduces the
directory under the destination, so a module's headers land in
`include/lexbor/<module>/`, not at the top of `include/lexbor/`.

| `stage1.md` claims | actually installs |
| --- | --- |
| `include/lexbor.h` | `include/lexbor/core/lexbor.h` — `find . -name lexbor.h` returns exactly one hit, `./source/lexbor/core/lexbor.h` |
| `include/lexbor/html.h` | `include/lexbor/html/html.h` |
| `include/lexbor/**` | `include/lexbor/{core,css,dom,encoding,engine,html,ns,punycode,selectors,style,tag,unicode,url,utils}/…` — the module list, not a flat tree |

Correct the install list to those paths, and correct the "How to verify once
built" bullets that use `include/lexbor.h` and `include/lexbor/html.h` — as
written, both are commands that cannot match their own target and would report
phantom failure. `lib/liblexbor_static.a`, `lib/pkgconfig/lexbor.pc` and
`lib/cmake/lexbor/lexbor-config.cmake` are correct
(`config.cmake:345-353`, `CMakeLists.txt:402-414`, `CMakeLists.txt:428-436`).

### 3. `packages/Lexbor/stage1.md` — `find $PREFIX/bin` is an unscoped check.

The suggested check `find $PREFIX/bin` → empty will fail the moment **any**
second package installs a binary, because `$PREFIX/bin` is the whole prefix's
`bin/`, not lexbor's. AGENTS.md:558-567 names this exact failure. Replace with
a scoped equivalent, e.g. `find "$PREFIX" -name 'liblexbor*' -o -name 'lexbor-*' -type f`,
or state the expectation as "lexbor contributes no `bin/` entry" without a
`find` over the shared prefix.

---

## Android rows and clang-native: correct

All five non-mingw rows are WILL BUILD, and I agree: one flag, no host programs
(`lexbor` builds libraries only — `EXECUTABLE_LIST` in `config.cmake:389` is
only reached from the `add_subdirectory` calls the OFF gates cover), no
platform surface, and the API level genuinely does not matter.

## mingw row

`config.cmake:45-49` picks `windows_nt`; `ports/windows_nt/config.cmake` sets
`-Wno-pedantic-ms-format` for the non-MSVC branch; the 72-TU compile above is
clean; no pthread, no sockets, no fork anywhere in `source/lexbor/`. The
CPack block at `CMakeLists.txt:443-466` only sets packaging variables and
`include(CPack)` generates metadata — it does not fail a configure and adds no
host program. **WILL BUILD stands.**

## Does any of the seven need a host tool at build time?

No. Answering the assignment's question explicitly, per package:

| package | host tool needed? | why |
| --- | --- | --- |
| libssh2 | no | `configure` needs a native `sed` (`configure.ac:16-18`), which the build host provides; nothing is compiled for the host |
| opusfile | no | none; `--disable-examples` removes the only programs |
| libsndfile | no | none; `make install` runs no target binary |
| Google-Benchmark | no | with `BENCHMARK_ENABLE_TESTING=OFF`, nothing; **with it ON it would fetch and build googletest — that is exactly what the flag prevents** |
| protobuf | no | with `PROTOC_BINARIES=OFF` there is no code generator to run; `require("abseil-cpp")` makes `find_package(absl)` succeed so the `FetchContent` fallback at `cmake/abseil-cpp.cmake:20-29` never runs |
| cmark | no | none; `man/CMakeLists.txt` only installs pre-built pages |
| Lexbor | no | none |

So **no `require("...@native")` is needed by any of the seven**, and none is
present. That is correct, not an omission.

## Carried to the build

`clang-native` is the system to build this on. Artifacts under `$PREFIX`:

| artifact | source of truth |
| --- | --- |
| `lib/liblexbor_static.a` | `CMakeLists.txt:211-221`, `config.cmake:345-353` |
| `include/lexbor/core/lexbor.h` | `config.cmake:357-373` |
| `include/lexbor/html/html.h` | same |
| `include/lexbor/{core,css,dom,encoding,engine,html,ns,punycode,selectors,style,tag,unicode,url,utils}/*.h` | same |
| `lib/pkgconfig/lexbor.pc` | `CMakeLists.txt:428-436` — **contents wrong until change 1 lands** |
| `lib/cmake/lexbor/{lexbor-config.cmake,lexbor-config-version.cmake,lexbor-targets.cmake}` | `CMakeLists.txt:402-414` |

No `bin/` entry and no shared object are expected.

### The ONE command that proves each

```sh
# the shaded static archive exists, right format, and really contains the HTML
# module (proving LEXBOR_BUILD_SEPARATELY=OFF produced one library, not 15)
test -f "$PREFIX/lib/liblexbor_static.a" &&
llvm-objdump -f "$PREFIX/lib/liblexbor_static.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/liblexbor_static.a" | grep -c lxb_html_document_parse
```
Expected: correct object format, non-zero count.

```sh
# headers landed under the module subdirectories
test -f "$PREFIX/include/lexbor/core/lexbor.h" &&
test -f "$PREFIX/include/lexbor/html/html.h" &&
ls "$PREFIX/include/lexbor" | wc -l
```
Expected: both `test -f` succeed. **Do not look for `include/lexbor.h`** — it
does not exist.

```sh
# no shared object and no binaries
find "$PREFIX/lib" -maxdepth 1 -name 'liblexbor.so*' | wc -l
```
Expected: `0`. Both scoped to lexbor's own names, so no second package in
`$PREFIX` can perturb them. **Do not** use `find "$PREFIX/bin"` — see
change 3.

```sh
# the "no threads, no sockets" claim, empirically
llvm-nm -u "$PREFIX/lib/liblexbor_static.a" | grep -cE 'pthread_|socket|connect|opendir'
```
Expected: `0`.

### After change 1 lands — the check that proves it

```sh
pkg-config --libs lexbor
```
Expected: `-L<prefix>/lib -llexbor_static`.

Before the fix this prints `-llexbor`, which names a file that is not in the
prefix. That single line is the whole check: it fails loudly and usefully
before the fix, and prints the right library after it. Cross-check that the
named archive exists:
```sh
test -f "$PREFIX/lib/$(pkg-config --libs lexbor | sed 's/.*-l//').a"
```
Expected: success. That is a glob-free, self-consistent pairing — it cannot
report a phantom failure the way a hardcoded `lib/liblexbor.so` would.