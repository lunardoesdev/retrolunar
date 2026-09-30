# nlohmann-json

nlohmann/json is a header-only C++11 JSON library. One `#include`, no
build step, no dependency: `nlohmann/json.hpp` is the whole library. It is
the most widely used JSON library in modern C++, and the reason is the API
— `json j = json::parse(text)` and then `j["key"][0]` — combined with the
fact that adding it to a project costs one file.

Three representations ship: `nlohmann::json` (dynamic), `json_fwd.hpp` for
forward declarations, and a meta-language backport if you must stay on
C++03.

```cpp
#include <nlohmann/json.hpp>
using json = nlohmann::json;

json j = json::parse(R"({"name":"retrolunar","tags":[1,2,3]})");
for (const auto& tag : j["tags"]) {
    std::cout << tag << '\n';
}
std::string text = j.dump(2);
```

Parsing is strict by default (no comments, no trailing commas, no NaN) with
`ignore_comments` and friends available as parse callbacks. Exceptions are
thrown on failure unless you ask for `parse` with a `false` return, or use
`at()`/`value()` for non-throwing access.

## What retrolunar builds

Nothing is compiled. The install target copies `nlohmann/json.hpp` (and the
other headers) into `$PREFIX/include`, plus a CMake package config and
`nlohmann_json.pc`, so CMake consumers get `find_package(nlohmann_json)` and
pkg-config consumers get `pkg-config --cflags nlohmann_json`.

Because it is header-only, the recipe's cmake run only exists to install
files. The toolchain flags are harmless here and keep the recipe uniform
with the rest of the tree.

## Notes

- `JSON_BuildTests=OFF` keeps a test suite that would otherwise compile
  hundreds of translation units of host-only code.
- No ABI, no library file, no link step: this package adds nothing to a
  link line.
