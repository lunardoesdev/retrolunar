ACCEPT

# DejaGNU 1.6.3 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/dejagnu/`. I did not build.

## Required changes

### 1. `packages/dejagnu/generic.lua:9` — the guard names a file DejaGNU does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree:

```
$ grep -c AC_CONFIG_HEADERS nest/source/dejagnu/configure.ac
0
$ find nest/source/dejagnu -maxdepth 2 -name 'config.h.in'
(no output)
$ grep -n AC_CONFIG_FILES nest/source/dejagnu/configure.ac
AC_CONFIG_FILES([Makefile])
```

DejaGNU has **no config header at all** — `configure.ac` ends with
`AC_CONFIG_FILES([Makefile])` and never calls `AC_CONFIG_HEADERS`. The
`config.h.in` touch creates a stray empty file and protects nothing.

**Replace line 9 with:**

```
        touch aclocal.m4 configure
```

**This does not fail today's build** — DejaGNU is `[x]` and did build, because
`touch` of a missing file in an existing directory exits 0 (verified under the
emitted `set -eu`; only a missing *directory* aborts). The guard is inert
rather than fatal.

### 2. `packages/dejagnu/stage1.md:13-16, 31-35` — the cross-risk story is invented

The forecast's central worry is `utils/socket.c` and a `HAVE_SOCKET`
conditional. **Neither exists in 1.6.3** — that is pre-1.6 code. The tree's
only C sources are `stub-loader.c` and `testglue.c`, and `Makefile.am:229`
puts the single compiled object (`unit`) behind `make check`.

That matters because the correct story is much stronger than the one told:
**DejaGNU 1.6.3 compiles nothing at all on a plain build.** `make` has no
compilation target, no host interpreter is needed at build time
(`configure.ac` probes only awk/cc/cxx), and the installed tree is a pure
Tcl/awk/shell data package that is byte-identical on every system. Rewrite the
per-system reasons to say that, and delete the socket paragraph.

### 3. Nothing else is required

`require("tcl")` is a real dependency and `packages/tcl` exists. `make -j1` /
`make -j1 install` are serial. `./configure $AUTOCONF_CONFIGURE_FLAGS` takes
every flag from the system. The six WILL BUILD verdicts stand — and are
stronger than currently argued.

## Carried to the build

- `bin/runtest`, `bin/dejagnu` — `[ -x bin/runtest ] && [ -x bin/dejagnu ]`. They are **shell/Tcl scripts with a `#!/bin/sh` line**, not target binaries, so the no-emulation rule does not apply to them — but they still cannot run without a target `tclsh`, so do not run them either.
- `share/dejagnu/lib/*.exp` — `[ -d share/dejagnu/lib ]`; the `.exp` files are the package.
- `share/dejagnu/baseboards/*.exp`, `share/dejagnu/config/*.exp` — both directories present.
- `info/dejagnu.info` — `[ -s info/dejagnu.info ]`.
- No compiled library and no `.pc`. **`$OUT/lib` should contain nothing compiled** — if a `.a` or `.o` appears, the `check_PROGRAMS` path was built when it should not have been.

---

## Rework verification

**Verdict: ACCEPT.** (The first line of this file was changed from `REJECT`
to `ACCEPT` by this review.)

Verified against `nest/source/dejagnu/` and `packages/dejagnu/`. I did not
build.

### Required change 1 — the guard: done, and correct

`generic.lua:8` is now `touch aclocal.m4 configure`. That is right, and it
is right for the reason stage2 gave: DejaGNU has no config header.

```
$ grep -n AC_CONFIG nest/source/dejagnu/configure.ac
45:AC_CONFIG_FILES([Makefile])
$ find nest/source/dejagnu -name '*config*.in'
(no output)
```

`AC_CONFIG_HEADERS` count is 0. So there was never a `config.h.in` to
touch, and naming one would have created a stray empty file. The guard is
now positioned after `./configure` (`generic.lua:7`) and before `make`
(`generic.lua:10`), and `find . -name 'Makefile.in' | xargs touch`
(`generic.lua:9`) covers the one real `Makefile.in` at the top level.
Nothing was broken to achieve this.

### Required change 2 — the fabrication: withdrawn, everywhere

Checked for `socket`, `HAVE_SOCKET` and `cross` across `stage1.md` and
`generic.lua`. The only two surviving hits are `stage1.md:23-24`, and they
are the retraction itself:

> An earlier version of this file told a story about `utils/socket.c` and a
> `HAVE_SOCKET` conditional. **Both are pre-1.6 code and neither exists in
> 1.6.3**; that was a fabricated risk and it is withdrawn.

I confirmed the retraction is true rather than merely polite:

```
$ grep -rn HAVE_SOCKET nest/source/dejagnu/      -> no hits
$ find nest/source/dejagnu -name 'socket.c'      -> no hits
$ find nest/source/dejagnu -name '*.c'
  ./stub-loader.c
  ./testglue.c
$ grep -n check_PROGRAMS nest/source/dejagnu/Makefile.am
229:check_PROGRAMS = unit
230:unit_SOURCES = testsuite/libdejagnu/unit.cc
```

Both `.c` files are `pkgdata_DATA` (`Makefile.am:51-52`) — shipped as
source text, never compiled. The only compiled object in the project is
`unit`, behind `make check`, which this repo never runs. There is no
library (`lib_LTLIBRARIES` absent) and `bin_SCRIPTS = dejagnu runtest`
(`Makefile.am:47`) is two shell scripts. The stronger replacement claim —
"compiles nothing at all on a plain build, so the install is byte-identical
on all six systems" — is **true**, and the per-system table at
`stage1.md:11-16` now rests on it rather than on the socket story. The
"Risks" section (`:28-49`) carries no trace of the fabrication.

`stage1.md:15`'s "configure probes only awk/cc/cxx" is also accurate:
`configure.ac:25-34` is `AC_PROG_MAKE_SET`, `AC_PROG_AWK`, `AC_PROG_CC`,
`AC_PROG_CXX`, `AC_PROG_INSTALL` plus the AWK check. Nothing else.

### Required change 3 — nothing else needed, and nothing was damaged

`require("tcl")` resolves to a real `packages/tcl`. `make -j1` /
`make -j1 install` are serial. No `export`, no hardcoded target facts, no
`sed`, no patch, no `/dev/null`. There is no `android.lua` and none is
needed.

### One pre-existing falsehood I did not gate this on

Not part of the assigned rework, so it does not change the verdict, but it
should be fixed: **`stage1.md:6` misattributes four of expect's programs to
DejaGNU.** It lists `bin/spectest`, `bin/summarize`, `bin/identfr`,
`bin/expecttest`, plus `share/site-toplevel/` and `share/site_expect/`.
DejaGNU 1.6.3 installs none of them:

```
$ grep -n bin_SCRIPTS nest/source/dejagnu/Makefile.am
47:bin_SCRIPTS = dejagnu runtest
$ find nest/source/dejagnu -name 'site-toplevel*' -o -name 'site_expect*'
(no output)
```

The real installed tree is `bin/dejagnu`, `bin/runtest`,
`include/dejagnu.h` (`Makefile.am:48`), `$(pkgdatadir)/{lib,commands,config,baseboards,libexec}`
and the texinfo pages. `spectest` and the `site_expect` layout belong to
`packages/expect`, which is a different package on another shard. This is
worth correcting because the `stage1.md:45-49` risk entry reasons about
`remote_expect` linking expect, and a reader who believes line 6 will
misread that relationship.
