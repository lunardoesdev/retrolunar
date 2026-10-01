ACCEPT

# libssh2 review (stage1: 1.11.1, `libssh2-1.11.1.tar.gz`)

## What the recipe gets right

- **Config template name is correct and verified against the unpacked tree.**
  `tar -xzf` of the real tarball gives exactly two templates,
  `src/libssh2_config.h.in` and `src/libssh2_config_cmake.h.in` — no
  top-level `config.h.in` exists. `configure.ac:10` reads
  `AC_CONFIG_HEADERS([src/libssh2_config.h])`. `generic.lua:29` touches
  `src/libssh2_config.h.in`, which is the file that exists. This is the
  single most-repeated defect class in this tree and this recipe avoids it.
- **Guard position is correct**: `./configure` at `generic.lua:23`, guard at
  `:29-30`, `make` at `:31`. After configure, before make.
- **System usage is clean.** Every build-system input comes from
  `$AUTOCONF_CONFIGURE_FLAGS`; no `export` of `CPPFLAGS`/`LDFLAGS`/
  `PKG_CONFIG_*`; no hardcoded target facts; `--prefix=$OUT` and the `-L$PREFIX`
  search path come from the system files.
- **The `--with-crypto=openssl` reasoning is correct and I re-derived it
  independently.** `acinclude.m4:855-865` walks
  `openssl, wolfssl, libgcrypt, mbedtls, wincng` and takes the first that links,
  appending `libcrypto` to `LIBSSH2_PC_REQUIRES_PRIVATE` (`:861`). Naming it
  makes the dependency explicit instead of order-dependent — and this tree
  *does* have a `wolfssl` package, so the adder's risk note is not
  hypothetical. Correct call.
- **`--with-libz` is genuinely load-bearing.** `configure.ac:157-170`: on
  failure with `use_libz=auto` it prints `Cannot find libz, disabling
  compression` and *continues*. Naming it turns a silent feature loss into a
  configure error. Correct call, correct citation.
- **`--disable-examples-build` really is the right spelling and really does
  default ON.** `configure.ac:289-291` declares
  `AS_HELP_STRING([--disable-examples-build], ...)`; `example/` is a
  `SUBDIRS` entry gated on `if BUILD_EXAMPLES` (`Makefile.am:6-8`). Confirmed.
  `tests/` is safe without a switch: `tests/Makefile.am:48` puts every test
  binary in `check_PROGRAMS`, which plain `make` does not build.
- **`make -j1`**: serial, no fan-out. Fine.
- **Dependencies exist**: `packages/openssl`, `packages/zlib` both present.
- **`require()`s resolve**: `require("openssl")`, `require("zlib")`,
  `require("libssh2@source")` — all name real package directories.

## Android API level: the "inert" claim is correct, and I tested it

I did not accept this on assertion. Sweeping every source file in `src/` for
the API-21 gap list (`posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`,
`getpass`, `mblen`, `O_BINARY`, `nl_langinfo`, `iconv`, `mktime_z`):
**zero hits.** The one near-miss is `explicit_bzero` at `src/misc.h:50`, and
it is behind `#elif defined(HAVE_EXPLICIT_BZERO)` (`:49`) with
`explicit_memset`, `memset_s` and a `memset`-based `_libssh2_memzero` fallback
underneath — so even if Bionic never provides it, the fall-through path is
taken, not an undefined symbol. `libssh2_config.h.in:24` shows it is an
`AC_CHECK_FUNCS` result, so configure resolves it either way.

**The API level really is inert for libssh2.** 21, 24 and 35 compile the same
translation units.

## x86_64-mingw: the row I was told to distrust most, and it holds

The stage1 claim is that the POSIX socket headers are absent on mingw but
every use is behind `#ifdef HAVE_*`, so the probes failing is the correct
path. I verified this by compiling, not by reading. My first probe was wrong
in an instructive way: I wrote `#define HAVE_SYS_UIO_H 0` into a stub
`libssh2_config.h`, and every file still failed on `sys/uio.h` — because
`src/libssh2_priv.h:76-84` tests with `#ifdef`, not `#if`, so *defining* the
macro to 0 still enables the `#include`. That is a trap any reviewer
hand-simulating configure's output will fall into.

Redone correctly (macros simply **absent**, as `AC_CHECK_HEADERS` would leave
them), compiling all 26 non-`wincng` sources against mingw-w64 GCC 16.2:

```
libssh2 mingw errors: 0
```

`configure.ac:35-39` adds `-lws2_32` for `*-mingw*` hosts and
`configure.ac:344-346` probes `select` in `ws2_32`, so the socket layer is
supplied by the platform. The stage1 citation of `session.c:45` including
`<ws2tcpip.h>` for `socklen_t` is correct.

## Install list — one correction to `stage1.md` (not a recipe defect)

`stage1.md` lists `include/libssh2_public.h`. That file does not exist.
`Makefile.am:14-17` installs exactly:

```
include/libssh2.h
include/libssh2_publickey.h
include/libssh2_sftp.h
```

The real name is `libssh2_publickey.h`. Recorded here so a builder does not
go looking for `libssh2_public.h` and report a missing artifact. The
`stage1.md` list also repeats `include/libssh2.h` twice. This is a
`stage1.md` prose defect only; `generic.lua` is untouched by it and the
verdict stands.

`lib/pkgconfig/libssh2.pc` is real (`Makefile.am:12`), generated from
`libssh2.pc.in` via `configure.ac:426-432`.

## Carried to the build

Expected artifacts under `$PREFIX` after a successful merge:

| artifact | source of truth |
| --- | --- |
| `lib/libssh2.a` | `src/Makefile.am:15` `lib_LTLIBRARIES = libssh2.la` |
| `include/libssh2.h` | `Makefile.am:14` |
| `include/libssh2_publickey.h` | `Makefile.am:15` |
| `include/libssh2_sftp.h` | `Makefile.am:16` |
| `lib/pkgconfig/libssh2.pc` | `Makefile.am:11-12` |
| `share/man/man3/libssh2_*.3` | `docs/Makefile.am:4` `dist_man_MANS` |

### The ONE command that proves each

```sh
# static archive exists, is the right object format, and holds the library
test -f "$PREFIX/lib/libssh2.a" &&
llvm-objdump -f "$PREFIX/lib/libssh2.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libssh2.a" | grep -c libssh2_session_init
```
Expected: `elf64-littleaarch64` on aarch64 (a PE/`pei-x86-64` archive on
mingw), and a non-zero count.

```sh
# all three headers and the .pc landed
test -f "$PREFIX/include/libssh2.h" &&
test -f "$PREFIX/include/libssh2_publickey.h" &&
test -f "$PREFIX/include/libssh2_sftp.h" &&
test -f "$PREFIX/lib/pkgconfig/libssh2.pc" &&
pkg-config --modversion libssh2
```
Expected modversion: `1.11.1`. **Do not look for `libssh2_public.h`** — see
above; it is not a libssh2 file.

```sh
# the two load-bearing flags actually took effect: the .pc must name BOTH
# crypto and zlib as private requires
grep -E '^Requires(\.private)?:' "$PREFIX/lib/pkgconfig/libssh2.pc"
```
Expected: a line naming `libcrypto` **and** `zlib`. `acinclude.m4:861` appends
`libcrypto` for the openssl backend and `configure.ac:170` appends `zlib` when
the libz probe succeeds. **A short line here is the check that
`--with-crypto=openssl` and `--with-libz` both landed** — if either had been
dropped, this is where it shows, and the library is silently missing a
feature rather than failing.

```sh
# no host programs were compiled or installed
find "$PREFIX/bin" -name 'libssh2*' 2>/dev/null | wc -l
```
Expected: `0`. The examples live in `example/` behind `if BUILD_EXAMPLES`
(`Makefile.am:6-8`), which `--disable-examples-build` turns off.

### Note for `stage3.md`

The `-llog` question does not arise here: `libssh2` is a static archive with
no link step and nothing in it calls `__android_log_write`. OpenSSL in this
prefix is a separate package with its own record. If a consumer link fails
with an undefined `__android_log_write`, that is the consumer's abseil/glog
surface, not this recipe — check `$LDFLAGS` (AGENTS.md: the Android systems
carry `-llog`), do not add a flag here.