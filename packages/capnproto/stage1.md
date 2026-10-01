# capnproto build forecast

- Package directory: `capnproto` (topackage.md writes the name "Cap'n-Proto"
  in its Linux list and splits "Cap'n" / "Proto" across two lines in the
  curated list; the directory is `capnproto`.)
- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 1.5.0
- URL: `https://capnproto.org/capnproto-c++-1.5.0.tar.gz`
- Build system: autotools
- Ships a generated `configure`: **yes** (verified: `configure` is present in
  the tarball and is byte-identical to the archive member)
- Config template: **`config.h.in`** — `configure.ac:7` is
  `AC_CONFIG_HEADERS([config.h])`, and `config.h.in` is present in the tree
  (2135 bytes). This is the ordinary spelling, not one of the odd ones.
- Requires: `capnproto@source`, `zlib`, `openssl` — all exist under
  `packages/`

## Installs

`lib/libkj.a`, `libkj-async.a`, `libkj-http.a`, `libkj-gzip.a`, `libkj-tls.a`,
`libcapnp.a`, `libcapnp-rpc.a`, `libcapnp-json.a`, `libcapnp-websocket.a`,
`libcapnpc.a`, `libkj-test.a`; the `kj/` and `capnp/` header trees plus the
shipped `.capnp` schema files; 11 `.pc` files (`pkgconfig_DATA`,
Makefile.am:133) and the CMake package config.

**No tools installed, and that is a deliberate choice with a real cost.**
`bin_PROGRAMS = capnp capnpc-capnp capnpc-c++` (Makefile.am:416) compile and
link fine on a cross build — nothing in the build runs them, so the build
system does not force their exclusion; only `install-binPROGRAMS` is left out.
But omitting them means no consumer in this prefix can generate code against
these headers, so this is a **library-only** package and `libcapnpc.a` (which
*is* installed) is the plugin half of a toolchain whose driver half is absent.
Consumers generate code with a host `capnp`.

## The one thing that decides this package

`make all` and `make install` both pull in `BUILT_SOURCES`
(Makefile.am:496 = `$(test_capnpc_outputs)`), and those are produced by
`test_capnpc_middleman`, whose rule **runs the freshly built target `capnp`
binary** (Makefile.am:487-490):

    ./capnp$(EXEEXT) compile --src-prefix=$(srcdir)/src -o./capnpc-c++$(EXEEXT):src ...

`install` depends on `BUILT_SOURCES` directly (Makefile.in:3914) and
`install-am` on `all-am` (Makefile.in:3921), so neither plain target can be
used on a cross build. The recipe instead uses the two install targets that do
not pass through `BUILT_SOURCES`:
`install-libLTLIBRARIES` (Makefile.in:1662, prerequisite `$(lib_LTLIBRARIES)`)
and `install-data`, which covers the whole header/`.pc`/CMake half in one go
(`Makefile.in:4149-4154`) and includes `install-cmakeconfigDATA`, so the CMake
package config really is installed.

**What actually makes the narrow targets safe** is not "the `.capnp.c++` files
ship pre-generated" as a separate safety property. `capnpc_outputs`
(Makefile.am:102) is a **bare variable**: `grep -n capnpc_outputs Makefile.am`
returns exactly two hits, the definition and nothing else. It is never a
target, never a prerequisite, and never appears in any `_SOURCES`. The
`.capnp.c++`/`.capnp.h` files are **ordinary sources** compiled directly —
`c++.capnp.c++` is in `libcapnp_la_SOURCES` in `Makefile.in` — and they ship
that way in the tarball. That is why no library target has to generate
anything; the thing that makes `all` unusable is the **RUN** in the
middleman rule above, and nothing else.

Evidence for the source claim, by name rather than by failed build: the tree
contains exactly 9 `*.capnp.c++` and 9 `*.capnp.h`, matching `capnpc_outputs`
one-for-one including the compiler's own `lexer.capnp.c++` and
`grammar.capnp.c++`, while every name in `test_capnpc_outputs`
(`test.capnp.c++` and friends) is **absent**.

## Optional-dependency decisions

- **`--without-fibers`** — configure.ac:253-289 probes for
  `makecontext`/`getcontext`/`swapcontext`. Bionic has `<ucontext.h>` but
  declares none of those three at any API level; compiling a
  `getcontext`/`makecontext` call against `aarch64-linux-android21/24/35-clang`
  fails with *"call to undeclared library function 'getcontext'"* on all three
  (probed). Unset, configure would fall through to `-lucontext` (absent) and
  only *warn*. Passing `--without-fibers` also makes the artifact identical
  everywhere: configure.ac:290-294 then sets `-DKJ_USE_FIBERS=0` instead of
  defining `KJ_USE_FIBERS`.
- **`--with-zlib`, `--with-openssl`** — both exist in this prefix. The default
  is `check`, which does `AC_CHECK_LIB`/`AC_CHECK_HEADER` and silently
  downgrades with only a warning (configure.ac:196-234), so the same tree
  could produce different libraries per system. Pinning them makes
  libkj-gzip and libkj-tls unconditional.

## Per-system verdicts

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | Fibers off is the only capability at risk and it is explicitly disabled. Remaining sources are plain C++11/14 over POSIX (`sched_yield`, pthreads, `std::atomic`) — `AC_SEARCH_LIBS(sched_yield, rt)` at configure.ac:114 is harmless when it fails. No `nl_langinfo`, `mktime_z`, `iconv`, `posix_spawn`, `pthread_cancel` or `process_vm_readv` anywhere in the library. The API-21 `stderr`/`O_BINARY`/`mblen`/`getpass` walls are all C library facilities that Cap'n Proto does not use. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; endian-neutral (`src/capnp/endian.h`). |
| x86_64-mingw | WILL BUILD | Cap'n Proto has a first-class Windows path: configure.ac:70-79 branches on `host_os` matching `*mingw*` and sets `PTHREAD_CFLAGS="-mthreads"`, no pthread libs and `ASYNC_LIBS=-lws2_32`; the sources carry `async-win32.c++`, `filesystem-disk-win32.c++` and `kj/async-win32.h`. The one macro this row used to leave unexamined is `AX_CXX_COMPILE_STDCXX_14` (configure.ac:68), so it was checked directly: `m4/ax_cxx_compile_stdcxx_14.m4:83-93` compiles a test body using `<type_traits>`, a deduced return type, a generic lambda and an init-capture, and `x86_64-w64-mingw32-g++` (GCC 16.2.0) compiles that body clean at the default standard, at `-std=c++14` and at `-std=gnu++14`. Fibers are a non-issue: configure.ac:255-257 treats `mingw*` as always supporting them, but we pass `--without-fibers`, which takes the same path everywhere. |
| clang-native | WILL BUILD | Native build, nothing cross-specific. `topackage.md:413` lists Cap'n-Proto as unchecked, so there is no prior build record to lean on. |

armv7a-androidNN and i686-androidNN behave like aarch64: no arch-specific code
paths are selected by the recipe, and fibers are off.

## Risks / what a reviewer should check

- **The narrow-target approach is the whole correctness argument.** If
  `install-libLTLIBRARIES` or `install-data` is misspelled, make fails loudly
  (no such target) — that is safe. The risk to check is the opposite: that one
  of them transitively reaches `BUILT_SOURCES`. Verified rather than assumed:
  `install-data` → `install-data-am` (Makefile.in:3918,4149-4154) lists ten
  data/header/pc targets and none of them has a `BUILT_SOURCES` prerequisite,
  while `BUILT_SOURCES` appears only in `all`, `check`, `distdir`, `install`,
  `install-exec` and `CLEANFILES` (Makefile.in:1531,3726,3902,3914,3916,3961).
- **`libkj-test.a` is still built.** It is a real `lib_LTLIBRARIES` entry
  (Makefile.am:261,263) and is installed with the rest. It is the KJ test
  harness, not the test suite itself; nothing runs it. Flagged so a reviewer
  does not mistake it for a missing `BUILD_TESTING`-style switch — this build
  system has no such option.
- **`--disable-reflection` (lite mode) is deliberately NOT used.** It would
  force `--with-external-capnp` (configure.ac:54-56), i.e. a need for a host
  `capnp`, and would change the ABI. Left off so full reflection ships.

## How to verify once built

- `lib/libcapnp.a`, `lib/libkj.a`, `lib/libkj-async.a`, `lib/libkj-http.a`,
  `lib/libkj-gzip.a`, `lib/libkj-tls.a`, `lib/libcapnp-rpc.a`
- `include/capnp/c++.capnp.h`, `include/kj/async.h`, `include/kj/compat/tls.h`
- `pkg-config --modversion capnp` → `1.5.0`
- `readelf -h lib/libcapnp.a` → `Machine: AArch64` on Android targets
- `[ -x bin/capnp ]` must FAIL — the compiler binaries are intentionally absent
- `ls lib/pkgconfig | grep -cE '^(capnp|capnpc|kj-)'` → **11**. The
  `CAPNP_PKG_CONFIG_FILES` list (configure.ac:156-168) names exactly 11 files:
  5 beginning `capnp`/`capnpc` (capnp, capnpc, capnp-rpc, capnp-json,
  capnp-websocket) and 6 beginning `kj-` (kj, kj-async, kj-http, kj-gzip,
  kj-tls, kj-test). Note that a plain `grep -c capnp` would return **5**, not
  11 — the `kj-*.pc` files do not contain the string "capnp" — so the filter
  has to cover both prefixes.
- `test -f lib/cmake/CapnProto/CapnProtoConfig.cmake` — this is the check
  that would have caught the dropped `install-cmakeconfigDATA`; it is installed
  only because the recipe uses `install-data`.