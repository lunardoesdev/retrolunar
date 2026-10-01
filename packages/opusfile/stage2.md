ACCEPT

# opusfile review (stage1: 0.12, `opusfile-0.12.tar.gz`)

## What the recipe gets right

- **Config template verified against the tree.** `find opusfile-0.12 -maxdepth 2
  -name '*.in'` returns `Makefile.in`, `config.h.in`, `doc/Doxyfile.in`,
  `opusfile.pc.in`, `opusurl.pc.in` and the two `-uninstalled.pc.in`.
  `config.h.in` is top level and is the only config template —
  `configure.ac:192` reads `AC_CONFIG_HEADERS([config.h])`. `generic.lua:23`
  touches exactly that. Correct.
- **Guard position is correct**: `./configure` at `:19`, guard at `:23-24`,
  `make` at `:25`.
- **System usage is clean** — only `$AUTOCONF_CONFIGURE_FLAGS`; no `export` of
  search flags; no hardcoded target facts.
- **`--disable-http` is the right spelling and the default really is ON.**
  `configure.ac:71-73`:
  ```m4
  AC_ARG_ENABLE([http],
    AS_HELP_STRING([--disable-http], [Disable HTTP support]),,
    enable_http=yes)
  ```
  and `:117-121` runs `PKG_CHECK_MODULES([URL_DEPS], [openssl])` whenever
  `enable_http != no`. The recipe comment at `generic.lua:12-15` correctly
  records that there is **no** `--without-libcurl`. Upstream's `src/winerrno.h`
  exists precisely because upstream supports Windows.
- **The version floors are real and the recipe's deps clear them.**
  `configure.ac:125` is `PKG_CHECK_MODULES([DEPS], [ogg >= 1.3 opus >= 1.0.1])`
  — unconditional, no `AS_IF` guard, so a missing dep is a hard configure
  error, not a silent feature loss. `packages/libogg` is 1.3.5 and
  `packages/opus` is 1.5.2.
- **`--disable-examples`** is real (`configure.ac:154-155`,
  `enable_examples=yes` default) and correctly described as removing target
  executables. They are `noinst_PROGRAMS` (`Makefile.am:24-26`) so nothing is
  installed either way.
- **`require()`s resolve**: `libogg`, `opus` both exist under `packages/`.

## Compiled, not assumed

Rather than take the "small Ogg/Opus reader" claim on faith, I compiled every
library source on all four compiler families with a stub `config.h` and real
libogg 1.3.5 + opus 1.5.2 headers:

```
src/opusfile.c   src/stream.c   src/info.c   src/internal.c   src/http.c
API21    OK OK OK OK OK
API35    OK OK OK OK OK
mingw    OK OK OK OK OK
native   OK OK OK OK OK
```

Note `src/http.c` compiles cleanly **with `--disable-http`'s effect in place**:
it compiles to nothing outside `OP_ENABLE_HTTP`, which is exactly why turning
the switch off removes the OpenSSL dependency rather than breaking the build.

## Android API level: inert, and tested

Sweeping `src/` for `posix_spawn`, `process_vm_readv`, `POSIX_MADV_*`,
`getpass`, `mblen`, `O_BINARY`, `nl_langinfo`, `iconv`, `mktime_z`,
`setlocale`, `localeconv`: **zero hits**. opusfile reads Ogg pages' own
language field and formats it itself; it never enters libc locale. The
`lrintf` link probe at `configure.ac:145` is an `AC_SEARCH_LIBS`, so it
degrades to the default library or `-lm` — and Android systems already carry
`-lm` in `$LDFLAGS`. **The API level really is inert here.**

## Install list — two corrections to `stage1.md` (recipe is fine)

`stage1.md` claims installs `include/opusfile.h`, `include/opusurl.h`. Neither
path is right:

1. `Makefile.am:7-8` sets `opusincludedir = ${includedir}/opus`, so
   `opusfile.h` installs to **`include/opus/opusfile.h`**, not
   `include/opusfile.h`. `opusfile.pc.in`'s `Cflags: -I${includedir}/opus`
   agrees.
2. **`include/opusurl.h` is never installed at all.** The only `HEADERS`
   assignment in `Makefile.am` is line 8, `opusfile.h`. `grep -n opusurl
   Makefile.am` shows opusurl appears only in `EXTRA_DIST` (`:51`), in the
   library sources (`:19-22`), and in `pkgconfig_DATA` (`:44`). So
   `opusurl.pc` ships and `libopusurl.a` ships, but the header does not.
   `stage1.md`'s "How to verify" line listing `include/opusurl.h` would send
   the builder after a file that does not exist and report a phantom defect.

Everything else in the stage1 install list is real: `libopusfile.a`,
`libopusurl.a`, `lib/pkgconfig/opusfile.pc`, `lib/pkgconfig/opusurl.pc`
(`Makefile.am:10,44`).

## Carried to the build

| artifact | source of truth |
| --- | --- |
| `lib/libopusfile.a` | `Makefile.am:10` |
| `lib/libopusurl.a` | `Makefile.am:10` |
| `include/opus/opusfile.h` | `Makefile.am:7-8` |
| `lib/pkgconfig/opusfile.pc` | `Makefile.am:44` |
| `lib/pkgconfig/opusurl.pc` | `Makefile.am:44` |
| `share/doc/opusfile/{COPYING,AUTHORS,README.md}` | `Makefile.am:6` |

### The ONE command that proves each

```sh
# both static archives exist and hold real symbols
test -f "$PREFIX/lib/libopusfile.a" && test -f "$PREFIX/lib/libopusurl.a" &&
llvm-objdump -f "$PREFIX/lib/libopusfile.a" | head -1 &&
llvm-nm --defined-only "$PREFIX/lib/libopusfile.a" | grep -c ' T op_open_file'
```
Expected: correct object format, non-zero count. Both libraries are
unconditional (`Makefile.am:10`) — a builder should **not** expect only
`libopusfile.a`.

> **Corrected after the build.** This check originally read
> `grep -c opusfile_open`, which returns **0 against a correct build**.
> opusfile 0.12 does not use an `opusfile_` symbol prefix at all: the library
> is `libopusfile.a` but its public API is spelled `op_*`. Verified against the
> tree — the header's exported identifiers are `op_fopen`, `op_fdopen`,
> `op_open_file`, `op_open_callbacks`, `op_open_memory`, `op_test_open` and so
> on, and `grep -cE ' T opusfile_'` on the installed archive returns 0. A grep
> for `opusfile` in the nm output matches only the object-file header line
> `opusfile.o:`, which is how this passes unnoticed at a glance.

```sh
# the header landed at the subdirectory path, and the .pc names it correctly
test -f "$PREFIX/include/opus/opusfile.h" &&
pkg-config --modversion opusfile &&
grep -m1 '^Cflags:' "$PREFIX/lib/pkgconfig/opusfile.pc"
```
Expected modversion `0.12`; `Cflags: -I${includedir}/opus`. **There is no
`include/opusurl.h` to check** — upstream does not install it.

```sh
# --disable-http actually took effect: no OpenSSL symbols and no curl in the
# archives, and the .pc names no crypto module
llvm-nm -u "$PREFIX/lib/libopusfile.a" "$PREFIX/lib/libopusurl.a" 2>/dev/null | grep -cE 'SSL_|curl_|EVP_' &&
grep -c 'openssl' "$PREFIX/lib/pkgconfig/opusurl.pc"
```
Expected: `0` and `0`. This is the check that `--disable-http` landed; had it
been left ON, `configure.ac:120` would have added `openssl` to
`opusurl.pc`'s `Requires.private` and the archive would carry SSL references.

```sh
# deps resolved through pkg-config as configured
grep -m1 '^Requires' "$PREFIX/lib/pkgconfig/opusfile.pc"
```
Expected: `Requires.private: ogg >= 1.3 opus >= 1.0.1` — copied verbatim from
`opusfile.pc.in`. If this line is empty, the `PKG_CHECK_MODULES` at
`configure.ac:125` did not see the prefix's `.pc` files and the configure
would have errored outright.