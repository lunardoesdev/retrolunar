# grub build forecast

- Recipe: `generic.lua`, source `source.lua` (no platform-specific file)
- Version pinned: 2.14 (LFS pins 2.12; the recipe uses the newer stable)
- Build system: autotools (with `gentpl.py` regenerating `Makefile.util.am`)
- Installs: `bin/grub-mkimage`, `bin/grub-file`, `bin/grub-mkstandalone`, `bin/grub-mkfont`, `bin/grub-script-check`, `bin/grub-editenv`, `sbin/grub-install`, `sbin/grub-probe`, `sbin/grub-mkdevicemap`, `sbin/grub-reboot`, `sbin/grub-bblt`; `lib/grub/` (target + host modules); `share/grub/`; **no `.pc`**
- Requires: `grub@source` only

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | **WILL NOT BUILD (upstream tarball defect)** | topackage.md:36 records it exactly: "2.14 tarball omits `grub-core/lib/libgcrypt-grub/src/misc.c` and defines no `gcry` module to compile it, so the new pubkey module's `rsa-common.c` references `_gcry_log_printmpi`, which no module defines; `grub-core/Makefile:57254 moddep.lst` then fails with `_gcry_log_printmpi in pubkey is not defined`. Not fixable without patching upstream sources." The recipe's `cat > grub-core/extra_deps.lst` heredoc (`generic.lua:44-46`) is a *different* fix — the release omits `depends bli part_gpt` from that file — and does not address the missing `misc.c`. |
| aarch64-android24 | **WILL NOT BUILD (upstream tarball defect)** | Same. |
| aarch64-android35 | **WILL NOT BUILD (upstream tarball defect)** | Same. Not API-level-related. |
| x86_64-android35 | **WILL NOT BUILD (upstream tarball defect)** | Same, arch-independent. |
| x86_64-mingw | **WILL NOT BUILD** | Same defect, plus GRUB is an x86/EFI bootloader and has no mingw target in its `configure` target list. |
| clang-native | **UNCERTAIN** | The `moddep.lst` failure is a *module dependency* problem that is arch-independent, so it would occur on the host too. On the other hand the recipe's Android-specific workarounds (`TARGET_CFLAGS+=" -fno-pic"`, `TARGET_LDFLAGS+=" -fno-pie -no-pie"`) are only needed for NDK clang, so a host build takes a different path. Not settled. |

## API level notes

**The blocker is an upstream packaging defect, not an API-level one and
not a Bionic gap.** That is worth stating plainly because it means no
system directory and no cache answer helps — the tarball is missing a file
its own build system requires. The only fixes are (a) a grub release that
ships `libgcrypt-grub/src/misc.c`, or (b) `--disable-pubkey` or similar to
drop the module that needs it, if such a flag exists. **(b) is a configure
flag and therefore within the no-patch rule, and is the first thing a
reviewer should try.**

## Risks / what a reviewer should check

- **The recipe's `cat > grub-core/extra_deps.lst <<'EOF'` heredoc
  (`generic.lua:44-46`) writes into the upstream source tree.** AGENTS.md
  says "recipes must not patch upstream sources", and a strict reading
  covers this. It is a *generated* file (grub regenerates `extra_deps.lst`
  from `Makefile.util.def`) whose shipped contents are simply incomplete,
  so the intent is "restore what the tarball should have had" rather than
  "modify upstream". That is a defensible reading, but **a reviewer should
  make that call explicitly** rather than let it pass. It is the only
  heredoc in any recipe in the a–g shard, and AGENTS.md's build-body
  hygiene list does allow `cat`-heredocs, so the mechanism is sanctioned.
- **The `-fno-pic` / `-fno-pie` reasoning at `generic.lua:31-43` is
  unusually careful and correct**, and the comment explains *why it is on
  the make line rather than in `$CFLAGS`*: configure's own flex probe
  links the generated scanner, and `-fno-pic` makes that link fail with
  `R_AARCH64_LDST64_ABS_LO12_NC`. That is exactly the kind of
  recipe-local knowledge AGENTS.md wants preserved.
- **`unset CFLAGS CPPFLAGS CXXFLAGS LDFLAGS` at `generic.lua:11`** is a
  deliberate departure from "take every flag from the system", and the
  comment justifies it (upstream and LFS both require a clean environment
  for a bootloader). Correct and explained.
- **`export TARGET_OBJCOPY` etc. at `generic.lua:21-24`** with the comment
  "These must be exported: configure reads them from the environment, and
  an unexported shell variable never reaches it" — a good, specific note.
  The underlying problem (grub's `AC_CHECK_TOOL` finding host GNU binutils
  that cannot read aarch64 ELF) is also clearly stated.
- **`touch Makefile.util.am` before the `Makefile.in` sweep
  (`generic.lua:52-57`)** is a third autotools timestamp trick, and the
  comment explains the ordering requirement precisely: a regenerated
  `Makefile.in` would make make re-run automake looking for `automake-1.16`.
  Well done.
- **`make -j1` is now explicit on both lines.** RETRACTION, and it matters: **bare `make` is not a parallelism violation.** Measured empirically: `make` reports `MAKEFLAGS=[]` and `make -j1` reports `MAKEFLAGS=[-j1]` — a bare `make` is already serial. The recipe now passes `-j1` explicitly anyway, because AGENTS.md asks for a single-job build to be *explicit* rather than implicit and that is better practice; but the edit was **not** required, and an earlier version of this file called the omission a defect and named other packages for the same thing. That was wrong, and it is the same defect class as the other false premises in this wave: a rule that sounds right, is not, and trains the next reader to fail correct recipes. No further package should be failed on bare `make`.

## How to verify once built

Not verifiable while the tarball defect stands. After a fix:

- `bin/grub-mkimage`, `sbin/grub-install`, `sbin/grub-probe`
- `lib/grub/<arch>-*/` module tree
- `share/grub/grub.cfg`
- `file bin/grub-mkimage` → Android ELF on a cross target
- **Do not run any grub binary here** — these are boot-sector tools
