# opusfile build forecast

- **Package:** opusfile
- **Version:** 0.12 (release `v0.12`, 2020-06-27, newest on xiph/opusfile)
- **Upstream URL:** `https://github.com/xiph/opusfile/releases/download/v0.12/opusfile-0.12.tar.gz`
  (HTTP 200, 471 354 bytes, top directory `opusfile-0.12/`)
- **Build system: autotools**, with a **generated `configure` present**
  (`opusfile-0.12/configure`, `aclocal.m4`, `Makefile.in`)
- **Config template: `config.h.in`** — top level. `configure.ac:192` reads
  `AC_CONFIG_HEADERS([config.h])`, and `tar tzf` confirms
  `opusfile-0.12/config.h.in`. Plain spelling, no subdirectory.
- **Dependencies required:** `libogg` (exists), `opus` (exists).
  **Verified, not assumed:** `configure.ac:125` is
  `PKG_CHECK_MODULES([DEPS], [ogg >= 1.3 opus >= 1.0.1])` with no default and
  no `AS_IF` guard, so both are hard requirements and a missing one is a hard
  configure error. `packages/libogg` installs `ogg.pc`/`vorbis.pc` and
  `packages/opus` installs `opus.pc`; the systems set
  `PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"`, so both resolve.
- **Installs:** `lib/libopusfile.a`, `include/opusfile.h`,
  `include/opusurl.h`, `lib/pkgconfig/opusfile.pc`,
  `lib/pkgconfig/opusurl.pc`.

| system | verdict | reason |
| --- | --- | --- |
| `aarch64-android21` | **WILL BUILD** | opusfile is a small Ogg/Opus reader: `src/opusfile.c`, `stream.c`, `info.c`, `internal.c` plus `http.c`. Its libc surface is `fopen`/`fread`/`fseek`/`ftell`, `malloc`, `strdup` and the **`lrintf`** probe. That last one is the one worth checking: `configure.ac:145` runs `AC_SEARCH_LIBS([lrintf], [m], ...)`, which is a *link* test. Bionic has `lrintf` in libc (not libm) on Android, so `AC_SEARCH_LIBS` finds it in the default library and no `-lm` is added; and `-lm` is in `$LDFLAGS` anyway (`packages/aarch64-android21/generic.lua:78`). No API-24+ symbol. |
| `aarch64-android24` | **WILL BUILD** | As above. |
| `aarch64-android35` | **WILL BUILD** | As above. |
| `x86_64-android35` | **WILL BUILD** | As above; no arch-specific code. |
| `x86_64-mingw` | **WILL BUILD** | The one thing that could have bitten here is `src/winerrno.h`, which opusfile ships precisely to paper over mingw's errno layout — upstream supports Windows with this source set. `configure.ac:46` probes `sys/stat.h`/`sys/types.h`, both of which mingw has. No POSIX socket or `poll` use anywhere in `src/`. `--disable-http` keeps `http.c`'s network path out, which is what removes the only OpenSSL and platform-socket dependency. |
| `clang-native` | **WILL BUILD** | Native; `lrintf` is in glibc's libm so `AC_SEARCH_LIBS` finds it with no extra library. |

**API level notes.** **No new wall, and the API level is inert.** opusfile
calls no symbol from the AGENTS.md API-21 list, and it uses no locale at all —
notably `opusfile`'s comment-reading does **not** call `setlocale` or
`nl_langinfo` (the API-26 gap), because Ogg pages carry their own language
field and opusfile formats it as a string itself. Nothing needs an API
introduced after 21.

**Risks / what a reviewer should check.**
1. **`--disable-http` is load-bearing, and its default is ON.**
   `configure.ac:117-121` runs `PKG_CHECK_MODULES([URL_DEPS], [openssl])`
   whenever `enable_http != no`, and `AC_DEFINE(OP_ENABLE_HTTP)`. Leaving it on
   adds `src/http.c` — an HTTP client — to the library. Two reasons to turn it
   off: a target prefix has no use for it, and it would drag OpenSSL into a
   package whose `.pc` currently has no crypto dependency. **Note the switch is
   `--disable-http`; there is no `--without-libcurl`.** `AC_CONFIG_FILES`
   (`configure.ac:184`) generates `opusfile.pc`, `opusurl.pc` and two
   `-uninstalled` variants regardless, so the `.pc` files exist either way —
   they just describe a smaller library.
2. **`opusurl` is a second library and it is not optional.** `opusurl.h` and
   `src/http.c` live in the same `libopusfile_la_SOURCES`
   (`Makefile.am:11`), so with `--disable-http` opusurl still builds, as a thin
   shim over `OP_ENABLE_HTTP`. Both `.pc` files install. A reviewer should not
   expect only `libopusfile.a`.
3. **`--disable-examples` matters on a cross build.**
   `configure.ac:153-156` makes it default **ON**
   (`enable_examples=yes`), and the examples are target executables
   (`opus_example`, `opus_decode_example`).
4. **`--disable-doc` avoids a doxygen and a dotgraph.** `configure.ac:170-179`
   probes for both `doxygen` and `dot` when `enable_doc=yes` (the default) and
   only builds the API docs if both are found. Benign either way, but the
   `AC_CONFIG_FILES` list includes `doc/Doxyfile`, so the probe runs regardless
   unless disabled.
5. **The `ogg >= 1.3` and `opus >= 1.0.1` version floors are real constraints**,
   not decoration. `packages/libogg` is at 1.3.5 and `packages/opus` at 1.5.2,
   so both clear them with margin.
6. **`CC_ATTRIBUTE_VISIBILITY`** at `configure.ac:164-166` appends
   `-fvisibility=hidden` to `CFLAGS` if the compiler supports it. That is an
   upstream-driven append to `$CFLAGS` inside configure, not an `export` in the
   recipe, so it does not breach AGENTS.md's rule about recipes exporting
   search flags — and `-fvisibility=hidden` with no matching export list is
   only a concern for the shared build, which we do not build.

**How to verify once built.**
- `lib/libopusfile.a`, `include/opusfile.h`, `include/opusurl.h`,
  `lib/pkgconfig/opusfile.pc`, `lib/pkgconfig/opusurl.pc`
- `pkg-config --modversion opusfile` → `0.12`
- `llvm-objdump -f lib/libopusfile.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libopusfile.a | grep -c opusfile_open` → non-zero
- `grep -c OP_ENABLE_HTTP lib/pkgconfig/opusfile.pc` → 0, and
  `llvm-nm -u lib/libopusfile.a | grep -cE 'SSL_|curl_'` → 0: both are the check
  that `--disable-http` took effect
- `grep -m1 'Requires' lib/pkgconfig/opusfile.pc` must name `opus` (and `ogg`
  via opus)