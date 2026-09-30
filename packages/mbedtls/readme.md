# Mbed TLS

Mbed TLS (formerly PolarSSL) is an embedded TLS library with a
configurability-first design: everything is compile-time options, the API is
plain C, and it fits in firmware-sized budgets. It is the TLS stack in
Espressif, Mongoose and many others, and a reasonable default when you want
a TLS implementation you can reason about.

```c
#include <mbedtls/ssl.h>

mbedtls_ssl_context ssl;
mbedtls_ssl_init(&ssl);
mbedtls_ssl_config conf;
mbedtls_ssl_config_init(&conf);
mbedtls_ssl_config_defaults(&conf, MBEDTLS_SSL_IS_CLIENT,
                            MBEDTLS_SSL_TRANSPORT_STREAM,
                            MBEDTLS_SSL_PRESET_DEFAULT);
mbedtls_ssl_setup(&ssl, &conf);
mbedtls_ssl_set_hostname(&ssl, host);
mbedtls_ssl_set_bio(&ssl, &socket, send_cb, recv_cb, NULL);
while ((ret = mbedtls_ssl_handshake(&ssl)) != 0) { /* pump the transport */ }
```

The library is split into three archives: `libmbedtls` (protocol),
`libmbedx509` (certificates) and `libmbedcrypto` (primitives). Link all
three, in that order for the static case.

`mbedtls_config.h` at the top of the prefix decides what exists. Turning
features off there shrinks the binary, and it is the intended way to use
this library.

## What retrolunar builds

The three static libraries above, their headers, `libmbedtls.a`'s DTLS
variant, and `mbedtls.pc` / `mbedx509.pc` / `mbedcrypto.pc`. The programs
(ssl_client2, ssl_server2, test/benchmark suites) are off: host programs
that would need a working network stack to run anyway.

## Using it

```sh
pkg-config --cflags --libs mbedtls
```

## Notes

- CMake build; the recipe passes only `$CMAKE_FLAGS` and mbedtls's own
  switches for what to skip and static versus shared.
- The default build includes the bundled copies of its own dependencies
  (PSA crypto, everest) inside the three archives, so no extra packages are
  needed from this prefix.
- On Android, the entropy source and the certificate store differ from a
  desktop: seed `mbedtls_entropy` with `MBEDTLS_ENTROPY_NV_SEED` cleared and
  an `mbedtls_hmac_drbg` seeded from `getrandom(2)`, and pass the system CA
  bundle yourself — mbedtls does not read the Android trust store.
