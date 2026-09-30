# simdjson

simdjson is a JSON parser for C and C++ that uses SIMD to stay several
times faster than the usual parsers while still being exact: it follows
RFC 8259, including the UTF-8 validation that most parsers skip.

The API is a three-stage pipeline, and the stages are separate on purpose —
you can reuse one parser for many documents:

```cpp
#include "simdjson.h"

auto parser = simdjson::dom::parser();
simdjson::padded_string doc = simdjson::padded_string::load("file.json");

simdjson::dom::element result;
auto error = parser.parse(doc, result);
if (error) { std::cerr << error.what() << '\n'; return 1; }

uint64_t id;
if (!result["id"].get(id)) { /* wrong type */ }
```

`ondemand::document` is the newer, zero-allocation interface with the same
shape. A `padded_string` is required for `parse` because the parser reads in
wide chunks and will over-read otherwise.

`SIMDJSON_ENABLE_THREADS=ON` is the default and pulls in pthread; the
Android systems already provide it.

## What retrolunar builds

A static `libsimdjson.a`, the normal headers, the generated single header
`simdjson.h`, `simdjson.pc` and a CMake package config. The implementation
is chosen at runtime from the CPU, so the same archive works on every
aarch64 device.

Only the `simdjson` target is built. simdjson's CMake unconditionally adds
its tests, examples, benchmarks and fuzzers on 64-bit hosts with no option
to disable them, and those are host programs — the benchmark links `-lrt`,
which Bionic does not have. Naming the target is the documented way to build
just the library; every install rule hangs off it.

## Using it

```sh
pkg-config --cflags --libs simdjson
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and the target name.
- The Android systems carry `-lm` in `LDFLAGS`, which matters here:
  simdjson's number-parsing path calls `log10`, and Bionic keeps that in
  libm.
