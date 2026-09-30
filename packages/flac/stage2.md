REJECT

# FLAC 1.5.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`flac-1.5.0` tree. I did not build.

## Required changes

### 1. `packages/flac/generic.lua:6-9` — the comment is false and the switch that would make it true is missing

```
        # Static libraries against the libogg in this prefix: libFLAC (the
        # format), libFLAC++ (the C++ decoder interface) and the plugins.
        # The command line tools and the test suite are host programs and
        # stay off.
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-oggtest
```

The guard (`touch ... config.h.in`) is **correct** here — flac really does use a
top-level `config.h.in`; it is one of only a handful in the shard that get it
right. The static flags are right too.

The comment is wrong: `flac` and `metaflac` are `bin_PROGRAMS` under an
`AM_CONDITIONAL` that defaults to true, so they are **built and installed** into
`$OUT/bin`. They are target programs, not host programs, and nothing in the
recipe stops them. If the intent is libraries-only, that needs
`--disable-programs`; if not, the comment and `stage1.md`'s artifact list must
say the tools are installed.

**Replace lines 6-9 with:**

```
        # Static libraries against the libogg in this prefix: libFLAC (the
        # format) and libFLAC++ (the C++ decoder interface). flac and
        # metaflac are bin_PROGRAMS and there is no switch that drops them
        # without --disable-programs; they are target programs, built and
        # installed, and never run here. --disable-oggtest was removed: flac
        # 1.5.0 has no such option, so it only printed "unrecognized
        # options" and switched nothing off. --disable-version-from-git
        # keeps configure from shelling out to git, which AGENTS.md keeps out
        # of the build path; the tarball's version string is already
        # substituted.
```

and the configure line with:

```
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-version-from-git
```

(add `--disable-programs` too if the tools are not wanted.)

### 2. `packages/flac/stage1.md` — three artifact errors

- "no command-line tools (flac, metaflac are noinst/check)" is wrong on both
  counts: they are `bin_PROGRAMS` and they are installed.
- The artifact list includes `lib/pkgconfig/ogg.pc`. flac installs only
  `flac.pc`; `ogg.pc` belongs to `libogg`, which is a separate package.
- The claim that the test programs are "compiled by `make all` and then
  discarded" is the opposite of what `--disable-oggtest` would do — and since
  that option does not exist, nothing was disabled at all.

## Carried to the build

- `lib/libFLAC.a` — `llvm-objdump -f lib/libFLAC.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `lib/libFLAC++.a` — `[ -f lib/libFLAC++.a ]`; its presence proves the C++ half compiled.
- `include/FLAC/*.h` and `include/FLAC++/*.h` — `[ -f include/FLAC/format.h ] && [ -f include/FLAC++/decoder.h ]`.
- `lib/pkgconfig/flac.pc` — `pkg-config --modversion flac` → `1.5.0`. `libogg` must also be present in the prefix, since flac links against it.
- `bin/flac`, `bin/metaflac` — expected unless `--disable-programs` is added. Either way, **never run them.**
- `lib/pkgconfig/ogg.pc` should come from `packages/libogg`, not from flac.

---

## Rework verification

**Verdict: REJECT.** Two of the four required changes are done; two claims
the rework was supposed to remove are still standing, and one of them is
the fabrication this review exists to catch.

### Required change 1 — the configure line: done

`generic.lua:14` now reads:

```
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-version-from-git
```

`--disable-oggtest` is gone. `--disable-version-from-git` is present, and
it is genuinely load-bearing — `configure.ac:370-374` defaults
`enable_version_from_git` to `yes`, and `configure.ac:511-516` then runs
`git describe` / `git log` inside an `if test x$GIT_FOUND$enable_version_from_git
= "xyesyes"`. Without the flag, and with a `git` on `$PATH`, configure
shells out to git, which AGENTS.md keeps out of the build path. The flag
short-circuits that `if` and the git calls never run.

### Required change 2a — the recipe comment: done

`generic.lua:7-13` now says flac and metaflac are `bin_PROGRAMS`, that
there is no switch dropping them short of `--disable-programs`, and that
they are built, installed and never run. That is correct:

```
$ grep -n "AC_ARG_ENABLE(\[programs\]" -A2 nest/source/flac/configure.ac
360:AC_ARG_ENABLE([programs],
361:	AS_HELP_STRING([--disable-programs], [Do not build and install flac and metaflac]))
362:AM_CONDITIONAL(FLaC__WITH_PROGRAMS, [test "x$enable_programs" != "xno"])
$ grep -n bin_PROGRAMS nest/source/flac/src/flac/Makefile.am nest/source/flac/src/metaflac/Makefile.am
src/flac/Makefile.am:27:bin_PROGRAMS = flac
src/metaflac/Makefile.am:27:bin_PROGRAMS = metaflac
$ grep -n PROGRAMS_DIRS -B2 nest/source/flac/src/Makefile.am
23:if FLaC__WITH_PROGRAMS
24:PROGRAMS_DIRS = flac metaflac
```

`test "x$enable_programs" != "xno"` with no default arm means the
conditional is **true** unless `--disable-programs` is passed. So they are
built and installed. The comment is right.

### Required change 2b — `stage1.md:6`: done

The "Installs" line now reads
"**`bin/flac` and `bin/metaflac` ARE installed**" with the two
`Makefile.am:27` citations, and it attributes `ogg.pc` to
`packages/libogg`. I confirmed both. flac installs only
`flac.pc` (`src/libFLAC/Makefile.am:53`) and `flac++.pc`
(`src/libFLAC++/Makefile.am:39`); neither `ogg.pc` nor any other `.pc`
appears in flac's `Makefile.am` tree. The `noinst` claim is gone from the
file.

### STILL WRONG — `stage1.md:57` reinstates the withdrawn claim

```
57:- `bin/flac` should be **absent** — confirms the "tools stay off" claim
```

This is the single reason for the REJECT. It is the *verification
checklist*, and it instructs the builder to expect the exact opposite of
what `stage1.md:6` and `stage1.md:28-35` now correctly assert. A builder
following line 57 would reject a **good** build — `bin/flac` will be
present, because it is a `bin_PROGRAMS` — and record the package as
failed. It also still carries the phrase "tools stay off", which is the
withdrawn claim verbatim.

`stage1.md:28-35` was rewritten specifically to withdraw that claim, and
the rewrite was not propagated to the verification section. Fix: delete
line 57, or replace it with `bin/flac`, `bin/metaflac` — expected unless
`--disable-programs` is added. **Never run them.**

### STILL WRONG — `stage1.md:43` misdescribes why `--disable-oggtest` left

```
43:- **`--disable-version-from-git` replaces the removed `--disable-oggtest`.**
```

Two problems in one line.

First, "replaces" is the wrong relation. The two flags do unrelated
things: `--disable-oggtest` skips a libogg *probe program*, while
`--disable-version-from-git` stops configure *shelling out to git*.
Dropping the first did not make room for the second.

Second, and more seriously, **the original stage2 justification for
removing `--disable-oggtest` was itself false, and stage1.md still carries
the corrected-sounding version of that falsehood.** stage2.md:38-40
claimed flac 1.5.0 "has no such option, so it only printed 'unrecognized
options' and switched nothing off". It does have the option:

```
$ grep -n oggtest nest/source/flac/m4/ogg.m4
15:AC_ARG_ENABLE(oggtest,AS_HELP_STRING([--disable-oggtest],[Do not try to compile and run a test Ogg program]),, enable_oggtest=yes)
$ ./configure --help | grep oggtest
$ grep -n "Check whether --enable-oggtest was given" nest/source/flac/configure
20022:# Check whether --enable-oggtest was given.
```

So the flag was real and it did switch something off. What it switches off
is `m4/ogg.m4:50-74`'s `AC_RUN_IFELSE` probe. That matters here: under
cross-compiling the `action-if-cross` arm is
`echo $ac_n "cross compiling; assumed OK..."` (`m4/ogg.m4:71`), so on the
five cross targets the probe is skipped anyway and removing the flag is
harmless. On `clang-native` the probe would compile *and run* a tiny
program whose body is `system("touch conf.oggtest")` — a host program,
which is permitted, but pointless.

The net effect is that removing `--disable-oggtest` is defensible but
*understated*, and the reason recorded for it is not true. Per AGENTS.md
("a recipe whose stated reason is false" is rejectable, because a wrong
justification is what makes the next person "fix" a correct flag), the
recipe must not carry a false reason. Fix `stage1.md:43` to state the real
one: `--disable-oggtest` skipped a libogg probe program
(`m4/ogg.m4:50-74`); on a cross build that probe is already inert, and on
the native build it only compiles and runs a `system("touch ...")` stub,
so the flag was noise. Keep `--disable-version-from-git` for its own,
separate, real reason.

### Required change 2c — the rest of `stage1.md`: done

The `ogg.pc` misattribution is gone from the artifact list and `:70` in
this file already said it belonged to libogg. The "test programs are
compiled by `make all` and then discarded" claim is gone; the truth is
that they are all `check_PROGRAMS` (`src/test_seeking`, `src/test_streams`,
`src/test_libFLAC`, `src/test_libFLAC++`, `src/test_grabbag/*`) which
`make all` does not build.

### The guard: correct

`generic.lua:15` touches `aclocal.m4 configure config.h.in`. flac really
does have a top-level `config.h.in`:

```
$ grep -n AC_CONFIG_HEADERS nest/source/flac/configure.ac
24:AC_CONFIG_HEADERS([config.h])
$ find nest/source/flac -name 'config.h.in'
nest/source/flac/config.h.in
```

(There is also a `config.cmake.h.in`, but that is the cmake path and this
recipe does not use it.) The guard sits between `./configure` (`:14`) and
`make` (`:17`), and `find . -name 'Makefile.in' | xargs touch` (`:16`)
covers the tree recursively, which matters here because flac's `Makefile.in`
files are spread over `src/`, `src/libFLAC/`, `src/libFLAC++/`,
`src/metaflac/`, `src/flac/`, `src/share/` and more.

### Nothing else damaged

`require("libogg")` resolves to a real `packages/libogg`. No `export`, no
hardcoded target facts, no `sed`/patch/`/dev/null`. `make -j1` (`:17`) and
`make install` (`:18`) are serial — note `:18` says `make install` rather
than `make -j1 install`, which is harmless since there is no jobserver
involved. No `android.lua`.

### One more thing `stage1.md:36-42` gets right and is worth keeping

flac's `--with-ogg-prefix` is not passed, so configure finds libogg through
the prefix's pkg-config path. That is implicit but works, and
`stage1.md:40` correctly cites the systems setting
`PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"`. Not a defect.
