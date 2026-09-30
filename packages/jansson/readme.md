# Jansson

Jansson is a C library for encoding, decoding and manipulating JSON. It is
small, permissive (MIT), and it is stricter than most parsers about what it
accepts, which is the main reason to pick it: the decoder rejects trailing
garbage, unescaped control characters and trailing commas instead of
quietly tolerating them.

Encoding is a value tree built with `json_object`, decoding is
`json_loadb` with an error code, and there is a `json_dump` family with
pretty and compact modes.

```c
#include <jansson.h>

json_t *root = json_object();
json_object_set_new(root, "name", json_string("retrolunar"));

json_error_t error;
json_t *parsed = json_loadb(input, length, 0, &error);
if (parsed == NULL) {
    fprintf(stderr, "%s at line %d\n", error.text, error.line);
}

char *text = json_dumps(root, JSON_COMPACT);
json_decref(root);
```

`json_decref` releases the whole subtree; every `json_t*` you own needs one.

## What retrolunar builds

A static `libjansson.a`, `jansson.h` and `jansson.pc`. Static because a
target prefix should not carry a shared object that nothing on the device
will load from the right soname path.

## Using it

```sh
pkg-config --cflags --libs jansson
```

## Notes

- Autotools build, so the recipe passes `$AUTOCONF_CONFIGURE_FLAGS` and adds
  only the package's own choices: `--enable-static --disable-shared
  --with-pic`. The picture is needed because the archive has to link into
  shared objects, and `--disable-shared` keeps the install to one file.
- The Autotools timestamp guard is present because the release tarball
  carries mtimes that would otherwise make make re-run `aclocal`.
- Upstream also ships a CMake build and an `android/` directory; the
  Autotools path is the one retrolunar uses, since the system already
  provides the host triplet and flags.
