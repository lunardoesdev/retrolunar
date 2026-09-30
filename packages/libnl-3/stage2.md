REJECT

# libnl-3 — stage 2 review

Reviewed against `AGENTS.md`, `packages/aarch64-android24/generic.lua` (and
all 60 Android system files), `packages/x86_64-mingw/generic.lua`,
`packages/clang-native/generic.lua`, and the real 3.12.0 tarball (downloaded,
listed, files read — nothing built).

## What the recipe gets right

- **`--enable-cli=no` is real and spelled right.** `configure.ac:99-108`:
  `AC_ARG_ENABLE([cli], AS_HELP_STRING([--enable-cli=yes|no|no-inst|bin|sbin], …))`,
  `[enable_cli="$enableval"], [enable_cli="yes"])`, then
  `AM_CONDITIONAL([ENABLE_CLI], [test "$enable_cli" != "no"])`. With `no`,
  `ENABLE_CLI` is false and I traced every consequence in `Makefile.am`:
  - `src/lib/libnl-cli-3.la` moves from `lib_LTLIBRARIES` (`:724`) to
    `check_LTLIBRARIES` (`:727`);
  - the nine CLI plugin modules move to `check_LTLIBRARIES` (`:690`);
  - all 51 `cli_programs` move to `check_PROGRAMS` (`:838`);
  - `libnl-cli-3.0.pc` drops out of `pkgconfig_DATA` (`:1244`).
  `check_*` are not in `all`, so `make -j1` builds none of them.
- **With the switch off, nothing links `-ldl`.** `-ldl` occurs exactly once in
  the whole `Makefile.am`, at line 758, inside
  `src_lib_libnl_cli_3_la_LIBADD`, which is only compiled when `ENABLE_CLI`.
  I grepped the entire tree: no other `-ldl`, no `LIBADD` with a library flag
  outside `$(CHECK_LIBS)` (test-only). Confirmed.
- **The Android pthread wall is REAL and the fix is the only one available.**
  `configure.ac:112-119` is `--disable-pthreads` →
  `AM_CONDITIONAL([DISABLE_PTHREADS], …)` / `AC_DEFINE([DISABLE_PTHREADS])`,
  else `AC_CHECK_LIB([pthread], [pthread_mutex_lock], [],
  AC_MSG_ERROR([libpthread is required]))` — a hard error. And Bionic has no
  `libpthread` at any API level: `find` over the whole NDK sysroot for
  `libpthread*` returns nothing, and I confirmed it at the linker with
  `aarch64-linux-android24-clang … -lpthread` → `ld.lld: error: unable to
  find library -lpthread`. The switch is real and it is the upstream cure.
- **`android.lua` is in exactly the right place.** All 60 `packages/*android*/generic.lua`
  files carry `recipe_fallbacks = {"android"}` (I enumerated them), so one
  `packages/libnl-3/android.lua` covers every Android target with no
  per-target copies — which is what AGENTS.md requires.
- **flex and bison are genuinely required, and both are named correctly.**
  The tarball ships `lib/route/pktloc_grammar.l`, `lib/route/pktloc_syntax.y`,
  `lib/route/cls/ematch_grammar.l`, `lib/route/cls/ematch_syntax.y` and **no**
  generated `.c`/`.h` — confirmed by `find`. `Makefile.am:419-421` lists the
  generated files in `CLEANFILES`, `:374-396` has four rules driving
  `$(FLEX)`/`$(YACC)`, and `lib/route/libnl-grammar.la` is
  `noinst_LTLIBRARIES` (`:407`) so `make all` cannot skip it.
  `configure.ac:156-163` `AC_MSG_ERROR`s if `YACC` or `FLEX` is empty, so a
  missing tool is a hard configure failure. `require("flex@native")` and
  `require("bison@native")` name packages that exist (`packages/flex`,
  `packages/bison`), use the right spelling, and `bison@native` transitively
  pulls `gperf@native` through its own recipe — which is correct, since
  `configure.ac:73` wants `bison -y`, i.e. the `bison` binary, not `yacc`.
  The loader puts `$NATIVE_PREFIX/bin` on `PATH` for every block
  (`src/loader.lua:412-415`), which is what `AC_CHECK_PROGS(FLEX, 'flex')` and
  `AC_CHECK_PROGS(YACC, 'bison -y')` (`configure.ac:72-73`) search.
- **Config template name is the real one**: `configure.ac:40` is
  `AC_CONFIG_HEADERS([include/config.h])`; `include/config.h.in` is the only
  one shipped and both recipes name it correctly. Guard position correct.
- **`AC_CONFIG_SUBDIRS([doc])` with no `doc/` dir is safe** — `configure:23303`
  has `test -d "$srcdir/$ac_dir" || continue` with upstream's own comment.
  Verified by reading the shipped script.
- **`make -j1` everywhere**, no `sed`, no patch, no `/dev/null`, no
  `export` of search flags. `--with-pic` is a real libtool option
  (`configure:11000`). Source recipe correct: 3.12.0 is current
  (`releases/latest`), URL 200, top dir `libnl-3.12.0/` stripped, `dl/` guard,
  `curl -C -`, lands in `$OUT/libnl-3/`.

## Required changes

1. **`packages/libnl-3/stage1.md:76-80` — a false claim that would send the
   next maintainer down the wrong path.** It says "`AC_CHECK_LIB` with an
   `AC_MSG_ERROR` action has no cache variable to preset, so there is no
   `ac_cv_search_pthread_mutex_lock` style override that would work here,
   because `AC_CHECK_LIB` with an `AC_MSG_ERROR` action has no cache variable
   to preset." That is wrong: `AC_CHECK_LIB` caches into
   **`ac_cv_lib_pthread_pthread_mutex_lock`**, which is settable like any other.
   Replace stage1.md:76-80 with:
   "Note that the obvious system-level fix is a trap.
   `AC_CHECK_LIB([pthread], …)` at `configure.ac:119` *does* have a cache
   variable — `ac_cv_lib_pthread_pthread_mutex_lock` — and presetting it to
   `yes` in `packages/<sys>/generic.lua` would stop configure aborting. But
   that is worse than the flag, not better: `AC_CHECK_LIB`'s default
   action-if-found prepends `-lpthread` to `LIBS`, so every subsequent link in
   libnl-3 would then carry `-lpthread`, and `ld.lld` fails with
   `unable to find library -lpthread`. I confirmed that link failure directly.
   `--disable-pthreads` is therefore the only mechanism that both configures
   and links, which is why the flag lives in `packages/libnl-3/android.lua`
   rather than in a system cache answer."
   The stage1 conclusion is unchanged; only the reasoning was wrong.

2. **`packages/libnl-3/stage1.md:205-209` (item 3) says that changing
   `--enable-cli=no` to `--enable-cli=no-inst` puts `libnl-cli-3.la` back in
   `lib_LTLIBRARIES` "and `-ldl` comes back".** The second half is wrong, and
   it is the half that matters, because it names the exact mechanism
   (`Makefile.am:721-727`: `if ENABLE_CLI` / `lib_LTLIBRARIES += …` /
   `else` / `check_LTLIBRARIES += …`). `ENABLE_CLI` is
   `test "$enable_cli" != "no"` (`configure.ac:106`), so `no-inst` — like `bin`
   and `sbin` — leaves it **true** and keeps `libnl-cli-3.la` in
   `check_LTLIBRARIES`. `-ldl` does **not** come back; what comes back is the
   51 CLI programs, which `no-inst` puts in `noinst_PROGRAMS`
   (`Makefile.am:833`). Rewrite that item as:
   "`--enable-cli=no-inst` is not a softer `no`. `ENABLE_CLI` is
   `test \"$enable_cli\" != \"no\"` (`configure.ac:106`), so `no-inst` leaves it
   true: `libnl-cli-3.la` stays in `check_LTLIBRARIES` (`Makefile.am:727`) and
   `-ldl` does **not** reappear. What does change is `Makefile.am:829-836`,
   where the 51 `cli_programs` move from `check_PROGRAMS` to
   `noinst_PROGRAMS` — and `noinst_PROGRAMS` **is** in `all`. So `no-inst`
   builds all 51 CLI programs and installs none of them. It is strictly worse
   than `no`, not a middle setting."

3. **`packages/libnl-3/stage1.md:196-199` (item 1) offers the reviewer the
   option "delete `packages/libnl-3/android.lua` and the Android targets
   revert to 'configure fails with a clear message'."** That is not a real
   option — a package that fails to configure on 60 of the systems in this
   repo is not shippable — and leaving it in the document invites exactly the
   "simplification" the rest of stage1 warns against. Delete that sentence and
   keep only the first half of the item, which is the useful part: replace
   stage1.md:196-199 with:
   "`android.lua` exists solely for `--disable-pthreads`. Its cost is
   documented: `DISABLE_PTHREADS` compiles `NL_LOCK`/`NL_RW_LOCK` away to no-ops
   (`include/base/nl-base-utils.h`), so libnl's internal caches
   (`lib/cache_mngt.c`, `lib/socket.c`, `lib/route/link/api.c`) stop being
   guarded against concurrent callers. That is a real behavioural regression
   for a multi-threaded process sharing an `nl_socket`, and it belongs in the
   readme. It is not a reason to drop the package: without the switch
   `configure` aborts on every Android target, and the alternative
   (a cache answer) breaks every link instead."

4. **`packages/libnl-3/android.lua:10-19` — the comment is right but should
   name the one fact that proves it, because that fact is not obvious and
   takes a filesystem search to establish.** Append to the comment:
   "Verified: `find` over the whole NDK sysroot for `libpthread*` returns
   nothing, and `aarch64-linux-android24-clang … -lpthread` fails with
   `ld.lld: error: unable to find library -lpthread`. There is no stub."

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libnl-3.a`, `libnl-route-3.a`, `libnl-idiag-3.a`, `libnl-genl-3.a`, `libnl-nf-3.a`, `libnl-xfrm-3.a` | `ls $PREFIX/lib/libnl-*-3.a \| wc -l` → `6` |
| `$PREFIX/lib/libnl-3.a` contents | `llvm-nm --defined-only $PREFIX/lib/libnl-3.a` shows `T nl_socket_alloc` (`lib/socket.c:227`) |
| **nothing links `-ldl`** | `llvm-nm --undefined-only $PREFIX/lib/libnl-*-3.a \| grep -c dlopen` → `0` |
| `$PREFIX/include/libnl3/netlink/socket.h` (+ ~190 more) | `test -f`; `ls $PREFIX/include/libnl3/netlink/route/link.h` for a header that needs the grammar |
| `$PREFIX/lib/pkgconfig/libnl-3.0.pc` and 5 siblings, **no `libnl-cli-3.0.pc`** | `pkg-config --modversion libnl-3.0` → `3.12.0`; `ls $PREFIX/lib/pkgconfig \| wc -l` → `6` |
| `$PREFIX/share/man/man8/` — 6 pages | `ls $PREFIX/share/man/man8 \| wc -l` → `6` (the `.8` files ship pre-generated in `man/`, verified) |
| `$PREFIX/etc/libnl/pktloc`, `$PREFIX/etc/libnl/classid` | `test -f` — `pkgsysconf_DATA`, so the exact dir depends on `sysconfdir`; check `find $PREFIX -name pktloc` |
| **no** `$PREFIX/bin`, **no** `libnl-cli-3.a` | `test ! -e $PREFIX/bin` — proves `--enable-cli=no` took effect |

## Where the builder is most likely to be wrong

1. **The `x86_64-mingw` row.** stage1's verdict (`WILL NOT BUILD`) is right and
   its reasons check out — `lib/nl.c:117` calls
   `socket(AF_NETLINK, SOCK_RAW | flags, protocol)` unconditionally,
   `AF_NETLINK` is not in mingw-w64's `winsock2.h`, and every
   `lib_libnl_*_3_la_LDFLAGS` carries `-Wl,--version-script=$(srcdir)/libnl-3.sym`.
   Worth knowing for the log: mingw-w64 *does* ship `libpthread`, so the
   Android-specific `--disable-pthreads` is not the thing that fails there, and
   `packages/libnl-3/generic.lua` (no `--disable-pthreads`) is the file that
   would be used. Expect configure to succeed and the build to fail in the
   compiler.
2. **flex/bison from `$NATIVE_PREFIX`.** `configure.ac:72-73` uses
   `AC_CHECK_PROGS`, a plain `PATH` search, and `loader.lua:412-415` puts the
   native prefix first — so the native `flex`/`bison` win over any distro ones.
   If the grammar fails to build, check the flex/bison *versions* first
   (stage1 item 5 is right that this is the first thing to look at), and only
   then the `.l`/`.y` files.
3. **`PKG_CHECK_MODULES([CHECK], [check >= 0.9.0])`** (`configure.ac:85`).
   `PKG_CONFIG_PATH` is empty and `PKG_CONFIG_LIBDIR` points at our prefix, so
   this prints `*** Disabling building of unit tests` and sets `has_check=no`.
   That is a warning, not an error — do not go looking for a missing `check`
   package.
4. **`$sysconfdir/libnl/*`.** These are the only artifacts in the whole
   package whose install path I could not pin from the recipe alone; if the
   expected `etc/libnl/pktloc` is missing, `find $PREFIX -name pktloc` tells
   you where it went rather than whether it was installed.
5. **`--disable-pthreads` is a behaviour change, not just a build flag.**
   If a downstream consumer shows unsynchronised libnl caches under threads,
   that is the cause, and required change 3 makes the readme note mandatory.