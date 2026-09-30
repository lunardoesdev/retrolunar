ACCEPT

# GMP 6.3.0 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gmp/`. I did not build.

## Required changes

### 1. `packages/gmp/generic.lua` — the mandated autotools timestamp guard is missing entirely

The build body is:

```
        cp -r $NESTDIR/source/gmp/* .
        ./configure $AUTOCONF_CONFIGURE_FLAGS \
            --enable-cxx \
            --disable-static \
            --docdir="$OUT/share/doc/gmp-6.3.0"
        make -j1
        make -j1 install
        make -j1 install-html
```

There is **no `touch` guard at all** after `./configure`. AGENTS.md mandates
one: *"Autotools timestamp guard after every `./configure` (tarball mtimes
trigger `aclocal-1.17` re-runs we don't have)"*. GMP is the only recipe in this
shard that runs `./configure` and has no guard whatsoever.

And GMP's template has another first-name variant, so a blind copy of the
standard line would be wrong again. Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gmp/configure.ac
AC_CONFIG_HEADERS(config.h:config.in)
$ find nest/source/gmp -maxdepth 2 \( -name 'config.h.in' -o -name 'config.in' \)
nest/source/gmp/config.in
$ ls nest/source/gmp/config.h.in
ls: cannot access ...: No such file or directory
```

`config.in` — not `config.hin`, not `config.h.in`, not in a subdirectory. A
fourth spelling in a shard that already has `config.hin`, `config.in.h` and
`configh.in`.

**Insert after the `./configure` line (i.e. before `make -j1`):**

```
        # GMP's config template is config.in - not config.h.in and not
        # config.hin - so the standard guard has to name it explicitly.
        # Without this, a tarball mtime can make make re-run autoheader
        # through the missing wrapper, which aborts under the emitted
        # set -eu.
        touch aclocal.m4 configure config.in
        find . -name 'Makefile.in' | xargs touch
```

GMP is `[x]` and did build without the guard, because on that run the mtimes
came out favourably. That is luck, not a property of the recipe, and it is
exactly the failure the guard is in the rulebook to prevent.

### 2. `packages/gmp/generic.lua:9` — the docdir hardcodes the version

```
            --docdir="$OUT/share/doc/gmp-6.3.0"
```

The version is spelled into the path while `version` already lives in
`source.lua`. A version bump that misses this line installs the docs into a
directory named for the previous release and nothing catches it. Same nit as
`gettext/generic.lua:21`; either drop the flag so upstream's default applies
or derive it. `stage1.md` should also check the installed directory name
against the pinned version.

### 3. Nothing else is required

- `make -j1` / `make -j1 install` / `make -j1 install-html` are all serial.
  Correct.
- `--enable-cxx` is a real GMP option and is needed for `libgmpxx`. Every
  system exports `$CXX`. Nothing is hardcoded to a target.
- `--disable-static` makes GMP shared-only, which is the opposite of this
  prefix's convention. That is a deliberate and defensible choice for GMP
  (its upstream default, and the library is large and slow to relink), but the
  recipe does not say so, and the backlog line's "static `libgmpxx`…" wording
  should be checked against what is actually installed. A comment stating the
  reason would settle it.
- `require("gmp@source")` names no missing package.

## Carried to the build

- `lib/libgmp.so*` (or `.a` if static is ever re-enabled) — `llvm-objdump -f lib/libgmp.so.10 | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Record which shape appears; `--disable-static` means a `.so`, and a `.a` would mean the flag did not take.
- `lib/libgmpxx.so*` — `[ -f lib/libgmpxx.so ]`; its presence is the check that `--enable-cxx` worked and that `$CXX` resolved.
- `include/gmp.h`, `include/gmpxx.h` — `[ -f include/gmp.h ] && [ -f include/gmpxx.h ]`.
- `lib/pkgconfig/gmp.pc`, `lib/pkgconfig/gmpxx.pc` — `pkg-config --modversion gmp` → `6.3.0`, and `pkg-config --modversion gmpxx` → `6.3.0`. Both `.pc` files are inside the loader's `$OUT`→`$PREFIX` rewrite set.
- `share/doc/gmp-6.3.0/` — and the directory name must match the pinned version, which is the direct check for change 2.
- **Never run anything GMP installs.**

## Rework verification

**ACCEPT** — first line changed from `REJECT` to `ACCEPT`.

### Correctly fixed

**Required change 1 — the missing guard.** `packages/gmp/generic.lua:11` is now

```
        touch aclocal.m4 configure config.in
```

Verified against the tree, not against the new comment, and with the open
question about `config.in.h`-style variants settled by exhaustive search
rather than assumption:

```
$ grep -n AC_CONFIG_HEADERS nest/source/gmp/configure.ac
82:AC_CONFIG_HEADERS(config.h:config.in)
$ find nest/source/gmp \( -name 'config*.in' -o -name 'config*.h' -o -name 'config*.hin' \)
nest/source/gmp/config.in
$ ls nest/source/gmp/config.h.in nest/source/gmp/config.in.h
ls: cannot access 'config.h.in': No such file or directory
ls: cannot access 'config.in.h': No such file or directory
```

`config.in` is the only header template in the entire tree. There is no
`config.hin`, no `config.h.in`, and no `config.in.h` — the comment at
lines 9-10 is accurate on both counts. The two other `.in` headers in the
tree, `demos/pexpr-config-h.in` and `demos/calc/calc-config-h.in`, are
`AC_CONFIG_FILES` outputs (`configure.ac:4012` and `:4038`), not
`AC_CONFIG_HEADERS` inputs, so autoheader does not watch them and they are
correctly absent from the touch list. `gmp-h.in`, `gmp.pc.in`, `gmpxx.pc.in`
are likewise `AC_CONFIG_FILES`/`AC_CONFIG_LINKS` sources.

Position is right: line 11 is after `./configure` (line 8) and before
`make -j1` (line 13). Line 12's `find . -name 'Makefile.in' | xargs touch`
covers the real set, and GMP's subdirectory count is the reason it matters
here more than for a flat package: `cxx/ doc/ mpf/ mpn/ mpq/ mpz/ printf/
rand/ scanf/ tests/ tune/ demos/` each ship a `Makefile.in` and all are
reached by the `-name` sweep.

**Required change 2 — the docdir version literal.** Done, and the comment's
claim checks out:

```
$ grep -n "^docdir=" nest/source/gmp/configure
917:docdir='${datarootdir}/doc/${PACKAGE_TARNAME}'
$ grep -m1 "PACKAGE_TARNAME=" nest/source/gmp/configure
PACKAGE_TARNAME='gmp'
```

With `--prefix=$OUT` supplied by `$AUTOCONF_CONFIGURE_FLAGS`, the default
resolves to `$OUT/share/doc/gmp`. The comment at lines 6-7 is true, the
literal `6.3.0` no longer appears anywhere in the recipe, and a version bump
in `source.lua:2` can no longer desynchronise the docs directory.

**Nothing else was damaged.** `--enable-cxx --disable-static` survive on line
8 with their flags still coming from `$AUTOCONF_CONFIGURE_FLAGS`; the three
`make -j1` invocations (build, install, `install-html`) are all serial;
`require("gmp@source")` names a package that exists; no `export`, no `sed`, no
patch, no `/dev/null`, no hardcoded target facts.

### `stage1.md` is wrong and this is where the wave's bug came from

`stage1.md:50-51`:

> The recipe uses `$AUTOCONF_CONFIGURE_FLAGS` correctly and includes the
> standard touch guard (`generic.lua:12`), which is right: **gmp's release
> ships a top-level `config.h.in`**.

There is no `config.h.in` in the gmp release. There was no guard at all in the
version stage1 was forecasting, and the sentence is self-contradictory in
either direction. This is a concrete instance of the failure AGENTS.md:369-373
describes: a forecast that asserted a fixed name, which is how a recipe came
to be written with no guard at all, or with the wrong one. This review's
finding was correct and `stage1.md` is the document that is wrong.
`stage1.md` is outside my remit to edit, so it is recorded here.

### Knock-on to this file

`stage2.md:95` tells the build to check `share/doc/gmp-6.3.0/` "and the
directory name must match the pinned version". Required change 2 removed the
version from that path on purpose, so the build should now look for
`share/doc/gmp/` and assert only that it is under `$OUT`. The `pkg-config
--modversion` checks on line 94 are unaffected and remain the real
version-tracking check.
