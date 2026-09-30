# toml++

toml++ is a header-only TOML parser for C++, in the same spirit as
nlohmann/json: one include, no build step, and an API that looks like the
document. It is fast enough for configuration files and strict enough that
it rejects invalid TOML instead of guessing.

```cpp
#include <toml++/toml.h>

auto config = toml::parse_file("config.toml");

std::string host = config["server"]["host"].as_string();
int port = config["server"]["port"].as_integer();

for (auto&& entry : config["tags"]) {
    std::cout << entry.as_string() << '\n';
}
```

`toml::parse` takes a string_view; `toml::parse_file` returns a
`toml::table`. The tree is `toml::node`, which is a table, array, or
value, and `as<T>()` converts leaves. `toml::find()` gives you an optional
node instead of throwing when a key is missing, and `toml::from<T>(node)`
maps a table onto your own struct.

## What retrolunar builds

Nothing is compiled. The install copies `toml++/toml.hpp` (plus the forward
header and the C shim `toml.h`) into `$PREFIX/include/toml++/`, and installs
a CMake package config under `lib/cmake/tomlplusplus/`.

toml++ ships no pkg-config file, so CMake consumers use
`find_package(tomlplusplus)` and `toml::tomlplusplus`; everyone else adds
`$PREFIX/include` and includes `<toml++/toml.h>`.

## Notes

- CMake build, but only its install rules do any work here: the library is
  header-only, so the recipe passes `$CMAKE_FLAGS` for consistency and
  nothing else.
- `TOMLPLUSPLUS_BUILD_TESTS=OFF` keeps the test suite (thousands of
  host-only assertions) out of the build.
- The C header `toml.h` is a convenience shim for C projects; the real API
  is C++.
