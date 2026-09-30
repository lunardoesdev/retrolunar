# libevent

libevent is an event loop with a small API and a plugin backend: you create
an `event_base`, register a few callbacks and call `event_base_dispatch`.
The loop itself is provided by epoll on Linux (and on Android), and SSL is
provided by a separate module that talks to OpenSSL.

```c
#include <event2/event.h>

struct app *self = calloc(1, sizeof *self);
struct event_base *base = event_base_new();

struct event *ev = evtimer_new(base, on_timeout, self);
evtimer_add(ev, &(struct timeval){ .tv_sec = 5, .tv_usec = 0 });

event_base_dispatch(base);
```

Callbacks receive `int fd, short events`; a socket callback gets the file
descriptor and asks libevent for the buffer with `event_get_iov`/`input_event`
because libevent owns the read/write buffer for efficiency. `bufferevent`
wraps that for you if you would rather not manage buffers.

Two backends matter for correctness: `libevent_pthreads` (thread support),
and for SSL the `libevent_openssl` module plus an `event_openssl` context
created with `event_openssl_init()`. Both are built here.

## What retrolunar builds

Four static libraries:

- `libevent_core` — the event loop and its buffers.
- `libevent_extra` — everything in the above that is not needed for a plain
  loop: signals, HTTP, RPC, and the DNS resolver.
- `libevent` — core plus extra, for the common case.
- `libevent_openssl` — the SSL backend.

Plus `event.h` and friends, `event-config.h`, `libevent.pc` and
`libevent_openssl.pc`. Sample programs, the regression suite and the
benchmark are off: host programs, and the regression suite is a large
autotest tree this prefix has no use for.

## Using it

```sh
pkg-config --cflags --libs libevent_openssl   # loop + SSL
pkg-config --cflags --libs libevent           # loop only
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the
  recipe adds only package facts: static, `-fpic`, the OpenSSL backend from
  this prefix (found through the prefix's pkg-config path), and the host
  programs off.
- Android has no `SO_REUSEPORT`-based DNS balancing and no `/dev/urandom`
  difference to worry about, so no Android-specific file is needed; the
  generic configure detects the platform itself.
- libevent's bundled DNS resolver is the default. `--disable-libevent-resolver`
  would use the system one, which is not useful here.
