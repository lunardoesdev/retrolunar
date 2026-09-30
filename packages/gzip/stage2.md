REJECT

# gzip 1.15 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gzip/`. I did not build.

## Required changes

### 1. `packages/gzip/generic.lua:9` — `make` without `-j1` violates the serial-build rule

```
        make
```

AGENTS.md: *"Build serially: use `make -j1` or the build tool's equivalent
single-job option."* Replace line 9 with:

```
        make -j1
```

`make install` on line 10 is an install target, not a compile, so it stays as
it is.

### 2. `packages/gzip/generic.lua:7` — the guard names a file gzip does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gzip/configure.ac
AC_CONFIG_HEADERS([lib/config.h:lib/config.hin])
$ find nest/source/gzip -maxdepth 2 \( -name 'config.h.in' -o -name 'config.hin' \)
nest/source/gzip/lib/config.hin
$ ls nest/source/gzip/config.h.in
ls: cannot access ...: No such file or directory
```

The `config.hin` trap again, in a subdirectory this time. `touch` creates a
stray empty `config.h.in` and leaves `lib/config.hin` unguarded.

**Replace line 7 with:**

```
        touch aclocal.m4 configure lib/config.hin
```

**This does not fail today's build** — gzip is `[x]` and did build, because
`touch` of a missing file in an existing directory exits 0 (verified under the
emitted `set -eu`; only a missing *directory* aborts). The guard is inert
rather than fatal. Same family as `coreutils`, `grep`, `diffutils` and `gawk`.

### 3. Nothing else is required

`./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system.
`require("gzip@source")` names no missing package. The six WILL BUILD
verdicts stand.

## Carried to the build

- `bin/gzip` — `llvm-objdump -f bin/gzip | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `bin/gunzip`, `bin/zcat` — `[ -x bin/gunzip ] && [ -x bin/zcat ]`.
- `info/gzip.info` — `[ -s info/gzip.info ]`.
- `share/man/man1/gzip.1` — `[ -s share/man/man1/gzip.1 ]`.
- No library and no `.pc`; gzip is a program. **Never run `bin/gzip`.**
