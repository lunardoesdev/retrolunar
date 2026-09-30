# utf8proc

utf8proc is a small C library for Unicode text processing with two things
going for it: it is a *library* rather than a table dump, and it is
reasonably fast. It gives you UTF-8 and UTF-32 conversion, Unicode
normalisation (NFC, NFD, NFKC, NFKD), general category and property
lookup, and case folding, all against tables compiled into the library.

The API you will actually use:

```c
#include <utf8proc.h>

const utf8proc_property_t *props = utf8proc_get_property(codepoint);
utf8proc_int32_t folded[4];
utf8proc_map(str, 0, &folded[0], 4, UTF8PROC_CASEFOLD | UTF8PROC_STABLE);
utf8proc_NFC(normalised, utf8proc_NFC, buffer, size);
```

`utf8proc_map` allocates through the supplied buffer, so no malloc is
involved. `utf8proc_iterate` walks one code point at a time and is the
right tool for validating a UTF-8 string.

## What retrolunar builds

`libutf8proc.a`, `utf8proc.h` and `utf8proc.pc`. The `data/` scripts in
the source tree are build-time tools for regenerating the tables; the
tables themselves are compiled in, so the install carries no data files.

## Using it

```sh
pkg-config --cflags --libs libutf8proc
```

## Notes

- CMake build; the recipe passes `$CMAKE_FLAGS` only.
- `-DBUILD_SHARED_LIBS=OFF` keeps the prefix to one static archive, which
  also avoids a runtime dependency on the C++-adjacent C++ runtime the
  upstream shared build pulls in.
