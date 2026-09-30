REJECT

# gettext 0.26 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/gettext/`. I did not build.

**The forecast is the best in this shard** — it independently found the serial
build violation and cross-referenced `grep` and `gzip`, which is exactly right.
The recipe has one hard-rule violation and one latent trap.

## Required changes

### 1. `packages/gettext/generic.lua:24` — `make` without `-j1` violates the serial-build rule

```
        make
```

AGENTS.md: *"Build serially: use `make -j1` or the build tool's equivalent
single-job option."* This matters more here than anywhere else in the shard:
gettext is libintl + libasprintf + libtextstyle + ~30 tools, so a
full-width parallel build is both a log-readability problem and a real
peak-memory one.

**Replace line 24 with:**

```
        make -j1
```

`make install` on line 25 is an install target, not a compile, so it stays.

### 2. `packages/gettext/generic.lua:22` — the guard names a file gettext does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree — gettext has **no top-level config
header at all**, and five templates in subdirectories:

```
$ grep -m1 AC_CONFIG_HEADERS nest/source/gettext/configure.ac
(no match)
$ find nest/source/gettext -maxdepth 3 -name 'config.h.in'
nest/source/gettext/gettext-runtime/config.h.in
nest/source/gettext/gettext-runtime/intl/config.h.in
nest/source/gettext/gettext-runtime/libasprintf/config.h.in
nest/source/gettext/gettext-tools/config.h.in
nest/source/gettext/libtextstyle/config.h.in
$ ls nest/source/gettext/config.h.in
ls: cannot access ...: No such file or directory
```

**Replace line 22 with:**

```
        touch aclocal.m4 configure
```

and, if the sub-configures are to be protected as well, extend the existing
`find` sweep rather than listing them:

```
        find . -name 'config.h.in' | xargs touch
```

**This does not fail today's build** — `touch` of a missing file in an existing
directory exits 0 (verified under the emitted `set -eu`; only a missing
*directory* aborts). The guard is inert rather than fatal.

### 3. `packages/gettext/generic.lua:21` — the docdir hardcodes the version

```
            --docdir=$OUT/share/doc/gettext-0.26
```

The version is in the path while `version` already lives in `source.lua`. A
version bump that forgets this line puts the docs in a directory named for the
previous release, and nothing catches it. Either drop the flag so upstream's
default applies, or derive it. Cosmetic but real, and `stage1.md:60-62` already
raises it.

### 4. Nothing else is required

`CFLAGS="$CFLAGS -Wno-error=incompatible-function-pointer-types"` +
`export CFLAGS` at lines 17-18 is the **sanctioned** recipe-local exception:
AGENTS.md permits a recipe-local workaround "with a comment explaining why",
and the comment at lines 7-16 is unusually precise (it names the diagnostic,
the source line, and says the link still fails afterwards). It is honestly
documented and honestly scoped. `--disable-static` is the conventional choice
for gettext and the comment-free case is fine. `chmod 0755
$OUT/lib/preloadable_libintl.so` is outside AGENTS.md's literal build-body
list, but it is a plain mode fix for a file whose documented use is
`LD_PRELOAD`, and the comment explains it. Keep both.

**The `x86_64-android35` / `aarch64-android35` row is the thing to test
first.** `stage1.md:13` is right that 35 ≥ 28 means the iconv probe should
succeed there and the recorded link failure should *not* apply. If that holds,
the blocker is API-level and the recipe's unconditional `-Wno-error` (which
`stage1.md:29-32` notes was written for the Android case) should be revisited.

## Carried to the build

Not buildable until the iconv problem is resolved. After that, on an API-35
target:

- `lib/libintl.so` — `llvm-objdump -f lib/libintl.so | head -3` → `elf64-littleaarch64`, and `llvm-objdump -p` shows `Type: DYN`.
- `lib/libasprintf.so`, `lib/preloadable_libintl.so` — `[ -f lib/libasprintf.so ] && [ -f lib/preloadable_libintl.so ]`.
- `lib/preloadable_libintl.so` mode — `ls -l lib/preloadable_libintl.so` must show `755`, not `644`. That is the direct check for the `chmod`.
- `include/libintl.h` — `[ -f include/libintl.h ]`.
- `bin/gettext`, `bin/ngettext`, `bin/xgettext`, `bin/msgfmt` — `[ -x bin/msgfmt ]`. Target programs; never run them.
- `share/doc/gettext-0.26/` — and the directory name must match the pinned version.
- No `.pc`; gettext ships none.

## Rework verification

**REJECT** — first line stays `REJECT`. Two of the three required changes are
correctly done; the guard change was made in the shape that leaves it inert.

### Correctly fixed

**Required change 1 (`make` → `make -j1`):** done.
`packages/gettext/generic.lua:24` is `make -j1`. `make install` on line 25 is
left unflagged, as this file said it would be.

**Required change 3 (`--docdir` hardcoding the version):** done, and the
comment's factual claim checks out. `packages/gettext/generic.lua:19-20` now
says "No --docdir: upstream's default already lands under $OUT". Verified:

```
$ grep -n "^docdir=" nest/source/gettext/configure
819:docdir='${datarootdir}/doc/${PACKAGE_TARNAME}'
$ grep -m1 "PACKAGE_TARNAME=" nest/source/gettext/configure
PACKAGE_TARNAME='gettext'
```

and `$AUTOCONF_CONFIGURE_FLAGS` carries `--prefix=$OUT` (AGENTS.md:319), so the
default resolves to `$OUT/share/doc/gettext` — under `$OUT`, and with no
version literal anywhere in the recipe. Dropping the flag was explicitly one
of the two sanctioned options in Required change 3, so this is not a
deviation. The stale `gettext-0.26` path is gone.

**Nothing else was damaged.** `CFLAGS="$CFLAGS -Wno-error=..."` + `export
CFLAGS` with the 10-line explanatory comment (lines 7-18) are intact, as this
file's §4 said to keep them; `--disable-static` is on line 21 and still takes
its flags from `$AUTOCONF_CONFIGURE_FLAGS`; `chmod 0755
$OUT/lib/preloadable_libintl.so` survives at line 28 with its comment;
`require("gettext@source")` names a package that exists; no `sed`, no patch,
no `/dev/null`, no `-j$(nproc)`.

### Still wrong — the guard names zero config templates

`packages/gettext/generic.lua:22-23`:

```
        touch aclocal.m4 configure
        find . -name 'Makefile.in' | xargs touch
```

This is the letter of Required change 2's primary instruction and nothing
more. gettext has **no top-level template by design**, so of the two files
named, neither is a config template — the guard as written touches no
`AC_CONFIG_HEADERS` target at all, which is the whole reason the guard exists.

AGENTS.md:245-246 is not optional here, and it names this package specifically:

> none at top level — gmp generates `config.in`, gettext has no top-level
> template; **guard the files it does have**

The files it does have are five, all verified present:

```
$ find nest/source/gettext -name 'config.h.in'
nest/source/gettext/gettext-runtime/config.h.in
nest/source/gettext/gettext-runtime/intl/config.h.in
nest/source/gettext/gettext-runtime/libasprintf/config.h.in
nest/source/gettext/gettext-tools/config.h.in
nest/source/gettext/libtextstyle/config.h.in
```

**Fix — insert after line 22, before the existing `Makefile.in` sweep:**

```
        find . -name 'config.h.in' | xargs touch
```

`find` only yields files that exist, so this cannot create the stray-file
problem this wave is about. gettext also ships sub-`configure` and
sub-`aclocal.m4` for each of those five sub-configures, so the complete guard
would add `find . -name 'configure' | xargs touch` as well; the
`config.h.in` sweep is the one AGENTS.md asks for and the one that closes the
autoheader hole.

### Where the original review was too soft

Required change 2 offered the sub-configure sweep as conditional — "and, **if**
the sub-configures are to be protected as well, extend the existing `find`
sweep". For every other package in the wave the sub-configure sweep was
phrased as an instruction; here the conditional wording is what let an
inert guard through as a fix. Given AGENTS.md:246 says "guard the files it
does have" in the mandatory rule itself, the sweep should have been the
prescribed form, not the optional one. This is the single most useful
correction from this review round.

### Knock-on to this file

`stage2.md:114` still tells the build to check `share/doc/gettext-0.26/` and
that "the directory name must match the pinned version". Required change 3
deliberately stopped producing a version-stamped directory, so the build
should now look for `share/doc/gettext/` and assert only that it is under
`$OUT`.
