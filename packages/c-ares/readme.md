# c-ares

c-ares is a C library for asynchronous DNS resolution: `getaddrinfo(3)` with
callbacks instead of blocking, and without a thread per lookup. It parses and
issues DNS queries itself (over UDP with TCP fallback), so it does not need
libc's resolver, getaddrinfo, or its NSS configuration.

The older API mirrors getaddrinfo with an extra `ares_callback` and an
`ares_getaddrinfo` call; the newer one is `ares_query`, `ares_query_dnsrec`
and the structured `_parse` result accessors, which give you the parsed
records instead of a hostent.

```c
#include <ares.h>

ares_library_init(ARES_LIB_INIT_ALL);
struct ares_options options;
ares_options_init(&options);
options.timeout = 2000;
options.retry = 2;
ares_init_options(&options);

struct ares_addrinfo hints = {0};
hints.ai_family = AF_UNSPEC;
hints.ai_socktype = SOCK_STREAM;

struct ares_addrinfo *result;
ares_getaddrinfo(NULL, "example.com", NULL, &hints, callback, &result);
```

The callback receives the `ares_addrinfo` list and must `ares_freeaddrinfo`
it. Options are per-channel, so a resolver can have its own timeout, servers
and retries without touching the process's global settings.

## What retrolunar builds

A static `libcares.a`, `ares.h` / `ares_build.h` / `ares_version.h` and
`libcares.pc`. The command line tools (`adig`, `ahost`, `aadd`) and the test
suite are off: host programs, and the tests want real network access.

## Using it

```sh
pkg-config --cflags --libs libcares
```

## Notes

- Autotools build with the system's `$AUTOCONF_CONFIGURE_FLAGS`; the recipe
  adds only package facts: static, `-fpic`, tests off.
- c-ares opens its own UDP sockets and uses the system resolver only for
  `/etc/resolv.conf`, which is what makes it useful on Android where the
  platform resolver is Java-based.
- `CARES_STATICLIB` must be defined when compiling against the static
  archive on Windows; on ELF targets visibility is handled by the
  version script, so no define is needed.
