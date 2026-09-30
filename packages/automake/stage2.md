ACCEPT

# automake 1.18.1 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/automake/`. I did not build.

## What the recipe gets right

- `require("autoconf")` first: automake's `configure` and its `Makefile`
  generation genuinely need a working autoconf in the prefix, and
  `packages/autoconf` exists and is built. This is the correct dependency
  direction, and it is the reason automake builds at all in this prefix.
- `./configure $AUTOCONF_CONFIGURE_FLAGS --prefix="$PREFIX"` then
  `make -j1 prefix="$OUT" install` is the same deliberate prefix-splitting
  pattern autoconf uses, and the comment gives the reason: the Perl scripts
  embed their module directory. Correct.
- `touch m4/amversion.m4 aclocal.m4 configure config.h.in` — the
  `m4/amversion.m4` touch is a real and correct addition to the standard guard:
  it is the one generated file whose staleness makes automake re-run
  `aclocal` looking for an `automake-1.18` that is not on the build host. This
  is the same class of trap `grub` handles with `touch Makefile.util.am`, and
  handling it here is better than most of the shard.
- `make -j1` is serial throughout. `require("automake@source")` names no
  missing package.

## One inaccuracy, not a reject reason

`config.h.in` in that touch line is the stray-file case again: automake has no
config header (no `AC_CONFIG_HEADERS` in its `configure.ac`, no `config.h.in`
in `nest/source/automake/`). Nothing is lost — the three files that *are*
touched are the right ones — so this is cosmetic. Fix it the next time the
file is edited:

```
        touch m4/amversion.m4 aclocal.m4 configure
```

## A dependency worth stating in the backlog

`automake` needs a **host** `autom4te` at run time, not just at build time:
`bin/automake` shells out to `autom4te`, and `bin/aclocal` shells out to
`automake` itself. In this prefix those come from the *target* `bin/`, which
a build cannot execute. That is fine for *building* automake, and it is worth
knowing before anyone tries to use this prefix's automake as a build tool on
the host. Not a defect — a scope statement.

## Carried to the build

- `bin/automake`, `bin/aclocal`, `bin/automake-1.18`, `bin/aclocal-1.18` — `[ -x bin/automake ]` and `[ -x bin/aclocal ]`; the versioned symlinks/copies must exist too, because `configure`'s `aclocal` wrapper looks for the versioned name.
- `share/automake-1.18/automake.m4`, `aclocal.m4`, `*.texi` — `[ -f share/automake-1.18/automake.m4 ]`. **The data directory is the artifact that matters**, and the prefix trick exists to get its embedded path right.
- `share/man/man1/automake.1` — `[ -s share/man/man1/automake.1 ]`.
- No library and no `.pc`.
- **Never run `bin/automake`** — it is a target binary.
