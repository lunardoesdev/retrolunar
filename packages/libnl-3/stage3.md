# libnl-3 3.12.0 — stage 3 build record

System built for: **`aarch64-android24`**.

## Outcome: **FAILURE — blocked before it ever compiled**

libnl-3's own `configure` **never ran**. The emitted script aborted in the
**`flex@clang-native`** block, four blocks earlier. Nothing of libnl-3's was
built, nothing was published, no stamp was written.

```
$ grep -cE 'libnl-3|netlink|route/link' /tmp/build-libnl-3.log
0
$ ls -a nest/aarch64-android24/.retrolunar-libnl-3
ls: cannot access '.../.retrolunar-libnl-3': No such file or directory
$ ls nest/aarch64-android24/lib/libnl-* nest/aarch64-android24/include/libnl3
ls: cannot access '...': No such file or directory
```

The last thing in the log is flex's `make` failing; the `gperf@clang-native`,
`bison@clang-native` and `libnl-3@aarch64-android24` blocks that follow it in
the script never executed.

## Command sequence

```sh
cd /home/si/ond/git/retrolunar
export ANDROID_HOME=/home/si/.local/share/mise/installs/android-sdk/23.0
rm -f nest/aarch64-android24/.retrolunar-libnl-3
rm -f nest/aarch64-android24/lib/libnl-*.a nest/aarch64-android24/lib/libnl-*.so* \
      nest/aarch64-android24/lib/libnl-*.la nest/aarch64-android24/lib/pkgconfig/libnl-*.pc
rm -rf nest/aarch64-android24/include/libnl3
rm -f nest/aarch64-android24/share/man/man8/libnl*.8
./builddir/retrolunar install --nest ./nest --packages ./packages \
    'libnl-3@aarch64-android24' > /tmp/build-libnl-3.sh
sh -n /tmp/build-libnl-3.sh          # exit 0 — syntax gate passed
sh /tmp/build-libnl-3.sh             # exit 2
```

The emitted script's ten blocks, in order, exactly as generated:

```
# --- m4@source ---              # --- flex@source ---
# --- m4@clang-native ---        # --- flex@clang-native ---     <-- FAILED HERE
# --- gperf@source ---           # --- gperf@clang-native ---
# --- bison@source ---           # --- bison@clang-native ---
# --- libnl-3@source ---         # --- libnl-3@aarch64-android24 ---
```

## Stale-artifact cleanup

libnl-3 had **no** stale artifacts and no stamp:

```
$ ls nest/aarch64-android24/lib/libnl-* nest/aarch64-android24/lib/pkgconfig/libnl* \
      nest/aarch64-android24/include/libnl3
(nothing — no such files)
$ ls -a nest/aarch64-android24/.retrolunar-libnl-3
ls: cannot access '.../.retrolunar-libnl-3': No such file or directory
```

The scoped cleanup (`rm -rf share/man` was **not** used — see the oniguruma
mistake recorded in `packages/oniguruma/stage3.md`; only
`share/man/man8/libnl*.8` was scoped) ran and found nothing. Post-cleanup the
shared man tree was still intact at **5181** files. So a false pass is
impossible here: the build produced nothing at all.

## The error, quoted in full

`/tmp/build-libnl-3.log:440-446`, the last lines of the run:

```
/bin/sh ../build-aux/ylwrap parse.y y.tab.c parse.c y.tab.h `echo parse.c | sed -e s/cc$/hh/ -e s/cpp$/hpp/ -e s/cxx$/hxx/ -e s/c++$/h++/ -e s/c$/h/` y.output parse.output -- bison -y -d 
bison: /home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/bison/m4sugar/m4sugar.m4: cannot open: No such file or directory
make[2]: *** [Makefile:1428: parse.c] Error 1
make[2]: Leaving directory '/home/si/ond/git/retrolunar/nest/tmp/work-c6nyUL/src'
make[1]: *** [Makefile:546: all] Error 2
make[1]: Leaving directory '/home/si/ond/git/retrolunar/nest/tmp/work-c6nyUL/src'
make: *** [Makefile:533: all-recursive] Error 1
```

This is **flex's** `src/parse.c` rule (`ylwrap` invoking `bison -y -d` to turn
`parse.y` into `parse.c`), not libnl-3's.

## Classification: a missing prerequisite, with two upstream/config defects behind it

`flex@clang-native` did not produce a working `flex`, so
`require("flex@native")` is still unmet and libnl-3 cannot be reached. Two
separate things went wrong, and both were diagnosed rather than guessed.

### (1) flex's autotools timestamp guard is incomplete — recipe defect

The **first**, standalone `flex@clang-native` attempt failed here
(`/tmp/build-flex.log:587-599`):

```
/bin/sh ./tableopts.sh > ./tableopts.am
 cd .. && /bin/sh .../build-aux/missing automake-1.15 --foreign tests/Makefile
.../build-aux/missing: line 81: automake-1.15: command not found
WARNING: 'automake-1.15' is missing on your system.
         You should only need it if you modified 'Makefile.am' or
         'configure.ac' or m4 files included by 'configure.ac'.
make[1]: *** [Makefile:1789: Makefile.in] Error 127
```

- **File and line:** `tests/Makefile` (generated), rule `Makefile:1789`
  `Makefile.in`.
- **Cause:** flex's `tests/` is a **sub-configured** project. `tests/Makefile.am`
  ends with `include $(srcdir)/tableopts.am` (line 451), and `tableopts.am` is
  itself generated (`tableopts.am: tableopts.sh`, line 448). flex's release
  tarball ships `tableopts.sh` **newer** than `tableopts.am`, so the
  `include`d fragment is out of date relative to `Makefile.in`, make re-runs
  the generator, `tests/Makefile.am` becomes newer than `tests/Makefile.in`,
  and the `automake` rule fires. The recipe's guard is
  `touch aclocal.m4 configure src/config.h.in` +
  `find . -name 'Makefile.in' | xargs touch` — the `find` does cover
  `tests/Makefile.in`, but the guard runs *before* `tableopts.am` is
  regenerated, so it is undone during `make`.
- **Why `automake-1.15` is missing:** `AM_INIT_AUTOMAKE` at
  `configure.ac:31` produced a `Makefile` that asks for the versioned
  `automake-1.15`; the host has 1.18.1 (`/usr/bin/automake-1.18`) and the
  native prefix has no automake at all. Neither is `automake-1.15`.
- **Classification:** recipe defect (an incomplete autotools guard for a
  sub-configured project), compounded by a version-pinned automake requirement
  the prefix cannot satisfy. **`packages/flex` is outside this build's scope —
  it is not one of the fifteen — so nothing was changed.** Recorded, not
  fixed.

### (2) the freshly built `bison@clang-native` is itself broken — recipe defect

This is the more interesting one, and it is why the *second* flex attempt
failed differently (at `src/parse.c` instead of `tests/`): by then bison
existed in the native prefix and **shadowed** the working host bison on
`PATH`, and it does not work.

`nest/clang-native/bin/bison` is a real, runnable **x86-64** binary:

```
$ file nest/clang-native/bin/bison
ELF 64-bit LSB pie executable, x86-64, ... interpreter /lib64/ld-linux-x86-64.so.2
$ nest/clang-native/bin/bison --version
bison (GNU Bison) 3.8.2
```

But its **data directory is baked to the staging path**, which the loader
deletes after publishing:

```
$ strings nest/clang-native/bin/bison | grep '/home/si/ond/git/retrolunar'
/home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/bison
/home/si/ond/git/retrolunar/nest/clang-native/bin/m4
/home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/locale
$ ls -d nest/tmp/out-LTM8ZA
NO — the staging dir is gone (loader rm -rf'd it)
```

So any bison invocation that actually parses a grammar fails — reproducing
the libnl-3-run error exactly, outside the build:

```
$ PATH="$PWD/nest/clang-native/bin:$PATH" bison -y -d -o good.tab.c good.y
bison: /home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/bison/m4sugar/m4sugar.m4: cannot open: No such file or directory
```

`--version` works (it never touches the data dir); parsing does not. bison's
`lib/relocatable.c` could paper over this via `INSTALLPREFIX`/`INSTALLDIR`
relocation, but `ENABLE_COSTLY_RELOCATABLE` is compiled out of this build
(no `--enable-relocatable` was passed), so `relocate()` is a no-op and the
staging path is used verbatim.

- **Cause:** `packages/bison/generic.lua` passes bare
  `./configure $AUTOCONF_CONFIGURE_FLAGS`, which sets `--prefix=$OUT` — the
  **staging** dir — and bison bakes `pkgdatadir` from it. The loader publishes
  with `cp -rf` and then `rm -rf`s `$OUT`, so the published binary points at a
  path that no longer exists.
- **Classification:** recipe defect (missing `--enable-relocatable`, or an
  equivalent). **`packages/bison` is outside this build's scope, so nothing was
  changed.** Recorded, not fixed. Note the preflight explicitly said *not* to
  "fix" bison's bare `./configure` — that advice is right about
  `--enable-static`/`--disable-shared` on a native host tool, and this finding
  is a separate defect it did not name.

### The cross-compiled bison decoy was avoided

`nest/aarch64-android24/bin/bison` exists and looks like the tool is already
present. It is a **cross-compiled aarch64 Android binary** and cannot run on
this x86-64 host:

```
$ file nest/aarch64-android24/bin/bison
ELF 64-bit LSB pie executable, ARM aarch64, ... interpreter /system/bin/linker64, for Android 24, built by NDK r28c
```

It was not copied anywhere and not on the block's `PATH`
(`$NATIVE_PREFIX/bin` is `nest/clang-native/bin`). **No target binary was
executed at any point in this batch** — no QEMU, no emulator, no `binfmt_misc`
registration, none installed.

### What libnl-3 itself would have hit

Not reached, but worth recording because it is a *host-tool* dependency, not a
platform wall: libnl-3's `configure.ac:156-163` `AC_MSG_ERROR`s if `YACC` or
`FLEX` is empty. Both would have been non-empty here — but from the **host's**
`/usr/bin/flex` and `/usr/bin/bison` (both present, `checking for flex... flex`,
`checking for bison... bison -y` in the log), *not* from the prefix. This
build machine happens to have flex and bison installed system-wide. On a host
without them, libnl-3 would have failed at configure. That is an undeclared
dependency on the build machine, and it is why the preflight's warning about
`flex@clang-native`/`bison@clang-native` being genuinely required is correct
even though configure itself would have limped along.

## Native tier results

Built for this package, serially, one at a time:

| tool | result | evidence |
| --- | --- | --- |
| `m4@clang-native` | **SUCCESS** | `file` → `ELF 64-bit LSB pie executable, x86-64`; `m4 --version` → `GNU M4 1.4.20`; rerun `skip m4@clang-native (fresh)` |
| `gperf@clang-native` | **skip (fresh)** — pre-existing | `file` → `x86-64`; `gperf --version` → `GNU gperf 3.3`; used successfully by libseccomp's `syscalls.perf` regeneration |
| `bison@clang-native` | built, **but broken** | `file` → `x86-64`; `bison --version` → `GNU Bison 3.8.2`; **fails on any real parse** — `m4sugar.m4` baked to the deleted staging dir |
| `flex@clang-native` | **FAILURE** | `automake-1.15: command not found` (run 1); `bison: …/out-LTM8ZA/share/bison/m4sugar/m4sugar.m4: cannot open` (run 2, native bison shadowing the host one) |

No `flex` binary exists in `nest/clang-native/bin` and no `.retrolunar-flex`
stamp was written — both correct, since the loader publishes and stamps only on
success. `bison` *does* have a stamp and a binary, which is why the second flex
attempt behaved differently: it got further before hitting a different wall.

## System-level findings

1. **Native host tools that bake `$OUT` into their binaries are published
   broken.** bison 3.8.2 is the concrete case in this batch: the loader's
   `cp -rf` + `rm -rf $OUT` publish step cannot rewrite a compiled-in absolute
   path, and bison's `--enable-relocatable` is off by default here. Any future
   native tool in this prefix that needs its data files at run time has the
   same exposure. This is a property of the loader's publish model meeting an
   upstream default, and it is worth knowing before adding more native tools.
   **Not worked around** — the honest fix belongs in `packages/bison/generic.lua`
   (`--enable-relocatable`) and in `packages/flex/generic.lua` (guard the
   `tests/` sub-configure), both outside this build's scope.

2. **No `automake-1.15` anywhere.** The host has automake 1.18.1 and the native
   prefix has none. Any autotools package in this prefix whose shipped
   `Makefile.in` was generated by automake 1.15 will re-run the automake rule
   and die with `command not found` if its timestamp guard is incomplete.

3. **The host has `flex` and `bison` installed system-wide**, so a missing
   `flex@native`/`bison@native` does not necessarily stop `configure` — it
   silently uses the host's copies. That is a latent cross-contamination risk:
   a build can appear to satisfy a `require("@native")` it has not actually
   built. Recorded.

## Recipe changes

**None.** No `packages/libnl-3/` file was modified in this build;
`source.lua`, `generic.lua` and `android.lua` are committed unmodified. No
system file was touched. The two defects above are in `packages/flex` and
`packages/bison`, which are outside the fifteen and outside this build's
scope — recorded here, not fixed.
