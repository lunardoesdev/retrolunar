REJECT

# acl 2.3.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/acl/`. I did not build.

One mandated-rule defect in the autotools timestamp guard, plus two artifact
errors in the forecast.

## Required changes

### 1. `packages/acl/generic.lua:8` — the guard names a config template acl does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/acl/configure.ac
AC_CONFIG_HEADERS([include/config.h])
$ find nest/source/acl -maxdepth 2 -name 'config.h.in'
nest/source/acl/include/config.h.in
$ ls nest/source/acl/config.h.in
ls: cannot access ...: No such file or directory
```

So `touch` creates a stray empty `config.h.in` in `$WORK` and leaves
`include/config.h.in` — the file automake actually watches — at tarball
mtime. AGENTS.md names this trap explicitly ("a config template named
config.hin or ac_config.h.in instead of config.h.in, which changes the
timestamp guard"). `packages/libnl-3` and `packages/libunwind` already guard
`include/config.h.in`; this one was missed.

**Replace line 8 with:**

```
        touch aclocal.m4 configure include/config.h.in
```

**This does not fail today's build** — acl is `[x]` and did build. `touch` of a
missing file in an existing directory exits 0 (verified), so the stray file is
harmless and the block continues. The defect is that the guard is *inert*: the
`$(top_srcdir)/include/config.h.in: $(am__configure_deps) → $(AUTOHEADER)`
maintainer rule can still fire on a tarball mtime, and under the emitted
`set -eu` the `missing` wrapper would abort the build. Latent, not observed.

### 2. `packages/acl/stage1.md` — correct the artifact list

- It says "no pkg-config file". `libacl.pc` **is** installed, to
  `$(libdir)/pkgconfig`, and is inside the loader's `$OUT`→`$PREFIX` rewrite
  set.
- It says the build is static-only. libtool builds **both** `libacl.a` and
  `libacl.so`; the recipe passes no `--disable-shared`. That is fine and
  intentional for a library another package links, but the artifact list must
  say so, and the builder should check for the `.so`.

### 3. Nothing else is required

`require("attr")` is a real dependency and `packages/attr` exists — attr is
load-bearing here. `./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag
from the system. `make -j1` is serial. The six WILL BUILD verdicts stand.

## Carried to the build

- `lib/libacl.a` — `llvm-objdump -f lib/libacl.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `lib/libacl.so` — expected as well as the `.a`; `[ -f lib/libacl.so ]`. Its absence would mean a `--disable-shared` was added without the artifact list being updated.
- `include/sys/acl.h`, `include/acl/libacl.h` — `[ -f include/sys/acl.h ] && [ -f include/acl/libacl.h ]`.
- `lib/pkgconfig/libacl.pc` — `pkg-config --modversion libacl` → `2.3.2`.
- `bin/getfacl`, `bin/setfacl` — `[ -x bin/getfacl ]`. Target programs; never run them.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- Required change 1 is done and correct. `packages/acl/generic.lua:8` now reads
  `touch aclocal.m4 configure include/config.h.in`, which is exactly what the
  tree ships:

  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/acl/configure.ac
  AC_CONFIG_HEADERS([include/config.h])
  $ find nest/source/acl -name 'config.h.in'
  nest/source/acl/include/config.h.in
  ```

  The guard is positioned correctly: `./configure` on line 7, guard on lines
  8-9, `make -j1` on line 10. `find . -name 'Makefile.in' | xargs touch` is
  adequate — acl 2.3.2 is a non-recursive build with exactly one `Makefile.in`,
  at the top level, so no subdirectory copy is missed.
- The rest of the recipe is undamaged: every flag comes from
  `$AUTOCONF_CONFIGURE_FLAGS`, `$PREFIX`, `$OUT`, `$NESTDIR`. No `export`, no
  `sed`, no `/dev/null`, no patch, `make -j1`. `require("attr")` and
  `require("acl@source")` both resolve — `packages/attr` exists and is itself
  correct.
- The "Installs" bullet (`stage1.md:6`) was corrected: it now claims
  `libacl.a` **and** `libacl.so` and lists `lib/pkgconfig/libacl.pc`. Both
  facts check out: `acl/libacl/Makemodule.am:1` is
  `lib_LTLIBRARIES += libacl.la` under an unconditional `LT_INIT`
  (`configure.ac:35`) with no `--disable-shared` in the recipe, and
  `acl/Makefile.am:16` is `pkgconf_DATA = libacl.pc` with
  `pkgconfdir = $(libdir)/pkgconfig` (`Makefile.am:13`), generated from
  `configure.ac:70`.

### Still wrong

- **`packages/acl/stage1.md:40`** — "No `.pc` file — a consumer uses `-lacl`
  with `-I$PREFIX/include`". This is the exact sentence required change 2
  said was wrong, it is still there verbatim, and it now **contradicts
  `stage1.md:6`** in the same file, which the adder did fix. The builder reads
  "How to verify once built" to decide what to check, so this line will
  suppress the `lib/pkgconfig/libacl.pc` check that this stage2's own "Carried
  to the build" section makes load-bearing. Required change 2 is therefore
  half-done: the artifact list was corrected, the verification list that
  repeats the same claim was not.
  **Fix:** replace that bullet with
  `- lib/libacl.so must be present alongside the .a; lib/pkgconfig/libacl.pc — pkg-config --modversion libacl → 2.3.2`
  and drop the "No `.pc` file" sentence entirely.

### Minor (not blocking, but recorded)

- `packages/acl/stage1.md:11` cites `libattr/generic.lua:8-13`. That file is
  12 lines, so the citation runs off the end and now points at the guard line
  rather than the build. Cosmetic, but it is a citation the builder may follow.

### Broken by the rework

Nothing. No flag was added, removed or re-spelled, and no system fact was moved
into the recipe.

## Rework verification — summary

The one defect that was rejected is fixed and verified against the tree. The
package is rejected only because a false claim the review explicitly named
survives at `stage1.md:40`, in direct contradiction of the line above it in
the same file.
