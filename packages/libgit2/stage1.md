# libgit2 build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.9.7
- URL: `https://github.com/libgit2/libgit2/archive/refs/tags/v1.9.7.tar.gz`
- Build system: **CMake only**
- Ships a generated `configure`: **no.** There is no `configure.ac` and no
  `aclocal.m4` in the tree; libgit2 is CMake-only, which matches the known
  state of the project (the autotools build was removed upstream).
- Config template: **none.** There is no `config.h.in`/`config.hin`/
  `configh.in`/`ac_config.h.in`/`configure.h.in`/`config-h.in`/`config_h.in`
  anywhere outside `deps/`. Note the trap: `src/libgit2/config.h` and
  `include/git2/config.h` both exist but are **ordinary source files**
  (`src/libgit2/config.h` starts with the libgit2 copyright banner and defines
  `git_config`), not `configure_file` products. No cmake project in this tree
  writes a config header, so there is **no timestamp guard to write** here.
- Requires: `libgit2@source`, `zlib`, `openssl`, `pcre2` — all exist under
  `packages/`. The `pcre2` require is **load-bearing**, not decorative:
  `cmake/SelectRegex.cmake:24-29` runs `find_package(PCRE2)` and then
  `MESSAGE(FATAL_ERROR "PCRE2 support was requested but not found")` if it is
  missing, and `cmake/FindPCRE2.cmake:19,22` looks for `pcre2.h` and a library
  named `pcre2-8` — precisely what `packages/pcre2` installs
  (`generic.lua:9` passes `--enable-pcre2-8`). Because the loader only orders a
  package after the ones that `require()` it, omitting the require would make
  success depend on whatever else happened to build first in the nest: a hard
  configure failure on a clean nest, a working build on a dirty one.

## Installs

`lib/libgit2.a` (static), the `git2/` header tree, `libgit2.pc`
(generated in-tree by `pkg_build_config`, `src/libgit2/CMakeLists.txt:91-96`,
via `cmake/PkgBuildConfig.cmake` — there is no `.pc.in` template to guard) and
the CMake package config.

## The option list, read out of the tree

libgit2 has a real option list and it matters, because the defaults are ON for
several things that must not be built:

| option | default | recipe | why |
|---|---|---|---|
| `BUILD_SHARED_LIBS` | ON | `OFF` | static prefix |
| `BUILD_TESTS` | **ON** | `OFF` | the Clar suite — target binaries |
| `BUILD_CLI` | **ON** | `OFF` | the `git2` command-line program |
| `BUILD_EXAMPLES` | OFF | OFF | left at default |
| `BUILD_FUZZERS` | OFF | OFF | left at default |
| `USE_SSH` | OFF | OFF | needs libssh2 (a separate package) or the `exec` provider, which shells out to a `git` binary |
| `USE_HTTPS` | ON | `OpenSSL` | use the OpenSSL in this prefix for HTTPS, TLS and hashing |
| `USE_BUNDLED_ZLIB` | OFF | OFF | `cmake/SelectZlib.cmake:10-25` runs `find_package(ZLIB)` and links `$PREFIX`'s zlib, adding `zlib` to the `.pc` Requires (`SelectZlib.cmake:18`) |
| `REGEX_BACKEND` | auto | `pcre2` | use the PCRE2 in this prefix; `require("pcre2")` makes it deterministic (`SelectRegex.cmake:27-29` is a `FATAL_ERROR` if PCRE2 is missing) |
| `USE_ICONV` | (APPLE only) | `OFF` | see below — **mandatory** on Android < 28, and the reason is our `STATIC_LIBRARY` try_compile, not a missing header |
| `USE_NSEC` | ON | *(left ON)* | probed: Bionic's `st_mtim`/`st_mtime_nsec` exist at API 21/24/35, so there is nothing to disable |

Every one of these was verified to exist by name in `CMakeLists.txt`,
`src/CMakeLists.txt`, `src/libgit2/CMakeLists.txt` or `cmake/`.

## The API-level finding: iconv

`src/util/fs_path.c:1017` guards its path-precomposition code with
`#ifdef GIT_USE_ICONV` and includes `<iconv.h>` (the `#include` is at the top of
the file, reached because the build defines the macro).
`src/CMakeLists.txt:187-196` sets `GIT_USE_ICONV` whenever
`find_package(IntlIconv)` succeeds:

    if(USE_ICONV)
        find_package(IntlIconv)
    endif()
    if(ICONV_FOUND)
        set(GIT_USE_ICONV 1)

**The header is present at every API level. The declarations are what is
gated.** Probed with the NDK r28 wrappers:

| API level | `#include <iconv.h>` | calling `iconv_open` |
|---|---|---|
| 21 | **found** | error: call to undeclared function |
| 24 | **found** | error: call to undeclared function |
| 26 | **found** | — |
| 28 | **found** | compiles |
| 35 | **found** | compiles |

The NDK header marks the declarations, not the file:
`iconv_open`/`iconv`/`iconv_close` all carry `__INTRODUCED_IN(28)`. So a
program that merely includes `<iconv.h>` compiles anywhere, while one that
*calls* `iconv_open` fails below 28.

**The load-bearing part is our own cmake setting, not Bionic.** libgit2's
`cmake/FindIntlIconv.cmake:15` gates on `check_function_exists(iconv_open)`,
which is a **link** test. Our systems export
`-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY` (every Android system file
does, e.g. `packages/aarch64-android21/generic.lua:125`) so cmake's compiler
check never has to run a target binary — and a static library does not
resolve symbols. The probe therefore succeeds where the function is
unusable. Reproduced with libgit2's own probe at API 21:

```
STATIC_LIBRARY:  -- Looking for iconv_open - found
                 -- RESULT iconv.h=/usr/include libc_has_iconv=1   -> ICONV_FOUND TRUE
default (exe):   -- Looking for iconv_open - not found
```

Note `iconv.h=/usr/include` in the STATIC_LIBRARY line: cmake found the
header at API 21 even in the same run where the function probe lied.

So `-DUSE_ICONV=OFF` is **mandatory** on `aarch64-android21` and
`aarch64-android24`: without it `ICONV_FOUND` is true, `GIT_USE_ICONV` is set
(`src/CMakeLists.txt:187-196`), and `src/util/fs_path.c:1017,1023` then calls
`iconv_open` and fails to compile. Turning it off everywhere also keeps one
artifact across all six families rather than two different libraries. It is
upstream's own switch (`CMakeLists.txt:77`).

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The one API-level wall is iconv, removed by `-DUSE_ICONV=OFF` (see above) — without it this does not compile, because our `STATIC_LIBRARY` try_compile makes libgit2's iconv probe report a false positive. Otherwise libgit2 is plain C99 over POSIX: `open`/`read`/`write`/`mmap`, `pthread` (via `find_package(Threads)`, `src/CMakeLists.txt:161`), `dirent`, `sys/stat`. `src/util/` and `src/streams/` contain **no** reference to `nl_langinfo`, `mktime_z`, `pthread_cancel` or `process_vm_readv` (grepped). `USE_NSEC` is left at its ON default and is safe: Bionic's `struct stat` has `st_mtim`/`st_mtime_nsec` at API 21 (probed at 21/24/35). |
| aarch64-android24 | WILL BUILD | As above; still below the API-28 declaration line, so `USE_ICONV=OFF` remains mandatory. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; endian-neutral. |
| x86_64-mingw | UNCERTAIN | libgit2 supports Windows with first-class providers — the `USE_HTTPS` list names `Schannel`, `SecureTransport`, `WinHTTP`, and `deps/winhttp` is bundled. But the recipe asks for `-DUSE_HTTPS=OpenSSL`, and on mingw that means linking the OpenSSL in this prefix against a PE target; libgit2 additionally appends `-lws2_32 -lsecur32` on Windows (`src/CMakeLists.txt:140`). That combination is plausible but **not verified here**, and the native-Windows provider (Schannel) would be the upstream-blessed choice instead. Marked UNCERTAIN rather than guessed. |
| clang-native | WILL BUILD | Native build; `USE_ICONV=OFF` is harmless (glibc has iconv but it is only used for macOS-style path precomposition). `topackage.md` has libgit2 unchecked, so there is no prior build record. |

armv7a-androidNN and i686-androidNN behave like aarch64.

## Risks / what a reviewer should check

- **`x86_64-mingw` is the open question**, recorded as UNCERTAIN. If the
  builder hits trouble there, `-DUSE_HTTPS=Schannel` is the upstream-native
  alternative to OpenSSL and is listed in `CMakeLists.txt:34`.
- **`REGEX_BACKEND=pcre2` is now guaranteed by the loader, not by nest
  luck.** The `require("pcre2")` above is what turns a configure-time
  `FATAL_ERROR` into a fixed ordering. The one thing left to eyeball in the log
  is `add_feature_info(regex ON "using system PCRE2")` — if that line is
  missing, something else won the selection.
- **`USE_NSEC` was deliberately left at its ON default.** An earlier draft of
  this recipe set `-DUSE_NSEC=OFF` on the claim that Bionic's nanosecond mtime
  fields are "not uniformly available across API levels". That claim was a
  guess and it is false: compiling a `struct stat` program that reads
  `st.st_mtim.tv_nsec` and `st.st_mtime_nsec` against the NDK r28 wrappers
  succeeds at API 21, 24 and 35. `USE_NSEC` only selects which `st_mtim` fields
  `src/libgit2/index.c:904-906` and `src/libgit2/iterator.c:1521-1525` read, so
  leaving it on is correct everywhere and keeps one artifact.
- **The GitHub `archive/refs/tags/` URL serves no `Content-Length`** (it is
  chunked), so a size check against the server is not possible for this one
  archive. Integrity was confirmed instead by `gzip -t` plus a member-count
  match between the archive (11907 file entries) and the extracted tree
  (11907 files). If a reviewer prefers a size-checked download, the release
  assets for v1.9.7 carry **no** tarball at all — the API reports the tag and
  the source archives only — so the `archive/refs/tags/` URL is the only
  usable one.
- **`deps/` is never built** as a consequence of `USE_BUNDLED_ZLIB=OFF` and
  `REGEX_BACKEND=pcre2`; `deps/pcre2`, `deps/zlib`, `deps/llhttp`,
  `deps/ntlmclient`, `deps/winhttp` and `deps/xdiff` stay out.

## How to verify once built

- `lib/libgit2.a`
- `include/git2.h`, `include/git2/sys/repository.h`
- `pkg-config --modversion libgit2` → `1.9.7`
- `readelf -h lib/libgit2.a` → `Machine: AArch64` on Android targets
- `[ -x bin/git2 ]` must FAIL — `BUILD_CLI=OFF`
- `nm lib/libgit2.a | grep iconv_open` must return **nothing** on Android —
  that is what proves `USE_ICONV=OFF` took effect at API 21/24