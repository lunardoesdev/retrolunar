# mbedtls build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 3.6.3 (GitHub release asset, `.tar.bz2`)
- Build system: CMake
- Installs: three static archives — `libmbedtls.a`, `libmbedx509.a`,
  `libmbedcrypto.a` — plus `include/mbedtls/`, `include/mbedx509/`,
  `include/mbedcrypto/`. **No programs**: `certs/` generation tools,
  `programs/` and the test suite are all off.
- Requires: `mbedtls@source` only. No dependencies.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `ENABLE_PROGRAMS=OFF` and `ENABLE_TESTING=OFF` at `generic.lua:8` remove the host programs and the self-test suite — both of which would be target executables that must never be run. `USE_SHARED_MBEDTLS_LIBRARY=OFF` / `USE_STATIC_MBEDTLS_LIBRARY=ON` give the static set. Mbed TLS is portable C99 with no platform branches in the crypto core; the one platform-aware area (entropy gathering) is behind `MBTLS_ENTROPY_C` and uses `getrandom`/`/dev/urandom`, both available in Bionic. |
| aarch64-android24 | WILL BUILD | As above; representative system. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above; no 32/64-bit difference in the library. |
| x86_64-mingw | WILL BUILD | As above. Mbed TLS supports Windows and its `net_sockets.c` has a Winsock path; with programs off, the network backend is compiled but unused. |
| clang-native | WILL BUILD | As above. |

**API level notes.** None. The crypto primitives (AES, ChaCha20, SHA-256,
RSA, ECC) are pure computation; the Bionic surface is `memcpy`, `mbedtls_ct`
type helpers and, for entropy, `getrandom` (declared `__INTRODUCED_IN(28)`) with
a `/dev/urandom` fallback that Mbed TLS uses below that. So the API level is a
fallback-selection variable, not a failure. `armv7a-android*` and
`i686-android*` match `aarch64-android*`.

**Risks / what a reviewer should check.**

1. **Three archives and a strict link order.** `libmbedx509.a` needs
   `libmbedtls.a` needs `libmbedcrypto.a`. Mbed TLS does **not** ship a
   `.pc` file by default in the CMake build for 3.6, so a consumer has to know
   the order by heart or use `find_package(MbedTLS)`. Check whether
   `lib/pkgconfig/` gets anything; if not, that is a real usability gap worth
   recording, and the CMake package config is the intended path.
2. **`ENABLE_TESTING=OFF` is the important switch here**, because Mbed TLS's
   self-tests (`mbedtls_test_*`) are *library* code, not separate programs —
   they get compiled into the archives unless testing is off. With it off they
   do not, which keeps the archives smaller and free of the test fixtures.
3. **The `certs/` generation step.** `ENABLE_PROGRAMS=OFF` should prevent
   `generate_certs.sh` and friends from running, and that matters: those
   scripts execute the freshly built `mbedtls` test programs. If any script
   invocation appears in the build log, programs got enabled.
4. **`topackage.md` has no entry for mbedtls**, and nothing in the tree
   `require()`s it — `libevent` needs OpenSSL, not mbedtls. So it is a
   standalone with no recorded build and no known consumer. Same standing as
   libwebp, libvpx, lua.
5. `cmake --build build --parallel 1` is correct (`:10`).

**How to verify once built.**

- `lib/libmbedtls.a`, `lib/libmbedx509.a`, `lib/libmbedcrypto.a` all exist.
- `include/mbedtls/ssl.h`, `include/mbedx509/x509.h` and
  `include/mbedcrypto/aes.h` exist.
- `pkg-config --modversion mbedtls` — check whether a `.pc` was installed at
  all; if not, verify by path instead.
- `$OBJDUMP -f lib/libmbedcrypto.a` prints `elf64-littleaarch64` on Android.
- `llvm-nm --defined-only lib/libmbedcrypto.a | grep -cw mbedtls_aes_encrypt`
  non-zero — the canonical crypto entry point.
- **`ls $OUT/bin/` must be empty.** Any `mbedtls_*` program here means
  `ENABLE_PROGRAMS=OFF` regressed, and those are target binaries that must
  never be run.
- `llvm-nm --defined-only lib/libmbedcrypto.a | grep -cw mbedtls_test_` must
  be **0**, proving `ENABLE_TESTING=OFF` kept the self-tests out of the
  archive.
