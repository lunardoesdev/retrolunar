ACCEPT

# libxml2 review (stage2)

Recipes: `generic.lua`, `android.lua`, `x86_64-mingw.lua`. Source:
`source.lua`, libxml2 2.15.4.
Verified against the real tarball (`tar tf` OK, 4524 entries, top dir
`libxml2-2.15.4/`), extracted to `/home/si/.revE/src/libxml2-2.15.4`.

## 1. Is it using the SYSTEM?

Yes. All three recipes run `./configure $AUTOCONF_CONFIGURE_FLAGS …` and
nothing else — no hardcoded `--host`/`--build`/`--prefix`, no `export` of
search flags, no `CPPFLAGS`/`LDFLAGS` fiddling. `android.lua` reads
`$ANDROID_API`, which every Android system exports (I checked all 56
`*-android*/generic.lua`: every one has both `ANDROID_API=` and
`export ANDROID_API`; none missing). `make -j1` is explicit everywhere.

**The guard is correct and the template name is real.** `configure.ac:8` is
`AC_CONFIG_HEADERS([config.h])`, the only such line, and `config.h.in` exists
(2706 bytes) — not a name guessed from the AGENTS.md list. Guard position is
right: after `./configure`, touching `aclocal.m4 configure config.h.in`, then
sweeping `find . -name 'Makefile.in' | xargs touch`. That is the AGENTS.md form,
and it sweeps **9** `Makefile.in` files in this tree.

Two absences I checked rather than assumed, per AGENTS.md's warning:

- `grep -c AC_CONFIG_SUBDIRS configure.ac` → **0**. Not sub-configured, so a
  top-level-only sweep is complete.
- `grep -c 'AC_RUN_IFELSE\|AC_TRY_RUN' configure.ac` → **0**. Nothing runs a
  target binary at configure time. (One caveat below on the *build*.)

`config.h.cmake.in` does exist in the tree and is correctly **not** touched —
it belongs to upstream's separate CMake build. The recipe never mentions it,
which is right.

## 2. Is it doing what the package needs? — the iconv question

**The brief's framing is inverted, and `stage1.md` is right to say so.**
The claim is that libxml2's probe is written *no-library-first*, so it works on
Bionic and the `-liconv` fallback is dead code there. Confirmed verbatim from
`configure.ac:859-880`:

```
    AC_MSG_CHECKING([for libiconv])
    AC_LINK_IFELSE([
        AC_LANG_PROGRAM([#include <iconv.h>], [iconv_open(0,0);])
    ], [
        WITH_ICONV=1
        AC_MSG_RESULT([none required])
    ], [
        LIBS="$LIBS -liconv"
        AC_LINK_IFELSE([...], [ WITH_ICONV=1; ICONV_LIBS="-liconv" ], [...])
    ])
    if test "$WITH_ICONV" = "0"; then
        AC_MSG_ERROR([libiconv not found])
    fi
```

The first `AC_LINK_IFELSE` adds nothing to `LIBS`, so on Bionic `iconv_open`
resolves out of libc, `WITH_ICONV=1`, result is `none required`, and
`ICONV_LIBS` stays empty. The `-liconv` branch is unreachable on Android.

**I probed every API level myself, with libxml2's exact conftest TU**
(`#include <iconv.h>` + `iconv_open(0,0)`, i.e. `configure.ac:861` verbatim):

| API | rc | result |
|---|---|---|
| 21 | 1 | `error: call to undeclared function 'iconv_open'` |
| 23 | 1 | same |
| 24 | 1 | same |
| 26 | 1 | same |
| 28 | **0** | **links, no `-liconv`** |
| 33 | **0** | links |
| 35 | **0** | links |

Controls: clang-native (glibc) rc=0; mingw fails with
`fatal error: iconv.h: No such file or directory`.

**One correction to the brief, and it matters.** The brief states the NDK's
`<iconv.h>` is "ABSENT at API 21/24/26 and PRESENT at 28/35". The header is
**present at every level** — there is exactly one
`$SYSROOT/usr/include/iconv.h` (3382 bytes) and the sysroot is not
per-API-versioned that way. What is gated is the *declaration inside it*:

```
iconv.h:64   #if __BIONIC_AVAILABILITY_GUARD(28)
iconv.h:65   iconv_t _Nonnull iconv_open(...) __INTRODUCED_IN(28);
iconv.h:87   #endif /* __BIONIC_AVAILABILITY_GUARD(28) */
```

So the failure below 28 is a **declaration** failure — the conftest does not
compile — not a link failure and not a missing file. `stage1.md` states this
correctly ("a declaration gate, not a link gate"); the recipe comment says the
same. The distinction has a practical consequence the brief's phrasing would
hide: `--without-iconv` is genuinely required, because both probes fail and
`configure.ac:879` aborts with `libiconv not found`.

**`--without-iconv` below API 28 is correct, and the fallback is real.**
`configure.ac:87-88` declares `--with-iso8859x` with default `(on)`, and
`configure.ac:519-523`:

```
if test "$WITH_ICONV" != "1" && test "$with_iso8859x" = "no" ; then
    WITH_ISO8859X=0
else
    WITH_ISO8859X=1
```

So with `--without-iconv` and the default iso8859x, `WITH_ISO8859X=1` — the
built-in tables stay in. The recipe's claim holds.

**`x86_64-mingw.lua --without-iconv` is correct for an independent reason.**
Verified: mingw-w64 ships no `iconv.h` (`fatal error: iconv.h: No such file or
directory`) and no `libiconv` (nothing iconv-named in
`/usr/x86_64-w64-mingw32/{lib,include}`). Without the flag both probes fail and
`configure.ac:879` aborts. Giving mingw its own file rather than folding it
into `android.lua` is right — it is a different fact with a different cause.

**No cache answer is needed, and none should be added.** I checked:
`grep -n 'AC_CHECK_LIB.*iconv\|ac_cv_lib_iconv' configure.ac` → **NONE**. There
is no `AC_CHECK_LIB([iconv], …)` in this `configure.ac`, so there is no
separate "does libiconv exist" predicate for a cache variable to answer; the
single `AC_LINK_IFELSE` pair already prefers libc. Adding
`ac_cv_lib_iconv=` would be answering a question the build never asks.

And per AGENTS.md, if a future release *did* introduce an `AC_CHECK_LIB`, that
answer would be a **Bionic fact belonging in `packages/<sys>/generic.lua`**
next to `ac_cv_func_ffsl` — **not** in a recipe. `stage1.md` says exactly this.
`packages/libiconv` exists in this tree but is correctly not required: it is
irrelevant to a libc-resident `iconv()`.

**`--without-python` / `--without-docs` are correctly characterised as
insurance, not fixes.** `stage1.md` risk 2 and the recipe comment both say the
release already defaults them off and that an explicit `yes` would pull a hard
doxygen/xsltproc requirement (`configure.ac:589-593`). The nuance in
`configure.ac:235` (`test "$with_python" = "" && with_python=no` under
`--with-minimal`) is consistent with that. Spelling them out is harmless and
guards against an upstream default flip.

**Version pairing is load-bearing and correct.** `libxslt-1.1.45/configure.ac:25`
is `LIBXML_REQUIRED_VERSION=2.15.1`, so 2.15.4 (the newest in the 2.15 series —
I listed the directory: 2.15.2, 2.15.3, 2.15.4; no 2.16 exists) is the right
pin. Pinning 2.14.6 would fail libxslt's gate.

## Corrections to `stage1.md` (none blocking)

- `stage1.md` says "`--with-modules` (default on, `configure.ac:618`)"; the
  argument handling is at `:622-629`. Immaterial.
- `stage1.md`'s claim that no cache variable is wanted is confirmed; the
  `libiconv` package correctly stays out of the requires.
- **The brief's "iconv.h absent below 28" is the error here**, not the
  forecast — see §2. Recorded because it is the kind of claim a later reader
  would otherwise repeat.

## Artifacts — what actually installs

From the real `Makefile.am`:

- `lib/libxml2.a` — `lib_LTLIBRARIES = libxml2.la` (static build, no `-fPIC`
  shared pair requested)
- `include/libxml/*.h` — `xmlincdir = $(includedir)/libxml`
- `lib/pkgconfig/libxml-2.0.pc` — `Makefile.am:230-231`
  (`pkgconfigdir = $(libdir)/pkgconfig`, `pkgconfig_DATA = libxml-2.0.pc`)
- `bin/xmllint` (`Makefile.am:33 bin_PROGRAMS = xmllint`),
  `bin/xmlcatalog` (`:53 bin_PROGRAMS += xmlcatalog`),
  `bin/xml2-config` (`:35 bin_SCRIPTS = xml2-config`)

These are **target** programs. They are compiled, never executed during the
build, so they do not violate the no-emulation rule. They *are* shipped into the
prefix, which is a policy choice consistent with other packages here (pixman
ships nothing, graphite2 ships `gr2fonttest`, cairo ships its script
interpreter).

## Forecast

I agree with **6 of 6**.

- `aarch64-android21` / `aarch64-android24` **WILL NOT BUILD**: iconv, the
  declaration gate. I reproduced rc=1 at 21, 23, 24, 26. `--without-iconv`
  in `android.lua` is what turns this into a build.
- `aarch64-android35` / `x86_64-android35` **WILL BUILD**: rc=0 at 33 and 35,
  so the probe reports `none required` with an empty `ICONV_LIBS` and no
  `-liconv` is needed. The gate is a libc API level, not an architecture —
  correct.
- `x86_64-mingw` **WILL BUILD**: the `x86_64-mingw.lua` recipe supplies the
  `--without-iconv` that avoids `configure.ac:879`. The claim that
  `--with-modules` needs no `dlopen` probe on mingw (`configure.ac:622-629`
  sets `MODULE_EXTENSION=.dll` directly) is consistent with the source.
- `clang-native` **WILL BUILD**: glibc has `iconv_open` in libc (rc=0), and
  `packages/clang-native/generic.lua:52`'s `$AUTOCONF_CONFIGURE_FLAGS` is
  `--build=… --prefix=$OUT` with no `--host`, so autoconf builds natively.
  I verified that system file exports `--prefix=$OUT`, so unlike the meson
  packages, libxml2 **does** install into `$OUT` on clang-native. The
  meson/`MESON_FLAGS` gap that affects pixman/fontconfig/cairo/pango does not
  touch this package.

**One honest caveat the adder raised and I endorse:** `android.lua` hardcodes
the constant `28`. It reads the API level from `$ANDROID_API` rather than
hardcoding `24`, so it is not a hardcoded *target* fact — it is a hardcoded
*Bionic* fact, which AGENTS.md's own precedent puts in system files. The
adder's `stage1.md` flags this and says the clean expression
(`BIONIC_ICONV=yes` in the system files) is outside this package's scope. I
agree with that characterisation: it is a system-level cleanup, not a recipe
defect, and it must not be worked around by guessing. Recorded for the builder.

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libxml2.a"                  || echo "MISSING libxml2.a"
test -f "$OUT/include/libxml/parser.h"        || echo "MISSING parser.h"
test -f "$OUT/lib/pkgconfig/libxml-2.0.pc"    || echo "MISSING libxml-2.0.pc"
test -x "$OUT/bin/xml2-config"                || echo "MISSING xml2-config"

# 2. version expected 2.15.4. libxslt's gate is >= 2.15.1, so anything below
#    2.15.1 here is a latent libxslt failure, not just a stale pin.
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion libxml-2.0

# 3. no $OUT left in the .pc — proves the loader rewrite ran
#    (src/loader.lua:454-468). Scoped to libxml2's own file.
grep -c "$OUT" "$OUT/lib/pkgconfig/libxml-2.0.pc"        # expected 0

# 4. THE ICONV CHECK, and it differs by system. The configure log line is the
#    direct evidence:
#      API >= 28 -> "checking for libiconv... none required"
#      API <  28 -> the line is ABSENT entirely, because --without-iconv
#                   short-circuits at configure.ac:849 before the probe.
#    So "no" is the correct result below 28, not a silent failure.
grep 'libiconv' "$WORK/config.log" | tail -2

# 5. no libiconv leaked into the archive. On Bionic the iconv code CALLS libc's
#    iconv_open; it must not DEFINE one. Scoped to the one symbol.
llvm-nm --defined-only "$OUT/lib/libxml2.a" | grep -cw iconv_open   # expected 0
# and the undefined reference should be present (it resolves from libc):
llvm-nm -u "$OUT/lib/libxml2.a" | grep -cw iconv_open               # expected >=1 on API>=28

# 6. ISO-8859-X tables must be in place on every system: --with-iso8859x
#    defaults on and configure.ac:519 keeps it enabled precisely when
#    WITH_ICONV != 1. Check the generated header reflects WITH_ISO8859X=1.
grep -E 'WITH_ICONV|WITH_ISO8859X' "$WORK/config.h"

# 7. static archive, ELF machine per family
$OBJDUMP -f "$OUT/lib/libxml2.a" | head -3

# 8. xmllint/xmlcatalog/xml2-config are target binaries: confirm they are the
#    right architecture and were never executed by the build (the build log
#    must contain no attempt to run them).
for b in xmllint xmlcatalog xml2-config; do $OBJDUMP -f "$OUT/bin/$b" 2>/dev/null | head -3; done
```

Note for check 4/6: `config.log` and the generated `config.h` live in `$WORK`,
which the loader's `trap` removes at block end — read them while the block runs
or copy them out first.