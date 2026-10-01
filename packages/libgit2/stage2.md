REJECT

# libgit2 1.9.7 — stage 2 review

Checked against the unpacked `libgit2-1.9.7` tree in `$HOME/dl` and against
NDK r28.2.13676358.

## Required changes

1. **`generic.lua:38-41` and `stage1.md:64-73` — the iconv justification is
   factually wrong, and the flag is right for a reason nobody wrote down.**

   stage1.md:64-73 presents a table claiming `<iconv.h>` is **absent** at API
   21/24/26 and present at 28/35, and generic.lua:38-39 says "Bionic exposes
   `<iconv.h>` from API 28 only". **Both are false. I probed it directly:**

   ```
   $ echo '#include <iconv.h>' | aarch64-linux-android{21,24,26,28,35}-clang -E
   api 21 iconv.h: FOUND
   api 24 iconv.h: FOUND
   api 26 iconv.h: FOUND
   api 28 iconv.h: FOUND
   api 35 iconv.h: FOUND
   ```

   The header is present at **every** level. What is gated is the *function
   declarations*, which carry `__INTRODUCED_IN(28)` in the NDK header:

   ```
   $ grep -n INTRODUCED $SYSROOT/usr/include/iconv.h
   65:iconv_open(...) __INTRODUCED_IN(28);
   76:size_t iconv(...) __INTRODUCED_IN(28);
   86:int iconv_close(...) __INTRODUCED_IN(28);
   ```

   and a probe that *calls* it fails exactly where claimed:

   ```
   api 21: error: call to undeclared function 'iconv_open'
   api 24: error: call to undeclared function 'iconv_open'
   api 28: COMPILES     api 35: COMPILES
   ```

   So the conclusion (`-DUSE_ICONV=OFF` is what lets 21/24 compile) survives,
   but the stated mechanism is wrong, and per AGENTS.md:505-508 a wrong
   justification is a real defect — it is what makes the next person "fix" a
   correct flag.

   **There is a second, larger problem the adder missed entirely, and it is
   the reason this must be fixed rather than reworded.** libgit2's bundled
   `cmake/FindIntlIconv.cmake:15` gates on `check_function_exists(iconv_open)`,
   and `check_function_exists` is a **link** test. Under our systems'
   `-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY`, cmake's try_compile builds
   a static library, and **a static library does not resolve symbols** — so the
   probe succeeds even where the function is unavailable. I built libgit2's
   exact probe with our exact flag:

   ```
   api 21, CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY:
     -- Looking for iconv_open - found
     -- RESULT iconv.h=/usr/include libc_has_iconv=1
   api 21, default (executable try_compile):
     -- Looking for iconv_open - not found
   ```

   That means `ICONV_FOUND` comes back **TRUE at API 21**, `GIT_USE_ICONV` gets
   set (`src/CMakeLists.txt:191-192`), and `src/util/fs_path.c:1023` then calls
   `iconv_open` — which is the undeclared-function error above. **Without
   `-DUSE_ICONV=OFF` this package does not compile at API 21 or 24 in this
   tree, for a reason that has nothing to do with the header being missing.**
   The flag is therefore *more* load-bearing than the forecast claims, and the
   forecast gives the wrong reason for a flag that is genuinely required.

   **Required:** rewrite generic.lua:38-41 to state the real mechanism — the
   header is present at all levels, the *declarations* are `__INTRODUCED_IN(28)`,
   and our systems' `CMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` makes
   libgit2's `check_function_exists(iconv_open)` return true anyway, so
   `USE_ICONV=OFF` is mandatory on every Android level below 28, not merely
   tidy. Same correction to stage1.md:64-73, with the STATIC_LIBRARY
   interaction stated, because that is the part a future builder needs.

2. **`generic.lua:2` — `require("pcre2")` is missing, and
   `-DREGEX_BACKEND=pcre2` makes it mandatory.**

   `cmake/SelectRegex.cmake:23-30` (verified):

   ```cmake
   elseif(REGEX_BACKEND STREQUAL "pcre2")
       find_package(PCRE2)
       if(NOT PCRE2_FOUND)
           MESSAGE(FATAL_ERROR "PCRE2 support was requested but not found")
       endif()
   ```

   `FATAL_ERROR` at configure time, not a silent fallback. And
   `cmake/FindPCRE2.cmake:22` looks for `find_library(PCRE2_LIBRARY NAMES
   pcre2-8)`, which resolves only if pcre2 has already been built into
   `$PREFIX` — `packages/pcre2` exists and does build it
   (`generic.lua:9` passes `--enable-pcre2-8`, and
   `nest/aarch64-android24/lib/pkgconfig/libpcre2-8.pc` is present), but the
   loader only orders a package after the packages that `require()` it. The
   recipe requires `libcap`… no: it requires `zlib` and `openssl` and **not
   `pcre2`**. Whether PCRE2 is in `$PREFIX` when libgit2 configures is
   therefore down to whatever else happened to build first in the nest — on a
   clean nest this is a hard configure failure, and on a dirty one it is a
   build that only works by accident. stage1.md:98-101 notices the dependency
   ("`REGEX_BACKEND=pcre2` is a system-neutral claim that is not quite
   system-neutral") and then waves it through. The fix is one line, and it is
   the loader's whole point:

   ```lua
   require("pcre2")
   ```

   Either that, or drop `-DREGEX_BACKEND=pcre2` and let `SelectRegex.cmake:6-19`
   pick `regcomp_l`/builtin on its own — which is also a legitimate answer and
   removes the dependency entirely. Pick one and make stage1 match.

3. **`-DUSE_NSEC=OFF` needs a reason, or it needs to go.** generic.lua:40-41
   justifies it as "st_mtim nanosecond fields are not uniformly available
   across Bionic API levels and the feature is optional here". I could not
   confirm that, and the option's own help text is neutral
   (`CMakeLists.txt:30`: "Support nanosecond precision file mtimes and ctimes").
   Since `USE_NSEC` only affects which `st_mtim` fields libgit2 reads — and
   Bionic has had `st_mtim` with nanoseconds since API 21 — the flag is very
   probably unnecessary, and the stated reason looks like a guess shaped like a
   finding. It is harmless either way, but an unjustified flag in a recipe is
   how the next person ends up defending a behaviour nobody chose. Either cite
   the file and line that makes it necessary, or drop it.

## What the recipe gets right

- **`src/libgit2/config.h` and `include/git2/config.h` are ordinary sources,
  not `configure_file` products — confirmed, and no guard is correct.**
  `src/libgit2/config.h` opens with the libgit2 copyright banner and then
  `#include "common.h"` / `#include "git2/config.h"`. The only
  `configure_file` calls in `src/libgit2/CMakeLists.txt` are for
  `experimental.h.in` (`:106`), a COPYONLY of the same file (`:119`, `:122`),
  and `config.cmake.in` (`:133`) — none produces `config.h`. There is no
  `configure.ac`, no `aclocal.m4`, no autotools path at all, so no timestamp
  guard is needed. The absence claim is properly evidenced rather than
  asserted. Good — this is the case AGENTS.md:528-534 is about, done right.
- **Every option named in the recipe exists.** Verified in `CMakeLists.txt`:
  `BUILD_SHARED_LIBS:22`, `BUILD_TESTS:23`, `BUILD_CLI:24`, `BUILD_EXAMPLES:25`,
  `BUILD_FUZZERS:26`, `USE_NSEC:30`, `USE_SSH:33`, `USE_HTTPS:34`,
  `USE_BUNDLED_ZLIB:41`, `USE_ICONV:77`, `REGEX_BACKEND:40`. No invented
  flags.
- **`USE_BUNDLED_ZLIB=OFF`** is right: `cmake/SelectZlib.cmake:10-25` runs
  `find_package(ZLIB)` against `$CMAKE_PREFIX_PATH` (which `$CMAKE_FLAGS` points
  at `$PREFIX`) and adds `zlib` to the `.pc` Requires. `require("zlib")` is
  present. Correct.
- **`USE_SSH=OFF`** is right: the alternative providers are libssh2 (a separate
  package) and `exec`, which shells out to a `git` binary.
- **`BUILD_TESTS/CLI/EXAMPLES/FUZZERS=OFF`** are right, and the defaults are
  genuinely ON for the first two (`:23`, `:24`) — leaving them on would
  cross-compile the Clar suite and the `git2` CLI as target binaries.
- **The system.** All flags via `$CMAKE_FLAGS`, no hardcoded target facts, no
  exported search flags, `cmake --build build --parallel 1`. Clean.

## Per-system verdicts

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | UNCERTAIN | WILL BUILD | **no** |
| aarch64-android24 | UNCERTAIN | WILL BUILD | **no** |
| aarch64-android35 | UNCERTAIN | WILL BUILD | **no** |
| x86_64-android35 | UNCERTAIN | WILL BUILD | **no** |
| x86_64-mingw | UNCERTAIN | UNCERTAIN | yes |
| clang-native | UNCERTAIN | WILL BUILD | **no** |

I mark all six UNCERTAIN, and the reason is change 2, not change 1: with
`-DREGEX_BACKEND=pcre2` and no `require("pcre2")`, every row's outcome depends
on nest state rather than on anything in the recipe. A forecast that cannot
distinguish "will build" from "will build if pcre2 happens to be there" is not
a forecast. Once `require("pcre2")` is added the Android rows become WILL
BUILD on the evidence I have; the mingw row stays UNCERTAIN for the reason the
adder gives (OpenSSL-into-PE plus `-lws2_32 -lsecur32` at
`src/CMakeLists.txt:140`), which I accept as an honest unknown.

stage1.md:122's check — `nm lib/libgit2.a | grep iconv_open` must return
nothing on Android — is a real check that can match its target. Keep it; it is
in fact the check that would have caught the wrong reasoning.

## Verdict

REJECT. The recipe's flags are nearly all real and well chosen, and the
no-guard-for-cmake analysis is exemplary. But the headline API finding rests on
a probe that was not actually run — `<iconv.h>` is present at every level — and
the correct mechanism (our `STATIC_LIBRARY` try_compile making
`check_function_exists` lie) is undocumented, which leaves a load-bearing flag
protected by a false reason. And `-DREGEX_BACKEND=pcre2` without
`require("pcre2")` is a `FATAL_ERROR` waiting on a clean nest. Three edits, no
flags need to change.
