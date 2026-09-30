REJECT

# libtool — stage 2 review

## The reported help2man blocker is REFUTED

The forecast says `WILL NOT BUILD` on every system because `help2man` is
missing. I checked the mechanism and the blocker does not fire.

1. `help2man` **is** absent from the build host (`command -v help2man` → not
   found), so the premise is right.
2. `configure.ac:177` is only `AM_MISSING_PROG([HELP2MAN], [help2man])`, which
   **warns** rather than erroring. Configure will not stop.
3. The manuals **ship in the tarball**: `doc/libtool.1` (3457 bytes) and
   `doc/libtoolize.1` (3051 bytes) are both present.
4. The regeneration rule is `Makefile.am:419-423` — `$(libtool_1): $(ltmain_sh)`
   running `$(update_mans)`. It only fires if `ltmain.sh` is **newer** than
   the shipped manual.
5. I reproduced the recipe's `cp -r` exactly and checked the resulting
   timestamps:

   ```
   2026-10-01 02:28:20.860 build-aux/ltmain.sh
   2026-10-01 02:28:20.872 doc/libtool.1
   ```

   `cp -r` walks the tree in glob order, so `build-aux/` is copied before
   `doc/`, leaving `doc/libtool.1` **newer** than `build-aux/ltmain.sh`. The
   rule does not fire, `$(HELP2MAN)` is never invoked, and the shipped manual
   is installed as-is.

So the correct verdict for all three buildable systems is **WILL BUILD**.

## Required changes

1. **`packages/libtool/stage1.md` — replace the per-system rows.** The three
   rows at lines 13, 17 and 18 currently say WILL NOT BUILD because of
   help2man. Replace each with **WILL BUILD**, reason:
   "`AM_MISSING_PROG` (configure.ac:177) only warns, and the manuals ship in
   the tarball (`doc/libtool.1`, `doc/libtoolize.1`). The regeneration rule
   `Makefile.am:419-423` fires only if `build-aux/ltmain.sh` is newer than the
   shipped manual, and after `cp -r` it is not — `cp` walks the tree in glob
   order, so `build-aux/` is written before `doc/` and the manual ends up
   newer. I reproduced the copy and measured the timestamps. No configure flag
   is needed because no rule fires."

   Also add a caveat worth recording, since it is one `touch` away from
   biting: "This is fragile. The guard's `find . -name 'Makefile.in' | xargs
   touch` does not touch the manuals, so nothing currently perturbs the
   ordering — but if anyone adds a `touch` that rewrites `doc/libtool.1`, or
   if the tarball is ever repacked with a different member order, the rule
   fires and the build fails with an empty `$(HELP2MAN)`. A defensive
   `touch doc/libtool.1 doc/libtoolize.1` after the guard would make it
   order-independent; that is optional, not required."

2. **`packages/libtool/generic.lua:16` — bare `make`, violating the
   serial-build rule** (`AGENTS.md:226-229`). Change to `make -j1`.

3. **`packages/libtool/stage1.md` — the praise is misplaced and should not
   stand unqualified.** The recipe's timestamp handling is genuinely the most
   careful in the tree and it **is correct** — I checked the ordering claim
   rather than assuming it. `generic.lua:14-18` touches `config.status` and
   `libtool` *after* `aclocal.m4`, which is what prevents `config.status
   --recheck` from re-running configure and resetting timestamps into a loop
   that asks for `aclocal-1.17`. Keep the praise. But the forecast's framing
   "the solved half (autotools timestamps)" implies the timestamps were what
   needed solving *for this package*; in fact the only real risk here was the
   manual, and it is a non-issue. Reword so the praise reads as a general
   observation about the recipe, not as the reason the package is expected to
   work.

## What the forecast got right

- The timestamp ordering at `generic.lua:11-18` is correct and is the best
  example in the tree. `touch configure.ac configure config.h.in` then
  `touch aclocal.m4` then `touch config.status libtool` is the right sequence,
  and the comment explaining *why* is exactly the kind `AGENTS.md` asks for.
- `libtool`'s own config template is `config-h.in`, not `config.hin`
  (`configure.ac:53` is `AC_CONFIG_HEADERS([config.h:config-h.in])`). The
  recipe's `generic.lua:13` touches `config.h.in`, which is therefore a
  **second** guard defect, described below.

## The second guard defect

4. **`packages/libtool/generic.lua:13` — `touch config.h.in` names a file that
   does not exist.** I verified in the unpacked tree: `configure.ac:53` is
   `AC_CONFIG_HEADERS([config.h:config-h.in])` and the file on disk is
   `config-h.in` (hyphen). So line 13 creates a bogus empty `config.h.in` and
   leaves the real `config-h.in` with its tarball mtime — the same failure mode
   as inetutils, and the same fix:

   ```sh
           touch configure.ac configure config-h.in
   ```

   with a comment: `# config-h.in, not config.h.in: configure.ac:53 is
   AC_CONFIG_HEADERS([config.h:config-h.in]).`

   This one **does** matter: without it, make may re-run `autoheader`, which
   this prefix does not ship.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/libtool`, `$PREFIX/bin/libtoolize` | `test -x $PREFIX/bin/libtool && test -x $PREFIX/bin/libtoolize` |
| `$PREFIX/share/man/man1/libtool.1` | `test -s $PREFIX/share/man/man1/libtool.1` — **non-empty** is the check that proves the help2man rule did not fire and produce an empty file |
| `$PREFIX/bin/*/libtool` (the installable copy) | `find $PREFIX/lib -name libtool` non-empty |
| **the check that catches the guard bug** | the build log must contain no `autoheader` invocation |
## Rework verification

**Verdict: REJECT.** First line stays `REJECT`.

### What was correctly fixed

**Nothing.** Both required changes are unapplied.

### What is still wrong

**1. `generic.lua:12` still names a config template libtool does not ship.**

```
12:        touch configure.ac configure config.h.in
```

Verified in the unpacked tree: `configure.ac:53` is
`AC_CONFIG_HEADERS([config.h:config-h.in])` — a **hyphen**, not a dot. The
file on disk is `nest/source/libtool/config-h.in`, and there is no
`config.h.in` anywhere in the tree:

```
$ ls nest/source/libtool/ | grep -i config
config-h.in
configure
configure.ac
```

So line 12 creates a stray empty `config.h.in` and leaves the real
`config-h.in` at its tarball mtime. This is the one guard defect stage2
flagged as *materially* important — "without it, make may re-run `autoheader`,
which this prefix does not ship" — and it is unfixed. Required edit:

```sh
        touch configure.ac configure config-h.in
```

**2. `generic.lua:19` is still a bare `make`, violating the serial-build rule
(AGENTS.md:226-229).**

```
19:        make
20:        make install
```

Required change #2 was to make this `make -j1`. `stage1.md:55-56` noticed
this too and waved it off; `stage2.md:56-57` made it required. It stands.

### The timestamp ordering itself — checked, and it IS right

The brief flagged this as easy to get backwards, so I verified it rather than
taking stage1.md's praise on faith. `generic.lua:11-18`:

```
11:        find . -path '*/m4/*.m4' | xargs touch
12:        touch configure.ac configure config.h.in
13:        touch aclocal.m4
...
18:        touch config.status libtool
```

The ordering is **correct**, and it is genuinely the most careful guard in the
tree:

- `aclocal.m4` depends on the whole `m4/*.m4` set, so line 11 touches the
  prerequisites and line 13 touches the dependent last. `am__aclocal_m4_deps`
  is at `Makefile.in:104`.
- `config.status` is touched **after** `aclocal.m4` (line 18 > line 13). This
  is the subtle one, and the comment at `:14-17` explains it correctly: if
  `configure` looks newer than `config.status`, make runs
  `config.status --recheck`, which re-runs `configure` and resets every
  timestamp, so the next pass wants `aclocal.m4` again and asks for the
  missing `aclocal-1.17`. Touching `config.status` last closes the loop.
- `libtool` in the same `touch` is the generated script `configure` produces,
  so it must move with `config.status`.

The praise in stage1.md is earned. It is also, as stage2 change 3 said,
attached to the wrong subject — the timestamps were never the reason this
package is in trouble, the manual is (and the manual is a non-issue). That
reword is also unapplied, which is fine, since it was documentation only.

### Damage check

The help2man REFUTATION above still holds and I re-confirmed it: the manuals
ship (`doc/libtool.1`, `doc/libtoolize.1` — both present in
`nest/source/libtool/doc/`), `configure.ac:177` is `AM_MISSING_PROG` which
only warns, and the regeneration rule is `Makefile.am:421-424`, gated on
`build-aux/ltmain.sh` being newer than the shipped manual. `AM_MISSING_PROG`
confirmed. No `export` of search flags, no `sed`/`patch`/`/dev/null`,
`require("libtool@source")` names a real package. No hardcoded target facts.

The one thing this package must never do — execute a target binary — it does
not attempt.
