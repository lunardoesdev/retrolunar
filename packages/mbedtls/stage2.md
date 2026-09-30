ACCEPT

# mbedtls — stage 2 review

## What the recipe gets right

- **`cmake --build build --parallel 1`** — single-job.
- `cmake -S . -B build $CMAKE_FLAGS` — every toolchain fact from the system.
- No `sed`, no patch, no `/dev/null`, no `DESTDIR`.
- `-DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF` correctly suppresses mbedtls's
  `programs/` and `tests/` trees, which are substantial and include host-run
  test binaries. `-DUSE_SHARED_MBEDTLS_LIBRARY=OFF
  -DUSE_STATIC_MBEDTLS_LIBRARY=ON` pins the static form. All four are real
  upstream options.

## What the forecast should add

mbedtls is notable among the Android-relevant packages in this shard for
**not** being an API-gate blocker: it is self-contained crypto with no
`nl_langinfo`, no `posix_spawn` and no procfs dependency. If the forecast says
so, it is worth saying plainly — it makes mbedtls one of the few packages here
that is simply buildable, with no API-level caveat.

## Carried to the build

| expected artifact | the one check that proves it |
| --- | --- |
| `$PREFIX/lib/libmbedcrypto.a`, `libmbedtls.a`, `libmbedx509.a` | `ls $PREFIX/lib/libmbed*.a` — three static archives |
| `$PREFIX/include/mbedtls/*.h` | `test -f $PREFIX/include/mbedtls/ssl.h` |
| `$PREFIX/lib/pkgconfig/mbedtls.pc` | `pkg-config --modversion mbedtls` |
| no programs | `test ! -e $PREFIX/bin/mbedtls_ssl_server2`, proving `-DENABLE_PROGRAMS=OFF` took |
