# FriBidi

FriBidi implements the Unicode Bidirectional Algorithm (UAX #9): given text
with mixed scripts and directionality — an Arabic phrase inside an English
sentence — it tells you which visual order to render it in and which
characters are mirrored.

It is the library Pango, HarfBuzz and GTK sit on, and it is hard to
replace: the algorithm has a large set of rules and the data tables come
from the Unicode Character Database, so implementations are mostly generated
against a specific Unicode version.

```c
#include <fribidi/fribidi.h>

FriBidiParType direction = FRIBIDI_PAR_LTR;
FriBidiChar *logical = ...;  /* UTF-8, n characters */
FriBidiStrIndex maps_nesting;
FriBidiLevel max_level;
FriBidiCharType types_n_paragraph;

fribidi_get_bidi_types(logical, len, &types_n_paragraph);
fribidi_get_par_embedding_levels(types_n_paragraph, len, &direction,
                                 &maps_nesting, &max_level);

FriBidiChar *visual = malloc(len * sizeof *visual);
fribidi_reorder_line(FRIBIDI_FLAGS_DEFAULT, logical, len, 0, direction,
                     types_n_paragraph, visual);
```

The three-stage shape is deliberate: resolve paragraph direction first
(UAX #9 rule P2/P3 need the whole paragraph), then compute embedding
levels, then reorder a line. Reordering a line on its own is what you want
for rendering, and it is the stage most callers use.

**FriBidiChar is `char`, and strings are UTF-8** — the library does not
transcode. UTF-32 callers must convert first.

## What retrolunar builds

A static `libfribidi.a`, the `fribidi/` headers including the generated
`fribidi-unicode-version.h`, and `fribidi.pc`. Tests, docs and the command
line tools are off.

## Using it

```sh
pkg-config --cflags --libs fribidi
```

## Notes

- Meson build with the system's `$MESON_FLAGS` (which carries the cross file
  and `--prefix=$OUT`). Two package facts are added: `default_library=static`,
  because meson defaults to shared and a target prefix has no loader path for
  a versioned object, and `tests`/`docs`/`bin` off.
- No `DESTDIR` on the install step: meson's `--prefix` is already `$OUT`, and
  `DESTDIR=$OUT ninja install` would concatenate the two into `$OUT$OUT`.
- The tables are generated at build time from the bundled Unicode data, so
  the Unicode version this build supports is whatever the release ships. It is
  written into `fribidi-unicode-version.h` for callers that need to check.
