ACCEPT

# lcms2 — stage 2 review

## What the recipe gets right

- **`make -j1` at line 12** — serialised correctly.
- The guard at line 10 is the standard form; lcms2 ships a top-level
  `config.h.in`.
- `--disable-utils` keeps `jpgicc`, `tificc`, `linkicc` and `tifficc` out — the
  lcms2 equivalent of the libseccomp defect, correctly avoided here.
- `--without-python` avoids a binding needing an interpreter at build time.
- `--with-jpeg="$PREFIX" --with-tiff="$PREFIX"` take the dependency prefixes
  from the system's `$PREFIX` rather than hardcoding one, and both packages
  are `require`d so they are in the queue first.
- `--enable-static --disable-shared --with-pic` matches the prefix convention.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`, no exported search flag.

## What the forecast should add — and it matters here

lcms2's plugin modules (`libcms_jpeg`, `libcms_tiff`) install as separate
`.so` files **even in a static build**, because lcms2 loads them at runtime via
`dlopen`. So the modules install, but a static consumer cannot use them, and a
target prefix has no loader path for the target anyway. The forecast should
say so plainly: it looks fine in a file listing and is useless in practice.
If that matters, the honest choice is `--without-jpeg --without-tiff` and a
smaller lcms2; if not, record it as a known limitation.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/liblcms2.a` | `ls $PREFIX/lib/liblcms2.*` — static |
| `$PREFIX/include/lcms2.h`, `lcms2_plugin.h` | `test -f $PREFIX/include/lcms2.h` |
| `$PREFIX/lib/pkgconfig/lcms2.pc` | `pkg-config --modversion lcms2` |
| plugins present but unloadable | `ls $PREFIX/lib/liblcms2_*.so` — present; these are `dlopen` plugins, unusable by a static consumer |
| no utils | `test ! -e $PREFIX/bin/jpgicc`, proving `--disable-utils` took |
