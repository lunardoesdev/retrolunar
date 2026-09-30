# libnl-3 — stage 1 build forecast

- **Package**: libnl-3
- **Version**: 3.12.0 (tag `libnl3_12_0`, the current `releases/latest`)
- **Upstream URL**: https://github.com/thom311/libnl/releases/download/libnl3_12_0/libnl-3.12.0.tar.gz
- **Build system**: autotools, **fully non-recursive** — a single top-level
  `Makefile.am` (about 1100 lines) that compiles `lib/`, `src/`, `tests/`
  and `man/` in one directory. `AC_CONFIG_HEADERS([include/config.h])`, so
  the template is `include/config.h.in`. Top directory is `libnl-3.12.0/`.

**These are predictions from reading the source and the recipe, not
measurements. Nothing here has been configured, compiled or run.**

## The real Android wall: there is no `libpthread` to find

This is the finding that shapes the package, and it is not subtle.

`configure.ac:117-121`:

```m4
AC_ARG_ENABLE([pthreads],
    AS_HELP_STRING([--disable-pthreads], [Disable pthreads support]),
    [enable_pthreads="$enableval"], [enable_pthreads="yes"])
AM_CONDITIONAL([DISABLE_PTHREADS], [test "$enable_pthreads" = "no"])
if test "x$enable_pthreads" = "xno"; then
    AC_DEFINE([DISABLE_PTHREADS], [1], [Define to 1 to disable pthreads])
else
    AC_CHECK_LIB([pthread], [pthread_mutex_lock], [], AC_MSG_ERROR([libpthread is required]))
fi
```

`AC_CHECK_LIB` **links** `-lpthread`. Bionic has no `libpthread` at all —
not as a stub, not at any API level. I searched the whole NDK r28b sysroot:

```
find sysroot -name 'libpthread*'   →  (no output)
```

and listed `usr/lib/aarch64-linux-android/21/`, which has `libc.so libm.so
libdl.so liblog.so libz.so …` and no `libpthread.*`. So on **every** Android
target in this repo, the `else` branch runs, the link fails, and configure
aborts with `libpthread is required`.

That is why this is the one package of the five that needs an
`android.lua`. `--disable-pthreads` defines `DISABLE_PTHREADS`, and
`include/base/nl-base-utils.h` then compiles the locking helpers away
(lines 23 and 829):

```c
#ifndef DISABLE_PTHREADS
#include <pthread.h>
#endif
...
#else
#define NL_LOCK(NAME)     int __unused_lock_##NAME _nl_unused
#define NL_RW_LOCK(NAME)  int __unused_lock_##NAME _nl_unused
#define nl_lock(LOCK)  do { } while (0)
#define nl_unlock(LOCK) do { } while (0)
...
```

The library still compiles and works; it just stops guarding its own
caches (`lib/cache_mngt.c:83,144,222`, `lib/socket.c:84`,
`lib/route/link/api.c:48`, `lib/utils.c:497`) against concurrent callers.
For a single-threaded Android process that is almost always fine; for a
multi-threaded one that shares a `nl_socket` cache it is a real
behavioural regression. I am shipping it because the alternative is a
package that does not configure at all on Android, and the loss is
documented here and in the recipe comment. **A reviewer who considers
unlocked caches unacceptable on Android should drop this package rather
than ship it with `--disable-pthreads`.**

Note that this is the opposite of the *usual* Bionic pthread problem. The
common failure is a library that insists on `-lpthread` when Bionic has
folded pthreads into libc. libnl-3 has that bug.

**Note that the obvious system-level fix is a trap.**
`AC_CHECK_LIB([pthread], …)` at `configure.ac:119` *does* have a cache
variable — `ac_cv_lib_pthread_pthread_mutex_lock` — and presetting it to
`yes` in `packages/<sys>/generic.lua` would stop configure aborting. But
that is worse than the flag, not better: `AC_CHECK_LIB`'s default
action-if-found prepends `-lpthread` to `LIBS`, so every subsequent link in
libnl-3 would then carry `-lpthread`, and `ld.lld` fails with
`unable to find library -lpthread`. (Confirmed at the linker.)
`--disable-pthreads` is therefore the only mechanism that both configures
*and* links, which is why the flag lives in `packages/libnl-3/android.lua`
rather than in a system cache answer.

An earlier version of this file said there was "no cache variable to
preset". **That was wrong**, and the conclusion was right only by accident.

## The CLI: `--enable-cli=no`, and what it changes

`configure.ac:98-108` defaults `enable_cli` to `yes`, which means `bin`.
With it on:

- 51 CLI programs are built and installed (`cli_programs`, Makefile.am).
- `libnl-cli-3` is built and installed as a real library
  (`src/lib/libnl-cli-3.la`).
- `libnl-cli-3.0.pc` is added to `pkgconfig_DATA`.
- 14 more `netlink/cli/*.h` headers are installed.
- The `pkglibdir` plugin modules (`lib/cli/cls/{basic,cgroup}.la`,
  `lib/cli/qdisc/*.la`, 9 in total) are built and installed.
- `src_lib_libnl_cli_3_la_LIBADD` includes **`-ldl`**.

With `--enable-cli=no` every one of those moves to `check_LTLIBRARIES` /
`check_PROGRAMS`, which the `all` target does not build. That drops `-ldl`
from the link entirely, which matters: Bionic's `libdl.a` is a stub and
Windows has no `-ldl` at all.

The six libraries that *are* installed:

| library | notes |
| --- | --- |
| `libnl-3` | core, `lib/libnl-3.la` |
| `libnl-route-3` | routing, links `libnl-3` + the generated grammar lib |
| `libnl-idiag-3` | socket diagnostics |
| `libnl-genl-3` | generic netlink |
| `libnl-nf-3` | netfilter, links `libnl-3` + `libnl-route-3` |
| `libnl-xfrm-3` | IPsec, links `libnl-3` |

## flex and bison: required, and native

The tarball ships `lib/route/pktloc_grammar.l`, `lib/route/pktloc_syntax.y`,
`lib/route/cls/ematch_grammar.l` and `lib/route/cls/ematch_syntax.y`, and
**not** the generated `.c`/`.h` — those are in `CLEANFILES`. Four
hand-written rules in `Makefile.am` run `$(FLEX)` and `$(YACC)` on them, and
`lib/route/libnl-grammar.la` is a `noinst_LTLIBRARIES` entry, so `make all`
cannot skip it. `configure.ac:74-75` sets `FLEX` and `YACC` with
`AC_CHECK_PROGS`, which is a PATH search for host programs.

So the recipe requires `flex@native` and `bison@native`. Both exist in this
repo (`packages/flex`, `packages/bison`); `bison@native` itself pulls
`gperf@native` through its own recipe. Native is required, not merely
preferable: a cross-compiled flex would run under no emulator, and
generating C is a build-machine job.

`bison` is invoked as `bison -y` (`YACC = 'bison -y'`), which is why the
`@native` form is `bison`, not `yacc`.

One more configure detail: `PKG_CHECK_MODULES([CHECK], [check >= 0.9.0])`
at `configure.ac:85` prints `*** Disabling building of unit tests` and sets
`has_check=no` when the `check` unit-test framework is not in the prefix. It
is not, and that is a warning, not an error. Fine.

Also: `AC_CONFIG_SUBDIRS([doc])` at `configure.ac:104`, but the release
tarball has **no `doc/` directory** at all. The generated `configure`
handles that — `test -d "$srcdir/$ac_dir" || continue` with the comment
"Do not complain, so a configure script can configure whichever parts of a
large source tree are present" (configure line ~23300). I read that, so
configure will not fail on the missing subdir.

## What it installs

- The six `lib/libnl-3.so`-shaped archives listed above, static:
  `lib/libnl-3.a`, `libnl-route-3.a`, `libnl-idiag-3.a`, `libnl-genl-3.a`,
  `libnl-nf-3.a`, `libnl-xfrm-3.a`.
- `include/libnl3/netlink/**` — roughly 190 headers across
  `netlink/`, `netlink/fib_lookup/`, `netlink/genl/`, `netlink/idiag/`,
  `netlink/netfilter/`, `netlink/route/**` and `netlink/xfrm/`. The
  `netlink/cli/*` headers are *not* installed (`--enable-cli=no`).
- `lib/pkgconfig/`: `libnl-3.0.pc`, `libnl-genl-3.0.pc`,
  `libnl-idiag-3.0.pc`, `libnl-nf-3.0.pc`, `libnl-route-3.0.pc`,
  `libnl-xfrm-3.0.pc`. **No `libnl-cli-3.0.pc`** — that one is added only
  under `ENABLE_CLI`.
- `share/man/man8/`: six pages (`dist_man8_MANS`) for
  `genl-ctrl-list`, `nl-classid-lookup`, `nl-pktloc-lookup`,
  `nl-qdisc-add`, `nl-qdisc-delete`, `nl-qdisc-list`.
- `$sysconfdir/libnl/pktloc` and `$sysconfdir/libnl/classid`
  (`pkgsysconf_DATA`) — two small lookup tables.
- No programs, with `--enable-cli=no`.

## Dependencies

- `flex@native`, `bison@native` — see above. Both exist in this repo.
  `bison` transitively needs `gperf@native`, which it already requires.
- `libnl-3@source`.
- Nothing else. libnl-3 has no zlib, no crypto and no external C library
  dependency in this configuration; `-ldl` is the only extra link flag and
  `--enable-cli=no` removes it.

## Per-system verdicts

armv7a and i686 Android targets match the aarch64 rows unless stated. The API
level is *not* the variable for this package — the missing `libpthread` is,
and it is missing at every level. The API level would only matter if
something needed `posix_spawn`, `mblen`, `getpass`, `O_BINARY`,
`process_vm_readv`, `nl_langinfo`, `program_invocation_short_name`,
`get_current_dir_name`, `fread_unlocked` or `scandir`/`versionsort`, and
none of the library sources reference any of them (grepped `lib/` and
`src/`).

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD, with a behavioural caveat** | Blocked and then unblocked: configure's `AC_CHECK_LIB([pthread], ...)` at `configure.ac:119` is a hard error on a target with no `libpthread`, and the NDK r28b sysroot has none at any API level (verified by `find` and by listing `usr/lib/aarch64-linux-android/21/`). `packages/libnl-3/android.lua` passes `--disable-pthreads`, which is the only upstream cure and which trades away the library's internal locking. Everything else checks out: `AF_NETLINK` is `16` in the NDK's `sys/socket.h:144`; `linux/netlink.h`, `linux/rtnetlink.h`, `linux/genetlink.h` and `linux/netfilter/nfnetlink.h` are all present in the NDK sysroot *and* vendored under `include/linux-private/`, so the UAPI headers do not depend on the sysroot version; `strerror_l` exists (`string.h:143`, aliased to `strerror`) together with `newlocale`/`freelocale` (`locale.h:102-103`), all three exported by `libc.so` at 21, so the `HAVE_STRERROR_L` branch in `lib/utils.c:180-204` compiles. |
| `aarch64-android24` | **WILL BUILD, with a behavioural caveat** | Identical: the pthread wall is level-independent, `--disable-pthreads` applies, and nothing else needs a level above 21. |
| `aarch64-android35` | **WILL BUILD, with a behavioural caveat** | As above. |
| `x86_64-android35` | **WILL BUILD, with a behavioural caveat** | Same. libnl-3 has no arch-specific code at all — no `$arch` conditional exists in the `Makefile.am` library sections, and the netlink message format is the same everywhere. |
| `x86_64-mingw` | **WILL NOT BUILD** | Netlink is a Linux kernel socket family. `AF_NETLINK` is not defined in mingw-w64's `winsock2.h`, and `lib/nl.c:117` calls `socket(AF_NETLINK, SOCK_RAW | flags, protocol)` unconditionally — the first thing `nl_socket_alloc()` does. Beyond that, the whole tree is `linux/` UAPI headers, and `lib_libnl_3_la_LDFLAGS` passes `-Wl,--version-script=$(srcdir)/libnl-3.sym`, an ELF-only linker option. Separately, mingw-w64 *does* have `libpthread` (`/usr/x86_64-w64-mingw32/lib/libpthread.dll.a`), so the pthread wall that shapes Android does **not** apply here — this is a genuine platform gap, not a toolchain one. |
| `clang-native` | **WILL BUILD** | Native glibc. `-lpthread` links fine, so the generic recipe (no `--disable-pthreads`) is correct here and the internal locking is kept. flex and bison come from `$NATIVE_PREFIX/bin` via the same `@native` mechanism. |

## For a reviewer to scrutinise

1. **`android.lua` exists solely for `--disable-pthreads`.** Its cost is
   documented: `DISABLE_PTHREADS` compiles `NL_LOCK`/`NL_RW_LOCK` away to
   no-ops (`include/base/nl-base-utils.h`), so libnl's internal caches
   (`lib/cache_mngt.c`, `lib/socket.c`, `lib/route/link/api.c`) stop being
   guarded against concurrent callers. **That is a real behavioural
   regression for a multi-threaded process sharing an `nl_socket`, and it
   belongs in the readme** — the fact, not the option to drop the package.
   It is not a reason to drop the package: without the switch `configure`
   aborts on every Android target, and the alternative (a cache answer)
   breaks every link instead.
2. **`--disable-pthreads` is not a configure cache answer, because the
   cache answer is worse.** A system-level
   `ac_cv_lib_pthread_pthread_mutex_lock=yes` *would* stop configure
   aborting, but `AC_CHECK_LIB`'s action-if-found prepends `-lpthread` to
   `LIBS` and every later link then fails. The recipe-local flag is the only
   mechanism that both configures and links.
3. **`--enable-cli=no-inst` is not a softer `no`.** `ENABLE_CLI` is
   `test "$enable_cli" != "no"` (`configure.ac:106`), so `no-inst` leaves it
   true: `libnl-cli-3.la` stays in `check_LTLIBRARIES` (`Makefile.am:727`)
   and **`-ldl` does *not* reappear**. What does change is `Makefile.am:829-836`,
   where the 51 `cli_programs` move from `check_PROGRAMS` to
   `noinst_PROGRAMS` — and `noinst_PROGRAMS` **is** in `all`. So `no-inst`
   builds all 51 CLI programs and installs none of them. It is strictly
   worse than `no`, not a middle setting. (An earlier version of this item
   claimed `no-inst` moved `libnl-cli-3.la` back to `lib_LTLIBRARIES` and
   brought `-ldl` with it; both halves were wrong.)
4. **`--disable-shared` and the version scripts.** Every
   `lib_libnl_*_3_la_LDFLAGS` has `-Wl,--version-script=$(srcdir)/libnl-3.sym`.
   For a static archive libtool does not link, so this is inert — the same
   argument as for libnuma. Untested.
5. **flex/bison version coupling.** libnl's `.l`/`.y` files are ordinary
   lexer/parser input with no unusual constructs that I saw, so the flex
   2.6.4 and bison 3.8.2 already in this prefix should be fine. If the
   generated C fails to compile, that pairing is the first thing to check,
   not the target.
6. **Timestamp guard.** `include/config.h.in` is not at the top level, so
   the recipe names it. The tarball ships no `config.status` and no
   `libtool` (checked), so neither is in the touch list.
