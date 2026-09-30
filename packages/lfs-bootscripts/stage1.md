# lfs-bootscripts build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 20250827 (linuxfromscratch.org, LFS 12.4's boot scripts)
- Build system: none. Pure data.
- Installs: the LFS init scripts and the `rc.symlinks` table, staged verbatim
  under `$OUT/etc/`. Nothing is compiled; there is no library, header or `.pc`.
- Requires: `lfs-bootscripts@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `generic.lua:6-7` is a `mkdir` and one recursive `cp`. No compiler, no configure, no sysroot. |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. |
| x86_64-mingw | WILL BUILD | As above; the data is shell scripts and a symlink table, architecture-independent. |
| clang-native | WILL BUILD | As above. |

**Nothing is compiled**, so the install is identical on every system and there
is no architecture check to make. The recipe says so at `generic.lua:4`.

**API level notes.** None. `armv7a-android*` and `i686-android*` match
`aarch64-android*` — the recipe has no step that could observe a level, and
the payload is shell scripts that are never executed by the build.

**Risks / what a reviewer should check.**

1. **This is the third pure-data package in the shard, and all three pick a
   different install path.** `iana-etc` puts its two files in `etc/`,
   `man-pages` puts its tree in `share/man/`, and this one copies the *whole
   tarball contents* into `etc/`. That means the published result is
   `$NESTDIR/<sys>/etc/` containing `rc.symlinks`, `lfs`, `lfs.inittab` and so
   on — the LFS layout, which is right, but worth being deliberate about: a
   blanket `cp -r` into `etc/` is a wide blast radius if the tarball ever
   gains a top-level `bin/` or `usr/`.
2. **Nothing runs these scripts, here or on the target.** They are LFS's
   SysV-style init scripts for a full Linux system; Android has no such init.
   They are staged as *data*. That is honest — the recipe never invokes them —
   but a reviewer should confirm the intent is documentation/reference, not
   a working boot path.
3. `.tar.xz`, unpacked with `tar -xf` (`source.lua:9`), which is correct and
   format-agnostic. Worth noting that only this package and `lame`… in fact
   `libtiff`/`lz4` use `-xf` with xz; the majority use `-xzf`. Both are fine;
   `-xf` is the more robust spelling.
4. No `version` metadata inside the installed files, so freshness rests on the
   `.retrolunar-lfs-bootscripts` stamp versus the recipe file.

**How to verify once built.**

- `$NESTDIR/<sys>/etc/rc.symlinks` exists — that is the one file every LFS
  consumer looks for.
- `ls $NESTDIR/<sys>/etc/` shows the `lfs*` init scripts.
- `wc -l etc/rc.symlinks` is non-zero; an empty file means the copy silently
  produced nothing useful.
- Spot-check that nothing executable was staged: `find etc -type f -perm -u+x`
  should be empty, since these are data files to be sourced, not run.
