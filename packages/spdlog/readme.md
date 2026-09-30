# spdlog

spdlog is a fast logging library for C++ built on fmt. It gives you the
fmt formatting syntax, compile-time-off (or on) log levels, several sink
types out of the box, and a printf-style API when you want it.

```cpp
#include <spdlog/spdlog.h>

auto log = spdlog::stdout_color_mt("app");
log->info("starting {}", name);
log->warn("disk {}/{} used: {:.1%}", used, total, ratio);
SPDLOG_LOGGER_CRITICAL("cannot open {}", path);
```

Levels are compile-time filterable (`SPDLOG_ACTIVE_LEVEL`), which removes
disabled branches entirely at build time. Sinks include stdout, stderr,
basic file, rotating file, daily file, syslog and Android's logcat. An async
logger moves formatting onto a worker thread with a ring buffer, which is
what you want if logging is on a hot path.

## What retrolunar builds

A static `libspdlog.a`, the `spdlog/` headers and `spdlog.pc`. Built with
`SPDLOG_FMT_EXTERNAL=ON` so it formats through the fmt library from this
prefix rather than carrying its own bundled copy — one formatting engine
across the tree, and one set of fmt flags at link time.

Examples, hooks, tests and benchmarks are off: host programs.

## Using it

```sh
pkg-config --cflags --libs spdlog
```

That pulls in `fmt` through spdlog's pkg-config `Requires`, so nothing else
is needed on the link line.

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` plus spdlog's own
  switches.
- Because spdlog was configured against external fmt, every consumer must
  use the same fmt; the Android prefix has exactly one.
- The Android-specific spdlog sink writes to logcat through liblog. That
  library ships with the NDK platform, not with this prefix, so a program
  using the android sink needs the platform's `liblog` at link time.
