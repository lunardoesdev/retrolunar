ACCEPT

# sysvinit 2.97 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **No `./configure`, therefore no timestamp guard — and none is present,
  which is correct.** sysvinit ships a hand-written `Makefile`, not autotools.
  The recipe is the cleanest expression of AGENTS.md's hand-written-build-file
  rule: nothing but a build and an install.
- `make install ROOT="$OUT" usrdir=` is the right way to drive a hand-written
  makefile's install. `ROOT` is the install target (allowed to be `$OUT`), and
  `usrdir=` is set empty deliberately so that programs land in `$OUT/bin`
  rather than `$OUT/usr/bin` — sysvinit's Makefile otherwise defaults to an
  FHS layout, and this prefix is not FHS. Neither is a hardcoded target fact;
  both are package-local install choices.
- The build body contains no `sed`, no patch, no `/dev/null`, no `export` of
  `CPPFLAGS`/`LDFLAGS`/`CFLAGS`, and no architecture, triplet or API level.
- `make` is bare, which **is serial by default** — verified empirically
  (`MAKEFLAGS` is empty without `-j`). Adder A's finding #7 is right and I am
  explicitly not failing it on that.
- `require("sysvinit@source")` names no missing package.

## Two things the forecast must settle, because they decide whether this builds

sysvinit's hand-written `Makefile` is old-school and does *not* respect every
convention a modern cross build needs. The two that decide this build:

1. **Does it honour `$CC` and `$CFLAGS` from the environment, or does it set
   its own `CC = cc`?** If the Makefile hardcodes `CC = cc`, the recipe compiles
   with the *host* compiler and produces x86-64 objects labelled as target —
   a silent, catastrophic failure that no artifact check would catch except
   `llvm-objdump -f`. `stage1.md` must read the Makefile and say which it is.
   If it hardcodes, the recipe needs `CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"`
   on the make line, exactly as `xml-parser` does for its own hand-written
   Makefile in this same shard.

2. **Does the install reference absolute `/sbin` or `/etc` paths?** An old
   `Makefile` often hardcodes `SBINDIR = /sbin` or writes `/etc/inittab`
   directly. `ROOT="$OUT"` only redirects the copies it honours, so the build
   may "succeed" while writing nothing, or writing outside `$OUT`. The
   builder's check is that `$OUT` actually contains what `stage1.md` promises.

Neither is a defect I can assert without reading the Makefile, and I am not
permitted to configure or build. Both are the specific things `stage1.md` should
have answered, and if it has not, that is the forecast's gap — not a reason to
reject a recipe that is correct as far as it goes.

## Carried to the build

- `sbin/init`, `sbin/getty`, `sbin/sulogin`, `sbin/agetty` (or `bin/` if `usrdir=` took effect — record which) — `[ -x sbin/init ]`. Note `sbin/init` is a symlink to `sbin/sid` on most releases; check both.
- `bin/mount`, `bin/umount`, `bin/fsck`, `bin/mkfs*`, `bin/df` — `[ -x bin/df ]`. sysvinit ships its own coreutils-alikes, and these **collide with `packages/coreutils` and `packages/util-linux`** on `mount`, `umount`, `fsck` and the `mkfs` family. Whoever installs last wins. That is a real prefix-wide hazard and belongs in the backlog next to coreutils' `--enable-no-install-program` note.
- `etc/inittab`, `etc/inittab.d/*` — `[ -f etc/inittab ]`. If the Makefile wrote to the real `/etc` instead of `$OUT/etc`, this will be missing; check that nothing landed outside the nest with `ls -la /etc/inittab` timestamp.
- `share/` — sysvinit ships a few sample files; record what appears.
- **The check that catches finding 1 above:** `llvm-objdump -f` on every
  installed binary must show the *target* machine (`elf64-littleaarch64` on
  Android, `pei-x86-64` on mingw). Host x86-64 ELF here means the Makefile
  ignored `$CC` and the build is wrong despite exiting 0.
- **Never run any installed sysvinit binary** — `init`, `shutdown`, `halt` and
  `poweroff` would act on the build host.
