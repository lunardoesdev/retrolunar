REJECT

# Gperf 3.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gperf/`. I did not build.

## Required changes

### 1. `packages/gperf/generic.lua:8` — the guard names two templates gperf does not have, and misses the two it does

```
        touch configure config.h.in
```

Verified against the real unpacked tree — gperf has **two** independent
sub-configures, each with its own template and its own `$(AUTOHEADER)`
maintainer rule:

```
$ grep -n AC_CONFIG_HEADERS nest/source/gperf/src/configure.ac nest/source/gperf/lib/configure.ac
src/configure.ac:AC_CONFIG_HEADERS([config.h])
lib/configure.ac:AC_CONFIG_HEADERS([config.h])
$ find nest/source/gperf -maxdepth 2 -name 'config.h.in'
nest/source/gperf/src/config.h.in
nest/source/gperf/lib/config.h.in
$ ls nest/source/gperf/config.h.in
ls: cannot access ...: No such file or directory
```

`touch` creates a stray empty `config.h.in` at the top level and leaves
**both** real templates unguarded — exactly the re-run the guard exists to
prevent.

**Replace line 8 with:**

```
        touch configure src/config.h.in lib/config.h.in
```

and, for symmetry with the `aclocal.m4` sweep on line 10, timestamp the
sub-configures too:

```
        find . -name 'configure' | xargs touch
```

**This does not fail today's build** — `touch` of a missing file in an
existing directory exits 0 (verified under the emitted `set -eu`; only a
missing *directory* aborts). The guard is inert rather than fatal.

### 2. Nothing else is required

The other three deviations in this recipe are all **good** and should be kept:

- `find . -name 'aclocal.m4' | xargs touch` instead of `touch aclocal.m4` —
  correct, because gperf's sub-configures ship their own `aclocal.m4`, and the
  recipe's comment says so.
- `touch doc/gperf.info doc/gperf.pdf doc/gperf.html doc/gperf.1` — correct;
  all four ship in the release, and touching them stops make demanding TeX.
- `make -j1` / `make install` — serial, and the install needs no flags.

gperf is a self-contained C++ program needing no m4, no gperf and no other
host tool, and it is the `gperf@native` provider for `bison` and
`libseccomp` — so this recipe is on the critical path for both. The six
WILL BUILD verdicts stand; `x86_64-mingw` is legitimately UNCERTAIN.

## Carried to the build

- `bin/gperf` — `llvm-objdump -f bin/gperf | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `share/info/gperf.info` — `[ -s share/info/gperf.info ]`; it ships pre-built, so a small file means TeX was invoked.
- `share/man/man1/gperf.1` — `[ -s share/man/man1/gperf.1 ]`.
- `lib/libgperf.a` — **must be absent** from `$OUT`; it is built for gperf's own tests and discarded.
- No `.pc`; gperf ships none.
- **Never run `bin/gperf`** — `bison@native` and `libseccomp` need a *runnable* gperf, which comes from the native prefix, not this one.

## Rework verification

**REJECT** — first line stays `REJECT`. The template half of Required change 1
was done correctly; the sub-configure half of the same change was not done at
all.

### Correctly fixed

`packages/gperf/generic.lua:7` is now
`touch configure src/config.h.in lib/config.h.in`. Verified against the tree:

```
$ grep -n AC_CONFIG_HEADERS nest/source/gperf/lib/configure.ac nest/source/gperf/src/configure.ac
lib/configure.ac:30:AC_CONFIG_HEADERS([config.h])
src/configure.ac:26:AC_CONFIG_HEADERS([config.h])
$ find nest/source/gperf -maxdepth 2 -name 'config.h.in'
nest/source/gperf/src/config.h.in
nest/source/gperf/lib/config.h.in
$ ls nest/source/gperf/config.h.in
ls: cannot access 'config.h.in': No such file or directory
```

Both required templates are named, in the right subdirectories, and the stray
top-level `config.h.in` is no longer created. That was the main defect and it
is genuinely fixed. The two deviations this file's §2 endorsed are intact and
undamaged: the `find . -name 'aclocal.m4' | xargs touch` sweep at line 9 with
its explanatory comment, and the four-file doc touch at line 12. `make -j1`
is on line 13, `make install` on line 14 unflagged (this file said that is
fine), flags still come from `$AUTOCONF_CONFIGURE_FLAGS` on line 6 with
nothing hardcoded, no `export`, and `require("gperf@source")` names a package
that exists.

### Still wrong — the sub-configure sweep was prescribed and is absent

Required change 1 had two parts. The first is done. The second was not:

> and, for symmetry with the `aclocal.m4` sweep on line 10, timestamp the
> sub-configures too:
> `find . -name 'configure' | xargs touch`

`packages/gperf/generic.lua` contains no such line. The sub-configures are
real and live:

```
$ ls -la nest/source/gperf/configure nest/source/gperf/lib/configure nest/source/gperf/src/configure nest/source/gperf/lib/aclocal.m4
-rwxr-xr-x  90542  gperf/configure
-rwxr-xr-x 545577  gperf/lib/configure
-rwxr-xr-x 163958  gperf/src/configure
-rw-r--r--  52578  gperf/lib/aclocal.m4
$ grep -n AC_CONFIG_SUBDIRS nest/source/gperf/configure.ac
33:AC_CONFIG_SUBDIRS([lib src tests doc])
```

`AC_CONFIG_SUBDIRS` is what makes them maintainer targets: the top-level
`Makefile` carries rules that re-run `$(AUTOHEADER)` and `$(AUTOCONF)` in each
subdirectory, and the subdirectory `configure` / `configure.ac` pair is
exactly the dependency whose mtime the sweep exists to defeat.

The recipe is now internally inconsistent, which is what makes this a REJECT
rather than a nit. Line 8's comment says *"The library subdirectory has its own
generated aclocal.m4"* — the author identified the subdirectory as the hazard
and swept its `aclocal.m4` — and then left that same subdirectory's much
cheaper-to-regenerate `configure` untouched on the very next line. Sweeping
`aclocal.m4` while not sweeping `configure` protects the input to autoconf and
ignores its output.

**Fix — insert between line 7 and line 8:**

```
        find . -name 'configure' | xargs touch
```

That makes lines 7-10:

```
        touch src/config.h.in lib/config.h.in
        find . -name 'configure' | xargs touch
        # The library subdirectory has its own generated aclocal.m4.
        find . -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
```

Two notes on that. The comment should move above the new `configure` sweep,
since it explains the subdirectory concern both sweeps now share. And
`find . -name 'configure'` matches all three `configure` scripts including the
top-level one, so the literal `configure` can come off line 7 — `src/config.h.in
lib/config.h.in` is what still needs naming explicitly.

### Where the original review contradicted itself

Required change 1 prescribed the sub-configure sweep, and §2 then declared
"Nothing else is required" and listed the recipe as correct. Both cannot hold.
§2 is the part that needs correcting, and the corrected reading is the reason
this is rejected: the recipe is not yet in the state §2 blessed.

### Noted, not charged

`touch doc/gperf.info doc/gperf.pdf doc/gperf.html doc/gperf.1` is brittle
against a release that changes the file set, and `stage1.md:41-46` raised
that. This file's §2 endorsed it and `touch` on a missing name is non-fatal,
so it does not affect the verdict. It is the one remaining spot in these six
packages where a stale name would fail silently rather than loudly.
