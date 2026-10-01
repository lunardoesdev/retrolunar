ACCEPT

# libxslt review (stage2)

Recipe: `generic.lua` only. Source: `source.lua`, libxslt 1.1.45.
Verified against the real tarball (`tar tf` OK, 2299 entries, top dir
`libxslt-1.1.45/`), extracted to `/home/si/.revE/src/libxslt-1.1.45`.

## 1. Is it using the SYSTEM?

Yes. `./configure $AUTOCONF_CONFIGURE_FLAGS --without-python
--without-debugger`, nothing else. No hardcoded `--host`/`--build`/`--prefix`,
no `export` of search flags, no `CPPFLAGS`/`LDFLAGS` fiddling, `make -j1`
explicit. `require("libxml2")` puts the dependency in the prefix first.

**The guard is correct.** `configure.ac:10` is `AC_CONFIG_HEADERS(config.h)`,
the only such line, and `config.h.in` exists (6244 bytes).
`grep -c AC_CONFIG_SUBDIRS configure.ac` → **0**, not sub-configured, so the
top-level sweep is complete; it catches **16** `Makefile.in` files.

The two *other* `.h.in` files in the tree are correctly **excluded from the
guard**, and this is the subtle one: `libxslt/xsltconfig.h.in` and
`libexslt/exsltconfig.h.in` exist, but they are `AC_CONFIG_FILES` `@VAR@`
substitution files (`configure.ac:567` and `:569`), not autoheader templates.
I confirmed they contain `@…@` substitutions (10 matches). Touching them would
be harmless but pointless; *not* naming them is right, and `stage1.md` risk 4
explains why. Guard position is correct: after `./configure`.

## 2. Is it doing what the package needs?

**`--without-python` is genuinely load-bearing, not cosmetic** — this is the
one real cross-build trap in the package, and the recipe is right to put it in
the system-neutral `generic.lua`. `configure.ac:190-198`:

```
AC_ARG_WITH(python, [  --with-python           build Python bindings (on)])

AS_IF([test "x$with_python" != "xno"], [
    AM_PATH_PYTHON
    PKG_CHECK_MODULES([PYTHON], [python-${PYTHON_VERSION}])
    case "$host" in
        *-*-cygwin* | *-*-mingw* | *-*-msys* )
            PYTHON_LDFLAGS="-no-undefined -shrext .pyd"
            ;;
    esac
])
```

`PKG_CHECK_MODULES` with **no action-if-not-found** expands to a hard
`as_fn_error`. The guard is `!= "xno"`, so the probe runs whenever the option
is merely *unset* — unlike libxml2 2.15.4, which probes only on an explicit
`yes`. Every system in this tree sets `PKG_CONFIG_LIBDIR` to `$PREFIX` only and
clears `PKG_CONFIG_PATH` (verified in `aarch64-android24`, `x86_64-mingw`,
`clang-native`), so a host `python-N.pc` is never visible and configure would
abort on **all six** systems without the flag. Correctly in `generic.lua`
because it is a property of this release's probe, not of any target.

**`--without-debugger` is honestly labelled as a no-op.**
`configure.ac:266-272`:

```
AC_ARG_WITH(debugger, [  --with-debugger        Add the debugging support (on)])
if test "$with_debugger" != "yes" ; then
    WITH_DEBUGGER=0
else
    echo Enabling debugger
    WITH_DEBUGGER=1
    AC_DEFINE([WITH_DEBUGGER],[], [Define if debugging support is enabled])
fi
```

So an unset option already leaves `WITH_DEBUGGER=0` and no define. The recipe
says so in its comment and `stage1.md` risk 3 explicitly warns a reviewer not
to "fix" it into a different flag. That is exactly right — and it is the kind
of honest labelling AGENTS.md wants, since a reviewer who believed the comment
would otherwise hunt for a bug that is not there.

**libxml2 is located correctly, and the fallback reasoning holds.**
`configure.ac:405-413` is the `PKG_CHECK_MODULES([LIBXML], [libxml-2.0 >= …])`
and `configure.ac:25` is `LIBXML_REQUIRED_VERSION=2.15.1`. The `xml2-config`
fallback at `configure.ac:420-437` is not reached because the pkg-config branch
leaves `LIBXML_LIBS` non-empty — and `AC_PATH_TOOL` (`configure.ac:332`) would
not find `$PREFIX/bin` anyway since `$PREFIX/bin` is not on `PATH`. Both claims
verified.

**Nothing host-side is compiled or executed.**
`grep -c 'AC_RUN_IFELSE\|AC_TRY_RUN' configure.ac` → **0**. `--with-crypto` is
off (`configure.ac:205`) and `--with-plugins` off (`configure.ac:449-451`), so
neither libgcrypt nor the shared-library plugin path is pulled in.

The profiler is left at its default (on, `configure.ac:280-287`) and is not
host-side: pure C calling `clock_gettime`/`gettimeofday`
(`libxslt/xsltutils.c`). I did not re-probe `clock_gettime` at API 21 — the
adder did and recorded rc=0 — but it is a POSIX 1993 function available since
Bionic's earliest API, so this is not a live risk.

**No `android.lua`, and that is the right call.** There is no switch here that
is correct for Android and wrong elsewhere; the one dangerous probe is disabled
for every system. Writing an `android.lua` that merely repeated the generic
build would be a second copy to keep in sync — precisely what AGENTS.md's
one-file-per-family rule exists to prevent.

## Corrections to `stage1.md` (none blocking)

- **The `source.lua` filename is misleading, and I checked whether it breaks.**
  It writes xz content to `dl/libxslt.tar.gz` and extracts with `tar -xJf`.
  `tar`'s `-J` selects the decompressor explicitly and ignores the filename,
  so I tested it: `tar -xJf misnamed.tar.gz` on xz content extracted all 40
  entries cleanly. So the recipe works — but the `.tar.gz` name is a genuine
  readability wart (the guard `if [ ! -f dl/libxslt.tar.gz ]` and the `-xJf`
  disagree). Worth a one-word fix to `dl/libxslt.tar.xz` for the next reader.
  Not a defect.
- `stage1.md` says the tarball is 1,519,992 bytes; I measured 1,519,992 and
  `tar tf` succeeded. Exact.
- `stage1.md` notes 1.1.44 is absent upstream. I listed the directory: 1.1.40,
  1.1.41, 1.1.42, 1.1.43, **1.1.45**. 1.1.44 is indeed not published, and
  1.1.45 is the newest. Correct.

## Artifacts — what actually installs

From the real `Makefile.am` files:

- `lib/libxslt.a` — `libxslt/Makefile.am:3 lib_LTLIBRARIES = libxslt.la`
- `lib/libexslt.a` — `libexslt/Makefile.am:5 lib_LTLIBRARIES = libexslt.la`
- `include/libxslt/*.h`, `include/libexslt/*.h`
- `lib/pkgconfig/libxslt.pc`, `lib/pkgconfig/libexslt.pc` —
  `Makefile.am:45-46` (`pkgconfigdir=$(libdir)/pkgconfig`,
  `pkgconfig_DATA = libxslt.pc libexslt.pc`)
- `bin/xsltproc` — `xsltproc/Makefile.am:5 bin_PROGRAMS = xsltproc`
- `bin/xslt-config` — `Makefile.am:13 bin_SCRIPTS = xslt-config`
  (`stage1.md` omits this one; it does install)

## Forecast

I agree with **6 of 6**. All six rows are **WILL BUILD**.

The reasoning chain checks out end to end: `--without-python` removes the one
hard configure error; libxml2 is in the prefix and satisfies
`>= 2.15.1`; no `AC_RUN_IFELSE` anywhere; the API-28 iconv gate is entirely
libxml2's and is already resolved by libxml2's own recipes (`--without-iconv`
below 28, none at or above).

**`clang-native` in particular deserves the adder's own emphasis, and it is
right for a second reason it did not state.** The adder's point is that
`PKG_CONFIG_LIBDIR="$PREFIX"` hides any host `python-N.pc`. That is correct.
But note that libxslt, unlike the four meson packages, is **not** subject to the
clang-native `MESON_FLAGS` gap at all: `packages/clang-native/generic.lua:53`
exports `AUTOCONF_CONFIGURE_FLAGS="--build=… --prefix=$OUT"`, so
`--prefix=$OUT` is carried and the install lands correctly. Same for mingw and
every Android system. So libxslt's clang-native row is sound as written.

## Carried to the build

```sh
# 1. artifacts (expected: all present)
test -f "$OUT/lib/libxslt.a"                     || echo "MISSING libxslt.a"
test -f "$OUT/lib/libexslt.a"                    || echo "MISSING libexslt.a"
test -x "$OUT/bin/xsltproc"                      || echo "MISSING xsltproc"
test -f "$OUT/lib/pkgconfig/libxslt.pc"          || echo "MISSING libxslt.pc"
test -f "$OUT/lib/pkgconfig/libexslt.pc"         || echo "MISSING libexslt.pc"

# 2. version expected 1.1.45
PKG_CONFIG_LIBDIR="$OUT/lib/pkgconfig" pkg-config --modversion libxslt

# 3. no $OUT left in either .pc — proves the loader rewrite ran. Scoped to
#    libxslt's own two files, not the pkgconfig directory (which holds every
#    package in the prefix).
grep -l "$OUT" "$OUT/lib/pkgconfig/libxslt.pc" "$OUT/lib/pkgconfig/libexslt.pc"
echo "(no output above = loader rewrite ran)"

# 4. THE PYTHON CHECK. The string "checking for python-" must NOT appear in
#    the configure log at all: its presence means --without-python did not take
#    effect and configure is one python-N.pc away from aborting. Assert the
#    absence, and do not let a pipe swallow the status.
if grep -q 'checking for python-' "$WORK/config.log"; then
  echo "REGRESSION: python probe ran; --without-python did not take effect"
else
  echo "OK: no python probe"
fi

# 5. --without-debugger is currently a no-op; confirm the define is absent,
#    which is what "upstream default is already off" predicts.
grep -c 'WITH_DEBUGGER' "$WORK/config.h"        # expected 0

# 6. it links against THIS tree's libxml2, not a system one: xmlXPathCompOpEval
#    and friends must be undefined in the archive.
llvm-nm -u "$OUT/lib/libxslt.a" | grep -cw xmlXPathCompOpEval   # expected 1
llvm-nm -u "$OUT/lib/libxslt.a" | grep -cw xmlFreeDoc          # expected 1

# 7. static, ELF machine per family
$OBJDUMP -f "$OUT/lib/libxslt.a" | head -3

# 8. xsltproc is a target binary: right architecture, and never executed by the
#    build. grep the build log for any attempt to run it.
$OBJDUMP -f "$OUT/bin/xsltproc" | head -3
grep -c 'xsltproc' "$WORK/config.log"    # config.log mentions it only as install metadata
```