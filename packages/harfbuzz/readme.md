# HarfBuzz

HarfBuzz is the text shaping engine: it takes a sequence of characters plus
a font and produces the glyphs, positions and advances a renderer needs. It
is what Pango, Firefox, Chromium, LibreOffice and every serious text stack
uses for shaping, because correct shaping (ligatures, kerning, mark
attachment, script runs, complex-script reordering) is a large amount of
detailed logic.

The API is buffer-based: fill a buffer, set the direction and script and
font, shape, read the results.

```c
#include <hb.h>

hb_blob_t *blob = hb_blob_create_from_file("font.ttf");
hb_face_t *face = hb_face_create(blob, 0);
hb_font_t *font = hb_font_create(face);

hb_buffer_t *buf = hb_buffer_create();
hb_buffer_add_utf8(buf, text, -1, 0, -1);
hb_buffer_set_direction(buf, HB_DIRECTION_LTR);
hb_buffer_set_script(buf, HB_SCRIPT_LATIN);

hb_shape(font, buf, NULL, 0);

unsigned count;
hb_glyph_info_t *info = hb_buffer_get_glyph_infos(buf, &count);
hb_glyph_position_t *pos = hb_buffer_get_glyph_positions(buf, &count);
for (unsigned i = 0; i < count; i++) {
    draw_glyph(info[i].codepoint, pos[i].x_offset, pos[i].y_offset);
}
```

The font is where the work happens: `hb_font_create` plus
`hb_font_set_scale` and, for real rendering, FreeType callbacks for glyph
outlines — which is why this build wires HarfBuzz to the FreeType in this
prefix. Glyph information and positions are in font units; the caller scales.

Set `hb_buffer_set_cluster_level` and `hb_buffer_set_flags` when you need
careful cursor mapping back to the source text, which is what text editors
use for selection and IME behaviour.

## What retrolunar builds

A static `libharfbuzz.a` with the FreeType and FriBidi integrations, the
`hb.h` family of headers, and `harfbuzz.pc`. Tests (a googletest suite),
utilities, introspection, glib/gobject/cairo/ICU and Graphite2 are all off.

## Using it

```sh
pkg-config --cflags --libs harfbuzz
```

FreeType and FriBidi come in through the same pkg-config line, since this
build enables those integrations.

## Notes

- Meson build with the system's `$MESON_FLAGS`, plus `-Ddefault_library=static`
  (meson would otherwise build a shared library) and the option switches for
  the host-side tests and utilities.
- The shape of the API is deliberately font-agnostic: the core shapes
  without knowing how to draw, so a caller can render with FreeType, Skia,
  CoreText or something custom. Only the optional integrations pull in
  libraries.
- HarfBuzz does not do bidi reordering of characters — that is FriBidi's
  job, which is why both are here and why `hb_buffer_set_direction` takes a
  resolved direction rather than raw text.
