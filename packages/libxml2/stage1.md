# libxml2 build forecast

- Recipes: `generic.lua` (fallback), `android.lua` (every Android target),
  `x86_64-mingw.lua` (that one system). Source: `source.lua`.
- Version pinned: **2.15.4** (download.gnome.org).
- Build system: **autotools**, and a *generated* `configure` ships in the
  release tarball (2,734,105-byte tarball; `configure` = 572,348 bytes,
  `configure.ac` = 28,990, `aclocal.m4` = 79,061, 4,426 files extracted).
  No `autogen.sh` run is needed and none is done.
- Config template: **`config.h.in`** — the only one. `configure.ac:8` is
  `AC_CONFIG_HEADERS([config.h])`, and the tree ships `config.h.in` (2,706
  bytes). Do not confuse it with `config.h.cmake.in`, which belongs to
  upstream's separate CMake build and is not an autoheader template.
- Sub-configured: **no** — `grep -c AC_CONFIG_SUBDIRS configure.ac` is `0`.
  One `configure`, one template, 9 `Makefile.in` files swept by the guard.
- Cross-hostility: **none**. `grep -c 'AC_RUN_IFELSE\|AC_TRY_RUN' configure.ac`
  is `0`, so no configure-time probe ever runs a target binary.
- Installs: `lib/libxml2.a`, `include/libxml/*.h`, `lib/pkgconfig/libxml-2.0.pc`,
  `bin/xml2-config`, `bin/xmllint`, `bin/xmlcatalog`.
- Requires: `libxml2@source` only. No external library is required: `--with-zlib`
  and `--with-icu` default off (`configure.ac:795` runs the zlib check only for a
  non-empty, non-`no` value), and this release has no `--with-lzma` option at all.

## The iconv question — resolved

**The trap as briefed is inverted, and libxml2's iconv probe is written in the
order that works on Bionic.** The probe tries *no library first* and only falls
back to a separate `-liconv` afterwards. `configure.ac:859-880`:

```
859	    AC_MSG_CHECKING([for libiconv])
860	    AC_LINK_IFELSE([
861	        AC_LANG_PROGRAM([#include <iconv.h>], [iconv_open(0,0);])
862	    ], [
863	        WITH_ICONV=1
864	        AC_MSG_RESULT([none required])          <-- taken on Bionic
865	    ], [
866	        LIBS="$LIBS -liconv"                      <-- never reached on Bionic
867	        AC_LINK_IFELSE([
868	            AC_LANG_PROGRAM([#include <iconv.h>], [iconv_open(0,0);])
869	        ], [
870	            WITH_ICONV=1
871	            ICONV_LIBS="-liconv"
872	            AC_MSG_RESULT([yes])
873	        ], [
874	            AC_MSG_RESULT([no])
875	    ])
...
878	    if test "$WITH_ICONV" = "0"; then
879	        AC_MSG_ERROR([libiconv not found])
880	    fi
```

The deciding line is **`configure.ac:860-864`**: the first link test adds
nothing to `LIBS`, so on Bionic it links `iconv_open` straight out of libc,
sets `WITH_ICONV=1`, prints `none required`, and leaves `ICONV_LIBS` empty. The
`-liconv` branch at `:866-872` is dead code on Android.

**The real gate is API 28, and it is a declaration gate, not a link gate.**
`$SYSROOT/usr/include/iconv.h:64` reads
`#if __BIONIC_AVAILABILITY_GUARD(28)` around the `iconv_open` prototype at
`:65`. So below API 28 the conftest at `:861` does not merely fail to *link* —
it fails to *compile*, both probes fail, and `:879` aborts configure with
`libiconv not found`.

Probed directly with the NDK wrappers (not a package build — the exact conftest
translation unit from `configure.ac:861`):

| API | result |
|---|---|
| 21 | rc=1 FAIL (undeclared `iconv_open`) |
| 23 | rc=1 FAIL |
| 24 | rc=1 FAIL |
| 26 | rc=1 FAIL |
| 28 | rc=0 **LINK OK** |
| 33 | rc=0 LINK OK |
| 35 | rc=0 LINK OK |

### What this means for the cache answer

**No `ac_cv_lib_iconv=` cache variable is wanted, and none is needed.** There is
no `AC_CHECK_LIB([iconv], ...)` anywhere in this `configure.ac`, so there is no
separate "does libiconv exist" question for a cache variable to answer — the one
and only test is the `AC_LINK_IFELSE` pair above, and it already prefers libc.
`packages/libiconv/` is irrelevant to this question and the recipe does not
require it. If a future libxml2 release ever introduces a real
`AC_CHECK_LIB([iconv])`, that cache answer would be a Bionic fact belonging in
`packages/<sys>/generic.lua` next to `ac_cv_func_ffsl`, **not** in a recipe.

### What the recipe does instead

`android.lua` reads `$ANDROID_API` (exported by every Android system, e.g.
`packages/aarch64-android21/generic.lua:37-38`) and adds `--without-iconv`
below 28. Below that, libxml2 keeps its built-in ISO-8859-X tables
(`--with-iso8859x`, default on, `configure.ac:88`; the guard at `:519` keeps
them enabled precisely when `WITH_ICONV != 1`). **Honest caveat for the
reviewer:** the constant `28` is a Bionic fact hardcoded in a package recipe.
The clean expression of this would be a system-level export such as
`BIONIC_ICONV=yes`; that belongs in the system files, which are outside this
package's scope.

`x86_64-mingw.lua` needs `--without-iconv` for a *different* reason —
mingw-w64 ships no `iconv.h` at all (probed: `fatal error: iconv.h: No such
file or directory`) — so it gets its own per-system file rather than being
folded into `android.lua`.

## Verdict

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD** | iconv. `iconv.h:64` gates `iconv_open` behind `__BIONIC_AVAILABILITY_GUARD(28)`, so the conftest at `configure.ac:861` fails to compile; both probes fail and `configure.ac:879` aborts with `libiconv not found`. `android.lua` works around it with `--without-iconv`, which leaves the built-in ISO-8859-X tables in place (`configure.ac:88`, `:519`). Nothing else in the recipe is API-gated: `--with-modules` (default on, `configure.ac:618`) needs `dlopen`, and `--with-threads` (default on) needs `pthread_create` — both probed linking at API 21 (rc=0). `grep -c AC_RUN_IFELSE configure.ac` = `0`, so nothing runs a target binary. |
| aarch64-android24 | **WILL NOT BUILD** | Same as 21: API 24 is below the API-28 declaration gate (`iconv.h:64`), probed rc=1. |
| aarch64-android35 | **WILL BUILD** | `iconv.h:64` gate satisfied: API 35 links the conftest at `configure.ac:861` with no `-liconv` (probed rc=0), so the probe reports `none required` and `ICONV_LIBS` stays empty. `--with-modules`/`--with-threads` probes link (rc=0). No `AC_RUN_IFELSE` anywhere. |
| x86_64-android35 | **WILL BUILD** | As aarch64-android35. The gate is the libc API level, not the architecture. |
| x86_64-mingw | **WILL BUILD** | No Android gate applies. `x86_64-mingw.lua` passes `--without-iconv` because mingw-w64 has no `iconv.h` (probed: header absent), which keeps configure from aborting at `configure.ac:879`. `configure.ac:338` only adds extra warning flags under GCC; no run-time probes. The default `--with-modules` (`configure.ac:622-629`) sets `MODULE_EXTENSION=.dll` and `WITH_MODULES=1` without probing `dlopen`, so no `AC_SEARCH_LIBS` fallback runs. |
| clang-native | **WILL BUILD** | glibc declares `iconv_open` and `iconv` in libc (probed: the conftest compiles and links, rc=0), so `configure.ac:860-864` reports `none required`. `--host` is omitted from `$AUTOCONF_CONFIGURE_FLAGS` here (`packages/clang-native/generic.lua:52` is `--build` only), so autoconf builds natively as expected. |

armv7a and i686 behave exactly like their aarch64/x86_64 counterparts: every
gate above is a libc API-level gate, and none of them is architecture-specific.

## API-level notes

Only one gate applies, and it is the iconv declaration. Explicitly checked and
**not** a problem for this package: `stderr` as a real symbol, `POSIX_MADV_*`,
`process_vm_readv`, `posix_spawn`, `mblen`, `getpass`, `O_BINARY` (none appear
in libxml2's sources); `nl_langinfo` (API 26) and `mktime_z` (API 35) are
never used. `dlopen` and `pthread_create` — the two the defaults actually need —
were probed and link at API 21.

## Risks / what a reviewer should check

1. **Version pairing is load-bearing.** libxslt 1.1.45 sets
   `LIBXML_REQUIRED_VERSION=2.15.1` (`configure.ac:25`), so this recipe pins
   **2.15.4**, not the 2.14.x series. `libxml2-2.14.6` is the newest 2.14 and
   would fail libxslt's version gate. A reviewer changing this version must
   keep `>= 2.15.1`.
2. **The `--without-python` / `--without-docs` flags are documentation, not
   fixes, in this release** — `configure.ac:579` and `:563` both probe only on
   an explicit `yes`. That is stated in the recipe so it is not mistaken for a
   workaround. They matter as insurance against an upstream default flip, and
   because an explicit `yes` triggers a hard `doxygen`/`xsltproc` requirement
   at `configure.ac:589-593`.
3. **The autotools guard is correct for this tree**: `config.h.in` is the real
   name (`configure.ac:8`), the file exists, the project is not
   sub-configured, and `make -j1` is explicit.
4. **A cache variable is the wrong fix here and would be a defect if added.**
   See the iconv section — there is no `AC_CHECK_LIB([iconv])` to answer.
5. **`iconv_open(0,0)` passes NULL to a `_Nonnull` parameter.** Upstream's own
   conftest does this and clang emits `-Wnonnull` for it. It is a warning, not
   an error, under the systems' `-O2` flags; if a system ever adds `-Werror`,
   this probe would start failing for a reason unrelated to iconv.

## How to verify once built

- `lib/libxml2.a` exists; `include/libxml/parser.h` exists.
- `pkg-config --modversion libxml-2.0` reports `2.15.4`.
- `grep -c '$OUT' lib/pkgconfig/libxml-2.0.pc` is `0`, proving the loader's
  `$OUT`→`$PREFIX` rewrite (`src/loader.lua:454-468`) ran.
- The configure log must show `checking for libiconv... none required` on
  API >= 28. On API < 28 it will not appear at all, because `--without-iconv`
  short-circuits at `configure.ac:849`.
- `llvm-nm --defined-only lib/libxml2.a | grep -cw iconv_open` should be
  **zero** — on Bionic the iconv code calls libc's `iconv_open`, it does not
  define one. A non-zero count here would mean a libiconv leaked into the link.