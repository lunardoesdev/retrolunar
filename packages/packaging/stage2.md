ACCEPT

# packaging — stage 2 review

## What the recipe gets right

- **It is already on the correct `python3.14` path**, unlike its four
  siblings. `generic.lua:7-9` use `$OUT/lib/python3.14/site-packages`, which
  matches `packages/python/source.lua:2` pinning 3.14.7. Confirmed on disk:
  `nest/aarch64-android24/lib/python3.14/site-packages/packaging/` exists.
- The comment at line 6 says "install its module for the target Python 3.14" —
  accurate.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no multi-job build (there
  is no build at all, just three `cp` commands).

## The tree-wide bug this package is NOT subject to

Four packages in this shard install into `python3.13` and are therefore
invisible to this tree's interpreter:

| file | wrong path |
| --- | --- |
| `packages/jinja2/generic.lua:8-10` | `python3.13` |
| `packages/markupsafe/generic.lua:7-9` | `python3.13` |
| `packages/meson/generic.lua:8-10` | `python3.13` |
| `packages/wheel/generic.lua:7-9` | `python3.13` |

This is a category (iii) finding — a latent bug, not a per-package verdict.
`meson` is the worst of the four because it also **ships `bin/meson`**, so its
failure surfaces as a broken launcher rather than silence. A separate reviewer
found the same class of bug in `setuptools` in the q-z shard; `setuptools` is
already on 3.14 and is correct.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/python3.14/site-packages/packaging/__init__.py` | `test -f $PREFIX/lib/python3.14/site-packages/packaging/__init__.py` |
| licenses carried | `ls $PREFIX/lib/python3.14/site-packages/packaging/ \| grep -c LICENSE` → 3 (`LICENSE`, `LICENSE.APACHE`, `LICENSE.BSD`) |
| **the tree-wide check** | `test ! -e $PREFIX/lib/python3.13` — after all four siblings are fixed, no `python3.13` directory should exist anywhere in the prefix |
