REJECT

# wheel — stage 2 review

## Required changes

1. **`packages/wheel/generic.lua:7-9` — installs into `python3.13`, but this
   tree's interpreter is Python 3.14.** `packages/python/source.lua:2` pins
   `3.14.7` and the interpreter installs to `$PREFIX/lib/python3.14/`, so
   `import wheel` fails at runtime. **Confirmed on disk**: the nest has
   `lib/python3.13/site-packages/wheel/` next to
   `lib/python3.14/site-packages/setuptools/`.

   Replace lines 7-9 with:

   ```sh
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r src/wheel $OUT/lib/python3.14/site-packages/
        cp LICENSE.txt $OUT/lib/python3.14/site-packages/wheel/LICENSE.txt
   ```

   and append to the comment at lines 5-6, matching
   `packages/flit-core/generic.lua:9-11`:

   ```sh
        # CPython 3.14's install scheme. packages/python pins 3.14.7, so this
        # is the only site-packages its interpreter searches; a python
        # version bump means updating this line.
   ```

## Note on the missing dist-info

The comment at lines 5-6 says dist-info metadata is skipped because it would
need a host `pip3`. That is consistent with the other pure-Python entries and
with `setuptools`, which *does* ship a `setuptools-84.0.0.dist-info`
directory in the nest. That inconsistency is worth a note in the forecast but
is not a build failure — `wheel`'s own API is importable without dist-info.
If any recipe later calls `importlib.metadata.version("wheel")`, it will need
the dist-info; say so in the forecast now rather than debugging it later.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/python3.14/site-packages/wheel/__init__.py` | `test -f $PREFIX/lib/python3.14/site-packages/wheel/__init__.py` |
| **the check that catches this bug** | `test ! -e $PREFIX/lib/python3.13` |
| no C extension to verify | nothing to build; `find $PREFIX/lib/python3.14/site-packages/wheel -name '*.so'` → empty |