REJECT

# groff 1.24.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/groff/`. I did not build.

The recipe is a deliberate record of a known wall, and the forecast treats it
as one. Two defects, one of them a hard rule.

## Required changes

### 1. `packages/groff/generic.lua:24` — `make` without `-j1` violates the serial-build rule

```
        make
```

AGENTS.md: *"Build serially: use `make -j1` or the build tool's equivalent
single-job option."* **Replace line 24 with:**

```
        make -j1
```

`make install` on line 25 is an install target, not a compile, so it stays.

### 2. `packages/groff/generic.lua:22` — the guard names a file groff does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/groff/configure.ac
AC_CONFIG_HEADERS([src/include/config.h:src/include/config.hin])
$ find nest/source/groff -maxdepth 3 \( -name 'config.h.in' -o -name 'config.hin' \)
nest/source/groff/src/include/config.hin
$ ls nest/source/groff/config.h.in
ls: cannot access ...: No such file or directory
```

`config.hin`, two directories deep. `touch` creates a stray empty `config.h.in`
and leaves the real template unguarded.

**Replace line 22 with:**

```
        touch aclocal.m4 configure src/include/config.hin
```

**This does not fail today's build** — `touch` of a missing file in an existing
directory exits 0 (verified under the emitted `set -eu`; only a missing
*directory* aborts). The guard is inert rather than fatal.

### 3. Nothing else is required, and the wall is correctly recorded

`generic.lua:3-9` documents the real blocker precisely: groff renders its own
manual and example documents with the groff it has just built
(`Makefile.am:497`, `GROFFBIN = $(abs_top_builddir)/groff`), and `make
install` wants those rendered files. Executing that binary on the build host
is forbidden by AGENTS.md's no-emulation rule, so **no cross target can build
this package**, and the recipe is right to say so rather than pretend
otherwise. `PAGE=letter` is a groff build variable, not a toolchain flag, and
the comment says so. `touch doc/gnu.eps` before the guard is correct and
explained — it stops make regenerating the shipped EPS with netpbm tools that
are not in the prefix.

`topackage.md`'s groff line already records the `doc/doc.am:392`
`webpage.ps` wall; that stays.

## Carried to the build

Not buildable on any cross target today. On `clang-native`, where the built
`troff` *is* executable on the build host:

- `bin/groff`, `bin/troff`, `bin/gprepro` — `llvm-objdump -f bin/groff | head -3`; on `clang-native` the artifact is host x86_64 ELF.
- `share/man/man1/groff.1` — `[ -s share/man/man1/groff.1 ]`.
- `info/groff.info` — `[ -s info/groff.info ]`.
- `doc/gnu.eps` — `[ -f doc/gnu.eps ]` under `$OUT` if installed; its presence confirms the `touch doc/gnu.eps` guard worked and netpbm was not needed.
- No library and no `.pc`; groff is programs plus data.
