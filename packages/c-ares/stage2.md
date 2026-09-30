REJECT

# c-ares 1.34.8 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the extracted
`c-ares-1.34.8` release tarball. I did not build.

**One recipe defect, in the mandated autotools timestamp guard.** The forecast
is otherwise right: the six WILL BUILD verdicts hold, and the configure line
is well judged.

## Required changes

### 1. `packages/c-ares/generic.lua:10` — the guard names two config templates c-ares does not have

```
        touch aclocal.m4 configure config.h.in
```

I extracted the tarball. c-ares has no top-level `config.h` and no top-level
`config.h.in`:

```
$ tar -tzf c-ares-1.34.8.tar.gz | grep -E 'config.*\.h\.in$'
c-ares-1.34.8/src/lib/ares_config.h.in

$ tar -xzOf … --wildcards '*/configure.ac' | grep -n AC_CONFIG_HEADER
39:AC_CONFIG_HEADERS([src/lib/ares_config.h include/ares_build.h])

$ tar -tzf c-ares-1.34.8.tar.gz | grep -E 'ares_build\.h'
c-ares-1.34.8/include/ares_build.h.in      <- the second template, also shipped
c-ares-1.34.8/include/ares_build.h
c-ares-1.34.8/include/ares_build.h.cmake
```

Both real templates are in subdirectories. The guard as written touches a
stray empty `config.h.in` in `$WORK` and leaves **both** real templates
un-refreshed, which is exactly the failure the guard exists to prevent.

**Correcting one thing that is easy to get wrong here:** this does *not* abort
the build. The generated script does start with `set -eu`
(`src/loader.lua:313`), but `touch` of a missing **file** in an existing
directory *creates* it and exits 0 — I verified both halves:

```
$ sh -eu -c 'touch aclocal.m4 configure config.h.in; echo SURVIVED'
SURVIVED
$ ls -l config.h.in
-rw-r--r-- 1 si si 0 … config.h.in          # zero bytes, exit 0
$ sh -eu -c 'touch aclocal.m4 configure no/such/dir/config.h.in'
touch: cannot touch 'no/such/dir/config.h.in': No such file or directory   # exit 1
```

So c-ares builds (and it has, it is `[x]` in the backlog). The defect is that
the guard is inert, not that it kills the block.

**Replace line 10 with:**

```
        touch aclocal.m4 configure src/lib/ares_config.h.in include/ares_build.h.in
```

The two subdirectory paths exist in the release tarball, so `touch` will find
them.

### 2. `packages/c-ares/generic.lua:6-8` — the comment is wrong twice

It reads:

```
        # Static library, headers and the pkg-config file. The tools
        # (adig, ahost, aadd) are host programs and stay off; the tests need
        # a network the build machine should not depend on.
```

- c-ares 1.34.8 has **no `aadd`**. The tool list is `adig ahost`
  (`src/tools/Makefile.am`, `PROGS = ahost adig`).
- `adig` and `ahost` are `noinst_PROGRAMS`, not host programs. `make all`
  **does** compile them — they are target programs that simply are not
  installed. Calling them "host programs" and saying they "stay off" is wrong on
  both counts, and the same mistake would lead a future maintainer to think
  `--disable-tools` is doing something.

**Replace lines 6-8 with:**

```
        # Static library, headers and the pkg-config file. The two sample
        # tools (adig, ahost) are noinst_PROGRAMS: they are compiled as
        # target programs but never installed, and there is no switch that
        # stops the compile. --disable-tests is the real cut, because the
        # test suite wants a live network the build machine should not
        # depend on; it is also already the default when cross-compiling.
```

### 3. Nothing else is required

`--enable-static --disable-shared --with-pic --disable-tests` are all real
options and all correct for a static target prefix. `make -j1` is serial.
`require("c-ares@source")` names no missing package. The six WILL BUILD
verdicts in `stage1.md` stand.

## Carried to the build

- `lib/libcares.a` — `llvm-objdump -f lib/libcares.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw).
- `include/ares.h`, `include/ares_build.h`, `include/ares_version.h` — `[ -f include/ares.h ] && [ -f include/ares_build.h ]`. `ares_build.h` is the one to look at: it is generated from the second config header, so its presence proves both templates resolved.
- `lib/pkgconfig/libcares.pc` — `pkg-config --modversion c-ares` → `1.34.8`.
- `bin/adig` and `bin/ahost` must be **absent** — they are `noinst`, so their appearing means the install picked up more than it should.
- The test suite must not be present: `ls lib | grep -c test` → 0.

---

## Rework verification

**REJECT** (this verdict supersedes line 1; line 1 is left as `REJECT`, so no
change was needed there.)

### Correctly fixed

- **Required change 1 is done and correct.** `packages/c-ares/generic.lua:12`
  reads

  ```
        touch aclocal.m4 configure src/lib/ares_config.h.in include/ares_build.h.in
  ```

  and both paths exist in the tree, verified independently of the adder:

  ```
  $ grep -m1 AC_CONFIG_HEADERS nest/source/c-ares/configure.ac
  AC_CONFIG_HEADERS([src/lib/ares_config.h include/ares_build.h])
  $ find nest/source/c-ares \( -name '*_config.h.in' -o -name 'ares_build.h.in' \)
  nest/source/c-ares/include/ares_build.h.in
  nest/source/c-ares/src/lib/ares_config.h.in
  ```

  Two directories, both named, nothing stray created. Guard position is right:
  `./configure` line 11, guard lines 12-13, `make -j1` line 14.
  `find . -name 'Makefile.in' | xargs touch` covers all 7, including
  `src/lib/`, `src/tools/`, `include/`, `docs/`, `src/` and `test/`.
- **Required change 2 is done, and the replacement comment is factually
  correct.** `generic.lua:6-10` now says the two tools are `noinst_PROGRAMS`,
  compiled as target programs but never installed, and that no switch stops the
  compile. I checked all three claims against the tree:

  ```
  $ cat nest/source/c-ares/src/tools/Makefile.am
  PROGS = ahost adig
  noinst_PROGRAMS =$(PROGS)
  $ grep -c -- '--disable-tools' nest/source/c-ares/configure
  0
  ```

  and there is no `aadd` anywhere in 1.34.8 (`find … -name '*aadd*'` returns
  nothing; the only matches for the string are the unrelated `aaddr` local in
  `lib/ares_gethostbyname.c`). So the old "host programs that stay off" claim is
  gone from the recipe and the replacement is true.
- The configure flags are all real and all package facts, not target facts:
  `--enable-static --disable-shared --with-pic --disable-tests`.
- Recipe hygiene is clean: `$AUTOCONF_CONFIGURE_FLAGS`, `$PREFIX`, `$OUT`,
  `$NESTDIR` only; no `export`, no `sed`, no `/dev/null`, no patch,
  `make -j1`. `require("c-ares@source")` resolves.

### Still wrong

The recipe is now clean, but **the rejected claim was not removed from the
  package — only from one file.** It survives verbatim in two other places, so
  the defect this stage2 rejected is still live for anyone reading the package:

- **`packages/c-ares/readme.md:37-39`** — "The command line tools (`adig`,
  `ahost`, `aadd`) and the test suite are off: host programs, and the tests want
  real network access." This is precisely the rejected sentence: wrong about
  `aadd` (it does not exist in 1.34.8), wrong about "host programs" (they are
  target programs), and wrong about "off" (they are compiled). It is also the
  file a consumer reads first. I am not permitted to edit `readme.md`.
  **Fix:** "The command line tools `adig` and `ahost` (there is no `aadd`) are
  `noinst_PROGRAMS`: they are compiled as target programs but never installed,
  and no switch stops that compile. Only the test suite is switched off, with
  `--disable-tests`, because it wants live network access and would also run
  target binaries."

- **`packages/c-ares/stage1.md:15`** — "Note that `generic.lua` does not disable
  the `adig`/`ahost`/`aadd` tools, so those get built too". Repeats the
  non-existent `aadd`. **Fix:** "`generic.lua` does not and cannot disable the
  `adig`/`ahost` tools — they are `noinst_PROGRAMS`, so they are always built
  and never installed".

- **`packages/c-ares/stage1.md:28-36`** — the whole "one claim I am least sure
  of" risk bullet is now stale: it quotes the recipe's old comment
  ("The tools (adig, ahost, aadd) are host programs and stay off",
  `generic.lua:7-8`) and asks the reader to settle it "cheaply by listing
  `$OUT/bin` after a build". The recipe no longer says that, and the question
  has already been answered from the tree. **Fix:** delete the bullet and
  replace it with the settled fact plus the citation
  (`src/tools/Makefile.am`: `PROGS = ahost adig`, `noinst_PROGRAMS = $(PROGS)`;
  no `--disable-tools` anywhere in `configure`).

- Minor drift, same cause: `stage1.md:11` cites `--disable-tests` at
  `generic.lua:9`; it is now line 11, and the guard is lines 12-13. Worth
  refreshing so a reader who follows the line numbers is not misled.

### Broken by the rework

Nothing. The guard rewrite did not lose a `Makefile.in` sweep and no flag was
  added or dropped.

## Rework verification — summary

Both required changes are correct in `generic.lua` and verified against the
  tree. Rejected because the false claim the review rejected — "host programs …
  stay off", plus a tool named `aadd` that does not exist — is still standing in
  `readme.md:38` and twice in `stage1.md`, so the underlying defect was papered
  over in one file rather than fixed.
