# libuv

libuv is the cross-platform asynchronous I/O library Node.js is built on.
It wraps the differences between epoll, kqueue, IOCP and the rest behind
one loop with three families of primitives:

- **handles** — long-lived things the loop owns: timers, TCP/UDP sockets,
  pipes, TTYs, DNS queries, file-system events, process spawning.
- **requests** — one-shot operations: `uv_fs_open`, `uv_getaddrinfo`,
  `uv_fs_read`.
- **streams** — the readable/writable pair on top of TCP, TTY, pipe and
  file handles, with backpressure.

Everything is callback or `uv_async`-driven; there is no scheduler of its
own.

```c
#include <uv.h>

uv_loop_t loop;
uv_timer_t timer;
uv_timer_init(&loop, &timer);
timer.data = "tick";
uv_timer_start(&timer, on_timer, 100, 0);
uv_run(&loop, UV_RUN_DEFAULT);
uv_loop_close(&loop);
```

The callback runs on the loop thread, so it must not block: hand slow work to
a thread pool (`uv_queue_work`) and get woken back with `uv_async_send`.
`uv_run` returns when there is nothing left to do, which is why a loop that
only holds idle handles exits immediately.

## What retrolunar builds

A static `libuv.a`, the `uv.h` header with its `uv/` subdirectory, and a
CMake package config under `lib/cmake/libuv/`. Tests, benchmarks and the
documentation are off.

libuv 1.51.0 does **not** install a pkg-config file, so CMake consumers use
`find_package(libuv)` with `$PREFIX` in `CMAKE_PREFIX_PATH`, and everyone
else links `-luv` with `$PREFIX/include`.

The `uv_run`/`luvc` sample tools upstream ships in `tools/` are not part of
the install.

## Using it

```c
/* link: -luv -lpthread */
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and libuv's own switches.
- On Android, libuv reads the eventfd and pipe abstractions from Bionic;
  there is no separate epoll or timerfd path to configure.
- The static library references `dlopen` and `clock_gettime`; the Android
  systems already carry `-lm` for the latter.
