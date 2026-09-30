# giflib

giflib is the reference GIF codec: it reads and writes GIF, including the
animation and interlace handling that most "GIF support" gets wrong. It is
old, small, and still the thing to reach for when a format says GIF.

The API is two pairs of calls. `DGifOpenFileName`/`DGifSlurp` to read, and
`EGifOpenFileName`/`EGifPutImageDesc` plus `EGifPutLine` to write; each
drawing operation takes an `GifFileType` with a save function you supply,
which is how the library stays format-agnostic about I/O.

```c
#include <gif_lib.h>

int err = 0;
GifFileType *gif = DGifOpenFileName(path, &err);
if (gif == NULL) { fprintf(stderr, "GIF open error %d\n", err); return 1; }

if (DGifSlurp(gif) != GIF_OK) { /* truncated or malformed */ }
for (int i = 0; i < gif->ImageCount; i++) {
    const SavedImage &img = gif->SavedImages[i];
    /* img.ImageDesc.Width/Height, img.RasterBits */
}
DGifCloseFile(gif, &err);
```

Writing an animation means one `EGifPutImageDesc` per frame into the same
`GifFileType` with a delay in the `Gif89a` extension. A decoder that only
needs the first frame can use `DGifGetImageDesc` and stop.

## What retrolunar builds

A static `libgif.a` and `gif_lib.h`. Only `install-lib` and
`install-include` are run, so the `giftext`/`gifbuild` utilities and the
manual pages stay out of the prefix.

giflib does **not** install a pkg-config file, so link `-lgif` and add
`$PREFIX/include`.

## Notes

- The build is upstream's plain makefile, not Autotools, so there is no
  `configure`: the recipe hands it the system's `CC`, `CFLAGS`, `LDFLAGS`
  and `PREFIX` directly.
- `EGifPutLine` needs an `int (*WriteFunc)(GifFileType *, const GifPixelType *, int)`
  callback. Writing a file is therefore a few lines of user code, which is
  why the utilities are not needed for real use.
- This is the GIF side only. For WebP or AVIF, use libwebp and libjxl from
  this prefix; they are not GIF.
