ACCEPT

# bc 7.0.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/bc/`. I did not build.

## What the recipe gets right

- The guard `touch aclocal.m4 configure config.h.in` is **harmless and
  correct-in-spirit**: verified in `nest/source/bc/`, `configure.ac` has **no**
  `AC_CONFIG_HEADERS` and the tree ships no `config.h.in`. The `touch` creates
  a stray empty file, but there is no template to protect, so nothing is lost.
  Drop `config.h.in` when the file is next edited:
  ```
          touch aclocal.m4 configure
  ```
  This is the cosmetic case, not the acl/attr/bison case where a *real*
  template is left unguarded.
- `require("readline")` is a real dependency, `packages/readline` exists, and
  bc 7.0.3 genuinely links it for the line editor. `make -j1` is serial.
- `android.lua` and `generic.lua` exist and the split is the AGENTS.md
  one-file-per-family pattern, not a per-target copy.

## One thing the forecast should state

bc 7.0.3 is the newest release (7.1.0 exists upstream as a later tag; if this
recipe is on 7.0.3, `stage1.md` should say why — LFS pins 7.0.3, and matching
the book's version is a legitimate reason, but it should be written down
rather than left as an omission). That is a version-policy question, not a
defect.

## Carried to the build

- `bin/bc`, `bin/dc` — `[ -x bin/bc ] && [ -x bin/dc ]`.
- `lib/libbc.a` — `[ -f lib/libbc.a ]` if the build produces it; record whether it is installed, because bc's `Makefile.am` decides this and the artifact list should match.
- `include/` — bc is header-light; check for `bc/` or `proto.h` if `stage1.md` claims headers.
- `$PREFIX/lib/libreadline.so` or `.a` must be present, because bc links readline. If readline is a different shape than the recipe expects, the link is where it shows.
- No `.pc` unless the tarball ships one.
- **Never run `bin/bc`.**

## Rework verification

**Verdict: ACCEPT.** First line stays `ACCEPT`.

### The brief's premise is half right, and that changes the check

The brief asked me to "verify the autotools timestamp guard names the config
template each package really ships … and that the guard sits AFTER
`./configure` and BEFORE make", and gave five candidate spellings. That
question has a different answer for bc than for findutils, and it is worth
stating plainly rather than forcing into the template:

**bc has no autotools build and therefore no timestamp guard, and correctly
has none.** Verified in the unpacked tree — none of these exist:

```
$ ls nest/source/bc/aclocal.m4 nest/source/bc/configure.ac nest/source/bc/config.h.in
ls: cannot access 'nest/source/bc/aclocal.m4': No such file or directory
ls: cannot access 'nest/source/bc/configure.ac': No such file or directory
ls: cannot access 'nest/source/bc/config.h.in': No such file or directory
```

bc ships GNU bc's own hand-written `configure` (generated from
`configure.sh`; both are present, along with a hand-maintained
`Makefile.in`). `stage1.md:5` and `:29-32` already say exactly this, and
`stage1.md:30` is right that running the standard guard "would fail on a
missing `aclocal.m4`" — under the emitted `set -eu`, `touch` on a missing
*file* in an existing directory is a no-op, but this package should not be
running the idiom at all.

So: the five-spelling question resolves to **"none of the five"** for bc, and
the guard-position question resolves to **"not applicable"**. `generic.lua`
and `android.lua` both correctly omit it. This is the cosmetic case
`stage2.md:10-19` described, arrived at by omission rather than by a stray
`touch` — strictly better than `file`'s, which is also cosmetic but leaves a
bogus empty `config.h.in` behind.

Worth saying explicitly for the next reviewer: **do not "fix" this omission.**
Adding the guard to bc would be a regression.

### What the recipes get right

- `generic.lua:11` / `android.lua:15` are the only two real lines, and the
  one-file-per-family split is the AGENTS.md pattern reached by
  `recipe_fallbacks = {"android"}` — the same mechanism ffmpeg uses, verified
  the same way (56 of 57 system dirs declare it; only `x86_64-mingw` and
  `clang-native` do not). No per-target copies.
- `--prefix="$OUT"` passed explicitly rather than via `$AUTOCONF_CONFIGURE_FLAGS`
  is **correct** for a hand-written configure: bc's `configure` does not
  accept `--host`/`--build`, and ffmpeg-style `$HOST_ARCH` reading is the
  pattern for that class. `stage1.md:33-37` is right, and there is no target
  fact hardcoded here.
- `CC="$CC -std=c99"`, `HOSTCC="cc"`, `HOSTCFLAGS="-std=c99"`,
  `--disable-nls` (`android.lua:11`) — bc's *generators* build for the host
  while `bc` itself targets Android, and Android has no message-catalog
  functions. This is deliberate, correct wall-avoidance, and it is the reason
  `android.lua` exists.
- `make -j1 LDFLAGS="$LDFLAGS -lreadline -ltermcap"` re-expands `$LDFLAGS` so
  `-L$PREFIX/lib` survives while appending the termcap that bc's custom
  configure omits from its static Readline link. Correct, and the re-expansion
  is the subtle part — dropping it would silently lose the search path
  (`stage1.md:38-41`).
- `make install` (no `-j1`) on both: an install target, not a compile.
- `require("readline")` and `require("bc@source")` both name real packages.

### Damage check

No `export` of search flags in either recipe, no `sed`/`patch`/`/dev/null`, no
`$NATIVE_PREFIX` misuse, no `config.status` clobbering. Nothing broken by the
adder — nothing was touched.

### The mingw row and the version note

`stage1.md:15` keeps mingw as **UNCERTAIN** with an honest account of what it
could not settle, and `stage2.md:27-31`'s version-policy note (7.0.3 vs the
7.1.0 upstream tag) is documentation-only. Neither is a recipe defect and
neither needs action in this wave.

### Target-binary execution

Not applicable — bc builds and installs programs and never runs one of its own
output. `HOSTCC="cc"` is the *host* compiler, which is exactly the sanctioned
direction: running a build-host tool is fine, running a target artifact is not.
