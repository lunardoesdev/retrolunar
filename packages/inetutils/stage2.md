REJECT

# inetutils — stage 2 review

## Required changes

1. **`packages/inetutils/generic.lua:17` — the timestamp guard names a config
   template that does not exist, and misses the one that does.** The recipe
   runs `touch aclocal.m4 configure config.h.in`, but this tarball's template
   is **`config.hin`**. I verified in the unpacked tree:

   - `configure.ac:28` is `AC_CONFIG_HEADERS([config.h:config.hin])`
   - the file on disk is `nest/source/inetutils/config.hin`
   - `Makefile.in:2615` is `stamp-h1: $(srcdir)/config.hin $(top_builddir)/config.status`
   - `Makefile.in:2618` is `$(srcdir)/config.hin: $(am__configure_deps)`

   So `touch config.h.in` **creates a bogus empty file** (and the guard's
   `find . -name 'Makefile.in' | xargs touch` runs on line 18, but
   `config.hin` is not a `Makefile.in`). Meanwhile the real `config.hin` keeps
   its tarball mtime, which is *older* than the just-touched `aclocal.m4`, so
   make sees the `$(srcdir)/config.hin: $(am__configure_deps)` rule at line
   2618 as out of date and tries to re-run `autoheader` — which this prefix
   does not have. The guard does not suppress the thing it exists to suppress.

   Replace line 17 with:

   ```sh
           touch aclocal.m4 configure config.hin
   ```

   and add a comment naming why, since this is not the usual name:

   ```sh
           # config.hin, not config.h.in: configure.ac:28 is
           # AC_CONFIG_HEADERS([config.h:config.hin]).
   ```

2. **`packages/inetutils/generic.lua:36-42` — six bare `make` invocations, none
   of them `-j1`.** Lines 36-41 are `make -C lib`, `make -C libinetutils`,
   `make -C libtelnet`, `make -C libicmp`, `make -C libls`, `make -C telnet
   AM_CPPFLAGS=...`, and line 42 is a bare `make`. `AGENTS.md:226-229` requires
   serial builds. Every one of these needs `-j1`, including the `telnet` one
   whose `AM_CPPFLAGS=` argument must stay:

   ```sh
           make -j1 -C lib
           make -j1 -C libinetutils
           make -j1 -C libtelnet
           make -j1 -C libicmp
           make -j1 -C libls
           make -j1 -C telnet AM_CPPFLAGS="-DTERMCAP -DLINEMODE -DKLUDGELINEMODE -DENV_HACK -I. -I.. -I../lib -I../libinetutils -include ../termios-first.h"
           make -j1
   ```

3. **`packages/inetutils/generic.lua:34-35` — the empty
   `cat > termios-first.h <<'EOF' / EOF` heredoc needs a comment.** It exists
   so the `telnet` subdir can `-include` a header before anything else
   (Bionic's `<termios.h>` ordering), but nothing in the recipe says so. Per
   `AGENTS.md:29` ("Explain non-obvious flags and recipe-local workarounds"),
   add above line 34:

   ```sh
           # telnet's sources need termios.h's feature macros settled before
           # any other header; -include'ing an empty file first (see the
           # -include below) forces that ordering.
   ```

4. **`packages/inetutils/stage1.md` — its line references are stale.** It
   cites `generic.lua:31-33` for the guard (actually 17-18) and `:36-40` for
   the subdir order (actually 36-41). Fix both, and correct the
   `touch config.h.in` claim to `config.hin`.

## What the forecast got right

**The `ether_hostton` blocker is CONFIRMED and is correctly framed as
permanent.** I verified it independently rather than taking it on trust:

- `llvm-nm --defined-only` on `sysroot/usr/lib/aarch64-linux-android/libc.a`
  finds only `T ether_aton` and `T ether_ntoa` — **no `ether_hostton`**.
- `netinet/ether.h` declares only `ether_ntoa`, `ether_ntoa_r`, `ether_aton`,
  `ether_aton_r`.

So this is *not* an API-level gate like `less`/`ninja`/`kmod`: android35 does
not help, and no target in this tree ever will. The only fixes are patching
upstream or shipping a shim, both forbidden by `AGENTS.md:28-29`. The
forecast's framing — "The telnet half builds" — is also right and is the
useful part.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/telnet` | `test -x $PREFIX/bin/telnet` — the half that builds |
| `$PREFIX/sbin/ifconfig` symlink | `test -L $PREFIX/sbin/ifconfig` (created by `generic.lua:43`) |
| **the check that catches the guard bug** | the build log must contain **no** `autoheader` invocation; if you see `cd ... && autoheader`, required change 1 was not applied |

Build order that makes sense here: `clang-native` first (it clears both
`ether_hostton` and the telnet termios issue, so it produces the most
artifacts and exercises the guard), then an Android target to confirm the
predicted `ether_hostton` failure.