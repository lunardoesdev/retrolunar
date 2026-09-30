ACCEPT

# m4 — stage 2 review

## What the recipe gets right

- **`make -j1` on every line**, including the staged `make -j1 -C lib`,
  `make -j1 -C src`, `make -j1 .version`, `make -j1 -C doc version.texi` and the
  final `make -j1`. The most carefully serialised recipe in the shard.
- The staging is correct and necessary: m4's build must generate `version.texi`
  before `doc/Makefile` can use it, and the recipe does `touch doc/m4.1` after
  generating the texinfo so the manual rule does not re-run and need a host
  `makeinfo`.
- `touch aclocal.m4 configure config.h.in` names the right file — m4 ships a
  top-level `config.h.in`.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## A note on `touch doc/m4.1`

That line is a recipe-local workaround of exactly the kind AGENTS.md:29 asks
to be explained, and it is **not** explained — the reason (the manual is
generated from texinfo by a host `makeinfo` this tree does not have, and the
touch suppresses that rule) is worth a comment. It is the kind of line a
tidying reader deletes.

## What the forecast should add

Note that m4 here is built as a **host tool** in practice: the `aclocal`,
`automake` and `autoconf` recipes in this tree generate `aclocal.m4` with a
native m4. The forecast should say so, and note that this recipe's
target-arch binary in `$PREFIX/bin/m4` is not what runs during those builds.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/m4` | `test -x $PREFIX/bin/m4` |
| `$PREFIX/share/info/m4.info` | `test -s $PREFIX/share/info/m4.info` — proves `version.texi` and the info build worked |
| `$PREFIX/share/man/man1/m4.1` | `test -s $PREFIX/share/man/man1/m4.1` — **non-empty** is the check that `touch doc/m4.1` suppressed a `makeinfo` rule rather than leaving an empty file |
| target binary, never executed | `file $PREFIX/bin/m4` shows the target arch — do not run it |
