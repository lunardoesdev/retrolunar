# Little CMS

Little CMS (lcms2) is a small colour management engine: ICC profiles in,
device links and transforms out. It is the library to reach for when a
program needs to convert colours between two profiles correctly — display
to display, display to printer, or an embedded profile to a working space.

The API is profile-first. Open a profile with `cmsOpenProfileFromMem` or
`cmsOpenProfileFromFile`, create a transform with `cmsCreateTransform` for a
given intent and input/output formats, and run `cmsDoTransform`.

```c
#include <lcms2.h>

cmsHPROFILE in  = cmsOpenProfileFromMem(icc, icc_len, "r");
cmsHPROFILE out = cmsCreate_sRGBProfile();
cmsHTRANSFORM t = cmsCreateTransform(in, TYPE_BGRA_8, out, TYPE_BGRA_8,
                                    INTENT_PERCEPTUAL, 0);
cmsDoTransform(t, pixels, pixels, pixels_size);
cmsDeleteTransform(t);
```

`cmsCreate_sRGBProfile()` needs no file, which is the easy path. For
anything else, ship the ICC profile as a data blob and open it from memory;
lcms2 does not look for profiles on disk.

Pixel formats are `TYPE_<layout>_<channels>_<bits>`, so the transform's
input and output formats are explicit rather than inferred — get them
right, because lcms2 does not check that your buffer matches the declared
format.

## What retrolunar builds

A static `liblcms2.a`, `lcms2.h` and `lcms2_plugin.h`, and `lcms2.pc`.
Built with the JPEG and TIFF plug-ins from this prefix (`libjpeg-turbo` and
`libtiff`), which is what lets lcms2 read and write those embedded
profiles. The utilities (`jpgicc`, `tificc`, `transicc`, `linkicc`) and the
Python bindings are off.

## Using it

```sh
pkg-config --cflags --libs lcms2
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the recipe
  adds only package facts: static, `-fpic`, the two plug-ins pointed at this
  prefix, and the host utilities off.
- lcms2 has its own threading model (it can use a plug-in thread pool set
  with `cmsFLAGS`); the default of no threads is fine for a single-threaded
  pipeline.
- Colour management is only as good as the profiles. lcms2 implements the
  maths faithfully, but a display profile that does not match the actual
  display will give you perfectly wrong colours.
