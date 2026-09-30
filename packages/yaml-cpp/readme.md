# yaml-cpp

yaml-cpp is a YAML 1.2 parser and emitter for C++, with a value-tree API
that reads like the document it parsed. It is one of the few YAML libraries
that does not require an external parser and is small enough to vendor.

```cpp
#include <yaml-cpp/yaml.h>

YAML::Node config = YAML::LoadFile("config.yaml");

std::string host = config["server"]["host"].as<std::string>();
int port = config["server"]["port"].as<int>();

for (const auto &entry : config["tags"]) {
    std::cout << entry.as<std::string>() << '\n';
}

YAML::Emitter out;
out << YAML::BeginMap << YAML::Key << "port" << YAML::Value << port << YAML::EndMap;
std::cout << out.c_str();
```

The tree is a `YAML::Node` that is a map, a sequence or a scalar, and
`as<T>()` converts leaves. A missing key yields an undefined node rather
than an exception, so `if (node)` is the idiomatic check; `Node::operator[]`
on a missing key returns an undefined node instead of creating one.

Two behaviours are worth knowing before you point it at untrusted input:
aliases can expand exponentially (there is a node-count budget in newer
releases, but not a complete defence), and `Load` throws
`YAML::ParserException` with a mark on bad input.

## What retrolunar builds

A static `libyaml-cpp.a`, the `yaml-cpp/` headers and `yaml-cpp.pc`. Tests,
tools and utilities are off: they are host programs and this prefix is for
the library.

## Using it

```sh
pkg-config --cflags --libs yaml-cpp
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` plus yaml-cpp's own
  switches for what to skip.
- The library is C++ and uses exceptions, so the consumer's toolchain must
  match; the Android systems here build it with the default NDK C++
  settings.
- YAML is a superset of JSON, so this also reads `.json`, but it is not a
  drop-in replacement for a JSON library when you want strict parsing.
