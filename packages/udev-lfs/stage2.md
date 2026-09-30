ACCEPT

# udev-lfs 20230818 — stage 2 review

Reviewed against AGENTS.md and the recipe. I did not build.

## What the recipe gets right

- **This is a pure-data package and the recipe is the right shape for one**:
  `mkdir -p` plus `cp`, nothing compiled, no configure, no flags, nothing
  hardcoded to a target. The installed bytes are identical on every system, so
  there is no architecture to check — and saying so in the build record is the
  correct response, not treating the absence as a gap.
- **The comment at lines 7-10 is the valuable part and it is a real catch.**
  udev-lfs ships a `Makefile.lfs`, and using it would be the obvious choice —
  but it installs from a *versioned* subdirectory
  (`udev-lfs-20230818/*.rules`), while the release tarball unpacks **flat**, so
  that path does not exist and `make -f Makefile.lfs` would fail. The recipe
  therefore hand-copies and says why. That is AGENTS.md's "smallest necessary,
  understandable set of steps" applied to a case where the obvious step is
  wrong.
- The `cp` globs are the mechanism, so their safety matters: `cp *.rules` and
  `cp *.txt` **fail the build** if the glob matches nothing. The builder should
  confirm the counts after the fact rather than assume. Nothing here is
  compiled, so this is the only way the package can fail.
- The comment "The rule generators are plain shell scripts, so install them as
  such" explains why `write_cd_rules`/`write_net_rules` go to
  `usr/share/udev/` rather than `bin/` — they are run by udev rules, not
  invoked by a user. Correct placement, and the reason is recorded.
- `require("udev-lfs@source")` names no missing package.

## Non-blocking observations

- The `cp -r $NESTDIR/source/udev-lfs/. .` at line 5 copies the whole tree into
  `$WORK` and is then unnecessary — everything used afterwards is copied by
  explicit name. It is harmless and keeps the "stage the tree in $WORK" pattern
  uniform with every other recipe, but it does mean the tree is materialised
  for nothing. Not worth changing.
- `topackage.md:78` records the artifact layout and matches the recipe
  (`lib/udev/rules.d/`, `usr/share/udev/`, `usr/share/doc/udev-20230818/`).
  One thing the entry could add: the `rules.d/network/` subdirectory is created
  (`mkdir -p`) but never populated, because the network rules are *generated* at
  boot by `write_net_rules`, not shipped. An empty directory is expected, not a
  bug.

## Carried to the build

- `lib/udev/rules.d/55-lfs.rules` — `[ -f lib/udev/rules.d/55-lfs.rules ]`. This is the one file that matters; it is what makes the LFS udev rules available.
- `usr/share/udev/write_cd_rules`, `usr/share/udev/write_net_rules` — `[ -x usr/share/udev/write_net_rules ]`. Both are executable shell scripts, and the execute bit is the check.
- `usr/share/doc/udev-20230818/` — `[ -d usr/share/doc/udev-20230818 ]`, plus the two generator scripts copied alongside the `.txt` docs.
- `lib/udev/rules.d/network/` — expected to be **empty**; it is where generated rules land at boot.
- **The count check that settles the globs:** `ls lib/udev/rules.d/*.rules | wc -l` must be **exactly 1** — `55-lfs.rules`. This package ships one rules file, so a correct install reads 1 and the earlier version of this line said "greater than 1" while treating a count of 1 as the failure mode, which is a logic inversion: it failed on a good build and would have passed on a broken one. Prefer the filename assertion on the line above as the primary check; this count is the secondary one that proves `cp *.rules` matched the whole top-level glob rather than silently copying something unexpected. A count of 0 means the glob matched nothing and the build should have stopped.
- There is no library, no header, no `.pc` and **no architecture to check** — say so in the build record rather than hunting for an artifact.
