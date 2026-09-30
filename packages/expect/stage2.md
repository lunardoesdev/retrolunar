REJECT

# expect 5.45.4 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/expect/`. I did not build.

## Required changes

### 1. `packages/expect/generic.lua:10` — an undeclared host-tool dependency that becomes a target-binary execution

```
            --with-tcl="$PREFIX/lib" \
```

expect's `configure.in` calls `TEA_PROG_TCLSH` ("so that we can run
`pkg_mkIndex` … during the install process"), and `tcl.m4` resolves
`TCLSH_PROG` by looking in `${TCL_BIN_DIR}/../bin` — i.e. with
`--with-tcl="$PREFIX/lib"`, that is **`$PREFIX/bin/tclsh`, the cross-compiled
target interpreter**. `Makefile.in:328-330` then pipes
`echo pkg_mkIndex . lib/expect.so` into `$(TCLSH)` during `make install` to
generate `pkgIndex.tcl`.

That is the builder executing a target binary, which AGENTS.md forbids
outright ("No emulation, ever"). The recipe also does not declare the
dependency it actually has, which is a **host** Tcl.

**Required fix:** make the host tool explicit. Either

```
require("tcl@native")
```

with a `--with-tcl` that does not point into the target prefix (so TEA finds
the native interpreter the emitter puts on `PATH`), or drop cross builds of
expect entirely and record the blocker honestly in `topackage.md`. The first is
the right answer if the tree wants the package.

Either way, `generic.lua:1` currently says `require("tcl")`, which resolves to
the *target* system — the opposite of what is needed.

### 2. `packages/expect/generic.lua:14` — the guard names a file expect does not have

```
        touch aclocal.m4 configure config.h.in
```

Verified against the real unpacked tree: expect has **no config header** and
no `config.h.in` at all — its `configure.in` writes `expect_cf.h` itself.

**Replace line 14 with:**

```
        touch aclocal.m4 configure
```

**This does not fail the build** — `touch` of a missing file in an existing
directory exits 0 (verified under the emitted `set -eu`; only a missing
*directory* aborts). The guard is inert rather than fatal.

### 3. `packages/expect/stage1.md:18-20` — the `x86_64-android35` verdict is wrong for the stated reason

The bundled `tclconfig/config.sub` is a 2003-vintage copy. It has **no
`aarch64`**, which is the real blocker for the aarch64 rows and the backlog
line. But it *does* handle `x86_64` and `i86` explicitly, so
`x86_64-android35` and every `i686-android*` row get **past** `config.sub
$host_alias`. The row is not blocked for the aarch64 reason; it is blocked by
change 1 instead. Rewrite the row to say that.

### 4. Nothing else is required

`--enable-shared --disable-rpath` is a deliberate, conventional choice for a
scripting library and the comment is adequate — though a shared `libexpect.so`
does need a loader path, which is worth stating in `readme.md`. `make -j1` is
serial. `require("tcl@native")` in change 1 resolves to the DEFAULT_SYSTEM,
which is the correct semantic for a build-host interpreter.

## Carried to the build

Not buildable until change 1 is made. After that, on an Android target:

- `bin/expect` — `llvm-objdump -f bin/expect | head -3` → `elf64-littleaarch64`.
- `bin/expectk` — `[ -x bin/expectk ]`.
- `lib/expect.exp`, `lib/expect.so` — `[ -f lib/expect.exp ] && [ -f lib/expect.so ]`; the `.so` follows from `--enable-shared`.
- `include/expect/*.h` — `[ -f include/expect/expect.h ]`.
- `lib/pkgIndex.tcl` — `[ -f lib/pkgIndex.tcl ]`. **This file is the proof that change 1 worked**: it can only exist if a *host* tclsh ran `pkg_mkIndex`. If it appears while a target tclsh was the one invoked, the build did something forbidden.
- No `.pc`; expect ships none.
- **Never run `bin/expect`.**

## Rework verification

**Verdict: REJECT.** First line left as `REJECT`.

### What was correctly fixed

- **Change 2 landed and is right.** `generic.lua:29` is now
  `touch aclocal.m4 configure`. Verified against the unpacked tree: expect has
  no `AC_CONFIG_HEADERS` at all — `configure.in:1058` is a bare `touch
  expect_cf.h`, so `expect_cf.h.in` ships but is never consumed by automake.
  The stray `config.h.in` is gone.
- **Change 1 was attempted in the right shape.** `require("tcl@native")` at
  `generic.lua:10` is spelled correctly, and it resolves: the loader maps
  `@native` → `DEFAULT_SYSTEM` (`src/loader.lua:208-213`), which is
  `clang-native` (`src/main.c:10`), and `packages/tcl/generic.lua` exists and
  is reachable from there. So the *intent* — a host interpreter, not the
  target one — is correctly expressed, and this is the one thing that must not
  be wrong.

### What is still wrong

**1. The fix inverts the defect instead of removing it, and the result is a
broken link line rather than a forbidden execution.**

`generic.lua:24` and `:28` point **both** `--with-tcl` and `--with-tclinclude`
at `$NATIVE_PREFIX`. `--with-tcl` is not only how `TEA_PROG_TCLSH` finds
`tclsh8.6` — it is how `TEA_PATH_TCLCONFIG` sets `TCL_BIN_DIR`
(`tclconfig/tcl.m4:64-79`), and `TEA_LOAD_TCLCONFIG` then **sources that
directory's `tclConfig.sh`** (`tcl.m4:357-360`). Everything downstream comes
from it: `TCL_LIB_SPEC`, `TCL_STUB_LIB_SPEC`, `TCL_INCLUDE_SPEC`, `TCL_DEFS`.

`Makefile.in:396` links `expect` with `@TCL_LIB_SPEC@`, and `Makefile.in:176`
compiles every `exp_*.c` with `@TCL_INCLUDES@`. So with `--with-tcl` aimed at
the native prefix, the aarch64 `expect` is compiled against the **host's**
`tcl.h`/`tclInt.h` and linked against the **host's x86-64** `libtcl8.6`. That
is precisely the failure the brief asked me to check for: requiring tcl at
NATIVE *does* drag the target tcl out of the link line. One lever cannot
serve both jobs, because `TCL_BIN_DIR` feeds both the interpreter search and
the library/header specs. **This is a REJECT-grade defect.**

The correct shape needs the two decoupled. Either:
- keep `--with-tcl="$PREFIX/lib"` (target tcl for the link line) and override
  only the interpreter on the make line — `Makefile.in:172` makes `TCLSH_PROG`
  a plain `=` make variable, so `make -j1 install TCLSH_PROG="$NATIVE_PREFIX/bin/tclsh8.6"`
  works and leaves `TCL_LIB_SPEC` alone. Note this needs
  `require("tcl")` (target) **and** `require("tcl@native")`; or
- use `pkgIndex.tcl-hand` (`Makefile.in:331-335`), which writes `pkgIndex.tcl`
  with plain shell `echo` and **runs no interpreter at all**. It is already
  wired into `binaries:` at `Makefile.in:217`, and it is what
  `install-lib-binaries` installs (`Makefile.in:557-559`). Prefer this.

**2. The stage1.md `x86_64-android35` correction is still wrong, in a new way.**
The row now claims the row "gets **past** `config.sub $host_alias`". I ran the
bundled script against the real `$HOST_TRIPLET`:

```
$ ./tclconfig/config.sub x86_64-linux-android
Invalid configuration `x86_64-linux-android': system `android' not recognized
$ echo $?
1
```

The machine half (`x86_64`) is recognised, but the **system** half (`android`)
is not in a 2003 `basic_system` table. So `x86_64-android35` fails at
`configure` exactly like aarch64 does — just with a different message
(`system` rather than `machine`). `configure:8453` wraps this in
`as_fn_error "$SHELL config.sub $host_alias failed"`, so it aborts before any
Makefile exists. The row's verdict "WILL NOT BUILD (**make install**)" is
wrong; the correct verdict is "WILL NOT BUILD (configure)", for the *unknown
system* reason, not the unknown-machine one. The same applies to every
`i*-android*` row (`config.sub i686-linux-android` → `system 'android' not
recognized`). Only `x86_64-w64-mingw32` and `x86_64-pc-linux-gnu` return 0.

This is not a nit: it means the `$(TCLSH)` argument in `stage1.md:14` and in
the recipe comment at `generic.lua:16-22` rests on a row that never reaches
`make install` at all.

**3. The recipe comment is now itself wrong.** `generic.lua:16-22` claims the
only lever is "which directory `--with-tcl` names" and that `AC_SUBST`
discards an environment override. The first half is what breaks the link line
above; the second half is wrong for `make` — `TCLSH_PROG` is an ordinary
substituted make variable (`Makefile.in:172`) and `make TCLSH_PROG=… install`
overrides it. A future maintainer reading this comment will not try the fix
that works.

### Damage check

Nothing else was broken. No hardcoded target facts beyond the pre-existing
`--mandir="$OUT/share/man"` (correct — `$OUT`, not a target fact). No `export`
of search flags, no `sed`/`patch`/`/dev/null`, `make -j1` on both steps
(`generic.lua:31-32`), `require("tcl@source")` and `require("tcl@native")` both
name real packages.

### Did the adder introduce a forbidden execution?

**No — this is worth recording precisely.** The recipe no longer *would*
execute a target binary, but it is not because the host tool is correctly
arranged; it is because `--with-tcl="$NATIVE_PREFIX/lib"` makes `TCLSH_PROG`
resolve to a host `tclsh8.6` at the cost of a wrong-arch link line. The right
outcome, reached by the wrong route. Both ends of the brief's rule are
currently satisfied for different reasons, and only one of them is durable.
