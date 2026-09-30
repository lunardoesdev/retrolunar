REJECT

# coreutils 9.7 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/coreutils/`. I did not build.

**This is the exact trap AGENTS.md warns about, by name.** The rulebook says:
*"a config template named `config.hin` or `ac_config.h.in` instead of
`config.h.in`, which changes the timestamp guard"*. coreutils' template is
`lib/config.hin`.

## Required changes

### 1. `packages/coreutils/generic.lua:10` — the guard names a file coreutils does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/coreutils/configure.ac
AC_CONFIG_HEADERS([lib/config.h:lib/config.hin])
$ find nest/source/coreutils -maxdepth 2 \( -name 'config.h.in' -o -name 'config.hin' \)
nest/source/coreutils/lib/config.hin
$ ls nest/source/coreutils/config.h.in
ls: cannot access ...: No such file or directory
```

`touch` creates a stray empty `config.h.in` and leaves `lib/config.hin` — the
template autoheader actually regenerates — unguarded.

**Replace line 10 with:**

```
        touch aclocal.m4 configure lib/config.hin
```

**This does not fail today's build** — coreutils is `[x]` and did build,
because `touch` of a missing file in an existing directory exits 0 (verified
under the emitted `set -eu`; only a missing *directory* would abort). The
guard is inert, and `lib/config.hin` is exactly the file whose staleness
re-triggers `autoheader` through the `missing` wrapper.

The same `config.hin` trap is present in `grep`, `gzip`, `diffutils` and
`gawk` in this shard; this is a copy-paste family, so fix all four together.

### 2. `packages/coreutils/generic.lua:7` — the comment is wrong

It reads "Procps and Psmisc provide these two commands separately."
`kill` and `uptime` both come from **procps**; psmisc provides
`killall`/`pkill`/`fuser`. Fix the comment to name procps only.

### 3. `packages/coreutils/generic.lua:11-12` — one latent follow-on worth checking

`cp -r` without `-p` gives every file a fresh mtime in traversal order, so
`doc/coreutils.info` can end up *older* than its `.texi` sources and `make`
will try to regenerate it with `makeinfo`, which the build host may not have.
coreutils' own `dist-hook` deliberately `touch`es `doc/coreutils.info` and
`doc/constants.texi` for precisely this reason. If a rebuild ever tries to run
`makeinfo`, add a matching `touch doc/coreutils.info` next to the guard. Not
required today.

### 4. Nothing else is required

`--enable-no-install-program=kill,uptime` is the right and only trim; `require("acl")`
is a real dependency and `packages/acl` exists. Nothing host-only is left on:
coreutils' tests are `make check` only, `stdbuf`'s `libstdbuf.so` is a target
library under `pkglibexecdir`, and the man pages come from the shipped `.1`
files. `make -j1` is serial. The six WILL BUILD verdicts stand.

## Carried to the build

- `bin/ls`, `bin/cp`, `bin/mv`, `bin/cat` — `llvm-objdump -f bin/ls | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Roughly 100 programs under `bin/`.
- `bin/kill` and `bin/uptime` must be **absent** — their presence means `--enable-no-install-program` did not take.
- `share/info/coreutils.info` — `[ -s share/info/coreutils.info ]`. Use `-s`: a zero-byte file is the signature of a `makeinfo` regeneration attempt.
- `share/man/man1/ls.1` — `[ -s share/man/man1/ls.1 ]`.
- No library and no `.pc`; coreutils is programs. Never run any of them.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- **Required change 1 is done and correct.** `packages/coreutils/generic.lua:9`
  reads `touch aclocal.m4 configure lib/config.hin`, and that is the real
  template:

  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/coreutils/configure.ac
  AC_CONFIG_HEADERS([lib/config.h:lib/config.hin])
  $ find nest/source/coreutils -maxdepth 2 \( -name 'config.h.in' -o -name 'config.hin' \)
  nest/source/coreutils/lib/config.hin
  ```

  Guard position is right: `./configure` line 8, guard lines 9-10,
  `make -j1` line 11. `find . -name 'Makefile.in' | xargs touch` covers both
  `Makefile.in` and `gnulib-tests/Makefile.in`.
- **Required change 2 is done, and the replacement comment is now true.**
  `generic.lua:7` reads "Procps provides both of these commands separately."
  I checked the ownership rather than taking it on trust:

  ```
  $ grep -n 'src/kill\|src/uptime' nest/source/procps/Makefile.am
  153: usrbin_exec_PROGRAMS += src/kill
  155: bin_PROGRAMS += src/kill
       src/uptime (lines 52, 64)
  $ sed -n '19,25p' nest/source/psmisc/Makefile.am
  bin_PROGRAMS = \
        src/killall \
        src/pslog \
        src/prtstat \
        src/pstree
  ```

  procps owns `kill` and `uptime`; psmisc owns `killall`/`pkill`-family tools and
  has neither. So the corrected comment is accurate, and the old "Procps and
  Psmisc provide" line was wrong exactly as this stage2 said.
- Everything else is intact: `--enable-no-install-program=kill,uptime` is a
  package-set choice, not a target fact; `$AUTOCONF_CONFIGURE_FLAGS`,
  `$PREFIX`, `$OUT`, `$NESTDIR` only; no `export`, no `sed`, no `/dev/null`, no
  patch, `make -j1`; `require("acl")` resolves to `packages/acl`.
- Required change 3 (the optional `touch doc/coreutils.info`) was correctly not
  done: this stage2 called it "not required today", and the tarball ships
  `doc/coreutils.info` at ~1 MB against `doc/coreutils.texi`, with coreutils'
  own `dist-hook` touching both. Recording it here so it is not mistaken for an
  oversight.

### Still wrong

The recipe is clean, but **the rejected attribution survives in the forecast**,
in the same package, in three places. That is the letter of the instruction
being satisfied while the claim under it is still false, which is the failure
mode this review exists to stop — the next reader of `stage1.md` still believes
psmisc supplies `kill`:

- **`packages/coreutils/stage1.md:11`** — "removes two tools that procps **and
  psmisc** provide."
- **`packages/coreutils/stage1.md:34-36`** — "If psmisc or procps were removed,
  two tools would silently disappear from the prefix."
- **`packages/coreutils/stage1.md:54`** — "`bin/kill` and `bin/uptime` should be
  **absent** (procps/psmisc own them)".

  **Fix:** name procps only in all three, matching the corrected recipe comment.
  I am not permitted to edit `stage1.md`, so this is recorded rather than fixed.

- Minor, and not from this rework: `stage1.md:6` says "no library, no `.pc`",
  but coreutils 9.7 does install a target shared library — `src/local.mk:35`
  is `pkglibexec_PROGRAMS` and `src/local.mk:498` builds `libstdbuf.so`
  ("only compiled if GCC is available", line 495). It lives under
  `$(pkglibexecdir)`, not `lib/`, so the artifact list is not *wrong* about the
  prefix root, but it should say `libstdbuf.so` under `pkglibexecdir` so the
  builder checks for it. This stage2 already noticed the file; the forecast
  never did.

### Broken by the rework

Nothing.

## Rework verification — summary

The guard and the comment are both correct and verified against the tree and
  against procps's and psmisc's own Makefile.am. Rejected because the false
  "procps and psmisc" attribution required change 2 rejected is still asserted
  three times in `stage1.md`, so the package now contradicts itself between the
  recipe and its own forecast.
