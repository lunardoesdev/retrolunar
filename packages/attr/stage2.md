REJECT

# attr 2.5.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/attr/`. I did not build.

Same mandated-rule defect as acl, and attr is the load-bearing one: **acl
requires attr**, so attr's recipe is on the critical path for both.

## Required changes

### 1. `packages/attr/generic.lua:7` — the guard names a config template attr does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/attr/configure.ac
AC_CONFIG_HEADERS([include/config.h])
$ find nest/source/attr -maxdepth 2 -name 'config.h.in'
nest/source/attr/include/config.h.in
$ ls nest/source/attr/config.h.in
ls: cannot access ...: No such file or directory
```

`touch` creates a stray empty `config.h.in` and leaves `include/config.h.in`
unguarded, so the `$(AUTOHEADER)` maintainer rule on that file can still fire
on a tarball mtime. AGENTS.md names this exact trap.

**Replace line 7 with:**

```
        touch aclocal.m4 configure include/config.h.in
```

**This does not fail today's build** — attr is `[x]` and did build, because
`touch` of a missing file in an existing directory exits 0 (verified), so the
block continues past a stray zero-byte file. The guard is inert rather than
fatal; the risk is a later rebuild on a different mtime set.

### 2. `packages/attr/stage1.md` — correct the artifact list

- "no pkg-config file" is wrong: `libattr.pc` is installed to
  `$(libdir)/pkgconfig`.
- "`lib/libattr.a` (static)" is incomplete: libtool builds `libattr.a` **and**
  `libattr.so`, because the recipe passes no `--disable-shared`. Both are
  present in the built nest. The artifact list and the build record should say
  so.

### 3. Nothing else is required

`./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system —
nothing is hardcoded. `make -j1` is serial. The six WILL BUILD verdicts stand.

## Carried to the build

- `lib/libattr.a` — `llvm-objdump -f lib/libattr.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `lib/libattr.so` — `[ -f lib/libattr.so ]`, expected alongside the `.a`.
- `include/attr/xattr.h` and `include/attr/` — `[ -f include/attr/xattr.h ]`.
- `lib/pkgconfig/libattr.pc` — `pkg-config --modversion attr` → `2.5.2`. This is the check acl depends on, so it matters more here than for most packages.
- `bin/getfattr`, `bin/setfattr` — `[ -x bin/getfattr ]`. Target programs; never run them.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- Required change 1 is done and correct. `packages/attr/generic.lua:7` now
  reads `touch aclocal.m4 configure include/config.h.in`, which matches the
  tree:

  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/attr/configure.ac
  AC_CONFIG_HEADERS([include/config.h])
  $ find nest/source/attr -name 'config.h.in'
  nest/source/attr/include/config.h.in
  ```

  Position is right: `./configure` line 6, guard lines 7-8, `make -j1` line 9.
  attr is a non-recursive build with a single top-level `Makefile.in`, so the
  `find` sweep covers everything.
- The recipe is otherwise undamaged: only `$AUTOCONF_CONFIGURE_FLAGS`,
  `$PREFIX`, `$OUT`, `$NESTDIR` are used; no `export`, no `sed`, no
  `/dev/null`, no patch, `make -j1`, and `require("attr@source")` is the only
  dependency and it resolves.
- `stage1.md:6` was corrected to list `libattr.a` **and** `libattr.so` plus
  `lib/pkgconfig/libattr.pc`. Both facts check out:
  `attr/libattr/Makemodule.am:1` is `lib_LTLIBRARIES += libattr.la` under an
  unconditional `LT_INIT` (`configure.ac:38`) with no `--disable-shared`, and
  `attr/Makefile.am:16` is `pkgconf_DATA = libattr.pc` with
  `pkgconfdir = $(libdir)/pkgconfig` (`Makefile.am:14`), generated from
  `configure.ac:66`.

### Still wrong

- **`packages/attr/stage1.md:41`** — "No `.pc` file — consumers use `-lattr`
  with `-I$PREFIX/include`". Same defect as acl: the sentence required
  change 2 said was wrong is still there verbatim, and it now contradicts the
  corrected `stage1.md:6`. This is the more expensive half of the pair, because
  acl depends on attr's `.pc` (see "Carried to the build" above), so the builder
  is the person most likely to skip this check on the strength of the forecast.

 **Fix:** replace that bullet with
  `- lib/libattr.so must be present alongside the .a; lib/pkgconfig/libattr.pc — pkg-config --modversion libattr → 2.5.2`
  and drop the "No `.pc` file" sentence.

  Note while fixing it: the `.pc` is named `libattr`, not `attr`
  (`attr/libattr.pc.in:6`, `Name:\t\tlibattr`). The `pkg-config --modversion attr`
  spelling in this stage2's own "Carried to the build" section is wrong for the
  same reason `config.h.in` was — it should be `pkg-config --modversion libattr`.
  That line predates this rework and is not the adder's, but it should be
  corrected in the same pass.

### Broken by the rework

Nothing.

## Rework verification — summary

The guard is right and verified against the tree. Rejected solely for the
surviving "No `.pc` file" line at `stage1.md:41`, which required change 2
named and which now contradicts the corrected line above it.
