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

**No tools installed.** `bin_PROGRAMS = capnp capnpc-capnp capnpc-c++`
(Makefile.am:416) are deliberately left out — see the recipe.

## The one thing that decides this package

`make all` and `make install` both pull in `BUILT_SOURCES`
(Makefile.am:496 = `$(test_capnpc_outputs)`), and those are produced by
`test_capnpc_middleman`, whose rule **runs the freshly built target `capnp`
binary** (Makefile.am:487-490):

    ./capnp$(EXEEXT) compile --src-prefix=$(srcdir)/src -o./capnpc-c++$(EXEEXT):src ...

`install` depends on `BUILT_SOURCES` directly (Makefile.in:3914) and
`install-am` on `all-am` (Makefile.in:3921), so neither plain target can be
used on a cross build. The recipe therefore uses narrow install targets, whose
only prerequisites are the libraries and headers
(Makefile.in:1662: `install-libLTLIBRARIES: $(lib_LTLIBRARIES)`).

This is safe because **no library source needs code generation**: every entry
of `capnpc_outputs` (Makefile.am:102-120) ships pre-generated in the tarball.
Verified: exactly 9 `*.capnp.c++` and 9 `*.capnp.h` files exist in the tree,
and their names match `capnpc_outputs` one-for-one, including the compiler's
own `lexer.capnp.c++` and `grammar.capnp.c++`. Every name in
`test_capnpc_outputs` (`test.capnp.c++` and friends) is **absent** — confirmed
by name, not inferred from a failed build.

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
| x86_64-mingw | WILL BUILD | Cap'n Proto has a first-class Windows path: configure.ac:70-79 branches on `host_os` matching `*mingw*` and sets `-mthreads`, no pthread libs and `ASYNC_LIBS=-lws2_32`; the sources carry `async-win32.c++`, `filesystem-disk-win32.c++` and `kj/async-win32.h`. `AX_CXX_COMPILE_STDCXX_14` (configure.ac:68) is satisfied by mingw g++. Fibers are a non-issue: configure.ac:255-257 treats `mingw*` as always supporting them, but we pass `--without-fibers`, which takes the same path everywhere. |
| clang-native | WILL BUILD | Native build, nothing cross-specific. `topackage.md:413` lists Cap'n-Proto as unchecked, so there is no prior build record to lean on. |

armv7a-androidNN and i686-androidNN behave like aarch64: no arch-specific code
paths are selected by the recipe, and fibers are off.

## Risks / what a reviewer should check

- **The narrow-target approach is the whole correctness argument.** If any of
  the `install-*` targets named in `generic.lua` is misspelled, make fails
  loudly (no such target) — that is safe. The risk to check is the opposite:
  that one of them *does* transitively reach `BUILT_SOURCES`. The target names
  were read out of `Makefile.in` (3385, 3406, 1662, and the
  `install-include*HEADERS` family) rather than assumed.
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
- `ls lib/pkgconfig | grep -c capnp` → 11 (the `CAPNP_PKG_CONFIG_FILES` list at
  configure.ac:156-168 names exactly 11)