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

`libcjson.a`, `cJSON.h`, and `libcjson.pc`. The upstream test program is
switched off because it is a host-side executable.

The module is `libcjson`, so `pkg-config --modversion libcjson` reports
`1.7.19`. Consumers may equally reference the library as `-lcjson` and the
header as `cjson/cJSON.h` after adding `$PREFIX/include`, or use
`find_package(cJSON)`.

Two claims in an earlier version of this file were wrong and are corrected
here. **`cJSON_add` and `cJSON_pretty` do not exist in 1.7.19** — the utils
are the `cjson_utils` *library* behind `ENABLE_CJSON_UTILS`, which defaults
OFF and is not enabled by the recipe, so nothing but the core library is
installed. And **cJSON does install a pkg-config file**:
`CMakeLists.txt:142-146` configures `libcjson.pc` from
`library_config/libcjson.pc.in` and installs it, so it is inside the
loader's `$OUT`→`$PREFIX` rewrite set. The version was also off: the recipe
pins 1.7.19, not 1.7.18.

## Notes

- The build is CMake, so the recipe passes only `$CMAKE_FLAGS`; the
  toolchain, install prefix and search prefix come from the system.
- `ENABLE_CJSON_TEST=OFF` also keeps the build from compiling the test
  harness, which would otherwise be a second, unused binary.
