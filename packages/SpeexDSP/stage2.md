REJECT

# SpeexDSP 1.2.1 — review

Recipe: `source.lua`, `generic.lua` (no `android.lua`).
Checked against `packages/aarch64-android24/generic.lua`,
`packages/x86_64-mingw/generic.lua`, `packages/clang-native/generic.lua`.

The provenance claim is sound. The argument built on top of it is not: the
recipe compiles five host test programs on every cross build, and the
stated reason why it does not is demonstrably false.

## Required changes

1. **Add `--disable-examples` to the `./configure` line**
   (`packages/SpeexDSP/generic.lua:19`). Upstream `libspeexdsp/Makefile.am:35`
   is `noinst_PROGRAMS = testdenoise testecho testjitter testresample
   testresample2`, gated on `if BUILD_EXAMPLES`, and `configure.ac:175-180`
   makes that conditional **true by default**:

   ```m4
   AC_ARG_ENABLE(examples, [  --disable-examples      Do not build example programs, only the library])
   if test "$enableval" != no; then
     AM_CONDITIONAL([BUILD_EXAMPLES], true)
   ```

   The recipe passes no `--disable-examples`, so `make` compiles and links
   all five on every one of the six systems. They are `noinst_`, so nothing
   is installed — but they are five target executables built for nothing on
   a cross build, which is the thing AGENTS.md's "no host programs on a cross
   build" rule exists to prevent, and they will not be quiet: each one links
   the target `libspeexdsp.la`.

2. **Correct the false justification** in `packages/SpeexDSP/generic.lua:9-13`
   and `packages/SpeexDSP/stage1.md:14` and `stage1.md:64-65`.

3. **Replace the vacuous verification check** at `packages/SpeexDSP/stage1.md:64-65`
   (see "Carried to the build").

## The false stated reason, in detail

`stage1.md:14` and `generic.lua:9-13` both rest on this:

> `Makefile.am:14` is `SUBDIRS = libspeexdsp include doc win32 symbian ti` —
> the `regressions/` directory that holds the test programs is **not** in
> `SUBDIRS`, only in `DIST_SUBDIRS` (`:16`)

`stage1.md` flags this itself as "subtle and easy-to-get-wrong", so it is
the right thing to check. It is wrong on both halves. From the unpacked
Debian tarball:

```
$ cat -n Makefile.am
13	#Fools KDevelop into including all files
14	SUBDIRS = libspeexdsp include doc win32 symbian ti
15
16	DIST_SUBDIRS = libspeexdsp include doc win32 symbian ti
```

Lines 14 and 16 are **byte-identical**. `regressions` appears in neither
list — not in `SUBDIRS`, and not in `DIST_SUBDIRS` either. So the
"in `DIST_SUBDIRS` but not `SUBDIRS`" distinction the recipe and forecast
both build on does not exist.

And it does not matter, because the directory is not there at all:

```
$ ls regressions regression-fixes
ls: cannot access 'regressions': No such file or directory
ls: cannot access 'regression-fixes': No such file or directory
```

The Debian orig tarball is a `make dist` output, and `regressions/`,
`regression-fixes/`, `tmv/`, `html/` and `macosx/` are all absent from it
(they are in the git tree; see the file-set diff below). So on the source
this recipe actually builds, there is nothing in `regressions/` to keep out
of the build, and the five programs that *do* get built are the
`libspeexdsp` ones the forecast never mentions.

The conclusion ("nothing host-side is built") is wrong; the reasoning is
wrong; and the recipe omits the switch that would make the conclusion true.
Per AGENTS.md ("a wrong justification is a real defect, because it is what
makes the next person 'fix' a correct flag"), this is a REJECT even though
the timestamp guard and the source choice are both right.

## Provenance of the Debian tarball — the claim is TRUE, verified

The brief asked for this to be checked carefully, because a `+ds` repack
would be a hard no-patch violation. It is clean.

**No Debian machinery at all:**

```
$ ls -d speexdeb/debian
ls: cannot access 'speexdeb/debian': No such file or directory
$ ls speexdeb/debian/patches
ls: cannot access 'speexdeb/debian/patches': No such file or directory
```

**Every file common to the GitHub tag tree and the Debian tarball is
byte-identical.** I compared the full intersection, not a sample:

```
$ comm -12 <(cd speex && find . -type f | sort) <(cd speexdeb && find . -type f | sort) \
  | while read f; do cmp -s "speex/$f" "speexdeb/$f" || echo "DIFFERS: $f"; done
(no output)
```

Zero differing files. So no file that upstream ships was modified — which
is the definition of "unmodified", independent of what Debian calls it.

**The only files unique to the Debian tarball are autotools-generated plus
one generated spec** — i.e. exactly the set `make dist` adds and a git
archive lacks:

```
Makefile.in  SpeexDSP.spec  aclocal.m4  compile  config.guess  config.h.in
config.sub  configure  depcomp  install-sh  ltmain.sh  missing
m4/libtool.m4  m4/ltoptions.m4  m4/ltsugar.m4  m4/ltversion.m4  m4/lt~obsolete.m4
doc/Makefile.in  include/Makefile.in  include/speex/Makefile.in
libspeexdsp/Makefile.in  symbian/Makefile.in  ti/Makefile.in
ti/speex_C54_test/Makefile.in  ti/speex_C55_test/Makefile.in  ti/speex_C64_test/Makefile.in
win32/Makefile.in  win32/VS2003/Makefile.in  win32/VS2003/libspeexdsp/Makefile.in
win32/VS2003/tests/Makefile.in  win32/VS2005/Makefile.in
win32/VS2005/libspeexdsp/Makefile.in  win32/VS2005/tests/Makefile.in
win32/VS2008/Makefile.in  win32/VS2008/libspeexdsp/Makefile.in
win32/VS2008/tests/Makefile.in  win32/libspeexdsp/Makefile.in
```

`SpeexDSP.spec` is generated from `SpeexDSP.spec.in`, which *is* in the git
tree; the rest is automake/autoconf/libtool output. `m4/lt~obsolete.m4` is
automake's own filename, not a patch marker.

**The three generated files the recipe depends on are all present:**

```
$ ls -la configure aclocal.m4 config.h.in
-rw-r--r-- 54394  aclocal.m4
-rw-r--r--  4907  config.h.in
-rwxr-xr-x 499329  configure
```

**And the version is right:** `configure.ac:3` is
`AC_INIT([speexdsp],[1.2.1],[speex-dev@xiph.org])`, and the generated
`configure:624-625` carries `PACKAGE_VERSION='1.2.1'` /
`PACKAGE_STRING='speexdsp 1.2.1'`. The source URL resolves.

So the adder's provenance claim holds, and fetching from Debian's pool is
the right call here (the GitHub tag archive genuinely ships no `configure`,
and `downloads.xiph.org` dist tarballs are gone). `stage1.md`'s warning
that a Debian-sourced tarball is a standing assumption to re-check on
update is well placed, and the contrast it draws with a `+ds` repack is
correct.

## Question 1 — is it using the SYSTEM?

Yes. `./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static
--disable-shared --with-pic`, then `make -j1`, `make -j1 install`. No
hardcoded target facts, no `export` of search flags.
`require("SpeexDSP@source")` resolves. `--with-pic` is a real libtool
option (it appears at `configure:1505` in the help text and is consumed at
`:8813-8816`), so it is not a phantom switch. `make -j1` is explicit and
`make` is serial anyway, so no fan-out. Correct.

## The timestamp guard — correct, and worth saying so

This is the one thing AGENTS.md's seven-spelling trap would have caught, and
the adder got it right by checking the tree:

- `configure.ac:338` is `AC_CONFIG_HEADERS([config.h])` → the template is
  `config.h.in`. Confirmed present (4 907 bytes, above).
- **Position is correct**: `touch aclocal.m4 configure config.h.in` and the
  `find . -name 'Makefile.in' | xargs touch` both sit **after** `./configure`
  and **before** `make`, which is the rule.
- The `find … Makefile.in | xargs touch` sweep is load-bearing rather than
  decorative: this tree has 22 `Makefile.in` files across `doc/`, `include/`,
  `include/speex/`, `libspeexdsp/`, `symbian/`, `ti/`, `ti/speex_C5*_test/`
  and six `win32/VS*` directories, and the tarball's mtimes are a mix of
  2018 (`Makefile.am`) and 2022 (`Makefile.in`) — exactly the skew that
  triggers automake re-runs.

Nothing to change here. Note for the record that this is a genuine
sub-configured-shaped project (`win32/` and `ti/` recurse via their own
`SUBDIRS`), but none of them has its own `configure`/`aclocal.m4`/config
template, so the top-level `touch` plus the `Makefile.in` sweep is the
correct guard, not a partial one.

## The other subdirectories — checked, and clean

`stage1.md` risk 2 asks for an eye on `ti/`. I read all of them:

- `ti/Makefile.am` has `SUBDIRS = speex_C54_test speex_C55_test
  speex_C64_test`, but each of those three is `EXTRA_DIST = …cmd …pjt`
  only — no programs, nothing to compile.
- `win32/Makefile.am` has `SUBDIRS = libspeexdsp VS2003 VS2005 VS2008`, and
  every leaf (`win32/libspeexdsp`, `win32/VS200{3,5,8}`,
  `win32/VS200{3,5,8}/libspeexdsp`, `win32/VS200{3,5,8}/tests`) is
  `EXTRA_DIST = *.vcproj` or `*.dsp` only. No programs. This is what
  `stage1.md:18` says and it is correct — the recursion is real, the
  programs are not.
- `doc/Makefile.am` is `doc_DATA = manual.pdf`. `doc/manual.pdf` is present
  in the tarball (439 545 bytes), so it is a prebuilt data file that gets
  *installed*, not regenerated. `stage1.md` risk 3's worry that something
  might "regenerate them with a host tool" is unfounded — there is no rule
  in that Makefile.am that could. Good news, recorded so the builder does
  not go looking for it.
- `symbian/Makefile.am` is `EXTRA_DIST` only.

So the *only* host-program problem is the one the recipe does not address:
`libspeexdsp`'s five `noinst_PROGRAMS`.

## The forecast

All six rows say WILL BUILD, and the reason given in each is
"`regressions/` is not in `SUBDIRS`, so SpeexDSP's tests never enter the
build … That is the key fact". **The key fact is false**, and the thing that
does enter the build was never identified. So the forecast is wrong on the
specific mechanism it rests on, on all six rows.

The API-level notes ("None. The codec is portable C") are credible — I
looked for libc dependencies and the library sources are
`preprocess.c jitter.c mdf.c fftwrap.c filterbank.c resample.c buffer.c
scal.c` plus an FFT, with `libspeexdsp_la_LIBADD = $(LIBM)`, and `-lm` is
already in every Android system's `LDFLAGS`. No gate found. The one thing
the forecast could not have known is that `--disable-examples` is simply
missing.

## Carried to the build

- `lib/libspeexdsp.a` exists; `include/speex/speexdsp.h` exists.
  (`libspeexdsp_la_SOURCES` at `libspeexdsp/Makefile.am:26`;
  `speexinclude_HEADERS` at `include/speex/Makefile.am`.)
- `pkg-config --modversion speexdsp` reports 1.2.1 (`pkgconfig_DATA =
  speexdsp.pc`, `Makefile.am:8-9`).
- `$OBJDUMP -f lib/libspeexdsp.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libspeexdsp.a | grep -cw speex_resampler`
  non-zero.
- **Replace `stage1.md`'s check.** `find $OUT -name '*_unittest*' -o -name
  'testwrapper*'` **cannot match its own target**: neither name occurs
  anywhere in SpeexDSP. Those are some other project's test binaries. It
  passes vacuously on a build where all five test programs *were* compiled.
  The check that actually means something, and that matches the real names
  from `libspeexdsp/Makefile.am:35`:

  ```
  find $OUT -name 'testdenoise*' -o -name 'testecho*' -o -name 'testjitter*' \
       -o -name 'testresample*'
  ```

  Expected result: **nothing** — they are `noinst_`, so a correct build
  compiles them and installs nothing. State that expected value explicitly;
  the check is worth keeping in this form precisely because it is the only
  thing that would catch `--disable-examples` regressing. A count of `0` is
  the assertion, and note it cannot pass vacuously in an empty `$OUT`
  because it is scoped to this package's own stage dir.
- Check the build log for `Making all in doc` completing without invoking a
  host tool (it should not; `doc/Makefile.am` only installs a shipped PDF).
- The freshness stamp should appear: rerunning prints `skip SpeexDSP (fresh)`.
