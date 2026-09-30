REJECT

# bash 5.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the NDK r28b
sysroot. I did not build.

**Adder B's finding #4 (bash half) is CORRECT.** I verified the header claim
directly:

```
$ grep -n getgrent $ANDROID_HOME/ndk/28.2.13676358/.../sysroot/usr/include/grp.h
56:struct group* _Nullable getgrent(void) __INTRODUCED_IN(26);
```

`__INTRODUCED_IN(26)` gates the declaration, so `libglob/libglob.c` will not
compile below API 26 — on **21, 23 and 24 alike**, not just 24. The recipe's
`android.lua` only sets `CC_FOR_BUILD`/`CFLAGS_FOR_BUILD` and cannot help.

The **forecast is right**: `stage1.md:11-12` says WILL NOT BUILD for
`aarch64-android21` and `aarch64-android24` and WILL BUILD for the API-35 rows,
and `stage1.md:46-48` already notes that the backlog line omits 21. This is a
category-(iii) reject on the backlog line, plus a category-(b) recipe defect
below.

## Required changes

### 1. `topackage.md:11` — the blocker line is incomplete and will mislead

It currently reads:

```
- [ ] Bash 5.3 (Android 24 blocked: getgrent requires API 26)
```

That names one system when the gate is a level, and it invites someone to try
`android23` or `android21` and lose an hour. It should read:

```
- [ ] Bash 5.3 (blocked on every Android system below API 26: libglob calls
  getgrent, which Bionic declares only from API 26, grp.h:56 __INTRODUCED_IN(26).
  Android 21, 23 and 24 all fail to compile it; android35 is expected to build)
```

`stage1.md:11-16` already carries the per-system verdicts; the backlog line
should match them.

### 2. `packages/bash/generic.lua:8` and `packages/bash/android.lua:11` — the guard misses a config template

Both files have:

```
        touch aclocal.m4 configure config.h.in
```

bash declares **two** config headers:

```
configure.ac:AC_CONFIG_HEADERS(config.h buildconf.h)
```

and ships `config.h.in` at the top level (I confirmed via the tarball listing).
`buildconf.h.in` also exists, so the guard should name both. Replace the line
in **both** files with:

```
        touch aclocal.m4 configure config.h.in buildconf.h.in
```

Minor, but it is the same mandated-guard rule and the tree applies it by hand
per project. `stage1.md` does not mention it.

### 3. `packages/bash/generic.lua` — the `CC_FOR_BUILD` workaround is Android-only but the wall is not

`android.lua:10` sets `CC_FOR_BUILD="cc" CFLAGS_FOR_BUILD="-std=gnu17"` for
bash's host-side `builtins/` helper, with the comment "Bash's host-side helper
uses a bool typedef; GCC 16 needs GNU17."

That is a *host-compiler* fact, not an Android fact. The two files are
otherwise byte-identical (`stage1.md:34-38` notes this), and `generic.lua:7`
builds without the flag. If the build host's default `cc` is a GCC new enough
to reject the typedef, `bash@clang-native` hits the same wall with no
workaround. Before the build runs, check what `cc` is on the build host; if it
is GCC ≥ 15, the `-std=gnu17` belongs in `generic.lua` too (or in both files),
because the cause is the host compiler rather than the target.

This is a "verify before building" item rather than a certain defect, so it is
listed here as required-checking, not as a known failure.

### 4. Nothing else is required

`CC_FOR_BUILD`/`CFLAGS_FOR_BUILD` set as a command prefix rather than `export`ed
is the sanctioned recipe-local exception, and the reason is written down. The
two-file split (`generic.lua` + one `android.lua`, no per-target copies) is
exactly what AGENTS.md prescribes. `--with-installed-readline` with
`require("readline")` is correct, and `packages/readline` exists.

## Carried to the build

Only the `android35` / `x86_64-android35` / `clang-native` rows are buildable.

- `bin/bash` — `llvm-objdump -f bin/bash | head -3` → `elf64-littleaarch64`; on a 35 target the `llvm-objdump -p` note section should show Android 35.
- `bin/bashbug` — `[ -x bin/bashbug ]`.
- `info/bash.info` — `[ -f info/bash.info ]`.
- No library and no `.pc`; bash is a program.
- **Never run `bin/bash`** — it is a target binary. The proof that the blocker is gone is that the file linked at all, not that it runs.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- **Required change 2 is done and correct.** Both recipes now name both
  templates, and both templates really exist:

  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/bash/configure.ac
  AC_CONFIG_HEADERS(config.h buildconf.h)
  $ find nest/source/bash -maxdepth 1 -name '*.h.in'
  nest/source/bash/buildconf.h.in
  nest/source/bash/config.h.in
  ```

  `generic.lua:8` and `android.lua:11` both read
  `touch aclocal.m4 configure config.h.in buildconf.h.in`. Nothing is missing,
  nothing extraneous is named, so no stray file is created and the guard is
  live on both targets. `buildconf.h.in` is not cosmetic either — see below, it
  is the header that is actually included on a cross build.
- Guard position is right in both files: `./configure` on line 7 / line 10,
  guard immediately after, `make -j1` on line 10 / line 13.
- `find . -name 'Makefile.in' | xargs touch` is adequate: bash 5.3 ships 13
  `Makefile.in` files, 12 of them in subdirectories (`builtins/`, `lib/glob/`,
  `lib/intl/`, `lib/malloc/`, `lib/readline/`, `lib/sh/`, `lib/termcap/`,
  `lib/tilde/`, `support/`, `doc/`, `examples/loadables/`). A plain `find` from
  `$WORK` reaches all of them; there is no `AC_CONFIG_SUBDIRS` here, so unlike
  gperf there are no second-level `configure` scripts to sweep.
- `--with-installed-readline` with `require("readline")` is right;
  `packages/readline` exists. `--without-bash-malloc` is a package choice, not
  a target fact.
- The `CC_FOR_BUILD="cc" CFLAGS_FOR_BUILD="-std=gnu17"` prefix form (not
  `export`) is the sanctioned recipe-local exception, and it is the *right
  variable*: `builtins/Makefile.in:63` is
  `CFLAGS_FOR_BUILD = @CFLAGS_FOR_BUILD@ @CROSS_COMPILE@` and line 106 is
  `CCFLAGS_FOR_BUILD = $(BASE_CCFLAGS) $(CPPFLAGS_FOR_BUILD) $(CFLAGS_FOR_BUILD)`,
  so the value reaches the host-helper compile line (lines 191/231/234).
  `configure.ac:266` declares it `AC_ARG_VAR`, so setting it in configure's
  environment is sufficient. The comment's stated cause is also correct — I
  confirmed it with a throwaway probe rather than taking it on trust.

### I verified the comment's claim, and it holds

The `android.lua:9` comment says "Bash's host-side helper uses a bool typedef;
  GCC 16 needs GNU17." That is accurate, but the mechanism is worth writing
  down, because it is what makes required change 3 a live defect rather than a
  stylistic one.

  `builtins/mkbuiltins.c:23-27` includes `buildconf.h` — **not** `config.h` —
  whenever `CROSS_COMPILING` is defined, and
  `builtins/Makefile.in:63` appends `-DCROSS_COMPILING` (`configure.ac:496`)
  on every cross build. `buildconf.h.in` then says:

  ```
  /* defining this implies a C23 environment */
  #undef HAVE_C_BOOL
  ```

  and never defines `HAVE_STDBOOL_H`. So `bashansi.h:39-46` falls into the
  `typedef unsigned char bool;` branch, and under a C23-default compiler that
  is a hard error. Probe against the host toolchain
  (`gcc 16.2.1`, default `-std=gnu23`):

  ```
  $ gcc -DCROSS_COMPILING -I<buildconf.h> -c ... builtins/mkbuiltins.c
  bashansi.h:44:23: error: 'bool' cannot be defined via 'typedef'
  $ gcc -DCROSS_COMPILING -std=gnu17 ... builtins/mkbuiltins.c
  (clean)
  ```

  The identical probe *without* `CROSS_COMPILING` (the native path, `config.h`
  with `HAVE_C_BOOL` set by `configure.ac:796` `gl_C_BOOL`) compiles clean at
  both standards — which is why `clang-native` never needed the flag and why
  nobody noticed.

### Still wrong

- **Required change 3 was not done, and the underlying claim in
  `stage1.md` is wrong.** The workaround is still Android-only, but the wall is
  not an Android fact: it is a *cross-compiling + host-compiler* fact, so it
  applies to every cross build. `x86_64-mingw` is a cross build —
  `packages/x86_64-mingw/generic.lua:54` sets
  `AUTOCONF_CONFIGURE_FLAGS="--host=$HOST_TRIPLET --build=$BUILD_TRIPLET"` with
  `HOST_TRIPLET=x86_64-w64-mingw32` and `BUILD_TRIPLET=x86_64-pc-linux-gnu`
  (lines 47-48) — and it resolves through `generic.lua`, which has no
  `CC_FOR_BUILD`/`CFLAGS_FOR_BUILD` at all. `configure.ac:556` therefore
  defaults `CC_FOR_BUILD` to `gcc` and `configure.ac:559` defaults
  `CFLAGS_FOR_BUILD` to `-g`, so `bash@x86_64-mingw` compiles `mkbuiltins` with
  host GCC 16 in its default C23 mode against the `buildconf.h` path, and hits
  exactly the `bashansi.h:44` error above.
  **Fix:** move the prefix to `generic.lua:7` as well (or into both files):

  ```
        CC_FOR_BUILD="cc" CFLAGS_FOR_BUILD="-std=gnu17" ./configure $AUTOCONF_CONFIGURE_FLAGS --without-bash-malloc --with-installed-readline
  ```

  and correct the `android.lua:9` comment to say the cause is cross-compiling
  plus the build host's default C standard, not Android.
  Note that keeping it in both files is correct, not a duplication bug: the two
  files then differ only in nothing, at which point `android.lua` should be
  deleted. Either way the flag must not live only in `android.lua`.

- **`packages/bash/stage1.md:15`** — the `x86_64-mingw` row says "WILL BUILD"
  and reasons only about `--with-installed-readline`. It does not consider
  `CC_FOR_BUILD`, and once required change 3 is honoured that row is right;
  as the recipe stands today it is a forecast that contradicts the recipe's own
  failure mode. Rewrite the row once the fix lands.

- **`packages/bash/stage1.md:11`** — "`libglob/libglob.c` calls `getgrent`
  when no user/group name is supplied". There is no `libglob/` in bash 5.3
  (`ls nest/source/bash/libglob` → no such directory). The call is at
  `nest/source/bash/bashline.c:2742`, inside the group-name lookup that
  `lib/`/`builtins/` pull in through `bashline.h`. The verdict is unaffected —
  I probed the gate directly and it is exactly as stated — but the citation
  points at a file that does not exist, and this stage2's own preamble repeats
  the same nonexistent path, so it is worth correcting in both.

  For the record, the probe settles the level question cleanly:

  ```
  $ for lvl in 21 23 24 26 35; do aarch64-linux-android$lvl-clang -c g.c; done
  API 21: error: call to undeclared function 'getgrent'   FAILED
  API 23: error: call to undeclared function 'getgrent'   FAILED
  API 24: error: call to undeclared function 'getgrent'   FAILED
  API 26: OK
  API 35: OK
  ```

  against NDK r28b `grp.h:56`, `getgrent(void) __INTRODUCED_IN(26)`. So 21, 23
  and 24 all fail to compile and 26+ is the floor, exactly as this stage2
  found.

- **Required change 1 was not done.** `topackage.md:11` still reads
  `- [ ] Bash 5.3 (Android 24 blocked: getgrent requires API 26)`. That is the
  line this stage2 called misleading, and the probe above shows it is worse
  than "incomplete": it names one of *three* Android systems that fail. I am
  not permitted to edit `topackage.md`, so this is recorded rather than fixed.

### Broken by the rework

Nothing. No flag was lost, no dependency dropped, and `generic.lua` /
  `android.lua` stayed otherwise byte-identical apart from the documented
  prefix.

## Rework verification — summary

The guard fix (required change 2) is correct and complete: both real templates
  are named in both files, and the comment justifying the host-helper flag is
  accurate. Rejected because required change 3 is untouched and demonstrably
  wrong — the flag is a cross-compiling fact, not an Android one, so
  `bash@x86_64-mingw` is broken as the recipe stands — and because required
  change 1 (`topackage.md:11`) was never applied.
