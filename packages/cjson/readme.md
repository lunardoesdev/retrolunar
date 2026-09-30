# cJSON

cJSON is a small, fast JSON parser and generator written in ANSI C. It is
the pragmatic choice when a project needs to read or emit JSON without
taking on a dependency, and it is small enough to vendor if you would
rather not have a package at all.

Parsing produces a tree of `cJSON` nodes linked through `child`/`next`;
printing walks that tree. Numbers are parsed with `strtod`, so the full
double range survives a round trip.

```c
#include <cJSON.h>

cJSON *root = cJSON_Parse(text);
if (root == NULL) {
    /* cJSON_GetErrorPtr() points into the input at the failure */
}
const cJSON *name = cJSON_GetObjectItemCaseSensitive(root, "name");
cJSON *copy = cJSON_Duplicate(root, 1);
char *out = cJSON_PrintUnformatted(copy);
```

The parser is not hardened against hostile input by itself: it walks the
document once and allocates per node, so bound the size of what you feed it.

## What retrolunar builds

`libcjson.a`, `cJSON.h` and the two utility programs, `cJSON_add` and
`cJSON_pretty`. The upstream test program is switched off because it is a
host-side executable.

cJSON 1.7.18 does not install a pkg-config file, so consumers reference the
library as `-lcjson` and the header as `cjson/cJSON.h` after adding
`$PREFIX/include`.

## Notes

- The build is CMake, so the recipe passes only `$CMAKE_FLAGS`; the
  toolchain, install prefix and search prefix come from the system.
- `ENABLE_CJSON_TEST=OFF` also keeps the build from compiling the test
  harness, which would otherwise be a second, unused binary.
