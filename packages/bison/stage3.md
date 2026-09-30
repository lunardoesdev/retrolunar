# bison 3.8.2 — stage 3 build record

Built and published on `clang-native`. This file records a **real defect in
the published binary** that no previous stage caught, the fix, and the
evidence. It also records a tree-wide hazard that affects every `@native`
require and is written down nowhere else.

## 1. The defect: the published bison was installed and broken

`require("@native")` builds bison, `make install` fills `$OUT`, and the
loader publishes with `cp -rf "$OUT"/. "$NESTDIR/<sys>/"` before
`rm -rf "$OUT"` (`src/loader.lua:471-473`). That is a *copy*: it cannot
rewrite a path that is already compiled into an ELF image.

Bison bakes its data directory in. `Makefile.in:12075`:

```
	  echo '#define PKGDATADIR "$(pkgdatadir)"'; \
```

That lands in `lib/configmake.h` and is read at `src/files.c:549-557`:

```c
char const *
pkgdatadir (void)
{
  if (relocate_buffer)
    return relocate_buffer;
  else
    {
      char const *cp = getenv ("BISON_PKGDATADIR");
      return cp ? cp : relocate2 (PKGDATADIR, &relocate_buffer);
    }
}
```

`PKGDATADIR` is `${datadir}/bison` = `$OUT/share/bison`, and `datadir`
derives from `--prefix` (`configure.ac` sets no `datadir` override; the
`gl_CONFIGMAKE_PREP` default is `${datarootdir}`). So the baked path is
**`--prefix`-derived**, not `--datarootdir`-derived and not a configure
default. It is a *literal absolute path* in `.rodata`.

**Evidence — before.** `nest/clang-native/bin/bison` (x86-64, verified with
`file` before executing):

```
$ strings -a nest/clang-native/bin/bison | grep -E 'out-|nest/tmp' | sort -u
/home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/bison
/home/si/ond/git/retrolunar/nest/tmp/out-LTM8ZA/share/locale
```

`out-LTM8ZA` is a `mktemp -d` staging dir that no longer exists. Two baked
paths, both load-bearing or near it: `PKGDATADIR` (skeletons, m4sugar,
XSLT — `src/output.c:725-727`, `src/print-xml.c:545`) and `LOCALEDIR`
(`src/main.c:77`, itself via `relocate2`).

**The premise in the report was correct**, and it reproduces on the Android
prefix too — `nest/aarch64-android24/bin/bison` contains
`/home/si/ond/git/retrolunar/nest/tmp/out-7AyGCF` (checked statically with
`grep -a`; **not** executed, per the no-emulation rule).

**Observed failure** (host x86-64 native binary, safe to run):

```
$ printf '%%%%\ns : s "x" | ;\n%%%%\n' > /tmp/v.y
$ ./nest/clang-native/bin/bison -o /tmp/v.tab.c /tmp/v.y
./nest/clang-native/bin/bison: /home/si/.../nest/tmp/out-LTM8ZA/share/bison/m4sugar/m4sugar.m4: cannot open: No such file or directory
rc=1
```

Note `--version` still worked. That is why this hid: the binary is
*installed*, answers `--version`, and only fails the moment it does real
work. A green "artifact exists" check is not a working-tool check.

## 2. The fix: `--enable-relocatable`

**Real option name: `--enable-relocatable`**, default **OFF**
(`m4/relocatable-lib.m4:36-45`, `gl_RELOCATABLE_NOP`). `--help` reads
"install a package that can be moved in the file system". It does **not**
just relink; it is the switch that makes the *program* resolve its own
prefix at runtime:

1. `m4/relocatable-lib.m4:25-28` — `#define ENABLE_RELOCATABLE 1`, and
   `INSTALLPREFIX` = the configured `--prefix` (line 20-24).
2. `lib/progname.h:39-49` — under `#if ENABLE_RELOCATABLE`,
   `set_program_name(ARG0)` becomes a macro for
   `set_program_name_and_installdir (ARG0, INSTALLPREFIX, INSTALLDIR)`.
   `src/main.c:73` calls `set_program_name (argv[0])`, so the hook is
   already in place; no bison-specific change is needed.
3. `lib/progreloc.c:425-439` `prepare_relocate()` resolves `argv[0]` via
   `find_executable()`, calls `compute_curr_prefix()`
   (`lib/relocatable.c:196`) to derive the *current* prefix by stripping
   the relative install dir, then `set_relocation_prefix()`.
4. `lib/relocatable.c:521-553` — `relocate()` rewrites any path starting
   with the compiled-in `orig_prefix` to the live `curr_prefix`.

So: the baked `orig_prefix` is still compared with `strncmp` (it has to
be), but the *used* path becomes the live one. The string
`$OUT/share/bison` necessarily remains in `.rodata`; **the loader cannot
and must not remove it.** The correct post-fix check is behavioural, not
`strings`-based.

Placement: **`generic.lua`**, because the defect is a property of the
*loader's publish step*, which is byte-identical for every system
(`src/loader.lua:470-473` is emitted per block regardless of `sys`). It is
not an Android/NDK fact. A `<sys>.lua` would leave native, mingw and every
Android target broken. Upstream's own `case "$host_os"` in
`m4/relocatable.m4:47-120` selects the *mechanism* per platform (ELF
`$ORIGIN` on glibc, a `install-reloc` wrapper on `linux*-android*`), which
is upstream's problem to solve, not ours.

## 3. Verification (built, not asserted)

Freshness was invalidated first — stamp deleted *and* the stale artifacts
removed, so a green skip could not masquerade as a build:

```
rm -f nest/clang-native/.retrolunar-bison
rm -f nest/clang-native/bin/bison nest/clang-native/bin/yacc
rm -rf nest/clang-native/share/bison nest/clang-native/share/locale
./builddir/retrolunar install --nest ./nest --packages ./packages 'bison@clang-native' > /tmp/b.sh
sh -n /tmp/b.sh && sh /tmp/b.sh          # BUILD rc=0
```

The generated script's bison block is the one carrying the flag
(line 283; line 128 is gperf's, untouched).

**Runtime resolution — the actual proof.** `file` confirmed
`ELF 64-bit LSB pie executable, x86-64` *before* executing:

```
$ ./nest/clang-native/bin/bison --print-datadir
/home/si/ond/git/retrolunar/nest/clang-native/share/bison     <-- published prefix, not out-go04VR
$ ls nest/clang-native/share/bison/
README.md  bison-default.css  m4sugar  skeletons  xslt
```

**The operation that failed before now succeeds** — this is the same
command, same grammar, that produced `m4sugar.m4: cannot open` earlier:

```
$ ./nest/clang-native/bin/bison -o /tmp/v.tab.c /tmp/v.y
rc=0
$ ls -l /tmp/v.tab.c
-rw-r--r-- 1 si si 39033 ... /tmp/v.tab.c
```

Seven skeletons load from the published data dir:

```
$ for s in glr.c glr.cc glr2.cc java-skel.m4 d-skel.m4 lalr1.cc lalr1.java c.m4; do ...
glr.c      OK (78818 bytes)     glr.cc     OK (89644 bytes)
glr2.cc    OK (98712 bytes)     java-skel.m4 OK (24718 bytes)
d-skel.m4  OK (19454 bytes)     lalr1.cc   OK (41647 bytes)
lalr1.java OK (24716 bytes)     c.m4       OK (24716 bytes)
```

**End-to-end**: the published bison generated a parser, it compiled, and
the result ran.

```
$ nest/clang-native/bin/bison -o calc.tab.c calc.y && cc -o calc calc.tab.c && ./calc
bison rc=0 ; parser rc=0
```

**True relocation, not a hardcoded path** — copied the prefix elsewhere and
it followed:

```
$ cp -r nest/clang-native/{bin,share} /tmp/relocated/
$ /tmp/relocated/bin/bison --print-datadir
/tmp/relocated/share/bison
$ /tmp/relocated/bin/bison -o /tmp/reloc.tab.c /tmp/v.y ; echo $?
0
```

`nest/clang-native/bin/yacc` is a POSIX shell wrapper that execs `bison`;
it works (`yacc rc=0`).

Freshness re-check after the build: rerun prints
`skip bison@clang-native (fresh)`, so the stamp is real.

**Consumer proof.** `libnl-3@clang-native` (`packages/libnl-3/generic.lua`
requires `bison@native`) builds its parser by running bison:

```
$ grep -n 'bison -y -d' /tmp/nl.log
442:/bin/sh ../build-aux/ylwrap parse.y y.tab.c parse.c y.tab.h ... -- bison -y -d
443:updating parse.h
```

bison ran and produced `parse.c`/`parse.h` — this is precisely the call
that could not have worked before. **libnl-3's build then fails for an
unrelated reason, not recorded as bison's:** `automake-1.15` and
`help2man` are absent and `tests/Makefile.in` wants to regenerate itself
(`Makefile:1789: Makefile.in Error 127`). Not worked around — out of scope
for this package, and it is a `tests/`-directory tooling gap.

## 4. flex and gperf: investigated, no defect — do not touch

Both were checked because they are the other two `@native` tools
`libnl-3` and `libseccomp` depend on.

- **gperf** — no baked path at all.
  `grep -a -o '/[^ "]*out-[^ "]*' nest/clang-native/bin/gperf` returns
  nothing, and gperf has no data files: `grep -rn 'datadir\|gperfdir'`
  over `src/*.c src/*.h configure.ac` finds nothing. `./configure --help
  | grep -i relocat` → **no such option**. It is a pure code generator.
  **This is the counterexample that identifies the real mechanism:**
  `libseccomp` built successfully not because gperf is special, but
  because **gperf bakes no path at all**. The thing that matters is
  whether a program bakes a path it needs at runtime, not whether it is
  "relocatable-capable".
- **flex** — no relocatability option (`--help | grep -i relocat` → none).
  Its only baked path is `M4`, `configure.ac:105`:
  `AC_DEFINE_UNQUOTED([M4], ["$M4"])`. That resolves to
  `$NATIVE_PREFIX/bin/m4` — the **published** native prefix, not a staging
  dir — and flex has no data-file lookup of its own. So flex is fine and
  was not modified.

## 5. Tree-wide: baking a staging path is not automatically a defect

Scanning every ELF in the native prefix for `nest/tmp/out-`:

| binary | baked staging path | broken? |
|---|---|---|
| `bison` | `out-go04VR/share/bison`, `out-go04VR/share/locale` | **was**, now fixed |
| `m4` | `out-lnoclW/share/locale` | no |
| `file` | `out-LlbAvN/lib` | no |
| `gperf`, `perl` | none | n/a |

`m4` and `file` also bake a staging path and still work, so "bakes `$OUT`"
is a *smell*, not the defect. The discriminator is whether the baked path
is **load-bearing**. `m4` uses its path only in
`src/m4.c:429 bindtextdomain (PACKAGE, LOCALEDIR)` — a gettext locale
*hint* that degrades silently; `nest/clang-native/bin/m4 --version` and a
real `define(x,1)` evaluation both succeed. Bison's `PKGDATADIR` is
consulted on every single run, with no fallback except the
`BISON_PKGDATADIR` env var, which the loader does not set. Worth
recording so a future reader does not "fix" m4 or file on the strength of
a `strings` hit alone.

## 6. HAZARD (affects every `@native` require): host tools mask the prefix

**Confirmed, and observed live during this task.** A `require("x@native")`
is satisfied by *any* `x` on `PATH`, not only by a tool built into
`$NATIVE_PREFIX`. The loader only prepends the native bin dir
(`src/loader.lua:413`):

```
  PATH="$NATIVE_PREFIX/bin${PATH:+:$PATH}"
```

...which makes the prefix win **when it exists**, and silently fall
through to the host when it does not.

This host has system-wide copies:

```
$ command -v flex bison m4 gperf
/usr/bin/flex
/usr/bin/bison        (GNU Bison 3.8.2 — same version as ours!)
/usr/bin/m4
(nothing for gperf)
```

Live demonstration while building `libnl-3`: **`flex@native` was never
built into the native prefix** — there is no
`nest/clang-native/.retrolunar-flex` and no `nest/clang-native/bin/flex`
— yet `flex` on `PATH` is `/usr/bin/flex`, and libnl-3's build happily
used it (`clang ... -c gen.c` on line 441 of the log). The require
"passed" for a tool this prefix does not contain. **gperf is the one that
was masked correctly** here, because the host has no `gperf` at all, so
`libseccomp`'s `AC_CHECK_TOOL(GPERF, gperf)` was forced to find the one in
`$NATIVE_PREFIX/bin`.

Two distinct sub-hazards, worth keeping apart:

- **`AC_CHECK_PROG`/`AC_CHECK_TOOL`-style probes** find whatever is first
  on `PATH`. `libseccomp/configure.ac:126` is `AC_CHECK_TOOL(GPERF,
  gperf)` — it cannot tell our gperf from a host gperf.
- **Makefile-level invocations are worse, because there is no check
  whatsoever.** `bison`'s own `Makefile.in:3668` is literally
  `GPERF = gperf`; the gperf rules at `Makefile.in:12241+` run `$(GPERF)`
  during `make`, long after configure could have complained. A missing or
  broken native gperf surfaces as an unexplained `make` failure deep in
  the build, not as a configure error.

Bison's own dependency on m4 is PATH-searched too
(`configure:13731` loops over `$PATH` for `gm4 gnum4 m4`), and bakes the
result via `configure.ac:269` — which is why the freshly built bison has
`/home/si/ond/git/retrolunar/nest/clang-native/bin/m4` baked in. That one
is *correct*: it is the published native prefix, not a staging dir.

**Consequence for a reviewer or builder:** `skip x@native (fresh)` and a
successful `configure` are *not* evidence that the native prefix contains a
working tool. To assert that, check the artifact exists in
`$NESTDIR/<native>/bin/` and, for a program with data files, run it.

## Files changed

- `packages/bison/generic.lua` — added `--enable-relocatable` plus a
  comment citing the mechanism (`PKGDATADIR` → `lib/configmake.h` →
  `src/files.c` → `relocate2`).

No other recipe was modified: flex and gperf are demonstrably fine
(§4). No system file was changed — the fix is system-neutral.
