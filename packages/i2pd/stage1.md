# stage1 — i2pd 2.61.0 (build forecast)

## Not on the backlog

`i2pd` is **not** in `topackage.md`'s LFS checklist and **not** in its
Android / Windows / Linux candidate lists. It is an I2P router daemon in C++17.
It was added because the user asked for it by name. No `topackage.md` entry was
added here: another worker owns that file.

## Version and where it comes from

| Field | Value |
|---|---|
| Version pinned | **2.61.0** |
| Release date of that release | 2026-07-21 (GitHub `<updated>` on the release entry) |
| URL used | `https://github.com/PurpleI2P/i2pd/archive/2.61.0/i2pd-2.61.0.tar.gz` |
| Newest **release** | 2.61.0 |
| Newest **tag** | 2.61.0 |
| Release vs tag | **they agree** — no disagreement to resolve |
| Chosen | the release, which is also the newest tag |

### Release vs tag, and the GitLab question

The brief said i2pd lives on GitLab and that GitLab publishes RELEASES
separately from tags. **Neither half of that is true any more, and I checked
rather than assuming.**

`gitlab.com/P2PFoundation/i2pd` is gone. Four probes:

| Command | Result |
|---|---|
| `curl "https://gitlab.com/api/v4/projects/P2PFoundation%2Fi2pd"` | `{"message":"404 Project Not Found"}` |
| `curl "https://gitlab.com/api/v4/projects/P2PFoundation%2Fi2pd/repository/tags"` | `404 Project Not Found` |
| `curl -I "https://gitlab.com/P2PFoundation/i2pd"` | `http=403`, effective URL `https://gitlab.com/users/sign_in` |
| `curl "https://gitlab.com/api/v4/groups/P2PFoundation"` and `/users/P2PFoundation` | `404 Group Not Found` / `404 Not Found` |

The namespace itself 404s, so this is not an access problem — it is a deleted or
renamed project. `https://gitlab.com/api/v4/projects?search=i2pd&per_page=50`
returns 50 hits and none of them is `P2PFoundation/i2pd`. For contrast, the same
API happily served tags for `equalitie/i2pd`, so the endpoint is not failing.

Upstream's canonical home is therefore **GitHub: `PurpleI2P/i2pd`**:

- `README.md:1` — `[![GitHub release](https://img.shields.io/github/release/PurpleI2P/i2pd.svg?label=latest%20release)](https://github.com/PurpleI2P/i2pd/releases/latest)`
- `README.md:52` — "You can fetch most of them on [release](https://github.com/PurpleI2P/i2pd/releases/latest) page."
- Arch's `PKGBUILD` sources `https://github.com/PurpleI2P/i2pd/archive/${pkgver}/${pkgname}-${pkgver}.tar.gz` at `pkgver=2.61.0`.

Two independent, unauthenticated, non-rate-limited feeds, both topped out at
2.61.0:

- `https://github.com/PurpleI2P/i2pd/tags.atom` — `2.61.0, 2.60.0, 2.59.0, 2.58.0, 2.57.0, 2.56.0, 2.55.0, 2.54.0, 2.53.1, 2.53.0`; feed `<updated>2026-07-20T18:25:22Z</updated>`.
- `https://github.com/PurpleI2P/i2pd/releases.atom` — same list, newest entry
  `<id>tag:github.com,2008:Repository/12522239/2.61.0</id>`,
  `<updated>2026-07-21T21:38:17Z</updated>`, with real release notes
  ("Implemented torsocks support in SOCKS proxy", "Set SSU2 default crypto type
  to ML-KEM-768 when applicable", …). It is a published **release**, not a bare
  tag.

So the newest release and the newest tag are the same version. Had they
differed, the release would have won; it does not have to.

Debian `sid` carries `2.59.0-1`
(`https://sources.debian.org/api/src/i2pd/`), one minor behind, which is
consistent with 2.61.0 being current and not with anything newer.

### Archive verification

```
curl -fSL -C - -o i2pd-2.61.0.tar.gz \
  https://github.com/PurpleI2P/i2pd/archive/2.61.0/i2pd-2.61.0.tar.gz
http=200 size=779272
-rw-r--r-- 1 si si 779272 i2pd-2.61.0.tar.gz
sha256  409cd3c0257491286611ab6aaf690940c7248fb898377c13fadb65a836e2a0ab
```

`sha256sum` matches Arch's `sha256sums[0]` for `pkgver=2.61.0` byte for byte
(`409cd3c0257491286611ab6aaf690940c7248fb898377c13fadb65a836e2a0ab`), so this
is the same tarball a distro ships.

`tar tf` exited 0 and listed **355 entries**; `cut -d/ -f1 | sort -u` gives
exactly one top-level directory, `i2pd-2.61.0/`. Hence
`tar -xzf … --strip-components=1`.

The archive's own `libi2pd/version.h:20-22` reads
`I2PD_VERSION_MAJOR 2 / I2PD_VERSION_MINOR 61 / I2PD_VERSION_MICRO 0`, and
`build/cmake_modules/Version.cmake:3-16` is what scrapes that file into
`PROJECT_VERSION` — so the built binary self-reports 2.61.0 with
`WITH_GIT_VERSION=OFF`.

## Build system

| Question | Answer | Evidence |
|---|---|---|
| Build system | **cmake**, project root is the **`build/` subdirectory** | `build/CMakeLists.txt:1` is the only `CMakeLists.txt`; `tar tf` shows none at the tree root |
| Generated `configure` ships? | **No.** No `configure`, no `configure.ac`, no `Makefile.in` anywhere | `tar tf | grep -c 'configure'` → 0 |
| Autotools config template | **N/A** — no `AC_CONFIG_HEADERS` anywhere | there is no `configure.ac`; `build/cmake_modules/` holds `CheckAtomic.cmake`, `FindCheck.cmake`, `FindMiniUPnPc.cmake`, `GetGitRevisionDescription.cmake(.in)`, `TargetArch.cmake`, `Version.cmake` and nothing autotools |
| `.pc` file | **No** | the four `install()` rules in the whole project are `build/CMakeLists.txt:74, :87, :100, :411`; none is `install(FILES …)` and none names a `.pc` |
| CMake package config | **No.** `install(TARGETS libi2pd EXPORT libi2pd …)` at `:75` declares an export set that is **never installed** — there is no `install(EXPORT …)` and no `configure_file` for a config anywhere in `build/` | grep `install(EXPORT\|configure_file\|Config.cmake` over `build/` returns only the `GetGitRevisionDescription.cmake:161,163` hits, which are git-only (and that module is not included) |
| Compiler / standard | C++17 minimum, C++20 when Boost ≥ 1.81 | `build/CMakeLists.txt:14-16` (`CMAKE_CXX_STANDARD 17`), `:322-331` (checks `-std=c++20` if `Boost_VERSION >= 1.81`, else `-std=c++17`, and appends it to `CMAKE_CXX_FLAGS` itself) |
| Generator | `Unix Makefiles` — cmake's default here; every system pins `-DCMAKE_MAKE_PROGRAM=$(command -v make)` so it is never `$PREFIX/bin/make` | `aarch64-android35/generic.lua:138-139`, `x86_64-mingw/generic.lua:73-74` |

### Options that exist, and which the recipe sets

All from `build/CMakeLists.txt:38-47`:

| Option | Default | Recipe | Why |
|---|---|---|---|
| `WITH_HARDENING` | OFF | default | — |
| `WITH_LIBRARY` | ON | default | installs `libi2pd`, `libi2pdclient`, `libi2pdlang` (`:74, :87, :100`) |
| `WITH_BINARY` | ON | default | installs `bin/i2pd` (`:411`) |
| `WITH_STATIC` | OFF | default | OFF is what `-fPIC` + `BOOST_*_DYN_LINK` + shared Boost assumes (`:279-287`) |
| `WITH_UPNP` | **OFF** | **`-DWITH_UPNP=OFF`** | ON adds `find_package(MiniUPnPc REQUIRED)` (`:304`). **There is no `packages/miniupnpc`** (`ls packages/miniupnpc` → no such file). Passing OFF explicitly also documents the reason. |
| `WITH_GIT_VERSION` | OFF | **`-DWITH_GIT_VERSION=OFF`** | ON pulls in `GetGitRevisionDescription.cmake`, whose `execute_process` calls at `:121, :203, :229, :269` run `git`. AGENTS.md forbids `git`/`jj` in a recipe. Default is already OFF; it is spelled out so the reason is on the record. |
| `WITH_*SANITIZER` | OFF | default | — |
| `BUILD_TESTING` | OFF | **`-DBUILD_TESTING=OFF`** | **mandatory, see below** |

### Targets that exist, and what the prefix carries

Built (`build/CMakeLists.txt`):

- `libi2pd` (`:70`), `libi2pdclient` (`:83`), `libi2pdlang` (`:96`) — three
  static archives; `set_target_properties(... PROPERTIES PREFIX "")` at `:71,
  :84, :97` strips the `lib` prefix, so the files are `libi2pd.a`,
  `libi2pdclient.a`, `libi2pdlang.a` in `$PREFIX/lib`.
- **exactly one executable**: `i2pd` (`:371`), the daemon. There is no separate
  `i2ptunnel`/client binary in this release — the "client" is the
  `libi2pdclient` library (SAM / SOCKS / HTTP proxy / I2CP live there). The
  `libi2pd_wrapper/` directory and the top-level `Makefile` family are **not**
  referenced by `build/CMakeLists.txt` at all, so nothing from them is built.
- No benchmarks anywhere in the tree.

**Tests are switched off, and it is mandatory.** `build/CMakeLists.txt:416-418`
does `add_subdirectory(${CMAKE_SOURCE_DIR}/tests …)` when `BUILD_TESTING` is on,
and `tests/CMakeLists.txt` is exactly what this repository forbids:

- `tests/CMakeLists.txt:2` — `find_package(Check 0.9.10 REQUIRED)`. There is no
  `packages/check` in this tree.
- `tests/CMakeLists.txt:111-123` — thirteen `add_test(test-… ${TEST_PATH}/test-…)`
  rules that **run the freshly built target binaries**. With
  `qemu-aarch64` registered via `binfmt_misc` on the host, an unguarded test
  binary is not merely unwanted, it is *runnable by accident*. `-DBUILD_TESTING=OFF`
  is the switch that prevents it, and it is the only such switch in the project.

### What the recipe installs

`cmake --install` gives four paths and nothing else. The rest is reproduced
from upstream's own Unix install rule, `Makefile.linux:56-72`.

| Path under `$OUT` | What | Source of truth |
|---|---|---|
| `bin/i2pd` | the daemon | `build/CMakeLists.txt:411` |
| `lib/libi2pd.a`, `lib/libi2pdclient.a`, `lib/libi2pdlang.a` | the three archives (no `lib` prefix) | `:74, :87, :100` + `:71, :84, :97` |
| `etc/i2pd/{i2pd.conf, subscriptions.txt, tunnels.conf}` | main config, reseed server list, tunnel definitions | `Makefile.linux:60` |
| `etc/i2pd/tunnels.conf.d/` | per-tunnel config directory | `Makefile.linux:59` |
| `share/i2pd/certificates/{family,reseed}/*.crt` | **22** certificates, 88 KB total — `family/` 6 (`gostcoin.crt`, `i2p-dev.crt`, `i2pd-dev.crt`, `mca2-i2p.crt`, `stormycloud.crt`, `volatile.crt`), `reseed/` 16 | `Makefile.linux:64` |
| `share/doc/i2pd/{ChangeLog, LICENSE, README.md, i2pd.conf, subscriptions.txt, tunnels.conf}` | docs | `Makefile.linux:62` |
| `share/man/man1/i2pd.1` | man page, **uncompressed** (upstream gzips it first) | `Makefile.linux:66`, `debian/i2pd.1` |
| `include/i2pd/*.h` | **68** headers — `i18n/*.h` 2 (`I18N.h`, `I18N_langs.h`), `libi2pd/*.h` 54, `libi2pd_client/*.h` 12, flattened into one directory | **not upstream cmake**; upstream's cmake install ships no headers at all, so the three archives it installs are unusable without this. Arch's `package()` does the same. Flattening verified, not assumed: `grep -rn '#include *"\.\./' i18n libi2pd libi2pd_client` → **0 hits**, `grep -rn '#include *<libi2pd'` → **0 hits**, and `ls i18n/*.h libi2pd/*.h libi2pd_client/*.h \| xargs -n1 basename \| sort \| uniq -d` → **0 duplicate basenames** across all 68. Every quoted include is a bare header name, so one flat directory resolves them all. |
| `var/lib/i2pd/{certificates, tunnels.d, i2pd.conf, subscriptions.txt, tunnels.conf}` | five **relative** symlinks into the prefix | `Makefile.linux:68-72`, made relative because upstream's are absolute `${PREFIX}` targets and `$OUT` is a staging dir that is renamed on merge |

The symlink farm is the one place a wrong data-file list would send a later
builder after a phantom defect, so the runtime contract is worth stating:

- `libi2pd/FS.cpp:214` — `certsDir = i2p::fs::DataDirPath("certificates")`.
- `libi2pd/FS.cpp:87-91` — `--datadir` wins outright.
- `libi2pd/FS.cpp:117` — with `service`, Linux gets `/var/lib/i2pd`.
- `libi2pd/FS.cpp:194-200` — otherwise `$HOME/.i2pd`, or `/tmp/i2pd` with no
  `$HOME`.
- `libi2pd/Config.cpp:47,48,51,57` — `i2pd.conf`, `tunnels.conf`, `i2pd.pid`
  and `datadir` all default to *empty*, i.e. "look next to the binary, then
  fall back". `libi2pd/FS.cpp:146` makes the binary's own directory the data dir
  when `i2pd.conf` sits next to it.

So a nest prefix is **not** a runnable deployment on its own: the daemon looks
in `$HOME/.i2pd` (or wherever `--datadir` says), not in `$PREFIX/var/lib/i2pd`.
The `var/lib/i2pd` symlinks exist so that `--datadir=$PREFIX/var/lib/i2pd`
works, which is what a distro does.

**No `.pc` file and no CMake package config ship.** `pkg-config --modversion
i2pd` will not work and must not be used as a verification check. There is no
manifest to check either.

## Dependencies

Read from the project, then checked against this tree.

| Dependency | Required by | Exists under `packages/` today? |
|---|---|---|
| **Boost** (`filesystem`, `program_options`, `atomic`) | `build/CMakeLists.txt:289` — `find_package(Boost REQUIRED COMPONENTS filesystem program_options atomic)` | **`packages/boost` exists**, but see the blocker below |
| **OpenSSL** | `build/CMakeLists.txt:294` — `find_package(OpenSSL REQUIRED)` | **YES** — `source.lua`, `generic.lua`, `android.lua`, `stage1.md`, `stage2.md` |
| **zlib** | `build/CMakeLists.txt:312` `find_package(ZLIB)` — *optional* in name only, because `:365` unconditionally links `ZLIB::ZLIB`, so a miss is a hard configure error | **YES** — `source.lua`, `generic.lua`, `stage1.md`, `stage2.md` |
| **pthreads / threads** | `build/CMakeLists.txt:237` — `find_package(Threads REQUIRED)` | toolchain-provided, no package |
| **miniupnpc** | `build/CMakeLists.txt:304`, only under `WITH_UPNP` | **NO** — hence `-DWITH_UPNP=OFF` |
| **Check** | `tests/CMakeLists.txt:2`, only under `BUILD_TESTING` | **NO** — hence `-DBUILD_TESTING=OFF` |

The `require()`s in the recipes are therefore `i2pd@source`, `openssl`, `zlib`,
`boost`, in that order (dependencies first, `recipe()` last).

### The Boost blocker, stated plainly

`packages/boost` **does exist** (it appeared while I worked — it did not when I
first checked; `ls packages/boost` → `clang-native.lua generic.lua source.lua
stage1.md`). But it installs **headers and a CMake package config only**, by
design: `packages/boost/generic.lua:48` runs
`b2 -d0 libs/headers/build//install --prefix="$OUT" --layout=system`, and
`packages/boost/stage1.md:156-161` lists the result as `include/boost/**`,
`lib/cmake/boost_headers-1.92.0/…`, `lib/cmake/Boost-1.92.0/BoostConfig.cmake`,
`lib/cmake/Boost-1.92.0/BoostConfigVersion.cmake` and
`lib/cmake/BoostDetectToolset-1.92.0.cmake`. **No `libboost_*.a`, no
`libboost_*.so`.**

i2pd needs the *compiled* components, not the headers:
`build/CMakeLists.txt:282` adds `-DBOOST_ATOMIC_DYN_LINK
-DBOOST_FILESYSTEM_DYN_LINK -DBOOST_PROGRAM_OPTIONS_DYN_LINK` in the non-static
branch, `libi2pd/FS.cpp` and `libi2pd_client/AddressBook.cpp` use
`boost::filesystem`, `libi2pd/Config.cpp` uses `boost::program_options`, and 31
files under `libi2pd/ daemon/ libi2pd_client/` include `boost/asio.hpp`.

I did not take this on faith. With the host's cmake 4.4.3, a project using
i2pd's exact policy prologue (`cmake_minimum_required(VERSION 3.7)` +
`cmake_policy(VERSION 3.22)`) and a prefix holding `include/boost/version.hpp`
(`BOOST_VERSION 109200`), `include/boost/config.hpp` and a `BoostConfig.cmake`
that defines only an `INTERFACE` target:

```
-- CMP0167=
CMake Warning (policy) at CMakeLists.txt:6 (find_package):
  Policy CMP0167 is not set: The FindBoost module is removed. ...
CMake Error at /usr/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:290 (message):
  Could NOT find Boost: missing: filesystem program_options atomic (found
  /home/si/ond/.pk-i2pd/probe/fakeboost/lib/cmake/Boost-1.92.0/BoostConfig.cmake
  (found version "1.92.0"))
Call Stack (most recent call first):
  /usr/share/cmake/Modules/FindPackageHandleStandardArgs.cmake:639 (_FPHSA_HANDLE_FAILURE_CONFIG_MODE)
  /usr/share/cmake/Modules/FindBoost.cmake:642 (find_package_handle_standard_args)
```

That is `build/CMakeLists.txt:291`'s `message(SEND_ERROR "Boost is not found,
or your boost version was below 1.46…")` landing, on all six systems.

Two useful side facts from that probe:

- `CMP0167` is **unset** under `cmake_policy(VERSION 3.22)` (i2pd's
  `build/CMakeLists.txt:3-7` selects 3.22 on any cmake ≥ 3.22), so
  `/usr/share/cmake/Modules/FindBoost.cmake` is still reachable and only warns.
  This is the same reason `packages/boost/stage1.md:47-61` gives for CGAL —
  CGAL's `cmake_minimum_required(3.15...3.31)` sets CMP0167 NEW and i2pd's does
  not. So i2pd and Boost are *reachable* to each other; they are just not
  complete.
- FindBoost/FindOpenSSL/FindZLIB/FindThreads contain **no `try_run`** and no
  `execute_process` (`grep -n "try_run\|execute_process"` over those four files
  → zero matches), and this cmake's FindOpenSSL derives `OPENSSL_VERSION` with
  `file(STRINGS …/opensslv.h)` (`:670-719`), not by running `openssl`.

**What would satisfy it:** `packages/boost` would have to build
`filesystem`, `program_options` and `atomic` per target system and install
`libboost_filesystem.*`, `libboost_program_options.*`, `libboost_atomic.*` plus
the matching `lib/cmake/Boost-1.92.0/Boost*-config.cmake` component configs.
`packages/boost/stage1.md:129-149` argues against that on its own terms (hours
of work, target-libc-bound artifacts), and `packages/boost/stage1.md:295-301`
explicitly says nothing in it is evidence that a *compiled* Boost would build on
android21. So this is not something a later wave can assume away.

Consequence for the verdict table: **every row is blocked on Boost today**,
independently of everything else below. The rows record what would happen *if*
Boost were complete, and the one Android API-level blocker that is real
regardless.

## Does anything run a target binary at build time?

Checked, because the repository forbids it outright and this host has
`qemu-aarch64` on `binfmt_misc`.

| Place | What it does | Verdict |
|---|---|---|
| `build/cmake_modules/TargetArch.cmake:143` | `try_run(...)` with `COMPILE_OUTPUT_VARIABLE ARCH` | **Safe.** The probe program (`TargetArch.cmake:12-75`) is a chain of `#error cmake_ARCH <name>` directives and therefore *always fails to compile*; only the compiler's message is parsed (`:153-156`). The module says so itself at `:138-142`: "the program itself never needs to be run (only the compiler/preprocessor)". Its only consumer is the `message(STATUS)` at `build/CMakeLists.txt:346`. |
| `build/cmake_modules/GetGitRevisionDescription.cmake:121,203,229,269` | `execute_process` running `git` | **Not reached**: only included under `WITH_GIT_VERSION` (`build/CMakeLists.txt:138-142`), which the recipe pins OFF. It would also be forbidden. |
| `build/cmake_modules/CheckAtomic.cmake:3-4,51,72` | `CHECK_CXX_SOURCE_COMPILES`, `CHECK_LIBRARY_EXISTS` | compile/link only, no run. Its `FATAL_ERROR`s at `:56, :59, :77, :80` are real, but see the ordering note below. |
| `build/cmakeLists.txt:323,325` | `CHECK_CXX_COMPILER_FLAG("-std=c++20"/"-std=c++17")` | compile only (`-c`). |
| `tests/CMakeLists.txt:111-123` | 13 × `add_test()` **running** target binaries | **Not reached**: `-DBUILD_TESTING=OFF`. This is the switch the brief calls mandatory, and it is the only one. |
| `FindBoost` / `FindOpenSSL` / `FindZLIB` / `FindThreads` | — | no `try_run`, no `execute_process` (grepped, zero matches each). |

Ordering note that turns out to matter: `CheckAtomic` is included at
`build/CMakeLists.txt:60`, but the Clang branch that poisons
`CMAKE_REQUIRED_FLAGS` is at `:174-179` — **after** it. So the two
`message(FATAL_ERROR …)` paths inside `CheckAtomic.cmake` are evaluated before
`-stdlib=libstdc++` exists.

## The `-stdlib=libstdc++` interaction on Android

`build/CMakeLists.txt:174-179`:

```cmake
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  if(LINUX)
    set(CMAKE_REQUIRED_FLAGS "${CMAKE_REQUIRED_FLAGS} -stdlib=libstdc++") # required for <atomic>
    list(APPEND CMAKE_REQUIRED_LIBRARIES "stdc++")
```

Our Android toolchain files deliberately set `CMAKE_SYSTEM_NAME Linux`
(`aarch64-android35/aarch64-linux-android35-toolchain.cmake:3`), so `LINUX` is
`1` — confirmed by a probe that reproduces lines 174-179 verbatim under the
real toolchain file:

```
-- LINUX=1 UNIX=1 ANDROID= ID=Clang
-- CMAKE_REQUIRED_FLAGS= -stdlib=libstdc++
```

So on every Android target i2pd asks cmake's *try_compile* probes to build with
`-stdlib=libstdc++`, which the NDK does not have. Probes against NDK 28.2.13676358:

| Probe | Diagnostic |
|---|---|
| `aarch64-linux-android35-clang++ -stdlib=libstdc++ -c` on a file with `#include <atomic>` | `t.cpp:1:10: fatal error: 'atomic' file not found` (exit 1) |
| same without `-stdlib=libstdc++` | exit 0 |
| `-stdlib=libstdc++ -c` on a trivial `int main(){return 0;}` | exit 0 |
| `-stdlib=libstdc++ -pthread` **link** of the trivial file | exit 0, produced `tr` |
| `aarch64-linux-android35-clang -stdlib=libstdc++ -c` (C, `#include <pthread.h>`) | `clang: warning: argument unused during compilation: '-stdlib=libstdc++'`, exit 0 |
| `aarch64-linux-android35-clang++ t.cpp -lstdc++ -o t4` | exit 0 (the `-lstdc++` half of `:178` is harmless) |

So the blast radius is exactly "try_compiles that need a **C++ standard
library header**". Running the same probe with i2pd's `:174-179` block plus
`set(THREADS_PREFER_PTHREAD_FLAG ON)` + `find_package(Threads REQUIRED)`:

```
-- Performing Test CMAKE_HAVE_LIBC_PTHREAD - Failed
-- Check if compiler accepts -pthread
-- Check if compiler accepts -pthread - yes
-- Found Threads: TRUE
-- Threads_FOUND=TRUE CMAKE_THREAD_LIBS_INIT=-pthread
```

`find_package(Threads REQUIRED)` at `:237` **survives, and only because**
`aarch64-android35/generic.lua:130` puts `-DTHREADS_PREFER_PTHREAD_FLAG=ON` in
`$CMAKE_FLAGS` — without it, FindThreads would fall through to its libc probe
(which `-stdlib=libstdc++` breaks, as the `CMAKE_HAVE_LIBC_PTHREAD - Failed`
line shows) and then to `-lpthreads`, which no Android sysroot has. That is an
inherited system fact, not something this recipe invents, and it is worth
recording because it is the difference between "will build" and "will not".

## Verdict table

Every row is **currently blocked by Boost** (§ "The Boost blocker"). Read the
second column as: what happens *once `packages/boost` installs the three
compiled components*, and the third column as: what is additionally true now.

| System family | Verdict | Basis |
|---|---|---|
| `aarch64-android21` | **WILL NOT BUILD** | Second, independent blocker, and it needs no Boost: `libi2pd/util.cpp:529, 575, 606, 632, 741, 764` call `getifaddrs()`/`freeifaddrs()`. Bionic declares them `__INTRODUCED_IN(24)` — `$ANDROID_HOME/ndk/28.2.13676358/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/ifaddrs.h:85` and `:93`. Probe, `#include <ifaddrs.h>` then `getifaddrs(&p)`: API 21 → `error: use of undeclared identifier 'getifaddrs'; did you mean 'ifaddrs'?` (exit 74), API 23 → same, **API 24 → exit 0**. i2pd reaches the same header by both routes: `libi2pd/util.cpp:120-124` picks `"ifaddrs.h"` under `#ifdef ANDROID` (a shim that is *not* in this tarball — `ls libi2pd/ifaddrs.h` → no such file) and `<ifaddrs.h>` otherwise, and the quoted form falls through to Bionic's sysroot header anyway. So `-DANDROID` is irrelevant to this one; API 21 and 23 are simply below the declaration. |
| `aarch64-android24` | **UNCERTAIN** | Clears the `getifaddrs` wall (exit 0 at API 24) and gets `THREADS_PREFER_PTHREAD_FLAG` from `aarch64-android24/generic.lua`. The `-stdlib=libstdc++` injection is proven to be harmless to every probe i2pd actually runs. `stderr` is fine here despite AGENTS.md's warning list: `daemon/UnixDaemon.cpp:110` and `libi2pd/FS.cpp:104,133,156` only use it as `fprintf(stderr, …)`/`freopen(…, stderr)`, and a probe compiling exactly that at API 21/24/35 with `aarch64-linux-android<N>-clang++` exits 0 with no output. None of `nl_langinfo`, `mktime_z`, `iconv`, `posix_spawn`, `process_vm_readv`, `getpass`, `mblen`, `O_BINARY`, `pthread_cancel`, `POSIX_MADV_*` appears anywhere in `daemon/ libi2pd/ libi2pd_client/ i18n/` (all 0 hits). UNCERTAIN, not WILL BUILD, because Boost is unresolved and because nothing here has been compiled. |
| `aarch64-android35` | **UNCERTAIN** | Same as android24 plus the `ANDROID` macro that `aarch64-android35/generic.lua:69` sets, which is what `packages/i2pd/android.lua` exists to correct (§ below). API 35's `mktime_z` is irrelevant — i2pd does not call it. |
| `x86_64-android35` | **UNCERTAIN** | Identical toolchain facts to `aarch64-android35` — `-DANDROID` from `x86_64-android35/generic.lua:63-64`, `-DTHREADS_PREFER_PTHREAD_FLAG=ON` from `:126`. The only difference is `CMAKE_SYSTEM_PROCESSOR`, which i2pd only reads through `TargetArch.cmake` for a `message(STATUS)`. |
| `x86_64-mingw` | **UNCERTAIN** | `CMAKE_CXX_COMPILER_ID` is **GNU** (mingw-w64 g++), so `build/CMakeLists.txt:167-173` runs and the Clang branch at `:174-179` — the `-stdlib=libstdc++` problem — **never fires**. `CMAKE_SYSTEM_NAME` is `Windows` (`x86_64-mingw/x86_64-w64-mingw32-toolchain.cmake:4`), so `WIN32` is set: `:118-132` appends `Win32/{DaemonWin32,Win32App,Win32Service,Win32NetState}.cpp` plus the `.rc` resources and `-DWIN32_APP -DWIN32_LEAN_AND_MEAN -DNOMINMAX`, `:369` builds the daemon `WIN32` (subsystem), `:374-380` adds `wsock32 ws2_32 iphlpapi`, and `:399-403` prunes `synchronization` off `Boost::filesystem`. The one thing I could not settle is that `:400` does `get_target_property(BOOSTFSLIBS Boost::filesystem INTERFACE_LINK_LIBRARIES)` — with a Boost that defines no such target, cmake returns `<var>-NOTFOUND` rather than erroring, but I did not exercise it. `packages/openssl/generic.lua:19` builds `mingw64` for this system, so OpenSSL is covered. |
| `clang-native` | **UNCERTAIN** | Host clang, so `CMAKE_CXX_COMPILER_ID` is Clang and `LINUX` is 1 → `:174-179` fires here too, and `-stdlib=libstdc++` is *correct* here (the system clang really does use libstdc++), which is what the comment at `:176-179` says it is for. `find_package(Threads REQUIRED)` resolves via the libc probe, which a C compile survives (the `clang: warning: argument unused during compilation` probe above). No `-DANDROID`, so `daemon/Daemon.h:113`'s `#else` gives the real `DaemonUnix`. Cheapest system to build on and the one a builder should pick. |

`armv7a-*` and `i686-*` behave exactly like `aarch64-*`: the recipes reached are
the same (`recipe_fallbacks = {"android"}`), the NDK wrappers differ only in
name, and `packages/openssl/android.lua:23-29` already maps all four arches.
The API level is the only variable that matters, so `armv7a-android21` and
`i686-android21` are WILL NOT BUILD for the same `getifaddrs` reason.

## What `packages/i2pd/android.lua` is for, and the reviewer's call

Every Android system puts `-DANDROID` into the C++ compile: the 64-bit ones
directly (`aarch64-android35/generic.lua:69`), the 32-bit and x86_64 ones via
`$CFLAGS`, which they copy into `$CXXFLAGS` (`armv7a-android35/generic.lua:
63-64`, `i686-android35/generic.lua:63-64`, `x86_64-android35/generic.lua:
63-64`). `daemon/Daemon.h:100` keys off exactly that macro:

```cpp
#elif (defined(ANDROID) && !defined(ANDROID_BINARY))
    #define Daemon i2p::util::DaemonAndroid::Instance()
    // dummy, invoked from android/jni/DaemonAndroid.*
    class DaemonAndroid: public i2p::util::Daemon_Singleton { ... };
```

`DaemonAndroid` (`Daemon.h:102-112`) overrides **none** of
`Daemon_Singleton`'s virtuals (`Daemon.h:27-33`), and it is not abstract, so
`daemon/i2pd.cpp:28-34` — `Daemon.init / .start / .run / .stop` — **compiles and
links**; it just binds to the base class's definitions in
`daemon/Daemon.cpp`. Nothing errors. The installed `bin/i2pd` would start and
do nothing. I reproduced the class shapes in a standalone probe: `-DANDROID`
alone, `-DANDROID -DANDROID_BINARY`, and neither all compile (exit 0), which is
exactly the point — the failure is silent.

So `packages/i2pd/android.lua` appends `-DANDROID_BINARY` to `$CXXFLAGS`,

upstream's own opt-out: `Daemon.h:113`'s `#else` gives the real `DaemonUnix`,
and `daemon/HTTPServer.cpp:836, :1420, :1429` — all gated
`(!defined(WIN32) && !defined(QT_GUI_LIB) && !defined(ANDROID)) || defined(ANDROID_BINARY)`
— re-enable the graceful-shutdown paths to match.

Delivery is by re-exporting `CXXFLAGS` rather than `-DCMAKE_CXX_FLAGS` because
cmake copies `$CXXFLAGS` into `CMAKE_CXX_FLAGS` only when it creates that cache
entry on the first configure. Probe, with the real
`aarch64-linux-android35-toolchain.cmake` and
`CXXFLAGS="-O2 -fPIC -I/somewhere/include -DANDROID"`:

```
-- CMAKE_CXX_FLAGS=[-O2 -fPIC -I/somewhere/include -DANDROID]
```

Passing `-DCMAKE_CXX_FLAGS=` on the command line would pre-create the entry and
make cmake ignore `$CXXFLAGS` outright, dropping `-fPIC` and the prefix include
path. `export CXXFLAGS="$CXXFLAGS -DANDROID_BINARY"` appends to the system's own
value and never replaces it, and it is a preprocessor define rather than a
search flag.

**This is the one judgement call in the package.** It changes which daemon
implementation upstream compiles for Android. I believe a package that ships a
daemon binary wants the working daemon and that `i2pd-android`'s JNI stub is
the wrong thing to inherit. A reviewer who disagrees has a one-line deletion;
the file carries no other Android-specific content.

Two other Android-observable behaviours I did **not** try to change, both
upstream's own design:

- `libi2pd/FS.cpp:184-192` puts the data dir under `$EXTERNAL_STORAGE/i2pd`,
  falling back to `/sdcard/i2pd`. So the `var/lib/i2pd` symlink farm installed
  by the recipe is only used if something passes `--datadir`.
- `libi2pd/FS.cpp:94` skips the `/var/lib/i2pd` service path under `-DANDROID`.

## Open questions I could NOT establish

Honest gaps. A builder should not read the WILL-NOT-BUILD row as covering them.

1. **Nothing here has been configured or compiled.** The brief forbids it, so
   every claim above is read from source or settled with a throwaway probe
   against the NDK compilers. `build/CMakeLists.txt` itself was never run. The
   first thing a builder should do is configure on `clang-native` and diff the
   resulting `$OUT` against the install table.

2. **Boost is the blocker and it is not mine to fix.** Every row is UNCERTAIN
   or WILL NOT BUILD for want of `libboost_filesystem`,
   `libboost_program_options` and `libboost_atomic`. See § "The Boost
   blocker" for the probe output. Nothing in this package can be moved forward
   until `packages/boost` grows a compiled target, and
   `packages/boost/stage1.md:295-301` warns that a *compiled* Boost is itself
   unproven on android21.

3. **`Boost::filesystem` on mingw (`build/CMakeLists.txt:399-403`).**
   `get_target_property` on a target that does not exist returns
   `<var>-NOTFOUND` in cmake and does not error, but I read that from the
   cmake docs rather than from a run, and this path only executes on WIN32.

4. **`-Winvalid-pch` (`:156`).** It is added unconditionally to
   `CMAKE_CXX_FLAGS` for every non-MSVC compiler, so NDK clang gets it. I did
   not check whether clang 19 warns about it; a warning is harmless but a
   `-Werror` would not be, and nothing in this tree sets `-Werror`.

5. **The five `var/lib/i2pd` symlinks.** I made them relative so they survive
   the loader's `cp -rf "$OUT"/. "$NESTDIR/<sys>/"`. I did not verify that
   `cp -rf` preserves a relative symlink whose target is inside `$OUT` — it
   should, since the whole tree is copied with the same internal layout, but a
   builder should `find $PREFIX/var/lib/i2pd -type l` and resolve each one.

6. **The `-stdlib=libstdc++` injection on Android is proven harmless for the
   probes i2pd *runs*, not for the probes it might run.** I enumerated them
   (`CheckAtomic`, `FindThreads`, `CHECK_CXX_COMPILER_FLAG`, `find_package`
   modules). A check I did not find that needs a C++ standard header through
   `CMAKE_REQUIRED_FLAGS` would fail on `find_package(Threads REQUIRED)`, and
   the only thing standing between that and a broken build is
   `THREADS_PREFER_PTHREAD_FLAG=ON` in the Android system recipes — a flag
   nobody asked me to justify and I have now justified.

7. **`clang-native` is UNCERTAIN largely for the boring reason that I have not
   run anything**, not because anything in the table suggests a problem there.
   It is the cheapest system and the most likely first success.

8. **`WITH_STATIC=OFF` assumes shared Boost.** `:279-287` adds
   `BOOST_*_DYN_LINK` and `-fPIC` in the non-static branch. If `packages/boost`
   ends up static-only, `WITH_STATIC=ON` becomes the consistent choice
   (`Boost_USE_STATIC_LIBS ON` at `:244`, `ZLIB_USE_STATIC_LIBS ON` at `:256`,
   `CMAKE_FIND_LIBRARY_SUFFIXES ".a"` at `:241`). This is downstream of the
   Boost question and will change with its answer.

9. **GitLab.** I could not check whether `P2PFoundation/i2pd` was renamed,
   transferred or deleted, only that it and its namespace no longer resolve on
   gitlab.com. If a mirror exists under a different path it is not reachable
   from here, and nothing in the recipe depends on one.
