ACCEPT

# tcl 8.6.16 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the recipe.
I did not build.

## What the recipe gets right

- **No autotools timestamp guard is needed and none is present**, which is
  correct: Tcl 8.6's `configure` is a hand-written shell script, not autoconf.
  Verified against the real tree — `configure.ac` has no `AC_CONFIG_HEADERS` and
  the tree ships no `config.h.in`. This is the same "the build system is not
  what you assume" point vim's recipe makes, handled correctly here by omission
  rather than by a stray `touch`.
- `./unix/configure $AUTOCONF_CONFIGURE_FLAGS --mandir="$OUT/share/man"
  --disable-rpath` run from the source root. Tcl's configure genuinely accepts
  being invoked from the root and then builds in the current directory — the
  comment at lines 6-7 says so, which is what makes the unusual-looking line
  readable. `--disable-rpath` is the right call for a target prefix: an rpath
  pointing at a build-host staging path is worse than none. `--mandir` points
  the manual pages at `$OUT`, consistent with the prefix `--prefix=$OUT` that
  `$AUTOCONF_CONFIGURE_FLAGS` supplies.
- `make -j1` on all three invocations, including the two installs. Explicitly
  serial, exactly as the rule asks.
- `make -j1 install-private-headers` at line 12 is a **real, load-bearing
  extra step**, not tidiness: `packages/expect` requires Tcl's private headers,
  and a plain `make install` does not install them. The comment says so. This
  is the sort of thing that gets "cleaned up" by a later maintainer and breaks
  expect — worth a preserve-it note in the backlog.
- `require("tcl@source")` names no missing package.

## The dependency this creates, and the one to watch

Tcl is a *host* dependency as well as a target one. Two consumers need care:

- `packages/expect` needs a **native** tclsh at install time to run
  `pkg_mkIndex` (see `packages/expect/stage2.md` — the recipe there currently
  resolves it to the *target* interpreter, which is a defect there, not here).
- `packages/dejagnu` needs a native tcl to run its `.exp` files.

So the real shape of this package is `tcl` for the target and `tcl@native` for
build-host execution. That distinction belongs in the backlog entry for Tcl,
and it is the one thing `stage1.md` should make explicit.

## Carried to the build

- `bin/tclsh8.6` (and the `tclsh` symlink) — `[ -x bin/tclsh8.6 ]` and `[ -e bin/tclsh ]`. Tcl installs a versioned binary plus an unversioned link; both must be present or a consumer's `#!/usr/bin/env tclsh` shebang has nothing to resolve.
- `lib/libtcl8.6.a` — `llvm-objdump -f lib/libtcl8.6.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). Record the exact SONAME/versioned name; Tcl's library naming is version-suffixed and easy to get wrong in a check.
- `include/tcl8.6/tcl.h` and, critically, the private headers — `[ -f include/tcl8.6/tcl.h ]` **and** `[ -f include/tcl8.6/tclInt.h ]`. `tclInt.h` is the one `install-private-headers` exists to deliver; if it is missing, `packages/expect` is broken and nothing else here will say so.
- `lib/tcl8.6/msgcat.msg` (or the equivalent under `$OUT/lib`) — `[ -f lib/tcl8.6/msgcat.msg ]`; without it Tcl's library initialisation fails at runtime.
- `share/man/man3/Tcl*.3` — `[ -d share/man/man3 ]`, the check that `--mandir` took.
- No `.pc` unless the release ships one; consumers use `find_package(Tcl)` or the raw `-ltcl8.6`.
- **Never run `bin/tclsh`** — target binary. This matters more here than for most packages, because a builder testing "does tclsh work" would be reaching for a host tclsh that is not this one.
