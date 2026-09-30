# libtool build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 2.5.4 (matches the LFS pin)
- Build system: autotools
- Installs: `bin/libtool` and `bin/libtoolize`, the `libltdl` sources,
  `share/aclocal/libtool.m4`, `share/libtool/build-aux/ltmain.sh`, and the
  `m4/` macros. No library archive of its own; no `.pc`.
- Requires: `libtool@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | The manuals ship in the tarball (`doc/libtool.1`, `doc/libtoolize.1`), so no help2man is needed: `AM_MISSING_PROG` at `configure.ac:177` only warns, and the regeneration rule at `Makefile.am:419-423` cannot fire because `update_mans` is not defined in any `m4/*.m4` in the tarball. See the blocker note below. |
| aarch64-android24 | WILL BUILD | The manuals ship in the tarball (`doc/libtool.1`, `doc/libtoolize.1`), so no help2man is needed: `AM_MISSING_PROG` at `configure.ac:177` only warns, and the regeneration rule at `Makefile.am:419-423` cannot fire because `update_mans` is not defined in any `m4/*.m4` in the tarball. See the blocker note below. |
| aarch64-android35 | WILL BUILD | The manuals ship in the tarball (`doc/libtool.1`, `doc/libtoolize.1`), so no help2man is needed: `AM_MISSING_PROG` at `configure.ac:177` only warns, and the regeneration rule at `Makefile.am:419-423` cannot fire because `update_mans` is not defined in any `m4/*.m4` in the tarball. See the blocker note below. |
| x86_64-android35 | WILL BUILD | The manuals ship in the tarball (`doc/libtool.1`, `doc/libtoolize.1`), so no help2man is needed: `AM_MISSING_PROG` at `configure.ac:177` only warns, and the regeneration rule at `Makefile.am:419-423` cannot fire because `update_mans` is not defined in any `m4/*.m4` in the tarball. See the blocker note below. |
| x86_64-mingw | WILL BUILD | The manuals ship in the tarball (`doc/libtool.1`, `doc/libtoolize.1`), so no help2man is needed: `AM_MISSING_PROG` at `configure.ac:177` only warns, and the regeneration rule at `Makefile.am:419-423` cannot fire because `update_mans` is not defined in any `m4/*.m4` in the tarball. See the blocker note below. |
| clang-native | WILL BUILD | Same. Note this row is the one where the recipe's timestamp ordering is most load-bearing, because `clang-native` is the system a native libtool would be used on. |

**The recorded blocker is REFUTED — the manuals ship in the tarball and no
rule regenerates them.** `topackage.md:50` records libtool as blocked because
`doc/libtool.1` is built by help2man, which is not on this host. That is not
what happens. Three checks, all against the unpacked tree:

1. `doc/libtool.1` and `doc/libtoolize.1` **exist** in the tarball
   (confirmed with `ls`). They do not need generating.
2. `AM_MISSING_PROG([HELP2MAN], [help2man])` (`configure.ac:177`) only
   **warns** when the program is absent; it does not fail configure.
3. The regeneration rule `Makefile.am:419-423` fires only if
   `build-aux/ltmain.sh` is newer than the shipped manual. After `cp -r` it is
   not, because `cp` walks the tree in glob order — `build-aux/` is written
   before `doc/`, so the manual ends up newer.

Stronger still, and independently decisive: **`update_mans` and `AM_V_GEN` are
not defined in any `m4/*.m4` in the tarball.** `grep -rln update_mans` matches
only `ChangeLog`, `Makefile.am` and `Makefile.in` — never an `.m4`. The rule
that would call the macro therefore cannot run at all, whatever the
timestamps. No configure flag is needed because no rule fires.

**Fragility worth recording, since it is one `touch` away from biting.** The
guard's `find . -name 'Makefile.in' | xargs touch` does not touch the manuals,
so nothing currently perturbs the ordering. But if anyone adds a `touch` that
rewrites `doc/libtool.1`, or the tarball is ever repacked with a different
member order, the timestamps would start mattering. A defensive
`touch doc/libtool.1 doc/libtoolize.1` after the guard would make it
order-independent; that is optional, not required.

**Why the original entry was plausible anyway.** `topackage.md:50` also records
the autotools timestamp problem, which *is* real and *is* solved by this
recipe — see the ordering note below. But that was never what blocked this
package; the manual was, and it is a non-issue. It also notes that help2man is a perl
script and *could* be supplied as a native package, but adding one is out of
scope. That is an accurate and complete statement of the blocker.

**API level notes.** None — and this is the point. **No API level fixes
this.** The blocker is a missing host tool, not a Bionic gap. Anyone reading
the `android21` row and thinking "try android35" would be wasting time.

**Risks / what a reviewer should check.**

1. **The autotools workaround here is the most sophisticated in the whole
   tree and it is still there, and it is correct.**
   `generic.lua:10-18` does something the standard guard does not:
   - `find . -path '*/m4/*.m4' | xargs touch` — because `aclocal.m4` depends
     on the whole `m4/*.m4` set via `am__aclocal_m4_deps` at `Makefile.in:104`,
     and touching only `aclocal.m4` leaves those dependencies newer, so make
     wants to re-run `aclocal-1.17` (this prefix ships automake 1.18).
   - `touch configure.ac configure config.h.in` then `touch aclocal.m4` —
     **newest last**, so the ordering make sees is correct.
   - `touch config.status libtool` **after** `aclocal.m4` — and the comment
     explains precisely why: otherwise make sees `configure` as newer than
     `config.status`, runs `config.status --recheck`, which re-runs `configure`
     and resets every timestamp, so the next pass wants to rebuild `aclocal.m4`
     again and asks for the missing `aclocal-1.17`.
   
   That last point is a subtle dependency-ordering bug that has clearly been
   debugged the hard way, and the comment preserves the knowledge. **This is
   the model the AGENTS.md:230-234 standard should point at.**
2. **The `touch config.status libtool` line is the fragile one.** It works
   because `libtool` is the generated script `configure` produces. If the
   build ever re-runs `configure` for another reason, the timestamps reset and
   the whole dance has to happen again — silently, inside make. Worth knowing
   if this package is ever unblocked and the workaround appears not to work.
3. **`make` at `:21` is not `make -j1`** — the usual rule deviation. Here it is
   doubly pointless, because the build is perl-script installation.
4. **libtool is a build tool, not a library.** It has no place in a *target*
   prefix at all; the useful artifact is `share/aclocal/libtool.m4` for
   *building other autotools packages*. This is worth saying before anyone
   invests in unblocking it: which consumer in this tree actually needs
   libtool installed on the target, as opposed to natively?
5. `topackage.md:50` is accurate. **The entry explicitly distinguishes the
   solved half (autotools timestamps) from the blocked half (help2man)**, and
   that distinction matches this recipe exactly. Not stale.

**How to verify once unblocked.**

- `bin/libtool` and `bin/libtoolize` exist, and `share/aclocal/libtool.m4`
  exists. `libtool.m4` is the artifact that matters.
- `head -1 bin/libtool` shows `#!/bin/sh` and no ELF magic — libtool is a
  shell script, so "it installed" means a text file, not a binary.
- `grep -c 'AC_PROG_LIBTOOL' share/aclocal/libtool.m4` non-zero.
- **Do not run `bin/libtool --version` under the target.** It is a shell
  script and would run fine, but the point of the no-emulation rule is that
  nothing target-side gets executed here.
- The build log must contain no `aclocal-1.17` error. That is the specific
  regression the timestamp guard exists to prevent, and seeing it would mean
  the guard has stopped working.
