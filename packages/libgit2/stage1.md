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
- Requires: `libgit2@source`, `zlib`, `openssl` — all exist under `packages/`.
  (`pcre2` also exists and is used via `-DREGEX_BACKEND=pcre2`, but libgit2
  resolves it by name, not through a package dependency the loader tracks.)

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
| `REGEX_BACKEND` | auto | `pcre2` | use the PCRE2 in this prefix |
| `USE_ICONV` | (APPLE only) | `OFF` | see below — required on Android < 28 |
| `USE_NSEC` | ON | `OFF` | nanosecond mtime fields are optional here |

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

Bionic exposes `<iconv.h>` **from API 28 only**. Probed directly with the NDK
r28 wrappers:

| API level | `<iconv.h>` |
|---|---|
| 21 | not found |
| 24 | not found |
| 26 | not found |
| **28** | **found** |
| 35 | found |

So on `aarch64-android21` and `aarch64-android24`, `-DUSE_ICONV=OFF` is not
an optimisation, it is what makes the package compile. Turning it off
everywhere keeps one artifact across all six families rather than two
different libraries.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The one API-level wall is iconv, removed by `-DUSE_ICONV=OFF` (see above). Otherwise libgit2 is plain C99 over POSIX: `open`/`read`/`write`/`mmap`, `pthread` (via `find_package(Threads)`, `src/CMakeLists.txt:161`), `dirent`, `sys/stat`. `src/util/` and `src/streams/` contain **no** reference to `nl_langinfo`, `mktime_z`, `pthread_cancel` or `process_vm_readv` (grepped). `--disable-io`-class dependencies are not involved. |
| aarch64-android24 | WILL BUILD | As above; still below the API-28 iconv line, which is why `USE_ICONV=OFF` is unconditional. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; endian-neutral. |
| x86_64-mingw | UNCERTAIN | libgit2 supports Windows with first-class providers — the `USE_HTTPS` list names `Schannel`, `SecureTransport`, `WinHTTP`, and `deps/winhttp` is bundled. But the recipe asks for `-DUSE_HTTPS=OpenSSL`, and on mingw that means linking the OpenSSL in this prefix against a PE target; libgit2 additionally appends `-lws2_32 -lsecur32` on Windows (`src/CMakeLists.txt:140`). That combination is plausible but **not verified here**, and the native-Windows provider (Schannel) would be the upstream-blessed choice instead. Marked UNCERTAIN rather than guessed. |
| clang-native | WILL BUILD | Native build; `USE_ICONV=OFF` is harmless (glibc has iconv but it is only used for macOS-style path precomposition). `topackage.md` has libgit2 unchecked, so there is no prior build record. |

armv7a-androidNN and i686-androidNN behave like aarch64.

## Risks / what a reviewer should check

- **`x86_64-mingw` is the open question**, recorded as UNCERTAIN. If the
  builder hits trouble there, `-DUSE_HTTPS=Schannel` is the upstream-native
  alternative to OpenSSL and is listed in `CMakeLists.txt:34`.
- **`REGEX_BACKEND=pcre2` is a system-neutral claim that is not quite
  system-neutral.** It resolves PCRE2 out of `$PREFIX` on every system, and
  `packages/pcre2` exists for all of them, so it should hold everywhere — but
  if a target lacks it, libgit2 falls back and the library changes. Worth a
  glance in the build log (`add_feature_info(regex ...)`).
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