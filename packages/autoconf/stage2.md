ACCEPT

# autoconf 2.72 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/autoconf/`. I did not build.

## What the recipe gets right

- `./configure $AUTOCONF_CONFIGURE_FLAGS --prefix="$PREFIX"` followed by
  `make -j1 prefix="$OUT" install` is a deliberate, correct pattern, and the
  comment says why: autoconf's generated scripts embed their data directory,
  so it must be configured with the *final* prefix and installed separately
  into the stage dir. `$AUTOCONF_CONFIGURE_FLAGS` already carries
  `--prefix=$OUT`, so the later `--prefix="$PREFIX"` overrides it at configure
  time and the `make`-line `prefix="$OUT"` re-points only the install. Correct
  and well explained.
- Building the individual programs first, then `.version`, then touching the
  shipped man pages, then a full `make -j1` is the right order for a GNU
  package: it keeps the release's pre-built `autom4te.info`/`.1` files from
  being regenerated with `help2man`/`makeinfo`, which the build host may not
  have. Every `make` is serial.
- `require("m4")` is a real and necessary dependency — autoconf's generated
  `autom4te` drives m4 — and `packages/m4` exists.
- `require("autoconf@source")` names no missing package.

## One inaccuracy, not a reject reason

`generic.lua:10` has `touch aclocal.m4 configure config.h.in`, but autoconf
has **no config header**: `configure.ac` never calls `AC_CONFIG_HEADERS` and
the tree ships no `config.h.in` (verified in `nest/source/autoconf/`). The
`touch` creates a stray empty file. Unlike the packages whose guard protects
the wrong *existing* template, here there is no template to protect, so nothing
is lost. The line is cosmetically wrong and the two files it does touch
(`aclocal.m4`, `configure`) are the right ones.

Worth fixing when the file is next edited — drop `config.h.in`:

```
        touch aclocal.m4 configure
```

Same applies to `automake` (below), which also has no config header.

## Carried to the build

- `bin/autoconf`, `bin/autoheader`, `bin/autom4te`, `bin/autoreconf`, `bin/autoscan`, `bin/autoupdate`, `bin/ifnames` — `[ -x bin/autoconf ]` and `[ -x bin/autom4te ]`; all seven must be present, and the recipe's explicit target list is the check that they were built.
- `share/autoconf/autoconf*.m4`, `share/autoconf/autosquash`, `share/autoconf/*.texi` — `[ -d share/autoconf ]`. **The data directory is the artifact that matters**; autoconf is useless without it, and the prefix trick exists precisely so these paths are right.
- `share/man/man1/autoconf.1` etc. — `[ -s share/man/man1/autoconf.1 ]`.
- No library and no `.pc`.
- **Never run `bin/autoconf` against real sources** — it is a target binary. Verifying it means `bin/autoconf --version` is *not* an option; check the file type instead.
