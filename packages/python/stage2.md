REJECT

# python — stage 2 review

## Required changes

1. **`packages/python/generic.lua:11` — bare `make`, violating the serial-build
   rule.** `AGENTS.md:226-229`: "Build serially: use `make -j1` or the build
   tool's equivalent single-job option." Change `make` to `make -j1` on line
   11.

2. **The python-version split is a TREE-WIDE bug and the fix spans four
   packages in this shard.** `packages/python/source.lua:2` pins `3.14.7`, and
   the built interpreter lands in `$PREFIX/lib/python3.14/`. Four recipes in
   this shard install into **`python3.13`** and are therefore invisible to the
   interpreter:

   | file:line | wrong path |
   | --- | --- |
   | `packages/jinja2/generic.lua:8` | `$OUT/lib/python3.13/site-packages` |
   | `packages/markupsafe/generic.lua:7` | `$OUT/lib/python3.13/site-packages` |
   | `packages/meson/generic.lua:8` | `$OUT/lib/python3.13/site-packages` |
   | `packages/wheel/generic.lua:7` | `$OUT/lib/python3.13/site-packages` |

   Three already say `python3.14`: `flit-core`, `packaging`, `setuptools`.
   `setuptools` also uses `python3.14`, which a separate reviewer found and
   which I confirmed.

   **This is confirmed empirically, not inferred.** The existing nest has
   both directories and the split is visible on disk:

   ```
   nest/aarch64-android24/lib/python3.13/site-packages/flit_core/
   nest/aarch64-android24/lib/python3.13/site-packages/jinja2/
   nest/aarch64-android24/lib/python3.13/site-packages/markupsafe/
   nest/aarch64-android24/lib/python3.13/site-packages/mesonbuild/
   nest/aarch64-android24/lib/python3.13/site-packages/wheel/
   nest/aarch64-android24/lib/python3.14/site-packages/setuptools/
   nest/aarch64-android24/lib/python3.14/site-packages/packaging/
   ```

   `flit_core` sits in 3.13 while its recipe *says* 3.14 — so the nest
   predates that fix and has not been rebuilt. The bug is live for the other
   four.

   In each of the four files, change every `python3.13` to `python3.14` on the
   affected lines (two or three occurrences per file — the `mkdir -p`, the
   `cp -r`, and any `cp LICENSE`), and update the comment in
   `packages/jinja2/generic.lua:5-7` to name 3.14 the way
   `packages/flit-core/generic.lua:9-11` already does.

   **Why the build does not catch it:** these packages have no build step
   beyond `cp`, so `make install` succeeds and nothing imports the module.
   The check that actually proves it is in the "carried to the build" line
   below.

## What the forecast got right

- The `--disable-test-modules` and `--without-ensurepip` flags are real and
  appropriate; `--with-build-python=python3` correctly keeps the *build*
  interpreter a host tool while `-Dcc="$CC"` cross-compiles the result.
- `--disable-shared` is right: a target interpreter needs no shared object
  this tree cannot load.
- The timestamp guard is **more careful than most**: line 10 is
  `find . -name 'Makefile.in' -o -name 'Makefile.pre.in' | xargs touch`,
  which is the `Makefile.pre.in` case `AGENTS.md:233-234` calls out
  specifically for python. Correct.
- `require("readline")` is a real dependency of a usable interpreter.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/bin/python3.14` | `test -x $PREFIX/bin/python3.14` |
| `$PREFIX/lib/python3.14/` stdlib | `test -f $PREFIX/lib/python3.14/os.py` |
| `readline` linked in | `llvm-nm --undefined-only $PREFIX/bin/python3.14 \| grep -c readline` → non-zero |
| **the site-packages check that catches the tree bug** | `find $PREFIX/lib -maxdepth 1 -name 'python3.*'` must list **only** `python3.14`; if `python3.13` appears, four recipes are still wrong |
| no `.so` | `test ! -e $PREFIX/lib/libpython3.14.so` |