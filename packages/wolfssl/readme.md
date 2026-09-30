# wolfSSL

wolfSSL is a TLS implementation in C, built around wolfCrypt's primitives.
It is the embedded-friendly cousin of OpenSSL: smaller, simpler to
configure, and with a header-only-ish API where you can compile only the
protocols and features you need. Where OpenSSL is the default for server
software, wolfSSL shows up in firmware and embedded stacks that cannot
afford OpenSSL's surface.

The API mirrors the parts of OpenSSL's SSL API that matter, so porting is
mostly renaming.

```c
#include <wolfssl/options.h>
#include <wolfssl/ssl.h>

WOLFSSL_CTX *ctx = wolfSSL_CTX_new(TLSv1_2_server_method());
wolfSSL_CTX_load_verify_locations(ctx, ca_cert, NULL);
int fd = wolfSSL_CTX_set_fd(ctx, socket_fd);

WOLFSSL *ssl = wolfSSL_new(ctx);
wolfSSL_accept(ssl);
wolfSSL_write(ssl, buf, len);
```

Options come from `wolfssl/options.h`, which the build generates and
installs, so a consumer compiles against the same feature set the library was
built with. Include `wolfssl/options.h` *before* anything else, which is the
usual wolfSSL gotcha.

## What retrolunar builds

A static `libwolfssl.a`, the `wolfssl/` headers with the generated
`wolfssl/options.h`, and `wolfssl.pc`. Built with `WOLFSSL_OPENSSLEXTRA`,
which is the OpenSSL 3.x API compatibility layer — useful when existing code
expects OpenSSL symbols.

The examples and wolfSSL's own crypt benchmark/test programs are off. They
are host binaries, and the test program additionally pulls in Android's
logcat through `WOLFSSL_ANDROID_DEBUG`, which needs the platform's liblog
rather than anything a package prefix provides.

## Using it

```sh
pkg-config --cflags --libs wolfssl
```

Link the crypto algorithms you use by enabling the corresponding options —
the archive contains everything the build enabled, and wolfSSL's ALPN,
session-ticket and certificate-generation helpers need a random source
configured explicitly (`wolfSSL_Init` plus a `wolfSSL_RNG`).

## Notes

- CMake build: the GitHub tag archive ships `Makefile.am` but no generated
  `configure`, so Autotools would mean running upstream's `autogen.sh` with
  the native autotools. The recipe passes `$CMAKE_FLAGS` plus wolfSSL's own
  switches.
- Two platform facts from the Android systems are load-bearing here:
  `-DTHREADS_PREFER_PTHREAD_FLAG=ON` (Bionic keeps pthreads in libc, so
  cmake's library hunt would otherwise reach for a `pthreads` library that
  does not exist) and `-lm` in `LDFLAGS` (wolfCrypt's maths use `log2`
  and friends, which Bionic keeps in libm).
- This is a second TLS stack alongside OpenSSL 4.0.2, which is already in
  this prefix. Most C code here should use OpenSSL; wolfSSL earns its place
  where the build configuration matters more than API familiarity.
