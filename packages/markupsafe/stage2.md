REJECT

# markupsafe — stage 2 review

## Required changes

1. **`packages/markupsafe/generic.lua:7-9` — installs into `python3.13`, but
   this tree's interpreter is Python 3.14.** `packages/python/source.lua:2`
   pins `3.14.7` and the interpreter installs to `$PREFIX/lib/python3.14/`, so
   `import markupsafe` fails at runtime. **Confirmed on disk**: the current
   nest has `lib/python3.13/site-packages/markupsafe/` alongside
   `lib/python3.14/site-packages/setuptools/`.

   Replace lines 7-9 with:

   ```sh
        mkdir -p $OUT/lib/python3.14/site-packages
        cp -r src/markupsafe $OUT/lib/python3.14/site-packages/
        cp LICENSE.txt $OUT/lib/python3.14/site-packages/markupsafe/LICENSE.txt
   ```

   and append to the comment at lines 5-6, matching
   `packages/flit-core/generic.lua:9-11`:

   ```sh
        # CPython 3.14's install scheme. packages/python pins 3.14.7, so this
        # is the only site-packages its interpreter searches; a python
        # version bump means updating this line.
   ```

## Note on the skipped C accelerator

The comment at lines 6-7 says the optional `_speedups` C accelerator is not
built and the module falls back to `_native.py`. That is correct and is a
deliberate, defensible choice — but make sure the forecast records it as a
*behavioural* difference, because MarkupSafe's pure-Python fallback is
noticeably slower and it is exactly the sort of thing that looks like a build
failure later. It is not one now.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/python3.14/site-packages/markupsafe/__init__.py` | `test -f $PREFIX/lib/python3.14/site-packages/markupsafe/__init__.py` |
| pure-Python fallback present | `test -f $PREFIX/lib/python3.14/site-packages/markupsafe/_native.py` |
| no compiled accelerator | `find $PREFIX/lib/python3.14/site-packages/markupsafe -name '*.so'` → empty |
| **the check that catches this bug** | `test ! -e $PREFIX/lib/python3.13` |