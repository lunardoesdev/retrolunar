# libyaml

libyaml is the reference YAML implementation in C: event-driven, strict,
and the library most other YAML parsers borrow from. It does not build a
document tree — it emits events (STREAM_START, DOCUMENT_START, MAPPING_START,
SCALAR, …) and lets the caller decide what to do with them.

```c
#include <yaml.h

yaml_parser_t parser;
yaml_event_t event;

yaml_parser_initialize(&parser);
yaml_parser_set_input_string(&parser, (const unsigned char *)input, length);

while (yaml_parser_parse(&parser, &event)) {
    if (event.type == YAML_SCALAR_EVENT) {
        printf("[%.*s]\n", (int) event.data.scalar.length, event.data.scalar.value);
    }
    yaml_event_delete(&event);
}
yaml_parser_delete(&parser);
```

To get a tree instead, use the higher-level document API
(`yaml_parser_load` + `yaml_document_get_root_node`) and walk
`yaml_node_t`. It is less code and still bounded by libyaml's limits.

Aliases and anchors are handled by the parser, but anchor expansion is
bounded by `yaml_parser_set_alias_limit` (and a byte limit in newer
releases), which is what stops a "billion laughs"-style document from
exhausting memory. Keep the limits set.

## What retrolunar builds

A static `libyaml.a`, `yaml.h` and `yaml-0.1.pc`. The reference parser
(`run-parser`), the hpricot test tool, the docs and the Python bindings are
off.

## Using it

```sh
pkg-config --cflags --libs yaml-0.1
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the recipe
  adds only package facts: static, `-fpic`, host tools off.
- The tarball comes from pyyaml.org, which is upstream's canonical release
  host. The GitHub tag archive has no generated `configure`, so it cannot be
  used here; the recipe falls back to the GitHub *release* asset, which does.
- libyaml validates strictly. YAML 1.1 booleans (`yes`, `on`) and the 1.2
  octal rules differ between implementations; libyaml follows YAML 1.1 core
  schema resolution, which surprises people moving from Python 3's parser.
