REJECT

# flex 2.6.4 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/flex/`. I did not build.

## Required changes

### 1. `packages/flex/generic.lua:10` — the guard names a file flex does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADER nest/source/flex/configure.ac
AC_CONFIG_HEADER([src/config.h])
$ find nest/source/flex -maxdepth 2 -name 'config.h.in'
nest/source/flex/src/config.h.in
$ ls nest/source/flex/config.h.in
ls: cannot access ...: No such file or directory
```

`touch` creates a stray empty `config.h.in` and leaves `src/config.h.in` — the
template autoheader watches — unguarded.

**Replace line 10 with:**

```
        touch aclocal.m4 configure src/config.h.in
```

**This does not fail today's build** — `touch` of a missing file in an existing
directory exits 0 (verified under the emitted `set -eu`; only a missing
*directory* aborts). The guard is inert rather than fatal.

### 2. `packages/flex/generic.lua:9` — `--disable-static` is a latent mistake

```
        ./configure $AUTOCONF_CONFIGURE_FLAGS --disable-static --disable-bootstrap
```

`--disable-bootstrap` is **correct and important** — without it flex runs a
previously built `flex` to regenerate its own scanner, which on a cross build
means executing a target binary, and the release ships the generated `scan.c`.
Keep it and keep the comment.

`--disable-static` is the other half of the line and deserves a second look.
Every other package in this prefix is `--enable-static --disable-shared`. A
build tool that installs a *shared* `libfl` needs a loader path a target has no
use for. The recipe is not wrong — flex is a program, and the library is
incidental — but the choice is undocumented and, per `stage1.md:37-42`,
probably not intended. Either drop the flag so flex's own default applies, or
keep it and say why in the comment. My recommendation is to drop it and let
`libfl` be static, for the same reason `freetype` needs
`-Ddefault_library=static` (see `packages/freetype/stage2.md`).

### 3. Nothing else is required

`require("m4")` is a real dependency and `packages/m4` exists, though with
`--disable-bootstrap` m4 is only needed at install time, not for the
generation step. `make -j1` is serial. The recorded blocker — configure's
inability to *run* its realloc probe while cross-compiling, which no API level
fixes — is correctly identified by `stage1.md:20-28`, and that is a
distinction the backlog line does not make.

One dependency fact worth putting in the backlog: **`flex@native` is what
`packages/libnl-3` depends on**, so this blocker does not propagate to
libnl-3 — but only for as long as `flex@clang-native` builds.
`stage1.md:43-48` is right to single that out; it belongs in `topackage.md`
too.

## Carried to the build

Not buildable on any cross target today. On `clang-native`, where configure can
run its probes:

- `bin/flex`, `bin/lex` — `llvm-objdump -f bin/flex | head -3`; on `clang-native` the artifact is host x86_64 ELF.
- `include/FlexLexer.h` — `[ -f include/FlexLexer.h ]`.
- `share/man/man1/flex.1` — `[ -s share/man/man1/flex.1 ]`.
- `lib/libfl.a` **or** `lib/libfl.so` — whichever appears is the direct evidence for change 2. A `.so` here means `--disable-static` is still in effect and should be questioned.
- **Never run `bin/flex`.**

---

## Rework verification

**Verdict: REJECT.** The recipe itself is now correct and the guard is
fixed. What is not fixed is `stage1.md`: it still tells the builder to
look for evidence of a flag that is no longer in the recipe, so the
"documented why" required change is only half done — the rationale landed
at `:37-42` and the stale counter-check survived at `:61-62`.

### Required change 1 — the guard: done, and correct

`generic.lua:12` is now `touch aclocal.m4 configure src/config.h.in`. That
is the right file:

```
$ grep -n "AC_CONFIG_HEADER" nest/source/flex/configure.ac
32:AC_CONFIG_HEADER([src/config.h])
$ find nest/source/flex -name 'config.h.in'
nest/source/flex/src/config.h.in
$ ls nest/source/flex/config.h.in
ls: cannot access 'config.h.in': No such file or directory
```

(flex uses the old singular `AC_CONFIG_HEADER` spelling, which is why a
plain `grep AC_CONFIG_HEADERS` finds nothing — worth knowing, since the
plural form is what most recipes use.) The guard is positioned after
`./configure` (`:11`) and before `make` (`:14`), and
`find . -name 'Makefile.in' | xargs touch` (`:13`) covers all eight
`Makefile.in` files including `src/`, `doc/`, `tools/`, `tests/` and the
three under `examples/`.

One caveat worth recording, not a defect: `configure.ac:172-182` lists
`po/Makefile.in` in `AC_CONFIG_FILES`, but the tree ships
`po/Makefile.in.in` and gettext's `config.status` generates
`po/Makefile.in` from it. `find . -name 'Makefile.in'` will not match
`po/Makefile.in.in` — correct, since the generated `po/Makefile.in` is
produced by `config.status` at `./configure` time, which is *before* the
guard runs, and is therefore already newer than its input.

### Required change 2 — `--disable-static` is gone, and the recipe is right

`generic.lua:11` now reads:

```
        ./configure $AUTOCONF_CONFIGURE_FLAGS --enable-static --disable-shared --with-pic --disable-bootstrap
```

`--disable-static` is gone and replaced with the prefix-wide
`--enable-static --disable-shared --with-pic`. `--disable-bootstrap` is
kept, which is correct and important: `configure.ac:78-82` makes
`ENABLE_BOOTSTRAP` default to yes, and `src/Makefile.am:98-100` then runs
`./stage1flex$(EXEEXT)` — a *previous build of flex itself* — to regenerate
`stage1scan.c`. On a cross build that means executing a target binary,
which the repo forbids outright. Skipping the bootstrap is necessary, and
the release does ship the generated `scan.c`.

I confirmed `libfl` is a real shared-capable library, so the flag change
is not cosmetic: `src/Makefile.am:13` has `lib_LTLIBRARIES = libfl.la`
with `libfl_la_LDFLAGS = -version-info @SHARED_VERSION_INFO@`
(`src/Makefile.am:18`). Under libtool that would build `lib/libfl.so`
unless static is forced.

### STILL WRONG — `stage1.md:61-62` still hunts for the removed flag

```
61:- `lib/` — check whether a `libfl.so` appeared; its presence would confirm
62:  `--disable-static` is in effect and would be worth questioning
```

This is the reason for the REJECT. `--disable-static` is no longer in the
recipe, so it cannot be "in effect", and the check is now
self-contradictory: under the current flags a `libfl.so` appearing would
mean `--disable-shared` *failed*, not that a forbidden flag was passed. The
verification checklist should say what is actually true:
`lib/libfl.a` present, `lib/libfl.so` **absent**. As written, a builder
reading `:61-62` has no way to tell which of two opposite conclusions to
draw, and the file contradicts its own `:37-42`.

Related, smaller, in the same file: `stage1.md:15` and `stage1.md:32` both
cite `--disable-bootstrap` as being at `generic.lua:9`. It is at
`generic.lua:11`; the three-line comment pushed it down. Cite
`generic.lua:11`, or better, drop the line-number citations from prose
that will drift again.

### Required change 3 — nothing else required, and nothing damaged

`require("m4")` resolves to a real `packages/m4`. Note `m4` is genuinely
still needed even with `--disable-bootstrap`: `src/Makefile.am:5` sets
`m4 = @M4@` and `:94-95` runs `mkskel.sh` with it to generate `skel.c`,
which is unconditional. So the `stage1.md:49-51` claim that m4 is "only
needed at install time" is **wrong** — it is needed during `make`, to
generate a real compiled source file. The dependency is correctly declared
in the recipe; only the explanation is off. Fix `:50` to say `skel.c` is
generated from `flex.skl` by `mkskel.sh` *using m4* during the build, so
m4 is a build-time requirement, not an install-time one.

`make -j1` / `make -j1 install` are serial. No `export`, no hardcoded
target facts, no `sed`/patch/`/dev/null`. No `android.lua`.

### The recorded blocker is untouched and still correctly described

`stage1.md:11-16` and `:20-28` are unchanged by this rework and remain
right: the cross failure is autoconf being unable to *run* its `realloc`
probe, which no API level fixes. `stage1.md:43-48`'s observation that
`flex@native` is what `packages/libnl-3` depends on, so the blocker does
not propagate, is the most useful thing in the file and is preserved.
`stage1.md:27-28` still honestly flags that the `ac_cv_func_realloc`-shaped
cache-variable claim was not verified — correct, and I did not verify it
either.
