# pugixml

pugixml is a light-weight XML parser for C++ with a DOM interface, XPath
1.0 support, and no dependencies. It is the XML library to reach for when a
document is configuration-sized: the whole thing is three files
(`pugixml.cpp`, `pugixml.hpp`, `pugixml.hpp`) and builds in seconds.

```cpp
#include <pugixml.hpp>

pugi::xml_document doc;
pugi::xml_parse_result result = doc.load_file("config.xml");
if (!result) {
    fprintf(stderr, "%s at line %d\n", result.description(), result.offset);
    return 1;
}

for (pugi::xml_node node : doc.select_nodes("//server")) {
    std::cout << node.attribute("host").as_string() << '\n';
}
```

`select_node` and `select_nodes` take an XPath 1.0 expression and return
nodes or a `xml_node_set`. Attribute values are strings until you ask for a
type with `as_int()`, `as_bool()` or `as_double()`, and the conversions are
explicit rather than silent.

Pugixml is not a validating parser and does not resolve external entities
or DTD-defined entities beyond skipping them, which is a reasonable default
for configuration files and the wrong one for hostile input.

## What retrolunar builds

A static `libpugixml.a`, `pugixml.hpp`, `pugixml.hpp`-adjacent headers and
`pugixml.pc`, plus a CMake package config. The test suite is off.

## Using it

```sh
pkg-config --cflags --libs pugixml
```

CMake consumers use `find_package(pugixml)` and link `pugixml::pugixml`.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and pugixml's own switch
  for tests.
- The library is C++, so a C project needs the C++ runtime on the link
  line.
- For very large documents the memory- or speed-oriented
  `pugixml::pugixml_ns` variant trades convenience for control; this build
  uses the default namespace-aware variant.
