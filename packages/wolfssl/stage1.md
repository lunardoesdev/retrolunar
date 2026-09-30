# wolfssl build forecast

- Recipe: `generic.lua`, source `source.lua`
- Version pinned: 5.8.2-stable, from the git tag `v5.8.2-stable` of
  `github.com/wolfSSL/wolfssl`
- Build system: **CMake** (`generic.lua:16`)
- Installs: `lib/libwolfssl.a`, `include/wolfssl/**/*.h`,
  `lib/pkgconfig/wolfssl.pc`, plus a CMake package config
- Requires: `wolfssl@source` only (`generic.lua:1`). No package dependencies —
  wolfSSL is self-contained and does not use OpenSSL.

| system | verdict | reason |
|---|---|---|
| aarch64-android21 | WILL BUILD | `-DWOLFSSL_CRYPT_TESTS=no` (`generic.lua:16`) is the load-bearing flag and its reason is recorded at `generic.lua:12-15`: that test program is a host binary that pulls in Android's logcat via `WOLFSSL_ANDROID_DEBUG`, which needs the platform `liblog` — which is **not** in this prefix and is not something it should be. With it off, the compiled surface is `src/*.c` (AES-GCM, ChaCha20, SHA-2, SHA-3, RSA, ECC, X25519, HKDF) plus wolfCrypt's `wc_port.h` dispatch. Bionic has every libc call reached at API 21: `mmap`, `munmap`, `fopen`, `time`, `gettimeofday`. **No `mktime_z`, no `nl_langinfo`, no `posix_spawn`.** |
| aarch64-android24 | WILL BUILD | As above. |
| aarch64-android35 | WILL BUILD | As above. |
| x86_64-android35 | WILL BUILD | As above. wolfSSL selects its assembly paths via `#if` on the arch; the portable C path is always available, so no row is architecture-blocked. |
| x86_64-mingw | WILL BUILD | As above, plus wolfSSL's own `WOLFSSL_WINDOWS_MSC`/`MINGW` handling in `wc_port.h`. |
| clang-native | WILL BUILD | Native; same flag set. |

**API level notes.** **No new wall.** wolfSSL is the kind of package that could
plausibly need something odd, and I looked for the three usual ones: it uses
`mktime` (not `mktime_z`) for certificate validity, `localtime_r` (not
`localtime_rz`), and its own `XMEMCPY`/`XMEMSET` rather than `<string.h>`
extensions. Nothing is API-24+ and nothing is API-26+. The API level is inert.

**Risks / what a reviewer should check.**
1. **The comment at `generic.lua:6-8` about CMake-not-Autotools is accurate and
   load-bearing.** The `v5.8.2-stable` tag archive ships `Makefile.am` but
   **no generated `configure`**, so the autotools route would need
   `autogen.sh` run with native autoconf/automake/libtool. CMake is shipped and
   complete, so the recipe takes it. This is the same shape as
   `packages/zopfli/stage1.md` and `packages/libconfig/stage1.md` — an upstream
   tag archive with inputs but no generated build system — and **no autotools
   timestamp guard is needed or present**, correctly.
2. **`-DWOLFSSL_OPENSSLEXTRA=yes` is a real API choice, not a default.** It
   turns on the OpenSSL 3.x compatibility shim, which is most of what makes
   wolfSSL drop-in for OpenSSL consumers — and it roughly doubles the compiled
   surface (`src/ssl.c`, `src/openssl/*.c`). That is a deliberate, documented
   trade in the recipe comment at `generic.lua:9`. A reviewer who wants a
   smaller archive should say so, but `OPENSSLEXTRA` is the reason most people
   take wolfSSL over a bare wolfCrypt build, so keeping it is defensible.
3. **`-DBUILD_SHARED_LIBS=OFF` matters**, and wolfSSL's CMake is a little
   unusual here: it defines its own `BUILD_SHARED_LIBS` and also honours a
   `WOLFSSL_SHARED` alias. If a future release makes one default independently,
   a `libwolfssl.so` could appear. The verification step below searches for
   `*.so*` and is the check that catches it.
4. **`-DWOLFSSL_EXAMPLES=no` is documentation** (upstream's default is off for
   CMake). Keeping it is fine.
5. **5.8.2 is the current stable line**; the `-stable` tag suffix is part of the
   tag name, so the URL in `source.lua:6` depends on it exactly.

**How to verify once built.**
- `lib/libwolfssl.a`, `include/wolfssl/ssl.h`, `include/wolfssl/wolfcrypt/settings.h`,
  `lib/pkgconfig/wolfssl.pc`
- `pkg-config --modversion wolfssl` → `5.8.2`
- `llvm-objdump -f lib/libwolfssl.a | head` → `elf64-littleaarch64` on aarch64
- `llvm-nm --defined-only lib/libwolfssl.a | grep -cE 'wc_AesGcmEncrypt|wc_ChaCha20Poly1305'`
  → **non-zero**, proving the crypto algorithms really compiled in rather than
  being stubbed out by a missing-algorithm path
- `llvm-nm -u lib/libwolfssl.a | grep -c '__android_log'` → must be **0**,
  which is the check that `-DWOLFSSL_CRYPT_TESTS=no` did its job and that no
  platform `liblog` dependency leaked in
- `find $PREFIX/lib -name 'libwolfssl.so*'` must be **empty** (risk 3)
- `test -f $PREFIX/include/wolfssl/openssl/ssl.h` → true, proving
  `-DWOLFSSL_OPENSSLEXTRA=yes` took effect (risk 2)