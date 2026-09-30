REJECT

# elfutils 0.193 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/elfutils/`. I did not build.

The guard here is **correct** — one of only three in the shard where
`config.h.in` is genuinely the right file. The rejection is about the build
scope.

## Required changes

### 1. `packages/elfutils/generic.lua:16` — `make -j1` builds the entire tree, not libelf

```
        make -j1
        make -j1 -C libelf install
```

The install is narrow, which is the right instinct, but the **build** is not.
elfutils' top-level `Makefile` recurses through `libdw`, `libdwfl`, `libelf`,
`libstack`, `libbacktrace`, `backends/` and `tests/`, so this compiles
dozens of libraries and elfutils' entire test suite, then throws all of it
away except `libelf`. On a cross build every one of those is a *target*
binary, which is wasted work and a large extra failure surface.

`stage1.md:26-29` calls this out as "the single most promising lead for
unblocking elfutils" and then says it did not check whether a configure
switch exists. It should have — the answer determines whether the package is
recoverable at all, and it is cheap to read from `configure.ac`:

```
$ grep -n "libdw\|libdwfl\|libstack\|libbacktrace\|AC_ARG_ENABLE" nest/source/elfutils/configure.ac
```

**Required:** if elfutils 0.193 has a switch that drops `libdw`/`libdwfl`
(the blocker is `argp`, which only `libdwfl`/`libdw` use), add it to the
`./configure` line with a comment naming argp as the reason. If it has no such
switch, say so explicitly in the recipe comment and in `topackage.md`, because
then the honest answer is that this recipe cannot work on Bionic at any API
level and the package should be dropped rather than left looking pending.

Either way, do **not** leave a bare `make -j1` at the top level next to a
`-C libelf install` — that mismatch is the defect.

### 2. `packages/elfutils/generic.lua:11-13` — the flags address the wrong problem

```
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
```

These are correct as far as they go (debuginfod is not reachable from a build
machine, and `=dummy` is the documented way to say so), and the comment is
honest that they address reachability rather than argp. Keep them. The
missing flag is the one from change 1.

### 3. Nothing else is required

- `generic.lua:14` `touch aclocal.m4 configure config.h.in` is **correct**:
  verified in `nest/source/elfutils/`, `AC_CONFIG_HEADERS([config.h])` and
  `config.h.in` is present at the top level. `stage1.md:47-49` is right, and it
  is worth saying louder, because the rest of this shard mostly gets it wrong.
- `require("bzip2")`, `require("xz")`, `require("zlib")` are all real and all
  exist. `stage1.md:44-46` is right that they are needed by the whole tree,
  not just libelf.
- The hand-copied `cp config/libelf.pc $OUT/lib/pkgconfig/` is a deviation
  from "ordinary upstream install steps" but is explained, and
  `lib/pkgconfig/*.pc` is inside the loader's `$OUT`→`$PREFIX` rewrite set, so
  it works.

## The `argp` blocker, verified

`argp_parse` is a GNU C library extension. Bionic has never had it and never
will, at any API level, so **no new `aarch64-androidNN` directory unblocks
this** — unlike `nl_langinfo` (26), `mktime_z` (35) or `stderr` (23), which
are all real `__INTRODUCED_IN` gates. That distinction is the one thing
`topackage.md` should record for elfutils, and `stage1.md:20-29` gets it
right.

## Carried to the build

Not buildable on any cross target today. On `clang-native`, where `<argp.h>`
exists:

- `lib/libelf.a` — `llvm-objdump -f lib/libelf.a | head -3`; host x86_64 ELF on `clang-native`, `elf64-littleaarch64` on a target.
- `include/libelf.h`, `include/gelf.h` — `[ -f include/libelf.h ] && [ -f include/gelf.h ]`.
- `lib/pkgconfig/libelf.pc` — `pkg-config --modversion libelf` → `0.193`.
- `ls $OUT/lib` must show **libelf and nothing else**. `libdw.so`, `libdwfl.so` or `libstack.so` appearing means the narrow install regressed and the package is installing far more than intended.

---

## Rework verification

**Verdict: REJECT.** The decisive question stage2 left open is now
answered, and the recipe comment answers it correctly — but the recipe
still contains the exact construct stage2 ordered removed, and the answer
it reaches makes that construct *more* misleading, not less.

### THE DECISIVE QUESTION: elfutils 0.193 has no switch to avoid the whole tree

stage2 required a yes/no from `configure.ac`. The answer is **no**, and it
is not a judgement call — it is the complete set of options the shipped
`configure` accepts. I enumerated every `--enable-*`, `--disable-*`,
`--with-*` and `--without-*` token in `./configure --help`: 47 of them,
and not one drops `libdw`, `libdwfl`, `libstack`, `libbacktrace`, `libebl`
or `tests/`:

```
--disable-FEATURE --disable-demangler --disable-dependency-tracking
--disable-largefile --disable-nls --disable-option-checking --disable-rpath
--disable-silent-rules --disable-symbol-versioning --disable-textrelcheck
--enable-FEATURE --enable-debuginfod --enable-debuginfod-ima-cert-path
--enable-debuginfod-ima-verification --enable-debuginfod-urls
--enable-debugpred --enable-dependency-tracking
--enable-deterministic-archives --enable-gcov --enable-gprof
--enable-helgrind --enable-install-elfh --enable-libdebuginfod
--enable-maintainer-mode --enable-sanitize-address --enable-sanitize-memory
--enable-sanitize-undefined --enable-silent-rules --enable-stacktrace
--enable-tests-rpath --enable-thread-safety --enable-valgrind
--enable-valgrind-annotations --enable-year2038
--with-PACKAGE --with-biarch --with-bzlib --with-gnu-ld
--with-libiconv-prefix --with-libintl-prefix --with-lzma --with-valgrind
--with-zlib --with-zstd --without-PACKAGE --without-libiconv-prefix
--without-libintl-prefix
```

There is no `--disable-libdw`, no `--disable-libdwfl`, no `--disable-tests`.
The `SUBDIRS` line is unconditional:

```
$ grep -n '^SUBDIRS' nest/source/elfutils/Makefile.am
31:SUBDIRS = config lib libelf libcpu backends libebl libdwelf libdwfl \
```

and the only switches that even *mention* the test tree or `libdwfl` are
`--enable-helgrind`, `--enable-valgrind`, `--enable-tests-rpath` and
`--with-biarch`, none of which removes a directory from `SUBDIRS`, plus the
four `--with-{zlib,bzlib,lzma,zstd}` compression options, which affect
`libdwfl` *features* rather than whether `libdwfl` is built.

**So: the recipe should not use such a switch, because none exists.** The
answer to "is elfutils recoverable" is that it is not recoverable by
configuration. `argp_parse` is required unconditionally at top level:

```
$ sed -n '650,658p' nest/source/elfutils/configure.ac
saved_LIBS="$LIBS"
AC_SEARCH_LIBS([argp_parse], [argp])
LIBS="$saved_LIBS"
case "$ac_cv_search_argp_parse" in
        no) AC_MSG_FAILURE([failed to find argp_parse]) ;;
        -l*) argp_LDADD="$ac_cv_search_argp_parse" ;;
        *) argp_LDADD= ;;
esac
AC_SUBST([argp_LDADD])
```

Not inside any `AS_IF`, no `AC_ARG_ENABLE` guarding it, and nothing in the
47-option list can pre-set `ac_cv_search_argp_parse`. `argp_parse` is a
GNU libc extension; I confirmed the prefix's Android sysroot carries no
`argp.h` at all (`find nest/aarch64-android21 -name argp.h` → nothing), so
this is not API-level gated and no new `aarch64-androidNN` directory
changes it. **The honest conclusion is that this recipe cannot work on
Bionic at any API level, and per stage2 the package should be dropped from
the target list rather than left looking pending.**

### What the recipe got right

`generic.lua:12-25` is an accurate, well-evidenced answer to the question,
and it is a genuine improvement over the version stage2 saw. It names
`configure.ac:649-656` for the `argp` block (the `AC_SEARCH_LIBS` is at
`:651` and the `AC_MSG_FAILURE` at `:654` — the cited span is right), it
states that the check is "at top level, not inside any `AS_IF`" (true), it
correctly concludes that no `--disable-libdw`/`--disable-libdwfl` exists,
and it correctly notes Bionic lacks argp at every API level. The guard is
right: `configure.ac:53` is `AC_CONFIG_HEADERS([config.h])` and
`nest/source/elfutils/config.h.in` exists at the top level, positioned
after `./configure` (`:26-28`) and before `make` (`:31`), with
`find . -name 'Makefile.in' | xargs touch` (`:30`) covering all sixteen
`Makefile.in` files including `libdw/`, `libdwfl/`, `backends/` and
`tests/`.

### STILL WRONG — `generic.lua:31-32` is the construct stage2 ordered removed

```
31:        make -j1
32:        make -j1 -C libelf install
```

stage2 was explicit: *"Either way, do **not** leave a bare `make -j1` at
the top level next to a `-C libelf install` — that mismatch is the
defect."* It is still there. Required change 1 was not performed; only the
commentary around it was.

The new comment does not excuse it. It argues the `-C libelf install` "is
never reached" on Bionic because `configure` fails first. That is true on
the five Android/mingw targets and **false on `clang-native`**, where
configure succeeds precisely because the host has `<argp.h>`. So on the
one system where the build can proceed at all, `make -j1` still compiles
the entire tree — `libdw`, `libdwfl`, `libstack`, `libbacktrace`,
`backends/` and elfutils' full test suite — and then line 32 throws
everything except `libelf` away. The wasted work is all *target* code on a
cross build, which is the specific cost stage2 named.

And the fix does **not** require a configure switch, which is the point
the comment misses. `libelf` builds standalone: its `Makefile.in:116`
needs only `$(top_builddir)/config.h`, which `./configure` already
generated, and `config/eu.am:34` gives it `-I$(top_srcdir)/lib` for
`common.h`/`abstract.h`. So the honest recipe is:

```
        make -j1 -C libelf
        make -j1 -C libelf install
```

or simply drop the bare `make -j1` and keep `-C libelf install`, which
implies the build. That removes the whole-tree compile from every system
without inventing a flag that does not exist — and it means the package
could plausibly build on a target that merely lacks argp, which is a
different and much more useful outcome than "blocked". That possibility
should be tested before the package is dropped, not assumed away.

### The claim the recipe comment makes that I cannot support

`generic.lua:22-25` asserts the package is unbuildable on Bionic and that
the `-C libelf install` "is never reached". The first half is right about
*this* recipe, but it is stated as a property of elfutils when the
narrow-install variant I describe above is untested. Given `configure` is
the only thing that needs argp, and `libelf` itself does not, the
comment's framing forecloses a question that is still open. Narrow the
claim to what is verified — "`configure` fails, so *this recipe* cannot
build on Bionic" — and note the untested `-C libelf`-only variant.

### Also worth recording

`stage1.md:37-39` still poses the `--disable-libdwfl` question as open ("I
did not check, and I am not permitted to configure it") and calls it "the
single most promising lead for unblocking elfutils". That lead is now
closed — there is no such flag — and `stage1.md` should say so, since the
file is what the next person reads. The recipe comment has the answer;
`stage1.md` does not.

`generic.lua:33-34`'s hand-copy of `config/libelf.pc` is correct and
necessary: `config/Makefile.am:37` has `pkgconfig_DATA = libelf.pc libdw.pc`,
so the `.pc` is installed by `make -C config install`, *not* by
`make -C libelf install`. Keeping the copy is right.

---

## Addendum (after the build) — the rework's premise was tested and failed

Added after `stage3.md`; the review text above is left as written, because it
is the record of what was argued at review time. This section states what the
build proved.

**The open question the rework raised has now been answered, and it goes
against the rework.** The rework argued that `-C libelf` needed no configure
switch, because "the package could plausibly build on a target that merely
lacks argp". `stage3.md` built it on `aarch64-android24` and it does not:

```
checking for library containing argp_parse... no
configure: error: in '/home/si/ond/git/retrolunar/nest/tmp/work-YX94fe':
configure: error: failed to find argp_parse
See 'config.log' for more details
```

`configure.ac:650-658` is top-level and unconditional — verified directly, not
inferred from the log: line 648 closes its `AS_IF`, line 650 opens a fresh
statement, and nothing between them is an `AS_IF`/`AC_ARG_ENABLE`/`AM_CONDITIONAL`.
`AC_OUTPUT` therefore never runs, so no `config.h` and no `Makefile` exist and
`make -C libelf` has nothing to descend into. The "libelf compiles standalone"
argument is true about libelf and irrelevant to the build order: `./configure`
is what produces the `config.h` libelf needs.

**What survives from the rework.** The `make -j1 -C libelf` /
`make -j1 -C libelf install` scoping is correct and stays. It is not a rescue
— the blocker is upstream of it — but it does stop `clang-native` (the one
system whose glibc has `<argp.h>`) compiling `libdw`, `libdwfl`, `libstack`,
`libbacktrace`, `backends/` and the full test suite just to discard them. That
is the cost this review named, and it is still worth naming it for.

**What does not survive.** Any suggestion that elfutils is "pending" or
"plausibly buildable" on Android. It is not buildable on Bionic at any API
level: `argp_parse` is a glibc extension with no `__INTRODUCED_IN` gate, unlike
`nl_langinfo` (API 26) or `posix_spawn` (API 28), so no new
`aarch64-androidNN` target helps. There is no switch, no cache answer that
works, and the only real routes — an upstream patch to `configure.ac:650-658`
or a stub `libargp` — are forbidden by AGENTS.md. The honest outcome is that
elfutils 0.193 does not build here, and the record should say so rather than
leave a reader looking for the switch that does not exist.
