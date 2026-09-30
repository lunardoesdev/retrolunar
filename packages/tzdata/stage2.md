REJECT

# tzdata 2025b — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

## What the recipe gets right — and adder A's finding #8 is intact

`ZIC=zic` at `generic.lua:13` is the single most important thing in this
recipe, and the comment at lines 7-12 explains it precisely: tzdata's Makefile
compiles the zone *source* files into TZif binaries by running `zic` at install
time, and left alone it would run the `./zic` it has just built with the cross
compiler — an aarch64 binary on an x86-64 host, which is precisely the
emulation AGENTS.md forbids outright. Pointing `ZIC` at the bare name `zic`
resolves a **host** zic through `$PATH` (the emitter puts `$NATIVE_PREFIX/bin`
first) and leaves the freshly built target `zic` unexecuted.

That is the correct mechanism, the correct reasoning, and the right place for
it — a package-local workaround in the recipe, not a system change. **Preserve
it.** This is the pattern `stage1.md` should point at for the rest of the
shard.

`TOPDIR="$OUT/usr"` is also right: tzdata is FHS-shaped and installs under
`usr/share/zoneinfo`, not `$OUT/share/zoneinfo`. Passing `TOPDIR` is how the
package expresses "install here", which is the allowed use of `$OUT`.

## Required changes

### 1. `topackage.md:79` — the recorded blocker is an upstream packaging defect, and the entry should say so once, not twice

The entry already describes it in detail (the 2025b tarball omits
`tzselect.ksh` and `workman.sh` while `Makefile:848` and `:586` require them, so
`make` stops with "No rule to make target 'tzselect.ksh'"), and correctly
compares it to GRUB 2.14's missing `libgcrypt-grub/src/misc.c`. That is a good
entry and it needs no correction.

What it does need is a decision, because the recipe cannot be built as it
stands and the reason is *not* a platform wall. Two options, and the adder
should pick one and write it down:

- **Drop `tzselect` from the build** if the Makefile has a switch or target for
  it. `tzdata`'s `Makefile` historically builds `zic`, `zdump`, `tzselect` and
  `workman` separately, so `make zic install` or an explicit target list may
  avoid the missing files entirely. That is the fix worth trying first, because
  `tzselect` and `workman` are interactive front-ends that a target prefix has
  little use for.
- If no such switch exists, the package is blocked by an upstream tarball defect
  that the no-patch rule makes unrecoverable, and the backlog line is already
  correct. In that case the entry should be left alone and the package
  recorded as blocked-pending-upstream, exactly as GRUB 2.14 is.

Either way, the fix is one line in the recipe or one word in the backlog —
which is more than most blocked packages in this tree can say.

### 2. Nothing else is required

`require("tzdata@source")` names no missing package. The build body is a single
`make … install`, with no `sed`, no patch, no `/dev/null`, and no flag
hardcoded to a target. `make` is bare, which is serial by default.

## Carried to the build

Not buildable while the tarball is missing `tzselect.ksh`. After whichever fix
in change 1 is applied, on an Android target:

- `usr/share/zoneinfo/UTC`, `usr/share/zoneinfo/Europe/London`, `usr/share/zoneinfo/America/New_York` — `[ -f usr/share/zoneinfo/UTC ]`. A `zoneinfo` directory full of **text** files named like zones means `zic` never ran and the install silently shipped uncompiled sources — the single most dangerous failure mode here, so check one zone file with `head -c 4`: a TZif file starts with `TZif`, not with a zone name.
- `bin/zic` and `bin/zdump` — `[ -x bin/zic ]` and `[ -x bin/zdump ]`. Both are target binaries; **never run them**, which is the whole point of `ZIC=zic`.
- `usr/share/zoneinfo/zone.tab`, `usr/share/zoneinfo/zone1970.tab`, `usr/share/zoneinfo/iso3166.tab` — these are data files copied verbatim, and their presence confirms the data half of the install completed even if the `zic` half did not.
- `usr/share/zoneinfo/leapseconds`, `tzdata.zi` — `[ -f usr/share/zoneinfo/tzdata.zi ]`, the source-of-truth file; useful to confirm the expected zone set.
- The check that settles `ZIC=zic`: the build log must show `zic` resolved from a path **outside** `$WORK` (i.e. `$NATIVE_PREFIX/bin/zic`). A log showing `./zic` means the mitigation did not take and a target binary was about to be executed.
