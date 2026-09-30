# toml11

toml11 is a header-only TOML parser and serialiser for C++ with a type-safe
mapping: you can read a document straight into your own structs, and it
rejects malformed input at parse time rather than leaving defaults behind.

```cpp
#include <toml11/toml.hpp>

struct server { std::string host; int port; };
struct config { std::string name; std::vector<std::string> tags; server srv; };

config cfg = toml::parse<config>("config.toml");
std::cout << cfg.srv.host << ':' << cfg.srv.port << '\n';

toml::value v = toml::parse("x.toml");
v["new"]["key"] = 42;
std::cout << toml::format(v) << '\n';
```

`toml::parse<T>` requires `T` to be an aggregate that mirrors the document,
with `toml::find<T>` for optional sub-tables and `toml::get<T>` when you want
an exception. For generic traversal use the `toml::value` tree.

The strictness is the feature: duplicate keys, wrong types and unknown
fields are errors at parse time, so a config typo fails loudly.

## What retrolunar builds

Nothing is compiled. The install copies the headers into
`include/toml11/` (and the single-header convenience form into
`include/toml.hpp`), and installs a CMake package config under
`lib/cmake/toml11/`. The test suite is off.

There is no pkg-config file, so CMake consumers use `find_package(toml11)`
and link `toml11::toml11`; everyone else adds `$PREFIX/include` and includes
`<toml11/toml.hpp>`.

## Notes

- CMake build, but only its install rules do work here: the library is
  header-only, so the recipe passes `$CMAKE_FLAGS` for consistency and
  nothing else.
- toml11 requires C++17 (or later) for `toml::parse<T>`; the older
  `toml::find`/`get` API has looser requirements.
- tomlplusplus is in this prefix too and is a reasonable alternative: it
  takes a tree-first approach where toml11's is type-first.
