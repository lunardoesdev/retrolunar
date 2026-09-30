ACCEPT

# GDBM 1.26 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gdbm/`. I did not build.

## Required changes

### 1. `packages/gdbm/generic.lua:9` — the guard names a file gdbm does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gdbm/configure.ac
AC_CONFIG_HEADERS([autoconf.h])
$ find nest/source/gdbm -maxdepth 2 \( -name 'config.h.in' -o -name 'autoconf.h.in' \)
nest/source/gdbm/autoconf.h.in
nest/source/gdbm/src/gdbm.h.in
$ ls nest/source/gdbm/config.h.in
ls: cannot access ...: No such file or directory
```

gdbm's configured header is `autoconf.h`, so the template autoheader watches
is `autoconf.h.in`. `touch` creates a stray empty `config.h.in` and leaves the
real one unguarded.

**Replace line 9 with:**

```
        touch aclocal.m4 configure autoconf.h.in
```

**This does not fail today's build** — gdbm is `[x]` and did build, because
`touch` of a missing file in an existing directory exits 0 (verified under the
emitted `set -eu`; only a missing *directory* aborts). The guard is inert
rather than fatal.

### 2. Nothing else is required

`make -j1` is serial. `./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag
from the system. `require("gdbm@source")` names no missing package. The six
WILL BUILD verdicts stand.

If `stage1.md` lists a `.pc` file, check it against the tarball: gdbm 1.26's
`configure.ac` has no `AC_CONFIG_FILES` for a `.pc` and its `Makefile.in`
installs `gdbm.h` and the archives. A missing `pkg-config --modversion gdbm`
would be correct, not a defect.

## Carried to the build

- `lib/libgdbm.so` — `llvm-objdump -f lib/libgdbm.so | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw), `Type: DYN`. **A `.so`, not a `.a`**: `generic.lua:9` passes `--disable-static`, so a static archive means the flag did not take. This line previously said `lib/libgdbm.a`, which contradicted this review's own `--disable-static` finding and `stage1.md:6`; the builder would have reported a phantom defect.
- `include/gdbm.h` — `[ -f include/gdbm.h ]`. gdbm also ships `gdbm-ndbm.h` and `gdbm-ndbm-compat.h`; check all three.
- `bin/gdbmtool` — `[ -x bin/gdbmtool ]` if it is installed; it is a target program, so never run it.
- No `.pc` unless the tarball proves otherwise.

## Rework verification

**ACCEPT** — first line changed from `REJECT` to `ACCEPT`.

### Correctly fixed

`packages/gdbm/generic.lua:9` is now `touch aclocal.m4 configure autoconf.h.in`.
Verified against the tree, not the new state of the comment:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gdbm/configure.ac
AC_CONFIG_HEADERS([autoconf.h])
$ ls nest/source/gdbm/autoconf.h.in nest/source/gdbm/config.h.in
autoconf.h.in exists;  ls: cannot access 'config.h.in': No such file or directory
```

The guard is at line 9, after `./configure` (lines 6-8) and before `make -j1`
(line 11), and line 10's `find . -name 'Makefile.in' | xargs touch` is
unchanged. `--disable-static` and `--enable-libgdbm-compat` are intact on
lines 7-8, the flags still come from `$AUTOCONF_CONFIGURE_FLAGS` on line 6,
there is no `export`, `make -j1` is present on both the build and install
lines, and `require("gdbm@source")` names a package that exists. No
`android.lua`, and this file's §2 did not ask for one. gdbm's
`src/gdbm.h.in` is a `nodist` BUILT_SOURCES input, not an
`AC_CONFIG_HEADERS` template, so it is correctly not in the touch list.

### The same claim shape as gawk — checked, and it holds

gawk's shape is "blocked on 21/24 by an API-26 symbol, builds at 35". gdbm has
no blocker, so the failure mode to look for is the mirror image: a forecast
that invents an API gate. `stage1.md:11-16` records six WILL BUILD rows with
"Nothing needs an API above 21", and `stage1.md:20-24` says so again as "21 is
the floor and gdbm clears it". I checked that against the sources rather than
taking it:

```
$ grep -rn 'nl_langinfo\|getgrent\|scandir\|argp_parse\|iconv_open\|__USE_GNU' \
      nest/source/gdbm/src/ nest/source/gdbm/compat/ nest/source/gdbm/tools/
(no matches)
```

Zero hits for the symbols that block gawk, `less`, `pkgconf` and gettext
elsewhere in this shard. `topackage.md:29` is `[x]` with no blocker note,
consistent. So there is no API-level statement here to qualify and nothing in
`stage1.md` over-blocks or under-blocks.

### The `.pc` check from §2 — done

"If `stage1.md` lists a `.pc` file, check it against the tarball":

```
$ find nest/source/gdbm -name '*.pc*'
(nothing)
$ grep -n AC_CONFIG_FILES nest/source/gdbm/configure.ac
223, 224, 260 — tests/Makefile, po/Makefile.in, tests/dejagnu/Makefile, Makefile; no .pc
```

`stage1.md:6`'s "**no pkg-config file**" is correct. A missing
`pkg-config --modversion gdbm` afterwards would be correct, not a defect.

### Defect in this file, not in the recipe

`stage2.md:56` tells the build to look for **`lib/libgdbm.a`**. That
contradicts `stage1.md:6`, this file's own `--disable-static` finding, and the
recipe's line 7. The build should expect a **`.so`**; a `.a` would mean
`--disable-static` did not take. Line 57's `include/gdbm.h` check is fine, but
it names `gdbm-ndbm.h` and `gdbm-ndbm-compat.h` while `stage1.md:6` names
`gdbm-compat.h` — worth settling at build time from the tarball, since the
compat layer's header name is the one that actually differs between releases.
