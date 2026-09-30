# libnuma — stage 1 build forecast

- **Package**: libnuma
- **Version**: 2.0.19 (tag `v2.0.19`, the current `releases/latest`)
- **Upstream URL**: https://github.com/numactl/numactl/releases/download/v2.0.19/numactl-2.0.19.tar.gz
- **Build system**: autotools, **one non-recursive `Makefile.am` with no
  `SUBDIRS` at all**. Top directory is `numactl-2.0.19/`.

**These are predictions from reading the source and the recipe, not
measurements. Nothing here has been configured, compiled or run.**

## Tarball provenance: verified, and it matters

Prior research recorded that the Debian orig tarball and the GitHub tag
archive ship no generated `Makefile.in`. I checked all three for v2.0.19
rather than taking it on trust:

| tarball | `configure` | `Makefile.in` | `config.h.in` |
| --- | --- | --- | --- |
| GitHub **release asset** `numactl-2.0.19.tar.gz` | yes | **yes** | yes |
| GitHub **tag archive** `archive/refs/tags/v2.0.19.tar.gz` | yes | **no** | no |
| Debian `numactl_2.0.19.orig.tar.gz` | yes | **no** | no |

Confirmed: the prior research is correct, and the release asset is the
only one of the three that can build without running automake/autoconf.
The recipe uses the release asset, and `source.lua` carries the reason as a
comment so nobody "simplifies" the URL later to the tag archive.

## The one non-recursive Makefile, and why the recipe does not run `make all`

`Makefile.am` (the whole file, 130 lines) declares:

- `bin_PROGRAMS = numactl numastat numademo migratepages migspeed memhog`
  — six host command-line tools, each linking `libnuma.la`.
- `lib_LTLIBRARIES = libnuma.la`
- `include_HEADERS = numa.h numacompat1.h numaif.h`
- `dist_man_MANS` — seven man pages, all for the tools.
- `pkgconfig_DATA = numa.pc` (generated from `numa.pc.in` by a hand-written
  `%.pc: %.pc.in Makefile` rule, Makefile.am:110-117).
- `check_PROGRAMS` — 14 test programs plus shell scripts under `test/`.

Because there is no `SUBDIRS`, there is no way to say `make -C` anything;
`make all` builds all six tools whether we want them or not. The recipe
therefore does the two things the library actually needs:

```sh
make -j1 libnuma.la
make -j1 install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA
```

I confirmed all three install targets exist by name in the generated
`Makefile.in`: `install-libLTLIBRARIES:` at line 862,
`install-pkgconfigDATA:` at line 1349, `install-includeHEADERS:` at line
1370. The `.la` target itself is at line 897.
`install-pkgconfigDATA: $(pkgconfig_DATA)` depends on `numa.pc`, and
`numa.pc`'s rule depends on `numa.pc.in` *and* `Makefile`, so asking for the
install target generates the `.pc` correctly without a separate build step.

## What it installs

- `lib/libnuma.a` (from `libnuma.la`; static, so the `.la` bookkeeping file
  is not installed as a library).
- `include/numa.h`, `include/numacompat1.h`, `include/numaif.h`.
- `lib/pkgconfig/numa.pc`.
- Nothing else. No tools, no man pages, no `numaint.h`/`util.h` (those are
  `noinst_HEADERS`).

### A consequence worth stating plainly

`libnuma_la_LDFLAGS` includes `-Wl,-init,numa_init -Wl,-fini,numa_fini`
(Makefile.am:35). Those linker options install a constructor/destructor and
they only take effect in a **shared** object. A consumer of the static
`libnuma.a` must call `numa_available()` (or `numa_init()`) itself. This is
not a defect in the recipe — it is inherent to static libnuma, and
`numa_available()` is libnuma's documented entry point for every consumer
(`numa.h:134` declares it, and the header comment says all calls are
undefined until it returns). It is worth a line in the eventual readme.

## Dependencies

None. `require("libnuma@source")` only. `configure.ac` is short and does no
library detection that can fail:

- `AC_SYS_LARGEFILE` — a compile test.
- `AX_TLS` — a *compile-only* test (`AC_TRY_COMPILE` on `__thread`), no link,
  no run. Cross-safe.
- `AX_CHECK_COMPILE_FLAG([-ftree-vectorize])` — compile-only, and it only
  affects `numademo_CFLAGS`, which we never build.
- `AC_SEARCH_LIBS([__atomic_fetch_and_1], [atomic])` — `AC_SEARCH_LIBS` is a
  link test; on aarch64 clang expands a 1-byte atomic inline
  (`ldaxrb`/`stlxrb`) so the probe needs no `-latomic` and returns "none
  required". If a target ever did need it, `AC_SEARCH_LIBS` would add
  `-latomic` to `LIBS` and every subsequent link would fail, because the NDK
  ships no `libatomic` — so a failure here would appear as a link error during
  `make libnuma.la`, not as a configure error.
- The `symver` attribute check is `AC_COMPILE_IFELSE` under `AC_LANG_WERROR`
  (configure.ac:29-33) — compile-only, and it only sets `HAVE_ATTRIBUTE_SYMVER`
  in `util.h`, which is a *tool* header not compiled into the library.

## Per-system verdicts

armv7a and i686 Android targets match the aarch64 rows unless stated; the API
level is the real variable, and libnuma's library is a thin wrapper over
`mbind`/`set_mempolicy`/`get_mempolicy`/`migrate_pages`/`move_pages` reached
through `syscall(2)` — kernel ABI, not libc API levels.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | The library sources are `libnuma.c syscall.c distance.c affinity.c sysfs.c rtnetlink.c`. Their system includes are, in full: `<stdlib.h> <stdio.h> <unistd.h> <string.h> <sched.h> <dirent.h> <errno.h> <stdarg.h> <ctype.h> <assert.h> <sys/mman.h> <limits.h> <sys/stat.h> <netdb.h> <sys/socket.h> <sys/ioctl.h> <net/if.h> <dirent.h> <linux/rtnetlink.h> <linux/netlink.h> <sys/types.h> <sys/sysmacros.h> <regex.h> <fcntl.h> <stdint.h>`. Every one of those exists in the NDK r28b sysroot — I checked each path, including `sys/sysmacros.h`, `linux/rtnetlink.h`, `linux/netlink.h` and `regex.h`. Grep for every symbol known to be absent from Bionic (`nl_langinfo`, `program_invocation_short_name`, `get_current_dir_name`, `fread_unlocked`, `scandir`, `versionsort`, `argp_parse`, `pthread_`, `mblen`, `getpass`, `O_BINARY`, `posix_spawn`, `process_vm_readv`) across the library sources and `numa.h`: **zero hits**. libnuma reaches every syscall through `syscall()`, which Bionic exports (`syscall@@LIBC` in `libc.so`), and through `<linux/netlink.h>` constants, not libc wrappers. |
| `aarch64-android24` | **WILL BUILD** | Nothing in the library is gated above 21, so a higher level cannot introduce a failure. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | The `#if defined(__x86_64__)` fallback block in `syscall.c:31-135` is **dead code on every Android target**: `<asm/unistd.h>` resolves from `sysroot/usr/include/<triple>/asm/unistd.h`, which is on clang's default search path, and it defines `__NR_mbind`/`__NR_set_mempolicy`/`__NR_get_mempolicy`/`__NR_migrate_pages`/`__NR_move_pages`, so the `#error` arm is unreachable. I compiled the include on aarch64, armv7a, i686 and x86_64 NDK targets to confirm. An earlier version of this file claimed `<asm/unistd.h>` was unavailable on the NDK and that the fallback block was the live path; **that was wrong**, and it is corrected here. The verdict is unchanged. `-Wl,--version-script,versions.ldscript` in `libnuma_la_LDFLAGS` is inert for a static archive — see risk 4. |
| `x86_64-mingw` | **WILL NOT BUILD** | Three independent, concrete walls. (1) `syscall.c:20` is `#include <asm/unistd.h>` — no such header in mingw-w64. (2) `affinity.c:40-41` and `rtnetlink.c:3-4` are `#include <linux/rtnetlink.h>` and `<linux/netlink.h>` — Linux UAPI, absent from mingw. (3) `libnuma_la_LDFLAGS` passes `-Wl,--version-script,...` and `-Wl,-init,numa_init`; the MinGW linker rejects ELF-only options. Even if the includes were worked around, there is no Netlink or NUMA syscall on Windows. This is a real gap. |
| `clang-native` | **WILL BUILD** | Native glibc has all headers; `<asm/unistd.h>` exists, so the primary `__NR_*` path is taken. The `bin_PROGRAMS` are never built, so `numactl`'s heavier includes never matter. |

## For a reviewer to scrutinise

1. **The targeted-install trick is the load-bearing part of this recipe.**
   If someone replaces the two `make` lines with `make -j1 && make -j1
   install`, the six host tools get compiled. They would probably *link*
   (they only use public libnuma API), but `numademo` needs `-lm` and
   `numastat` needs `-std=gnu99`, and it is wasted work either way. The
   comment in the recipe explains why; the risk is a well-meaning
   "simplification".
2. **Man pages are deliberately dropped.** All seven are for the tools we do
   not build. There is no `install-data` target that gives headers + `.pc`
   without also giving the man pages, so the explicit three-target list is
   the only way to skip them. If the reviewer wants the man pages in the
   prefix, that is `install-man` as a fourth target and nothing else
   changes.
3. **Static means no `numa_init` constructor.** Covered above; it is a real
   behavioural difference from a distro's shared libnuma and belongs in the
   readme.
4. **`-Wl,-init`/`-Wl,-fini` and `LDFLAGS` from the system.** With
   `--disable-shared`, libtool satisfies a `.la` from `archive_cmds` (`ar cru`)
   and **never invokes the linker**, so every `-Wl,…` in
   `libnuma_la_LDFLAGS` (`Makefile.am:44`: `-Wl,--version-script`,
   `-Wl,-init,numa_init`, `-Wl,-fini,numa_fini`) is recorded in `libnuma.la`
   and passed to nothing. That is the mechanism, and it is the single most
   surprising thing about this recipe. **If you ever see a link error
   mentioning `--version-script`, the build was not static** — check the
   configure line. On Android `$LDFLAGS` additionally carries
   `-L$PREFIX/lib`, `-Wl,-rpath-link,...` and `-lm`; all are equally inert
   against `ar`.
5. **Timestamp guard.** `config.h.in` is at the top level here, so the
   standard guard applies as written. The tarball ships no `config.status`
   and no `libtool` (checked by listing the archive), so neither is in the
   touch list.
