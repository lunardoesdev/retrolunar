# inetutils build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.8 (GNU release tarball from ftp.gnu.org)
- Build system: autotools. This one ships its own `configure`, so
  `$AUTOCONF_CONFIGURE_FLAGS` and the `touch aclocal.m4 configure config.hin`
  + `find . -name 'Makefile.in' | xargs touch` guard at `generic.lua:31-33`
  apply.
- Installs: `bin/telnet` and `bin/ifconfig`, plus the intermediate libraries
  `lib/libinetutils.a`, `lib/libtelnet.a`, `lib/libicmp.a`, `lib/libls.a`.
  No `.pc` files and no headers.
- Requires: `inetutils@source`, `ncurses` (exists in `packages/`).

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | `ifconfig/changeif.c:256` calls `ether_hostton`. Bionic has no such symbol and no header declaring it: I checked `llvm-nm --defined-only` on the sysroot's `libc.a` and `ether_hostton` has **zero** matches while `ether_aton` has one, and `$SYSROOT/usr/include/netinet/ether.h` declares only `ether_aton`/`ether_aton_r`/`ether_ntoa`/`ether_ntoa_r` (lines 63-71). glibc declares `ether_hostton` in `<netether.h>`, which Bionic does not have. `topackage.md:42` records exactly this. The failure is at link time, so `libinetutils.a` and friends build and `telnet` links, but `ifconfig` cannot. |
| aarch64-android24 | **WILL NOT BUILD** | Same `ether_hostton` wall; nothing about API 24 changes it. |
| aarch64-android35 | **WILL NOT BUILD** | Same; the symbol is absent at every API level, not gated by one. |
| x86_64-android35 | **WILL NOT BUILD** | Same. |
| x86_64-mingw | UNCERTAIN | `ether_hostton` is not a Bionic problem, but Bionic is also not the target. mingw-w64's `winsock2.h`/`ws2tcpip.h` do not export `ether_hostton` either; ifconfig is also not normally built on Windows. What would settle it: whether `configure` even attempts ifconfig under this `--host`, and whether mingw's headers declare the function. The telnet half would build. |
| clang-native | WILL BUILD | glibc **does** provide `ether_hostton`, so the whole package links natively. This is a cross-only blocker, not an upstream bug. |

**API level notes.** The blocker is not an API-level gate — `ether_hostton` is
simply absent from Bionic at every level, so raising the API level would not
help. That is the important distinction: **no amount of `android35` fixes
this.** The only fixes are patching the call site or shipping a shim, both
forbidden by AGENTS.md:28-29. `armv7a-android*` and `i686-android*` match
`aarch64-android*`.

**Risks / what a reviewer should check.**

1. **The telnet workaround is a real, working local fix and it is still
   there** — `generic.lua:19-30`. `telnet/sys_bsd.c` uses `struct termios` and
   the `tcgetattr` family without including `<termios.h>`; glibc drags it in
   transitively, Bionic does not. The recipe writes a two-line
   `termios-first.h` (config.h first, because gnulib refuses to be included
   before it) and force-includes it. That is a legitimate recipe-local
   workaround, correctly commented, and it is exactly the kind of thing
   AGENTS.md:218-222 permits. It is a build-only artefact, not a source patch.
2. **The `AM_CPPFLAGS` restatement at `generic.lua:41` is load-bearing and easy
   to break.** A command-line variable assignment *replaces* the makefile's,
   so the recipe re-states `-I. -I.. -I../lib -I../libinetutils` verbatim. If
   upstream changes those paths, this line must change with it. The reason it
   exists at all is that the top-level make walks `SUBDIRS` in order and telnet
   links `../libtelnet/libtelnet.a`, so the libraries are built first by hand
   (`:36-40`).
3. **`make -C telnet` before the top-level `make` is a workaround, not an
   optimisation.** It exists because the `-include` flag has to be passed to
   one subdirectory only. Do not "simplify" it into a single `make`.
4. The `ifconfig` symlink at `generic.lua:47` (`ln -s ../sbin/ifconfig
   $OUT/bin/ifconfig`) is an LFS layout convenience: LFS moves ifconfig from
   sbin to bin, and the recipe links rather than `mv` so `$OUT/sbin` keeps its
   copy. Fine, and additive.
5. `topackage.md:42` says telnet "links and is a real Android 24 aarch64
   binary" — that is consistent with this forecast. The entry's `[ ]` with a
   "mostly builds" note is honest, not stale.

**How to verify once built** (on `clang-native`, the only system that can
currently build it).

- `bin/telnet` and `bin/ifconfig` exist under `$NESTDIR/clang-native/`.
- `$OBJDUMP -f bin/telnet` prints the host machine (`elf64-x86-64`).
- `nm bin/telnet | grep telnet_init` finds `telnet_init` defined.
- On Android, expect the run to stop at ifconfig: the log will show
  `undefined reference to 'ether_hostton'`. That is the expected, recorded
  failure, not a regression.
