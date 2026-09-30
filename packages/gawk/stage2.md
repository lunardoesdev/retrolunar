ACCEPT

# gawk 5.3.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gawk/`. I did not build.

## Required changes

### 1. `packages/gawk/generic.lua:7` — the guard names a file gawk does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gawk/configure.ac
AC_CONFIG_HEADERS([config.h:configh.in])
$ ls nest/source/gawk/config.h.in nest/source/gawk/configh.in 2>&1
ls: cannot access .../config.h.in: No such file or directory
nest/source/gawk/configh.in
```

`configh.in` — no `.h` before `.in`, the template in the same family as
`config.hin`. `touch` creates a stray empty `config.h.in` and leaves the real
template unguarded.

**Replace line 7 with:**

```
        touch aclocal.m4 configure configh.in
```

**This does not fail today's build** — `touch` of a missing file in an existing
directory exits 0 (verified under the emitted `set -eu`; only a missing
*directory* aborts). The guard is inert rather than fatal.

### 2. Nothing else is required

`make -j1` / `make -j1 install` are serial and correct.
`./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system, and
the recipe passing **no** flags is the right answer here: no configure switch
can work around a missing libc symbol, and the only fixes are a higher API
level (available: `aarch64-android35` exists) or a patch (forbidden). The
absence of an `android.lua` is therefore the finding, and `stage1.md:31-35`
says so correctly.

The `nl_langinfo` blocker is genuine and API-level: Bionic declares it behind
`__INTRODUCED_IN(26)`, the same root cause as `less` and `pkgconf`. The
backlog line already says this; it should also record that the same gate
blocks those two, so the three are fixed or not together.

`stage1.md:44` cites `generic.lua:13` for `make -j1 install`; the recipe is 11
lines and the install is line 10. Cosmetic citation drift.

## Carried to the build

Buildable on `aarch64-android35`, `x86_64-android35` and `clang-native` only.

- `bin/gawk` — `llvm-objdump -f bin/gawk | head -3` → `elf64-littleaarch64`; `llvm-objdump -p` should name Android 35, which is the whole story for this package.
- `bin/awk` and `bin/nawk` — `[ -x bin/awk ] && [ -x bin/nawk ]`; both are links to gawk.
- `info/gawk.info` — `[ -s info/gawk.info ]`. gawk ships a pre-built `.info`; if it is small, `makeinfo` was invoked.
- No installed library and no `.pc` — `libgawk.a` is a convenience archive for gawk's own tests, built and discarded. Do not expect it under `$OUT/lib`.
- **Never run `bin/gawk`.**

## Rework verification

**ACCEPT** — first line changed from `REJECT` to `ACCEPT`.

### Correctly fixed

`packages/gawk/generic.lua:7` is now `touch aclocal.m4 configure configh.in`.
Verified against the tree, not the new comment:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gawk/configure.ac
AC_CONFIG_HEADERS([config.h:configh.in])
$ ls nest/source/gawk/configh.in nest/source/gawk/config.h.in
configh.in exists;  ls: cannot access 'config.h.in': No such file or directory
```

The stray-`config.h.in` creation is gone and the real template is now the one
being timestamped. The guard sits at line 7, after `./configure` (line 6) and
before `make -j1` (line 9). Line 8's `find . -name 'Makefile.in' | xargs touch`
is unchanged and correct. Nothing else in the recipe moved: still
`./configure $AUTOCONF_CONFIGURE_FLAGS` with no hardcoded flags, no `export`,
`make -j1` / `make -j1 install`, `require("gawk@source")` names a package that
exists, and no `android.lua` — which this file's §2 correctly endorses.

### The `nl_langinfo` claim — stated precisely, and it does not over-block

`stage1.md` makes it an API-level statement, not a standing block:

- `stage1.md:11` aarch64-android21 **WILL NOT BUILD**, `stage1.md:12`
  aarch64-android24 **WILL NOT BUILD** — both with the API-26 reason.
- `stage1.md:13` aarch64-android35 **WILL BUILD** and `stage1.md:14`
  x86_64-android35 **WILL BUILD** — explicitly "The recipe is unchanged for this
  row and should need no new flags."
- `stage1.md:20-27` names it "a genuine API-level blocker", says the fixes are
  "raising the target API or patching the call site", and closes "gawk builds
  on the API-35 systems and on the host, and is blocked on every lower Android
  system."

Nothing in `stage1.md` implies android35 is blocked. `topackage.md:27` itself
is unqualified ("blocked: needs nl_langinfo, Bionic exposes it at API 26"), so
`stage1.md` is *more* precise than the backlog line it is correcting.

I could not re-derive `__INTRODUCED_IN(26)` first-hand — there is no NDK
sysroot in this environment (`/opt/android*` and `~/Android` do not exist;
the only `langinfo.h` on the box is glibc's `/usr/include/langinfo.h`). The
claim therefore rests on `topackage.md:45`, which records the same symbol for
`less` with the declaration site (`langinfo.h:97`). I am not calling it wrong;
I am recording that it is inherited, not independently re-verified.

### New finding the original review missed — gawk is a TWO-TEMPLATE package

This is the thing worth carrying forward, and it is the same shape as the
gperf finding in this wave:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gawk/extension/configure.ac
AC_CONFIG_HEADERS([config.h:configh.in])
$ grep -n AC_CONFIG_SUBDIRS nest/source/gawk/configure.ac
494:	AC_CONFIG_SUBDIRS(extension)
$ ls nest/source/gawk/extension/{configh.in,aclocal.m4,configure,Makefile.in}
all four present
```

`extension/` is a real sub-configure that the top-level `./configure` recurses
into, and it ships its own `configh.in`. The recipe touches the top-level
`configh.in`, `aclocal.m4` and `configure` explicitly by name at line 7, while
line 8's `find` sweep *already reaches* `extension/Makefile.in`. So the
author was thinking about the subdirectory, and the subdirectory's autoheader
target is the one file left unguarded — the live re-run AGENTS.md:248-252
describes.

Not charged against the adder: §1 of "Required changes" prescribed exactly
`touch aclocal.m4 configure configh.in` and that is exactly what was executed;
§2's "Nothing else is required" was wrong, not ignored. The gap is in
AGENTS.md:241, which lists gawk under the single-template spellings as
"`configh.in` — gawk" when the tree has two. AGENTS.md's list should read
"two files — c-ares, gperf, **gawk** (`configh.in` and `extension/configh.in`)"
alongside the existing gperf bullet.

Hardening, if the batch wants it:

```
        find . -name 'configh.in' -o -name 'configure' -o -name 'aclocal.m4' | xargs touch
        find . -name 'Makefile.in' | xargs touch
```

### Unchanged, still cosmetic

`stage1.md:44` cites `generic.lua:13` for `make -j1 install`; the recipe is 11
lines and the install is line 10. This file already recorded the drift in §2.
`stage1.md` is out of scope for me to edit.
