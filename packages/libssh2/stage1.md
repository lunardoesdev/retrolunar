# libssh2 build forecast

- **Package:** libssh2
- **Version:** 1.11.1 (`libssh2-1.11.1`, release 2024-10-16, newest on the
  libssh2/libssh2 release list)
- **Upstream URL:** `https://github.com/libssh2/libssh2/releases/download/libssh2-1.11.1/libssh2-1.11.1.tar.gz`
  (HTTP 200, 1 093 012 bytes, top directory `libssh2-1.11.1/`)
- **Build system: autotools**, with a **generated `configure` present**
  (`libssh2-1.11.1/configure`, plus `aclocal.m4` and `Makefile.in` at top level)
- **Config template: `src/libssh2_config.h.in`** — *not* a top-level
  `config.h.in`. `configure.ac:10` reads
  `AC_CONFIG_HEADERS([src/libssh2_config.h])`, and `tar tzf` confirms
  `libssh2-1.11.1/src/libssh2_config.h.in`. The recipe's guard names that path.
- **Dependencies required:** `openssl` (exists), `zlib` (exists).
  Both are `require()`d so they land in `$PREFIX` before configure runs and the
  pkg-config/header probes find them.
- **Installs:** `lib/libssh2.a`, `include/libssh2.h`, `include/libssh2_public.h`,
  `include/libssh2_sftp.h`, `include/libssh2.h`, `lib/pkgconfig/libssh2.pc`.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | The crypto backend is named explicitly (`--with-crypto=openssl`), so `acinclude.m4:860` does the OpenSSL probe: `LIBSSH2_LIB_HAVE_LINKFLAGS([ssl], [crypto], ...)` against the in-prefix OpenSSL. zlib is named too, so `configure.ac:157` links `-lz` and defines `LIBSSH2_HAVE_ZLIB`. No host programs: `--disable-examples-build` turns off `build_examples` (default **yes**, `configure.ac:289-299`), and the docker/sshd test conditionals are off. libssh2's socket code is entirely behind `HAVE_SYS_SOCKET_H` / `HAVE_SYS_SELECT_H` / `HAVE_SYS_UIO_H` (`src/libssh2_priv.h:72-85`), and Bionic supplies all three, so the `#else` fallbacks never fire. Bionic has **no separate `-lpthread`** and libssh2 needs none. |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above; no arch-specific code. |
| `x86_64-mingw` | **WILL BUILD** | mingw-w64 supplies the Windows socket layer. `winsock2.h` and `ws2tcpip.h` are both present under `/usr/x86_64-w64-mingw32/include`, and `session.c:45` includes `<ws2tcpip.h>` for `socklen_t`. The POSIX socket headers libssh2 probes for (`sys/socket.h`, `sys/select.h`, `sys/uio.h`, `sys/ioctl.h`) are **absent** from that sysroot, but every one of them is behind an `#ifdef HAVE_*` (`src/libssh2_priv.h:72-85`), so the probes failing is the correct path, not an error. `configure.ac:46` separately probes `winsock2` and `ws2tcpip` for Windows. Note the wincng backend is *not* selected: `--with-crypto=openssl` bypasses the `have_windows_h` branch at `acinclude.m4:892-906`. |
| `clang-native` | **WILL BUILD** | Native x86_64 Linux; glibc has all four POSIX socket headers, so the real socket path is taken. |

**API level notes.** No Bionic API-21 gap applies. libssh2's compiled surface
is `read`/`write`/`poll`/`select`/`ioctl`/`getaddrinfo`/`time`/`rand` plus
OpenSSL. None of the AGENTS.md API-21 absences (`stderr` as a real symbol,
`POSIX_MADV_*`, `process_vm_readv`, `posix_spawn`, `mblen`/`getpass`,
`O_BINARY`) is referenced; libssh2 does use `O_BINARY`-equivalent logic on
Windows but guards it under `_WIN32`, and on Android the POSIX branch is taken.
**The API level is inert for this package** — 21, 24 and 35 behave identically.

**Risks / what a reviewer should check.**
1. **The crypto backend must be named, not left on `auto`.**
   `acinclude.m4:857` walks `openssl, libgcrypt, mbedtls, wincng, wolfssl`
   and the *first* one whose headers and library link wins. On this prefix only
   OpenSSL is present, so `auto` would resolve to openssl today — but a future
   `wolfssl` package (the tree already has one) would silently take over and
   change what `libssh2.pc` puts in `Requires.private`. Naming it makes the
   dependency explicit and is the same reasoning as
   `packages/util-linux/generic.lua`'s `--without-cap-ng`.
2. **`--with-libz` must also be named.** `configure.ac:158-160` probes with
   `AC_LIB_HAVE_LINKFLAGS([z], [], [#include <zlib.h>])` and on failure with
   `use_libz=auto` prints "Cannot find libz, disabling compression" and
   continues. That is a *silent* feature loss, not a failure — the exact class
   of defect the pipeline exists to catch. Naming it turns that into an error
   if the dependency ever goes missing.
3. **The config template is in `src/`, and this is a real trap.** A guard
   naming a top-level `config.h.in` would `touch` a file that does not exist —
   and per AGENTS.md:451-455 that *succeeds* and creates it, leaving the
   autoheader re-run live and the build surviving on lucky mtimes. The recipe
   names `src/libssh2_config.h.in`.
4. **`--disable-examples-build` is load-bearing on a cross build.**
   `configure.ac:299` makes it the default **on**, and the examples are target
   executables.
5. **`os400/`, `vms/` and `crypto_config.h` are in the tarball** and are not
   touched by any flag; they are simply not built.

**How to verify once built.**
- `lib/libssh2.a`, `include/libssh2.h`, `include/libssh2_sftp.h`,
  `lib/pkgconfig/libssh2.pc`
- `pkg-config --modversion libssh2` → `1.11.1`
- `llvm-objdump -f lib/libssh2.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libssh2.a | grep -c libssh2_session_init` → non-zero
- `grep -m1 'Libs.private' lib/pkgconfig/libssh2.pc` must list `libcrypto`
  and `zlib` — that is the check that both `--with-crypto=openssl` and
  `--with-libz` took effect
- On mingw: `file lib/libssh2.a` and confirm `llvm-nm -u` shows no
  `__android_log_write`; the archive should be a PE object, not ELF