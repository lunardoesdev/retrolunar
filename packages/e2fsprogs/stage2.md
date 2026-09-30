ACCEPT

# e2fsprogs 1.47.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, the NDK r28b
sysroot, and the extracted `e2fsprogs-1.47.3` tarball. I did not build.

**Adder B's finding #1 is CORRECT.** I re-ran both URLs myself:

```
404  https://downloads.sourceforge.net/project/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz
206  https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz
```

The tarball at the kernel.org mirror is the real 1.47.3 release (9.6 MB, full
`e2fsprogs-1.47.3/` tree, `configure` + `aclocal.m4` + 19 `Makefile.in`). So
`topackage.md:19`'s "(blocked: upstream tarball URLs return 404)" is stale as a
statement that no source is reachable.

**The forecast itself is right** — `stage1.md` says WILL NOT BUILD (fetch) on all
six systems, which is correct. This is a category-(b) reject: the recipe is
defective, and the forecast documents rather than papers over it.

## Required changes

### 1. `packages/e2fsprogs/source.lua:6` — the URL 404s, so nothing builds

The recipe can never fetch. Replace the URL:

```
          curl -fSL -C - -o dl/e2fsprogs.tar.gz "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz"
```

That is the whole fetch-level fix. Keep the `if [ ! -f dl/e2fsprogs.tar.gz ]`
guard and the `curl -C -` resume exactly as they are.

### 2. `packages/e2fsprogs/generic.lua:15` — the timestamp guard names a file that does not exist

The recipe has:

```
        touch aclocal.m4 configure config.h.in
```

I extracted the tarball. The config-header template is **not** `config.h.in`:

```
configure.ac:5:AC_CONFIG_HEADERS([lib/config.h])
$ find . -maxdepth 2 -name '*config*.in'
./lib/config.h.in          <-- this one
$ ls config.h.in
ls: cannot access 'config.h.in': No such file or directory
```

So `touch ... config.h.in` **creates a stray empty `config.h.in`** in `$WORK`
and leaves the real template `lib/config.h.in` un-refreshed. The guard's whole
purpose is to stop `config.status` regenerating and to keep the generated files
newer than their inputs; for this project it does neither, because it is aimed
at the wrong path. The tree already has the precedent for this — `libnl-3` and
`libunwind` guard `include/config.h.in`, `oniguruma` guards `src/config.h.in`,
`libseccomp` guards `configure.h.in`.

**Replace line 15 with:**

```
        touch aclocal.m4 configure lib/config.h.in lib/dirpaths.h.in
```

`lib/dirpaths.h.in` matters for the same reason: `Makefile.in:30-31` lists
`lib/config.h` and `lib/dirpaths.h` in `SUBS`, and both come from `.in`
templates at configure time.

### 3. `packages/e2fsprogs/stage1.md:6` — the "Installs" line contradicts the recipe

Line 6 lists `lib/libblkid.so` and `lib/libuuid.so` as installed. The recipe
disables both (`generic.lua:11-12`, `--disable-libblkid --disable-libuuid`),
and I confirmed upstream gates them on the `@BLKID_CMT@` / `@UUID_CMT@`
configure substitutions (`Makefile.in:15-16`), so with them disabled those
libraries are genuinely never built. Delete both from the "Installs" line. The
"how to verify" section at lines 69-72 already gets this right, so line 6 is
the only place to change.

### 4. Nothing else is required

`generic.lua:6-7`'s claim that "Util-linux provides the blkid, uuid and fsck
wrappers" is **true** — `packages/util-linux` exists — so the disable set is a
defensible de-duplication, not a mistake. `--sysconfdir="$OUT/etc"` is a
`$OUT`-relative install path and is allowed. `make -j1` / `make -j1 install`
are serial. The `SUBDIRS`/`PROG_SUBDIRS` sweep in `Makefile.in:25-28` does pull
in `tests/progs` and `tests/fuzz` unconditionally, but those are *target*
programs, never run, and there is no upstream switch to drop them — worth
knowing for build time, not a defect to fix.

## The `topackage.md:19` correction

`stage1.md` is right that the line is stale. After a successful
`aarch64-android24` build it should read something like:

```
- [x] E2fsprogs 1.47.3 (shared libext2fs/libcom_err/libss/libe2p via --enable-elf-shlibs;
  sbin/mke2fs, sbin/e2fsck, sbin/debugfs, sbin/dumpe2fs, sbin/resize2fs, sbin/chattr, sbin/lsattr;
  include/ext2fs/ext2fs.h; pkg-config --modversion ext2fs reports 1.47.3.
  Note: fetched from mirrors.edge.kernel.org — the SourceForge project URL 404s.
  blkid/uuid/uuidd/fsck are disabled because packages/util-linux provides them.
  This is one of the few shared-library packages in the prefix)
```

Until then the honest state is "source is reachable; not yet built".

## Carried to the build

- `lib/libext2fs.so` — `llvm-objdump -f lib/libext2fs.so | head -3` → `elf64-littleaarch64` on Android, `pei-x86-64` on mingw.
- `lib/libcom_err.so`, `lib/libss.so`, `lib/libe2p.so` — `[ -f lib/libcom_err.so ]`.
- `include/ext2fs/ext2fs.h` — `[ -f include/ext2fs/ext2fs.h ]`.
- `lib/pkgconfig/ext2fs.pc` — `pkg-config --modversion ext2fs` → `1.47.3`.
- `sbin/mke2fs`, `sbin/e2fsck` — `[ -x sbin/mke2fs ] && [ -x sbin/e2fsck ]`. **Never run them**; they are filesystem tools and running a target binary is forbidden.
- `lib/libblkid.so` and `lib/libuuid.so` must be **absent** — their presence means `--disable-libblkid` / `--disable-libuuid` did not take.

---

## Rework verification

**Verdict: ACCEPT.** (The first line of this file was changed from `REJECT`
to `ACCEPT` by this review.)

### Required change 1 — the URL: fixed, and I fetched it

`source.lua:6` now points at the kernel.org mirror. I re-ran it myself
rather than trusting the comment:

```
$ curl -sS -o /dev/null -w "%{http_code} %{size_download}\n" -L \
    "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.3/e2fsprogs-1.47.3.tar.gz"
200 10071750
```

Full GET into `/tmp`, sha256 `7d4612f4e4f7ca6c2f669679028bcb02763e3b6280c9c19b2cf168eaf65e88af`.
Both `.in` files the guard names are really in the tarball, and the version
is really 1.47.3:

```
$ tar -tzf e.tgz | grep -E 'config\.h\.in|dirpaths\.h\.in'
e2fsprogs-1.47.3/lib/config.h.in
e2fsprogs-1.47.3/lib/dirpaths.h.in
$ tar -xzf e.tgz -O e2fsprogs-1.47.3/version.h | grep VERS
12:#define E2FSPROGS_VERSION "1.47.3"
```

The `if [ ! -f dl/e2fsprogs.tar.gz ]` guard and `curl -C -` resume are
untouched, as required.

### Required change 2 — the guard: correct, and both files matter

`generic.lua:15` is `touch aclocal.m4 configure lib/config.h.in
lib/dirpaths.h.in`, positioned after `./configure` (`:8-14`) and before
`make` (`:17`).

`configure.ac:5` is `AC_CONFIG_HEADERS([lib/config.h])` with
`AH_BOTTOM([#include <dirpaths.h>])`, so the top-level `config.h.in` the
recipe used to touch never existed and `touch` was creating it. The second
file is not decoration — I confirmed `dirpaths.h` is generated from its
template via the project's own `SUBS` mechanism, at the top level:

```
$ sed -n '30,31p' Makefile.in
SUBS= util/subst.conf lib/config.h $(top_builddir)/lib/dirpaths.h \
	lib/ext2fs/ext2_types.h lib/blkid/blkid_types.h lib/uuid/uuid_types.h
```

which matches stage2's citation exactly. `find . -name 'Makefile.in' |
xargs touch` (`:16`) covers all 19 `Makefile.in` files including
`lib/ext2fs/`, `tests/progs/`, `tests/fuzz/` and `util/`.

### Required change 3 — the "Installs" line: fixed

`stage1.md:6` no longer claims `lib/libblkid.so` or `lib/libuuid.so`. It now
states positively that upstream never builds them. I checked that this is
true rather than merely consistent with the flags: upstream gates both on
`@BLKID_CMT@` / `@UUID_CMT@` (`Makefile.in:15-16`), and `--disable-libblkid`
/ `--disable-libuuid` are genuine options (`configure --help` lists
`--enable-libblkid`, `--enable-libuuid`, `--enable-fsck`;
`--disable-uuidd` is spelled out at `configure.ac` and in `--help`). All
four flags the recipe passes exist.

### Required change 4 — the verdicts: no longer "blocked at fetch"

All six rows at `stage1.md:11-16` are now **UNCERTAIN**, and the reason
text is right: the fetch works, the build does not. This is the correct
state and it is materially different from the old "WILL NOT BUILD (fetch)"
that stage2 rejected. The `:39-63` risk section also correctly records that
`--enable-elf-shlibs` makes this the prefix's second shared-library package
and that the `mke2fs` side is unexamined.

### Nothing else damaged

`--sysconfdir="$OUT/etc"` is a `$OUT`-relative install path and is allowed.
`require("e2fsprogs@source")` names no missing package. `make -j1` /
`make -j1 install` are serial. No `export`, no hardcoded target facts, no
`sed`, no patch, no `/dev/null`. There is no `android.lua` and none is
needed. The `util-linux` comment at `:6-7` is accurate — `packages/util-linux`
exists.

### One pre-existing inaccuracy I did not gate this on

`stage1.md:6` says the disables mean "upstream never builds them", which is
right, but the same line still asserts the *positive* artifact list
`lib/libss.so`, `lib/libe2p.so`, `lib/libext2fs.so` as a `.so` set. That is
downstream of the recipe's own `--enable-elf-shlibs`, so it is consistent —
just flagging that the shared/static mix is asserted rather than verified,
which is already called out at `stage1.md:55-60`. No change required.
