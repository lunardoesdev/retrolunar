REJECT

# GRUB 2.14 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/grub/`. I did not build.

**This is the most carefully reasoned recipe in the shard, and the forecast
respects it.** Two defects remain, one of them a hard rule.

## Required changes

### 1. `packages/grub/generic.lua:52` — `make` without `-j1` violates the serial-build rule

```
        make TARGET_CFLAGS+=" -fno-pic" TARGET_LDFLAGS+=" -fno-pie -no-pie"
```

AGENTS.md: *"Build serially: use `make -j1` or the build tool's equivalent
single-job option."* **Replace line 52 with:**

```
        make -j1 TARGET_CFLAGS+=" -fno-pic" TARGET_LDFLAGS+=" -fno-pie -no-pie"
```

`make install` on line 53 is an install target, not a compile, so it stays.
Note that GRUB's build recurses through a large generated module tree, so the
serial rule matters more here than the line count suggests.

### 2. `packages/grub/generic.lua:43` — the guard names a template grub does not use

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/grub/configure.ac
AC_CONFIG_HEADERS([config-util.h])
$ find nest/source/grub -maxdepth 2 \( -name 'config.h.in' -o -name 'config-util.h.in' \)
nest/source/grub/config.h.in
nest/source/grub/config-util.h.in
```

grub configures `config-util.h`, not `config.h`, so the template autoheader
watches is `config-util.h.in`. `config.h.in` does exist, so `touch` succeeds
here — this is the one case in the shard where the guard does not create a
stray file, but it is still guarding the wrong one.

**Replace line 43 with:**

```
        touch aclocal.m4 configure config-util.h.in
```

### 3. Nothing else is required, and the four workarounds are all correctly placed

Worth stating plainly, because each looks like a rule violation and is not:

- `unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS` (line 9) is a *removal*, not an
  `export`, and it is what upstream and LFS both require for a bootloader. The
  comment says exactly that. Keep it.
- `export TARGET_OBJCOPY/NM/STRIP/RANLIB="$OBJCOPY/..."` (lines 18-21) exports
  **tool names**, not search flags, each taken from the system's `$OBJCOPY`,
  `$NM`, `$STRIP`, `$RANLIB`. The comment explains why they must be exported
  (configure reads the environment) and why the host binutils cannot be used
  on a target ELF. Correct, and this is the `AC_CHECK_TOOL` problem the
  backlog line for grub does not mention at all.
- `TARGET_CFLAGS+=` on the **make** line rather than in `$CFLAGS` at configure
  time is deliberate and the comment proves it was thought through: configure's
  own flex probe links the generated scanner, and `-fno-pic` breaks that link
  with `R_AARCH64_LDST64_ABS_LO12_NC`. Putting it in the environment would
  break configure. That is a genuinely good catch by the author.
- The `cat > grub-core/extra_deps.lst <<'EOF'` heredoc is in AGENTS.md's
  allowed build-body list and the comment records why the release omits the
  `bli`/`part_gpt` entries.

`touch Makefile.util.am` before the `find . -name 'Makefile.in' | xargs touch`
sweep is also correct and well explained: it makes `Makefile.in` the newer of
the two so the `automake-1.16` re-run never triggers. This is the best
timestamp-guard work in the shard — which makes the `config.h.in` slip on line
43 more of a shame.

The recorded blocker (the 2.14 tarball omits
`grub-core/lib/libgcrypt-grub.*`) stands, and this recipe is a good model for
how to record one.

## Carried to the build

Not buildable today. After the tarball blocker is resolved, on an Android
target:

- `bin/i386-pc-binutils/*` or the `tooldir` output — GRUB installs a
  `grub-mkimage`-style tree plus the `grub-probe`/`grub-editenv` host-side
  scripts. Check the actual layout: `ls $OUT/bin` and `ls $OUT/lib/grub`.
- `lib/grub/*-info` modules and `include/grub/` — `[ -d include/grub ]`.
- `share/grub/` — `[ -d share/grub ]`.
- A bootloader is a target binary: **never run anything it installs.**
- The check that matters for the two workarounds: `llvm-objdump -f` on any
  installed module must show `elf64-littleaarch64`, and
  `llvm-objdump -h` must show no `.rela.dyn` — that is what `-fno-pic
  -fno-pie` is for, and its absence would mean the flags did not take.
