REJECT

# sed 4.9 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/sed/`. I did not build.

## Required changes

### 1. `packages/sed/generic.lua:7` — the guard names a config template sed does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/sed/configure.ac
AC_CONFIG_HEADERS([config.h:config.h:config_h.in])
```

I re-ran this to be certain of the spelling, because it is unlike anything else
in the tree — **an underscore, not a dot**: the template is `config_h.in`, and
there is no `config.h.in` anywhere in the tree. So the `touch` creates a stray
empty `config.h.in` and leaves the real template un-refreshed, which is exactly
the failure the guard exists to prevent.

**Replace line 7 with:**

```
        touch aclocal.m4 configure config_h.in
```

**This does not break the build**, and the builder should know that before
treating this as a blocker: `touch` of a missing *file* in an existing
directory creates it and exits 0, even under the emitted `set -eu`
(`src/loader.lua:313`); only a missing *directory* aborts. I verified both
halves. The defect is that the guard is **inert** — `config_h.in` is the file
whose staleness re-triggers `autoheader` through the `missing` wrapper, and
nothing refreshes it.

`readline`, `sysklogd`, `texinfo`, `util-linux` and `xz` in this same shard get
the guard right; `sed` is the one that does not, and it is a one-word fix.

### 2. Nothing else is required

- `./configure $AUTOCONF_CONFIGURE_FLAGS` takes every flag from the system, so
  install lands in `$OUT`. sed needs no feature switches — it is a single
  program with no optional library — so passing none is correct, and nothing is
  hardcoded to a target.
- `make` and `make install` at lines 9-10 are bare. **Not a defect**: bare
  `make` is serial by default, which I verified empirically (`MAKEFLAGS` is
  empty without `-j`). Adder A's finding #7 is correct on this and I am
  explicitly not failing the package for it.
- `require("sed@source")` names no missing package.

## One thing the forecast should add

sed builds `bin/sed` and nothing else that matters, but it also installs
`share/man/man1/sed.1` and `info/sed.info`. The `.info` file is a build
product: sed's `Makefile.in` generates it with its own just-built `makeinfo`
in some versions, and ships a pre-built one in others. If `stage1.md` does not
say which, the builder should check for an empty `info/sed.info` after the
build — that is the signature of a help2man/`makeinfo` regeneration attempt on
a host that lacks the tool.

## Carried to the build

- `bin/sed` — `llvm-objdump -f bin/sed | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw), and `llvm-objdump -p` should name the Android API level.
- `share/man/man1/sed.1` — `[ -s share/man/man1/sed.1 ]`. Use **`-s`**: a zero-byte man page is the signature of a failed help2man regeneration.
- `info/sed.info` — `[ -s info/sed.info ]`, same `-s` reasoning.
- No library, no headers, no `.pc`; sed is one program.
- **Never run `bin/sed`.**
