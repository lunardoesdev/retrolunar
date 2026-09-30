# TinyXML-2

TinyXML-2 is a small, permissive XML parser and serialiser in C++. It is
the XML library you pick when the documents are configuration files, not
arbitrary user input: it parses the common cases quickly, the API fits in
your head, and the whole thing is a handful of files.

It is not a validating parser and not a DOM you can query fluently — it is a
document made of `XMLDocument`, `XMLElement`, `XMLAttribute` and `XMLText`
nodes you walk yourself.

```cpp
#include <tinyxml2.h>
using namespace tinyxml2;

XMLDocument doc;
if (doc.Parse(xml) != XML_SUCCESS) {
    fprintf(stderr, "%s at line %d\n", doc.ErrorStr(), doc.ErrorLine());
    return 1;
}

const XMLElement *root = doc.RootElement();
for (const XMLElement *child = root->FirstChildElement();
     child; child = child->NextSiblingElement()) {
    const char *name = child->Attribute("name");
}
```

`XMLPrinter` serialises back to text, and `XMLWriter` builds a document
incrementally. Whitespace handling is explicit (`PreserveWhiteSpace`), so
documents round-trip predictably.

## What retrolunar builds

A static `libtinyxml2.a`, `tinyxml2.h` and `tinyxml2.pc`. The bundled
`xmltest` program and the C tests are switched off: they are host programs,
and a target prefix exists to produce libraries.

## Using it

```sh
pkg-config --cflags --libs tinyxml2
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` plus tinyxml2's own
  options for what to skip.
- The library is C++, so a C project linking it needs the C++ runtime on the
  link line (`clang++`, or `-lstdc++`).
- TinyXML-2 does not resolve external entities, DTDs or namespaces beyond
  keeping their text. That is fine for configuration files and wrong for
  hostile input; use a real XML parser when the document comes from a user.
