ACCEPT

# wolfSSL 5.8.2 — stage 2 review

Reviewed against AGENTS.md, the three representative systems, and the unpacked
tree at `nest/source/wolfssl/`. I did not build.

**A correction to my own first pass.** An early bulk scan reported "wolfssl has
no timestamp guard" as a possible defect, because `configure.ac` declares
`AC_CONFIG_HEADERS([config.h:config.in])` — so the template is `config.in`, a
fifth spelling in the tree. I flagged it before reading the recipe. **Reading
the recipe shows there is no `./configure` at all**, so AGENTS.md's guard — which
is mandated "after every `./configure`" — does not apply, and the absence is
correct. A guard would have been the *defect* here, touching a stray
`config.h.in` for no reason.

## What the recipe gets right

- **The build-system comment at lines 6-8 is the useful part and it is
  accurate.** The tag archive ships `Makefile.am` but no generated `configure`,
  so the autotools route would need upstream's `autogen.sh` run with the
  *native* autotools — a host-tool dependency this project does not take. CMake
  is the right choice and the reason is written down. This is the
  "tarball ships no generated build system" case, handled by choosing the other
  build system rather than by invoking `autoreconf`.
- `-DWOLFSSL_EXAMPLES=no` and `-DWOLFSSL_CRYPT_TESTS=no` are real wolfSSL CMake
  options and both are load-bearing:
  - the examples are host programs that a target prefix has no use for;
  - `WOLFSSL_CRYPT_TESTS` builds a test program that pulls in Android's
    logcat via `WOLFSSL_ANDROID_DEBUG`, i.e. it would need the platform
    `liblog` — and that is exactly the platform library our Android systems
    do **not** put in `LDFLAGS` (the same defect class I found in `abseil-cpp`
    and `glog` in wave 1). Turning the test off is therefore not cosmetic
    house-keeping; it avoids stepping on a real system gap.
  Both reasons are stated in the comment, which is what AGENTS.md asks for.
- `-DBUILD_SHARED_LIBS=OFF` gives the static `libwolfssl.a` the prefix wants.
  `cmake --build build --parallel 1` is serial, and install goes to `$OUT` via
  the system's `-DCMAKE_INSTALL_PREFIX=$OUT`.
- `-DWOLFSSL_OPENSSLEXTRA=yes` enables the OpenSSL 3.x compatibility layer,
  which is what makes wolfSSL drop-in for an OpenSSL consumer. That is a
  deliberate feature choice and the comment says so.
- `require("wolfssl@source")` names no missing package.

## One thing the forecast should record

wolfSSL's CMake has no `find_package` for a TLS stack — it bundles its own
crypto — so there is no `$PREFIX` dependency at all. That is worth stating
explicitly, because in a tree where most recipes `require()` two or three
packages, a zero-dependency recipe looks like an omission rather than a
property.

## Carried to the build

- `lib/libwolfssl.a` — `llvm-objdump -f lib/libwolfssl.a | head -3` → `elf64-littleaarch64` (Android) / `pei-x86-64` (mingw). A `libwolfssl.so*` means `-DBUILD_SHARED_LIBS=OFF` did not take.
- `include/wolfssl/*.h` (notably `include/wolfssl/options.h` and `include/wolfssl/ssl.h`) — `[ -f include/wolfssl/ssl.h ]`. `options.h` is **generated** by the build from `options.h.in`, so its presence proves the configure step completed rather than merely copying files.
- `lib/pkgconfig/wolfssl.pc` — `pkg-config --modversion wolfssl` → `5.8.2`. Check `Cflags` references `include/wolfssl` and not the source dir.
- `bin/` and the test programs: `testsuite/testsuite` and `examples/*` must both be **absent** — their presence means `-DWOLFSSL_CRYPT_TESTS=no` or `-DWOLFSSL_EXAMPLES=no` did not take, and the former is the one that would drag in `liblog`.
- `lib/libwolfssl.la` may also appear (wolfSSL installs a libtool archive); it is inside the loader's `$OUT/lib/*.la` rewrite set, so its `libdir=` should point at `$PREFIX` and not a staging path — worth checking with `grep '^libdir=' lib/libwolfssl.la`.
