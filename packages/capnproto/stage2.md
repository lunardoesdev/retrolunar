REJECT

# capnproto 1.5.0 — stage 2 review

Both questions were checked against the unpacked tree
(`capnproto-c++-1.5.0`, downloaded to `$HOME/dl`).

## Required changes

1. **`generic.lua:38-59` — the narrow-install-target scheme is not needed, and
   the comment's central claim about it is false.**

   The whole argument rests on `make all` / `make install` reaching
   `BUILT_SOURCES`. Verified in the real tree:

   ```
   $ grep -n 'BUILT_SOURCES' Makefile.in
   1423:BUILT_SOURCES = $(test_capnpc_outputs)
   1531:all: $(BUILT_SOURCES) config.h
   3726:distdir: $(BUILT_SOURCES)
   3902:check: $(BUILT_SOURCES)
   3914:install: $(BUILT_SOURCES)
   3916:install-exec: $(BUILT_SOURCES)
   3961:	-$(am__rm_f) $(BUILT_SOURCES)
   ```

   So `install: $(BUILT_SOURCES)` and `install-exec: $(BUILT_SOURCES)` are real
   — the adder cited those correctly. **But the claim that the library itself
   needs no code generation is what makes the scheme safe, and `capnpc_outputs`
   is not what the libraries compile.** `grep -n capnpc_outputs Makefile.am`
   returns exactly two hits: the definition at `:102` and nothing else. It is
   a bare variable that is never assigned to any target, never listed in any
   `_SOURCES`, and never given a rule. The `.capnp.c++`/`.capnp.h` files are
   ordinary in-tree sources compiled directly (confirmed: 9 `.capnp.c++` and 9
   `.capnp.h` exist, and `grep -n 'c++.capnp.c++' Makefile.in` shows them in
   `libcapnp_la_SOURCES`). The adder's own stage1 says as much in one sentence
   ("no library source needs code generation") and then treats the existence of
   the pre-generated files as a *separate* safety property, as if shipping them
   were a lucky fact rather than the only mechanism there is.

   The consequence for the recipe is not cosmetic. `install-libLTLIBRARIES`
   depends on `$(lib_LTLIBRARIES)` (`Makefile.in:1662`, confirmed), and
   `lib_LTLIBRARIES` includes `libkj-test.la`, whose sources are ordinary `.c++`
   — so the narrow targets are *safe*, just not for the reason given. The real
   defect is what the comment says about the programs:

   > "bin_PROGRAMS (capnp, capnpc-capnp, capnpc-c++, Makefile.am:416) are
   > left out: they are target binaries nothing in this prefix runs."

   Leaving them out is a **deliberate functional decision**, not a build-system
   necessity, and the recipe presents it as the latter. `Makefile.am:416` is
   confirmed: `bin_PROGRAMS = capnp capnpc-capnp capnpc-c++`. `make all` builds
   them fine on a cross build — they are ordinary `noinst`-style programs with
   no rule that runs them. The only reason they cannot be installed is that
   nothing in this prefix can execute them. That is a real cost: **without
   `bin/capnp`, no consumer can generate code against these headers**, and
   `libcapnpc.a` (which the recipe *does* install, `Makefile.am:261`) is the
   plugin half of a toolchain whose driver half is missing. The recipe must
   say plainly that this is a library-only package, not imply the build system
   made the choice.

   **Required:** rewrite `generic.lua:38-59` so the stated reason is the true
   one — (a) the `.capnp.c++`/`.capnp.h` files are ordinary sources, not
   generated, so no library target reaches `BUILT_SOURCES`; (b) `bin_PROGRAMS`
   is omitted **by choice**, because they are target binaries no consumer here
   can run, and that leaves the prefix without a working `capnp` driver.
   Either that or install the programs.

2. **`generic.lua:60-73` — eleven `make -j1 install-*` invocations where the
   package's own install target is fine, and one of them is a no-op risk.**

   `install-data-am` (`Makefile.in:4149`) is `install-cmakeconfigDATA
   install-dist_includecapnpDATA install-pkgconfigDATA install-includecapnpDATA
   install-includecapnpcompatDATA install-includekjHEADERS
   install-includekjcompatHEADERS install-includekjparseHEADERS
   install-includekjstdHEADERS` — verified by reading `:4149-4155`. And
   `install-data: install-data-am` (`:3918`). So the whole header/pc/cmake half
   of the recipe is one target: `make -j1 install-data`. Only
   `install-libLTLIBRARIES` genuinely needs naming on its own, because it is
   in `install-exec-am` (`:4160`) alongside `install-binPROGRAMS`.

   Replace lines 61-73 with `make -j1 install-data`. That also picks up
   `install-cmakeconfigDATA`, which the recipe currently **drops silently**:
   stage1.md:24 claims "and the CMake package config" installs, but there is no
   `make -j1 install-cmakeconfigDATA` in the recipe and no other line installs
   `cmake/CapnProtoConfig.cmake`. A consumer's `find_package(CapnProto)` would
   fail. Either add the target or delete the claim from stage1.

3. **stage1.md:108 — `ls lib/pkgconfig | grep -c capnp` → 11 is a check that
   cannot pass as written.** `grep -c` counts *matching lines*, and the six
   `kj-*.pc` files do not contain the string `capnp`. The `CAPNP_PKG_CONFIG_FILES`
   list (`configure.ac:156-168`, confirmed: capnp, capnpc, capnp-rpc,
   capnp-json, capnp-websocket, kj, kj-async, kj-http, kj-gzip, kj-tls, kj-test)
   yields **5** files matching `capnp`, not 11. This is the AGENTS.md:577
   failure exactly: a correctly-scoped-looking filter that matches only what
   you expect. Use
   `ls lib/pkgconfig | grep -cE '^(capnp|capnpc)'` → **5**, and
   `ls lib/pkgconfig | grep -c '^kj'` → **6**, or just
   `ls lib/pkgconfig | grep -cE '^(capnp|capnpc|kj-)'` → **11**.

## What the recipe gets right

- **The system.** Every flag comes from `$AUTOCONF_CONFIGURE_FLAGS`;
  `--enable-static --disable-shared --without-fibers --with-zlib
  --with-openssl` are all real (`configure.ac:19,25,30,35` — `AC_ARG_WITH` for
  external-capnp/zlib/openssl/fibers, `AC_ARG_ENABLE` for reflection).
  No hardcoded target facts, no `export`ed search flags. `--prefix` comes from
  the system. Clean.
- **The config template.** `config.h.in` is right: `configure.ac:7` is
  `AC_CONFIG_HEADERS([config.h])` and the file is present (2,135 bytes). The
  guard sits after `./configure` and before `make`, touches
  `aclocal.m4 configure config.h.in` plus `find . -name 'Makefile.in'`.
  Correct.
- **`--without-fibers` is genuinely necessary, and I re-probed it.** Bionic has
  `<ucontext.h>` at every level but declares none of the three functions.
  Compiling a `getcontext` call against NDK r28 wrappers:
  ```
  api 21: error: call to undeclared library function 'getcontext'
  api 24: same    api 28: same    api 35: same
  ```
  All four fail identically, so "at any API level" is right. The reason to pass
  it anyway is the one the comment gives second: `configure.ac:290-294` then
  sets `-DKJ_USE_FIBERS=0` uniformly instead of warning and falling through to
  `-lucontext` (absent here). Good reasoning, correct flags.
- **`--with-zlib --with-openssl`** are justified properly:
  `configure.ac:196-234` really does `AC_CHECK_LIB` and only
  `AC_MSG_WARN([could not find zlib -- won't build libkj-gzip])` on failure, so
  leaving them at `check` would make the artifact set host-dependent. Both
  `packages/zlib` and `packages/openssl` exist. Correct.
- **No target binary is executed.** This is the claim I checked hardest, given
  the binfmt_misc/qemu risk. `test_capnpc_middleman`'s rule
  (`Makefile.am:487-490`) does run `./capnp$(EXEEXT)`, and the narrow targets
  genuinely do not reach it — `BUILT_SOURCES` appears only in `all`, `check`,
  `distdir`, `install`, `install-exec` and `CLEANFILES`, never as a
  prerequisite of `lib_LTLIBRARIES`. Confirmed safe. Worth noting the recipe's
  reasoning reaches the right answer partly by luck, which is why change 1
  matters: the *stated* mechanism (pre-generated files) is not the operative
  one.
- `make -j1` is explicit on every line; no fan-out.

## Per-system verdicts

Six of seven I accept as written. All six are WILL BUILD and I found nothing
API-gated in the library sources.

| system | my verdict | adder's | agree |
|---|---|---|---|
| aarch64-android21 | WILL BUILD | WILL BUILD | yes |
| aarch64-android24 | WILL BUILD | WILL BUILD | yes |
| aarch64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-android35 | WILL BUILD | WILL BUILD | yes |
| x86_64-mingw | UNCERTAIN | WILL BUILD | **no** |
| clang-native | WILL BUILD | WILL BUILD | yes |

**The mingw row is the one I would not sign.** `configure.ac:70-79` (verified)
branches `*mingw*` into `PTHREAD_CFLAGS="-mthreads"`, `PTHREAD_LIBS=""`,
`ASYNC_LIBS="-lws2_32"` — that part of the claim is right. But
`AX_CXX_COMPILE_STDCXX_14` at `configure.ac:68` must actually find a C++14
compiler, and the forecast asserts that "is satisfied by mingw g++" without
naming a version or a probe. The whole recipe's cross story on Windows rests on
one unexamined macro-conditional. UNCERTAIN is the honest answer until someone
reads what that macro expands to against the mingw g++ in this tree. This does
not change the package verdict — the Android rows are the ones that matter and
they are sound — but the builder should not be told mingw is green.

## Verdict

REJECT. The recipe uses the system correctly and its flags are all real; the
defects are (1) a comment that misstates why the narrow targets are safe and
presents a deliberate tools-omission as a build-system consequence, (2) eleven
`make` invocations where one target does the job — and in the process the CMake
package config that stage1 promises is silently never installed, and (3) a
verification count that cannot return the number it claims. All three are
fixable without touching a flag.
