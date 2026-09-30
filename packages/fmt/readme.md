# fmt

fmt is a formatting library for C++: `{}` placeholders, compile-time type
checking when you use the C++20 `std::format` interface or `FMT_COMPILE`, and
a `printf`-compatible path out of the box. It is fast enough that the cost
disappears next to the I/O it feeds, and the output is stable enough to
diff in tests.

```cpp
#include <fmt/core.h>
#include <fmt/format.h>

std::string s = fmt::format("{} of {} ({:.1%})", done, total, fraction);
fmt::print("hello {}\n", name);
```

`fmt::format` writes into a caller-provided buffer when you care about
allocations, and `fmt::format_to_n` is the no-exception variant. Compile-time
format string checking is available through `fmt/compile.h` and, since 11,
through the `std::format` compatibility header when the standard library
provides one.

## What retrolunar builds

A static `libfmt.a`, the `fmt/` headers, `fmt-base.h`, `fmt.pc` and a CMake
package config. The test suite and the bundled `format` program are off:
they are host programs.

## Using it

```sh
pkg-config --cflags --libs fmt
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and fmt's own switches
  for what to skip.
- fmt is header-heavy but not header-only: `libfmt.a` holds the
  `format_error` machinery and the locale helpers, so link the archive.
- Consumers that want `std::format` rather than `fmt::format` can include
  `fmt/format.h` with `FMT_USE_NONTYPE_TEMPLATE_ARGS` tuned to the NDK's
  C++20 support; the default here is the library's own interface.
