REJECT

# jinja2 — stage 2 review

## Required changes

1. **`packages/jinja2/generic.lua:8-10` — installs into `python3.13`, but this
   tree's interpreter is Python 3.14.** `packages/python/source.lua:2` pins
   `3.14.7`, and the built interpreter installs to
   `$PREFIX/lib/python3.14/`. Everything jinja2 puts in
   `$OUT/lib/python3.13/site-packages/` is invisible to it, so `import jinja2`
   fails at runtime even though the build succeeds.

   **Confirmed on disk**, not inferred — the current nest has both:

   ```
   nest/aarch64-android24/lib/python3.13/site-packages/jinja2/
   nest/aarch64-android24/lib/python3.14/site-packages/setuptools/
   ```

   Replace lines 8-10 with:

   ```sh
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r src/jinja2 $OUT/lib/python3.14/site-packages/
        cp LICENSE.txt $OUT/lib/python3.14/site-packages/jinja2/LICENSE.txt
   ```

   and extend the comment at lines 5-7 with the reason, matching the wording
   already used in `packages/flit-core/generic.lua:9-11`:

   ```sh
        # CPython 3.14's install scheme. packages/python pins 3.14.7, so this
        # is the only site-packages its interpreter searches; a python
        # version bump means updating this line.
   ```

## Why this one is worth a REJECT on its own

The build reports success. There is no `make`, no configure, no test — just
three `cp` commands — so nothing in the build log distinguishes a correct
path from a wrong one. The bug is only visible when something imports the
module. `packages/jinja2` is required by `packages/harfbuzz`? No — but it is
in the backlog for consumers that will do exactly that.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/python3.14/site-packages/jinja2/__init__.py` | `test -f $PREFIX/lib/python3.14/site-packages/jinja2/__init__.py` |
| its filter extension is pure Python (no C) | `test -f $PREFIX/lib/python3.14/site-packages/jinja2/environment.py` |
| **the check that catches this bug** | `test ! -e $PREFIX/lib/python3.13` — after the fix no `python3.13` directory should exist anywhere in the prefix |