REJECT

# meson — stage 2 review

## Required changes

1. **`packages/meson/generic.lua:8` — installs into `python3.13`, but this
   tree's interpreter is Python 3.14.** `packages/python/source.lua:2` pins
   `3.14.7` and the interpreter installs to `$PREFIX/lib/python3.14/`, so
   `import mesonbuild` fails and the launcher at `bin/meson` cannot import its
   own package. **Confirmed on disk**: the nest has
   `lib/python3.13/site-packages/mesonbuild/` next to
   `lib/python3.14/site-packages/setuptools/`.

   Replace line 8 with:

   ```sh
        mkdir -p $OUT/lib/python3.14/site-packages
   ```

   and line 9 with:

   ```sh
        cp -r mesonbuild $OUT/lib/python3.14/site-packages/
   ```

   and line 10 with:

   ```sh
        cp COPYING $OUT/lib/python3.14/site-packages/mesonbuild/COPYING
   ```

   and append to the comment at lines 5-7, matching
   `packages/flit-core/generic.lua:9-11`:

   ```sh
        # CPython 3.14's install scheme. packages/python pins 3.14.7, so this
        # is the only site-packages its interpreter searches; a python
        # version bump means updating this line.
   ```

## Why meson is the worst-affected of the five

The other four land in a directory nothing reads. `bin/meson` is *shipped as
an executable* at `generic.lua:11-12` (`cp meson.py $OUT/bin/meson;
chmod +x`), so the failure mode is a **broken launcher**: running `meson`
raises `ModuleNotFoundError: No module named 'mesonbuild'` rather than
silently doing nothing. If any recipe in this tree ends up shelling out to
`meson`, it fails at that moment, far from the cause.

## What the recipe otherwise gets right

- No C extension to build, so no toolchain involvement — correct, and the
  comment says so.
- Skipping `dist-info` is deliberate and defensible: no host `pip3` is
  invoked, and no recipe in this tree runs `pip`.
- `chmod +x $OUT/bin/meson` at line 12 is necessary because the upstream
  `meson.py` is not executable in the tarball.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/python3.14/site-packages/mesonbuild/__init__.py` | `test -f $PREFIX/lib/python3.14/site-packages/mesonbuild/__init__.py` |
| `$PREFIX/bin/meson` executable | `test -x $PREFIX/bin/meson` |
| **the check that catches this bug** | `test ! -e $PREFIX/lib/python3.13` |
| launcher finds its own package | `grep -c mesonbuild $PREFIX/lib/python3.14/site-packages/mesonbuild/coredata.py` → non-zero (sanity: the package is self-contained) |